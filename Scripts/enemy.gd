extends CharacterBody2D

@export var gravity = 1000
@export var move_speed = 120

@export var notice_radius = 220
@export var attack_radius = 45

@export var hurt_duration = 0.25
@export var hurt_left = 0.0
@export var knockback_strength = 250

@export var attack_hit_frame = 1

@onready var visual_root: Node2D = $VisualRoot
@onready var anim: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox

@onready var visual_base_x: float = visual_root.position.x
@onready var hitbox_base_x: float = hitbox.position.x

enum State { IDLE, CHASE, ATTACK, HURT }
var state = State.IDLE

var facing = 1
var player: Node2D = null

var already_hit = false

func _ready():
	hitbox.monitoring = false
	hitbox.monitorable = false
	player = get_tree().get_first_node_in_group("player") as Node2D
	$Hurtbox.hurtbox_hit.connect(_on_hurtbox_hit)
	anim.animation_finished.connect(_on_anim_finished)
	set_state(State.IDLE)
	set_facing(facing)
	
func _physics_process(delta):
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D

	if not is_on_floor():
		velocity.y += gravity * delta
		
	match state:
		State.IDLE:
			update_idle(delta)
		State.CHASE:
			update_chase(delta)
		State.ATTACK:
			update_attack(delta)
		State.HURT:
			update_hurt(delta)
		
	move_and_slide()
	
func _on_hurtbox_hit(attack_position: Vector2):
	if state == State.HURT:
		return
		
	# Calculate knockback direction
	var dir = sign(global_position.x - attack_position.x)
	if dir == 0:
		dir = -facing
		
	velocity.x = dir * knockback_strength
	velocity.y = -200
	
	set_state(State.HURT)
	
func set_facing(new_facing):
	if new_facing == 0 or new_facing == facing:
		return
	facing = new_facing
	
	anim.flip_h = (facing == -1)
	
	visual_root.position.x = visual_base_x * facing
	hitbox.position.x = hitbox_base_x * facing
	
func _on_anim_finished():
	if state == State.ATTACK:
		hitbox_off()
		set_state(State.CHASE)
	
func distance_to_player():
	if player == null:
		return INF
	return global_position.distance_to(player.global_position)
	
func direction_to_player():
	if player == null:
		return 0.0
	return sign(player.global_position.x - global_position.x)
	
func update_idle(delta):
	velocity.x = 0.0
	play_anim("idle")
	
	var d = distance_to_player()
	if d <= notice_radius:
		set_state(State.CHASE)
		
func update_chase(delta):
	var d = distance_to_player()
	
	if d > notice_radius:
		set_state(State.IDLE)
		return
		
	if d <= attack_radius:
		set_state(State.ATTACK)
		return
		
	var dir = direction_to_player()
	if dir != 0:
		set_facing(int(dir))
		
	velocity.x = dir * move_speed
	play_anim("walk")
	
func update_attack(delta):
	velocity.x = 0.0
		
	# Turn on hitbox for single attack frame
	if anim.frame == attack_hit_frame:
		if not hitbox.monitorable:
			hitbox_on()
	else:
		if hitbox.monitorable:
			hitbox_off()
		
	if not anim.is_playing():
		hitbox_off()
		set_state(State.CHASE)
		return
		
func hitbox_on():
	already_hit = false
	hitbox.monitoring = true
	hitbox.monitorable = true
	
func hitbox_off():
	hitbox.monitoring = false
	hitbox.monitorable = false
				
func update_hurt(delta):
	play_anim("hurt")
	hurt_left -= delta
	if hurt_left <= 0.0:
		var d = distance_to_player()
		if d <= notice_radius:
			set_state(State.CHASE)
		else:
			set_state(State.IDLE)
			
func set_state(new_state: State):
	if state == new_state:
		return
		
	if state == State.ATTACK:
		hitbox.monitorable = false
		hitbox.monitoring = false
		
	state = new_state
	
	match state:
		State.IDLE:
			velocity.x = 0.0
		State.CHASE:
			pass
		State.ATTACK:
			already_hit = false
			hitbox_off()
			anim.play("attack")
		State.HURT:
			hurt_left = hurt_duration
			hitbox.monitorable = false
			hitbox.monitoring = false
	
func play_anim(name):
	if anim.animation != name:
		anim.play(name)
