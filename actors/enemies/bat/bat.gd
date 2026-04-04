extends BaseEnemy

@export_group("Movement")
@export var friction = 500
@export var move_speed = 120
@export var lunge_speed = 400
@export_group("Combat")
@export var notice_radius = 250
@export var attack_radius = 80
@onready var sprite = $AnimatedSprite2D
@onready var hitbox = $Hitbox
@onready var hurtbox = $Hurtbox
enum State { SLEEP, CHASE, ATTACK, HURT, DEAD }
var state = State.SLEEP

# ==============================================================================
# BaseEnemy virtual overrides
# ==============================================================================

func _enemy_ready():
	hurtbox.enemy_hurt.connect(_on_hurtbox_hit)
	hitbox.area_entered.connect(_on_hitbox_entered)
	sprite.animation_finished.connect(_on_anim_finished)
	sprite.play("sleeping")
	set_state(State.SLEEP)
	
func _enemy_physics_process(delta):
	match state:
		State.SLEEP:
			_handle_sleep_logic()
			velocity = Vector2.ZERO
		State.CHASE:
			_handle_chase_logic(delta)
		State.ATTACK:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		State.HURT:
			pass
		State.DEAD:
			pass
	move_and_slide()
	
func _apply_facing():
	sprite.flip_h = (facing == -1)
	
func _get_sprite():
	return sprite
	
func _on_hurt_finished():
	if state == State.DEAD: return
	set_state(State.CHASE)
	
# ==============================================================================
# State logic
# ==============================================================================

func set_state(new_state: State):
	if state == new_state: return
	if state == State.DEAD: return
	state = new_state
	match state:
		State.SLEEP:
			sprite.play("sleeping")
			hitbox.set_deferred("monitoring", false)
		State.CHASE:
			sprite.play("flying")
			hitbox.set_deferred("monitoring", true)
		State.ATTACK:
			sprite.play("attacking")
			hitbox.set_deferred("monitoring", true)
			if is_instance_valid(player):
				var dir = global_position.direction_to(player.global_position)
				velocity = dir * lunge_speed
				sprite.flip_h = (dir.x < 0)
		State.HURT:
			hurt_timer = hurt_duration
			sprite.play("hurt")
			hitbox.set_deferred("monitoring", false)
		State.DEAD:
			begin_death()
		
func _handle_sleep_logic():
	if _get_distance_to_player() <= notice_radius:
		set_state(State.CHASE)
		
func _handle_chase_logic(delta):
	if not is_instance_valid(player): return
	
	if _get_distance_to_player() <= attack_radius:
		set_state(State.ATTACK)
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
	if state == State.HURT or state == State.DEAD: return
	if _take_hit(attack_position):
		set_state(State.DEAD)
	else:
		velocity.y = 0
		set_state(State.HURT)
	
func _on_hitbox_entered(area: Area2D):
	if state == State.DEAD: return
	if area.has_signal("player_hurt"):
		area.player_hurt.emit(global_position)
		
func _on_anim_finished():
	match sprite.animation:
		"attacking":
			set_state(State.CHASE)
