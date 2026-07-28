class_name DestroyableProp
extends StaticBody2D

signal damaged(current_health: int, amount: int)
signal destroyed

@export_range(1, 100, 1) var max_health: int = 3
@export var blocks_movement: bool = true
@export var hit_sound: AudioStream
@export var break_sound: AudioStream

@onready var sprite: Sprite2D = $Sprite2D
@onready var physical_collision: CollisionShape2D = $PhysicalCollision
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurtbox_collision: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var hit_particles: GPUParticles2D = $HitParticles
@onready var break_particles: GPUParticles2D = $BreakParticles

var health: int = 0
var is_destroyed: bool = false
var sprite_rest_position: Vector2
var hit_tween: Tween


func _ready() -> void:
	add_to_group("destroyable_prop")
	health = max_health
	sprite_rest_position = sprite.position

	if sprite.material != null:
		sprite.material = sprite.material.duplicate()
		set_flash_amount(0.0)

	physical_collision.disabled = not blocks_movement
	collision_layer = 1 if blocks_movement else 0
	hit_particles.emitting = false
	break_particles.emitting = false


func machete_hit(amount: int = 1, hit_position: Vector2 = Vector2.ZERO) -> void:
	take_damage(amount, hit_position, &"machete")


func take_damage(amount: int = 1, hit_position: Vector2 = Vector2.ZERO, _source: StringName = &"") -> void:
	if is_destroyed or amount <= 0:
		return

	var impact_position := hit_position
	if impact_position == Vector2.ZERO:
		impact_position = global_position

	health = maxi(health - amount, 0)
	damaged.emit(health, amount)
	play_hit_feedback(impact_position)

	if health <= 0:
		break_apart()


func play_hit_feedback(hit_position: Vector2) -> void:
	hit_particles.global_position = hit_position
	hit_particles.restart()
	spawn_sound(hit_sound, 0.9)

	if hit_tween != null and hit_tween.is_valid():
		hit_tween.kill()

	set_flash_amount(1.0)
	sprite.position = sprite_rest_position + Vector2(-2.0, 0.0)
	hit_tween = create_tween().set_parallel(true)
	hit_tween.tween_method(set_flash_amount, 1.0, 0.0, 0.1)
	hit_tween.tween_property(sprite, "position", sprite_rest_position, 0.1)


func break_apart() -> void:
	if is_destroyed:
		return

	is_destroyed = true
	destroyed.emit()

	set_deferred("collision_layer", 0)
	physical_collision.set_deferred("disabled", true)
	hurtbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("collision_layer", 0)
	hurtbox_collision.set_deferred("disabled", true)

	sprite.visible = false
	break_particles.global_position = global_position
	break_particles.restart()
	spawn_sound(break_sound, 0.65)

	await get_tree().create_timer(break_particles.lifetime + 0.2).timeout
	queue_free()


func set_flash_amount(value: float) -> void:
	var material := sprite.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("flash_amount", value)


func spawn_sound(stream: AudioStream, pitch: float) -> void:
	if stream == null or get_tree().current_scene == null:
		return

	var sound := AudioStreamPlayer2D.new()
	sound.stream = stream
	sound.volume_db = -4.0
	sound.pitch_scale = pitch * randf_range(0.94, 1.06)
	sound.global_position = global_position
	get_tree().current_scene.add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
