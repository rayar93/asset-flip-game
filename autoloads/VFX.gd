extends Node

var trauma = 0.0
const DECAY = 1.0
var max_offset = 12.0
var base_offset = Vector2(0, -50)

var camera: Camera2D

func _ready():
	await get_tree().process_frame
	camera = get_tree().get_first_node_in_group("camera")
	print("VFX camera: ", camera)
	if is_instance_valid(camera):
		base_offset = camera.offset
		print("camera: ", base_offset)

func screenshake(amount: float = 0.5, m_offset = 12.0):
	print("Screenshake: ", camera)
	trauma = min(trauma + amount, 1.0)
	max_offset = m_offset
	
func _physics_process(delta):
	if not is_instance_valid(camera):
		camera = get_tree().get_first_node_in_group("camera")
		if is_instance_valid(camera):
			base_offset = camera.offset
		return
	if trauma <= 0.0:
		camera.offset = base_offset
		return
	trauma = max(trauma - DECAY * delta, 0.0)
	var shake = trauma * trauma
	camera.offset = base_offset + Vector2(
		randf_range(-max_offset, max_offset) * shake,
		randf_range(-max_offset, max_offset) * shake
	)
