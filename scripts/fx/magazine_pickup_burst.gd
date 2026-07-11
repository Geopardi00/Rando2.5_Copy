extends Node2D

@onready var particles: CPUParticles2D = $Particles


func play() -> void:
	particles.emitting = true
	await get_tree().create_timer(particles.lifetime + 0.2).timeout
	queue_free()
