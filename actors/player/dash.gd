extends Node2D

func play():
	if has_method("reset_physics_interpolation"):
		reset_physics_interpolation()
	$AnimatedSprite2D.play()
	$AnimatedSprite2D.animation_finished.connect(queue_free)
