extends Node

var failures: int = 0
var splash_events: int = 0


func _ready() -> void:
	run_test()


func run_test() -> void:
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	var water_scene := load("res://scenes/water/water_body_2d.tscn") as PackedScene
	var level_scene := load("res://scenes/levels/test_room_water.tscn") as PackedScene
	check(player_scene != null, "Player scene should load.")
	check(water_scene != null, "Reusable water scene should load.")
	check(level_scene != null, "Water test room should load.")
	if player_scene == null or water_scene == null or level_scene == null:
		finish_test()
		return

	var player := player_scene.instantiate()
	var pool := water_scene.instantiate()
	var tunnel := water_scene.instantiate()
	tunnel.has_visible_surface = false
	tunnel.ripple_enabled = false
	tunnel.position = Vector2(1000.0, 0.0)
	add_child(pool)
	add_child(tunnel)
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)

	check(pool.water_area.collision_mask == 2, "Water body detection should scan the player layer.")
	check(pool.water_head_area.collision_mask == 256, "Water head detection should scan only the head-sensor layer.")
	check(pool.water_shape.position.y == pool.water_size.y * 0.5, "Water volume should extend downward from its surface origin.")
	check(not tunnel.water_surface.visible, "Flooded tunnel should not draw a false surface.")

	player.enter_water(pool)
	player.enter_water(tunnel)
	check(player.is_in_water(), "Entering water should enable swimming.")
	check(player.active_water_bodies.size() == 2, "Overlapping water volumes should both be tracked.")
	player.exit_water(pool, 0.0, false)
	check(player.is_in_water(), "Exiting one overlapping volume should keep swimming active.")

	player.set_head_submerged(pool, true)
	player.set_head_submerged(tunnel, true)
	player.set_head_submerged(pool, false)
	check(player.is_head_submerged(), "Leaving one overlapping head volume should not reset breath.")

	player.current_hp = player.max_hp
	var configured_breath: float = tunnel.breath_duration
	var configured_damage_interval: float = tunnel.damage_interval
	player.breath_elapsed = 0.0
	player.next_drowning_damage_time = configured_breath
	player.update_water_breath(configured_breath - 0.01)
	check(player.current_hp == player.max_hp, "Drowning should not damage before the configured breath duration.")
	player.update_water_breath(0.02)
	check(player.current_hp == player.max_hp - 1, "First drowning damage should occur at the configured breath duration.")
	player.update_water_breath(configured_damage_interval - 0.02)
	check(player.current_hp == player.max_hp - 1, "Repeat drowning damage should wait for the configured interval.")
	player.update_water_breath(0.02)
	check(player.current_hp == player.max_hp - 2, "Drowning should bypass unrelated invulnerability on its configured cycle.")

	player.velocity = Vector2.ZERO
	Input.action_press("move_right")
	Input.action_press("move_up")
	player.update_swimming(0.1)
	Input.action_release("move_right")
	Input.action_release("move_up")
	check(player.velocity.x > 0.0, "Swimming should respond horizontally.")
	check(player.velocity.y < 0.0, "Swimming should respond vertically.")

	pool.surface_crossed.connect(_on_surface_crossed)
	player.global_position = pool.global_position
	player.velocity.y = 360.0
	pool.create_surface_splash(player, true)
	check(splash_events == 1, "A fast surface entry should create one splash.")
	pool.create_surface_splash(player, true)
	check(splash_events == 1, "Splash cooldown should suppress duplicate crossings.")
	tunnel.create_surface_splash(player, true)
	check(splash_events == 1, "A flooded tunnel should not create surface splashes.")

	var ripple_active := false
	for ripple_velocity in pool.ripple_velocities:
		ripple_active = ripple_active or not is_zero_approx(ripple_velocity)
	check(ripple_active, "Surface splash should impulse the pool ripple.")

	player.set_head_submerged(tunnel, false)
	check(not player.is_head_submerged(), "Reaching air should clear head submersion.")
	check(is_zero_approx(player.breath_elapsed), "Reaching air should reset the breath timer.")
	player.exit_water(tunnel, 0.0, false)
	check(not player.is_in_water(), "Exiting the last water volume should restore land mode.")

	var overlap_player := player_scene.instantiate()
	overlap_player.position = Vector2(520.0, -100.0)
	add_child(overlap_player)
	await get_tree().create_timer(0.06).timeout
	overlap_player.global_position = Vector2(0.0, 100.0)
	overlap_player.velocity = Vector2.ZERO
	await get_tree().create_timer(0.12).timeout
	check(overlap_player.is_in_water(), "WaterArea body overlap should enter swimming automatically.")
	check(overlap_player.is_head_submerged(), "WaterArea head-sensor overlap should start breath tracking automatically.")
	overlap_player.global_position = Vector2(520.0, -100.0)
	await get_tree().create_timer(0.12).timeout
	check(not overlap_player.is_in_water(), "Leaving the WaterArea should exit swimming automatically.")
	check(not overlap_player.is_head_submerged(), "Leaving the WaterArea should reset head submersion automatically.")

	finish_test()


func _on_surface_crossed(_body: Node2D, _position: Vector2, _strength: float, _entering: bool) -> void:
	splash_events += 1


func check(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error(message)


func finish_test() -> void:
	if failures == 0:
		print("Water system smoke test passed.")
	else:
		push_error("Water system smoke test failed with %d error(s)." % failures)

	get_tree().quit(failures)
