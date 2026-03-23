class_name GameManager
extends Node
## Placeholder game manager for SIGNAL SMASH.
## Will handle game state, scene transitions, and global configuration.

enum GameState { MENU, CHARACTER_SELECT, FIGHTING, MINI_GAME, VICTORY, SPECTATOR }

var current_state: GameState = GameState.MENU
var player_count: int = 0

func _ready() -> void:
	print("SIGNAL SMASH — Game Manager initialized")
