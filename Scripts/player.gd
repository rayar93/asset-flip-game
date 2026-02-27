extends CharacterBody2D

# Tunables (can be adjusted in the inspector)
@export var move_speed = 300
@export var air_move_speed = 0.7
@export var jump_velocity = -400
@export var gravity = 1000
@export var dash_speed = 1000
@export var dash_duration = 0.2
@export var max_health = 3

# Node references
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_root: Node2D = $AttackRoot
@onready var attack_area: Area2D = $AttackRoot/AttackArea
@onready var slash_vfx: AnimatedSprite2D = $AttackRoot/SlashVFX

# Internal variables
var dash_time_left = 0.0
var can_dash = true
var can_double_jump = true
var double_jump_anim_lock = false
var targets_hit_this_attack: Array[Node2D] = []

# State machine
enum State { GROUNDED, AIR, ATTACK, HURT, DASH, DEAD }
var state := State.AIR
var facing = 1 # 1 = right, -1 = left
var current_health = max_health

# ==============================================================================================================================================================================================================
# Engine callbacks
# ==============================================================================================================================================================================================================

# Initialization
func _ready():
	attack_area.area_entered.connect(_on_attack_hit)
	$PlayerHurtbox.player_hurt.connect(_on_player_hurt)
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	_return_to_base_state()
	
# Runs every physics tick
# Updates movement and state, applies physics
func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	
	var move_dir = Input.get_axis("move_left", "move_right")
	
	# Update states
	match state:
		State.GROUNDED:		_handle_grounded_input(move_dir)
		State.AIR:			_handle_air_input(move_dir)
		State.ATTACK:		_handle_attack_logic()
		State.HURT:			pass
		State.DASH:			_handle_dash_logic(delta)

	move_and_slide()
	_check_ground_status()
	_update_facing(move_dir)
	_update_animations(move_dir)
		
# ====================================================================================================================================================================================================
# State logic
# ====================================================================================================================================================================================================
	
func set_state(new_state: State):
	if state == new_state: return
			
	# Kill momentum after dash
	if state == State.DASH: velocity.x = 0
			
	state = new_state
	
	# Do this if entering state
	match state:
		State.GROUNDED:
			can_double_jump = true
			can_dash = true
			double_jump_anim_lock = false
		State.DASH:
			dash_time_left = dash_duration
			velocity = Vector2(facing * dash_speed, 0)
			can_dash = false
		State.ATTACK:
			_execute_attack_startup()
		State.DEAD:
			velocity = Vector2.ZERO
			get_tree().reload_current_scene()
	
func _handle_grounded_input(move_dir):
	velocity.x = move_dir * move_speed

	if Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		set_state(State.AIR)
	elif Input.is_action_just_pressed("dash") and can_dash:
		set_state(State.DASH)
	elif Input.is_action_just_pressed("attack"):
		set_state(State.ATTACK)
		
func _handle_air_input(move_dir):
	velocity.x = move_dir * move_speed * air_move_speed
	
	if Input.is_action_just_pressed("jump") and can_double_jump:
		velocity.y = jump_velocity
		can_double_jump = false
		double_jump_anim_lock = true
	elif Input.is_action_just_pressed("dash") and can_dash:
		set_state(State.DASH)
	elif Input.is_action_just_pressed("attack"):
		set_state(State.ATTACK)
			
func _handle_attack_logic():
	if not slash_vfx.is_playing():
		_return_to_base_state()

func _handle_dash_logic(delta: float):
	dash_time_left -= delta
	if dash_time_left <= 0:
		_return_to_base_state()
		
# ===========================================================================================================================================================================================================================
# Helpers
# ===========================================================================================================================================================================================================================
	
func _execute_attack_startup():
	targets_hit_this_attack.clear()
	
	var up = Input.is_action_pressed("up")
	var down = Input.is_action_pressed("down")
	
	attack_root.rotation_degrees = 0
	attack_root.scale = Vector2.ONE
	
	if up:		attack_root.rotation_degrees = -90
	elif down:	attack_root.rotation_degrees = 90
	else:		attack_root.scale.x = facing
	
	slash_vfx.show()
	slash_vfx.play("attack")
	attack_area.monitoring = true
	
func _update_facing(move_dir):
	if move_dir != 0 and state != State.DASH:
		facing = sign(move_dir)
	sprite.flip_h = (facing == -1)
		
func _update_animations(move_dir):
	match state:
		State.HURT:
			_play_anim("hurt")
		State.GROUNDED:
			_play_anim("run" if move_dir != 0 else "idle")
		State.AIR:
			if double_jump_anim_lock:
				_play_anim("double_jump")
				if velocity.y >= 0: double_jump_anim_lock = false
			else:
				_play_anim("jump" if velocity.y < 0 else "fall")
		
func _play_anim(anim_name):
	if sprite.animation != anim_name:
		sprite.play(anim_name)
		
func _check_ground_status():
	if state in [State.ATTACK, State.DASH, State.HURT]: return
	
	if is_on_floor() and state == State.AIR:
		set_state(State.GROUNDED)
	elif not is_on_floor() and state == State.GROUNDED:
		set_state(State.AIR)
		
func _return_to_base_state():
	attack_area.monitoring = false
	slash_vfx.hide()
	set_state(State.GROUNDED if is_on_floor() else State.AIR)

# ===============================================================================================================================================================================================
# Signals
# ===============================================================================================================================================================================================

func _on_player_hurt(attack_position: Vector2):
	if state == State.HURT: return
	
	current_health -= 1
	if current_health <= 0:
		set_state(State.DEAD)
		return
	
	var knockback_dir = sign(global_position.x - attack_position.x)
	if knockback_dir == 0: knockback_dir = -facing
	velocity = Vector2(knockback_dir * 300, -200)
	set_state(State.HURT)

func _on_attack_hit(area:Area2D):
	if area in targets_hit_this_attack: return
	
	if area.has_signal("enemy_hurt"):
		targets_hit_this_attack.append(area)
		area.enemy_hurt.emit(global_position)
		
		if attack_root.rotation_degrees == 90 and not is_on_floor():
			velocity.y = jump_velocity
			can_double_jump = true

func _on_sprite_animation_finished():
	if state == State.HURT:
		_return_to_base_state()
