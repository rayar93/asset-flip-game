extends CharacterBody2D

@export_group("Movement")
@export var gravity = 2000
@export var move_speed = 100

@export_group("Combat")
@export var hurt_duration = 0.2
@export var knockback_strength = 400
@export var max_health = 2

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var hurtbox: Area2D = $Hurtbox

enum State { PATROL, HURT, DEAD }
var state = State.PATROL
var facing = 1
var current_health = max_health
var hurt_timer = 0.0

# ==============================================================================
# Engine callbacks
# ==============================================================================

func _ready():
	hurtbox.enemy_hurt.connect(_on_hurtbox_hit)
	hitbox.area_entered.connect(_on_hitbox_entered)

	sprite.play("default")
	set_state(State.PATROL)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	match state:
		State.PATROL:	_handle_patrol_logic(delta)
		State.HURT:    	_handle_hurt_logic(delta)

	move_and_slide()
	if state == State.PATROL:
		_check_wall_flip()

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

		# Wall normal pointing opposite of movement
		if abs(normal.x) > 0.9 and sign(normal.x) == -facing:
			_set_facing(-facing)
			break

func _handle_hurt_logic(delta):
	hurt_timer -= delta
	if hurt_timer <= 0.0:
		set_state(State.PATROL)

# ==============================================================================
# Helpers
# ==============================================================================

func _set_facing(new_facing):
	if new_facing == 0 or new_facing == facing: return
	facing = new_facing
	sprite.flip_h = (facing == -1)
	
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

	current_health -= 1
	var knockback_dir = sign(global_position.x - attack_position.x)
	if knockback_dir == 0: knockback_dir = -facing

	velocity = Vector2(knockback_dir * knockback_strength, -200)
	set_state(State.DEAD if current_health <= 0 else State.HURT)

func _on_hitbox_entered(area: Area2D):
	if state == State.DEAD: return
	
	if area.has_signal("player_hurt"):
		area.player_hurt.emit(global_position)
