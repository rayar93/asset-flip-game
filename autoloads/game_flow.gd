extends Node

signal player_died
signal boss_died

var _overlay: ColorRect
var _canvas: CanvasLayer
var _is_transitioning = false

var current_level_path = ""

const FADE_DURATION = 0.4

func _ready():
	_canvas = CanvasLayer.new()
	_canvas.layer = 100
	add_child(_canvas)
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_overlay)
	
	await get_tree().process_frame
	var initial_path = get_tree().current_scene.scene_file_path
	current_level_path = initial_path
	_update_music_for_path(initial_path)
	
func _update_music_for_path(path: String):
	if "tutorial" in path or "main_menu" in path:
		AudioManager.play_music(preload("res://audio/music/SunnyLand Music/SunnyLand Music/Adventure pack 1 ogg/arcade.ogg"))
	elif "level_1" in path or "death_screen1" in path:
		AudioManager.play_music(preload("res://audio/music/SunnyLand Music/SunnyLand Music/adventure pack 2 ogg/megabot.ogg"))
	elif "level_2" in path or "death_screen2" in path:
		AudioManager.play_music(preload("res://audio/music/Lost(loop) - drone - dark.mp3"))
		AudioManager.play_ambient(preload("res://audio/SFX/Ambient/BGS Loops/Cave/Cave.wav"))
	elif "level_3" in path or "death_screen3" in path:
		AudioManager.play_music(preload("res://audio/music/Alone(loop) - melancholic - slow.mp3"))
		AudioManager.play_ambient(preload("res://audio/SFX/Ambient/BGS Loops/Forest Night/Forest Night.wav"))
	elif "final_level" in path or "death_screen4" in path:
		AudioManager.play_music(preload("res://audio/music/01 - DavidKBD - Purgatory Pack - Purgatory.ogg"))
		AudioManager.play_ambient(preload("res://audio/SFX/Ambient/BGS Loops/Interior Day/Inside Day Rain.wav"))
	elif "pause_menu" in path:
		pass
	elif "win_screen" in path:
		AudioManager.stop_ambient()
	else:
		AudioManager.stop_music()
		AudioManager.stop_ambient()

func go_to_scene(path: String, spawn_point_name = "SpawnPoint"):
	if _is_transitioning: return
	_is_transitioning = true
	current_level_path = path
	
	await _fade(1.0)
	
	if VFX:
		VFX.reset_shake()
	
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	
	_move_player_to_spawn(spawn_point_name)

	_update_music_for_path(path)

	await _fade(0.0)
	_is_transitioning = false
	
func _fade(target_alpha: float):
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", target_alpha, FADE_DURATION)
	await tween.finished
	
func _move_player_to_spawn(spawn_point_name):
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player): return
	
	var spawn: Node = get_tree().current_scene.find_child(spawn_point_name, true, false)
	if is_instance_valid(spawn):
		player.global_position = spawn.global_position
	else:
		push_warning("GameFlow: no node named '%s' found in scene." %spawn_point_name)
		
func is_gameplay_scene() -> bool:
	var path = get_tree().current_scene.scene_file_path
	var non_gameplay = ["main_menu", "death_screen", "win_screen"]
	for keyword in non_gameplay:
		if keyword in path:
			return false
	return true

func on_boss_died():
	boss_died.emit()
	await get_tree().create_timer(1.5).timeout
	go_to_scene("res://levels/shared/win_screen.tscn")
	
func on_player_died():
	player_died.emit()
	var scene_path = get_tree().current_scene.scene_file_path
	if "level_1" in scene_path:
		go_to_scene("res://levels/level_1/death_screen1.tscn")
	elif "level_2" in scene_path:
		go_to_scene("res://levels/level_2/death_screen2.tscn")
	elif "level_3" in scene_path:
		go_to_scene("res://levels/level_3/death_screen3.tscn")
	elif "final_level" in scene_path:
		go_to_scene("res://levels/final_level/death_screen4.tscn")
	else: pass
