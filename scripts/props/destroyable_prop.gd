class_name DestroyableProp
extends StaticBody2D

const DEBRIS_PIECE_SCENE := preload("res://scenes/props/destroyable/destroyable_debris_piece.tscn")

signal damaged(current_health: int, amount: int)
signal destroyed

@export_range(1, 100, 1) var max_health: int = 3
@export var blocks_movement: bool = true
@export var hit_sound: AudioStream
@export var break_sound: AudioStream
@export_category("Debris")
@export var debris_textures: Array[Texture2D] = []
@export_range(0.1, 10.0) var debris_lifetime: float = 1.5
@export_range(0.0, 2.0) var debris_fade_duration: float = 0.4
@export var debris_launch_strength := Vector2(150.0, 200.0)
@export_range(0.0, 20.0) var debris_max_spin: float = 7.5

@onready var sprite: Sprite2D = $Sprite2D
@onready var physical_collision: CollisionShape2D = $PhysicalCollision
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurtbox_collision: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var hit_particles: GPUParticles2D = $HitParticles

var health: int = 0
var is_destroyed: bool = false
var sprite_rest_position: Vector2
var last_hit_position: Vector2
var hit_tween: Tween


func _ready() -> void:
	add_to_group("destroyable_prop")
	health = max_health
	sprite_rest_position = sprite.position
	last_hit_position = global_position

	if sprite.material != null:
		sprite.material = sprite.material.duplicate()
		set_flash_amount(0.0)

	physical_collision.disabled = not blocks_movement
	collision_layer = 1 if blocks_movement else 0
	hit_particles.emitting = false


func machete_hit(amount: int = 1, hit_position: Vector2 = Vector2.ZERO) -> void:
	take_damage(amount, hit_position, &"machete")


func take_damage(amount: int = 1, hit_position: Vector2 = Vector2.ZERO, _source: StringName = &"") -> void:
	if is_destroyed or amount <= 0:
		return

	var impact_position := hit_position
	if impact_position == Vector2.ZERO:
		impact_position = global_position
	last_hit_position = impact_position

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

	spawn_debris()
	sprite.visible = false
	spawn_sound(break_sound, 0.65)

	var hit_effect_duration := hit_particles.lifetime / maxf(hit_particles.speed_scale, 0.001)
	await get_tree().create_timer(hit_effect_duration + 0.2).timeout
	queue_free()


func spawn_debris() -> void:
	if debris_textures.is_empty() or get_tree().current_scene == null:
		return

	var piece_count := debris_textures.size()
	var source_scale := sprite.global_transform.get_scale().abs()
	var source_size := Vector2(32.0, 32.0)
	if sprite.texture != null:
		source_size = sprite.texture.get_size() * source_scale

	var strike_direction := signf(global_position.x - last_hit_position.x)
	var launch_parent := get_tree().current_scene

	for index in piece_count:
		var texture := debris_textures[index]
		if texture == null:
			continue

		var spread_ratio := 0.0
		if piece_count > 1:
			spread_ratio = float(index) / float(piece_count - 1)
		var fan_direction := lerpf(-1.0, 1.0, spread_ratio)
		var spawn_offset := Vector2(
			fan_direction * source_size.x * 0.18,
			randf_range(-source_size.y * 0.12, source_size.y * 0.08)
		)
		var horizontal_speed := fan_direction * randf_range(
			debris_launch_strength.x * 0.65,
			debris_launch_strength.x
		)
		horizontal_speed += strike_direction * debris_launch_strength.x * 0.25
		var launch_velocity := Vector2(
			horizontal_speed,
			-randf_range(debris_launch_strength.y * 0.7, debris_launch_strength.y * 1.1)
		)
		var spin := randf_range(-debris_max_spin, debris_max_spin)
		if debris_max_spin > 0.0 and absf(spin) < debris_max_spin * 0.25:
			spin = signf(spin if spin != 0.0 else fan_direction) * debris_max_spin * 0.25

		var debris := DEBRIS_PIECE_SCENE.instantiate()
		launch_parent.add_child(debris)
		debris.configure(
			texture,
			source_scale,
			sprite.global_position + spawn_offset,
			sprite.global_rotation + randf_range(-0.08, 0.08),
			launch_velocity,
			spin,
			debris_lifetime,
			debris_fade_duration
		)


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
