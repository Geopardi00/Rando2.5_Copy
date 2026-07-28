extends Node

var failures: int = 0


func _ready() -> void:
	run_test()


func run_test() -> void:
	var crate_scene := load("res://scenes/props/destroyable/destroyable_crate_box05.tscn") as PackedScene
	var fallback_crate_scene := load("res://scenes/props/destroyable/destroyable_crate.tscn") as PackedScene
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	check(crate_scene != null, "Box05 destroyable crate scene should load.")
	check(fallback_crate_scene != null, "Fallback destroyable crate scene should load.")
	check(player_scene != null, "Player scene should load.")

	if crate_scene == null or fallback_crate_scene == null or player_scene == null:
		finish_test()
		return

	var crate := crate_scene.instantiate()
	var player := player_scene.instantiate()
	add_child(crate)
	add_child(player)
	await get_tree().process_frame

	var hurtbox := crate.get_node("Hurtbox") as Area2D
	var physical_collision := crate.get_node("PhysicalCollision") as CollisionShape2D
	var sprite := crate.get_node("Sprite2D") as Sprite2D

	check(crate.health == 3, "Crate should begin with three health.")
	check(not crate.has_node("BreakParticles"), "The retired break-particle effect should not be present.")
	check(sprite.texture != null, "Crate should use its configured sprite texture.")
	check(crate.debris_textures.size() == 4, "Box05 should configure four debris textures.")
	check(hurtbox.is_in_group("destroyable_prop_hurtbox"), "Crate hurtbox should use the destroyable group.")
	check(not hurtbox.is_in_group("enemy_hurtbox"), "Crate hurtbox should not be treated as an enemy.")
	check(hurtbox.collision_layer == 64, "Crate hurtbox should use the destroyable physics layer.")
	check((player.melee_hitbox.collision_mask & 64) != 0, "The machete should scan the destroyable physics layer.")
	check((17 & hurtbox.collision_layer) == 0, "The bullet mask should not scan the destroyable physics layer.")

	# Audio is configured in the scene; disable it here so the test can exit immediately.
	check(crate.hit_sound != null and crate.break_sound != null, "Crate should have hit and break sounds configured.")
	crate.hit_sound = null
	crate.break_sound = null

	player.melee_hitbox_active = true
	player._on_melee_hitbox_area_entered(hurtbox)
	player._on_melee_hitbox_area_entered(hurtbox)
	check(crate.health == 2, "One melee swing should damage the crate only once.")

	player.melee_hit_targets.clear()
	player._on_melee_hitbox_area_entered(hurtbox)
	check(crate.health == 1, "The second swing should leave one health.")

	player.melee_hit_targets.clear()
	player._on_melee_hitbox_area_entered(hurtbox)
	await get_tree().physics_frame

	check(crate.is_destroyed, "The third swing should destroy the crate.")
	check(crate.collision_layer == 0, "A destroyed crate should leave the world collision layer.")
	check(hurtbox.collision_layer == 0, "A destroyed crate hurtbox should stop receiving hits.")
	check(physical_collision.disabled, "A destroyed crate should disable physical collision.")
	check(not sprite.visible, "A destroyed crate should hide its intact sprite.")

	var debris_pieces := get_tree().get_nodes_in_group("destroyable_debris")
	check(debris_pieces.size() == 4, "Destroying Box05 should spawn exactly four debris pieces.")

	var debris_textures: Array[Texture2D] = []
	var has_leftward_piece := false
	var has_rightward_piece := false
	for piece in debris_pieces:
		check(piece.collision_layer == 0, "Debris should not occupy a gameplay collision layer.")
		check(piece.collision_mask == 8193, "Debris should collide with World and OneWayPlatform only.")
		check(piece.linear_velocity.y < 0.0, "Debris should launch upward before falling.")
		check(not is_zero_approx(piece.angular_velocity), "Debris should receive angular velocity.")
		has_leftward_piece = has_leftward_piece or piece.linear_velocity.x < 0.0
		has_rightward_piece = has_rightward_piece or piece.linear_velocity.x > 0.0
		var piece_sprite := piece.get_node("Sprite2D") as Sprite2D
		if piece_sprite.texture != null:
			debris_textures.append(piece_sprite.texture)

	check(debris_textures.size() == 4, "Every debris piece should have a texture.")
	check(count_unique_textures(debris_textures) == 4, "Each Box05 fragment texture should be used once.")
	check(has_leftward_piece and has_rightward_piece, "Debris should fan out to both sides.")

	var fallback_crate := fallback_crate_scene.instantiate()
	add_child(fallback_crate)
	await get_tree().process_frame
	fallback_crate.hit_sound = null
	fallback_crate.break_sound = null
	fallback_crate.take_damage(fallback_crate.max_health)
	await get_tree().physics_frame
	check(
		get_tree().get_nodes_in_group("destroyable_debris").size() == 4,
		"A prop without debris textures should keep the particle-only fallback."
	)

	await get_tree().create_timer(3.0).timeout
	check(
		get_tree().get_nodes_in_group("destroyable_debris").is_empty(),
		"Debris should fade and free itself after its configured lifetime."
	)
	finish_test()


func count_unique_textures(textures: Array[Texture2D]) -> int:
	var unique_textures: Dictionary = {}
	for texture in textures:
		unique_textures[texture] = true
	return unique_textures.size()


func check(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error(message)


func finish_test() -> void:
	if failures == 0:
		print("Destroyable prop smoke test passed.")
	else:
		push_error("Destroyable prop smoke test failed with %d error(s)." % failures)

	get_tree().quit(failures)
