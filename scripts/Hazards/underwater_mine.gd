class_name UnderwaterMine
extends Node2D

signal triggered
signal exploded
signal finished

const DAMAGE_SOURCE_ENVIRONMENT: StringName = &"environment"

@export_group("Warning")
@export_range(1, 10, 1) var warning_flash_count: int = 3
@export_range(0.02, 1.0, 0.01) var flash_on_duration: float = 0.12
@export_range(0.02, 1.0, 0.01) var flash_off_duration: float = 0.12
@export var warning_color: Color = Color(1.0, 0.12, 0.08, 1.0)
@export var warning_white_color: Color = Color(2.2, 2.2, 2.2, 1.0)
@export var trigger_margin: float = 2.0

@export_group("Explosion")
@export var damage: int = 1
@export var explosion_radius: float = 72.0
@export var damage_active_duration: float = 0.12
@export var destroy_after_explosion: bool = true

@export_group("Mine Visual")
@export var mine_flip_h: bool = false
@export var mine_flip_v: bool = false

@export_group("Shockwave")
@export var shockwave_material: ShaderMaterial
@export_range(0.01, 1.0, 0.01) var shockwave_radius: float = 0.28
@export_range(0.01, 3.0, 0.01) var shockwave_speed: float = 0.7
@export_range(0.001, 0.25, 0.001) var shockwave_width: float = 0.04
@export_range(0.0, 0.1, 0.001) var shockwave_strength: float = 0.02
@export_range(0.0, 1.0, 0.001) var shockwave_aberration: float = 0.425

@onready var mine_sprite: Sprite2D = $Mine
@onready var mine_body: StaticBody2D = $Mine/MineBody
@onready var mine_body_shape: CollisionShape2D = $Mine/MineBody/CollisionShape2D
@onready var trigger_area: Area2D = $Mine/TriggerArea
@onready var trigger_shape: CollisionShape2D = $Mine/TriggerArea/CollisionShape2D
@onready var explosion_area: Area2D = $ExplosionArea
@onready var explosion_shape: CollisionShape2D = $ExplosionArea/CollisionShape2D
@onready var explosion_sprite: AnimatedSprite2D = $Explosion
@onready var explosion_sound: AudioStreamPlayer2D = $ExplosionSound
@onready var shockwave_effect: ColorRect = $ShockwaveLayer/ShockwaveEffect

var is_triggered: bool = false
var has_exploded: bool = false
var damaged_bodies: Dictionary = {}
var mine_base_modulate: Color = Color.WHITE
var shockwave_tween: Tween


func _ready() -> void:
	mine_base_modulate = mine_sprite.self_modulate
	mine_sprite.flip_h = mine_flip_h
	mine_sprite.flip_v = mine_flip_v
	explosion_sprite.visible = false
	explosion_sprite.stop()
	explosion_sprite.frame = 0
	shockwave_effect.visible = false
	if shockwave_material != null:
		shockwave_effect.material = shockwave_material.duplicate()
		_apply_shockwave_settings()
	var mine_body_circle := mine_body_shape.shape as CircleShape2D
	var trigger_circle := trigger_shape.shape as CircleShape2D
	if mine_body_circle != null and trigger_circle != null:
		var visual_scale := maxf(minf(absf(mine_sprite.scale.x), absf(mine_sprite.scale.y)), 0.001)
		trigger_circle.radius = mine_body_circle.radius + maxf(trigger_margin, 0.0) / visual_scale
	var explosion_circle := explosion_shape.shape as CircleShape2D
	if explosion_circle != null:
		explosion_circle.radius = maxf(explosion_radius, 1.0)

	trigger_area.monitoring = true
	trigger_shape.disabled = false
	mine_body.collision_layer = 1
	mine_body.collision_mask = 2
	mine_body_shape.disabled = false
	explosion_area.monitoring = false
	explosion_shape.disabled = true
	trigger_area.body_entered.connect(_on_trigger_area_body_entered)
	explosion_area.body_entered.connect(_on_explosion_area_body_entered)
	explosion_sprite.animation_finished.connect(_on_explosion_animation_finished)


func _on_trigger_area_body_entered(body: Node) -> void:
	if is_triggered or has_exploded or not body.is_in_group("player"):
		return

	is_triggered = true
	trigger_area.set_deferred("monitoring", false)
	trigger_shape.set_deferred("disabled", true)
	triggered.emit()
	_run_warning_sequence()


func _run_warning_sequence() -> void:
	for _flash_index in range(maxi(warning_flash_count, 0)):
		if has_exploded or not is_inside_tree():
			return
		mine_sprite.self_modulate = warning_color
		await get_tree().create_timer(maxf(flash_on_duration, 0.02)).timeout
		if has_exploded or not is_inside_tree():
			return
		mine_sprite.self_modulate = warning_white_color
		await get_tree().create_timer(maxf(flash_off_duration, 0.02)).timeout

	if not has_exploded:
		mine_sprite.self_modulate = mine_base_modulate
		explode()


func explode() -> void:
	if has_exploded:
		return

	has_exploded = true
	mine_sprite.self_modulate = mine_base_modulate
	mine_sprite.visible = false
	trigger_area.monitoring = false
	trigger_shape.disabled = true
	mine_body.collision_layer = 0
	mine_body.collision_mask = 0
	mine_body_shape.set_deferred("disabled", true)

	explosion_sprite.visible = true
	explosion_sprite.frame = 0
	explosion_sprite.frame_progress = 0.0
	explosion_sprite.play(&"explode")
	explosion_sound.play()
	_play_shockwave_if_configured()

	damaged_bodies.clear()
	explosion_shape.disabled = false
	explosion_area.monitoring = true
	await get_tree().physics_frame
	for body in explosion_area.get_overlapping_bodies():
		_damage_player_once(body)

	exploded.emit()
	await get_tree().create_timer(maxf(damage_active_duration, 0.02)).timeout
	explosion_area.monitoring = false
	explosion_shape.disabled = true

	if destroy_after_explosion:
		await _wait_for_effects()
		finished.emit()
		queue_free()


func _on_explosion_area_body_entered(body: Node) -> void:
	if has_exploded:
		_damage_player_once(body)


func _on_explosion_animation_finished() -> void:
	if has_exploded and explosion_sprite.animation == &"explode":
		explosion_sprite.visible = false


func _damage_player_once(body: Node) -> void:
	if damage <= 0 or not body.is_in_group("player") or damaged_bodies.has(body):
		return

	damaged_bodies[body] = true
	if body.has_method("take_damage"):
		body.call("take_damage", damage, false, DAMAGE_SOURCE_ENVIRONMENT)


func _play_shockwave_if_configured() -> void:
	var shader_material := shockwave_effect.material as ShaderMaterial
	if shader_material == null:
		return

	shockwave_effect.visible = true
	_apply_shockwave_settings()
	_set_shockwave_radius(0.0)
	if shockwave_tween != null:
		shockwave_tween.kill()
	var duration := maxf(shockwave_radius, 0.01) / maxf(shockwave_speed, 0.01)
	shockwave_tween = create_tween()
	shockwave_tween.tween_method(_set_shockwave_radius, 0.0, maxf(shockwave_radius, 0.01), duration)
	shockwave_tween.tween_callback(func() -> void: shockwave_effect.visible = false)


func _apply_shockwave_settings() -> void:
	var shader_material := shockwave_effect.material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter(&"width", shockwave_width)
	shader_material.set_shader_parameter(&"strength", shockwave_strength)
	shader_material.set_shader_parameter(&"aberration", shockwave_aberration)


func _set_shockwave_radius(value: float) -> void:
	var shader_material := shockwave_effect.material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter(&"radius", value)
	shader_material.set_shader_parameter(&"center", _get_shockwave_screen_center())


func _get_shockwave_screen_center() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2(0.5, 0.5)
	var screen_position := get_viewport().get_canvas_transform() * explosion_sprite.global_position
	return screen_position / viewport_size


func _wait_for_effects() -> void:
	if explosion_sprite.is_playing():
		await explosion_sprite.animation_finished
	if shockwave_tween != null and shockwave_tween.is_running():
		await shockwave_tween.finished
	if explosion_sound.playing:
		await explosion_sound.finished
