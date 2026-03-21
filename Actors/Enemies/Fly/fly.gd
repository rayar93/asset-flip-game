extends BaseEnemy

@export_group("Movement")
@export var friction = 500
@export var move_speed = 120

@export_group("Combat")
@export var notice_radius = 250

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var hurtbox: Area2D = $Hurtbox

enum State { IDLE, CHASE, DEAD }
var state = State.IDLE

# ==============================================================================
# BaseEnemy virtual overrides
# ==============================================================================

func _enemy_ready():
	hurtbox.enemy_hurt.connect(_on_hurtbox_hit)
	hitbox.area_entered.connect(_on_hitbox_entered)
	sprite.animation_finished.connect(_on_anim_finished)

	sprite.play("default")
	set_state(State.IDLE)

func _enemy_physics_process(delta):
	match state:
		State.IDLE:
			_handle_idle_logic()
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		State.CHASE:
			_handle_chase_logic(delta)
		State.DEAD:
			velocity.y += 1000 * delta
			velocity.x = move_toward(velocity.x, 0, friction * 0.5 * delta)

	move_and_slide()
	
func _get_sprite():
	return sprite

# ==============================================================================
# State logic
# ==============================================================================

func set_state(new_state: State):
	if state == new_state: return
	state = new_state

	match state:
		State.DEAD:
			hitbox.set_deferred("monitoring", false)
			hitbox.set_deferred("monitorable", false)
			hurtbox.set_deferred("monitoring", false)
			hurtbox.set_deferred("monitorable", false)
			sprite.play("death")
			
func _handle_idle_logic():
	if _get_distance_to_player() <= notice_radius:
		set_state(State.CHASE)

func _handle_chase_logic(delta):
	if not is_instance_valid(player): return
	
	if _get_distance_to_player() > notice_radius + 50:
		set_state(State.IDLE)
		return
		
	var dir = global_position.direction_to(player.global_position)
	
	var separation = Vector2.ZERO
	for body in $SeparationArea.get_overlapping_bodies():
		if body == self: continue
		var away = global_position - body.global_position
		if away.length() > 0:
			separation += away.normalized() / away.length()
			
	dir = (dir + separation * 1.5).normalized()
	
	velocity = velocity.move_toward(dir * move_speed, friction * delta)
	
	if dir.x != 0:
		sprite.flip_h = (dir.x < 0)

# ==============================================================================
# Signals
# ==============================================================================

func _on_hurtbox_hit(attack_position: Vector2):
	if state == State.DEAD: return
	
	var knockback_dir = (global_position - attack_position).normalized()
	velocity = knockback_dir * knockback_strength
	AudioManager.play("enemy_death")
	set_state(State.DEAD)
	
func _on_hitbox_entered(area: Area2D):
	if state == State.DEAD: return
	
	if area.has_signal("player_hurt"):
		area.player_hurt.emit(global_position)

func _on_anim_finished():
	if sprite.animation == "death":
		queue_free()
