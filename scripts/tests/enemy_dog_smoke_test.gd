extends SceneTree

var failures: int = 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	var dog_scene := load("res://scenes/enemies/enemy_dog.tscn") as PackedScene
	check(player_scene != null, "Player scene should load.")
	check(dog_scene != null, "Enemy dog scene should load.")
	if player_scene == null or dog_scene == null:
		finish_test()
		return

	var test_root := Node2D.new()
	root.add_child(test_root)
	var player := player_scene.instantiate() as CharacterBody2D
	var dog := dog_scene.instantiate() as CharacterBody2D
	test_root.add_child(player)
	test_root.add_child(dog)
	await process_frame
	player.set_physics_process(false)
	dog.set_physics_process(false)

	dog.set("player", player)
	dog.set("state", 0)
	dog.set("chase_lock_timer", 0.0)
	dog.global_position = Vector2.ZERO
	player.global_position = Vector2(100.0, 0.0)
	dog.call("update_state")
	check(int(dog.get("state")) == 1, "A nearby living player should put the dog into chase state.")

	dog.set("move_direction", 1)
	player.set("is_dead", true)
	dog.call("refresh_player_reference")
	dog.call("update_state")
	check(dog.get("player") == null, "The dog should release a dead player target.")
	check(int(dog.get("state")) == 0, "A dead player should return the dog to patrol state.")
	check(int(dog.get("move_direction")) == 1, "Ignoring a dead player should preserve the dog's walking direction.")

	dog.set("player", player)
	dog.set("state", 1)
	dog.velocity = Vector2.ZERO
	dog.call("run_chase")
	check(int(dog.get("state")) == 0, "Chase movement should defensively reject a dead player.")
	check(is_equal_approx(dog.velocity.x, float(dog.get("patrol_speed"))), "The dog should continue at patrol speed after rejecting a dead player.")

	test_root.queue_free()
	await process_frame
	finish_test()


func check(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error(message)


func finish_test() -> void:
	if failures == 0:
		print("Enemy dog smoke test passed.")
	else:
		push_error("Enemy dog smoke test failed with %d error(s)." % failures)

	quit(failures)
