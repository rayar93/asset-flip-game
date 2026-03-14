class_name BaseEnemy
extends CharacterBody2D

@export_group("Combat")
@export var max_health = 3
@export var knockback_strength = 250
@export var hurt_duration = 0.2

var current_health: int
var hurt_timer = 0.0
var facing = 1

var player: Node2D = null

# ==============================================================================
# Engine callbacks
# ==============================================================================

func _ready() -> void:
	current_health = max_health
	player = get_tree().get_first_node_in_group("player") as Node2D
	_enemy_ready()

func _physics_process(delta: float) -> void:
	_tick_hurt_timer(delta)
	_enemy_physics_process(delta)
	
# ==============================================================================
# Virtual hooks - overridden in each enemy
# ==============================================================================

func _enemy_ready():
	pass
	
func _enemy_physics_process(_delta):
	pass
	
func _on_hurt_finished():
	pass
	
func _apply_facing():
	pass
	
# ==============================================================================
# Shared helpers
# ==============================================================================

func _get_distance_to_player():
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
		return INF
	return global_position.distance_to(player.global_position)
	
func _get_distance_x_to_player():
	if not is_instance_valid(player): return INF
	return abs(player.global_position.x - global_position.x)
	
func _get_direction_to_player():
	if not is_instance_valid(player): return 0.0
	var x_diff = player.global_position.x - global_position.x
	if abs(x_diff) < 8.0: return 0.0
	return sign(x_diff)
	
func _set_facing(new_facing: int):
	if new_facing == 0 or new_facing == facing: return
	facing = new_facing
	_apply_facing()
	
func _play_anim(anim_name: String):
	var sprite = _get_sprite()
	if sprite and sprite.animation != anim_name:
		sprite.play(anim_name)
		
func _get_sprite():
	return null
	
func _take_hit(attack_position: Vector2):
	AudioManager.play("enemy_hurt")
	current_health -= 1
	var knockback_dir = sign(global_position.x - attack_position.x)
	if knockback_dir == 0:
		knockback_dir = -facing
	velocity = Vector2(knockback_dir * knockback_strength, -200)
	return current_health <= 0
	
func _tick_hurt_timer(delta):
	if hurt_timer > 0.0:
		hurt_timer -= delta
		if hurt_timer <= 0.0:
			_on_hurt_finished()
