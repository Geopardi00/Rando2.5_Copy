extends Node

const IMPLEMENTED_FEATURES := {
	"level_01_layout": true,
	"player_movement": true,
	"jump_with_coyote_and_buffer": true,
	"shooting_with_fire_rate": true,
	"enemy_patrol_ai": true,
	"bullet_enemy_damage": true,
	"player_respawn_on_hit": true,
	"checkpoint_respawn": true,
	"player_slap_attack": true,
	"mosquito_harassment_enemy": true,
	"mosquito_swatting_state": true,
	"non_lethal_mosquito_swarm": true,
	"gameplay_freeze_frame": true,
}

var session_unix_time: float = Time.get_unix_time_from_system()
var level_name: String = ""
var spawn_position: Vector2 = Vector2.ZERO
var player_position: Vector2 = Vector2.ZERO
var player_velocity: Vector2 = Vector2.ZERO
var player_facing: int = 1
var goal_reached: bool = false
var enemies_total: int = 0
var enemies_defeated: int = 0
var shots_fired: int = 0
var bullet_hits: int = 0
var player_deaths: int = 0
var last_respawn_position: Vector2 = Vector2.ZERO
var checkpoint_active: bool = false
var checkpoint_level_name: String = ""
var checkpoint_position: Vector2 = Vector2.ZERO


func reset_runtime_state() -> void:
	goal_reached = false
	enemies_defeated = 0
	shots_fired = 0
	bullet_hits = 0
	player_deaths = 0
	last_respawn_position = Vector2.ZERO


func register_level_start(new_level_name: String, new_spawn_position: Vector2, new_enemies_total: int) -> void:
	if level_name != "" and level_name != new_level_name:
		clear_checkpoint()

	level_name = new_level_name
	spawn_position = new_spawn_position
	player_position = get_respawn_position(new_level_name, new_spawn_position)
	enemies_total = max(new_enemies_total, 0)
	reset_runtime_state()


func activate_checkpoint(new_level_name: String, new_checkpoint_position: Vector2) -> void:
	checkpoint_active = true
	checkpoint_level_name = new_level_name
	checkpoint_position = new_checkpoint_position
	last_respawn_position = new_checkpoint_position


func get_respawn_position(current_level_name: String, fallback_position: Vector2) -> Vector2:
	if checkpoint_active and checkpoint_level_name == current_level_name:
		return checkpoint_position

	return fallback_position


func clear_checkpoint() -> void:
	checkpoint_active = false
	checkpoint_level_name = ""
	checkpoint_position = Vector2.ZERO


func update_player_snapshot(new_position: Vector2, new_velocity: Vector2, new_facing: int) -> void:
	player_position = new_position
	player_velocity = new_velocity
	player_facing = sign(new_facing) if new_facing != 0 else player_facing


func register_shot_fired() -> void:
	shots_fired += 1


func register_bullet_hit() -> void:
	bullet_hits += 1


func register_enemy_defeated() -> void:
	enemies_defeated += 1
	if enemies_total > 0:
		enemies_defeated = min(enemies_defeated, enemies_total)


func register_player_died(respawn_position: Vector2) -> void:
	player_deaths += 1
	last_respawn_position = respawn_position


func register_goal_reached() -> void:
	goal_reached = true


func build_state_dictionary() -> Dictionary:
	return {
		"implemented_features": IMPLEMENTED_FEATURES.duplicate(true),
		"runtime_state": {
			"session_unix_time": session_unix_time,
			"level_name": level_name,
			"spawn_position": _vec2_to_dictionary(spawn_position),
			"player_position": _vec2_to_dictionary(player_position),
			"player_velocity": _vec2_to_dictionary(player_velocity),
			"player_facing": player_facing,
			"goal_reached": goal_reached,
			"enemies_total": enemies_total,
			"enemies_defeated": enemies_defeated,
			"shots_fired": shots_fired,
			"bullet_hits": bullet_hits,
			"player_deaths": player_deaths,
			"last_respawn_position": _vec2_to_dictionary(last_respawn_position),
			"checkpoint_active": checkpoint_active,
			"checkpoint_level_name": checkpoint_level_name,
			"checkpoint_position": _vec2_to_dictionary(checkpoint_position),
		},
	}


func _vec2_to_dictionary(value: Vector2) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y,
	}
