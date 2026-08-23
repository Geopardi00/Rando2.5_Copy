class_name BurningGround
extends Area2D

const DAMAGE_SOURCE_ENEMY: StringName = &"enemy"
const MIN_TIMER_INTERVAL: float = 0.05

@export var ground_fire_damage: int = 1
@export var ground_fire_damage_interval: float = 0.8
@export var ground_fire_lifetime: float = 4.0
@export var fade_out_time: float = 0.25
@export var patch_size: Vector2 = Vector2(72.0, 14.0):
	set(value):
		patch_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		if is_node_ready():
			_apply_patch_size()

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var fire_particles: GPUParticles2D = $FireParticles
@onready var damage_timer: Timer = $DamageTimer
@onready var lifetime_timer: Timer = $LifetimeTimer

var _is_expiring: bool = false


func _ready() -> void:
	_apply_patch_size()

	monitoring = true
	monitorable = false
	collision_shape.disabled = false

	damage_timer.one_shot = false
	damage_timer.wait_time = maxf(ground_fire_damage_interval, MIN_TIMER_INTERVAL)
	damage_timer.timeout.connect(_on_damage_timer_timeout)
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timer_timeout)

	damage_timer.start()
	refresh_lifetime()

	fire_particles.emitting = true
	fire_particles.restart()


func refresh_lifetime() -> void:
	if _is_expiring or not is_inside_tree():
		return

	lifetime_timer.start(maxf(ground_fire_lifetime, MIN_TIMER_INTERVAL))


func apply_damage_tick() -> void:
	if _is_expiring or not monitoring:
		return

	for body: Node2D in get_overlapping_bodies():
		if not body.is_in_group(&"player"):
			continue
		if body.has_method(&"take_damage"):
			body.call(&"take_damage", ground_fire_damage, false, DAMAGE_SOURCE_ENEMY)


func _apply_patch_size() -> void:
	var rectangle: RectangleShape2D = collision_shape.shape as RectangleShape2D
	if rectangle == null:
		push_warning("BurningGround requires a RectangleShape2D collision shape.")
		return

	if not rectangle.resource_local_to_scene:
		rectangle = rectangle.duplicate() as RectangleShape2D
		rectangle.resource_local_to_scene = true
		collision_shape.shape = rectangle

	rectangle.size = patch_size
	collision_shape.position.y = -patch_size.y * 0.5
	fire_particles.position.y = -patch_size.y * 0.5

	var particle_material: ParticleProcessMaterial = fire_particles.process_material as ParticleProcessMaterial
	if particle_material != null:
		if not particle_material.resource_local_to_scene:
			particle_material = particle_material.duplicate() as ParticleProcessMaterial
			particle_material.resource_local_to_scene = true
			fire_particles.process_material = particle_material
		particle_material.emission_box_extents = Vector3(
			patch_size.x * 0.42,
			maxf(patch_size.y * 0.15, 1.0),
			1.0
		)


func _on_damage_timer_timeout() -> void:
	apply_damage_tick()


func _on_lifetime_timer_timeout() -> void:
	_begin_expiration()


func _begin_expiration() -> void:
	if _is_expiring:
		return

	_is_expiring = true
	remove_from_group(&"burning_ground")
	damage_timer.stop()
	lifetime_timer.stop()
	monitoring = false
	collision_shape.set_deferred(&"disabled", true)
	fire_particles.emitting = false

	if fade_out_time <= 0.0:
		queue_free()
		return

	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(self, ^"modulate:a", 0.0, fade_out_time)
	fade_tween.finished.connect(queue_free)


func _exit_tree() -> void:
	if is_instance_valid(damage_timer):
		damage_timer.stop()
	if is_instance_valid(lifetime_timer):
		lifetime_timer.stop()
