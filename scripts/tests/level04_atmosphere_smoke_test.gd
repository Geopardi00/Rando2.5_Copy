extends SceneTree

const LEVEL_PATH := "res://scenes/levels/level_04.tscn"
const FOG_SHADER_PATH := "res://shaders/atmospheric_fog.gdshader"
const MAX_AMBIENT_PARTICLES := 113

var failures := 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var packed_level := load(LEVEL_PATH) as PackedScene
	check(packed_level != null, "Level04 should load with its atmosphere resources.")
	if packed_level == null:
		finish_test()
		return

	var level := packed_level.instantiate()
	root.add_child(level)
	await process_frame

	var fog_far := level.get_node_or_null("World/BackgroundObjectsFar/FogFar") as Sprite2D
	var fog_mid := level.get_node_or_null("World/BackgroundMid/FogMid") as Sprite2D
	var dust_mid := level.get_node_or_null("World/BackgroundMid/DustMid") as GPUParticles2D
	var dust_near := level.get_node_or_null("World/ForegroundNear/DustNear") as GPUParticles2D
	var warehouse_light := level.get_node_or_null("Lights/Light01/PointLight2D") as PointLight2D
	var background_light := level.get_node_or_null("World/BackgroundMid/Light02/PointLight2D") as PointLight2D
	var background_fill := level.get_node_or_null("World/BackgroundMid/Light02/PointLight2D2") as PointLight2D

	check(fog_far != null, "Level04 should provide far background fog.")
	check(fog_mid != null, "Level04 should provide mid background fog.")
	check(dust_mid != null, "Level04 should provide mid-depth dust.")
	check(dust_near != null, "Level04 should provide near foreground dust.")
	check(warehouse_light != null, "Level04 should instance the reusable warehouse light.")
	check(warehouse_light != null and warehouse_light.range_item_cull_mask == 3, "Warehouse light should illuminate gameplay and atmosphere masks.")
	check(background_light != null, "Level04 should provide the focused background light.")
	check(background_fill != null, "Level04 should provide the focused background fill light.")
	for background_light_component in [background_light, background_fill]:
		if background_light_component == null:
			continue
		check(
			background_light_component.range_z_min == -8 and background_light_component.range_z_max == -7,
			"Light02 components should illuminate only background Z indices -8 through -7."
		)

	if fog_far != null and fog_mid != null:
		var far_material := fog_far.material as ShaderMaterial
		var mid_material := fog_mid.material as ShaderMaterial
		check(far_material != null and mid_material != null, "Both fog layers should use ShaderMaterial instances.")
		check(far_material != mid_material, "Fog layers should keep independent tuning materials.")
		check(far_material != null and far_material.shader != null and far_material.shader.resource_path == FOG_SHADER_PATH, "Far fog should use the shared atmosphere shader.")
		check(mid_material != null and mid_material.shader != null and mid_material.shader.resource_path == FOG_SHADER_PATH, "Mid fog should use the shared atmosphere shader.")
		check(fog_far.texture == fog_mid.texture, "Fog layers should share one seamless noise texture.")
		check(fog_far.light_mask == 0, "Far fog should ignore Canvas lights.")
		check(fog_mid.light_mask == 2, "Mid fog should reserve atmosphere light-mask bit 2.")

	var particle_total := 0
	for dust in [dust_mid, dust_near]:
		if dust == null:
			continue
		particle_total += dust.amount
		check(dust.light_mask == 2, "%s should reserve atmosphere light-mask bit 2." % dust.name)
		check(dust.fixed_fps == 30, "%s should use the 30 FPS particle budget." % dust.name)
		check(dust.texture != null, "%s should use the shared soft dust texture." % dust.name)

	check(particle_total <= MAX_AMBIENT_PARTICLES, "Level04 ambient particles should not exceed %d." % MAX_AMBIENT_PARTICLES)
	check(level.get_node_or_null("World/BackgroundNear/FogNear") == null, "V1 should not add near gameplay fog.")
	check(level.get_node_or_null("World/ForegroundNearest/DustExtreme") == null, "V1 should not add extreme foreground dust.")

	level.queue_free()
	await process_frame
	finish_test()


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func finish_test() -> void:
	if failures == 0:
		print("Level04 atmosphere smoke test passed.")
	else:
		push_error("Level04 atmosphere smoke test failed with %d error(s)." % failures)
	quit(failures)
