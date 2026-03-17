extends Parallax2D

func _process(delta: float) -> void:
	var cam = get_viewport().get_camera_2d()
	scroll_offset.y = -cam.global_position.y
