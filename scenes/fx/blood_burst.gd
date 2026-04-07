extends GPUParticles2D

func _ready() -> void:
	emitting = true
	await get_tree().create_timer(lifetime + 0.2).timeout
	queue_free()
