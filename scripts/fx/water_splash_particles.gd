extends GPUParticles2D

@export var minimum_amount: int = 5
@export var maximum_amount: int = 18
@export var minimum_speed: float = 55.0
@export var maximum_speed: float = 165.0


func _ready() -> void:
	one_shot = true
	emitting = false
	if not finished.is_connected(_on_finished):
		finished.connect(_on_finished)


func emit_splash(intensity: float = 1.0) -> void:
	var normalized_intensity := clampf(intensity, 0.0, 1.0)
	amount = maxi(roundi(lerpf(float(minimum_amount), float(maximum_amount), normalized_intensity)), 1)

	var particle_material := process_material as ParticleProcessMaterial
	if particle_material != null:
		particle_material.initial_velocity_min = lerpf(minimum_speed, maximum_speed * 0.62, normalized_intensity)
		particle_material.initial_velocity_max = lerpf(minimum_speed * 1.35, maximum_speed, normalized_intensity)
		particle_material.scale_min = lerpf(0.28, 0.55, normalized_intensity)
		particle_material.scale_max = lerpf(0.7, 1.25, normalized_intensity)

	restart()
	emitting = true


func _on_finished() -> void:
	queue_free()
