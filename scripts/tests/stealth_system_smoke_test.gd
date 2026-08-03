extends SceneTree

var failures: int = 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	var shadow_scene := load("res://scenes/stealth/shadow_area.tscn") as PackedScene
	var ui_scene := load("res://scenes/ui/game_ui.tscn") as PackedScene
	var dog_scene := load("res://scenes/enemies/enemy_dog.tscn") as PackedScene
	var thrower_scene := load("res://scenes/enemies/enemy_knife_thrower.tscn") as PackedScene
	var mosquito_scene := load("res://scenes/enemies/enemy_mosquito.tscn") as PackedScene
	var bullet_scene := load("res://scenes/projectiles/boss_bullet.tscn") as PackedScene
	var knife_scene := load("res://scenes/Weapons/knife_projectile.tscn") as PackedScene
	var grenade_scene := load("res://scenes/projectiles/boss_grenade.tscn") as PackedScene
	var final_grenade_scene := load("res://scenes/projectiles/final_boss_grenade.tscn") as PackedScene
	var prototype_scene := load("res://scenes/levels/test_room.tscn") as PackedScene

	check(player_scene != null, "Player scene should load.")
	check(shadow_scene != null, "ShadowArea scene should load.")
	check(ui_scene != null, "GameUI scene should load.")
	check(dog_scene != null and thrower_scene != null and mosquito_scene != null, "Non-boss enemy scenes should load.")
	check(bullet_scene != null and knife_scene != null and grenade_scene != null and final_grenade_scene != null, "Enemy attack scenes should load.")
	check(prototype_scene != null, "Stealth prototype room should load.")
	if player_scene == null or shadow_scene == null or ui_scene == null:
		finish_test()
		return

	check_input_map()
	check_duplicate_player_scripts()

	var test_root := Node2D.new()
	test_root.name = "StealthSmokeTestRoot"
	root.add_child(test_root)
	current_scene = test_root

	var player: Variant = player_scene.instantiate()
	var ui: Variant = ui_scene.instantiate()
	var first_area := shadow_scene.instantiate() as Area2D
	var second_area := shadow_scene.instantiate() as Area2D
	first_area.position = Vector2(10000.0, 10000.0)
	second_area.position = Vector2(10200.0, 10000.0)
	test_root.add_child(player)
	test_root.add_child(ui)
	test_root.add_child(first_area)
	test_root.add_child(second_area)
	await process_frame
	player.set_physics_process(false)

	check(first_area.collision_layer == 0, "ShadowArea should not occupy a physics layer.")
	check(first_area.collision_mask == 2, "ShadowArea should scan only the player body layer.")
	first_area.set("area_size", Vector2(240.0, 120.0))
	var first_rectangle := first_area.get_node("CollisionShape2D").shape as RectangleShape2D
	check(first_rectangle != null and first_rectangle.size == Vector2(240.0, 120.0), "ShadowArea size should update its rectangle collision.")
	check(first_area.get_node("ShadowTint").polygon.size() == 4, "ShadowArea should keep a four-corner tint polygon.")

	ui.call("bind_player", player)
	check(not ui.get_node("StealthPrompt").visible, "Stealth prompt should start hidden.")

	first_area.call("_on_body_entered", player)
	check(player.is_stealth_available(), "Entering one shadow area should make stealth available.")
	check(not player.is_stealth_active(), "Entering a shadow area should not activate stealth automatically.")
	check(ui.get_node("StealthPrompt").visible, "GameUI should show the contextual stealth prompt.")
	player.register_shadow_area(first_area)
	check(player.active_shadow_areas.size() == 1, "Registering the same ShadowArea twice should not duplicate it.")

	player.set_stealth_active(true)
	check(player.is_stealth_active(), "Stealth should activate while an area is available.")
	check(not player.is_detectable_by_enemies(), "An active stealth player should not be detectable.")
	check(player.animated_sprite.self_modulate == player.stealth_tint, "Stealth should darken the player sprite.")
	check(player.stealth_highlight.visible, "Stealth should enable the bright player highlight.")
	check(ui.get_node("StealthPrompt/PromptLabel").text.contains("LEAVE"), "The active prompt should offer leaving stealth.")

	second_area.call("_on_body_entered", player)
	check(player.active_shadow_areas.size() == 2, "Two overlapping ShadowAreas should both be tracked.")
	first_area.call("_on_body_exited", player)
	check(player.is_stealth_active(), "Leaving one of two overlapping areas should preserve stealth.")
	second_area.call("_on_body_exited", player)
	check(not player.is_stealth_available(), "Leaving the final ShadowArea should remove availability.")
	check(not player.is_stealth_active(), "Leaving the final ShadowArea should cancel stealth.")
	check(player.animated_sprite.self_modulate == player.default_player_self_modulate, "Ending stealth should restore the original sprite modulation.")
	check(not player.stealth_highlight.visible, "Ending stealth should hide the highlight.")

	var cleanup_area := shadow_scene.instantiate() as Area2D
	cleanup_area.position = Vector2(10400.0, 10000.0)
	test_root.add_child(cleanup_area)
	await process_frame
	cleanup_area.call("_on_body_entered", player)
	player.set_stealth_active(true)
	cleanup_area.queue_free()
	await process_frame
	check(not player.is_stealth_available() and not player.is_stealth_active(), "Freeing an occupied ShadowArea should clean up player state.")

	first_area.call("_on_body_entered", player)
	check_failed_and_successful_attack_cancellation(player)
	await wait_process_frames(12)

	check_damage_filtering(player)
	await check_enemy_target_loss(test_root, player, dog_scene, thrower_scene, mosquito_scene)
	await check_enemy_attacks(test_root, player, bullet_scene, knife_scene, grenade_scene, final_grenade_scene)

	if prototype_scene != null:
		var prototype := prototype_scene.instantiate()
		check(prototype.get_node_or_null("ShadowAreas/ShadowArea") != null, "Prototype room should contain its first ShadowArea placement.")
		check(prototype.get_node_or_null("ShadowAreas/ShadowArea2") != null, "Prototype room should contain an overlapping second ShadowArea.")
		prototype.free()

	test_root.queue_free()
	await process_frame
	await process_frame
	finish_test()


func check_failed_and_successful_attack_cancellation(player: Variant) -> void:
	player.current_ammo = 0
	player.set_stealth_active(true)
	player.try_shoot()
	check(player.is_stealth_active(), "A failed zero-ammo shot should not cancel stealth.")

	player.current_ammo = 2
	player.bullet_scene = load("res://scenes/player/bullet.tscn")
	player.fire_timer.stop()
	player.try_shoot()
	check(not player.is_stealth_active(), "A successful shot should cancel stealth.")
	player.shoot_sound.stop()

	player.set_stealth_active(true)
	player.slap_cooldown_timer = 0.0
	player.slap_duration = 0.0
	player.try_slap()
	check(not player.is_stealth_active(), "A successful slap should cancel stealth.")

	player.set_stealth_active(true)
	player.try_melee_attack()
	check(not player.is_stealth_active(), "Starting a machete attack should cancel stealth.")
	player.cancel_melee_attack()


func check_damage_filtering(player: Variant) -> void:
	player.current_hp = player.max_hp
	player.invulnerability_timer = 0.0
	player.set_stealth_active(true)
	var starting_hp: int = player.current_hp
	player.take_damage(1, false, &"enemy")
	check(player.current_hp == starting_hp, "Enemy-category damage should be ignored while hidden.")

	player.take_damage(1, false, &"environment")
	check(player.current_hp == starting_hp - 1, "Environmental damage should remain active while hidden.")
	player.invulnerability_timer = 0.0
	player.take_damage(1, false, &"generic")
	check(player.current_hp == starting_hp - 2, "Generic damage should remain active while hidden.")
	player.current_hp = player.max_hp
	player.invulnerability_timer = 0.0


func check_enemy_target_loss(test_root: Node2D, player: Variant, dog_scene: PackedScene, thrower_scene: PackedScene, mosquito_scene: PackedScene) -> void:
	player.set_stealth_active(true)

	var dog: Variant = dog_scene.instantiate()
	var thrower: Variant = thrower_scene.instantiate()
	var mosquito: Variant = mosquito_scene.instantiate()
	test_root.add_child(dog)
	test_root.add_child(thrower)
	test_root.add_child(mosquito)
	await process_frame
	dog.set_physics_process(false)
	thrower.set_physics_process(false)
	mosquito.set_physics_process(false)

	dog.player = player
	dog.state = 1
	dog.update_state()
	check(int(dog.state) == 0, "A chasing dog should return to patrol when the player hides.")

	thrower.player = player
	thrower.is_throwing = true
	thrower.knife_spawned_this_throw = false
	thrower.animated_sprite.play(&"throw2")
	thrower._on_animated_sprite_frame_changed()
	check(not thrower.is_throwing and thrower.knife_spawned_this_throw, "A pending knife throw should cancel before release when the player hides.")

	mosquito.player = player
	mosquito.state = 1
	mosquito._physics_process(0.016)
	check(int(mosquito.state) == 3, "A charging mosquito should enter escape when the player hides.")

	var sniper: Variant = create_test_sniper()
	test_root.add_child(sniper)
	await process_frame
	sniper.set_physics_process(false)
	sniper.player = player
	sniper.state = 2
	var previous_scan_rotation: float = sniper.vision_pivot.rotation
	sniper._physics_process(0.016)
	check(int(sniper.state) == 0, "An alerted/tracking sniper should return to scan when the player hides.")
	check(not sniper.can_see_player() and not sniper.has_clear_line_to_player(), "Sniper perception should reject a hidden player.")
	check(not is_equal_approx(sniper.vision_pivot.rotation, previous_scan_rotation), "The sniper spotlight should keep scanning after target loss.")


func check_enemy_attacks(test_root: Node2D, player: Variant, bullet_scene: PackedScene, knife_scene: PackedScene, grenade_scene: PackedScene, final_grenade_scene: PackedScene) -> void:
	player.current_hp = player.max_hp
	player.invulnerability_timer = 0.0
	player.set_stealth_active(true)
	var starting_hp: int = player.current_hp

	var bullet := bullet_scene.instantiate()
	test_root.add_child(bullet)
	await process_frame
	bullet._on_body_entered(player)
	check(player.current_hp == starting_hp, "An existing enemy bullet should not damage a hidden player.")

	var knife := knife_scene.instantiate()
	knife.lifetime = 0.0
	test_root.add_child(knife)
	knife._on_body_entered(player)
	check(player.current_hp == starting_hp, "An existing thrown knife should not damage a hidden player.")
	await process_frame

	var grenade := grenade_scene.instantiate()
	test_root.add_child(grenade)
	await process_frame
	grenade._damage_body(player)
	check(player.current_hp == starting_hp, "A boss grenade explosion should be categorized as enemy damage.")

	var final_grenade := final_grenade_scene.instantiate()
	test_root.add_child(final_grenade)
	await process_frame
	final_grenade.damage_body(player)
	check(player.current_hp == starting_hp, "A final-boss grenade explosion should be categorized as enemy damage.")


func create_test_sniper() -> Variant:
	var sniper: Variant = Node2D.new()
	sniper.name = "TestSniper"
	sniper.set_script(load("res://scripts/enemies/enemy_sentry_sniper.gd"))

	var shoot_point := Marker2D.new()
	shoot_point.name = "ShootPoint"
	sniper.add_child(shoot_point)
	var vision_pivot := Node2D.new()
	vision_pivot.name = "VisionPivot"
	sniper.add_child(vision_pivot)
	var cooldown := Timer.new()
	cooldown.name = "FireCooldownTimer"
	sniper.add_child(cooldown)
	return sniper


func wait_process_frames(frame_count: int) -> void:
	for _index in range(frame_count):
		await process_frame


func check_input_map() -> void:
	check(InputMap.has_action("toggle_stealth"), "Input Map should contain toggle_stealth.")
	var has_q := false
	var has_right_shoulder := false
	for event in InputMap.action_get_events("toggle_stealth"):
		if event is InputEventKey and event.physical_keycode == KEY_Q:
			has_q = true
		elif event is InputEventJoypadButton and event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			has_right_shoulder = true
	check(has_q, "toggle_stealth should bind physical keyboard Q.")
	check(has_right_shoulder, "toggle_stealth should bind joypad right shoulder/RB.")


func check_duplicate_player_scripts() -> void:
	var scene_script := FileAccess.get_file_as_bytes("res://scenes/player/player.gd")
	var scripts_copy := FileAccess.get_file_as_bytes("res://scripts/player/player.gd")
	check(scene_script == scripts_copy, "Both player controller copies should remain byte-identical.")


func check(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error(message)


func finish_test() -> void:
	if failures == 0:
		print("Stealth system smoke test passed.")
	else:
		push_error("Stealth system smoke test failed with %d error(s)." % failures)

	quit(failures)
