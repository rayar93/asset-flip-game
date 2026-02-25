extends CharacterBody2D

# ===========================================================
# Tunables (can be adjusted in the inspector)
# ===========================================================

@export var move_speed = 300
@export var jump_velocity = -400
@export var gravity = 1000

@export var hurt_duration = 0.2

@export var attack_active_time = 0.1

@export var dash_speed = 900
@export var dash_duration = 0.2

# ================================================
# Node references
# ================================================

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

@onready var attack_area: Area2D = $AttackRoot/AttackArea
@onready var slash_vfx: AnimatedSprite2D = $AttackRoot/SlashVFX

@onready var down_attack_area: Area2D = $DownAttackRoot/DownAttackArea
@onready var down_slash_vfx: AnimatedSprite2D = $DownAttackRoot/DownSlashVFX

# ================================================
# Other variables
# ================================================

# Timers
var attack_active_left = 0.0
var hurt_time_left := 0.0

var dash_time_left = 0.0
var can_dash = true

var can_double_jump = true

# State machine
enum State { GROUNDED, AIR, ATTACK, HURT, DASH, ATTACK_DOWN }
var state := State.GROUNDED

# Facing convention: 1 = right, -1 = left
var facing = 1

# ====================================
# Engine callbacks
# ====================================

# Initialization
func _ready():
	attack_off()
	down_attack_off()
	slash_vfx.visible = false
	down_slash_vfx.visible = false
	
	# Player hurtbox emits signal when enemy hitbox overlaps
	$PlayerHurtbox.player_hurt.connect(_on_player_hurt)
	
	# Player hitbox emits signal with entering enemy hurtbox
	down_attack_area.area_entered.connect(_on_down_attack_hit)
	
	# Starting state depends on if player is on ground
	if is_on_floor():
		set_state(State.GROUNDED)
	else:
		set_state(State.AIR)

# Runs every physics tick
# Updates movement and state, applies physics
func _physics_process(delta):
	# Input gathered every tick
	var move_dir: float = Input.get_axis("move_left", "move_right")
	var jump_pressed: bool = Input.is_action_just_pressed("jump")
	var attack_pressed: bool = Input.is_action_just_pressed("attack")
	var dash_pressed: bool = Input.is_action_just_pressed("dash")
	var down_pressed: bool = Input.is_action_pressed("down")
	
	# Gravity when airborne
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Run state logic depending on player input
	match state:
		State.GROUNDED:
			update_grounded(delta, move_dir, jump_pressed, attack_pressed, dash_pressed)
		State.AIR:
			update_air(delta, move_dir, jump_pressed, attack_pressed, dash_pressed, down_pressed)
		State.ATTACK:
			update_attack(delta, move_dir, jump_pressed)
		State.HURT:
			update_hurt(delta)
		State.DASH:
			update_dash(delta)
		State.ATTACK_DOWN:
			update_attack_down(delta)
	
	# Apply motion and collisions
	move_and_slide()
	
	# Post-move transitions depend on floor contact
	if state == State.GROUNDED and not is_on_floor():
		set_state(State.AIR)
	elif state == State.AIR and is_on_floor():
		set_state(State.GROUNDED)

# Separate from physics, remains responsive even if physics tick rate changes
func _process(_delta: float):
	# Every frame, make sure sprite and hitbox are faced correctly
	anim.flip_h = (facing == -1)
	attack_area.position.x = abs(attack_area.position.x) * facing
	slash_vfx.flip_h = (facing == -1)
	slash_vfx.position.x = abs(slash_vfx.position.x) * facing

# ============================================
# Signals
# ============================================

func _on_player_hurt(attack_position: Vector2):
	# Calculate knockback direction
	var dir = sign(global_position.x - attack_position.x)
	if dir == 0:
		dir = -facing
	
	# Apply knockback, enter hurt state
	var knockback = Vector2(dir * 300, -200)
	velocity = knockback
	set_state(State.HURT)
	
# Pogo enemies
func _on_down_attack_hit(area: Area2D):
	if state == State.ATTACK_DOWN and area.has_signal("hurtbox_hit"):
		velocity.y = jump_velocity
		down_attack_off()

# ========================================================================
# Helpers
# ========================================================================

func play_anim(anim_name: String):
	if anim.animation != anim_name:
		anim.play(anim_name)

func attack_on():
	attack_area.monitoring = true
	attack_area.monitorable = true
	down_attack_area.monitoring = false
	down_attack_area.monitorable = false
	
func attack_off():
	attack_area.monitoring = false
	attack_area.monitorable = false
	down_attack_area.monitoring = false
	down_attack_area.monitorable = false
	
func down_attack_on():
	down_attack_area.monitoring = false
	down_attack_area.monitorable = false
	PhysicsServer2D.area_set_monitorable(down_attack_area.get_rid(), true)
	down_attack_area.monitoring = true
	down_attack_area.monitorable = true
	attack_area.monitoring = false
	attack_area.monitorable = false
	
func down_attack_off():
	down_attack_area.monitoring = false
	down_attack_area.monitorable = false
	attack_area.monitoring = false
	attack_area.monitorable = false
	
# ======================================
# State transitions
# ======================================

func set_state(new_state: State):
	if state == new_state:
		return
		
	# Turn off hitboxes when leaving a state
	attack_off()
	down_attack_off()
	slash_vfx.visible = false
	down_slash_vfx.visible = false
			
	# Kill momentum after dash
	if state == State.DASH:
		velocity.x = 0
			
	state = new_state
	
	# Do this if entering state
	match state:
		State.GROUNDED:
			can_double_jump = true
			can_dash = true
		State.DASH:
			dash_time_left = dash_duration
			velocity.y = 0
			velocity.x = facing * dash_speed
			can_dash = false
			anim.pause()
		State.AIR:
			attack_off()
			down_attack_off()
		State.ATTACK:
			attack_active_left = attack_active_time
			attack_on()
			slash_vfx.visible = true
			slash_vfx.frame = 0
			slash_vfx.play("slash")
		State.HURT:
			hurt_time_left = hurt_duration
			play_anim("hurt")
		State.ATTACK_DOWN:
			attack_off()
			down_attack_on()
			down_slash_vfx.visible = true
			down_slash_vfx.frame = 0
			down_slash_vfx.play("down_attack")
			
# =================================================
# State updates
# =================================================
	
func update_grounded(_delta: float, move_dir: float, jump_pressed: bool, attack_pressed: bool, dash_pressed: bool):
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
		
	# Dash
	if dash_pressed and can_dash:
		set_state(State.DASH)
		return
		
	# Attack
	if attack_pressed:
		set_state(State.ATTACK)
		return
		
	# Idle vs run animation
	if abs(velocity.x) > 0:
		play_anim("run")
	else:
		play_anim("idle")
		
func update_air(_delta: float, move_dir: float, jump_pressed: bool, attack_pressed: bool, dash_pressed: bool, down_pressed: bool):
	# Reduced air control
	if move_dir != 0:
		facing = sign(move_dir)
		velocity.x = move_dir * move_speed * 0.7
	else:
		velocity.x = 0
		
	if jump_pressed and can_double_jump:
		velocity.y = jump_velocity
		can_double_jump = false
		play_anim("double_jump")
		
	# Dash
	if dash_pressed and can_dash:
		set_state(State.DASH)
		return
		
	# Allow air attacks including downward attacks
	if attack_pressed:
		if down_pressed:
			set_state(State.ATTACK_DOWN)
		else:
			set_state(State.ATTACK)
		return
			
	# Double-jump vs ump vs fall animation
	if anim.animation == "double_jump" and velocity.y < 0:
		pass
	elif velocity.y < 0:
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
	
	# Turn hitbox off at end of attack animation
	attack_active_left -= delta
	if attack_active_left <= 0.0:
		attack_off()
	
	# When the slash animation ends, exit ATTACK state
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

func update_dash(delta: float):
	dash_time_left -= delta
	
	velocity.x = facing * dash_speed
	velocity.y = 0
	
	if dash_time_left <= 0:
		anim.play()
		if is_on_floor():
			set_state(State.GROUNDED)
		else:
			set_state(State.AIR)

func update_attack_down(_delta: float):
	if not down_slash_vfx.is_playing():
		down_attack_off()
		down_slash_vfx.visible = false
		
		if is_on_floor():
			set_state(State.GROUNDED)
		else:
			set_state(State.AIR)
