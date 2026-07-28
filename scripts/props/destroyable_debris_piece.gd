class_name DestroyableDebrisPiece
extends RigidBody2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func configure(
	texture: Texture2D,
	visual_scale: Vector2,
	initial_position: Vector2,
	initial_rotation: float,
	initial_velocity: Vector2,
	initial_spin: float,
	lifetime: float,
	fade_duration: float
) -> void:
	sprite.texture = texture
	sprite.scale = Vector2(absf(visual_scale.x), absf(visual_scale.y))
	global_position = initial_position
	global_rotation = initial_rotation
	linear_velocity = initial_velocity
	angular_velocity = initial_spin

	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle != null:
		var scaled_size := texture.get_size() * sprite.scale * 0.85
		rectangle.size = Vector2(maxf(scaled_size.x, 2.0), maxf(scaled_size.y, 2.0))

	cleanup_after(lifetime, fade_duration)


func cleanup_after(lifetime: float, fade_duration: float) -> void:
	await get_tree().create_timer(maxf(lifetime, 0.0)).timeout

	if fade_duration <= 0.0:
		queue_free()
		return

	var fade_tween := create_tween()
	fade_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade_tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	await fade_tween.finished
	queue_free()
