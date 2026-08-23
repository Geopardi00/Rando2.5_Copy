extends SceneTree

const GATE_SCENE_PATH := "res://scenes/props/gate_mechanism.tscn"
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const BULLET_SCENE_PATH := "res://scenes/player/bullet.tscn"
const LEVEL_02_SCENE_PATH := "res://scenes/levels/test_room_2.tscn"

var failures: int = 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var gate_scene := load(GATE_SCENE_PATH) as PackedScene
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var bullet_scene := load(BULLET_SCENE_PATH) as PackedScene
	var level_scene := load(LEVEL_02_SCENE_PATH) as PackedScene
	check(gate_scene != null, "Reusable gate scene should load.")
	check(player_scene != null, "Player scene should load.")
	check(bullet_scene != null, "Player bullet scene should load.")
	check(level_scene != null, "Level 02 should load with the reusable gate.")
	if gate_scene == null or player_scene == null or bullet_scene == null or level_scene == null:
		finish_test()
		return

	var test_root := Node2D.new()
	test_root.name = "GateMechanismSmokeTestRoot"
	root.add_child(test_root)
	current_scene = test_root

	var gate: Variant = gate_scene.instantiate()
	gate.set("opening_duration", 0.05)
	gate.set("lever_animation_duration", 0.02)
	test_root.add_child(gate)

	var player: Variant = player_scene.instantiate()
	player.global_position = Vector2(-60.0, 3.0)
	test_root.add_child(player)
	await physics_frame
	player.set_physics_process(false)

	check_scene_contract(gate)
	check_clip_progression(gate)
	check_physical_blocking(gate, player)
	await check_attack_filtering_and_opening(test_root, gate, player, bullet_scene)
	check_level_placement(level_scene)
	check_player_script_parity()

	current_scene = null
	test_root.free()
	finish_test()


func check_scene_contract(gate: Variant) -> void:
	var moving_gate := gate.get_node("GateAssembly/MovingGate") as Node2D
	var gate_sprite := gate.get_node("GateAssembly/MovingGate/Gate") as Sprite2D
	var gate_body := gate.get_node("GateAssembly/MovingGate/GateBody") as StaticBody2D
	var lever_area := gate.get_node("LeverHitArea") as Area2D
	var lever_animation := gate.get_node("LeverVisualPivot/AnimatedSprite2D") as AnimatedSprite2D
	var clip_guide := gate.get_node("GateAssembly/ClipLine/EditorGuide") as Line2D
	var moving_gate_art_z := moving_gate.z_index + gate_sprite.z_index
	check(moving_gate_art_z <= (gate.get_node("GateAssembly/GateRight") as Sprite2D).z_index, "Moving gate should render behind GateRight.")
	check(moving_gate_art_z <= (gate.get_node("GateAssembly/GateLeft") as Sprite2D).z_index, "Moving gate should render behind GateLeft.")
	check(gate_body.collision_layer == 1 and gate_body.collision_mask == 2, "Closed gate should be World collision that blocks the player.")
	check(lever_area.collision_layer == 16 and lever_area.collision_mask == 0, "Lever should occupy layer 5 only for slap overlap.")
	check(lever_area.is_in_group("slap_interactable"), "Lever hit area should use the generic slap-interactable group.")
	check(not lever_area.is_in_group("enemy_hurtbox"), "Lever should not masquerade as an enemy hurtbox.")
	check(not lever_area.is_in_group("destroyable_prop_hurtbox"), "Machete logic should ignore the lever.")
	check(lever_animation.sprite_frames.has_animation(&"default"), "Lever should provide its authored activation animation.")
	check(not lever_animation.sprite_frames.get_animation_loop(&"default"), "Lever activation animation should play only once.")
	check(lever_animation.frame == 0 and not lever_animation.is_playing(), "Lever animation should wait on its first frame before activation.")
	check(not clip_guide.visible, "Clip guide should remain editor-only during gameplay.")
	var clip_material := gate_sprite.material as ShaderMaterial
	check(clip_material != null and clip_material.get_shader_parameter(&"clip_uv_y") != null, "Moving gate should have an adjustable vertical clip shader.")
	check(gate.has_signal(&"lever_activated") and gate.has_signal(&"opening_started") and gate.has_signal(&"opened"), "Reusable gate should publish its activation lifecycle.")
	check(bool(gate.get("camera_effect_enabled")), "Gate camera feedback should be enabled by default.")
	check(float(gate.get("camera_shake_amplitude")) > 0.0, "Gate should expose an adjustable camera shake amplitude.")
	check(float(gate.get("camera_shake_duration")) == 0.0, "Gate shake should follow the authored opening duration by default.")
	check(float(gate.get("camera_zoom_multiplier")) > 1.0, "Gate should expose a subtle camera zoom multiplier.")


func check_clip_progression(gate: Variant) -> void:
	var moving_gate := gate.get_node("GateAssembly/MovingGate") as Node2D
	var gate_sprite := gate.get_node("GateAssembly/MovingGate/Gate") as Sprite2D
	var material := gate_sprite.material as ShaderMaterial
	var closed_position := moving_gate.position
	var closed_cutoff := float(material.get_shader_parameter(&"clip_uv_y"))
	gate.call("_set_open_progress", 0.5)
	var half_cutoff := float(material.get_shader_parameter(&"clip_uv_y"))
	check(is_equal_approx(moving_gate.position.y, closed_position.y - float(gate.get("opening_distance")) * 0.5), "Gate progress should move the visual and collision parent upward.")
	check(half_cutoff > closed_cutoff, "More of gate.png should be clipped as it passes above the fixed clip line.")
	gate.call("_set_open_progress", 0.0)


func check_physical_blocking(gate: Variant, player: Variant) -> void:
	player.global_position = Vector2(-60.0, 3.0)
	var collision: KinematicCollision2D = player.move_and_collide(Vector2(120.0, 0.0), true)
	check(collision != null, "Closed gate should physically stop the player.")
	check(collision != null and collision.get_collider() == gate.get_node("GateAssembly/MovingGate/GateBody"), "Player should collide with the gate's moving StaticBody2D.")


func check_attack_filtering_and_opening(test_root: Node2D, gate: Variant, player: Variant, bullet_scene: PackedScene) -> void:
	var lever_area := gate.get_node("LeverHitArea") as Area2D
	var bullet: Variant = bullet_scene.instantiate()
	test_root.add_child(bullet)
	bullet.call("_on_area_entered", lever_area)
	check(not bool(gate.get("activated")), "Player bullets should pass the lever without activating it.")
	check(is_instance_valid(bullet) and not bullet.is_queued_for_deletion(), "Lever should not consume a player bullet.")

	player.set("melee_hitbox_active", true)
	player.call("_on_melee_hitbox_area_entered", lever_area)
	player.set("melee_hitbox_active", false)
	check(not bool(gate.get("activated")), "Machete attacks should not activate the slap-only lever.")

	var lever_signal_count := [0]
	var opening_signal_count := [0]
	var opened_signal_count := [0]
	gate.lever_activated.connect(func() -> void: lever_signal_count[0] += 1)
	gate.opening_started.connect(func() -> void: opening_signal_count[0] += 1)
	gate.opened.connect(func() -> void: opened_signal_count[0] += 1)
	var slap_targets: Array[Node] = []
	player.call("_on_slap_hitbox_area_entered", lever_area, slap_targets)
	check(bool(gate.get("activated")) and bool(gate.get("is_opening")), "A slap should activate the lever and begin opening immediately.")
	var lever_animation := gate.get_node("LeverVisualPivot/AnimatedSprite2D") as AnimatedSprite2D
	check(lever_animation.is_playing(), "The first slap should start the lever animation.")
	await create_timer(0.1).timeout
	await physics_frame
	check(bool(gate.call("is_gate_open")), "The gate should reach its permanent open state.")
	check(is_equal_approx(float(gate.get("open_progress")), 1.0), "Opening tween should finish at full progress.")
	check((gate.get_node("GateAssembly/MovingGate/GateBody") as StaticBody2D).collision_layer == 0, "Fully open gate should stop blocking the player.")
	check((gate.get_node("GateAssembly/MovingGate/GateBody/CollisionShape2D") as CollisionShape2D).disabled, "Fully open gate collision shape should be disabled.")
	check(not (gate.get_node("GateAssembly/MovingGate/Gate") as Sprite2D).visible, "Fully clipped moving gate should be hidden after opening.")
	check(lever_animation.frame > 0, "Lever animation should advance after activation.")
	check(is_zero_approx((gate.get_node("LeverVisualPivot") as Node2D).rotation), "Animated lever frames should replace the legacy pivot rotation.")
	check(lever_signal_count[0] == 1 and opening_signal_count[0] == 1 and opened_signal_count[0] == 1, "One slap should emit each gate lifecycle signal exactly once.")

	var frame_before_repeat := lever_animation.frame
	gate.call("slapped")
	await process_frame
	check(lever_animation.frame >= frame_before_repeat, "Repeated slaps should not restart the lever animation.")
	check(lever_signal_count[0] == 1 and opening_signal_count[0] == 1 and opened_signal_count[0] == 1, "Repeated slaps should not replay a one-shot gate.")
	if is_instance_valid(bullet):
		bullet.queue_free()


func check_level_placement(level_scene: PackedScene) -> void:
	var level := level_scene.instantiate()
	var gate := level.get_node_or_null("Gates")
	check(gate != null and gate.has_method("slapped"), "Level 02 should instance the reusable gate mechanism.")
	if gate != null:
		check(gate.position == Vector2(5626.0, -33.0), "Reusable gate root should preserve the authored Level 02 placement.")
		check(gate.get_node_or_null("GateAssembly/MovingGate/GateBody") is StaticBody2D, "Level 02 gate instance should contain its physical blocking body.")
		check(gate.get_node_or_null("LeverHitArea") is Area2D, "Level 02 gate instance should contain its slap target.")
	check(level.get_node_or_null("Gate") == null, "Obsolete hidden legacy gate should be removed from Level 02.")
	level.free()


func check_player_script_parity() -> void:
	var scene_script := FileAccess.get_file_as_string("res://scenes/player/player.gd")
	var reusable_script := FileAccess.get_file_as_string("res://scripts/player/player.gd")
	check(not scene_script.is_empty() and scene_script == reusable_script, "Duplicate player scripts should remain byte-identical.")


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("Gate mechanism smoke test: %s" % message)


func finish_test() -> void:
	if failures == 0:
		print("Gate mechanism smoke test passed.")
		quit(0)
	else:
		push_error("Gate mechanism smoke test failed with %d issue(s)." % failures)
		quit(1)
