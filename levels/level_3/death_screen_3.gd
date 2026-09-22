extends Control

func _on_continue_pressed():
	GameFlow.go_to_scene("res://levels/level_3/level_3.tscn")

func _on_restart_pressed():
	GameFlow.go_to_scene("res://levels/level_1/level_1.tscn")
	
func _on_menu_pressed():
	GameFlow.go_to_scene("res://UI/main_menu.tscn")
	
func _on_exit_pressed():
	get_tree().quit()
