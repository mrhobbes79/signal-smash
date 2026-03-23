class_name IdleState
extends FighterState
## Fighter standing still, waiting for input.

func enter() -> void:
	fighter.velocity.x = 0.0
	fighter.velocity.z = 0.0

func physics_update(delta: float) -> void:
	fighter.read_input()

	# Transition to run if moving
	if fighter.input_direction.length() > 0.1:
		transitioned.emit("run")
		return

	# Apply friction
	fighter.velocity.x *= fighter.FRICTION
	fighter.velocity.z *= fighter.FRICTION

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") and fighter.is_on_floor():
		transitioned.emit("jump")
	elif event.is_action_pressed("attack"):
		transitioned.emit("attack")
