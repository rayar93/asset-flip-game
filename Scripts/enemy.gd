extends CharacterBody2D

# Tunables (can be adjusted in the Inspector)
@export_group("Movement")
@export var gravity = 1000
@export var move_speed = 120

@export_group("Combat")
@export var notice_radius = 220
@export var attack_radius = 45
@export var hurt_duration = 0.1
@export var hurt_left = 0.0
@export var knockback_strength = 250
@export var max_health = 3

# Node references
@onready var visual_root: Node2D = $VisualRoot
@onready var anim: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox

# Offsets for flipping
@onready var visual_base_x: float = visual_root.position.x
@onready var hitbox_base_x: float = hitbox.position.x

# State
enum State { IDLE, CHASE, ATTACK, HURT, DEAD }
var state = State.IDLE
var facing = 1 # 1 = right, -1 = left

# Internal variables
var player: Node2D = null
var attack_hit_frame = 1
var current_health = 3

# ====================================
# Engine callbacks
# ====================================

# Initialization
func _ready():
	hitbox_off()
	
	# Find player
	player = get_tree().get_first_node_in_group("player") as Node2D
	
	# Hurtbox emits signal when struck by player's attack
	$Hurtbox.hurtbox_hit.connect(_on_hurtbox_hit)
	
	# Used to know when attack animation is finished
	anim.animation_finished.connect(_on_anim_finished)
	
	# Initialize state and facing
	hitbox_off()
	_apply_facing()
	set_state(State.IDLE)
	anim.play("idle")

# Runs every physics tick
# Updates movement and state, applies physics
func _physics_process(delta):
	# Reacquire player if needed
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D

	# Gravity when airborne
	if not is_on_floor():
		velocity.y += gravity * delta
		
	# Update the state machine
	match state:
		State.IDLE:		update_idle()
		State.CHASE:	update_chase()
		State.ATTACK:	update_attack()
		State.HURT:		update_hurt(delta)
		
	# Apply motion and collisions
	move_and_slide()
	
# ======================================
# State transitions
# ======================================

func set_state(new_state: State):
	if state == new_state: return
	
	# Turn the hitbox off when changing states to prevent sticking
	hitbox_off()

	state = new_state
	
	# If transitioning into a state, do this once
	match state:
		State.IDLE:
			velocity.x = 0.0
			anim.play("idle")
		State.CHASE:
			play_anim("walk")
		State.ATTACK:
			hitbox_off()
			anim.play("attack")
		State.HURT:
			hurt_left = hurt_duration
			hitbox_off()
		State.DEAD:
			queue_free()

# =================================================
# State updates
# =================================================

func update_idle():
	velocity.x = 0.0
	if distance_to_player() <= notice_radius:
		set_state(State.CHASE)
		
func update_chase():
	var dist = distance_to_player()
	
	# Lose interest if player leaves
	if dist > notice_radius:
		set_state(State.IDLE)
		return
		
	# Attack when close
	if dist <= attack_radius:
		set_state(State.ATTACK)
		return
	
	# Otherwise walk towards player
	var dir = direction_to_player()
	if dir != 0:
		set_facing(int(dir))
		velocity.x = dir * move_speed
		play_anim("walk")
	
func update_attack():
	velocity.x = 0.0
		
	# Turn on hitbox for single attack frame
	if anim.frame == attack_hit_frame:
		hitbox_on()
	else:
		hitbox_off()
				
func update_hurt(delta):
	hurt_left -= delta
	
	# After hitsun ends, idle or resume chase
	if hurt_left <= 0.0:
		_return_to_engagement_state()
		
func _return_to_engagement_state():
	if distance_to_player() <= notice_radius:
		set_state(State.CHASE)
	else:
		set_state(State.IDLE)

# ========================================================================
# Helpers
# ========================================================================

# Hitbox / animation flipping
func set_facing(new_facing):
	if new_facing == 0 or new_facing == facing: return
	facing = new_facing
	_apply_facing()
	
func _apply_facing():
	anim.flip_h = (facing == -1)
	visual_root.position.x = visual_base_x * facing
	hitbox.position.x = hitbox_base_x * facing
	
# Distance to player
func distance_to_player():
	if player == null:
		return INF
	return global_position.distance_to(player.global_position)

# Direction of player
func direction_to_player():
	if player == null:
		return 0.0
	return sign(player.global_position.x - global_position.x)

func hitbox_on():
	hitbox.monitoring = true
	hitbox.monitorable = true
	
func hitbox_off():
	hitbox.monitoring = false
	hitbox.monitorable = false

# Avoids anim.play() breaking hitbox logic
func play_anim(anim_name):
	if anim.animation != anim_name:
		anim.play(anim_name)

# ============================================
# Signals
# ============================================

func _on_hurtbox_hit(attack_position: Vector2):
	# Ignore hits while already hurt or dead
	if state == State.HURT or state == State.DEAD: return
		
	current_health -= 1
		
	# Calculate knockback direction
	var dir = sign(global_position.x - attack_position.x)
	# If attack was perfectly centered, just face the other way
	if dir == 0:
		dir = -facing
	
	# Apply horizontal knockback velocity and a little vertical velocity
	velocity.x = dir * knockback_strength
	velocity.y = -200
	
	set_state(State.DEAD if current_health <= 0 else State.HURT)
	
func _on_anim_finished():
	if state == State.ATTACK:
		set_state(State.CHASE)
