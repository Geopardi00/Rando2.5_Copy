extends Node

var failures: int = 0
var splash_events: int = 0
var last_splash_strength: float = 0.0


func _ready() -> void:
	run_test()


func run_test() -> void:
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	var water_scene := load("res://scenes/water/water_body_2d.tscn") as PackedScene
	var level_scene := load("res://scenes/levels/test_room_water.tscn") as PackedScene
	var crate_scene := load("res://scenes/props/push_crate.tscn") as PackedScene
	var game_ui_scene := load("res://scenes/ui/game_ui.tscn") as PackedScene
	check(player_scene != null, "Player scene should load.")
	check(water_scene != null, "Reusable water scene should load.")
	check(level_scene != null, "Water test room should load.")
	check(crate_scene != null, "Push crate scene should load.")
	check(game_ui_scene != null, "Game UI scene should load.")
	if player_scene == null or water_scene == null or level_scene == null or crate_scene == null or game_ui_scene == null:
		finish_test()
		return

	var player := player_scene.instantiate()
	var game_ui := game_ui_scene.instantiate()
	game_ui.underwater_vignette_color = Color(0.02, 0.25, 0.95, 0.6)
	game_ui.underwater_vignette_pulse_count = 2
	game_ui.underwater_vignette_pulse_duration = 0.05
	var pool := water_scene.instantiate()
	var tunnel := water_scene.instantiate()
	tunnel.has_visible_surface = false
	tunnel.ripple_enabled = false
	tunnel.position = Vector2(1000.0, 0.0)
	add_child(pool)
	add_child(tunnel)
	add_child(player)
	add_child(game_ui)
	await get_tree().process_frame
	player.set_physics_process(false)
	game_ui.bind_player(player)

	check(pool.water_area.collision_mask == 2, "Water body detection should scan the player layer.")
	check(pool.water_head_area.collision_mask == 256, "Water head detection should scan only the head-sensor layer.")
	check(pool.water_shape.position.y == pool.water_size.y * 0.5, "Water volume should extend downward from its surface origin.")
	check(pool.water_fill.position == Vector2.ZERO and pool.water_fill.scale == Vector2.ONE, "Water fill should use generated geometry without inherited transform distortion.")
	check(pool.water_surface.position == Vector2.ZERO and pool.water_surface.scale == Vector2.ONE, "Water surface should use generated geometry without inherited transform distortion.")
	var shader_texture_size: Vector2 = pool.shader_rectangle.texture.get_size()
	check(pool.shader_rectangle.position == Vector2(0.0, pool.water_size.y * 0.5), "Underwater shader rectangle should remain centered below the surface.")
	check(pool.shader_rectangle.scale.is_equal_approx(pool.water_size / shader_texture_size), "Underwater shader rectangle should match Water Size.")
	var original_water_size: Vector2 = pool.water_size
	pool.water_size = Vector2(640.0, 240.0)
	check((pool.water_shape.shape as RectangleShape2D).size == pool.water_size, "Changing Water Size should resize the body collision immediately.")
	check((pool.water_head_shape.shape as RectangleShape2D).size == pool.water_size, "Changing Water Size should resize the head-sensor collision immediately.")
	check(pool.water_fill.polygon[-1] == Vector2(-320.0, 240.0), "Changing Water Size should regenerate the fill geometry immediately.")
	check(pool.water_surface.points[0].x == -320.0 and pool.water_surface.points[-1].x == 320.0, "Changing Water Size should regenerate the ripple surface immediately.")
	check(pool.shader_rectangle.position == Vector2(0.0, 120.0), "Changing Water Size should reposition the shader rectangle immediately.")
	check(pool.shader_rectangle.scale.is_equal_approx(pool.water_size / shader_texture_size), "Changing Water Size should resize the shader rectangle immediately.")
	pool.water_size = original_water_size
	check(not tunnel.water_surface.visible, "Flooded tunnel should not draw a false surface.")
	check(pool.is_in_group("water_body"), "Reusable water bodies should register for geometric overlap reconciliation.")
	check(not pool.splash_particles.emitting, "Legacy splash particles should remain inactive.")
	check(pool.splash_particles.process_mode == Node.PROCESS_MODE_DISABLED, "Legacy splash particles should remain disabled.")
	check(pool.bubble_particles != null and pool.bubble_particles.texture != null, "Underwater bubble particles should remain available.")
	var original_player_material: Material = player.animated_sprite.material
	player.reset_water_state()
	pool.player_underwater_shader_enabled = true
	player.enter_water(pool)
	var player_frames: SpriteFrames = player.animated_sprite.sprite_frames
	check(player_frames.has_animation(&"swim"), "Player sprite frames should include the swim animation.")
	check(player_frames.get_frame_count(&"swim") == 15, "Swim animation should include all 15 imported frames.")
	check(player_frames.get_animation_loop(&"swim"), "Swim animation should loop while movement input is held.")
	check(player_frames.has_animation(&"swim_idle"), "Player sprite frames should include the water-idle pose.")
	check(player_frames.get_frame_count(&"swim_idle") == 1, "Water idle should use one swim frame.")
	check(player_frames.get_frame_texture(&"swim_idle", 0) == player_frames.get_frame_texture(&"swim", 0), "Water idle should use the first swim frame.")
	Input.action_press("move_right")
	player.update_animation()
	Input.action_release("move_right")
	check(player.animated_sprite.animation == &"swim", "Directional input in water should play the swim animation.")
	player.update_animation()
	check(player.animated_sprite.animation == &"swim_idle", "Neutral input in water should use the first swim frame.")
	check(player.player_underwater_shader_active, "An enabled water body should activate the player-only underwater shader.")
	check(player.animated_sprite.material == player.player_underwater_material, "The underwater effect should apply only to the animated player sprite.")
	check(is_equal_approx(float(player.player_underwater_material.get_shader_parameter(&"wobble_strength")), pool.player_underwater_wobble_strength), "The player shader should use the active water body's wobble tuning.")
	player.is_surface_swimming = true
	player.update_player_underwater_shader()
	check(not player.player_underwater_shader_active, "Reaching the swimming surface should disable the player shader before becoming airborne.")
	check(player.animated_sprite.material == original_player_material, "Surface swimming should restore the player's original sprite material.")
	player.is_surface_swimming = false
	player.surface_jump_active = true
	player.update_player_underwater_shader()
	check(not player.player_underwater_shader_active, "A surface jump should keep the player shader disabled while leaving the water collider.")
	player.surface_jump_active = false
	player.finish_water_exit(pool)
	check(not player.player_underwater_shader_active, "Leaving the last affected water body should disable the player shader.")
	check(player.animated_sprite.material == original_player_material, "Leaving water should restore the player's original sprite material.")
	pool.player_underwater_shader_enabled = false
	pool.submerged_players.append(player)
	player.global_position = pool.global_position + Vector2(0.0, 100.0)
	pool.update_bubbles(0.1)
	check(pool.active_bubbles.size() == 1, "Submerged players should emit individual bubbles.")
	pool.spawn_bubble(pool.global_position + Vector2(0.0, 10.0))
	pool.update_active_bubbles(0.01)
	var deep_bubble := pool.active_bubbles[0].get("sprite") as Sprite2D
	var surface_bubble := pool.active_bubbles[1].get("sprite") as Sprite2D
	check(surface_bubble.modulate.a < deep_bubble.modulate.a, "Each bubble should fade independently as it approaches the visible surface.")
	surface_bubble.global_position.y = pool.global_position.y - 1.0
	pool.update_active_bubbles(0.01)
	check(pool.active_bubbles.size() == 1 and pool.active_bubbles[0].get("sprite") == deep_bubble, "A bubble touching the surface should disappear without removing deeper bubbles.")
	pool.submerged_players.clear()
	tunnel.submerged_players.append(player)
	player.global_position = tunnel.global_position + Vector2(0.0, 10.0)
	tunnel.update_bubbles(0.1)
	check(tunnel.active_bubbles.size() == 1, "Flooded-tunnel bubbles should remain available without a visible surface.")
	tunnel.submerged_players.clear()
	tunnel.update_bubbles(0.1)

	var test_room := level_scene.instantiate()
	var test_crate := test_room.get_node_or_null("WaterImpactCrate") as RigidBody2D
	check(test_crate != null, "Water test room should include a push crate for manual impact testing.")
	if test_crate != null:
		check((test_crate.collision_mask & 1) != 0, "Water test crate should collide with world geometry.")
	test_room.free()

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
	player.breath_elapsed = 1.25
	player.set_head_submerged(tunnel, true)
	check(is_equal_approx(player.breath_elapsed, 1.25), "Repeated submerged overlap reports should not reset elapsed breath.")

	player.current_hp = player.max_hp
	var configured_breath: float = tunnel.breath_duration
	var configured_damage_interval: float = tunnel.damage_interval
	player.breath_elapsed = 0.0
	player.next_drowning_damage_time = configured_breath
	player.update_water_breath(configured_breath - 0.01)
	check(player.current_hp == player.max_hp, "Drowning should not damage before the configured breath duration.")
	player.update_water_breath(0.02)
	check(player.current_hp == player.max_hp - 1, "First drowning damage should occur at the configured breath duration.")
	check(game_ui.damage_vignette.color.is_equal_approx(game_ui.underwater_vignette_color), "Drowning damage should use the configured underwater vignette color.")
	check(game_ui.damage_vignette_tween != null, "Drowning damage should start the underwater vignette pulse sequence.")
	player.update_water_breath(configured_damage_interval - 0.02)
	check(player.current_hp == player.max_hp - 1, "Repeat drowning damage should wait for the configured interval.")
	player.update_water_breath(0.02)
	check(player.current_hp == player.max_hp - 2, "Drowning should bypass unrelated invulnerability on its configured cycle.")
	await get_tree().create_timer(0.14).timeout
	check(game_ui.damage_vignette.modulate.a <= 0.001, "Underwater vignette should fade out after the configured pulse count and duration.")
	check(game_ui.damage_vignette.color.is_equal_approx(game_ui.default_damage_vignette_color), "Underwater vignette should restore the normal damage color after pulsing.")

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

	var wave_pool := water_scene.instantiate()
	wave_pool.position = Vector2(3000.0, 0.0)
	add_child(wave_pool)
	await get_tree().process_frame
	wave_pool.set_physics_process(false)
	var center_index: int = roundi(float(wave_pool.ripple_heights.size() - 1) * 0.5)

	wave_pool.configure_ripple()
	wave_pool.apply_ripple_impulse(wave_pool.global_position.x, 180.0)
	wave_pool.update_ripple(1.0 / 60.0)
	var localized_height: float = absf(wave_pool.ripple_heights[center_index])
	check(localized_height > 1.0, "A surface impact should visibly displace the nearest spring by more than one pixel.")
	var neighbor_motion: float = absf(wave_pool.ripple_heights[center_index - 1]) + absf(wave_pool.ripple_heights[center_index + 1])
	check(neighbor_motion > 0.001, "Neighbor springs should move during propagation passes.")

	wave_pool.configure_ripple()
	wave_pool.apply_ripple_impulse(wave_pool.global_position.x, 120.0)
	wave_pool.update_ripple(1.0 / 60.0)
	var downward_height: float = wave_pool.ripple_heights[center_index]
	wave_pool.configure_ripple()
	wave_pool.apply_ripple_impulse(wave_pool.global_position.x, -120.0)
	wave_pool.update_ripple(1.0 / 60.0)
	var upward_height: float = wave_pool.ripple_heights[center_index]
	check(downward_height > 0.0 and upward_height < 0.0, "Entry and resurfacing should initially displace the surface in opposite directions.")

	var unsaturated_speed: float = wave_pool.ripple_maximum_impact_speed / maxf(wave_pool.ripple_impact_scale, 0.001)
	wave_pool.configure_ripple()
	wave_pool.apply_ripple_impulse(wave_pool.global_position.x, unsaturated_speed * 0.15)
	wave_pool.update_ripple(1.0 / 60.0)
	var slow_wave_height := maximum_absolute(wave_pool.ripple_heights)
	wave_pool.configure_ripple()
	wave_pool.apply_ripple_impulse(wave_pool.global_position.x, unsaturated_speed * 0.45)
	wave_pool.update_ripple(1.0 / 60.0)
	var fast_wave_height := maximum_absolute(wave_pool.ripple_heights)
	check(fast_wave_height > slow_wave_height, "Faster player impacts should produce larger waves.")

	var initial_wave_height := fast_wave_height
	for frame in 600:
		wave_pool.update_ripple(1.0 / 60.0, false)
	var settled_wave_height := maximum_absolute(wave_pool.ripple_heights)
	check(settled_wave_height < initial_wave_height * 0.25, "Spring waves should decay toward their rest height.")

	wave_pool.configure_ripple()
	wave_pool.apply_ripple_impulse(wave_pool.global_position.x, 100000.0)
	for frame in 120:
		wave_pool.update_ripple(1.0 / 60.0, false)
	check(ripple_values_are_stable(wave_pool), "Spring values should remain finite and respect configured clamps.")

	wave_pool.configure_ripple()
	player.global_position = wave_pool.global_position
	player.velocity.y = unsaturated_speed * 0.2
	wave_pool.splash_cooldowns.clear()
	var player_impulse: float = absf(wave_pool.create_surface_splash(player, true))
	var impact_crate := crate_scene.instantiate() as RigidBody2D
	impact_crate.freeze = true
	add_child(impact_crate)
	impact_crate.global_position = wave_pool.global_position
	impact_crate.linear_velocity.y = unsaturated_speed * 0.2
	wave_pool.configure_ripple()
	wave_pool.splash_cooldowns.clear()
	var crate_impulse: float = absf(wave_pool.create_surface_splash(impact_crate, true))
	check(crate_impulse > player_impulse, "A crate impact should use mass-scaled momentum and exceed an equal-speed player impact.")

	wave_pool.configure_ripple()
	wave_pool.splash_cooldowns.clear()
	wave_pool.tracked_surface_positions.clear()
	wave_pool.surface_crossed.connect(_on_surface_crossed)
	var events_before_crate_crossing := splash_events
	impact_crate.global_position = wave_pool.global_position + Vector2(0.0, -30.0)
	impact_crate.linear_velocity.y = 140.0
	wave_pool.update_surface_crossings()
	impact_crate.global_position.y = wave_pool.global_position.y - 15.0
	impact_crate.linear_velocity.y = 20.0
	wave_pool.update_surface_crossings()
	wave_pool.update_surface_crossings()
	check(splash_events == events_before_crate_crossing + 1, "One crate surface crossing should emit one deduplicated event.")
	check(last_splash_strength > 150.0, "Crate entry should retain the stronger pre-crossing velocity before applying mass.")

	var tunnel_height_before := maximum_absolute(tunnel.ripple_heights)
	tunnel.apply_ripple_impulse(tunnel.global_position.x, 220.0, 2.0)
	tunnel.update_ripple(1.0 / 60.0)
	check(is_equal_approx(maximum_absolute(tunnel.ripple_heights), tunnel_height_before), "Flooded-tunnel water should remain flat.")
	impact_crate.queue_free()
	wave_pool.queue_free()

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
	surface_player.exit_water(pool, pool.global_position.y, true)
	check(is_equal_approx(surface_player.velocity.y, -35.0), "A duplicate surface-exit notification should not cancel upward velocity.")
	check(not surface_player.is_surface_swimming and surface_player.surface_recovery_water_body == null, "A duplicate surface-exit notification should not enter recovery.")

	surface_player.global_position = pool.global_position + Vector2(0.0, 30.0)
	surface_player.velocity = Vector2.ZERO
	surface_player.enter_water(pool)
	surface_player.is_surface_swimming = false
	surface_player.surface_water_body = null
	Input.action_press("jump")
	surface_player.update_swimming(0.1)
	Input.action_release("jump")
	check(surface_player.surface_jump_active, "Jump near a visible surface should launch even when surface holding is inactive.")
	check(is_equal_approx(surface_player.velocity.y, -pool.surface_exit_boost), "Near-surface Jump should use the full configured exit boost on its first press.")
	surface_player.exit_water(pool, pool.global_position.y, true)

	var configured_jump_distance: float = surface_player.surface_jump_distance
	surface_player.surface_jump_distance = 0.0
	surface_player.global_position = pool.global_position + Vector2(0.0, 15.0)
	surface_player.velocity = Vector2.ZERO
	surface_player.enter_water(pool)
	Input.action_press("jump")
	surface_player.update_swimming(0.1)
	Input.action_release("jump")
	check(not surface_player.surface_jump_active, "The fallback test should begin as an ordinary underwater jump.")
	surface_player.global_position.y = pool.global_position.y - 1.0
	surface_player.exit_water(pool, pool.global_position.y, true)
	check(not surface_player.is_in_water(), "A Jump-requested surface crossing should leave water instead of entering recovery.")
	check(is_equal_approx(surface_player.velocity.y, -pool.surface_exit_boost), "A Jump-requested surface crossing should be promoted to the full exit boost.")
	surface_player.surface_jump_distance = configured_jump_distance

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

	var original_pool_breath_duration: float = pool.breath_duration
	var original_pool_damage_interval: float = pool.damage_interval
	pool.breath_duration = 0.05
	pool.damage_interval = 0.05
	var overlap_player := player_scene.instantiate()
	overlap_player.position = Vector2(520.0, -100.0)
	add_child(overlap_player)
	await get_tree().create_timer(0.06).timeout
	overlap_player.global_position = Vector2(0.0, 100.0)
	overlap_player.velocity = Vector2.ZERO
	await get_tree().create_timer(0.12).timeout
	check(overlap_player.is_in_water(), "WaterArea body overlap should enter swimming automatically.")
	check(overlap_player.is_head_submerged(), "WaterArea head-sensor overlap should start breath tracking automatically.")
	check(overlap_player.current_hp < overlap_player.max_hp, "Continuous submerged overlap reconciliation should allow breath to expire and deal drowning damage.")
	overlap_player.global_position = Vector2(520.0, -100.0)
	await get_tree().create_timer(0.12).timeout
	check(not overlap_player.is_in_water(), "Leaving the WaterArea should exit swimming automatically.")
	check(not overlap_player.is_head_submerged(), "Leaving the WaterArea should reset head submersion automatically.")
	pool.breath_duration = original_pool_breath_duration
	pool.damage_interval = original_pool_damage_interval

	finish_test()


func _on_surface_crossed(_body: Node2D, _position: Vector2, strength: float, _entering: bool) -> void:
	splash_events += 1
	last_splash_strength = strength


func maximum_absolute(values: PackedFloat32Array) -> float:
	var maximum_value := 0.0
	for value in values:
		maximum_value = maxf(maximum_value, absf(value))
	return maximum_value


func ripple_values_are_stable(water_body: WaterBody2D) -> bool:
	for value in water_body.ripple_heights:
		if not is_finite(value) or absf(value) > water_body.ripple_maximum_height + 0.001:
			return false
	for value in water_body.ripple_velocities:
		if not is_finite(value) or absf(value) > water_body.ripple_maximum_impact_speed + 0.001:
			return false
	return true


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
