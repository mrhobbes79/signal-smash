class_name FighterState
extends Node
## Base class for all fighter states. Override methods to define behavior.

signal transitioned(new_state: String)

## Reference to the fighter CharacterBody3D — set by FighterBase on _ready
var fighter: FighterBase

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
