extends Node

signal score_changed(new_score)

var score: int = 0

func add_score(amount: int):
	score += amount
	emit_signal("score_changed", score)

func reset_score():
	score = 0
	emit_signal("score_changed", score)
