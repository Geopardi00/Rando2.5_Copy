class_name GameplayFreeze
extends RefCounted

static var _is_frozen: bool = false
static var _previous_time_scale: float = 1.0


static func freeze(duration: float = 0.05) -> void:
	if _is_frozen:
		return

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	_is_frozen = true
	_previous_time_scale = Engine.time_scale
	Engine.time_scale = 0.08

	await tree.create_timer(duration, true, false, true).timeout

	Engine.time_scale = _previous_time_scale
	_is_frozen = false
