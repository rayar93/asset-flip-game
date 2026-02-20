extends Area2D

signal hurtbox_hit(attack_position)

func _ready() -> void:
	area_entered.connect(_on_area_entered)

# When player hitbox enters this hurtbox, emit signal
func _on_area_entered(area: Area2D):
	if area.is_in_group("player_attack"):
		hurtbox_hit.emit(area.global_position)
