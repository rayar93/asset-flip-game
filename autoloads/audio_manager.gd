extends Node

@onready var players = {
	"player_attack": $PlayerAttack,
	"enemy_attack": $EnemyAttack,
	"dash": $Dash,
	"jump": $Jump,
	"player_hurt": $PlayerHurt,
	"player_death": $PlayerDeath,
	"enemy_hurt": $EnemyHurt,
	"enemy_death": $EnemyDeath,
}

func play(sound: String):
	if players.has(sound) and not players[sound].playing:
		players[sound].play()
		print('Sound: ', sound)
	else:
		print('No sound: ', sound)
