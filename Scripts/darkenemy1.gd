extends CharacterBody2D

@export_group("Movement")
@export var gravity = 2000
@export var move_speed = 100

@export_group("Combat")
@export var notice_radius = 200
@export var attack_radius = 100
@export var hurt_duration = 0.2
@export var knockback_strength = 250
@export var max_health = 3

@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var hurtbox: Area2D = $Hurtbox
@onready var contact_hitbox: Area2D = $ContactHitbox

@onready var visual_base_x: float = visual_root.position.x
@onready var hitbox_base_x: float = hitbox.position.x

enum State { IDLE, CHASE, ATTACK, HURT, DEAD }
var state = State.IDLE
var facing = 1
var current_health = max_health
var hurt_timer = 0.0
var attack_cooldown = 0.4
var attack_cooldown_timer = 0.0

var player: Node2D = null
var attack_hit_frame = 2
var targets_hit_this_attack: Array[Node2D] = []

# ==============================================================================
# Engine callbacks
# ==============================================================================

func _ready():
	player = get_tree().get_first_node_in_group("player") as Node2D

	hurtbox.enemy_hurt.connect(_on_hurtbox_hit)
	sprite.animation_finished.connect(_on_anim_finished)
	hitbox.area_entered.connect(_on_hitbox_entered)
	contact_hitbox.area_entered.connect(_on_contact_hitbox_entered)

	_set_hitbox_active(false)
	_apply_facing()
	sprite.play("idle")
	set_state(State.IDLE)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
		
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

	match state:
		State.IDLE:    _handle_idle_logic()
		State.CHASE:   _handle_chase_logic()
		State.ATTACK:  _handle_attack_logic()
		State.HURT:    _handle_hurt_logic(delta)

	move_and_slide()

# ==============================================================================
# State logic
# ==============================================================================

func set_state(new_state: State):
	if state == new_state: return

	_set_hitbox_active(false)
	targets_hit_this_attack.clear()
	state = new_state

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
			_play_anim("hurt")
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

	if dist <= attack_radius and attack_cooldown_timer <= 0:
		set_state(State.ATTACK)
		return

	var dir = _get_direction_to_player()
	if dir == 0:
		velocity.x = 0
		_play_anim("idle")
		return

	_set_facing(dir)
	velocity.x = dir * move_speed
	_play_anim("walk")

func _handle_attack_logic():
	_set_hitbox_active(sprite.frame == attack_hit_frame)

func _handle_hurt_logic(delta):
	hurt_timer -= delta
	if hurt_timer <= 0.0:
		_return_to_engagement_state()

# ==============================================================================
# Helpers
# ==============================================================================

func _set_facing(new_facing):
	if new_facing == 0 or new_facing == facing: return
	facing = new_facing
	_apply_facing()

func _apply_facing():
	sprite.flip_h = (facing == -1)
	visual_root.position.x = visual_base_x * facing
	hitbox.position.x = hitbox_base_x * facing

func _get_distance_to_player() -> float:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return INF
	return global_position.distance_to(player.global_position)

func _get_direction_to_player() -> float:
	if not is_instance_valid(player): return 0.0
	var x_diff = player.global_position.x - global_position.x
	if abs(x_diff) < 8.0:
		return 0.0
	return sign(x_diff)

func _set_hitbox_active(active):
	hitbox.monitoring = active
	hitbox.monitorable = active

func _play_anim(anim_name):
	if sprite.animation != anim_name:
		sprite.play(anim_name)

func _return_to_engagement_state():
	set_state(State.CHASE if _get_distance_to_player() <= notice_radius else State.IDLE)

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
	
	if area.is_in_group("player_attack"):
		targets_hit_this_attack.append(area)
		var knockback_dir = sign(global_position.x - area.global_position.x)
		if knockback_dir == 0: knockback_dir = -facing
		velocity = Vector2(knockback_dir * 400, -250)
		set_state(State.HURT)
		return
	
	if area.has_signal("player_hurt"):
		targets_hit_this_attack.append(area)
		area.player_hurt.emit(global_position)

func _on_anim_finished():
	if state == State.ATTACK:
		attack_cooldown_timer = attack_cooldown
		_return_to_engagement_state()

func _on_contact_hitbox_entered(area: Area2D):
	if state == State.DEAD: return
	if area.name == "PlayerHurtbox":
		area.player_hurt.emit(global_position)
