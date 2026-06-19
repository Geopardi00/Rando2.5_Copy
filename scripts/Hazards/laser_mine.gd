extends Node2D

@export var trigger_delay: float = 0.2
@export var destroy_after_explosion: bool = true
@export var auto_disable_beam_on_explode: bool = true

@onready var mine_sprite: Sprite2D = $MineSprite
@onready var beam_sprite: Sprite2D = $BeamSprite
@onready var beam_trigger: Area2D = $BeamTrigger
@onready var explosion_area: Area2D = $ExplosionArea
@onready var explosion_collision: CollisionShape2D = $ExplosionArea/CollisionShape2D
@onready var explosion_particles: GPUParticles2D = get_node_or_null("ExplosionParticles") as GPUParticles2D
@onready var explosion_animation: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var explosion_sound: AudioStreamPlayer2D = get_node_or_null("ExplosionSound") as AudioStreamPlayer2D

var is_triggered: bool = false
var has_exploded: bool = false


func _ready() -> void:
	beam_sprite.visible = true
	beam_trigger.monitoring = true
	explosion_area.monitoring = false
	explosion_collision.disabled = true

	if explosion_animation != null:
		explosion_animation.visible = false
		explosion_animation.stop()
		explosion_animation.frame = 0

	beam_trigger.body_entered.connect(_on_beam_trigger_body_entered)
	explosion_area.body_entered.connect(_on_explosion_area_body_entered)


func _on_beam_trigger_body_entered(body: Node) -> void:
	if is_triggered or has_exploded:
		return

	if not body.is_in_group("player"):
		return

	is_triggered = true
	_start_trigger_sequence()


func _start_trigger_sequence() -> void:
	_flash_warning()

	await get_tree().create_timer(trigger_delay).timeout
	explode()


func explode() -> void:
	if has_exploded:
		return

	has_exploded = true
	beam_trigger.monitoring = false

	if auto_disable_beam_on_explode:
		beam_sprite.visible = false

	mine_sprite.visible = false
	_play_explosion_effects()

	# Enable the blast only at explosion time, then check anything already inside it.
	explosion_collision.disabled = false
	explosion_area.monitoring = true
	await get_tree().physics_frame

	var bodies: Array[Node2D] = explosion_area.get_overlapping_bodies()
	for body: Node2D in bodies:
		_try_kill_player(body)

	if destroy_after_explosion:
		await _wait_for_explosion_finish()
		queue_free()


func _on_explosion_area_body_entered(body: Node) -> void:
	if not has_exploded:
		return

	_try_kill_player(body)


func _try_kill_player(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("die"):
		body.die()


func _play_explosion_effects() -> void:
	if explosion_particles != null:
		explosion_particles.emitting = true

	if explosion_animation != null:
		explosion_animation.visible = true
		explosion_animation.play("mine_explosion")

	if explosion_sound != null:
		explosion_sound.play()


func _wait_for_explosion_finish() -> void:
	if explosion_animation != null and explosion_animation.is_playing():
		await explosion_animation.animation_finished

	if explosion_sound != null and explosion_sound.playing:
		await explosion_sound.finished
		return

	await get_tree().create_timer(0.35).timeout


func _flash_warning() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(beam_sprite, "modulate:a", 0.35, 0.05)
	tween.tween_property(beam_sprite, "modulate:a", 1.0, 0.05)
	tween.tween_property(mine_sprite, "scale", mine_sprite.scale * 1.08, 0.05)
	tween.tween_property(mine_sprite, "scale", mine_sprite.scale, 0.05)
