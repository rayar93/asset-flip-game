extends CharacterBody2D

@export var gravity = 1000
@export var move_speed = 120

@export var notice_radius = 220
@export var attack_radius = 45

@export var attack_windup = 0.15
@export var attack_active = 0.1
@export var attack_recover = 0.2

@export var hurt_duration = 0.25
@export var hurt_left = 0.0
@export var knockback_strength = 250

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var hurtbox: Area2D = $Hurtbox

enum State { IDLE, CHASE, ATTACK, HURT }
var state = State.IDLE

var facing = 1
var player: Node2D = null

var attack_windup_left = 0.0
var attack_active_left = 0.0
var attack_recover_left = 0.0

func _ready():
	hitbox.monitoring = false
	player = get_tree().get_first_node_in_group("player") as Node2D
	set_state(State.IDLE)
	
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
		facing = int(dir)
		
	velocity.x = dir * move_speed
	play_anim("walk")
	
func update_attack(delta):
	var dir = direction_to_player()
	if dir != 0:
		facing = int(dir)
		
	velocity.x = 0.0
	play_anim("attack")
	
	if attack_windup_left > 0.0:
		attack_windup_left -= delta
		if attack_windup_left <= 0.0:
			hitbox.monitoring = true
			attack_active_left = attack_active
		return
		
	if attack_active_left > 0.0:
		attack_active_left -= delta
		for body in hitbox.get_overlapping_bodies():
			if body.is_in_group("player"):
				var knockback_dir = (body.global_position - global_position).normalized()
				var knockback = knockback_dir * 300
				body.take_hit(knockback)
		if attack_active_left <= 0.0:
			hitbox.monitoring = false
			attack_recover_left = attack_recover
		return
		
	if attack_recover_left > 0.0:
		attack_recover_left -= delta
		if attack_recover_left <= 0.0:
			var d = distance_to_player()
			if d <= notice_radius:
				set_state(State.CHASE)
			else:
				set_state(State.IDLE)
				
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
		hitbox.monitoring = false
		
	state = new_state
	
	match state:
		State.IDLE:
			velocity.x = 0.0
		State.CHASE:
			pass
		State.ATTACK:
			attack_windup_left = attack_windup
			attack_active_left = 0.0
			attack_recover_left = 0.0
		State.HURT:
			hurt_left = hurt_duration
			hitbox.monitoring = false
			
func take_hit(from_world_pos: Vector2):
	# Ignore hits while already hurt
	if state == State.HURT:
		return
		
	# Horizontal knockback
	var dir = sign(global_position.x - from_world_pos.x)
	if dir == 0:
		dir = -facing
	velocity.x = dir * knockback_strength
	
	set_state(State.HURT)
	
func _process(delta):
	anim.flip_h = (facing == -1)
	hitbox.position.x = abs(hitbox.position.x) * facing
	hurtbox.position.x = abs(hurtbox.position.x) * facing
	
func play_anim(name):
	if anim.animation != name:
		anim.play(name)
