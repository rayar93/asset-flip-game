extends BaseEnemy

@export_group("Movement")
@export var friction = 600
@export var move_speed = 100

@export_group("Combat")
@export var notice_radius = 280
@export var attack_radius = 180
@export var attack_cooldown = 2.0
@export var projectile_speed = 220.0

@onready var visual_root = $VisualRoot
@onready var sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D
@onready var hurtbox: Area2D = $VisualRoot/Hurtbox
@onready var projectile_spawn: Marker2D = $VisualRoot/ProjectileSpawn
@onready var hitbox: Area2D = $VisualRoot/Hitbox

enum State { IDLE, FLY, ATTACK, HURT, DEAD }
var state = State.IDLE
var attack_cooldown_timer = 0.0
var projectile_spawned_this_attack = false
const PROJECTILE = preload("res://actors/enemies/demon/fireball.tscn")

var attack_spawn_frame = 5

# ==============================================================================
# BaseEnemy virtual overrides
# ==============================================================================

func _enemy_ready():
	hurtbox.enemy_hurt.connect(_on_hurtbox_hit)
	sprite.animation_finished.connect(_on_anim_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	hitbox.area_entered.connect(_on_hitbox_entered)
	_apply_facing()
	sprite.play("idle")
	set_state(State.IDLE)
	
func _enemy_physics_process(delta):
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
		
	match state:
		State.IDLE:
			_handle_idle_logic()
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		State.FLY:
			_handle_fly_logic(delta)

	move_and_slide()
	
func _apply_facing():
	if visual_root:
		visual_root.scale.x = -facing
		
func _get_sprite():
	return sprite
	
func _on_hurt_finished():
	set_state(State.FLY if _get_distance_to_player() <= notice_radius else State.IDLE)
	
# ==============================================================================
# State logic
# ==============================================================================

func set_state(new_state: State):
	if state == new_state: return
	
	if state == State.ATTACK:
		attack_cooldown_timer = attack_cooldown
		
	state = new_state
	projectile_spawned_this_attack = false
	
	match state:
		State.IDLE:
			_play_anim("idle")
		State.FLY:
			_play_anim("fly")
		State.ATTACK:
			velocity = Vector2.ZERO
			_play_anim("attack")
		State.HURT:
			hurt_timer = hurt_duration
			_play_anim("hurt")
		State.DEAD:
			ScoreManager.add_score(200)
			begin_death()

func _handle_idle_logic():
	if _get_distance_to_player() <= notice_radius:
		set_state(State.FLY)
		
func _handle_fly_logic(delta):
	if not is_instance_valid(player): return
	
	var distance = _get_distance_to_player()
	
	if distance > notice_radius + 50:
		set_state(State.IDLE)
		return
		
	if distance <= attack_radius and attack_cooldown_timer <= 0:
		set_state(State.ATTACK)
		return
		
	var dir = global_position.direction_to(player.global_position)
	velocity = velocity.move_toward(dir * move_speed, friction * delta)
	
	if dir.x != 0:
		_set_facing(int(sign(dir.x)))
		
# ==============================================================================
# Projectile
# ==============================================================================

func _spawn_projectile():
	var proj = PROJECTILE.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = projectile_spawn.global_position
	
	var dir = (player.global_position - projectile_spawn.global_position).normalized()
	proj.launch(dir, projectile_speed)
	AudioManager.play("fireball_launch")
	
# ==============================================================================
# Signals
# ==============================================================================

func _on_frame_changed():
	if state == State.ATTACK and not projectile_spawned_this_attack:
		if sprite.frame == attack_spawn_frame:
			projectile_spawned_this_attack = true
			_spawn_projectile()
			
func _on_anim_finished():
	match state:
		State.ATTACK:
			set_state(State.FLY if _get_distance_to_player() <= notice_radius else State.IDLE)
			
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
