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

@onready var music = $Music
@onready var ambient = $Ambient

func _ready():
	music.process_mode = Node.PROCESS_MODE_ALWAYS

func play(sound: String):
	if players.has(sound) and not players[sound].playing:
		players[sound].play()
		print('Sound: ', sound)
	else:
		print('No sound: ', sound)

func play_music(stream: AudioStream):
	print("play_music called, same stream: ", music.stream == stream)
	if music.stream == stream: return
	music.stream = stream
	music.play()
	
func play_ambient(stream: AudioStream):
	if ambient.stream == stream: return
	ambient.stream = stream
	ambient.play()

func stop_music():
	music.stop()
	
func stop_ambient():
	ambient.stop()
