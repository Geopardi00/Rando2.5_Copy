extends SceneTree

const WATER_SCENE_PATH := "res://scenes/water/interactive_water_body.tscn"
const SPLASH_SCENE_PATH := "res://scenes/fx/water_splash_particles.tscn"
const TEST_ROOM_PATH := "res://scenes/levels/test_room_water02.tscn"

var failures: int = 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var water_scene := load(WATER_SCENE_PATH) as PackedScene
	var splash_scene := load(SPLASH_SCENE_PATH) as PackedScene
	var test_room_scene := load(TEST_ROOM_PATH) as PackedScene
	check(water_scene != null, "Interactive water scene should load.")
	check(splash_scene != null, "Reusable water splash scene should load.")
	check(test_room_scene != null, "Water visual test room should load.")
	if water_scene == null or splash_scene == null:
		finish_test()
		return

	var test_root := Node2D.new()
	test_root.name = "InteractiveWaterSmokeTestRoot"
	root.add_child(test_root)
	current_scene = test_root

	var water: Variant = water_scene.instantiate()
	water.global_position = Vector2(400.0, 180.0)
	water.set("water_size", Vector2(640.0, 240.0))
	test_root.add_child(water)
	await physics_frame
	water.set_physics_process(false)

	check_scene_contract(water)
	check_shared_spring_geometry(water)
	await check_splash_api_and_particles(test_root, water)
	await check_multiple_instances(test_root, water_scene, water)
	check_unrelated_area_is_safe(water)
	if test_room_scene != null:
		check_test_room_placement(test_room_scene)

	stop_test_particles(test_root)
	test_root.queue_free()
	await process_frame
	await process_frame
	finish_test()


func check_scene_contract(water: Variant) -> void:
	check(water is WaterBody2D, "Interactive water should inherit the existing WaterBody2D gameplay component.")
	check(water.is_in_group("water_body"), "Interactive water should retain the existing water_body group.")
	check(water.has_method("splash"), "Interactive water should expose splash(global_x_position, force).")

	var water_area := water.get_node_or_null("WaterArea") as Area2D
	var head_area := water.get_node_or_null("WaterHeadArea") as Area2D
	check(water_area != null and water_area.collision_layer == 0 and water_area.collision_mask == 2, "WaterArea should preserve player-body detection.")
	check(head_area != null and head_area.collision_layer == 0 and head_area.collision_mask == 256, "WaterHeadArea should preserve the existing head-sensor mask.")
	check(water.get_node_or_null("BubbleParticles") is GPUParticles2D, "Existing bubble resources should remain available.")
	check(water.get_node_or_null("Shader/Icon") is Sprite2D, "Existing water-region shader visual should remain available.")

	var back := water.get_node_or_null("BackWaterVisual") as Node2D
	var top := water.get_node_or_null("TopSurfaceVisual") as Polygon2D
	var front := water.get_node_or_null("FrontWaterVisual") as Node2D
	check(back != null and top != null and front != null, "Water should provide separate back, top, and front visual layers.")
	check(not water.get_node("WaterFill").visible and not water.get_node("WaterSurface").visible, "Derived visuals should replace the legacy fill and line only in this experimental scene.")
	if top != null:
		var material := top.material as ShaderMaterial
		check(material != null and material.shader != null, "Top surface should use its lightweight animated shader.")
		if material != null:
			check(is_equal_approx(float(material.get_shader_parameter(&"ripple_speed")), float(water.get("surface_ripple_speed"))), "Inspector ripple speed should reach the surface shader.")
	check(front.z_index > top.z_index, "Front water should render above the behind-player top surface.")


func check_shared_spring_geometry(water: Variant) -> void:
	var spring_count: int = water.ripple_heights.size()
	var front_edge := water.get_node("FrontWaterVisual/FrontWaterEdge") as Line2D
	var rear_edge := water.get_node("BackWaterVisual/RearWaterEdge") as Line2D
	var top := water.get_node("TopSurfaceVisual") as Polygon2D
	var front_body := water.get_node("FrontWaterVisual/WaterBody") as Polygon2D
	check(spring_count == int(water.get("ripple_point_count")), "Spring arrays should use the authored point count.")
	check(front_edge.points.size() == spring_count, "Front edge should have one point per spring.")
	check(rear_edge.points.size() == spring_count, "Rear edge should reuse the same spring count.")
	check(top.polygon.size() == spring_count * 2, "Top plane should be clipped between the shared front and rear edges.")
	check(front_body.polygon.size() == spring_count + 2, "Front cross-section should follow every front spring and close at water depth.")

	var center := spring_count / 2
	var world_x: float = water.to_global(Vector2.ZERO).x
	var applied: float = water.call("splash", world_x, 120.0, false)
	check(applied > 0.0, "A centered splash should apply a spring impulse.")
	check(water.ripple_velocities[center] > 0.0, "Nearest spring should receive the main impulse.")
	check(water.ripple_velocities[center - 1] > 0.0 and water.ripple_velocities[center + 1] > 0.0, "Adjacent springs should receive the configured smaller impulse.")

	water.call("update_surface_geometry")
	var front_y: float = front_edge.points[center].y
	var rear_y: float = rear_edge.points[center].y
	var expected_rear_y: float = -float(water.get("perspective_height")) + front_y * float(water.get("back_wave_scale"))
	check(is_equal_approx(front_y, water.ripple_heights[center]), "Front silhouette should use full spring displacement.")
	check(is_equal_approx(rear_y, expected_rear_y), "Rear edge should use the same spring at back_wave_scale plus perspective offset.")

	var initial_peak := maximum_absolute(water.ripple_heights)
	for _step in range(480):
		water.call("update_ripple", 1.0 / 60.0, false)
	var settled_peak := maximum_absolute(water.ripple_heights)
	check(settled_peak < maxf(initial_peak, 0.01), "Damping should reduce an interactive wave instead of leaving permanent oscillation.")


func check_splash_api_and_particles(_test_root: Node2D, water: Variant) -> void:
	water.ripple_heights.fill(0.0)
	water.ripple_velocities.fill(0.0)
	water.set("ripple_is_active", false)
	var children_before: int = water.get_child_count()
	var world_x: float = water.global_position.x - 90.0
	var applied: float = water.call("splash", world_x, 150.0, true)
	await process_frame
	check(applied > 0.0, "Public splash API should accept scripted impacts.")
	check(water.get_child_count() == children_before + 1, "Strong scripted splashes should create one reusable particle effect.")

	var effect := water.get_node_or_null("WaterSplashParticles") as GPUParticles2D
	check(effect != null, "Spawned splash should use WaterSplashParticles.")
	if effect != null:
		var expected_position: Vector2 = water.call("get_surface_global_position", world_x)
		check(effect.global_position.distance_to(expected_position) < 0.5, "Splash particles should appear on the current spring surface.")
		check(effect.emitting and effect.one_shot, "Splash particles should emit once and clean themselves up.")

	var rejected: float = water.call("splash", water.global_position.x + float(water.get("water_size").x), 150.0, false)
	check(is_zero_approx(rejected), "Splash calls outside the water width should be ignored safely.")


func check_multiple_instances(test_root: Node2D, water_scene: PackedScene, first_water: Variant) -> void:
	var second_water: Variant = water_scene.instantiate()
	second_water.global_position = Vector2(1300.0, 180.0)
	second_water.set("water_size", Vector2(320.0, 180.0))
	test_root.add_child(second_water)
	await physics_frame
	second_water.set_physics_process(false)
	check(maximum_absolute(second_water.ripple_velocities) <= 0.0001, "A second WaterBody should start with independent spring state.")
	first_water.call("splash", first_water.global_position.x, 90.0, false)
	check(maximum_absolute(second_water.ripple_velocities) <= 0.0001, "Splashing one WaterBody should not affect another instance.")
	second_water.queue_free()
	await process_frame


func check_unrelated_area_is_safe(water: Variant) -> void:
	var unrelated_area := Area2D.new()
	unrelated_area.name = "UnrelatedArea"
	water.call("_on_body_entered", unrelated_area)
	water.call("_on_body_exited", unrelated_area)
	unrelated_area.free()
	check(true, "Unrelated Area2D nodes should be ignored without errors.")


func check_test_room_placement(test_room_scene: PackedScene) -> void:
	var room := test_room_scene.instantiate()
	check(room.get_node_or_null("InteractiveWaterBody") != null, "test_room_water02 should instance the reusable interactive water.")
	check(room.get_node_or_null("WaterImpactCrate") != null, "test_room_water02 should include a falling object for splash testing.")
	room.free()


func maximum_absolute(values: PackedFloat32Array) -> float:
	var maximum := 0.0
	for value in values:
		maximum = maxf(maximum, absf(value))
	return maximum


func stop_test_particles(parent: Node) -> void:
	for node in get_descendants(parent):
		if node is GPUParticles2D:
			node.emitting = false
			node.process_mode = Node.PROCESS_MODE_DISABLED


func get_descendants(parent: Node) -> Array[Node]:
	var descendants: Array[Node] = []
	for child in parent.get_children():
		descendants.append(child)
		descendants.append_array(get_descendants(child))
	return descendants


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("Interactive water smoke test: %s" % message)


func finish_test() -> void:
	if failures == 0:
		print("Interactive water smoke test passed.")
		quit(0)
		return
	push_error("Interactive water smoke test failed with %d issue(s)." % failures)
	quit(1)
