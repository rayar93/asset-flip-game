extends Node

@onready var camera: Camera2D = get_tree().get_first_node_in_group("camera")

var trauma = 0.0
const DECAY = 1.0
const MAX_OFFSET = 12.0

func screenshake(amount: float = 0.5):
	trauma = min(trauma + amount, 1.0)
	
func _physics_process(delta):
	if not is_instance_valid(camera): return
	if trauma <= 0.0:
		camera.offset = Vector2.ZERO
		return
	trauma = max(trauma - DECAY * delta, 0.0)
	var shake = trauma * trauma
	camera.offset = Vector2(
		randf_range(-MAX_OFFSET, MAX_OFFSET) * shake,
		randf_range(-MAX_OFFSET, MAX_OFFSET) * shake
	)
