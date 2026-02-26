extends CharacterBody2D

# Tunables (can be adjusted in the inspector)

# ===========================================================



@export_group("Movement")
@export var move_speed = 300

@export var jump_velocity = -400
@export var gravity = 1000
@export var dash_speed = 900
@export var dash_duration = 0.2

@export_group("Combat")
@export var hurt_duration = 0.2
@export var attack_active_time = 0.1

# Node references
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackRoot/AttackArea
@onready var slash_vfx: AnimatedSprite2D = $AttackRoot/SlashVFX
@onready var down_attack_area: Area2D = $DownAttackRoot/DownAttackArea
@onready var down_slash_vfx: AnimatedSprite2D = $DownAttackRoot/DownSlashVFX

# Timers and flags
var attack_active_left = 0.0
var hurt_time_left := 0.0
var dash_time_left = 0.0
var can_dash = true
var can_double_jump = true

# State machine
enum State { GROUNDED, AIR, ATTACK, HURT, DASH, ATTACK_DOWN }
var state := State.GROUNDED
var facing = 1 # 1 = right, -1 = left

# ==============================================================================================================================================================================================================
# Engine callbacks
# ==============================================================================================================================================================================================================

# Initialization
func _ready():
	all_attacks_off()
	
	# Player hurtbox emits signal when enemy hitbox overlaps
	$PlayerHurtbox.player_hurt.connect(_on_player_hurt)
	
	# Player hitbox emits signal with entering enemy hurtbox
	down_attack_area.area_entered.connect(_on_down_attack_hit)
	
	set_state(State.GROUNDED if is_on_floor() else State.AIR)

# Runs every physics tick
# Updates movement and state, applies physics
func _physics_process(delta):
	# Gravity when airborne
	if not is_on_floor():
		velocity.y += gravity * delta
	
	var move_dir = Input.get_axis("move_left", "move_right")
	
	# Update states
	match state:
		State.GROUNDED:		update_grounded(move_dir)
		State.AIR:			update_air(move_dir)
		State.ATTACK:		update_attack(delta, move_dir)
		State.HURT:			update_hurt(delta)
		State.DASH:			update_dash(delta)
		State.ATTACK_DOWN:	update_attack_down()
	
	move_and_slide()
	_check_landed_or_fell()

# Separate from physics, remains responsive even if physics tick rate changes
func _process(_delta: float):
	# Every frame, make sure sprite and hitbox are faced correctly
	anim.flip_h = (facing == -1)
	attack_area.position.x = abs(attack_area.position.x) * facing
	slash_vfx.flip_h = (facing == -1)
	slash_vfx.position.x = abs(slash_vfx.position.x) * facing
			
# ====================================================================================================================================================================================================
# State updates
# ====================================================================================================================================================================================================
	
func update_grounded(move_dir):
	velocity.x = move_dir * move_speed
	if move_dir != 0: facing = sign(move_dir)
	
	if Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		set_state(State.AIR)
	elif Input.is_action_just_pressed("dash") and can_dash:
		set_state(State.DASH)
	elif Input.is_action_just_pressed("attack"):
		set_state(State.ATTACK)
		
	play_anim("run" if velocity.x != 0 else "idle")
		
func update_air(move_dir):
	velocity.x = move_dir * move_speed * 0.7
	if move_dir != 0: facing = sign(move_dir)
	
	if Input.is_action_just_pressed("jump") and can_double_jump:
		velocity.y = jump_velocity
		can_double_jump = false
		play_anim("double_jump")
	elif Input.is_action_just_pressed("dash") and can_dash:
		set_state(State.DASH)
	elif Input.is_action_just_pressed("attack"):
		set_state(State.ATTACK_DOWN if Input.is_action_pressed("down") else State.ATTACK)
	
	if anim.animation != "double_jump":
		play_anim("jump" if velocity.y < 0 else "fall")
			
func update_attack(delta, move_dir):
	velocity.x = move_dir * move_speed * 0.5
	attack_active_left -= delta
	
	if attack_active_left <= 0:
		attack_off()
		
	if not slash_vfx.is_playing():
		_return_to_base_state()
		
func update_attack_down():
	if not down_slash_vfx.is_playing():
		_return_to_base_state()

func update_hurt(delta):
	hurt_time_left -= delta
	if hurt_time_left <= 0.0:
		_return_to_base_state()

func update_dash(delta: float):
	dash_time_left -= delta
	
	if dash_time_left <= 0:
		anim.play()
		_return_to_base_state()
		
func _return_to_base_state():
	set_state(State.GROUNDED if is_on_floor() else State.AIR)
	
# =============================================================================================================================================================================================================
# State transitions
# =============================================================================================================================================================================================================

func set_state(new_state: State):
	if state == new_state: return
		
	all_attacks_off()
			
	# Kill momentum after dash
	if state == State.DASH: velocity.x = 0
			
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
		State.HURT:
			hurt_time_left = hurt_duration
			play_anim("hurt")
		State.ATTACK_DOWN:
			down_attack_on()

# ===========================================================================================================================================================================================================================
# Helpers
# ===========================================================================================================================================================================================================================

func attack_on():
	_toggle_area(attack_area, true)
	_play_vfx(slash_vfx, "slash")
	
func attack_off():
	_toggle_area(attack_area, false)
	slash_vfx.visible = false
	
func down_attack_on():
	# Reset area to ensure physics re-detection
	_toggle_area(down_attack_area, false)
	_toggle_area(down_attack_area, true)
	_play_vfx(down_slash_vfx, "down_attack")
	
func down_attack_off():
	_toggle_area(down_attack_area, false)
	down_slash_vfx.visible = false
	
func all_attacks_off():
	attack_off()
	down_attack_off()
	
func _toggle_area(area: Area2D, active: bool):
	area.monitoring = active
	area.monitorable = active
	
func _play_vfx(vfx: AnimatedSprite2D, anim_name: String):
	vfx.visible = true
	vfx.frame = 0
	vfx.play(anim_name)
	
func play_anim(anim_name: String):
	if anim.animation != anim_name:
		anim.play(anim_name)
		
func _check_landed_or_fell():
	if state in [State.ATTACK, State.DASH, State.HURT]: return
	
	if is_on_floor() and state == State.AIR:
		set_state(State.GROUNDED)
	elif not is_on_floor() and state == State.GROUNDED:
		set_state(State.AIR)

# ===============================================================================================================================================================================================
# Signals
# ===============================================================================================================================================================================================

func _on_player_hurt(attack_position: Vector2):
	# Calculate knockback direction
	var dir = sign(global_position.x - attack_position.x)
	if dir == 0:
		dir = -facing
	
	# Apply knockback, enter hurt state
	velocity = Vector2(dir * 300, -200)
	set_state(State.HURT)
	
# Pogo enemies
func _on_down_attack_hit(area: Area2D):
	if state == State.ATTACK_DOWN and area.has_signal("hurtbox_hit"):
		area.hurtbox_hit.emit(global_position)
		velocity.y = jump_velocity
		call_deferred("down_attack_off")
