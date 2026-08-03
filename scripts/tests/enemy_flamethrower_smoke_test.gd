extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const FLAMETHROWER_SCENE_PATH := "res://scenes/enemies/enemy_flamethrower.tscn"
const BURNING_GROUND_SCENE_PATH := "res://scenes/Hazards/burning_ground.tscn"

const STATE_PATROL := 0
const STATE_WIND_UP := 1
const STATE_FIRING := 2
const STATE_COOLDOWN := 3

var failures: int = 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var flamethrower_scene := load(FLAMETHROWER_SCENE_PATH) as PackedScene
	var burning_ground_scene := load(BURNING_GROUND_SCENE_PATH) as PackedScene
	check(player_scene != null, "Player scene should load.")
	check(flamethrower_scene != null, "Flamethrower enemy scene should load.")
	check(burning_ground_scene != null, "BurningGround scene should load.")
	if player_scene == null or flamethrower_scene == null or burning_ground_scene == null:
		finish_test()
		return

	var test_root := Node2D.new()
	test_root.name = "FlamethrowerSmokeTestRoot"
	root.add_child(test_root)
	current_scene = test_root

	var player: Variant = player_scene.instantiate()
	var enemy: Variant = flamethrower_scene.instantiate()
	test_root.add_child(player)
	test_root.add_child(enemy)
	await physics_frame
	player.set_physics_process(false)
	enemy.set_physics_process(false)

	check_enemy_scene_contract(enemy)
	await check_patrol_probes(test_root, enemy)
	await check_detection(test_root, enemy, player)
	await check_attack_states(enemy, player)
	await check_flame_wall_clamp_and_left_facing(test_root, enemy, player)
	enemy.queue_free()
	await process_frame

	var combat_enemy: Variant = flamethrower_scene.instantiate()
	test_root.add_child(combat_enemy)
	await physics_frame
	combat_enemy.set_physics_process(false)
	combat_enemy.set("player", player)
	await check_direct_flame_damage(combat_enemy, player)
	await check_ground_fire_spawn(test_root, combat_enemy, player)
	await check_burning_ground_scene(test_root, burning_ground_scene, player)
	await check_health_and_death(combat_enemy)

	test_root.queue_free()
	await process_frame
	await process_frame
	finish_test()


func check_enemy_scene_contract(enemy: Variant) -> void:
	check(enemy is CharacterBody2D, "Flamethrower enemy should use a CharacterBody2D root.")
	check(enemy.collision_layer == 4, "Flamethrower body should occupy enemy physics layer 3.")
	check((enemy.collision_mask & 1) != 0, "Flamethrower body should collide with World layer 1.")
	check(enemy.is_in_group("enemy"), "Flamethrower should join the enemy group.")

	var sprite := enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	check(sprite != null, "Flamethrower should have an AnimatedSprite2D.")
	if sprite != null and sprite.sprite_frames != null:
		check(sprite.sprite_frames.has_animation(&"walk"), "Flamethrower should contain a walk animation.")
		check(sprite.sprite_frames.get_frame_count(&"walk") == 9, "Walk should use all nine imported flamethrower frames.")
		check(sprite.sprite_frames.get_animation_loop(&"walk"), "Flamethrower walk should loop.")
		for animation_name in [&"idle", &"wind_up", &"fire", &"cooldown"]:
			check(sprite.sprite_frames.has_animation(animation_name), "Flamethrower should contain the %s animation." % animation_name)

	var hurtbox := enemy.get_node_or_null("Hurtbox") as Area2D
	check(hurtbox != null, "Flamethrower should have an enemy hurtbox.")
	if hurtbox != null:
		check(hurtbox.collision_layer == 16 and hurtbox.collision_mask == 0, "Flamethrower hurtbox should use layer 5 and no mask.")
		check(hurtbox.is_in_group("enemy_hurtbox"), "Flamethrower hurtbox should join enemy_hurtbox.")

	for ray_path in [
		"WallCheckLeft",
		"WallCheckRight",
		"FloorCheckLeft",
		"FloorCheckRight",
		"FlamePivot/FlameOrigin/FlameReachRay",
		"FlamePivot/FlameOrigin/GroundRayFar",
	]:
		var ray := enemy.get_node_or_null(ray_path) as RayCast2D
		check(ray != null, "Flamethrower should contain %s." % ray_path)
		if ray != null:
			check(ray.collision_mask == 1, "%s should query World layer 1 only." % ray_path)

	var flame_area := enemy.get_node_or_null("FlamePivot/FlameOrigin/FlameDamageArea") as Area2D
	check(flame_area != null, "Flamethrower should have a separate flame damage area.")
	if flame_area != null:
		check(flame_area.collision_layer == 0 and flame_area.collision_mask == 2, "Flame damage should occupy no layer and scan only the player body.")
		check(not flame_area.monitorable, "Flame damage should not be monitorable by other areas.")
		check(not flame_area.monitoring, "Flame damage should start disabled.")
		var flame_shape := flame_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		check(flame_shape != null and flame_shape.disabled, "Flame collision should start disabled.")

	var particles := enemy.get_node_or_null("FlamePivot/FlameOrigin/FlameParticles") as GPUParticles2D
	check(particles != null, "Flamethrower should have separate visual flame particles.")
	if particles != null:
		check(not particles.emitting, "Flame particles should start stopped.")

	check(has_property(enemy, &"contact_damage"), "Flamethrower should expose contact_damage for the player hurtbox path.")
	check(has_property(enemy, &"patrol_distance"), "Flamethrower should expose a bounded patrol distance.")
	check(has_property(enemy, &"detection_range"), "Flamethrower should expose detection range tuning.")
	check(has_property(enemy, &"vertical_tolerance"), "Flamethrower should expose vertical detection tolerance.")
	check(has_property(enemy, &"wind_up_time"), "Flamethrower should expose wind-up timing.")
	check(has_property(enemy, &"firing_duration"), "Flamethrower should expose burst duration.")


func check_patrol_probes(test_root: Node2D, enemy: Variant) -> void:
	enemy.global_position = Vector2.ZERO
	enemy.set("patrol_origin_x", 0.0)
	enemy.set("move_direction", 1)
	enemy.global_position.x = float(enemy.get("patrol_distance")) + 1.0
	check(bool(enemy.call("reached_patrol_limit")), "Patrol should turn when it reaches its exported origin distance.")

	enemy.global_position = Vector2.ZERO
	var floor_body := make_world_rectangle(Vector2(0.0, 25.0), Vector2(200.0, 10.0))
	var wall_body := make_world_rectangle(Vector2(18.0, 0.0), Vector2(4.0, 60.0))
	test_root.add_child(floor_body)
	test_root.add_child(wall_body)
	await physics_frame
	force_patrol_rays(enemy)
	check(bool(enemy.call("should_turn_around")), "The forward wall ray should turn patrol around at a wall.")

	wall_body.queue_free()
	await process_frame
	await physics_frame
	force_patrol_rays(enemy)
	check(not bool(enemy.call("should_turn_around")), "Patrol should continue when its forward floor ray has ground and no wall.")

	floor_body.queue_free()
	await process_frame
	await physics_frame
	force_patrol_rays(enemy)
	check(bool(enemy.call("should_turn_around")), "The forward floor ray should turn patrol around at a ledge.")


func check_detection(test_root: Node2D, enemy: Variant, player: Variant) -> void:
	enemy.set("player", player)
	enemy.set("state", STATE_PATROL)
	enemy.set("move_direction", 1)
	enemy.global_position = Vector2.ZERO
	player.global_position = Vector2(100.0, 0.0)
	player.set("is_dead", false)
	player.set("stealth_active", false)
	await physics_frame
	check(bool(enemy.call("can_detect_player")), "A visible player in front, in range, and at similar height should be detected.")

	player.global_position = Vector2(-100.0, 0.0)
	check(not bool(enemy.call("can_detect_player")), "A player behind the flamethrower should not be acquired.")

	player.global_position = Vector2(100.0, float(enemy.get("vertical_tolerance")) + 20.0)
	check(not bool(enemy.call("can_detect_player")), "A player outside vertical tolerance should not be acquired.")

	player.global_position = Vector2(float(enemy.get("detection_range")) + 20.0, 0.0)
	check(not bool(enemy.call("can_detect_player")), "A player outside detection range should not be acquired.")

	player.global_position = Vector2(100.0, 0.0)
	player.set("is_dead", true)
	check(not bool(enemy.call("can_detect_player")), "A dead player should not be acquired.")
	player.set("is_dead", false)
	player.set("stealth_active", true)
	check(not bool(enemy.call("can_detect_player")), "An active stealth player should not be acquired.")
	player.set("stealth_active", false)

	var blocker := make_world_rectangle(Vector2(50.0, 0.0), Vector2(10.0, 180.0))
	test_root.add_child(blocker)
	await physics_frame
	check(not bool(enemy.call("can_detect_player")), "World geometry should block flamethrower line of sight.")
	blocker.queue_free()
	await physics_frame
	check(bool(enemy.call("can_detect_player")), "Detection should recover after the World blocker is removed.")


func check_attack_states(enemy: Variant, player: Variant) -> void:
	enemy.global_position = Vector2.ZERO
	player.global_position = Vector2(120.0, 0.0)
	player.set("is_dead", false)
	player.set("stealth_active", false)
	enemy.set("player", player)
	enemy.set("move_direction", 1)

	enemy.call("enter_wind_up")
	check(int(enemy.get("state")) == STATE_WIND_UP, "Detection should enter WIND_UP.")
	check(float(enemy.get("state_time_remaining")) > 0.0, "WIND_UP should start a readable delay.")
	check(bool(enemy.call("has_wind_up_target")), "A visible player inside lose range should remain a valid wind-up target.")
	player.set("stealth_active", true)
	check(not bool(enemy.call("has_wind_up_target")), "Hiding during WIND_UP should invalidate the target.")
	player.set("stealth_active", false)

	enemy.call("enter_firing")
	await process_frame
	check(int(enemy.get("state")) == STATE_FIRING, "Completed wind-up should enter FIRING.")
	check(int(enemy.get("locked_fire_direction")) == 1, "FIRING should capture the current facing direction.")
	check(float(enemy.get("effective_flame_range")) > 0.0, "FIRING should calculate a positive effective flame range.")
	var flame_area := enemy.get_node("FlamePivot/FlameOrigin/FlameDamageArea") as Area2D
	var flame_shape := flame_area.get_node("CollisionShape2D") as CollisionShape2D
	var particles := enemy.get_node("FlamePivot/FlameOrigin/FlameParticles") as GPUParticles2D
	check(flame_area.monitoring and not flame_shape.disabled, "Entering FIRING should enable flame monitoring and collision.")
	check(particles.emitting, "Entering FIRING should enable flame particles.")

	var locked_direction: int = int(enemy.get("locked_fire_direction"))
	var pivot_scale_x: float = enemy.get_node("FlamePivot").scale.x
	player.global_position = Vector2(-120.0, 0.0)
	enemy.set_physics_process(true)
	await process_frame
	enemy.set_physics_process(false)
	check(int(enemy.get("state")) == STATE_FIRING, "A burst should continue when the player crosses behind it.")
	check(int(enemy.get("locked_fire_direction")) == locked_direction, "A burst should retain its locked firing direction.")
	check(is_equal_approx(enemy.get_node("FlamePivot").scale.x, pivot_scale_x), "The flame pivot should not flip during a burst.")

	enemy.call("enter_cooldown")
	await process_frame
	check(int(enemy.get("state")) == STATE_COOLDOWN, "Finished firing should enter COOLDOWN.")
	check(not flame_area.monitoring and flame_shape.disabled, "COOLDOWN should disable flame monitoring and collision.")
	check(not particles.emitting, "COOLDOWN should stop flame emission.")

	enemy.call("enter_patrol")
	check(int(enemy.get("state")) == STATE_PATROL, "Finished cooldown should return to PATROL.")


func check_flame_wall_clamp_and_left_facing(test_root: Node2D, enemy: Variant, player: Variant) -> void:
	enemy.global_position = Vector2.ZERO
	enemy.set("locked_fire_direction", 1)
	var wall_body := make_world_rectangle(Vector2(100.0, 0.0), Vector2(10.0, 120.0))
	test_root.add_child(wall_body)
	await physics_frame

	enemy.call("enter_firing")
	await physics_frame
	var effective_range: float = float(enemy.get("effective_flame_range"))
	var authored_range: float = float(enemy.get("flame_range"))
	check(effective_range > 0.0 and effective_range < authored_range, "World geometry should clamp the effective flame reach.")
	var flame_shape := enemy.get_node("FlamePivot/FlameOrigin/FlameDamageArea/CollisionShape2D") as CollisionShape2D
	var rectangle := flame_shape.shape as RectangleShape2D
	check(is_equal_approx(rectangle.size.x, effective_range), "The flame collision length should match the wall-clamped reach.")
	enemy.call("enter_cooldown")
	await physics_frame
	wall_body.queue_free()
	await physics_frame

	enemy.set("locked_fire_direction", -1)
	enemy.call("enter_firing")
	await physics_frame
	var pivot := enemy.get_node("FlamePivot") as Node2D
	var flame_origin := enemy.get_node("FlamePivot/FlameOrigin") as Node2D
	check(pivot.scale.x < 0.0, "A left-facing burst should mirror the entire flame pivot.")
	check(flame_shape.global_position.x < flame_origin.global_position.x, "The mirrored flame collision should extend left from the nozzle.")
	player.global_position = flame_shape.global_position
	await physics_frame
	await physics_frame
	check((enemy.call("get_flame_damage_targets") as Array).has(player), "Left-facing flame collision should retain its mirrored global transform.")
	enemy.call("enter_cooldown")
	await physics_frame


func check_direct_flame_damage(enemy: Variant, player: Variant) -> void:
	enemy.global_position = Vector2.ZERO
	player.set("is_dead", false)
	player.set("stealth_active", false)
	player.set("current_hp", int(player.get("max_hp")))
	player.set("invulnerability_timer", 0.0)
	enemy.set("move_direction", 1)
	enemy.call("enter_firing")
	await process_frame

	var flame_area := enemy.get_node("FlamePivot/FlameOrigin/FlameDamageArea") as Area2D
	var flame_shape := flame_area.get_node("CollisionShape2D") as CollisionShape2D
	player.global_position = flame_shape.global_position
	await physics_frame
	await physics_frame
	check((enemy.call("get_flame_damage_targets") as Array).has(player), "The enabled flame collision shape should recognize the player body.")

	var starting_hp: int = int(player.get("current_hp"))
	var expected_damage: int = int(enemy.get("flame_damage"))
	enemy.call("apply_flame_damage_tick")
	check(int(player.get("current_hp")) == starting_hp - expected_damage, "A direct flame tick should damage a visible player once.")
	enemy.call("apply_flame_damage_tick")
	check(int(player.get("current_hp")) == starting_hp - expected_damage, "Player invulnerability should reject an immediate second flame tick.")

	player.set("invulnerability_timer", 0.0)
	player.set("stealth_active", true)
	var hidden_hp: int = int(player.get("current_hp"))
	enemy.call("apply_flame_damage_tick")
	check(int(player.get("current_hp")) == hidden_hp, "Direct flame should be tagged as enemy damage and remain harmless during stealth.")

	player.set("stealth_active", false)
	player.set("current_hp", int(player.get("max_hp")))
	player.set("invulnerability_timer", 0.0)
	enemy.call("enter_cooldown")
	await process_frame


func check_ground_fire_spawn(test_root: Node2D, enemy: Variant, player: Variant) -> void:
	player.global_position = Vector2(-600.0, -300.0)
	enemy.global_position = Vector2.ZERO
	enemy.set("move_direction", 1)
	var floor_body := make_world_rectangle(Vector2(130.0, 52.0), Vector2(700.0, 24.0))
	test_root.add_child(floor_body)
	await physics_frame

	enemy.call("enter_firing")
	await process_frame
	var ray := enemy.get_node("FlamePivot/FlameOrigin/GroundRayFar") as RayCast2D
	ray.force_raycast_update()
	check(ray.is_colliding(), "The far ground probe should find a suitable World surface beneath the flame.")

	var patches_before: int = get_nodes_in_group("burning_ground").size()
	enemy.call("try_spawn_ground_fire")
	await process_frame
	var patches_after: Array[Node] = get_nodes_in_group("burning_ground")
	check(patches_after.size() == patches_before + 1, "A firing burst should create one BurningGround patch on valid ground.")
	if patches_after.size() > patches_before:
		var spawned_patch: Node = patches_after.back()
		check(spawned_patch.get_parent() == test_root, "BurningGround should belong to the current level, not the enemy.")
		enemy.call("try_spawn_ground_fire")
		await process_frame
		check(get_nodes_in_group("burning_ground").size() == patches_after.size(), "The per-burst cap should prevent repeated ground patches.")

		var lifetime_timer := spawned_patch.get_node("LifetimeTimer") as Timer
		await create_timer(0.05).timeout
		var time_before_refresh: float = lifetime_timer.time_left
		enemy.call("enter_cooldown")
		await physics_frame
		enemy.call("enter_firing")
		await physics_frame
		ray.force_raycast_update()
		enemy.call("try_spawn_ground_fire")
		await process_frame
		check(get_nodes_in_group("burning_ground").size() == patches_after.size(), "A new burst should refresh, not stack, a nearby ground patch.")
		check(lifetime_timer.time_left > time_before_refresh, "Duplicate suppression should refresh the existing patch lifetime.")
		spawned_patch.queue_free()
		await process_frame

	enemy.call("enter_cooldown")
	floor_body.queue_free()
	await physics_frame


func check_burning_ground_scene(test_root: Node2D, burning_ground_scene: PackedScene, player: Variant) -> void:
	var patch: Variant = burning_ground_scene.instantiate()
	check(has_property(patch, &"ground_fire_lifetime"), "BurningGround should expose lifetime tuning.")
	check(has_property(patch, &"ground_fire_damage"), "BurningGround should expose damage tuning.")
	check(patch.has_method("refresh_lifetime"), "BurningGround should provide refresh_lifetime for duplicate suppression.")
	check(patch.has_method("apply_damage_tick"), "BurningGround should provide a controlled damage-tick method.")
	patch.set("ground_fire_lifetime", 0.18)
	patch.set("fade_out_time", 0.0)
	patch.global_position = Vector2(500.0, 0.0)
	test_root.add_child(patch)
	await physics_frame

	check(patch is Area2D, "BurningGround should use an Area2D root.")
	check(patch.collision_layer == 0 and patch.collision_mask == 2, "BurningGround should occupy no layer and scan only the player body.")
	check(not patch.monitorable, "BurningGround should not be monitorable by unrelated areas.")
	check(patch.is_in_group("burning_ground"), "BurningGround should join its duplicate-suppression group.")
	var patch_shape := patch.get_node_or_null("CollisionShape2D") as CollisionShape2D
	check(patch_shape != null and not patch_shape.disabled, "BurningGround should begin with enabled collision.")
	check(patch.get_node_or_null("FireParticles") is GPUParticles2D, "BurningGround should provide visual fire particles.")
	var damage_timer := patch.get_node_or_null("DamageTimer") as Timer
	var lifetime_timer := patch.get_node_or_null("LifetimeTimer") as Timer
	check(damage_timer != null and not damage_timer.is_stopped(), "BurningGround should start a repeating damage timer.")
	check(lifetime_timer != null and not lifetime_timer.is_stopped(), "BurningGround should start a lifetime timer.")

	player.set("is_dead", false)
	player.set("stealth_active", false)
	player.set("current_hp", int(player.get("max_hp")))
	player.set("invulnerability_timer", 0.0)
	player.global_position = patch_shape.global_position
	await physics_frame
	await physics_frame
	var starting_hp: int = int(player.get("current_hp"))
	patch.call("apply_damage_tick")
	check(int(player.get("current_hp")) == starting_hp - int(patch.get("ground_fire_damage")), "BurningGround should damage an overlapping visible player.")
	player.set("invulnerability_timer", 0.0)
	player.set("stealth_active", true)
	var hidden_hp: int = int(player.get("current_hp"))
	patch.call("apply_damage_tick")
	check(int(player.get("current_hp")) == hidden_hp, "Enemy-created ground fire should use the enemy damage category.")
	player.set("stealth_active", false)

	await create_timer(0.10).timeout
	var time_before_refresh: float = lifetime_timer.time_left
	patch.call("refresh_lifetime")
	check(lifetime_timer.time_left > time_before_refresh, "Refreshing a nearby patch should restart its lifetime.")
	await create_timer(0.10).timeout
	check(is_instance_valid(patch), "A refreshed BurningGround patch should survive its original expiry time.")
	await create_timer(0.12).timeout
	check(not is_instance_valid(patch), "BurningGround should free itself after its refreshed lifetime expires.")

	player.set("current_hp", int(player.get("max_hp")))
	player.set("invulnerability_timer", 0.0)


func check_health_and_death(enemy: Variant) -> void:
	check(has_property(enemy, &"hp"), "Flamethrower should expose local hp like the existing enemies.")
	enemy.call("enter_firing")
	await physics_frame
	var flame_particles := enemy.get_node("FlamePivot/FlameOrigin/FlameParticles") as GPUParticles2D
	var damage_timer := enemy.get_node("DamageTickTimer") as Timer
	check(flame_particles.emitting and not damage_timer.is_stopped(), "Health cleanup test should begin during an active flame burst.")
	var starting_hp: int = int(enemy.get("hp"))
	enemy.call("take_damage", 1)
	check(int(enemy.get("hp")) == starting_hp - 1, "Flamethrower should receive ordinary enemy damage.")
	enemy.call("take_damage", int(enemy.get("max_hp")))
	check(not flame_particles.emitting and damage_timer.is_stopped(), "Lethal damage during FIRING should stop particles and damage ticks immediately.")
	await process_frame
	check(not is_instance_valid(enemy), "Lethal damage should remove the flamethrower enemy.")
	await create_timer(0.7).timeout


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


func force_patrol_rays(enemy: Variant) -> void:
	for ray_name in [&"WallCheckLeft", &"WallCheckRight", &"FloorCheckLeft", &"FloorCheckRight"]:
		var ray := enemy.get_node(NodePath(ray_name)) as RayCast2D
		ray.force_raycast_update()


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
		print("Enemy flamethrower smoke test passed.")
	else:
		push_error("Enemy flamethrower smoke test failed with %d error(s)." % failures)

	quit(failures)
