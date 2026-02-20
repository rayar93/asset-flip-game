extends CharacterBody2D

@export var move_speed = 300 # @export makes variables visible in the inspector
@export var jump_velocity = -400
@export var gravity = 1000

@export var attack_duration = 0.1 # seconds
@export var slash_linger = 0.05
@export var hurt_duration = 0.2

@export var attack_hit_frame = 1
var attack_active_left = 0.0
@export var attack_active_time = 0.1

@onready var attack_area: Area2D = $AttackRoot/AttackArea # rename AttackArea node
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var slash_vfx: AnimatedSprite2D = $AttackRoot/SlashVFX

# For the player's finite state machine
enum State { GROUNDED, AIR, ATTACK, HURT }
var state := State.GROUNDED

var facing = 1 # 1 is right, -1 is left

# Timers used by states
var attack_time_left := 0.0
var linger_time_left := 0.0
var hurt_time_left := 0.0

var already_hit = false

func _ready():
	attack_area.monitoring = false
	attack_area.monitorable = false
	slash_vfx.visible = false
	
	$PlayerHurtbox.player_hurt.connect(_on_player_hurt)
	
	
	if is_on_floor():
		set_state(State.GROUNDED)
	else:
		set_state(State.AIR)

# _physics_process() is called by the engine every tick
# we use this instead of _process so that physics is independent of framerate
func _physics_process(delta):
	var move_dir: float = Input.get_axis("move_left", "move_right")
	var jump_pressed: bool = Input.is_action_just_pressed("jump")
	var attack_pressed: bool = Input.is_action_just_pressed("attack")
	
	# Handle falling
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Run state logic
	match state:
		State.GROUNDED:
			update_grounded(delta, move_dir, jump_pressed, attack_pressed)
		State.AIR:
			update_air(delta, move_dir, jump_pressed, attack_pressed)
		State.ATTACK:
			update_attack(delta, move_dir, jump_pressed)
		State.HURT:
			update_hurt(delta)
	
	# move_and_slide() takes our velocity and handles collision
	move_and_slide()
	
	# Post-move transitions depend on floor contact
	if state == State.GROUNDED and not is_on_floor():
		set_state(State.AIR)
	elif state == State.AIR and is_on_floor():
		set_state(State.GROUNDED)

func attack_on():
	attack_area.monitoring = true
	attack_area.monitorable = true
	
func attack_off():
	attack_area.monitoring = false
	attack_area.monitorable = false

func _on_player_hurt(attack_position: Vector2):
	# Knockback direction
	var dir = sign(global_position.x - attack_position.x)
	if dir == 0:
		dir = -facing
		
	var knockback = Vector2(dir * 300, -200)
	velocity = knockback
	set_state(State.HURT)
	
func update_grounded(delta: float, move_dir: float, jump_pressed: bool, attack_pressed: bool):
	# Horizontal movement
	if move_dir != 0:
		facing = sign(move_dir)
		velocity.x = move_dir * move_speed
	else:
		velocity.x = 0
		
	# Jump
	if jump_pressed and is_on_floor():
		velocity.y = jump_velocity
		set_state(State.AIR)
		return
		
	# Attack takes priority over idle/run
	if attack_pressed:
		set_state(State.ATTACK)
		return
		
	# Idle vs run
	if abs(velocity.x) > 0:
		play_anim("run")
	else:
		play_anim("idle")
		
func update_air(delta: float, move_dir: float, jump_pressed: bool, attack_pressed: bool):
	# Air control is weaker than ground control
	if move_dir != 0:
		facing = sign(move_dir)
		velocity.x = move_dir * move_speed * 0.7
	else:
		velocity.x = 0
			
	# Allow air attacks
	if attack_pressed:
		set_state(State.ATTACK)
		return
			
	# Jump vs fall
	if velocity.y < 0:
		play_anim("jump")
	else:
		play_anim("fall")
			
func update_attack(delta: float, move_dir: float, jump_pressed: bool):
	# Slower movement while attacking
	if move_dir != 0:
		facing = sign(move_dir)
		velocity.x = move_dir * move_speed * 0.7
	else:
		velocity.x = 0
		
	# Allow jumping during attack
	if jump_pressed and is_on_floor():
		velocity.y = jump_velocity
	
	attack_active_left -= delta
	if attack_active_left <= 0.0:
		attack_off()
		
	if not slash_vfx.is_playing():
		attack_off()
		slash_vfx.visible = false
		set_state(State.GROUNDED if is_on_floor() else State.AIR)
		return

func update_hurt(delta: float):
	hurt_time_left -= delta
	if hurt_time_left <= 0.0:
		if is_on_floor():
			set_state(State.GROUNDED)
		else:
			set_state(State.AIR)

func set_state(new_state: State):
	if state == new_state:
		return
		
	match state:
		State.ATTACK:
			attack_off()
			slash_vfx.visible = false
			
	state = new_state
	
	match state:
		State.GROUNDED:
			pass
		State.AIR:
			pass
		State.ATTACK:
			already_hit = false
			attack_active_left = attack_active_time
			attack_on()
			slash_vfx.visible = true
			slash_vfx.frame = 0
			slash_vfx.play("slash")
		State.HURT:
			hurt_time_left = hurt_duration
			play_anim("hurt")

func _process(_delta: float):
	anim.flip_h = (facing == -1)
	attack_area.position.x = abs(attack_area.position.x) * facing
	slash_vfx.flip_h = (facing == -1)
	slash_vfx.position.x = abs(slash_vfx.position.x) * facing
	
func play_anim(anim_name: String):
	if anim.animation != anim_name:
		anim.play(anim_name)
