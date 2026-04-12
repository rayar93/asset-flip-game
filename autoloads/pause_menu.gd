extends CanvasLayer

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event):
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if not GameFlow.is_gameplay_scene():
			return
		if get_tree().paused:
			resume()
		else:
			pause()
		
func pause():
	show()
	get_tree().paused = true
	
func resume():
	hide()
	get_tree().paused = false
	
func _on_resume_pressed():
	resume()
	
func _on_restart_pressed():
	get_tree().paused = false
	GameFlow.go_to_scene(GameFlow.current_level_path)
	
func _on_menu_pressed():
	GameFlow.go_to_scene("res://Main_Menu.tscn")
	
func _on_quit_pressed():
	get_tree().paused = false
	get_tree().quit()
