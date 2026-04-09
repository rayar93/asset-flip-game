extends BaseEnemy

@export_group("Movement")
@export var gravity = 1500.0
@export var move_speed = 180.0
@export var roll_speed = 600.0

@export_group("Combat")
@export var attack_cooldown = 0.7
@export var attack_radius = 90.0
@export var notice_radius = 500.0
@export var roll_cooldown = 2.5

@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D
@onready var hitbox: Area2D = $VisualRoot/Hitbox
@onready var hurtbox: Area2D = $VisualRoot/Hurtbox

@onready var shape_slash = $VisualRoot/Hitbox/ShapeSlash
@onready var shape_stab = $VisualRoot/Hitbox/ShapeStab
@onready var shape_down = $VisualRoot/Hitbox/ShapeDown

enum State {
	PRAY,
	STOP_PRAY,
	CHASE,
	SLASH,
	STAB,
	COMBO,
	ATTACK_DOWN,
	ROLL,
	HURT,
	DEAD
}

var state = State.PRAY
var action_cooldown = 0.0
var roll_cooldown_timer = 0.0
var roll_timer = 0.0
var targets_hit_this_attack: Array[Node2D] = []
var _descending_for_down_attack = false

# ==============================================================================
# BaseEnemy virtual overrides
# ==============================================================================

func _enemy_ready():
	hurtbox.enemy_hurt.connect(_on_hurtbox_hit)
	sprite.animation_finished.connect(_on_anim_finished)
	hitbox.area_entered.connect(_on_hitbox_entered)
	hitbox.monitoring = true
	_disable_all_hitboxes()
	_apply_facing()
	set_state(State.PRAY)

func _enemy_physics_process(delta):
	if roll_cooldown_timer > 0.0:
		roll_cooldown_timer -= delta
	
	if not is_on_floor():
		velocity.y += gravity * delta
		if _descending_for_down_attack:
			set_collision_mask_value(2, false)
			
	if _descending_for_down_attack and is_on_floor():
		_descending_for_down_attack = false
		set_collision_mask_value(2, true)
		_trigger_down_attack_impact()

	match state:
		State.PRAY:
			_handle_pray_logic()
		State.STOP_PRAY:
			pass
		State.CHASE:
			_handle_chase_logic(delta)
		State.SLASH, State.STAB, State.COMBO:
			_handle_attack_anim_logic()
		State.ATTACK_DOWN:
			_handle_down_attack_logic()
		State.ROLL:
			_handle_roll_logic(delta)
		State.HURT:
			pass
		
	move_and_slide()
	
func _apply_facing():
	visual_root.scale.x = facing
	
func _get_sprite():
	return sprite
	
func _on_hurt_finished():
	if roll_cooldown_timer <= 0.0 and randf() < 0.4:
		_set_facing(-int(_get_direction_to_player()))
		set_state(State.ROLL)
	else:
		_set_facing(int(_get_direction_to_player()))
		_return_to_chase()

# ==============================================================================
# State logic
# ==============================================================================

func set_state(new_state: State):
	if state == new_state: return

	if state in [State.SLASH, State.STAB, State.COMBO, State.ATTACK_DOWN]:
		action_cooldown = attack_cooldown

	_disable_all_hitboxes()
	targets_hit_this_attack.clear()
	state = new_state

	match state:
		State.PRAY:
			velocity.x = 0.0
			sprite.play("prayer")
		State.STOP_PRAY:
			sprite.play("stop_prayer")
		State.CHASE:
			pass
		State.SLASH:
			velocity.x = 0.0
			AudioManager.play("boss_attack")
			sprite.play("slash")
		State.STAB:
			velocity.x = 0
			AudioManager.play("boss_attack")
			sprite.play("stab")
		State.COMBO:
			velocity.x = 0
			AudioManager.play("boss_attack")
			_play_anim("combo")
		State.ATTACK_DOWN:
			velocity.x = 0
			velocity.y = -200
			_descending_for_down_attack = false
			sprite.play("jump")
		State.ROLL:
			roll_cooldown_timer = roll_cooldown
			AudioManager.play("boss_dash")
			sprite.play("roll")
		State.HURT:
			VFX.screenshake(0.4, 14.0)
			hurt_timer = hurt_duration
			sprite.play("hurt")
		State.DEAD:
			VFX.screenshake(0.8, 20.0)
			begin_death()
			GameFlow.on_boss_died()

func start_combat():
	if state == State.PRAY:
		set_state(State.STOP_PRAY)

func _handle_pray_logic():
	velocity.x = 0.0
	if _get_distance_to_player() <= notice_radius:
		set_state(State.STOP_PRAY)

func _handle_chase_logic(delta):
	if action_cooldown > 0.0:
		action_cooldown -= delta
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
		sprite.play("idle")
		return
		
	var dir = _get_direction_to_player()
	_set_facing(dir)
	velocity.x = dir * move_speed
	sprite.play("run")
	
	var dx = _get_distance_x_to_player()
	var dy = player.global_position.y - global_position.y
	
	if dy < -120 and dx < 60 and is_on_floor():
		set_state(State.ATTACK_DOWN)
		return
		
	if dx <= attack_radius and abs(dy) < 60.0:
		_choose_attack()

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

# ==============================================================================
# Helpers
# ==============================================================================

func _disable_all_hitboxes():
	shape_side.call_deferred("set_disabled", true)
	shape_up.call_deferred("set_disabled", true)
	shape_strong.call_deferred("set_disabled", true)
	shape_down.call_deferred("set_disabled", true)

func _return_to_engagement_state():
	action_cooldown = attack_cooldown
	_set_facing(_get_direction_to_player())
	set_state(State.CHASE)

# ==============================================================================
# Signals
# ==============================================================================

func _on_hurtbox_hit(attack_position: Vector2):
	if state == State.HURT or state == State.DEAD: return
	if _take_hit(attack_position):
		set_state(State.DEAD)
	else:
		set_state(State.HURT)

func _on_hitbox_entered(area: Area2D):
	if area in targets_hit_this_attack: return
	if area.has_signal("player_hurt"):
		targets_hit_this_attack.append(area)
		area.player_hurt.emit(global_position)
		AudioManager.play("boss_attack_connect")

func _on_anim_finished():
	if state in [State.ATTACK_SIDE, State.ATTACK_UP, State.ATTACK_STRONG, State.ATTACK_DOWN]:
		_return_to_engagement_state()
