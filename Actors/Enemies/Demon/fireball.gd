extends Area2D

@export var velocity = Vector2.ZERO
@export var lifetime = 4.0
var _lifetime_timer = 0.0
var _has_hit = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func launch(direction: Vector2, speed: float):
	velocity = direction * speed
	rotation = direction.angle()
	sprite.play("default")
	
func _physics_process(delta: float) -> void:
	_lifetime_timer += delta
	if _lifetime_timer >= lifetime:
		queue_free()
		return
	position += velocity * delta
	
func _on_area_entered(area: Area2D):
	if _has_hit: return
	
	if area.has_signal("player_hurt"):
		_has_hit = true
		area.player_hurt.emit(global_position)
		_on_hit()
		
func _on_body_entered(body: Node2D):
	if _has_hit: return
	if body == get_tree().get_first_node_in_group("player"): return
	_has_hit = true
	_on_hit()
	
func _on_hit():
	queue_free()
