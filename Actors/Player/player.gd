extends CharacterBody2D

@export_group("Movement")
@export var gravity = 1500
@export var move_speed = 300
@export var air_move_speed = 0.7
@export var jump_velocity = -450
@export var dash_speed = 1000
@export var dash_duration = 0.2

@export_group("Combat")
@export var max_health = 3
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
var coyote_timer = 0.0
var jump_buffer_timer = 0.0
var hurt_timer = 0.0
var targets_hit_this_attack: Array[Node2D] = []

enum State { GROUNDED, AIR, ATTACK, HURT, DASH, DEAD }
var state := State.AIR
var facing = 1
var current_health = max_health

var afterimage_timer = 0.0
const AFTERIMAGE_INTERVAL = 0.1

signal health_changed(new_health: int)

# ==============================================================================
# Engine callbacks
# ==============================================================================

func _ready():
	attack_area.area_entered.connect(_on_attack_hit)
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
		State.DASH:
			afterimage_timer -= delta
			if afterimage_timer <= 0.0:
				_spawn_afterimage()
				afterimage_timer = AFTERIMAGE_INTERVAL
			_handle_dash_logic(delta)

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
			can_dash = true
			if jump_buffer_timer > 0:
				jump_buffer_timer = 0
				velocity.y = jump_velocity
				set_state(State.AIR)
				return
		State.DASH:
			velocity.y = 0
			afterimage_timer = 0.0
			dash_time_left = dash_duration
			velocity = Vector2(facing * dash_speed, 0)
			can_dash = false
		State.ATTACK:
			_execute_attack_startup()
		State.HURT:
			hurt_timer = hurt_duration
		State.DEAD:
			VFX.screenshake(0.6, 20.0)
			velocity = Vector2.ZERO
			GameFlow.call_deferred("on_player_died")

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

	if Input.is_action_just_pressed("jump"):
		if coyote_timer > 0:
			velocity.y = jump_velocity
			coyote_timer = 0
		elif can_double_jump:
			velocity.y = jump_velocity
			can_double_jump = false
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
		State.HURT:     _play_anim("hurt")
		State.DASH:     pass
		State.GROUNDED: _play_anim("run" if move_dir != 0 else "idle")
		State.AIR:      _play_anim("jump" if velocity.y < 0 else "fall")

func _play_anim(anim_name):
	if sprite.animation != anim_name:
		sprite.play(anim_name)

func _check_ground_status():
	if state in [State.ATTACK, State.DASH, State.HURT]: return

	if is_on_floor() and state == State.AIR:
		set_state(State.GROUNDED)
	elif not is_on_floor() and state == State.GROUNDED:
		coyote_timer = coyote_time
		set_state(State.AIR)

func _return_to_base_state():
	attack_area.monitoring = false
	attack_area.monitorable = false
	slash_vfx.hide()
	set_state(State.GROUNDED if is_on_floor() else State.AIR)
	
func _spawn_afterimage():
	var ghost = AnimatedSprite2D.new()
	ghost.sprite_frames = sprite.sprite_frames
	ghost.animation = sprite.animation
	ghost.frame = sprite.frame
	
	ghost.offset = sprite.offset
	ghost.centered = sprite.centered
	ghost.flip_h = sprite.flip_h
	ghost.flip_v = sprite.flip_v	
	ghost.modulate.a = 0.8

	get_parent().add_child(ghost)
	ghost.global_transform = sprite.global_transform
	
	if ghost.has_method("reset_physics_interpolation"):
		ghost.reset_physics_interpolation()
	
	var tween = create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.05)
	tween.tween_callback(ghost.queue_free)
	
func die():
	set_state(State.DEAD)

# ==============================================================================
# Signals
# ==============================================================================

func _on_player_hurt(attack_position: Vector2):
	if state == State.HURT: return

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
