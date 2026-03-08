extends Area2D

@export var target_scene: String = ""

@export var spawn_point_name: String = "SpawnPoint"

@export var trigger_delay: float = 0.3

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node):
	if not body.is_in_group("player"): return
	if target_scene == "":
		push_warning("TransitionArea: target_scene is not set.")
		return
		
	if trigger_delay > 0.0:
		await get_tree().create_timer(trigger_delay).timeout
		
	GameFlow.go_to_scene(target_scene, spawn_point_name)
