extends CharacterBody2D

@export_group("Movement")
@export var gravity = 1500
@export var move_speed = 250
@export var dash_speed = 1000
@export var jump_force = -800

@export_group("Combat")
@export var attack_cooldown = 0.5
@export var side_attack_radius = 80

@export var air_far_x = 260
@export var air_medium_x = 160

@export var above_y = 60
@export var below_y = 80
@export var overhead_x = 100
@export var strong_x = 100

@export var hurt_duration = 0.5
@export var knockback_strength = 150
@export var max_health = 10

@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D
@onready var hitbox: Area2D = $VisualRoot/Hitbox
@onready var hurtbox: Area2D = $VisualRoot/Hurtbox

@onready var shape_side   = $VisualRoot/Hitbox/SideShape
@onready var shape_up     = $VisualRoot/Hitbox/UpShape
@onready var shape_strong = $VisualRoot/Hitbox/StrongShape
@onready var shape_down = 	$VisualRoot/Hitbox/DownShape

enum State {
	INTRO,
	CHASE,
	DASH,
	AIR,
	ATTACK_SIDE,
	ATTACK_UP,
	ATTACK_STRONG,
	ATTACK_DOWN,
	HURT,
	DEAD
}

var state = State.INTRO
var facing = 1
var current_health = max_health

var player: Node2D = null
var hurt_timer = 0.0
var chase_timer = 0.0
var dash_timer = 0.0
var action_cooldown = 0.0
var targets_hit_this_attack: Array[Node2D] = []

# ==============================================================================
# Engine callbacks
# ==============================================================================

func _ready():
	current_health = max_health
	player = get_tree().get_first_node_in_group("player") as Node2D

	hurtbox.enemy_hurt.connect(_on_hurtbox_hit)
	sprite.animation_finished.connect(_on_anim_finished)
	hitbox.area_entered.connect(_on_hitbox_entered)

	hitbox.monitoring = true
	_disable_all_hitboxes()
	_apply_facing()
	set_state(State.CHASE)

func _physics_process(delta):
	if not is_on_floor():
		if state not in [State.ATTACK_SIDE, State.ATTACK_UP, State.ATTACK_STRONG, State.ATTACK_DOWN, State.HURT, State.DEAD]:
			_play_anim("fall")
		velocity.y += gravity * delta

	match state:
		State.INTRO:			velocity.x = 0.0; _play_anim("idle")
		State.CHASE:			_handle_chase_logic(delta)
		State.DASH:				_handle_dash_logic(delta)
		State.AIR:				_handle_air_logic()
		State.ATTACK_SIDE:		_handle_attack_logic("attack", 0, shape_side)
		State.ATTACK_UP:		_handle_attack_logic("up_attack", 1, shape_up)
		State.ATTACK_STRONG:	_handle_attack_logic("strong_attack", 1, shape_strong)
		State.ATTACK_DOWN:		_handle_attack_logic("down_attack", 1, shape_down, true)
		State.HURT:				_handle_hurt_logic(delta)
		State.DEAD:				pass

	move_and_slide()

# ==============================================================================
# State logic
# ==============================================================================

func set_state(new_state: State):
	if state == new_state: return

	_disable_all_hitboxes()
	targets_hit_this_attack.clear()
	state = new_state

	match state:
		State.INTRO:
			velocity.x = 0.0
			_play_anim("idle")
		State.CHASE:
			chase_timer = 0.0
		State.DASH:
			dash_timer = 0.4
			velocity.y = 0
			velocity.x = facing * dash_speed
			_play_anim("dash")
		State.ATTACK_SIDE:
			velocity.x = 0
			_play_anim("attack")
		State.ATTACK_UP:
			velocity.x = 0
			_play_anim("up_attack")
		State.ATTACK_STRONG:
			velocity.x = 0
			_play_anim("strong_attack")
		State.ATTACK_DOWN:
			velocity.x = 0
			_play_anim("down_attack")
		State.HURT:
			hurt_timer = hurt_duration
			_play_anim("hurt")
		State.DEAD:
			queue_free()

func start_combat():
	if state == State.INTRO:
		set_state(State.CHASE)

func _handle_chase_logic(delta):
	var dir = _get_direction_to_player()
	_set_facing(dir)
	velocity.x = dir * move_speed
	
	if not is_on_floor():
		set_state(State.AIR)
		return

	if action_cooldown > 0:
		action_cooldown -= delta
		if is_on_floor(): _play_anim("walk")
		return

	_play_anim("walk")
	chase_timer += delta

	var dx = _get_distance_to_player()
	var dy = player.global_position.y - global_position.y

	if not player.is_on_floor():
		if dx >= air_far_x:
			if chase_timer > 1.5: set_state(State.DASH)
			return
		if dx >= air_medium_x:
			velocity.y = jump_force
			set_state(State.AIR)
			return
		if dx <= overhead_x and abs(dy) <= above_y:
			set_state(State.ATTACK_UP)
			return
		if dx <= strong_x:
			set_state(State.ATTACK_STRONG)
			return
		return

	if chase_timer > 3.0 and abs(dy) < 50.0:
		set_state(State.DASH)
		return

	if dx <= side_attack_radius and abs(dy) < 50:
		set_state(State.ATTACK_SIDE)

func _handle_dash_logic(delta):
	dash_timer -= delta
	if _get_distance_to_player() < side_attack_radius:
		_set_facing(_get_direction_to_player())
		set_state(State.ATTACK_SIDE)
		return
	if dash_timer <= 0:
		_return_to_engagement_state()

func _handle_air_logic():
	if is_on_floor():
		_return_to_engagement_state()
		return

	var dir = _get_direction_to_player()
	var dx = _get_distance_to_player()
	var dy = player.global_position.y - global_position.y

	if dx <= side_attack_radius:
		set_state(State.ATTACK_SIDE)
		return
	if dx <= overhead_x and abs(dy) <= above_y and dy < 0:
		set_state(State.ATTACK_UP)
		return
	if dx <= overhead_x and abs(dy) <= below_y and dy > 0:
		set_state(State.ATTACK_DOWN)
		return

	_set_facing(dir)
	if velocity.y >= 0:
		set_state(State.DASH)
	else:
		velocity.x = dir * (move_speed * 0.75)

func _handle_attack_logic(anim_name: String, active_frame: int, shape: CollisionShape2D, lock_x: bool = false):
	_play_anim(anim_name)
	shape.disabled = (sprite.frame != active_frame)
	if lock_x: velocity.x = 0

func _handle_hurt_logic(delta):
	hurt_timer -= delta
	if hurt_timer <= 0.0:
		if randf() < 0.33:
			_set_facing(-_get_direction_to_player())
			set_state(State.DASH)
		else:
			_set_facing(_get_direction_to_player())
			_return_to_engagement_state()
			action_cooldown = 0.1

# ==============================================================================
# Helpers
# ==============================================================================

func _set_facing(new_facing):
	if new_facing == 0 or new_facing == facing: return
	facing = new_facing
	_apply_facing()

func _apply_facing():
	visual_root.scale.x = facing

func _get_direction_to_player() -> float:
	if not is_instance_valid(player): return 0.0
	return sign(player.global_position.x - global_position.x)

func _get_distance_to_player() -> float:
	if not is_instance_valid(player): return INF
	return abs(player.global_position.x - global_position.x)

func _disable_all_hitboxes():
	shape_side.disabled		= true
	shape_up.disabled		= true
	shape_strong.disabled	= true
	shape_down.disabled		= true

func _play_anim(anim_name):
	if sprite.animation != anim_name:
		sprite.play(anim_name)

func _return_to_engagement_state():
	action_cooldown = attack_cooldown
	_set_facing(_get_direction_to_player())
	set_state(State.CHASE)

# ==============================================================================
# Signals
# ==============================================================================

func _on_hurtbox_hit(attack_position: Vector2):
	if state == State.HURT or state == State.DEAD: return

	current_health -= 1
	var knockback_dir = sign(global_position.x - attack_position.x)
	if knockback_dir == 0: knockback_dir = -facing

	velocity = Vector2(knockback_dir * knockback_strength, -200)
	set_state(State.DEAD if current_health <= 0 else State.HURT)

func _on_hitbox_entered(area: Area2D):
	if area in targets_hit_this_attack: return
	if area.has_signal("player_hurt"):
		targets_hit_this_attack.append(area)
		area.player_hurt.emit(global_position)

func _on_anim_finished():
	if state in [State.ATTACK_SIDE, State.ATTACK_UP, State.ATTACK_STRONG, State.ATTACK_DOWN]:
		_return_to_engagement_state()
