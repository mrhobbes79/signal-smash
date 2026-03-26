class_name RunState
extends FighterState
## Fighter moving on the ground.

func physics_update(delta: float) -> void:
	if fighter == null:
		return
	fighter.read_input()

	# Apply movement (equipment speed modifier)
	var spd: float = fighter.get_move_speed()
	fighter.velocity.x = fighter.input_direction.x * spd
	fighter.velocity.z = fighter.input_direction.z * spd

	# Transition to idle if no input
	if fighter.input_direction.length() < 0.1:
		transitioned.emit("idle")
		return

	# Transition to fall if walking off edge
	if not fighter.is_on_floor():
		transitioned.emit("fall")

	# Gamepad buttons
	if fighter.device_id >= 0:
		if fighter.is_device_button_pressed(JOY_BUTTON_A) and fighter.is_on_floor():
			transitioned.emit("jump")
		elif fighter.is_device_button_pressed(JOY_BUTTON_X):
			transitioned.emit("attack")
		elif fighter.is_device_button_pressed(JOY_BUTTON_Y):
			fighter.activate_special()

func handle_input(event: InputEvent) -> void:
	if fighter and fighter.device_id >= 0:
		return
	if event.is_action_pressed("jump") and fighter.is_on_floor():
		transitioned.emit("jump")
	elif event.is_action_pressed("attack"):
		transitioned.emit("attack")
