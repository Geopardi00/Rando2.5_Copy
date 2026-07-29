extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var game_ui: Node = $GameUI


func _ready() -> void:
	var level_id := scene_file_path.get_file().get_basename()
	var respawn_position := player_spawn.global_position
	var state := get_node_or_null("/root/StateOfGame")

	if state != null and state.has_method("register_level_start"):
		state.register_level_start(level_id, player_spawn.global_position, 0)
	if state != null and state.has_method("get_respawn_position"):
		respawn_position = state.get_respawn_position(level_id, player_spawn.global_position)

	if player.has_method("reset_water_state"):
		player.call("reset_water_state")
	player.global_position = respawn_position

	if game_ui != null and game_ui.has_method("bind_player"):
		game_ui.call("bind_player", player)
