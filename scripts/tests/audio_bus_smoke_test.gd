extends SceneTree

const MUSIC_BUS: StringName = &"Music"
const SOUND_EFFECTS_BUS: StringName = &"Sound Effects"

const SCENE_EXPECTATIONS: Array[Dictionary] = [
	{"scene": "res://scenes/ui/main_menu.tscn", "nodes": {"ClickSound": SOUND_EFFECTS_BUS, "MainMenuMusic": MUSIC_BUS}},
	{"scene": "res://scenes/levels/level_03.tscn", "nodes": {"LevelAmbience": MUSIC_BUS, "World/BackgroundNearest/Waterfall2/WaterfallSound": SOUND_EFFECTS_BUS}},
	{"scene": "res://scenes/Intro/cut_scene.tscn", "nodes": {"Voice": SOUND_EFFECTS_BUS}},
	{"scene": "res://scenes/player/player.tscn", "nodes": {"ShootSound": SOUND_EFFECTS_BUS}},
	{"scene": "res://scenes/enemies/enemy.tscn", "nodes": {"HitSound": SOUND_EFFECTS_BUS}},
	{"scene": "res://scenes/enemies/enemy_dog.tscn", "nodes": {"HitSound": SOUND_EFFECTS_BUS}},
	{"scene": "res://scenes/enemies/enemy_knife_thrower.tscn", "nodes": {"HitSound": SOUND_EFFECTS_BUS}},
	{"scene": "res://scenes/enemies/enemy_mosquito.tscn", "nodes": {"HitSound": SOUND_EFFECTS_BUS}},
	{"scene": "res://scenes/Hazards/laser_mine.tscn", "nodes": {"ExplosionSound": SOUND_EFFECTS_BUS}},
	{"scene": "res://scenes/projectiles/final_boss_grenade.tscn", "nodes": {"ExplosionSound": SOUND_EFFECTS_BUS}},
	{"scene": "res://scenes/fx/one_shot_sound_2d.tscn", "nodes": {".": SOUND_EFFECTS_BUS, "Bullethitenemy": SOUND_EFFECTS_BUS}},
	{"scene": "res://scenes/water/water_body_2d.tscn", "nodes": {"AudioStreamPlayer2D": SOUND_EFFECTS_BUS}},
	{"scene": "res://scenes/levels/test_room.tscn", "nodes": {"Checkpoint/AudioStreamPlayer2D": SOUND_EFFECTS_BUS}},
]

var failures: int = 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	check(AudioServer.get_bus_index(MUSIC_BUS) >= 0, "Music audio bus should exist.")
	check(AudioServer.get_bus_index(SOUND_EFFECTS_BUS) >= 0, "Sound Effects audio bus should exist.")

	for expectation in SCENE_EXPECTATIONS:
		check_scene_buses(String(expectation["scene"]), expectation["nodes"] as Dictionary)

	finish_test()


func check_scene_buses(scene_path: String, expected_nodes: Dictionary) -> void:
	var packed_scene := load(scene_path) as PackedScene
	check(packed_scene != null, "%s should load." % scene_path)
	if packed_scene == null:
		return

	var instance := packed_scene.instantiate()
	for node_path in expected_nodes:
		var audio_player := instance.get_node_or_null(NodePath(node_path))
		var expected_bus := expected_nodes[node_path] as StringName
		check(audio_player != null, "%s should contain audio player %s." % [scene_path, node_path])
		if audio_player != null:
			check(audio_player.get("bus") == expected_bus, "%s:%s should use the %s bus." % [scene_path, node_path, expected_bus])

	instance.free()


func check(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error(message)


func finish_test() -> void:
	if failures == 0:
		print("Audio bus smoke test passed.")
	else:
		push_error("Audio bus smoke test failed with %d error(s)." % failures)

	quit(failures)
