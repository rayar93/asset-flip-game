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
var targets_hit_this_attack: Array[Node2D] = []

# ==============================================================================
# BaseEnemy virtual overrides
# ==============================================================================

func _enemy_ready():
	hurtbox.enemy_hurt.connect(_on_hurtbox_hit)
	hitbox.area_entered.connect(_on_hitbox_entered)
	hitbox.area_exited.connect(_on_hitbox_exited)
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
			pass

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
			ScoreManager.add_score(50)
			begin_death()
			
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
		if body is BaseEnemy and body.state == body.State.DEAD: continue
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
	set_state(State.DEAD)
	
func _on_hitbox_entered(area: Area2D):
	if state == State.DEAD: return
	if area in targets_hit_this_attack: return
	if area.has_signal("player_hurt"):
		targets_hit_this_attack.append(area)
		area.player_hurt.emit(global_position)

func _on_hitbox_exited(area: Area2D):
	targets_hit_this_attack.erase(area)
