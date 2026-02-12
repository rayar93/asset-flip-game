extends CharacterBody2D

@export var move_speed = 300 # @export makes variables visible in the inspector
@export var jump_velocity = -400
@export var gravity = 1000

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
	velocity.x = direction * move_speed
	
	# move_and_slide() takes our velocity and handles collision
	move_and_slide()

""" Below is the default script for CharacterBody2D, for reference.

const SPEED = 300.0
const JUMP_VELOCITY = -400.0


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
"""
