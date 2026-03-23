class_name RunState
extends FighterState
## Fighter moving on the ground.

func physics_update(delta: float) -> void:
	fighter.read_input()

	# Apply movement
	fighter.velocity.x = fighter.input_direction.x * fighter.MOVE_SPEED
	fighter.velocity.z = fighter.input_direction.z * fighter.MOVE_SPEED

	# Transition to idle if no input
	if fighter.input_direction.length() < 0.1:
		transitioned.emit("idle")
		return

	# Transition to fall if walking off edge
	if not fighter.is_on_floor():
		transitioned.emit("fall")

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") and fighter.is_on_floor():
		transitioned.emit("jump")
	elif event.is_action_pressed("attack"):
		transitioned.emit("attack")
