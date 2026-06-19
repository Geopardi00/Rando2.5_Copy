extends Node2D

@onready var goal: Area2D = $Goal
@onready var player: CharacterBody2D = $Player
@onready var player_spawn: Marker2D = $PlayerSpawn


func _ready() -> void:
	var level_id := scene_file_path.get_file().get_basename()
	var enemy_count := get_tree().get_nodes_in_group("enemy").size()
	var respawn_position := player_spawn.global_position
	var state := _get_state_of_game()

	if state != null and state.has_method("register_level_start"):
		state.register_level_start(level_id, player_spawn.global_position, enemy_count)

	if state != null and state.has_method("get_respawn_position"):
		respawn_position = state.get_respawn_position(level_id, player_spawn.global_position)

	player.global_position = respawn_position
	player.set("respawn_position", respawn_position)

	if not goal.body_entered.is_connected(_on_goal_body_entered):
		goal.body_entered.connect(_on_goal_body_entered)


func _on_goal_body_entered(body: Node) -> void:
	if body != player:
		return

	var state := _get_state_of_game()
	if state != null and state.has_method("register_goal_reached"):
		state.register_goal_reached()

	print("goal reached")


func _get_state_of_game() -> Node:
	return get_node_or_null("/root/StateOfGame")
