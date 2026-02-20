extends CharacterBody2D

# ===========================================
# Tunables (can be adjusted in the Inspector)
# ===========================================

@export var gravity = 1000
@export var move_speed = 120

# Player engagement ranges
@export var notice_radius = 220
@export var attack_radius = 45

# Hurt / knockback settings
@export var hurt_duration = 0.25
@export var hurt_left = 0.0
@export var knockback_strength = 250

# ==============================================
# @onready variables are computed after _ready()
#===============================================

# Node references
@onready var visual_root: Node2D = $VisualRoot
@onready var anim: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox

# The enemy hitbox and animation are offset.
# We store the offsets so we can flip them later.
@onready var visual_base_x: float = visual_root.position.x
@onready var hitbox_base_x: float = hitbox.position.x

# ===============
# Other variables
# ===============

# State machine variables
enum State { IDLE, CHASE, ATTACK, HURT }
var state = State.IDLE

# 1 = right, -1 = left
var facing = 1

# Reference to player
var player: Node2D = null

# Which animation frame should the attack be active on
var attack_hit_frame = 1

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
	set_state(State.IDLE)
	set_facing(facing)

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
		State.IDLE:
			update_idle(delta)
		State.CHASE:
			update_chase(delta)
		State.ATTACK:
			update_attack(delta)
		State.HURT:
			update_hurt(delta)
		
	# Apply motion and collisions
	move_and_slide()
	
# ============================================
# Signals
# ============================================

func _on_hurtbox_hit(attack_position: Vector2):
	# Ignore hits while already hurt
	if state == State.HURT:
		return
		
	# Calculate knockback direction
	var dir = sign(global_position.x - attack_position.x)
	# If attack was perfectly centered, just face the other way
	if dir == 0:
		dir = -facing
	
	# Apply horizontal knockback velocity and a little vertical velocity
	velocity.x = dir * knockback_strength
	velocity.y = -200
	
	set_state(State.HURT)
	
# When attack animation ends, turn hitbox off and resume chasing player.
func _on_anim_finished():
	if state == State.ATTACK:
		hitbox_off()
		set_state(State.CHASE)

# ========================================================================
# Helpers
# ========================================================================

# Hitbox / animation flipping
func set_facing(new_facing):
	if new_facing == 0 or new_facing == facing:
		return
		
	facing = new_facing
	
	# Flip sprite
	anim.flip_h = (facing == -1)
	
	# Mirror child nodes by flipping their X offset
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

# ======================================
# State transitions
# ======================================

func set_state(new_state: State):
	if state == new_state:
		return
	
	# Turn the hitbox off when changing states to prevent sticking
	hitbox_off()
		
	state = new_state
	
	# If transitioning into a state, do this once
	match state:
		State.IDLE:
			velocity.x = 0.0
		State.CHASE:
			pass
		State.ATTACK:
			hitbox_off()
			play_anim("attack")
		State.HURT:
			hurt_left = hurt_duration
			hitbox_off()

# =================================================
# State updates
# =================================================

func update_idle(_delta):
	velocity.x = 0.0
	play_anim("idle")
	
	# If the player is close enough, begin chasing
	var d = distance_to_player()
	if d <= notice_radius:
		set_state(State.CHASE)
		
func update_chase(_delta):
	var d = distance_to_player()
	
	# Lose interest if player leaves
	if d > notice_radius:
		set_state(State.IDLE)
		return
		
	# Attack when close
	if d <= attack_radius:
		set_state(State.ATTACK)
		return
	
	# Otherwise walk towards player
	var dir = direction_to_player()
	if dir != 0:
		set_facing(int(dir))
		
	velocity.x = dir * move_speed
	play_anim("walk")
	
func update_attack(_delta):
	velocity.x = 0.0
		
	# Turn on hitbox for single attack frame
	if anim.frame == attack_hit_frame:
		if not hitbox.monitorable:
			hitbox_on()
	else:
		if hitbox.monitorable:
			hitbox_off()
	
	# If animation stops unexpectedly, stop attacking
	if not anim.is_playing():
		hitbox_off()
		set_state(State.CHASE)
		return
				
func update_hurt(delta):
	# Plays hurt animation if it exists
	play_anim("hurt")
	
	# Hitstun
	hurt_left -= delta
	
	# After hitsun ends, idle or resume chase
	if hurt_left <= 0.0:
		var d = distance_to_player()
		if d <= notice_radius:
			set_state(State.CHASE)
		else:
			set_state(State.IDLE)
