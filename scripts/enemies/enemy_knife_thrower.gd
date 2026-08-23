extends CharacterBody2D

const BLOOD_BURST_SCENE := preload("res://scenes/fx/blood_burst.tscn")
const THROW_RELEASE_FRAME := 8

@export var knife_scene: PackedScene

@export var gravity: float = 1100.0
@export var max_hp: int = 3
@export var contact_damage: int = 3

@export var attack_range: float = 360.0
@export var vertical_tolerance: float = 56.0
@export var throw_cooldown: float = 1.2

@export var throw_offset: Vector2 = Vector2(28, 4)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var hit_sound: AudioStreamPlayer2D = $HitSound

var hp: int = 0
var player: Node2D = null
var is_throwing: bool = false
var pending_throw_dir: int = -1
var knife_spawned_this_throw: bool = false


func _ready() -> void:
	add_to_group("enemy")

	hp = max_hp

	cooldown_timer.wait_time = throw_cooldown
	cooldown_timer.one_shot = true

	player = get_tree().get_first_node_in_group("player") as Node2D

	# Make sure each thrower instance has its own shader material.
	if animated_sprite.material != null:
		animated_sprite.material = animated_sprite.material.duplicate()
		_set_flash_amount(0.0)

	animated_sprite.frame_changed.connect(_on_animated_sprite_frame_changed)
	animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
	animated_sprite.play("idle")


func _physics_process(delta: float) -> void:
	# Stay grounded
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	velocity.x = 0.0
	move_and_slide()

	# Refresh player ref if needed
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
		return
	if not is_player_detectable():
		cancel_pending_throw()
		return

	var dx: float = player.global_position.x - global_position.x
	var dy: float = abs(player.global_position.y - global_position.y)
	var dir: int = 1 if dx > 0.0 else -1

	update_facing(dir)

	if abs(dx) <= attack_range and dy <= vertical_tolerance and cooldown_timer.is_stopped() and not is_throwing:
		start_throw(dir)


func update_facing(dir: int) -> void:
	# Assumes enemy art faces LEFT by default.
	# If your art faces RIGHT by default, change this to:
	# animated_sprite.flip_h = dir < 0
	animated_sprite.flip_h = dir > 0


func start_throw(dir: int) -> void:
	if not is_player_detectable():
		return

	is_throwing = true
	pending_throw_dir = dir
	knife_spawned_this_throw = false
	update_facing(dir)
	animated_sprite.play("throw2")
	animated_sprite.frame = 0


func spawn_knife(dir: int) -> void:
	if knife_scene == null or not is_player_detectable():
		return

	var knife = knife_scene.instantiate()
	knife.direction = dir

	var spawn_pos: Vector2 = global_position + Vector2(throw_offset.x * dir, throw_offset.y)
	knife.global_position = spawn_pos

	get_tree().current_scene.add_child(knife)
	cooldown_timer.start()


func _on_animated_sprite_frame_changed() -> void:
	if not is_throwing:
		return
	if not is_player_detectable():
		cancel_pending_throw()
		return

	if animated_sprite.animation != "throw2":
		return

	if knife_spawned_this_throw:
		return

	if animated_sprite.frame >= THROW_RELEASE_FRAME:
		knife_spawned_this_throw = true
		spawn_knife(pending_throw_dir)


func _on_animated_sprite_animation_finished() -> void:
	if animated_sprite.animation != "throw2":
		return

	if is_throwing and not knife_spawned_this_throw:
		knife_spawned_this_throw = true
		spawn_knife(pending_throw_dir)

	is_throwing = false
	animated_sprite.play("idle")


func is_player_detectable() -> bool:
	if not is_instance_valid(player) or bool(player.get("is_dead")):
		return false

	if player.has_method("is_detectable_by_enemies"):
		return bool(player.call("is_detectable_by_enemies"))

	return true


func cancel_pending_throw() -> void:
	if not is_throwing:
		return

	is_throwing = false
	knife_spawned_this_throw = true
	animated_sprite.play("idle")


func take_damage(amount: int = 1) -> void:
	hp -= amount
	flash_hit()
	spawn_hit_sound()

	if hp <= 0:
		die()


func flash_hit() -> void:
	if animated_sprite.material == null:
		return

	var mat: ShaderMaterial = animated_sprite.material as ShaderMaterial
	if mat == null:
		return

	mat.set_shader_parameter("flash_amount", 1.0)

	var tween := create_tween()
	tween.tween_method(_set_flash_amount, 1.0, 0.0, 0.08)


func _set_flash_amount(value: float) -> void:
	if animated_sprite.material == null:
		return

	var mat: ShaderMaterial = animated_sprite.material as ShaderMaterial
	if mat == null:
		return

	mat.set_shader_parameter("flash_amount", value)


func die() -> void:
	spawn_death_fx()
	queue_free()
	
func spawn_hit_sound() -> void:
	if hit_sound == null:
		return

	if hit_sound.stream == null:
		return

	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = hit_sound.stream
	sfx.volume_db = hit_sound.volume_db
	sfx.pitch_scale = hit_sound.pitch_scale
	sfx.bus = hit_sound.bus
	sfx.global_position = global_position

	get_tree().current_scene.add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	sfx.play()


func spawn_death_fx() -> void:
	if BLOOD_BURST_SCENE == null:
		return

	var fx = BLOOD_BURST_SCENE.instantiate()
	fx.global_position = global_position
	get_tree().current_scene.add_child(fx)
