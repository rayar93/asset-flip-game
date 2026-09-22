extends CanvasLayer

@onready var label = $Count

func _ready():
	label.text = "Score: 0"
	ScoreManager.connect("score_changed", _on_score_changed)

func _on_score_changed(new_score):
	label.text = "Score: " + str(new_score)
