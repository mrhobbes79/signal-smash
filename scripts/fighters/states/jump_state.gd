class_name JumpState
extends FighterState
## Fighter jumping upward.

func enter() -> void:
	fighter.velocity.y = fighter.JUMP_FORCE
	fighter.is_grounded = false

func physics_update(delta: float) -> void:
	fighter.read_input()

	# Air movement (reduced control)
	fighter.velocity.x = lerpf(fighter.velocity.x, fighter.input_direction.x * fighter.MOVE_SPEED, 0.1)
	fighter.velocity.z = lerpf(fighter.velocity.z, fighter.input_direction.z * fighter.MOVE_SPEED, 0.1)

	# Transition to fall when velocity goes negative
	if fighter.velocity.y <= 0.0:
		transitioned.emit("fall")
		return

	# Landed
	if fighter.is_on_floor():
		transitioned.emit("idle")

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") and fighter.can_double_jump:
		fighter.can_double_jump = false
		fighter.velocity.y = fighter.DOUBLE_JUMP_FORCE
	elif event.is_action_pressed("attack"):
		transitioned.emit("attack")
