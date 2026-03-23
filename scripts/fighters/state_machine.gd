class_name StateMachine
extends Node
## Generic state machine. Add FighterState children to define available states.
## The first child state (or the one set as initial_state) becomes active on _ready.

@export var initial_state: FighterState

var current_state: FighterState
var states: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		if child is FighterState:
			states[child.name.to_lower()] = child
			child.transitioned.connect(_on_state_transition)
	if initial_state:
		initial_state.enter()
		current_state = initial_state
	elif states.size() > 0:
		current_state = states.values()[0]
		current_state.enter()

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

func _on_state_transition(new_state_name: String) -> void:
	var new_state: FighterState = states.get(new_state_name.to_lower())
	if new_state == null or new_state == current_state:
		return
	current_state.exit()
	new_state.enter()
	current_state = new_state
