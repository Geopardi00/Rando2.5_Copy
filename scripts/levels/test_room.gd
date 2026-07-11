extends Node2D

@onready var player: Node = $Player
@onready var game_ui: Node = $GameUI


func _ready() -> void:
	if game_ui != null and game_ui.has_method("bind_player"):
		game_ui.call("bind_player", player)
