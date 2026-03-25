class_name FallState
extends FighterState
## Fighter falling / in the air with negative velocity.

func physics_update(delta: float) -> void:
	if fighter == null:
		return
	fighter.read_input()

	# Air movement
	fighter.velocity.x = lerpf(fighter.velocity.x, fighter.input_direction.x * fighter.MOVE_SPEED, 0.1)
	fighter.velocity.z = lerpf(fighter.velocity.z, fighter.input_direction.z * fighter.MOVE_SPEED, 0.1)

	# Landed
	if fighter.is_on_floor():
		transitioned.emit("idle")

	# Gamepad buttons
	if fighter.device_id >= 0:
		if fighter.is_device_button_pressed(JOY_BUTTON_A) and fighter.can_double_jump:
			fighter.can_double_jump = false
			fighter.velocity.y = fighter.DOUBLE_JUMP_FORCE
			transitioned.emit("jump")
		elif fighter.is_device_button_pressed(JOY_BUTTON_X):
			transitioned.emit("attack")

func handle_input(event: InputEvent) -> void:
	if fighter and fighter.device_id >= 0:
		return
	if event.is_action_pressed("jump") and fighter.can_double_jump:
		fighter.can_double_jump = false
		fighter.velocity.y = fighter.DOUBLE_JUMP_FORCE
		transitioned.emit("jump")
	elif event.is_action_pressed("attack"):
		transitioned.emit("attack")
