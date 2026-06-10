extends CharacterBody2D

const BLOOD_BURST_SCENE := preload("res://scenes/fx/blood_burst.tscn")

@export var move_speed: float = 100.0
@export var gravity: float = 1000.0
@export var move_direction: int = -1
@export var max_hp: int = 2

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var wall_check_left: RayCast2D = $WallCheckLeft
@onready var wall_check_right: RayCast2D = $WallCheckRight
@onready var floor_check_left: RayCast2D = $FloorCheckLeft
@onready var floor_check_right: RayCast2D = $FloorCheckRight
@onready var hit_sound: AudioStreamPlayer2D = $HitSound

var hp: int = 0


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

	if should_turn_around():
		turn_around()

	velocity.x = move_direction * move_speed
	move_and_slide()

	# Assumes sprite faces LEFT by default.
	# If wrong, change to: animated_sprite.flip_h = move_direction < 0
	animated_sprite.flip_h = move_direction > 0


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
