extends SceneTree

const MINE_SCENE_PATH := "res://scenes/Hazards/underwater_mine.tscn"
const LEVEL_02_SCENE_PATH := "res://scenes/levels/test_room_2.tscn"

var failures: int = 0


class FakePlayer extends CharacterBody2D:
	var damage_received: int = 0
	var last_source_category: StringName = &""

	func take_damage(amount: int = 1, _ignore_invulnerability: bool = false, source_category: StringName = &"generic") -> void:
		damage_received += amount
		last_source_category = source_category


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var mine_scene := load(MINE_SCENE_PATH) as PackedScene
	var level_scene := load(LEVEL_02_SCENE_PATH) as PackedScene
	check(mine_scene != null, "Reusable underwater mine scene should load.")
	check(level_scene != null, "Level 02 should load with reusable underwater mines.")
	if mine_scene == null or level_scene == null:
		finish_test()
		return

	var test_root := Node2D.new()
	test_root.name = "UnderwaterMineSmokeTestRoot"
	root.add_child(test_root)
	current_scene = test_root

	var mine: Variant = mine_scene.instantiate()
	mine.set("warning_flash_count", 3)
	mine.set("flash_on_duration", 0.03)
	mine.set("flash_off_duration", 0.03)
	mine.set("destroy_after_explosion", false)
	test_root.add_child(mine)

	var player := FakePlayer.new()
	player.name = "FakePlayer"
	player.collision_layer = 2
	player.collision_mask = 1
	player.add_to_group("player")
	var player_shape := CollisionShape2D.new()
	var player_circle := CircleShape2D.new()
	player_circle.radius = 8.0
	player_shape.shape = player_circle
	player.add_child(player_shape)
	player.position = Vector2(-50.0, 9.0)
	test_root.add_child(player)
	await physics_frame

	check_mine_contract(mine)
	var collision := player.move_and_collide(Vector2(100.0, 0.0), true)
	check(collision != null, "The mine StaticBody2D should physically block the player.")
	player.position = Vector2.ZERO
	await physics_frame
	mine.call("_on_trigger_area_body_entered", player)
	check(bool(mine.get("is_triggered")), "Player contact should trigger the mine exactly once.")
	await create_timer(0.1).timeout
	check(not bool(mine.get("has_exploded")), "Three warning flashes should finish before the explosion begins.")

	var timeout := 1.0
	while not bool(mine.get("has_exploded")) and timeout > 0.0:
		await process_frame
		timeout -= 1.0 / 60.0
	check(bool(mine.get("has_exploded")), "Mine should explode after all three red flashes.")
	await physics_frame
	await physics_frame
	check(not (mine.get_node("Mine") as Sprite2D).visible, "Mine sprite should disappear when the explosion starts.")
	check((mine.get_node("Mine/MineBody") as StaticBody2D).collision_layer == 0, "Explosion should remove the mine's physical collision.")
	check((mine.get_node("Explosion") as AnimatedSprite2D).visible, "Explosion animation should become visible when the mine disappears.")
	check(player.damage_received == int(mine.get("damage")), "Explosion should damage an overlapping player once.")
	check(player.last_source_category == &"environment", "Underwater mine damage should remain environmental during stealth.")
	mine.call("_damage_player_once", player)
	check(player.damage_received == int(mine.get("damage")), "One mine explosion should not damage the same player twice.")
	await create_timer(0.5).timeout
	check(not (mine.get_node("Explosion") as AnimatedSprite2D).visible, "The last explosion frame should hide as soon as its animation finishes.")

	check_level_instances(level_scene)
	(mine.get_node("ExplosionSound") as AudioStreamPlayer2D).stop()
	current_scene = null
	test_root.free()
	finish_test()


func check_mine_contract(mine: Variant) -> void:
	var trigger_area := mine.get_node("Mine/TriggerArea") as Area2D
	var mine_body := mine.get_node("Mine/MineBody") as StaticBody2D
	var explosion_area := mine.get_node("ExplosionArea") as Area2D
	var explosion := mine.get_node("Explosion") as AnimatedSprite2D
	check(trigger_area.collision_layer == 0 and trigger_area.collision_mask == 2, "Mine trigger should monitor only player bodies.")
	check(mine_body.collision_layer == 1 and mine_body.collision_mask == 2, "Mine body should physically collide with players as World geometry.")
	check((mine_body.get_node("CollisionShape2D") as CollisionShape2D).shape != null, "The hand-authored mine collision should belong to its StaticBody2D.")
	check(explosion_area.collision_layer == 0 and explosion_area.collision_mask == 2, "Mine blast should monitor only player bodies.")
	var body_circle := (mine_body.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	var trigger_circle := (trigger_area.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	check(trigger_circle.radius > body_circle.radius, "Touch trigger should extend slightly beyond the physical mine collision.")
	check(is_equal_approx((explosion_area.get_node("CollisionShape2D") as CollisionShape2D).shape.radius, float(mine.get("explosion_radius"))), "Authored explosion radius should configure the blast shape.")
	check(explosion.sprite_frames.get_frame_count(&"explode") == 8, "Mine should use all eight underwater explosion frames.")
	check(not explosion.sprite_frames.get_animation_loop(&"explode"), "Underwater explosion animation should play once.")
	check(int(mine.get("warning_flash_count")) == 3, "Mine warning should default to three red flashes.")
	var bright_color: Color = mine.get("warning_white_color")
	check(bright_color.r > 1.0 and bright_color.g > 1.0 and bright_color.b > 1.0, "Warning sequence should include a clearly visible bright-white flash.")
	check(mine.get_node_or_null("ShockwaveLayer/ShockwaveEffect") is ColorRect, "Mine shockwave should use the full-screen ColorRect required by its screen-space shader.")
	var shockwave_material := (mine.get_node("ShockwaveLayer/ShockwaveEffect") as ColorRect).material as ShaderMaterial
	check(shockwave_material != null and shockwave_material.get_shader_parameter(&"radius") != null, "Shockwave shader should expose the radius value animated by the mine.")
	check(float(mine.get("shockwave_radius")) > 0.0, "Shockwave radius should be editable on the mine.")
	check(float(mine.get("shockwave_speed")) > 0.0, "Shockwave speed should be editable on the mine.")
	check(float(mine.get("shockwave_width")) > 0.0, "Shockwave width should be editable on the mine.")
	check(float(mine.get("shockwave_strength")) >= 0.0, "Shockwave strength should be editable on the mine.")
	check(float(mine.get("shockwave_aberration")) >= 0.0, "Shockwave aberration should be editable on the mine.")


func check_level_instances(level_scene: PackedScene) -> void:
	var level := level_scene.instantiate()
	var underwater_props := level.get_node_or_null("UnderwaterProps")
	check(underwater_props != null, "Level 02 should retain its UnderwaterProps container.")
	if underwater_props != null:
		check(underwater_props.get_node_or_null("UnderwaterMine") != null, "Level 02 should replace the first static mine with a reusable instance.")
		check(underwater_props.get_node_or_null("UnderwaterMine2") != null, "Level 02 should replace the second static mine with a reusable instance.")
		check(underwater_props.get_node_or_null("UnderwaterMine3") != null, "Level 02 should replace the third static mine with a reusable instance.")
	level.free()


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("Underwater mine smoke test: %s" % message)


func finish_test() -> void:
	if failures == 0:
		print("Underwater mine smoke test passed.")
		quit(0)
	else:
		push_error("Underwater mine smoke test failed with %d issue(s)." % failures)
		quit(1)
