extends CharacterBody2D

# Tunables (can be adjusted in the Inspector)
@export_group("Movement")
@export var gravity = 2000
@export var move_speed = 100

@export_group("Combat")
@export var notice_radius = 200
@export var attack_radius = 100
@export var hurt_duration = 0.2
@export var knockback_strength = 250
@export var max_health = 3

# Node references
@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var hurtbox: Area2D = $Hurtbox

# Offsets for flipping
@onready var visual_base_x: float = visual_root.position.x
@onready var hitbox_base_x: float = hitbox.position.x

# State
enum State { IDLE, CHASE, ATTACK, HURT, DEAD }
var state = State.IDLE
var facing = 1 # 1 = right, -1 = left
var current_health = max_health
var hurt_timer = 0.0

# Internal variables
var player: Node2D = null
var attack_hit_frame = 2
var targets_hit_this_attack: Array[Node2D] = []

# =======================================================================================================================================================================================
# Engine callbacks
# =======================================================================================================================================================================================

# Initialization
func _ready():
	# Find player
	player = get_tree().get_first_node_in_group("player") as Node2D
	
	# Signal connections
	hurtbox.enemy_hurt.connect(_on_hurtbox_hit)
	sprite.animation_finished.connect(_on_anim_finished)	
	hitbox.area_entered.connect(_on_hitbox_entered)
	
	# Initialize state and facing
	_set_hitbox_active(false)
	_apply_facing()
	sprite.play("idle")
	set_state(State.IDLE)

# Runs every physics tick
# Updates movement and state, applies physics
func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
		
	# Update the state machine
	match state:
		State.IDLE:		_handle_idle_logic()
		State.CHASE:	_handle_chase_logic()
		State.ATTACK:	_handle_attack_logic()
		State.HURT:		_handle_hurt_logic(delta)
		
	# Apply motion and collisions
	move_and_slide()

# ====================================================================================================================================================================================================
# State logic
# ====================================================================================================================================================================================================

func set_state(new_state: State):
	if state == new_state: return
	
	_set_hitbox_active(false)
	targets_hit_this_attack.clear()

	state = new_state
	
	# If transitioning into a state, do this once
	match state:
		State.IDLE:
			velocity.x = 0.0
			_play_anim("idle")
		State.CHASE:
			_play_anim("walk")
		State.ATTACK:
			velocity.x = 0
			_play_anim("attack")
		State.HURT:
			hurt_timer = hurt_duration
		State.DEAD:
			queue_free()

func _handle_idle_logic():
	if _get_distance_to_player() <= notice_radius:
		set_state(State.CHASE)
		
func _handle_chase_logic():
	var dist = _get_distance_to_player()
	
	if dist > notice_radius:
		set_state(State.IDLE)
		return
		
	if dist <= attack_radius:
		set_state(State.ATTACK)
		return
	
	var dir = _get_direction_to_player()
	if dir != 0:
		_set_facing(int(dir))
		velocity.x = dir * move_speed
		_play_anim("walk")
	
func _handle_attack_logic():
	_set_hitbox_active(sprite.frame == attack_hit_frame)
				
func _handle_hurt_logic(delta):
	hurt_timer -= delta
	if hurt_timer <= 0.0:
		_return_to_engagement_state()

# ===========================================================================================================================================================================================================================
# Helpers
# ===========================================================================================================================================================================================================================

# Hitbox / animation flipping
func _set_facing(new_facing):
	if new_facing == 0 or new_facing == facing: return
	facing = new_facing
	_apply_facing()
	
func _apply_facing():
	sprite.flip_h = (facing == -1)
	visual_root.position.x = visual_base_x * facing
	hitbox.position.x = hitbox_base_x * facing
	
func _get_distance_to_player():
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return INF
	return global_position.distance_to(player.global_position)

func _get_direction_to_player():
	if not is_instance_valid(player): return 0.0
	return sign(player.global_position.x - global_position.x)

func _set_hitbox_active(active):
	hitbox.monitoring = active
	hitbox.monitorable = active

# Avoids anim.play() breaking hitbox logic
func _play_anim(anim_name):
	if sprite.animation != anim_name:
		sprite.play(anim_name)
		
func _return_to_engagement_state():
	set_state(State.CHASE if _get_distance_to_player() <= notice_radius else State.IDLE)

# ===============================================================================================================================================================================================
# Signals
# ===============================================================================================================================================================================================

func _on_hurtbox_hit(attack_position: Vector2):
	# Ignore hits while already hurt or dead
	if state == State.HURT or state == State.DEAD: return
		
	current_health -= 1
		
	# Calculate knockback direction
	var knockback_dir = sign(global_position.x - attack_position.x)
	# If attack was perfectly centered, just face the other way
	if knockback_dir == 0: knockback_dir = -facing
	
	# Apply horizontal knockback velocity and a little vertical velocity
	velocity = Vector2(knockback_dir * knockback_strength, -200)

	set_state(State.DEAD if current_health <= 0 else State.HURT)
	
func _on_hitbox_entered(area: Area2D):
	if area in targets_hit_this_attack: return
	
	if area.has_signal("player_hurt"):
		targets_hit_this_attack.append(area)
		area.player_hurt.emit(global_position)
	
func _on_anim_finished():
	if state in [State.ATTACK, State.HURT]:
		_return_to_engagement_state()
