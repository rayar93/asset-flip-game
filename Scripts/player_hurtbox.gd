extends Area2D

signal player_hurt(attack_position)

func _ready() -> void:
	area_entered.connect(_on_area_entered)

# Emit signal when enemy hitbox enters player hurtbox
func _on_area_entered(area: Area2D):
	if area.name == "Hitbox":
		player_hurt.emit(area.global_position)
