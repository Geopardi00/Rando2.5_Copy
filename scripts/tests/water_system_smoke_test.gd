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
	check(pool.is_in_group("water_body"), "Reusable water bodies should register for geometric overlap reconciliation.")

	var geometry_player := player_scene.instantiate()
	add_child(geometry_player)
	await get_tree().process_frame
	geometry_player.set_physics_process(false)
	geometry_player.global_position = pool.global_position + Vector2(0.0, 100.0)
	check(pool.contains_body(geometry_player), "Visible water bounds should contain a player positioned below the surface.")
	geometry_player.reset_water_state()
	geometry_player.reconcile_water_overlaps()
	check(geometry_player.is_in_water(), "Geometric reconciliation should repair a missing Area2D water state while the player remains inside.")
	check(geometry_player.is_head_submerged(), "Geometric reconciliation should repair missing head-submersion state at depth.")
	var lost_water_while_ascending := false
	Input.action_press("move_up")
	for frame in 90:
		geometry_player.update_swimming(1.0 / 60.0)
		geometry_player.move_and_slide()
		geometry_player.reconcile_water_overlaps()
		lost_water_while_ascending = lost_water_while_ascending or not geometry_player.is_in_water()
		await get_tree().physics_frame
	Input.action_release("move_up")
	check(not lost_water_while_ascending, "Holding Up from underwater should never transition through airborne state.")
	check(geometry_player.is_surface_swimming, "Holding Up should reach the surface-swimming state without Jump.")
	var held_surface_y: float = geometry_player.global_position.y
	for frame in 12:
		geometry_player.update_swimming(1.0 / 60.0)
		geometry_player.move_and_slide()
		geometry_player.reconcile_water_overlaps()
		await get_tree().physics_frame
	check(not geometry_player.is_surface_swimming, "Releasing Up should release the surface boundary.")
	check(geometry_player.global_position.y > held_surface_y + 0.05, "Water gravity should make the player sink after releasing Up.")
	geometry_player.queue_free()

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

	pool.splash_cooldowns.erase(player)
	pool.tracked_surface_positions.erase(player)
	player.global_position = pool.global_position + Vector2(0.0, -40.0)
	player.velocity.y = 240.0
	pool.update_surface_crossings()
	player.global_position.y = pool.global_position.y - 20.0
	pool.update_surface_crossings()
	check(splash_events == 2, "Crossing the surface downward should create an entry ripple.")

	pool.splash_cooldowns.erase(player)
	player.global_position.y = pool.global_position.y + 30.0
	player.velocity.y = -100.0
	pool.update_surface_crossings()
	player.global_position.y = pool.global_position.y - 1.0
	pool.update_surface_crossings()
	check(splash_events == 3, "Swimming upward from depth should ripple when the player reaches the surface.")

	pool.splash_cooldowns.erase(player)
	var events_before_deep_exit := splash_events
	player.global_position.y = pool.global_position.y + 100.0
	pool._on_body_exited(player)
	check(splash_events == events_before_deep_exit, "A deep Area2D exit should not create an early surface ripple.")

	var ripple_active := false
	for ripple_velocity in pool.ripple_velocities:
		ripple_active = ripple_active or not is_zero_approx(ripple_velocity)
	check(ripple_active, "Surface splash should impulse the pool ripple.")

	player.set_head_submerged(tunnel, false)
	check(not player.is_head_submerged(), "Reaching air should clear head submersion.")
	check(is_zero_approx(player.breath_elapsed), "Reaching air should reset the breath timer.")
	player.exit_water(tunnel, 0.0, false)
	check(not player.is_in_water(), "Exiting the last water volume should restore land mode.")

	var surface_player := player_scene.instantiate()
	add_child(surface_player)
	await get_tree().process_frame
	surface_player.set_physics_process(false)
	var surface_target: float = pool.global_position.y - surface_player.surface_float_offset

	surface_player.global_position = Vector2(0.0, surface_target - 8.0)
	surface_player.velocity.y = surface_player.surface_entry_max_fall_speed + 120.0
	surface_player.enter_water(pool)
	check(not surface_player.is_surface_swimming, "A fast water entry should submerge instead of snapping to the surface.")
	check(surface_player.is_in_water(), "A fast entry should switch to swimming on the first body overlap.")
	surface_player.exit_water(pool, pool.global_position.y, false)

	surface_player.global_position = Vector2(0.0, surface_target - 8.0)
	surface_player.velocity.y = surface_player.surface_entry_max_fall_speed * 0.5
	Input.action_press("move_up")
	surface_player.enter_water(pool)
	check(surface_player.is_surface_swimming, "Holding Up during a gentle entry should capture the visible surface.")
	check(is_equal_approx(surface_player.get_applied_gravity(), surface_player.water_gravity * pool.gravity_multiplier), "Water gravity should remain active at the surface.")
	surface_player.global_position.y = surface_target + 4.0
	surface_player.update_surface_float(0.1, pool.vertical_swim_speed)
	check(is_equal_approx(surface_player.global_position.y + surface_player.velocity.y * 0.1, surface_target), "Surface movement should stop at the configured float target without overshooting.")
	Input.action_release("move_up")

	Input.action_press("move_down")
	surface_player.update_swimming(0.1)
	Input.action_release("move_down")
	check(not surface_player.is_surface_swimming, "Down input should release the surface hold for diving.")
	check(surface_player.velocity.y > 0.0, "Down input should move the player deeper into the water.")

	surface_player.global_position.y = surface_target + surface_player.surface_capture_distance
	surface_player.velocity.y = -20.0
	Input.action_press("move_up")
	surface_player.update_swimming(0.1)
	Input.action_release("move_up")
	check(surface_player.is_surface_swimming, "Swimming upward should capture the surface near its target.")
	Input.action_press("jump")
	surface_player.update_swimming(0.1)
	Input.action_release("jump")
	check(surface_player.surface_jump_active, "Jump at the surface should enter the intentional airborne phase.")
	check(is_equal_approx(surface_player.velocity.y, -pool.surface_exit_boost), "Surface jump should apply the configured exit boost once.")
	check(is_equal_approx(surface_player.get_applied_gravity(), surface_player.gravity), "Intentional jump-out should report airborne gravity while leaving water.")

	surface_player.velocity.y = -35.0
	surface_player.exit_water(pool, pool.global_position.y, true)
	check(is_equal_approx(surface_player.velocity.y, -35.0), "A generic surface exit should not apply an automatic boost.")
	check(not surface_player.surface_jump_active, "Leaving the water area should clear the jump-out override.")

	surface_player.global_position = Vector2(0.0, surface_target + surface_player.surface_capture_distance + 10.0)
	surface_player.velocity.y = -pool.vertical_swim_speed
	surface_player.enter_water(pool)
	Input.action_press("move_up")
	surface_player.prevent_unintentional_surface_exit(0.1, pool.vertical_swim_speed)
	Input.action_release("move_up")
	check(surface_player.is_surface_swimming, "An upward physics step that crosses the capture line should enter surface holding predictively.")
	check(surface_player.global_position.y + surface_player.velocity.y * 0.1 >= surface_target, "Predictive capture should prevent movement beyond the float target.")

	surface_player.is_surface_swimming = false
	surface_player.surface_water_body = null
	surface_player.velocity.y = -35.0
	surface_player.exit_water(pool, pool.global_position.y, true)
	check(surface_player.is_in_water() and surface_player.is_surface_swimming, "An unintended top exit should retain swimming during the recovery window.")
	check(surface_player.velocity.y >= 0.0, "Surface recovery should cancel upward escape without applying an airborne knockback.")
	surface_player.enter_water(pool)
	check(surface_player.surface_recovery_water_body == null, "Re-entering the water area should clear surface recovery.")
	surface_player.finish_water_exit(pool)

	surface_player.global_position = Vector2(tunnel.global_position.x, tunnel.global_position.y - 8.0)
	surface_player.velocity.y = 0.0
	surface_player.enter_water(tunnel)
	check(not surface_player.is_surface_swimming, "Water without a visible surface should not activate surface holding.")
	check(is_equal_approx(surface_player.get_applied_gravity(), surface_player.water_gravity * tunnel.gravity_multiplier), "Swimming should report the effective configured water gravity.")
	surface_player.exit_water(tunnel, tunnel.global_position.y, false)

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
