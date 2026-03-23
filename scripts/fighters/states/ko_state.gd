class_name KOState
extends FighterState
## Fighter is KO'd — LINK DOWN. Disable all input, play death animation.

const RESPAWN_DELAY: float = 3.0
var _timer: float = 0.0

func enter() -> void:
	_timer = 0.0
	fighter.is_invincible = true
	fighter.velocity = Vector3.ZERO
	print("[FIGHT] Player %d LINK DOWN! Signal: %.0f%%" % [fighter.player_id, fighter.signal_percent])

func physics_update(delta: float) -> void:
	_timer += delta
	# Could auto-respawn or wait for game manager
	# For now just sit in KO state
	fighter.velocity.x *= 0.9
	fighter.velocity.z *= 0.9
