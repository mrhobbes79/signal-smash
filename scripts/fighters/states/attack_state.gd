class_name AttackState
extends FighterState
## Fighter performing a basic attack. Activates hitbox for a short window.

const ATTACK_DURATION: float = 0.35
const HITBOX_START: float = 0.1    ## Hitbox activates after this delay
const HITBOX_END: float = 0.25     ## Hitbox deactivates after this time
const ATTACK_DAMAGE: float = 8.0
const ATTACK_KNOCKBACK: float = 3.0
const ATTACK_LUNGE: float = 3.0    ## Forward movement during attack

var _timer: float = 0.0
var _has_hit: bool = false

func enter() -> void:
	_timer = 0.0
	_has_hit = false

	if fighter == null:
		return

	# Attack SFX
	if fighter.has_node("/root/AudioManager"):
		fighter.get_node("/root/AudioManager").play_sfx("hit_heavy", -3.0)

	# Lunge forward
	var lunge_dir: float = 1.0 if fighter.facing_right else -1.0
	fighter.velocity.x += lunge_dir * ATTACK_LUNGE

	# Reset per-target hit tracking
	var hitbox: Area3D = fighter.get_node_or_null("Model/Hitbox")
	if not hitbox:
		hitbox = fighter.get_node_or_null("Hitbox")
	if hitbox:
		hitbox.set_meta("hit_targets", [])

	# Enable hitbox
	_set_hitbox_active(false)

func exit() -> void:
	_set_hitbox_active(false)

func physics_update(delta: float) -> void:
	if fighter == null:
		return
	_timer += delta

	# Activate hitbox during attack window
	if _timer >= HITBOX_START and _timer <= HITBOX_END:
		_set_hitbox_active(true)
	else:
		_set_hitbox_active(false)

	# Apply air friction during attack
	fighter.velocity.x *= fighter.AIR_FRICTION

	# Attack finished
	if _timer >= ATTACK_DURATION:
		if fighter.is_on_floor():
			transitioned.emit("idle")
		else:
			transitioned.emit("fall")

func _set_hitbox_active(active: bool) -> void:
	var hitbox: Area3D = fighter.get_node_or_null("Model/Hitbox")
	if not hitbox:
		hitbox = fighter.get_node_or_null("Hitbox")
	if hitbox:
		hitbox.monitoring = active
		# Visual feedback — make hitbox visible when active
		for child in hitbox.get_children():
			if child is MeshInstance3D:
				child.visible = active
