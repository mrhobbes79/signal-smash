class_name FighterState
extends Node
## Base class for all fighter states. Override methods to define behavior.

signal transitioned(new_state: String)

## Reference to the fighter — resolved lazily through the tree
var fighter: CharacterBody3D:
	get:
		if fighter == null:
			# Walk up: State -> StateMachine -> Fighter
			var sm = get_parent()
			if sm:
				fighter = sm.get_parent() as CharacterBody3D
		return fighter

func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass
