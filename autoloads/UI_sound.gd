extends Node

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_connect_existing_buttons(get_tree().root)
	
func _connect_existing_buttons(node: Node):
	if node is Button:
		_wire_button(node)
	for child in node.get_children():
		_connect_existing_buttons(child)

func _on_node_added(node: Node):
	if node is Button:
		_wire_button(node)
		
func _wire_button(button):
	if not button.mouse_entered.is_connected(AudioManager.play):
		button.mouse_entered.connect(AudioManager.play.bind("hover"))
	if not button.pressed.is_connected(AudioManager.play):
		button.pressed.connect(AudioManager.play.bind("click"))
