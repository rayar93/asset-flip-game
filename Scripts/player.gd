extends CharacterBody2D

@export var move_speed = 300 # @export makes variables visible in the inspector
@export var jump_velocity = -400
@export var gravity = 1000

@export var attack_duration = 0.1 # seconds

@onready var attack_area: Area2D = $AttackArea # rename AttackArea node
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var facing = 1 # 1 is right, -1 is left
var is_attacking = false

func _ready():
	attack_area.monitoring = false
	anim.play("idle")

# _physics_process() is called by the engine every tick
# we use this instead of _process so that physics is independent of framerate
func _physics_process(delta):
	# Handle falling
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Handle jumping
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		
	# Handle horizontal movement
	var direction = Input.get_axis("move_left", "move_right")
	if direction != 0:
		facing = sign(direction)
		velocity.x = direction * move_speed
	else:
		velocity.x = 0
		
	anim.flip_h = (facing == -1) # flip sprite when player is facing left
	attack_area.position.x = abs(attack_area.position.x) * facing
	
	# Handle attacking
	if Input.is_action_just_pressed("attack"):
		do_attack()
	
	# Pick an animation
	if not is_attacking:
		if not is_on_floor():
			if velocity.y < 0:
				play_anim("jump")
			else:
				play_anim("fall")
		elif abs(velocity.x) > 0:
			play_anim("run")
		else:
			play_anim("idle")
	
	# move_and_slide() takes our velocity and handles collision
	move_and_slide()
	
func play_anim(anim_name: String):
	if anim.animation != anim_name:
		anim.play(anim_name)
	
func do_attack():
	is_attacking = true
	attack_area.monitoring = true
	await get_tree().physics_frame
	
	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			body.queue_free()
			
	await get_tree().create_timer(attack_duration).timeout
	attack_area.monitoring = false
	
	is_attacking = false
