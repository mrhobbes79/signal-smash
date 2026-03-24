class_name JumpState
extends FighterState
## Fighter jumping upward.

func enter() -> void:
	if fighter:
		fighter.velocity.y = fighter.JUMP_FORCE
		fighter.is_grounded = false
		if Engine.has_singleton("AudioManager") or fighter.has_node("/root/AudioManager"):
			fighter.get_node("/root/AudioManager").play_sfx("jump")

func physics_update(delta: float) -> void:
	if fighter == null:
		return
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
