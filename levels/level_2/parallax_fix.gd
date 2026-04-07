extends Parallax2D

var base_offset_y = 0.0

func _ready():
	await get_tree().process_frame
	var cam = get_viewport().get_camera_2d()
	if cam:
		base_offset_y = cam.offset.y

func _process(_delta: float) -> void:
	var cam = get_viewport().get_camera_2d()
	if not cam: return
	scroll_offset.y = -(cam.global_position.y + base_offset_y)
