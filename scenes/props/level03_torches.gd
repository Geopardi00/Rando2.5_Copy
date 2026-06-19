extends PointLight2D

@export var min_energy: float = 0.65
@export var max_energy: float = 1.25
@export var min_scale: float = 1.7
@export var max_scale: float = 2.1
@export var min_time: float = 0.05
@export var max_time: float = 0.16

func _ready() -> void:
	_flicker_once()

func _flicker_once() -> void:
	var target_energy := randf_range(min_energy, max_energy)
	var target_scale := randf_range(min_scale, max_scale)
	var duration := randf_range(min_time, max_time)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		self,
		"energy",
		target_energy,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		self,
		"texture_scale",
		target_scale,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.finished.connect(_flicker_once)
