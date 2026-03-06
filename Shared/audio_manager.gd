extends Node

@onready var players = {
	"player_attack": $PlayerAttack,
	"enemy_hit": $EnemyHit,
	"player_hurt": $PlayerHurt,
	"player_dash": $PlayerDash,
	"jump": $Jump
}

func play(sound: String):
	if players.has(sound):
		players[sound].play()
