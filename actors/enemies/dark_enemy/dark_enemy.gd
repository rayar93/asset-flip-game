extends BaseEnemy

@export_group("Movement")
@export var gravity = 2000
@export var move_speed = 100

@export_group("Combat")
@export var notice_radius = 200
@export var attack_radius = 100
@export var attack_cooldown = 1.0

@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var hurtbox: Area2D = $Hurtbox
@onready var contact_hitbox: Area2D = $ContactHitbox

@onready var visual_base_x: float = visual_root.position.x
@onready var hitbox_base_x: float = hitbox.position.x

enum State { IDLE, CHASE, ATTACK, HURT, DEAD }
var state = State.IDLE
var attack_cooldown_timer = 0.0

var attack_hit_frame = 2
var targets_hit_this_attack: Array[Node2D] = []

# ==============================================================================
# BaseEnemy virtual overrides
# ==============================================================================

func _enemy_ready():
	hurtbox.enemy_hurt.connect(_on_hurtbox_hit)
	sprite.animation_finished.connect(_on_anim_finished)
	hitbox.area_entered.connect(_on_hitbox_entered)
	contact_hitbox.area_entered.connect(_on_contact_hitbox_entered)

	_set_hitbox_active(false)
	_apply_facing()
	sprite.play("idle")
	set_state(State.IDLE)

func _enemy_physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
		
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

	match state:
		State.IDLE:    _handle_idle_logic()
		State.CHASE:   _handle_chase_logic()
		State.ATTACK:  _handle_attack_logic()

	move_and_slide()
	
func _apply_facing():
	sprite.flip_h = (facing == -1)
	visual_root.position.x = visual_base_x * facing
	hitbox.position.x = hitbox_base_x * facing
	
func _get_sprite():
	return sprite
	
func _on_hurt_finished():
	set_state(State.CHASE if _get_distance_to_player() <= notice_radius else State.IDLE)

# ==============================================================================
# State logic
# ==============================================================================

func set_state(new_state: State):
	if state == new_state: return

	if state == State.ATTACK:
		attack_cooldown_timer = attack_cooldown

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
			AudioManager.play("enemy_death")
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
	if sprite.frame == attack_hit_frame:
		AudioManager.play("enemy_attack")

# ==============================================================================
# Helpers
# ==============================================================================

func _set_hitbox_active(active):
	hitbox.set_deferred("monitoring", active)
	hitbox.set_deferred("monitorable", active)

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
		set_state(State.CHASE if _get_distance_to_player() <= notice_radius else State.IDLE)

func _on_contact_hitbox_entered(area: Area2D):
	if state == State.DEAD: return
	if area.name == "PlayerHurtbox":
		area.player_hurt.emit(global_position)
