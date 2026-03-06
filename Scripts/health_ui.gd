extends CanvasLayer

@onready var pips = $HBoxContainer.get_children()

func _ready() -> void:
	var player = get_tree().get_first_node_in_group("player")
	player.health_changed.connect(_on_health_changed)
	
func _on_health_changed(new_health):
	for i in pips.size():
		pips[i].modulate = Color.WHITE if i < new_health else Color(0.2, 0.2, 0.2)
