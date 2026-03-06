extends Node

@onready var camera: Camera2D = get_tree().get_first_node_in_group("camera")

func screenshake(duration: float = 0.2, strength: float = 8.0):
	if not is_instance_valid(camera): return
	var tween = create_tween()
	var elapsed = 0.0
	var step = 0.02
	var original = camera.offset
	while elapsed < duration:
		var progress = elapsed / duration
		var current_strength = strength * (1.0 - progress)
		
		var offset = Vector2(
			randf_range(-current_strength, current_strength),
			randf_range(-current_strength, current_strength)
		)
		tween.tween_property(camera, "offset", offset, step)
		elapsed += step
	tween.tween_property(camera, "offset", original, step)
