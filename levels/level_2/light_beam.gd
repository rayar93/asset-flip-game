extends Node2D

@export var beam_length = 300
@export var beam_width = 60
@export var beam_angle = 0
@export var beam_color: Color = Color(1.0, 0.95, 0.8, 0.4)

@onready var sprite: Sprite2D = $Sprite2D
@onready var light: PointLight2D = $PointLight2D

func _ready() -> void:
	apply_settings()
	
func apply_settings():
	sprite.scale = Vector2(beam_width / 64.0, beam_length / 256.0)
	sprite.rotation_degrees = beam_angle
	sprite.self_modulate = beam_color
	light.position = Vector2(
		sin(deg_to_rad(beam_angle)) * beam_length,
		cos(deg_to_rad(beam_angle)) * beam_length
	)
