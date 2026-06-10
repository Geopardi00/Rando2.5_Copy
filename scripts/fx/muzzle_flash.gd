extends Sprite2D

@export var lifetime: float = 0.06
@export var fade_out: bool = true


func _ready() -> void:
	if lifetime <= 0.0:
		queue_free()
		return

	var tween := create_tween()

	if fade_out:
		modulate.a = 1.0
		tween.tween_property(self, "modulate:a", 0.0, lifetime)
	else:
		tween.tween_interval(lifetime)

	tween.finished.connect(queue_free)