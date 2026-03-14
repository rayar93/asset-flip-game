extends BaseEnemy

@export_group("Movement")
@export var gravity = 2000
@export var move_speed = 100

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var hurtbox: Area2D = $Hurtbox

enum State { PATROL, HURT, DEAD }
var state = State.PATROL

# ==============================================================================
# BaseEnemy virtual overrides
# ==============================================================================

func _enemy_ready():
	hurtbox.enemy_hurt.connect(_on_hurtbox_hit)
	hitbox.area_entered.connect(_on_hitbox_entered)

	sprite.play("default")
	set_state(State.PATROL)

func _enemy_physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	match state:
		State.PATROL:	_handle_patrol_logic(delta)

	move_and_slide()
	if state == State.PATROL:
		_check_wall_flip()
		
func _apply_facing():
	sprite.flip_h = (facing == -1)
	
func _get_sprite():
	return sprite
	
func _on_hurt_finished():
	set_state(State.PATROL)

# ==============================================================================
# State logic
# ==============================================================================

func set_state(new_state: State):
	if state == new_state: return

	state = new_state

	match state:
		State.PATROL:
			hitbox.monitoring = true
		State.HURT:
			hurt_timer = hurt_duration
			hitbox.monitoring = false
		State.DEAD:
			AudioManager.play("enemy_death")
			queue_free()

func _handle_patrol_logic(delta):
	velocity.x = move_toward(
		velocity.x,
		facing * move_speed,
		1000 * delta
	)

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var normal = collision.get_normal()

		if abs(normal.x) > 0.9 and sign(normal.x) == -facing:
			_set_facing(-facing)
			break

# ==============================================================================
# Helpers
# ==============================================================================
	
func _check_wall_flip():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var normal = collision.get_normal()
	
		if abs(normal.x) > 0.9 and sign(normal.x) == -facing:
			_set_facing(-facing)
			break

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
	if state == State.DEAD: return
	
	if area.has_signal("player_hurt"):
		area.player_hurt.emit(global_position)
