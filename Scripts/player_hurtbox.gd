extends Area2D

signal player_hurt(attack_position)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D):
	# Check if area entering player hurtbox is enemy hitbox
	if area.name == "Hitbox":
		player_hurt.emit(area.global_position)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
