class_name FighterBase
extends CharacterBody3D
## Base fighter class. Handles physics, signal (health), knockback, and provides
## shared functionality for all characters.

## Movement constants
const MOVE_SPEED: float = 8.0
const JUMP_FORCE: float = 12.0
const DOUBLE_JUMP_FORCE: float = 10.0
const GRAVITY: float = 30.0
const FRICTION: float = 0.85
const AIR_FRICTION: float = 0.95
const MAX_FALL_SPEED: float = 25.0

## Combat constants
const KNOCKBACK_BASE: float = 5.0
const KNOCKBACK_GROWTH: float = 0.08
const HITSTUN_BASE: float = 0.2

## Signal (health) — 100% = full health, 0% = KO
var signal_percent: float = 100.0
var damage_accumulated: float = 0.0  ## Smash-style: more damage = more knockback

## State
var player_id: int = 0
var facing_right: bool = true
var can_double_jump: bool = true
var is_grounded: bool = false
var is_invincible: bool = false
var hitstun_timer: float = 0.0

## Input
var input_direction: Vector3 = Vector3.ZERO
var use_manual_input: bool = false  ## If true, skip read_input() — input set externally (P2)

## References
@onready var state_machine: StateMachine = $StateMachine
@onready var model: Node3D = $Model
@onready var hurtbox: Area3D = $Hurtbox

func _ready() -> void:
	# States resolve their fighter reference lazily via tree traversal
	pass

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		velocity.y = max(velocity.y, -MAX_FALL_SPEED)
	else:
		if not is_grounded:
			is_grounded = true
			can_double_jump = true

	if not is_on_floor():
		is_grounded = false

	# Hitstun countdown
	if hitstun_timer > 0.0:
		hitstun_timer -= delta

	move_and_slide()

	# Check ring-out (fell below arena)
	if global_position.y < -10.0:
		trigger_ko()

## Read movement input for this player's device
func read_input() -> void:
	if use_manual_input:
		return  # Input is set externally (e.g., P2 arrow keys)
	input_direction = Vector3.ZERO
	input_direction.x = Input.get_axis("move_left", "move_right")
	input_direction.z = Input.get_axis("move_forward", "move_back")

	# Update facing direction
	if input_direction.x > 0.1:
		facing_right = true
		if model:
			model.rotation_degrees.y = 0.0
	elif input_direction.x < -0.1:
		facing_right = false
		if model:
			model.rotation_degrees.y = 180.0

## Apply knockback force from a hit
func apply_knockback(direction: Vector3, base_force: float) -> void:
	var knockback_multiplier: float = 1.0 + (damage_accumulated * KNOCKBACK_GROWTH)
	var force: float = base_force * knockback_multiplier * KNOCKBACK_BASE
	velocity = direction.normalized() * force
	velocity.y = max(velocity.y, force * 0.5)  # Always some upward knockback
	hitstun_timer = HITSTUN_BASE * knockback_multiplier

## Take damage — increases damage_accumulated (Smash-style) and reduces signal
func take_damage(amount: float, attacker_position: Vector3, knockback_force: float) -> void:
	if is_invincible:
		return

	damage_accumulated += amount
	signal_percent = max(0.0, 100.0 - damage_accumulated)

	# Calculate knockback direction (away from attacker)
	var knock_dir: Vector3 = (global_position - attacker_position).normalized()
	if knock_dir.length() < 0.1:
		knock_dir = Vector3(1.0 if facing_right else -1.0, 0.5, 0.0)

	apply_knockback(knock_dir, knockback_force)

	# Transition to hit state
	if state_machine and state_machine.states.has("hit"):
		state_machine._on_state_transition("hit")

	# Check for KO
	if signal_percent <= 0.0:
		trigger_ko()

## KO — LINK DOWN
func trigger_ko() -> void:
	signal_percent = 0.0
	if state_machine and state_machine.states.has("ko"):
		state_machine._on_state_transition("ko")
	# Notify game manager
	print("[FIGHT] LINK DOWN: Player %d" % player_id)

## Reset fighter for new round
func reset_fighter() -> void:
	signal_percent = 100.0
	damage_accumulated = 0.0
	velocity = Vector3.ZERO
	hitstun_timer = 0.0
	is_invincible = false
	can_double_jump = true
	if state_machine and state_machine.states.has("idle"):
		state_machine._on_state_transition("idle")
