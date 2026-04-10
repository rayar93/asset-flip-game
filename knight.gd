extends BaseEnemy

@export_group("Movement")
@export var gravity = 1500.0
@export var move_speed = 180.0
@export var roll_speed = 600.0

@export_group("Combat")
@export var attack_cooldown = 0.7
@export var attack_radius = 50.0
@export var notice_radius = 300.0
@export var roll_cooldown = 2.5
@export var jump_force = -700
@export var plunge_min_x = 120.0
@export var plunge_max_x = 300.0
@export var plunge_cooldown = 4.0

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
	AIR,
	ATTACK_DOWN,
	ROLL,
	HURT,
	DEAD
}

var state = State.PRAY
var action_cooldown = 0.0
var roll_cooldown_timer = 0.0
var plunge_cooldown_timer = 0.0
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
	
	if plunge_cooldown_timer > 0.0:
		plunge_cooldown_timer -= delta
	
	if not is_on_floor():
		velocity.y += gravity * delta
		if _descending_for_down_attack:
			set_collision_mask_value(2, false)
			
	if _descending_for_down_attack and is_on_floor():
		_descending_for_down_attack = false
		_trigger_down_attack_impact()

	match state:
		State.PRAY:
			_handle_pray_logic()
		State.STOP_PRAY:
			pass
		State.CHASE:
			_handle_chase_logic(delta)
		State.SLASH, State.STAB, State.COMBO:
			velocity.x = 0.0
		State.AIR:
			_handle_air_logic()
		State.ATTACK_DOWN:
			_handle_down_attack_logic()
		State.ROLL:
			_handle_roll_logic()
		State.HURT:
			pass
		
	move_and_slide()
	
func _apply_facing():
	visual_root.scale.x = facing
	
func _get_sprite():
	return sprite
	
func _on_hurt_finished():
	if state == State.DEAD: return
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
			velocity.x = 0.0
			sprite.play("stop_prayer")
		State.CHASE:
			pass
		State.SLASH:
			velocity.x = 0.0
			sprite.play("slash")
		State.STAB:
			velocity.x = 0
			sprite.play("stab")
		State.COMBO:
			velocity.x = 0
			_play_anim("combo")
		State.AIR:
			velocity.y = jump_force
			var dir = _get_direction_to_player()
			velocity.x = dir * move_speed * 2
			sprite.play("jump")
		State.ATTACK_DOWN:
			velocity.x = 0
			velocity.y = -200
			_descending_for_down_attack = false
			sprite.play("jump")
		State.ROLL:
			roll_cooldown_timer = roll_cooldown
			AudioManager.play("boss_dash")
			velocity.x = facing * roll_speed
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
	
	if plunge_cooldown_timer <= 0.0 and is_on_floor():
		if dx >= plunge_min_x and dx <= plunge_max_x:
			if randf() < 0.02:
				set_state(State.AIR)
				return
	
	if dx <= attack_radius and abs(dy) < 60.0:
		_choose_attack()
		
func _handle_air_logic():
	if velocity.y < 0:
		sprite.play("jump")
		var dir = _get_direction_to_player()
		velocity.x = move_toward(velocity.x, dir * move_speed *1.5, 400. * get_physics_process_delta_time())
		return
		
	if not _descending_for_down_attack:
		_descending_for_down_attack = true
		state = State.ATTACK_DOWN
		velocity.y = 0
		velocity.x = 0
		sprite.play("fall")
		await get_tree().create_timer(0.2).timeout
		if state == State.ATTACK_DOWN:
			velocity.y = 1400.0
			set_collision_mask_value(2, false)
			plunge_cooldown_timer = plunge_cooldown

func _choose_attack():
	var roll = randf()
	if roll < 0.35:
		set_state(State.SLASH)
	elif roll < 0.70:
		set_state(State.STAB)
	else:
		set_state(State.COMBO)
		
func _handle_down_attack_logic():
	if velocity.y < 0:
		sprite.play("jump")
		return
	if not _descending_for_down_attack:
		_descending_for_down_attack = true
		velocity.y = 600.0
		set_collision_mask_value(2, false)
		sprite.play("fall")

func _trigger_down_attack_impact():
	_descending_for_down_attack = false
	velocity.x = 0
	sprite.play("attack_down")
	shape_down.call_deferred("set_disabled", false)
	AudioManager.play("boss_attack")
	VFX.screenshake(0.3, 10.0)
	
func _handle_roll_logic():
	velocity.x = facing * roll_speed

# ==============================================================================
# Helpers
# ==============================================================================

func _disable_all_hitboxes():
	shape_slash.call_deferred("set_disabled", true)
	shape_stab.call_deferred("set_disabled", true)
	shape_down.call_deferred("set_disabled", true)

func _return_to_chase():
	set_collision_mask_value(2, true)
	_set_facing(_get_direction_to_player())
	state = State.CHASE

# ==============================================================================
# Signals
# ==============================================================================

func _on_frame_changed():
	match state:
		State.AIR:
			if sprite.animation == "fall" and sprite.frame == 2:
				if not is_on_floor():
					sprite.pause()
		State.SLASH:
			shape_slash.disabled = sprite.frame not in [3, 7]
			if sprite.frame in [3, 7]:
				AudioManager.play("boss_attack")
		State.STAB:
			shape_stab.disabled = (sprite.frame not in [1, 2, 3, 4])
			shape_slash.disabled = (sprite.frame not in [7, 8])
			if sprite.frame in [1, 7]:
				AudioManager.play("boss_attack")
		State.COMBO:
			shape_slash.disabled = sprite.frame not in [3, 7, 16, 17]
			shape_stab.disabled = sprite.frame not in [10, 11, 12, 13]
			if sprite.frame in [3, 7, 10, 16]:
				AudioManager.play("boss_attack")
		State.ATTACK_DOWN:
			if sprite.animation == "fall" and sprite.frame == 2:
				if not is_on_floor():
					sprite.pause()

func _on_hurtbox_hit(attack_position: Vector2):
	if state == State.HURT or state == State.DEAD: return
	if state == State.ROLL: return
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
	match state:
		State.STOP_PRAY, State.SLASH, State.STAB, State.COMBO, State.ATTACK_DOWN:
			shape_down.disabled = true
			_return_to_chase()
		State.ROLL:
			velocity.x = 0.0
			_set_facing(int(_get_direction_to_player()))
			_return_to_chase()
