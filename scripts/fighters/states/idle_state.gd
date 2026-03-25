class_name IdleState
extends FighterState
## Fighter standing still, waiting for input.

func enter() -> void:
	if fighter:
		fighter.velocity.x = 0.0
		fighter.velocity.z = 0.0

func physics_update(delta: float) -> void:
	if fighter == null:
		return
	fighter.read_input()

	# Transition to run if moving
	if fighter.input_direction.length() > 0.1:
		transitioned.emit("run")
		return

	# Apply friction
	fighter.velocity.x *= fighter.FRICTION
	fighter.velocity.z *= fighter.FRICTION

	# Gamepad button checks (for controllers)
	if fighter.device_id >= 0:
		if fighter.is_device_button_pressed(JOY_BUTTON_A) and fighter.is_on_floor():
			transitioned.emit("jump")
		elif fighter.is_device_button_pressed(JOY_BUTTON_X):
			transitioned.emit("attack")

func handle_input(event: InputEvent) -> void:
	if fighter and fighter.device_id >= 0:
		return  # Gamepad fighters handle input in physics_update
	if event.is_action_pressed("jump") and fighter.is_on_floor():
		transitioned.emit("jump")
	elif event.is_action_pressed("attack"):
		transitioned.emit("attack")
