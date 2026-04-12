extends Node

@onready var sfx_players: Array = [$SFX1, $SFX2, $SFX3, $SFX4, $SFX5, $SFX6, $SFX7, $SFX8]

@onready var music = $Music
@onready var ambient = $Ambient

var _next_player = 0

var sound_pools = {
	"click": [
		preload("res://audio/SFX/kenney_interface-sounds/Audio/click.ogg")
	],
	"hover": [
		preload("res://audio/SFX/kenney_interface-sounds/Audio/hover.ogg")
	],
	"pause": [
		preload("res://audio/SFX/kenney_interface-sounds/Audio/pause.ogg")
	],
	"resume": [
		preload("res://audio/SFX/kenney_interface-sounds/Audio/resume.ogg")
	],
	"footstep": [
		preload("res://audio/SFX/footsteps/Linoleum_Mono_01.wav"),
		preload("res://audio/SFX/footsteps/Linoleum_Mono_02.wav"),
		preload("res://audio/SFX/footsteps/Linoleum_Mono_03.wav"),
		preload("res://audio/SFX/footsteps/Linoleum_Mono_04.wav"),
		preload("res://audio/SFX/footsteps/Linoleum_Mono_05.wav"),
	],
	"player_jump": [
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNTonl_STEP-Magic Step_HY_PC-001.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNTonl_STEP-Magic Step_HY_PC-002.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNTonl_STEP-Magic Step_HY_PC-003.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNTonl_STEP-Magic Step_HY_PC-004.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNTonl_STEP-Magic Step_HY_PC-005.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNTonl_STEP-Magic Step_HY_PC-006.wav")	
	],
	"player_dash": [
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/WHSH_MOVEMENT-Simple Whoosh_HY_PC-001.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/WHSH_MOVEMENT-Simple Whoosh_HY_PC-002.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/WHSH_MOVEMENT-Simple Whoosh_HY_PC-003.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/WHSH_MOVEMENT-Simple Whoosh_HY_PC-004.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/WHSH_MOVEMENT-Simple Whoosh_HY_PC-005.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/WHSH_MOVEMENT-Simple Whoosh_HY_PC-006.wav")
	],
	"player_hurt": [
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_HIT-Fleeting Hit_HY_PC-001.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_HIT-Fleeting Hit_HY_PC-002.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_HIT-Fleeting Hit_HY_PC-003.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_HIT-Fleeting Hit_HY_PC-004.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_HIT-Fleeting Hit_HY_PC-005.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_HIT-Fleeting Hit_HY_PC-006.wav")
	],
	"player_death": [
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_SKILL IMPACT-Dramatic Finish_HY_PC-001.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_SKILL IMPACT-Dramatic Finish_HY_PC-002.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_SKILL IMPACT-Dramatic Finish_HY_PC-003.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_SKILL IMPACT-Dramatic Finish_HY_PC-004.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_SKILL IMPACT-Dramatic Finish_HY_PC-005.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_SKILL IMPACT-Dramatic Finish_HY_PC-006.wav")
	],
	"pogo_bounce": [
		preload("res://audio/SFX/kenney_impact-sounds/Audio/impactBell_heavy_003.ogg"),
		preload("res://audio/SFX/kenney_impact-sounds/Audio/impactBell_heavy_004.ogg")
	],
	"land": [
		preload("res://audio/SFX/footsteps/Parquet_Floor_Mono_01.wav")
	],
	"player_heal": [
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/MAGAngl_BUFF-Simple Heal_HY_PC-001.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/MAGAngl_BUFF-Simple Heal_HY_PC-002.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/MAGAngl_BUFF-Simple Heal_HY_PC-003.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/MAGAngl_BUFF-Simple Heal_HY_PC-004.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/MAGAngl_BUFF-Simple Heal_HY_PC-005.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/MAGAngl_BUFF-Simple Heal_HY_PC-006.wav")
	],
	"player_attack": [
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/SWSH_MOVEMENT-Bamboo Whip_HY_PC-001.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/SWSH_MOVEMENT-Bamboo Whip_HY_PC-002.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/SWSH_MOVEMENT-Bamboo Whip_HY_PC-003.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/SWSH_MOVEMENT-Bamboo Whip_HY_PC-004.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/SWSH_MOVEMENT-Bamboo Whip_HY_PC-005.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/SWSH_MOVEMENT-Bamboo Whip_HY_PC-006.wav")
	],
	"enemy_hurt": [
		preload("res://audio/SFX/Sword Attacks Hits and Blocks/Sword Impact Hit 1.wav"),
		preload("res://audio/SFX/Sword Attacks Hits and Blocks/Sword Impact Hit 2.wav"),
		preload("res://audio/SFX/Sword Attacks Hits and Blocks/Sword Impact Hit 3.wav")
	],
	"boss_attack_connect": [
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/FGHTImpt_HIT-Strong Smack_HY_PC-001.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/FGHTImpt_HIT-Strong Smack_HY_PC-002.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/FGHTImpt_HIT-Strong Smack_HY_PC-003.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/FGHTImpt_HIT-Strong Smack_HY_PC-004.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/FGHTImpt_HIT-Strong Smack_HY_PC-005.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/FGHTImpt_HIT-Strong Smack_HY_PC-006.wav")
	],
	"boss_jump": [
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_MOVEMENT-Mecha Large Takeoff_HY_PC-001.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_MOVEMENT-Mecha Large Takeoff_HY_PC-002.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_MOVEMENT-Mecha Large Takeoff_HY_PC-003.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_MOVEMENT-Mecha Large Takeoff_HY_PC-004.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_MOVEMENT-Mecha Large Takeoff_HY_PC-005.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_MOVEMENT-Mecha Large Takeoff_HY_PC-006.wav")
	],
	"boss_dash": [
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/WHSH_MOVEMENT-Mecha Energy Passby_HY_PC-001.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/WHSH_MOVEMENT-Mecha Energy Passby_HY_PC-002.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/WHSH_MOVEMENT-Mecha Energy Passby_HY_PC-003.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/WHSH_MOVEMENT-Mecha Energy Passby_HY_PC-004.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/WHSH_MOVEMENT-Mecha Energy Passby_HY_PC-005.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/WHSH_MOVEMENT-Mecha Energy Passby_HY_PC-006.wav")
	],
	"fireball_launch": [
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_SKILL RELEASE-Flame Ball_HY_PC-001.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_SKILL RELEASE-Flame Ball_HY_PC-002.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_SKILL RELEASE-Flame Ball_HY_PC-004.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_SKILL RELEASE-Flame Ball_HY_PC-003.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_SKILL RELEASE-Flame Ball_HY_PC-005.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_SKILL RELEASE-Flame Ball_HY_PC-006.wav")
	],
	"fireball_hit": [
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_SKILL IMPACT-Flare Hit_HY_PC-001.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_SKILL IMPACT-Flare Hit_HY_PC-002.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_SKILL IMPACT-Flare Hit_HY_PC-003.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_SKILL IMPACT-Flare Hit_HY_PC-004.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_SKILL IMPACT-Flare Hit_HY_PC-005.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_SKILL IMPACT-Flare Hit_HY_PC-006.wav")
	],
	"enemy_attack": [
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/WHSH_MOVEMENT-Sand Swipe_HY_PC-001.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/WHSH_MOVEMENT-Sand Swipe_HY_PC-002.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/WHSH_MOVEMENT-Sand Swipe_HY_PC-003.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/WHSH_MOVEMENT-Sand Swipe_HY_PC-004.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/WHSH_MOVEMENT-Sand Swipe_HY_PC-005.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/WHSH_MOVEMENT-Sand Swipe_HY_PC-006.wav")
	],
	"boss_attack": [
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_MELEE-Sword Slash_HY_PC-001.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_MELEE-Sword Slash_HY_PC-002.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_MELEE-Sword Slash_HY_PC-003.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_MELEE-Sword Slash_HY_PC-004.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_MELEE-Sword Slash_HY_PC-005.wav"),
		preload("res://audio/SFX/Helton Yan's Pixel Combat - Single Files/DSGNMisc_MELEE-Sword Slash_HY_PC-006.wav")
	]
}

func _ready():
	randomize()
	music.process_mode = Node.PROCESS_MODE_ALWAYS

func play(key: String, volume_db: float = 0.0):
	if not sound_pools.has(key): return
	var p = _get_free_player()
	if p == null: return
	var pool = sound_pools[key]
	p.stream = pool[randi() % pool.size()]
	p.volume_db = volume_db
	p.play()
		
func _get_free_player() -> AudioStreamPlayer:
	for i in sfx_players.size():
		var idx = (_next_player + i) % sfx_players.size()
		if not sfx_players[idx].playing:
			_next_player = idx + 1
			return sfx_players[idx]
	return null

func play_music(stream: AudioStream):
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
