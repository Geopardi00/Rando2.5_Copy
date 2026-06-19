extends Sprite2D

@export var bob_height: float = 1.5
@export var bob_time: float = 1.8
@export var rotation_amount: float = 0.6

var start_position: Vector2
var start_rotation: float

func _ready() -> void:
	start_position = position
	start_rotation = rotation_degrees

	var tween := create_tween()
	tween.set_loops()

	tween.tween_property(
		self,
		"position:y",
		start_position.y - bob_height,
		bob_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.parallel().tween_property(
		self,
		"rotation_degrees",
		start_rotation + rotation_amount,
		bob_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		self,
		"position:y",
		start_position.y + bob_height,
		bob_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.parallel().tween_property(
		self,
		"rotation_degrees",
		start_rotation - rotation_amount,
		bob_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
