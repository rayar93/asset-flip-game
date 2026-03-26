extends GPUParticles2D

func _process(_delta):
	var cam = get_viewport().get_camera_2d()
	if cam:
		global_position = cam.global_position
