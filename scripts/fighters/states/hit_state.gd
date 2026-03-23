class_name HitState
extends FighterState
## Fighter reacting to being hit — stunned and knocked back.

func enter() -> void:
	pass  # Knockback already applied in take_damage()

func physics_update(delta: float) -> void:
	if fighter == null:
		return
	# Apply air friction to slow knockback
	fighter.velocity.x *= 0.95
	fighter.velocity.z *= 0.95

	# Exit hitstun when timer expires and grounded
	if fighter.hitstun_timer <= 0.0:
		if fighter.is_on_floor():
			transitioned.emit("idle")
		else:
			transitioned.emit("fall")
