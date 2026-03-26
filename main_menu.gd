extends Control

func _on_start_pressed():
	GameFlow.go_to_scene("res://levels/level_1/level_1_demo.tscn")
	
func _on_options_pressed():
	pass
	
func _on_exit_pressed():
	get_tree().quit()
