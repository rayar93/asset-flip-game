extends CharacterBody2D

# Tunables (can be adjusted in the inspector)
@export_group("Movement")
@export var move_speed = 300
@export var jump_velocity = -400
@export var gravity = 1000
@export var dash_speed = 1000
@export var dash_duration = 0.2

@export_group("Combat")
@export var max_health = 3

# Node references
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackRoot/AttackArea
@onready var slash_vfx: AnimatedSprite2D = $AttackRoot/SlashVFX
@onready var down_attack_area: Area2D = $DownAttackRoot/DownAttackArea
@onready var down_slash_vfx: AnimatedSprite2D = $DownAttackRoot/DownSlashVFX
@onready var up_attack_area: Area2D = $UpAttackRoot/UpAttackArea
@onready var up_slash_vfx: AnimatedSprite2D = $UpAttackRoot/UpSlashVFX

# Internal variables
var dash_time_left = 0.0
var can_dash = true
var can_double_jump = true
var targets_hit_this_attack: Array[Node2D] = []
var current_health = 3

# State machine
enum State { GROUNDED, AIR, ATTACK, HURT, DASH, ATTACK_DOWN, ATTACK_UP, DEAD }
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
	attack_area.area_entered.connect(_on_side_attack_hit)
	down_attack_area.area_entered.connect(_on_down_attack_hit)
	up_attack_area.area_entered.connect(_on_up_attack_hit)
	
	anim.animation_finished.connect(_on_anim_finished)
	
	slash_vfx.animation_finished.connect(_on_vfx_finished)
	down_slash_vfx.animation_finished.connect(_on_vfx_finished)
	up_slash_vfx.animation_finished.connect(_on_vfx_finished)
	
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
		State.ATTACK_UP:	update_attack_up(move_dir)
	
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
		if Input.is_action_pressed("up"):
			set_state(State.ATTACK_UP)
		else:
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
		if Input.is_action_pressed("up"):
			set_state(State.ATTACK_UP)
		elif Input.is_action_pressed("down"):
			set_state(State.ATTACK_DOWN)
		else:
			set_state(State.ATTACK)
			
	if anim.animation != "double_jump":
		play_anim("jump" if velocity.y < 0 else "fall")
			
func update_attack(delta, move_dir):
	if not slash_vfx.is_playing():
		_return_to_base_state()
		
func update_attack_down():
	if not down_slash_vfx.is_playing():
		_return_to_base_state()
		
func update_attack_up(move_dir):
	velocity.x = move_dir * move_speed * 0.5
	if not up_slash_vfx.is_playing():
		_return_to_base_state()

func update_hurt(delta):
	pass

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
	targets_hit_this_attack.clear()
			
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
			pass
		State.ATTACK:
			attack_on()
		State.HURT:
			play_anim("hurt")
		State.ATTACK_DOWN:
			down_attack_on()
		State.ATTACK_UP:
			up_attack_on()
		State.DEAD:
			velocity = Vector2.ZERO
			get_tree().reload_current_scene()

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
	
func up_attack_on():
	_toggle_area(up_attack_area, true)
	_play_vfx(up_slash_vfx, "up_attack")
	
func up_attack_off():
	_toggle_area(up_attack_area, false)
	up_slash_vfx.visible = false
	
func all_attacks_off():
	attack_off()
	down_attack_off()
	up_attack_off()
	
func die():
	if state == State.DEAD: return
	set_state(State.DEAD)
	
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
	if state == State.HURT: return
	
	current_health -= 1
	if current_health <= 0:
		die()
		return
	
	# Calculate knockback direction
	var dir = sign(global_position.x - attack_position.x)
	if dir == 0:
		dir = -facing
	
	# Apply knockback, enter hurt state
	velocity = Vector2(dir * 300, -200)
	set_state(State.HURT)

func _handle_hit(area: Area2D, required_state: State):
	if area in targets_hit_this_attack: return
	
	if state == required_state and area.has_signal("hurtbox_hit"):
		targets_hit_this_attack.append(area)
		area.hurtbox_hit.emit(global_position)
		return true # if hit happened
	return false

func _on_side_attack_hit(area: Area2D):
	_handle_hit(area, State.ATTACK)

# Pogo enemies
func _on_down_attack_hit(area: Area2D):
	if _handle_hit(area, State.ATTACK_DOWN):
		velocity.y = jump_velocity
		
func _on_up_attack_hit(area: Area2D):
	_handle_hit(area, State.ATTACK_UP)

func _on_anim_finished():
	if state == State.HURT:
		_return_to_base_state()
		
func _on_vfx_finished():
	if state in [State.ATTACK, State.ATTACK_UP, State.ATTACK_DOWN]:
		_return_to_base_state()
