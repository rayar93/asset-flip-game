extends CanvasLayer

@onready var pips = $HBoxContainer.get_children()
var player = null

func _ready() -> void:
	GameFlow.player_died.connect(func(): hide())
	get_tree().node_added.connect(func(node):
		if node.is_in_group("player"):
			await _find_and_connect_player()
	)
	await _find_and_connect_player()
	
func _on_node_added(node: Node):
	if node.is_in_group("player"):
		await _find_and_connect_player()

func _find_and_connect_player():
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		hide()
		return
	show()
	_update_pips(player.current_health)
	if not player.health_changed.is_connected(_on_health_changed):
		player.health_changed.connect(_on_health_changed)
	
func _on_health_changed(new_health):
	_update_pips(new_health)
	
func _update_pips(current_health):
	for i in pips.size():
		pips[i].modulate = Color.WHITE if i < current_health else Color(0.2, 0.2, 0.2, 0.5)
