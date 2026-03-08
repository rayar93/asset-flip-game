extends Node

signal player_died
signal boss_died

var _overlay: ColorRect
var _canvas: CanvasLayer
var _is_transitioning = false

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

func go_to_scene(path: String, spawn_point_name = "SpawnPoint"):
	if _is_transitioning: return
	_is_transitioning = true
	
	await _fade(1.0)
	
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	
	_move_player_to_spawn(spawn_point_name)
	
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

func on_boss_died():
	boss_died.emit()
	await get_tree().create_timer(1.5).timeout
	go_to_scene("res://scenes/WinScreen.tscn")
	
func on_player_died():
	player_died.emit()
