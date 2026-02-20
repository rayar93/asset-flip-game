extends Area2D

signal hurtbox_hit(attack_position)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D):
	# Check if area entering enemy hurtbox is player hitbox
	if area.name == "AttackArea":
		hurtbox_hit.emit(area.global_position)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
