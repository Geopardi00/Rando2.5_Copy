extends SceneTree

const TEST_LEVELS: Array[String] = [
	"res://scenes/levels/level_01.tscn",
	"res://scenes/levels/level_03.tscn",
	"res://scenes/levels/test_room_2.tscn",
]

var failures: int = 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	for level_path in TEST_LEVELS:
		await validate_level_camera(level_path)

	finish_test()


func validate_level_camera(level_path: String) -> void:
	var level_scene := load(level_path) as PackedScene
	check(level_scene != null, "%s should load." % level_path)
	if level_scene == null:
		return

	var level := level_scene.instantiate()
	root.add_child(level)
	for frame in 5:
		await process_frame
		await physics_frame

	var player := level.get_node_or_null("Player") as Node2D
	var legacy_camera := level.get_node_or_null("Player/Camera2D") as Camera2D
	var camera := level.get_node_or_null("CameraRig/Camera2D") as Camera2D
	var host := level.get_node_or_null("CameraRig/Camera2D/PhantomCameraHost")
	var phantom_camera := level.get_node_or_null("CameraRig/PhantomCamera2D") as Node2D
	var landing_shake_emitter := level.get_node_or_null("CameraRig/LandingShakeEmitter") as Node2D
	var gate_shake_emitter := level.get_node_or_null("CameraRig/GateShakeEmitter") as Node2D
	var landing_shake_noise := landing_shake_emitter.get("noise") as Resource if landing_shake_emitter != null else null
	var gate_shake_noise := gate_shake_emitter.get("noise") as Resource if gate_shake_emitter != null else null

	check(player != null, "%s should provide a player target." % level_path)
	check(legacy_camera != null and not legacy_camera.enabled, "%s should disable the legacy player camera." % level_path)
	check(camera != null and root.get_camera_2d() == camera, "%s should give viewport control to the rig Camera2D." % level_path)
	check(phantom_camera != null and phantom_camera.get("follow_target") == player, "%s should bind PhantomCamera2D to its player." % level_path)
	check(phantom_camera != null and bool(phantom_camera.call("is_following")), "%s should activate PhantomCamera2D follow logic." % level_path)
	check(phantom_camera != null and int(phantom_camera.get("follow_mode")) == 5, "%s should preserve the tuned Framed follow mode at runtime." % level_path)
	check(phantom_camera != null and bool(phantom_camera.get("follow_damping")), "%s should preserve follow damping at runtime." % level_path)
	check(host != null and host.call("get_active_pcam") == phantom_camera, "%s should select the player follow camera on its host." % level_path)
	check(landing_shake_emitter != null, "%s should provide the reusable hard-landing shake emitter." % level_path)
	check(landing_shake_noise != null, "%s should configure Phantom Camera positional noise for hard landings." % level_path)
	check(phantom_camera != null and landing_shake_emitter != null and (int(phantom_camera.get("noise_emitter_layer")) & int(landing_shake_emitter.get("noise_emitter_layer"))) != 0, "%s should use matching Phantom Camera noise layers." % level_path)
	check(landing_shake_noise != null and not bool(landing_shake_noise.get("rotational_noise")), "%s landing shake should not rotate the camera." % level_path)
	check(landing_shake_noise != null and float(landing_shake_noise.get("positional_multiplier_y")) > float(landing_shake_noise.get("positional_multiplier_x")), "%s landing shake should be stronger vertically than horizontally." % level_path)
	check(gate_shake_emitter != null and gate_shake_noise != null, "%s should provide a separate reusable gate shake emitter." % level_path)
	check(level.get_node_or_null("CameraRig").is_in_group("camera_rig"), "%s camera rig should be discoverable by opening gates." % level_path)
	if gate_shake_emitter != null and phantom_camera != null:
		var original_zoom: Vector2 = phantom_camera.get("zoom")
		level.get_node("CameraRig").call("play_gate_opening_effect", 0.08, 2.0, 10.0, 1.02, 0.01, 0.01)
		check(bool(gate_shake_emitter.call("is_emitting")), "%s gate effect should emit camera shake." % level_path)
		await create_timer(0.1).timeout
		var restored_zoom: Vector2 = phantom_camera.get("zoom")
		check(restored_zoom.is_equal_approx(original_zoom), "%s gate zoom should restore the authored camera zoom." % level_path)
		gate_shake_emitter.call("stop", false)

	if player != null and landing_shake_emitter != null:
		landing_shake_emitter.call("stop", false)
		player.call("start_hard_landing")
		check(float(player.get("landing_animation_timer")) > 0.0, "%s hard landing should start the dust animation timer." % level_path)
		check(bool(landing_shake_emitter.call("is_emitting")), "%s hard landing should start Phantom Camera noise on the same event." % level_path)
		landing_shake_emitter.call("stop", false)

	stop_level_audio(level)
	level.queue_free()
	for frame in 3:
		await process_frame

	var phantom_camera_manager := root.get_node_or_null("PhantomCameraManager")
	if phantom_camera_manager != null and phantom_camera_manager.has_method("scene_changed"):
		phantom_camera_manager.call("scene_changed")


func stop_level_audio(level: Node) -> void:
	for audio_player in level.find_children("*", "AudioStreamPlayer", true, false):
		var player := audio_player as AudioStreamPlayer
		player.stop()
		player.stream = null
	for audio_player in level.find_children("*", "AudioStreamPlayer2D", true, false):
		var player := audio_player as AudioStreamPlayer2D
		player.stop()
		player.stream = null


func check(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error(message)


func finish_test() -> void:
	if failures == 0:
		print("Camera rig smoke test passed.")
	else:
		push_error("Camera rig smoke test failed with %d error(s)." % failures)

	quit(failures)
