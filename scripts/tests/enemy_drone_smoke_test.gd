extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const DRONE_SCENE_PATH := "res://scenes/enemies/drone_enemy.tscn"
const DRONE_GRENADE_SCENE_PATH := "res://scenes/projectiles/drone_grenade.tscn"
const FINAL_BOSS_GRENADE_SCENE_PATH := "res://scenes/projectiles/final_boss_grenade.tscn"
const TEST_ROOM_SCENE_PATH := "res://scenes/levels/test_room.tscn"

const STATE_PATROL := 0
const STATE_TURN_PAUSE := 1
const STATE_ATTACK := 2

var failures: int = 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var drone_scene := load(DRONE_SCENE_PATH) as PackedScene
	var drone_grenade_scene := load(DRONE_GRENADE_SCENE_PATH) as PackedScene
	var final_boss_grenade_scene := load(FINAL_BOSS_GRENADE_SCENE_PATH) as PackedScene
	var test_room_scene := load(TEST_ROOM_SCENE_PATH) as PackedScene

	check(player_scene != null, "Player scene should load.")
	check(drone_scene != null, "Reusable drone scene should load.")
	check(drone_grenade_scene != null, "Drone grenade scene should load.")
	check(final_boss_grenade_scene != null, "Final Boss grenade scene should still load.")
	check(test_room_scene != null, "Test Room should load with the reusable drone.")
	if player_scene == null or drone_scene == null or drone_grenade_scene == null or final_boss_grenade_scene == null:
		finish_test()
		return

	var test_root := Node2D.new()
	test_root.name = "EnemyDroneSmokeTestRoot"
	root.add_child(test_root)
	current_scene = test_root

	var player: Variant = player_scene.instantiate()
	var drone: Variant = drone_scene.instantiate()
	player.global_position = Vector2(10000.0, 10000.0)
	drone.global_position = Vector2.ZERO
	test_root.add_child(player)
	test_root.add_child(drone)
	await physics_frame
	player.set_physics_process(false)
	drone.set_physics_process(false)

	check_drone_scene_contract(drone)
	await check_patrol_pause_and_lean(drone)
	await check_detection_and_target_loss(test_root, drone, player)
	await check_release_frame_and_duplicate_guard(test_root, drone, player)
	await check_spawn_marker_mirroring(test_root, drone_scene)
	await check_natural_release_animation(test_root, drone_scene, player)

	drone.queue_free()
	await process_frame

	await check_drone_grenade_contract_and_fall(test_root, drone_grenade_scene)
	await check_drone_grenade_impact(test_root, drone_grenade_scene)
	await check_drone_grenade_one_way_impact(test_root, drone_grenade_scene)
	await check_drone_grenade_safety_cleanup(test_root, drone_grenade_scene)
	await check_explosion_damage_filtering(test_root, drone_scene, drone_grenade_scene, player)
	await check_final_boss_grenade_compatibility(test_root, final_boss_grenade_scene)

	if test_room_scene != null:
		check_test_room_contract(test_room_scene)

	stop_test_audio(test_root)
	await process_frame
	test_root.queue_free()
	await process_frame
	await process_frame
	finish_test()


func check_drone_scene_contract(drone: Variant) -> void:
	check(drone is CharacterBody2D, "Drone should use a CharacterBody2D root.")
	if not drone is CharacterBody2D:
		return

	check(drone.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "Drone should use floating motion mode.")
	check(drone.collision_layer == 4, "Drone body should occupy enemy physics layer 3.")
	check((drone.collision_mask & 1) != 0, "Drone body should collide with World layer 1.")
	check(drone.is_in_group("enemy"), "Drone should join the enemy group.")
	check(is_zero_approx(drone.rotation), "Drone physics root should start unrotated.")
	check(drone.get_node_or_null("CollisionShape2D") is CollisionShape2D, "Drone should have body collision.")

	var hurtbox := drone.get_node_or_null("Hurtbox") as Area2D
	check(hurtbox != null, "Drone should have an enemy hurtbox.")
	if hurtbox != null:
		check(hurtbox.collision_layer == 16 and hurtbox.collision_mask == 0, "Drone hurtbox should use layer 5 and no mask.")
		check(hurtbox.is_in_group("enemy_hurtbox"), "Drone hurtbox should join enemy_hurtbox.")
		check(hurtbox.get_node_or_null("CollisionShape2D") is CollisionShape2D, "Drone hurtbox should have collision.")

	var visual_pivot := drone.get_node_or_null("VisualPivot") as Node2D
	var sprite := drone.get_node_or_null("VisualPivot/AnimatedSprite2D") as AnimatedSprite2D
	var spawn_point := drone.get_node_or_null("VisualPivot/GrenadeSpawnPoint") as Marker2D
	check(visual_pivot != null, "Drone should have a visual-only lean pivot.")
	check(sprite != null, "Drone should have an AnimatedSprite2D below VisualPivot.")
	check(spawn_point != null, "Drone should expose an editor-movable GrenadeSpawnPoint.")
	if sprite != null and sprite.sprite_frames != null:
		check(sprite.sprite_frames.has_animation(&"idle_flying"), "Drone should contain idle_flying.")
		check(sprite.sprite_frames.get_frame_count(&"idle_flying") == 5, "idle_flying should use all five frames.")
		check(sprite.sprite_frames.get_animation_loop(&"idle_flying"), "idle_flying should loop.")
		check(sprite.sprite_frames.has_animation(&"release"), "Drone should contain release.")
		check(sprite.sprite_frames.get_frame_count(&"release") == 8, "release should use all eight frames.")
		check(not sprite.sprite_frames.get_animation_loop(&"release"), "release should not loop.")
		check(is_equal_approx(sprite.sprite_frames.get_animation_speed(&"release"), 12.0), "release should retain its authored 12 FPS timing.")

	var cone_pivot := drone.get_node_or_null("SearchConePivot") as Node2D
	var cone_light := drone.get_node_or_null("SearchConePivot/ConeLight") as PointLight2D
	var front_glow := drone.get_node_or_null("SearchConePivot/FrontDotGlow") as PointLight2D
	var detection_area := drone.get_node_or_null("SearchConePivot/DetectionArea") as Area2D
	var detection_polygon := drone.get_node_or_null("SearchConePivot/DetectionArea/CollisionPolygon2D") as CollisionPolygon2D
	check(cone_pivot != null, "Drone should have an independent SearchConePivot.")
	check(cone_light != null, "Drone should have a visible search-cone light.")
	if cone_light != null:
		check(cone_light.shadow_enabled, "Drone search cone should cast Canvas shadows.")
		check(cone_light.range_item_cull_mask == 1, "Drone cone should illuminate Canvas layer 1.")
		check(cone_light.shadow_item_cull_mask == 1, "Drone cone shadows should use occluder mask 1.")
	check(front_glow != null, "Drone should have a separate front-dot glow telegraph.")
	check(detection_area != null, "Drone should have gameplay detection separate from its light.")
	if detection_area != null:
		check(detection_area.collision_layer == 0 and detection_area.collision_mask == 2, "Detection Area should occupy no layer and scan only the player body.")
	check(detection_polygon != null and detection_polygon.polygon.size() >= 3, "Detection Area should have a cone-shaped polygon.")

	check(drone.get_node_or_null("TurnPauseTimer") is Timer, "Drone should have a TurnPauseTimer.")
	check(drone.get_node_or_null("AttackCooldownTimer") is Timer, "Drone should have an AttackCooldownTimer.")
	check(drone.get_node_or_null("HitSound") is AudioStreamPlayer2D, "Drone should have enemy hit audio.")
	var flight_loop_sound := drone.get_node_or_null("FlightLoopSound") as AudioStreamPlayer2D
	check(flight_loop_sound != null, "Drone should have positional flight-loop audio.")
	if flight_loop_sound != null:
		check(flight_loop_sound.autoplay, "Drone flight audio should start automatically.")
		check(flight_loop_sound.stream is AudioStreamWAV, "Drone flight audio should use the authored WAV stream.")
		if flight_loop_sound.stream is AudioStreamWAV:
			check(flight_loop_sound.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Drone flight audio should loop continuously.")
		check(is_equal_approx(flight_loop_sound.max_distance, 900.0), "Drone flight audio should fade out over its authored range.")
		check(flight_loop_sound.bus == &"Sound Effects", "Drone flight audio should use the Sound Effects bus.")
	for property_name in [
		&"patrol_speed", &"patrol_distance", &"turn_pause_duration", &"move_direction",
		&"max_lean_angle_degrees", &"lean_speed_degrees", &"cone_move_offset_degrees", &"cone_turn_speed_degrees",
		&"detection_confirmation_time", &"detection_decay_multiplier", &"player_detection_offset", &"vision_block_mask",
		&"attack_cooldown", &"grenade_release_frame", &"grenade_damage", &"grenade_scene",
		&"max_hp", &"contact_damage", &"debug_draw_detection", &"debug_draw_los",
	]:
		check(has_property(drone, property_name), "Drone should expose %s for tuning." % property_name)
	check(int(drone.get("grenade_release_frame")) == 7, "Drone should release the standalone grenade on frame 7.")
	check(not bool(drone.get("debug_draw_detection")) and not bool(drone.get("debug_draw_los")), "Drone debug drawing should default off.")


func check_patrol_pause_and_lean(drone: Variant) -> void:
	var visual_pivot := drone.get_node("VisualPivot") as Node2D
	var cone_pivot := drone.get_node("SearchConePivot") as Node2D
	drone.global_position = Vector2.ZERO
	drone.set("patrol_origin_x", 0.0)
	drone.set("patrol_distance", 1000.0)
	drone.set("move_direction", 1)
	drone.set("state", STATE_PATROL)
	drone.velocity = Vector2.ZERO

	drone.call("_physics_process", 0.10)
	check(drone.global_position.x > 0.0, "PATROL should move horizontally in the authored direction.")
	check(absf(visual_pivot.rotation) > 0.0001, "Moving should ease the visual pivot into a lean.")
	check(is_zero_approx(drone.rotation), "Visual lean should never rotate the CharacterBody2D root.")
	check(absf(cone_pivot.global_rotation) > 0.0001, "Moving should ease the search cone away from vertical.")

	var lean_before_pause: float = absf(visual_pivot.rotation)
	var cone_before_pause: float = absf(cone_pivot.global_rotation)
	drone.call("enter_turn_pause")
	check(int(drone.get("state")) == STATE_TURN_PAUSE, "Reaching a patrol end should enter TURN_PAUSE.")
	check(is_zero_approx(drone.velocity.x), "TURN_PAUSE should stop horizontal motion.")
	for _index in range(4):
		drone.call("_physics_process", 0.05)
	check(absf(visual_pivot.rotation) < lean_before_pause, "Visual lean should ease toward neutral while stopped.")
	check(absf(cone_pivot.global_rotation) < cone_before_pause, "Search cone should ease toward vertical while stopped.")
	check(is_zero_approx(drone.rotation), "Turning should not rotate the physics root.")

	var direction_before_turn: int = int(drone.get("move_direction"))
	var turn_timer := drone.get_node("TurnPauseTimer") as Timer
	turn_timer.timeout.emit()
	check(int(drone.get("state")) == STATE_PATROL, "Turn timeout should return to PATROL.")
	check(int(drone.get("move_direction")) == -direction_before_turn, "Turn timeout should reverse patrol direction once.")

	drone.global_position.x = float(drone.get("patrol_origin_x")) + float(drone.get("patrol_distance")) + 1.0
	drone.set("move_direction", 1)
	drone.set("state", STATE_PATROL)
	drone.call("_physics_process", 0.016)
	check(int(drone.get("state")) == STATE_TURN_PAUSE, "Crossing a local patrol bound should enter TURN_PAUSE.")


func check_detection_and_target_loss(test_root: Node2D, drone: Variant, player: Variant) -> void:
	drone.global_position = Vector2.ZERO
	drone.set("patrol_origin_x", 0.0)
	drone.set("patrol_distance", 1000.0)
	drone.set("move_direction", 1)
	drone.set("state", STATE_TURN_PAUSE)
	drone.set("player", player)
	player.global_position = Vector2(0.0, 180.0)
	player.set("is_dead", false)
	player.set("stealth_active", false)
	drone.call("_on_detection_area_body_entered", player)
	await physics_frame

	check(bool(drone.call("is_player_inside_detection_area")), "Detection broad phase should track the player body.")
	check(bool(drone.call("is_player_detectable")), "A living visible player should be targetable.")
	check(bool(drone.call("has_clear_line_to_player")), "A player below the drone should have clear World LOS.")
	check(bool(drone.call("can_accumulate_detection")), "Cone overlap plus clear LOS should permit detection progress.")

	var blocker := make_world_rectangle(Vector2(0.0, 90.0), Vector2(80.0, 18.0))
	test_root.add_child(blocker)
	await physics_frame
	check(not bool(drone.call("has_clear_line_to_player")), "World geometry should block drone LOS.")
	check(not bool(drone.call("can_accumulate_detection")), "Detection should not accumulate through cover.")
	blocker.queue_free()
	await physics_frame
	check(bool(drone.call("has_clear_line_to_player")), "Drone LOS should recover when cover is removed.")

	player.set("stealth_active", true)
	check(not bool(drone.call("is_player_detectable")), "Stealth should make the player invalid to the drone.")
	check(not bool(drone.call("has_clear_line_to_player")), "LOS helper should defensively reject a hidden player.")
	check(not bool(drone.call("can_accumulate_detection")), "A hidden player should not build confirmation progress.")
	player.set("stealth_active", false)

	drone.set("detection_progress", 0.0)
	drone.set("state", STATE_TURN_PAUSE)
	drone.call("_physics_process", float(drone.get("detection_confirmation_time")) + 0.01)
	check(int(drone.get("state")) == STATE_ATTACK, "Sustained valid detection should enter ATTACK, including during TURN_PAUSE.")

	# A hidden target cancels only a pending release; released projectiles own their lifecycle.
	var grenades_before_cancel: int = count_scene_instances(test_root, DRONE_GRENADE_SCENE_PATH)
	player.set("stealth_active", true)
	drone.call("_physics_process", 0.016)
	check(int(drone.get("state")) != STATE_ATTACK, "Stealth during the unreleased telegraph should cancel ATTACK.")
	check(count_scene_instances(test_root, DRONE_GRENADE_SCENE_PATH) == grenades_before_cancel, "Cancelling an unreleased attack should not spawn a grenade.")
	player.set("stealth_active", false)

	drone.call("_on_detection_area_body_exited", player)
	player.global_position = Vector2(1000.0, -1000.0)
	await physics_frame
	var tracked_players := drone.get("_players_in_detection_area") as Array
	check(not tracked_players.has(player), "Leaving the cone should clear the tracked broad-phase candidate.")


func check_release_frame_and_duplicate_guard(test_root: Node2D, drone: Variant, player: Variant) -> void:
	player.set("is_dead", false)
	player.set("stealth_active", false)
	drone.set("player", player)
	drone.set("state", STATE_PATROL)
	drone.call("start_attack")
	check(int(drone.get("state")) == STATE_ATTACK, "Confirmed detection should start ATTACK.")
	check(not bool(drone.get("grenade_spawned_this_attack")), "A new ATTACK should reset its release guard.")

	var sprite := drone.get_node("VisualPivot/AnimatedSprite2D") as AnimatedSprite2D
	var spawn_point := drone.get_node("VisualPivot/GrenadeSpawnPoint") as Marker2D
	sprite.pause()
	var grenades_before: int = count_scene_instances(test_root, DRONE_GRENADE_SCENE_PATH)
	sprite.animation = &"release"
	sprite.frame = 6
	drone.call("_on_animated_sprite_frame_changed")
	check(count_scene_instances(test_root, DRONE_GRENADE_SCENE_PATH) == grenades_before, "Release frame 6 should still use the baked-in grenade and spawn nothing.")

	sprite.frame = 7
	drone.call("_on_animated_sprite_frame_changed")
	var spawned_grenades := find_scene_instances(test_root, DRONE_GRENADE_SCENE_PATH)
	check(spawned_grenades.size() == grenades_before + 1, "Release frame 7 should create exactly one standalone grenade.")
	if spawned_grenades.size() > grenades_before:
		var spawned: Variant = spawned_grenades.back()
		check(absf(spawned.global_position.x - spawn_point.global_position.x) < 0.1, "Standalone grenade should inherit the editor-movable marker's horizontal position.")
		check(spawned.global_position.y >= spawn_point.global_position.y and spawned.global_position.y - spawn_point.global_position.y < 2.0, "Standalone grenade should begin at the editor-movable marker before falling.")
		check(is_zero_approx(spawned.velocity.x) and is_zero_approx(spawned.velocity.y), "Fresh drone grenade should start with zero velocity.")

	check(bool(drone.get("grenade_spawned_this_attack")), "Frame 7 should lock the per-attack release guard.")
	drone.call("_on_animated_sprite_frame_changed")
	drone.call("_on_animated_sprite_animation_finished")
	await process_frame
	check(count_scene_instances(test_root, DRONE_GRENADE_SCENE_PATH) == grenades_before + 1, "Repeated frame/finish callbacks must not duplicate a released grenade.")

	for grenade in find_scene_instances(test_root, DRONE_GRENADE_SCENE_PATH):
		grenade.queue_free()
	await process_frame


func check_spawn_marker_mirroring(test_root: Node2D, drone_scene: PackedScene) -> void:
	var drone: Variant = drone_scene.instantiate()
	var spawn_point := drone.get_node("VisualPivot/GrenadeSpawnPoint") as Marker2D
	# Override the packed marker before _ready(), exactly as an authored scene
	# value would be captured by the controller.
	var authored_left_position := Vector2(-17.0, 26.0)
	spawn_point.position = authored_left_position
	test_root.add_child(drone)
	await process_frame
	drone.set_physics_process(false)

	drone.set("move_direction", -1)
	drone.call("_update_facing")
	var left_position: Vector2 = spawn_point.position
	drone.set("move_direction", 1)
	drone.call("_update_facing")
	var right_position: Vector2 = spawn_point.position
	check(is_equal_approx(left_position.x, authored_left_position.x), "Left-facing drone should retain the authored nonzero grenade-marker X offset.")
	check(is_equal_approx(right_position.x, -authored_left_position.x), "Right-facing drone should mirror the authored grenade-marker X offset.")
	check(is_equal_approx(left_position.y, right_position.y), "Facing changes should preserve the grenade marker's authored Y offset.")

	drone.queue_free()
	await process_frame


func check_natural_release_animation(test_root: Node2D, drone_scene: PackedScene, player: Variant) -> void:
	var drone: Variant = drone_scene.instantiate()
	drone.global_position = Vector2(2400.0, -1200.0)
	test_root.add_child(drone)
	await process_frame
	drone.set_physics_process(false)
	drone.set("player", player)
	player.set("is_dead", false)
	player.set("stealth_active", false)

	var sprite := drone.get_node("VisualPivot/AnimatedSprite2D") as AnimatedSprite2D
	var grenades_before: int = count_scene_instances(test_root, DRONE_GRENADE_SCENE_PATH)
	var saw_release_frame_seven := [false]
	var spawned_before_frame_seven := [false]
	sprite.frame_changed.connect(func() -> void:
		if sprite.animation != &"release":
			return
		if sprite.frame == 7:
			saw_release_frame_seven[0] = true
		elif count_scene_instances(test_root, DRONE_GRENADE_SCENE_PATH) > grenades_before:
			spawned_before_frame_seven[0] = true
	)

	# Keep the real SpriteFrames clock and callbacks, but accelerate it so this
	# remains a fast smoke test rather than a wall-clock animation test.
	sprite.speed_scale = 8.0
	drone.call("start_attack")
	await create_timer(0.20).timeout
	check(bool(saw_release_frame_seven[0]), "Natural release playback should advance through frame 7.")
	check(not bool(spawned_before_frame_seven[0]), "Natural release playback should not spawn the grenade before frame 7.")
	check(count_scene_instances(test_root, DRONE_GRENADE_SCENE_PATH) == grenades_before + 1, "Natural release playback should spawn exactly one grenade.")
	await create_timer(0.05).timeout
	check(count_scene_instances(test_root, DRONE_GRENADE_SCENE_PATH) == grenades_before + 1, "Animation completion should not duplicate the frame-7 grenade.")

	for grenade in find_scene_instances(test_root, DRONE_GRENADE_SCENE_PATH):
		grenade.queue_free()
	drone.queue_free()
	await process_frame


func check_drone_grenade_contract_and_fall(test_root: Node2D, grenade_scene: PackedScene) -> void:
	var grenade: Variant = grenade_scene.instantiate()
	grenade.global_position = Vector2(3000.0, -2000.0)
	test_root.add_child(grenade)
	await physics_frame
	grenade.set_physics_process(false)

	check(grenade is CharacterBody2D, "Drone grenade should use deterministic CharacterBody2D motion.")
	check(grenade.collision_layer == 0 and grenade.collision_mask == 8193, "Drone grenade should hit only World and one-way-platform layers.")
	check(not bool(grenade.get("fuse_enabled")), "Drone grenade should have no airborne fuse.")
	check(bool(grenade.get("explode_on_first_impact")), "Drone grenade should explode on its first ground impact.")
	check(bool(grenade.get("vertical_drop_only")), "Drone grenade should enforce a vertical-only fall.")
	check(int(grenade.get("max_bounces")) == 0, "Drone grenade should have no configured bounces.")
	check(is_equal_approx(float(grenade.get("explosion_radius")), 72.0), "Drone grenade should use its authored 72 px blast radius.")
	check(float(grenade.get("safety_lifetime")) > 0.0, "Drone grenade should have void-fall safety cleanup.")
	var explosion_area := grenade.get_node("ExplosionArea") as Area2D
	check(explosion_area.collision_layer == 0 and explosion_area.collision_mask == 2, "Grenade explosion should scan only player bodies.")
	var explosion_sprite := grenade.get_node("ExplosionSprite") as AnimatedSprite2D
	check(explosion_sprite.sprite_frames.get_frame_count(&"explode") == 10, "Grenade should reuse all ten explosion frames.")
	var explosion_sound := grenade.get_node("ExplosionSound") as AudioStreamPlayer2D
	check(explosion_sound.stream != null, "Grenade should reuse the authored explosion sound.")
	check(grenade.has_signal(&"exploded") and grenade.has_signal(&"finished"), "Generic grenade signals should be available to the drone variant.")

	grenade.call("setup", grenade.global_position, Vector2(125.0, 0.0), 1, null)
	check(is_zero_approx(grenade.velocity.x), "Drone setup should discard horizontal launch velocity.")
	var start_x: float = grenade.global_position.x
	grenade.set("fuse_timer", -1.0)
	grenade.call("_physics_process", 0.10)
	check(is_equal_approx(grenade.global_position.x, start_x) and is_zero_approx(grenade.velocity.x), "Drone grenade should not drift horizontally while falling.")
	check(grenade.velocity.y > 0.0, "Gravity should accelerate the drone grenade downward.")
	check(not bool(grenade.get("has_exploded")), "Expired fuse state should not explode a fuse-disabled drone grenade in midair.")

	grenade.velocity.y = float(grenade.get("max_fall_speed")) + 500.0
	grenade.call("_physics_process", 0.016)
	check(grenade.velocity.y <= float(grenade.get("max_fall_speed")), "Drone grenade fall speed should respect its authored cap.")
	grenade.queue_free()
	await process_frame


func check_drone_grenade_impact(test_root: Node2D, grenade_scene: PackedScene) -> void:
	var floor_body := make_world_rectangle(Vector2(500.0, 80.0), Vector2(180.0, 20.0))
	test_root.add_child(floor_body)
	var grenade: Variant = grenade_scene.instantiate()
	grenade.global_position = Vector2(500.0, 0.0)
	test_root.add_child(grenade)
	await physics_frame
	grenade.set_physics_process(false)
	# Audio playback is covered by the scene contract above. Suppress it for the
	# forced-impact simulation so the headless audio driver leaves no playback
	# resource alive when SceneTree quits immediately after the test.
	grenade.set("explosion_sound", null)
	grenade.call("setup", grenade.global_position, Vector2.ZERO, 1, null)

	var start_x: float = grenade.global_position.x
	for _index in range(180):
		if bool(grenade.get("has_exploded")):
			break
		grenade.call("_physics_process", 1.0 / 60.0)
	check(bool(grenade.get("has_exploded")), "Drone grenade should explode on its first World ground collision.")
	check(is_equal_approx(grenade.global_position.x, start_x), "Ground impact should occur directly below the release point.")
	check(int(grenade.get("bounce_count")) == 0, "First-impact explosion should bypass all bounce handling.")
	check(grenade.velocity == Vector2.ZERO, "Impact explosion should stop grenade motion without a rebound.")
	var body_shape := grenade.get_node("CollisionShape2D") as CollisionShape2D
	var explosion_shape := grenade.get_node("ExplosionArea/CollisionShape2D") as CollisionShape2D
	check(body_shape.disabled and not explosion_shape.disabled, "Impact should disable projectile collision and enable the explosion shape.")

	grenade.queue_free()
	floor_body.queue_free()
	await process_frame


func check_drone_grenade_one_way_impact(test_root: Node2D, grenade_scene: PackedScene) -> void:
	var platform := make_one_way_platform(Vector2(850.0, 80.0), Vector2(180.0, 20.0))
	test_root.add_child(platform)
	var grenade: Variant = grenade_scene.instantiate()
	grenade.global_position = Vector2(850.0, 0.0)
	test_root.add_child(grenade)
	await physics_frame
	grenade.set_physics_process(false)
	grenade.set("explosion_sound", null)
	grenade.call("setup", grenade.global_position, Vector2.ZERO, 1, null)

	for _index in range(180):
		if bool(grenade.get("has_exploded")):
			break
		grenade.call("_physics_process", 1.0 / 60.0)
	check(bool(grenade.get("has_exploded")), "Drone grenade should explode on first contact with a layer-14 one-way platform.")
	check(int(grenade.get("bounce_count")) == 0 and grenade.velocity == Vector2.ZERO, "One-way-platform impact should explode without a bounce.")

	grenade.queue_free()
	platform.queue_free()
	await process_frame


func check_drone_grenade_safety_cleanup(test_root: Node2D, grenade_scene: PackedScene) -> void:
	var grenade: Variant = grenade_scene.instantiate()
	grenade.global_position = Vector2(5000.0, -5000.0)
	grenade.set("safety_lifetime", 0.01)
	test_root.add_child(grenade)
	await physics_frame
	grenade.set_physics_process(false)
	grenade.set("explosion_sound", null)
	grenade.set("safety_timer", 0.01)
	var exploded_signal_emitted := [false]
	var finished_signal_emitted := [false]
	grenade.exploded.connect(func() -> void: exploded_signal_emitted[0] = true)
	grenade.finished.connect(func() -> void: finished_signal_emitted[0] = true)
	grenade.call("_physics_process", 0.02)
	await process_frame
	check(not is_instance_valid(grenade), "A grenade falling into the void should clean itself up after its safety lifetime.")
	check(bool(finished_signal_emitted[0]), "Safety cleanup should emit finished.")
	check(not bool(exploded_signal_emitted[0]), "Safety cleanup should not create an airborne explosion.")


func check_explosion_damage_filtering(test_root: Node2D, drone_scene: PackedScene, grenade_scene: PackedScene, player: Variant) -> void:
	player.set("is_dead", false)
	player.set("stealth_active", false)
	player.set("current_hp", int(player.get("max_hp")))
	player.set("invulnerability_timer", 0.0)
	var grenade: Variant = grenade_scene.instantiate()
	test_root.add_child(grenade)
	await physics_frame
	grenade.set_physics_process(false)
	var starting_hp: int = int(player.get("current_hp"))
	grenade.call("damage_body", player)
	check(int(player.get("current_hp")) == starting_hp - int(grenade.get("damage")), "Drone explosion should damage a visible player with enemy-category damage.")
	grenade.call("damage_body", player)
	check(int(player.get("current_hp")) == starting_hp - int(grenade.get("damage")), "One explosion should damage a player at most once.")
	grenade.queue_free()
	await process_frame

	player.set("current_hp", int(player.get("max_hp")))
	player.set("invulnerability_timer", 0.0)
	player.set("stealth_active", true)
	var hidden_grenade: Variant = grenade_scene.instantiate()
	test_root.add_child(hidden_grenade)
	await physics_frame
	hidden_grenade.set_physics_process(false)
	var hidden_hp: int = int(player.get("current_hp"))
	hidden_grenade.call("damage_body", player)
	check(int(player.get("current_hp")) == hidden_hp, "Enemy-category grenade damage should be harmless during stealth.")

	var enemy: Variant = drone_scene.instantiate()
	test_root.add_child(enemy)
	await physics_frame
	enemy.set_physics_process(false)
	var enemy_hp: int = int(enemy.get("hp"))
	hidden_grenade.call("damage_body", enemy)
	check(int(enemy.get("hp")) == enemy_hp, "Drone grenade explosion should not damage enemies or its owner.")
	hidden_grenade.queue_free()
	enemy.queue_free()
	player.set("stealth_active", false)
	player.set("current_hp", int(player.get("max_hp")))
	player.set("invulnerability_timer", 0.0)
	await process_frame


func check_final_boss_grenade_compatibility(test_root: Node2D, grenade_scene: PackedScene) -> void:
	var grenade: Variant = grenade_scene.instantiate()
	grenade.global_position = Vector2(7000.0, -5000.0)
	test_root.add_child(grenade)
	await physics_frame
	grenade.set_physics_process(false)

	check(grenade.has_method("setup") and grenade.has_method("explode") and grenade.has_method("damage_body"), "Final Boss grenade should retain its public API.")
	check(grenade.has_signal(&"exploded") and grenade.has_signal(&"finished"), "Final Boss grenade should retain exploded and finished signals.")
	check(bool(grenade.get("fuse_enabled")), "Final Boss grenade should retain its fuse.")
	check(not bool(grenade.get("explode_on_first_impact")), "Final Boss grenade should retain bounce-first behavior.")
	check(not bool(grenade.get("vertical_drop_only")), "Final Boss grenade should retain two-axis launch velocity.")
	check(int(grenade.get("max_bounces")) == 2, "Final Boss grenade should retain two authored bounces.")
	check(is_zero_approx(float(grenade.get("safety_lifetime"))), "Final Boss grenade should not gain drone-only safety cleanup.")
	check((grenade.get_node("ExplosionSound") as AudioStreamPlayer2D).stream != null, "Final Boss grenade should retain its authored explosion sound.")
	grenade.set("explosion_sound", null)

	var owner := Node2D.new()
	test_root.add_child(owner)
	var launch_velocity := Vector2(123.0, -234.0)
	grenade.call("setup", Vector2(7000.0, -5000.0), launch_velocity, 3, owner)
	check(grenade.velocity == launch_velocity, "Final Boss setup should preserve two-axis launch velocity.")
	check(int(grenade.get("damage")) == 3 and grenade.get("boss_owner") == owner, "Final Boss setup should retain positional damage and owner arguments.")
	grenade.set("fuse_timer", 0.01)
	grenade.call("_physics_process", 0.02)
	check(bool(grenade.get("has_exploded")), "Final Boss grenade fuse should still trigger an explosion.")

	grenade.queue_free()
	owner.queue_free()
	await process_frame


func check_test_room_contract(test_room_scene: PackedScene) -> void:
	var room := test_room_scene.instantiate()
	var found_reusable_drone := false
	for node in get_descendants(room):
		if node.scene_file_path == DRONE_SCENE_PATH:
			found_reusable_drone = true
			break
	check(found_reusable_drone, "Test Room should instance the reusable drone scene.")
	check(room.get_node_or_null("DroneOcclusionBlocker") != null, "Test Room should include the drone physics/light occlusion test blocker.")
	var blocker := room.get_node_or_null("DroneOcclusionBlocker")
	if blocker != null:
		var has_world_body: bool = blocker is StaticBody2D and blocker.collision_layer == 1
		var has_light_occluder := false
		for node in get_descendants(blocker):
			if node is StaticBody2D and node.collision_layer == 1:
				has_world_body = true
			elif node is LightOccluder2D and node.occluder_light_mask == 1:
				has_light_occluder = true
		check(has_world_body, "Drone test blocker should contain World-layer physics collision.")
		check(has_light_occluder, "Drone test blocker should contain a matching light occluder on mask 1.")
	room.free()


func make_world_rectangle(position: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = position
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	body.add_child(collision)
	return body


func make_one_way_platform(position: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1 << 13
	body.collision_mask = 0
	body.position = position
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	collision.one_way_collision = true
	body.add_child(collision)
	return body


func count_scene_instances(parent: Node, scene_path: String) -> int:
	return find_scene_instances(parent, scene_path).size()


func find_scene_instances(parent: Node, scene_path: String) -> Array[Node]:
	var matches: Array[Node] = []
	for node in get_descendants(parent):
		if node.scene_file_path == scene_path:
			matches.append(node)
	return matches


func get_descendants(parent: Node) -> Array[Node]:
	var descendants: Array[Node] = []
	for child in parent.get_children():
		descendants.append(child)
		descendants.append_array(get_descendants(child))
	return descendants


func stop_test_audio(parent: Node) -> void:
	for node in get_descendants(parent):
		if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
			node.stop()


func has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false


func check(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error(message)


func finish_test() -> void:
	if failures == 0:
		print("Enemy drone smoke test passed.")
	else:
		push_error("Enemy drone smoke test failed with %d error(s)." % failures)

	quit(failures)
