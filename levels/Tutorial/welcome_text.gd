extends Area2D

@onready var anim_player = $AnimationPlayer

func _ready():
	connect("body_entered", _on_body_entered)

func _on_body_entered(body):
	anim_player.play("Show")
