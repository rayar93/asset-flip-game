extends CharacterBody2D

@export_group("Movement")
@export var gravity = 1500
@export var move_speed = 300
@export var air_move_speed = 0.7
@export var jump_velocity = -450
@export var dash_speed = 1000
@export var dash_duration = 0.2

@export_group("Combat")
@export var max_health = 5
@export var hurt_duration = 0.4

@export_group("Jump Feel")
@export var coyote_time = 0.12
@export var jump_buffer_time = 0.12

@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D
@onready var attack_root: Node2D = $AttackRoot
@onready var attack_area: Area2D = $AttackRoot/AttackArea
@onready var slash_vfx: AnimatedSprite2D = $AttackRoot/SlashVFX

var dash_time_left = 0.0
var can_dash = true
var can_double_jump = true
var _double_jumped = false
var coyote_timer = 0.0
var jump_buffer_timer = 0.0
var hurt_timer = 0.0
var targets_hit_this_attack: Array[Node2D] = []

enum State { GROUNDED, AIR, ATTACK, HURT, DASH, DEAD }
var state := State.AIR
var facing = 1
var current_health = max_health

#const SmokeEffect = preload("C:/Users/alanr/OneDrive - Appalachian State University/Documents/GitHub/Capstone-Project/actors/player/dash.tscn")

signal health_changed(new_health: int)

# ==============================================================================
# Engine callbacks
# ==============================================================================

func _ready():
	sprite.frame_changed.connect(_on_frame_changed)
	attack_area.area_entered.connect(_on_attack_hit)
	if not $PlayerHurtbox.player_hurt.is_connected(_on_player_hurt):
		$PlayerHurtbox.player_hurt.connect(_on_player_hurt)
	_return_to_base_state()

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	coyote_timer -= delta
	jump_buffer_timer -= delta
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

	var move_dir = Input.get_axis("move_left", "move_right")

	match state:
		State.GROUNDED:  _handle_grounded_input(move_dir)
		State.AIR:       _handle_air_input(move_dir)
		State.ATTACK:    _handle_attack_logic()
		State.HURT:      _handle_hurt_logic(delta)
		State.DASH:		 _handle_dash_logic(delta)

	move_and_slide()
	_check_ground_status()
	_update_facing(move_dir)
	_update_animations(move_dir)

# ==============================================================================
# State logic
# ==============================================================================

func set_state(new_state: State):
	if state == new_state: return

	if state == State.DASH: velocity.x = 0
	state = new_state

	match state:
		State.GROUNDED:
			can_double_jump = true
			_double_jumped = false
			can_dash = true
			if jump_buffer_timer > 0:
				jump_buffer_timer = 0
				velocity.y = jump_velocity
				set_state(State.AIR)
				return
		State.DASH:
			AudioManager.play("player_dash")
			velocity.y = 0
			dash_time_left = dash_duration
			velocity = Vector2(facing * dash_speed, 0)
			can_dash = false
			#_spawn_dash_smoke()
		State.ATTACK:
			_execute_attack_startup()
		State.HURT:
			hurt_timer = hurt_duration
		State.DEAD:
			ScoreManager.reset_score()
			AudioManager.play("player_death")
			VFX.screenshake(0.6, 20.0)
			velocity = Vector2.ZERO
			GameFlow.call_deferred("on_player_died")

func _handle_grounded_input(move_dir):
	velocity.x = move_dir * move_speed

	if Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		AudioManager.play("player_jump")
		set_state(State.AIR)
	elif Input.is_action_just_pressed("dash") and can_dash:
		set_state(State.DASH)
	elif Input.is_action_just_pressed("attack"):
		set_state(State.ATTACK)

func _handle_air_input(move_dir):
	velocity.x = move_dir * move_speed * air_move_speed

	if Input.is_action_just_pressed("jump"):
		if coyote_timer > 0:
			velocity.y = jump_velocity
			coyote_timer = 0
			AudioManager.play("player_jump", -10.0)
		elif can_double_jump:
			velocity.y = jump_velocity
			can_double_jump = false
			_double_jumped = true
			sprite.play("double_jump")
			AudioManager.play("player_jump")
	elif Input.is_action_just_pressed("dash") and can_dash:
		set_state(State.DASH)
	elif Input.is_action_just_pressed("attack"):
		set_state(State.ATTACK)

func _handle_attack_logic():
	if not slash_vfx.is_playing():
		_return_to_base_state()

func _handle_dash_logic(delta: float):
	velocity.y = 0
	dash_time_left -= delta
	if dash_time_left <= 0:
		_return_to_base_state()

func _handle_hurt_logic(delta):
	hurt_timer -= delta
	if hurt_timer <= 0.0:
		_return_to_base_state()

# ==============================================================================
# Helpers
# ==============================================================================

func _execute_attack_startup():
	targets_hit_this_attack.clear()

	attack_root.rotation_degrees = 0
	attack_root.scale = Vector2.ONE

	if Input.is_action_pressed("up"):
		attack_root.rotation_degrees = -90
	elif Input.is_action_pressed("down"):
		attack_root.rotation_degrees = 90
	else:
		attack_root.scale.x = facing
		
	attack_root.reset_physics_interpolation()

	AudioManager.play("player_attack")
	slash_vfx.show()
	slash_vfx.play("attack")
	attack_area.monitoring = true
	attack_area.monitorable = true

func _update_facing(move_dir):
	if move_dir != 0 and state != State.DASH:
		facing = sign(move_dir)
	visual_root.scale.x = facing

func _update_animations(move_dir):
	match state:
		State.HURT:
			_play_anim("hurt")
		State.DASH:
			pass
		State.GROUNDED:
			_play_anim("run" if move_dir != 0 else "idle")
		State.AIR:
			if _double_jumped and velocity.y < 0:
				_play_anim("double_jump")
			elif velocity.y < 0:
				_play_anim("jump")
			else:
				_play_anim("fall")

func _play_anim(anim_name):
	if sprite.animation != anim_name:
		sprite.play(anim_name)

func _check_ground_status():
	if state in [State.ATTACK, State.DASH, State.HURT]: return

	if is_on_floor() and state == State.AIR:
		set_state(State.GROUNDED)
		AudioManager.play("land")
	elif not is_on_floor() and state == State.GROUNDED:
		coyote_timer = coyote_time
		set_state(State.AIR)

func _return_to_base_state():
	attack_area.monitoring = false
	attack_area.monitorable = false
	slash_vfx.hide()
	set_state(State.GROUNDED if is_on_floor() else State.AIR)

#func _spawn_dash_smoke():
	#var smoke = SmokeEffect.instantiate()
	#get_parent().add_child(smoke)
	#smoke.global_position = global_position
	#smoke.scale.x = facing
	#smoke.play()

func die():
	set_state(State.DEAD)

# ==============================================================================
# Signals
# ==============================================================================

func _on_player_hurt(attack_position: Vector2):
	if state == State.HURT: return

	AudioManager.play("player_hurt")
	current_health -= 1
	health_changed.emit(current_health)
	VFX.screenshake()
	if current_health <= 0:
		set_state(State.DEAD)
		return

	var knockback_dir = sign(global_position.x - attack_position.x)
	if knockback_dir == 0: knockback_dir = -facing
	velocity = Vector2(knockback_dir * 300, -200)
	set_state(State.HURT)

func _on_attack_hit(area: Area2D):
	if area in targets_hit_this_attack: return

	if area.has_signal("enemy_hurt"):
		targets_hit_this_attack.append(area)
		area.enemy_hurt.emit(global_position)

		if attack_root.rotation_degrees == 90 and not is_on_floor():
			velocity.y = jump_velocity
			can_double_jump = true
			AudioManager.play("pogo_bounce")

func _on_frame_changed():
	if state != State.GROUNDED: return
	if sprite.animation != "run": return
	if sprite.frame in [1, 3]:
		AudioManager.play("footstep", -10.0)
