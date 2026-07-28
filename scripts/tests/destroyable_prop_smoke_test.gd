extends Node

var failures: int = 0


func _ready() -> void:
	run_test()


func run_test() -> void:
	var crate_scene := load("res://scenes/props/destroyable/destroyable_crate.tscn") as PackedScene
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	check(crate_scene != null, "Destroyable crate scene should load.")
	check(player_scene != null, "Player scene should load.")

	if crate_scene == null or player_scene == null:
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
	check(sprite.texture != null, "Crate should use its configured sprite texture.")
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

	await get_tree().create_timer(1.0).timeout
	finish_test()


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
