extends CharacterBody2D

const BLOOD_BURST_SCENE := preload("res://scenes/fx/blood_burst.tscn")

@export var move_speed: float = 100.0
@export var gravity: float = 1000.0
@export var move_direction: int = -1
@export var max_hp: int = 2
@export var slap_knockback_distance: float = 20.0
@export var slap_knockback_duration: float = 0.12

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var wall_check_left: RayCast2D = $WallCheckLeft
@onready var wall_check_right: RayCast2D = $WallCheckRight
@onready var floor_check_left: RayCast2D = $FloorCheckLeft
@onready var floor_check_right: RayCast2D = $FloorCheckRight
@onready var hit_sound: AudioStreamPlayer2D = $HitSound

var hp: int = 0
var is_head_turning: bool = false
var slap_knockback_timer: float = 0.0
var slap_knockback_velocity: float = 0.0


func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp

	# Give this enemy instance its own material copy.
	if animated_sprite.material != null:
		animated_sprite.material = animated_sprite.material.duplicate()
		_set_flash_amount(0.0)

	animated_sprite.play("walk")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	if slap_knockback_timer > 0.0:
		slap_knockback_timer -= delta
		velocity.x = slap_knockback_velocity
		move_and_slide()
		update_sprite_facing(get_direction_from_velocity(slap_knockback_velocity))
		return

	if should_turn_around():
		turn_around()

	velocity.x = move_direction * move_speed
	move_and_slide()

	update_sprite_facing(move_direction)


func should_turn_around() -> bool:
	if move_direction < 0:
		if wall_check_left.is_colliding():
			return true
		if not floor_check_left.is_colliding():
			return true

	if move_direction > 0:
		if wall_check_right.is_colliding():
			return true
		if not floor_check_right.is_colliding():
			return true

	return false


func turn_around() -> void:
	move_direction *= -1


func take_damage(amount: int = 1) -> void:
	hp -= amount
	flash_hit()
	spawn_hit_sound()

	if hp <= 0:
		die()


func slapped() -> void:
	take_damage(1)

	if hp > 0:
		start_slap_knockback()

	if hp > 0 and not is_head_turning and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(&"head_turn"):
		play_head_turn()


func start_slap_knockback() -> void:
	var knockback_direction := get_slap_knockback_direction()
	var duration: float = maxf(slap_knockback_duration, 0.001)

	slap_knockback_timer = duration
	slap_knockback_velocity = knockback_direction * slap_knockback_distance / duration


func get_slap_knockback_direction() -> int:
	var player := get_tree().get_first_node_in_group("player") as Node2D

	if player != null:
		if player.global_position.x < global_position.x:
			return 1
		if player.global_position.x > global_position.x:
			return -1

	if move_direction != 0:
		return -signi(move_direction)

	return 1


func get_direction_from_velocity(current_velocity: float) -> int:
	if current_velocity > 0.0:
		return 1
	if current_velocity < 0.0:
		return -1

	return 0


func update_sprite_facing(direction: int) -> void:
	if direction == 0:
		return

	# Assumes sprite faces LEFT by default.
	# If wrong, change to: animated_sprite.flip_h = direction < 0
	animated_sprite.flip_h = direction > 0


func play_head_turn() -> void:
	is_head_turning = true
	animated_sprite.play(&"head_turn")
	await animated_sprite.animation_finished

	if hp > 0 and animated_sprite.animation == &"head_turn":
		animated_sprite.play(&"walk")

	is_head_turning = false


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

	var state: Node = _get_state_of_game()
	if state != null and state.has_method("register_enemy_defeated"):
		state.register_enemy_defeated()

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


func _get_state_of_game() -> Node:
	return get_node_or_null("/root/StateOfGame")
