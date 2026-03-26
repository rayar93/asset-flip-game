extends Control

func _on_continue_pressed():
	GameFlow.go_to_scene("res://levels/level_1/level_1_demo.tscn")
	
func _on_menu_pressed():
	GameFlow.go_to_scene("res://Main_Menu.tscn")
	
func _on_exit_pressed():
	get_tree().quit()
