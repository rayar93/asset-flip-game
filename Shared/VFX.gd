extends Node

@onready var camera: Camera2D = get_tree().get_first_node_in_group("camera")

var trauma = 0.0
const DECAY = 1.0
const MAX_OFFSET = 12.0
var base_offset = Vector2(0, -50)

func _ready():
	await get_tree().process_frame
	if is_instance_valid(camera):
		base_offset = camera.offset
		print("camera: ", base_offset)

func screenshake(amount: float = 0.5):
	trauma = min(trauma + amount, 1.0)
	
func _physics_process(delta):
	if not is_instance_valid(camera): return
	if trauma <= 0.0:
		camera.offset = base_offset
		return
	trauma = max(trauma - DECAY * delta, 0.0)
	var shake = trauma * trauma
	camera.offset = base_offset + Vector2(
		randf_range(-MAX_OFFSET, MAX_OFFSET) * shake,
		randf_range(-MAX_OFFSET, MAX_OFFSET) * shake
	)
