extends Area2D

@export var boss_path: NodePath = ""

var _triggered = false

func _ready():
	body_entered.connect(_on_body_entered)
	
func _on_body_entered(body: Node):
	if _triggered: return
	if not body.is_in_group("player"): return
	
	_triggered = true
	
	var boss = get_node_or_null(boss_path)
	if is_instance_valid(boss) and boss.has_method("start_combat"):
		boss.start_combat()
	else:
		push_warning("BossTriggerZone: couldn't find boss at path '%s'." %boss_path)
