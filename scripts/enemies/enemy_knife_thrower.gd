extends CharacterBody2D

@export var knife_scene: PackedScene

@export var gravity: float = 1100.0
@export var max_hp: int = 3

@export var attack_range: float = 360.0
@export var vertical_tolerance: float = 56.0
@export var throw_cooldown: float = 1.2

@export var throw_offset: Vector2 = Vector2(28, -6)

@onready var sprite: Sprite2D = $Sprite2D
@onready var cooldown_timer: Timer = $CooldownTimer

var hp: int
var player: Node2D


func _ready() -> void:
	add_to_group("enemy")

	hp = max_hp

	cooldown_timer.wait_time = throw_cooldown
	cooldown_timer.one_shot = true

	player = get_tree().get_first_node_in_group("player") as Node2D

	# Make sure each thrower instance has its own shader material.
	if sprite.material != null:
		sprite.material = sprite.material.duplicate()
		_set_flash_amount(0.0)


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

	var dx: float = player.global_position.x - global_position.x
	var dy: float = abs(player.global_position.y - global_position.y)
	var dir: int = 1 if dx > 0.0 else -1

	update_facing(dir)

	if abs(dx) <= attack_range and dy <= vertical_tolerance and cooldown_timer.is_stopped():
		throw_knife(dir)


func update_facing(dir: int) -> void:
	# Assumes enemy art faces LEFT by default.
	# If your art faces RIGHT by default, change this to:
	# sprite.flip_h = dir < 0
	sprite.flip_h = dir > 0


func throw_knife(dir: int) -> void:
	if knife_scene == null:
		return

	var knife = knife_scene.instantiate()
	knife.direction = dir

	var spawn_pos: Vector2 = global_position + Vector2(throw_offset.x * dir, throw_offset.y)
	knife.global_position = spawn_pos

	get_tree().current_scene.add_child(knife)
	cooldown_timer.start()


func take_damage(amount: int = 1) -> void:
	hp -= amount
	flash_hit()

	if hp <= 0:
		die()


func flash_hit() -> void:
	if sprite.material == null:
		return

	var mat: ShaderMaterial = sprite.material as ShaderMaterial
	if mat == null:
		return

	mat.set_shader_parameter("flash_amount", 1.0)

	var tween := create_tween()
	tween.tween_method(_set_flash_amount, 1.0, 0.0, 0.08)


func _set_flash_amount(value: float) -> void:
	if sprite.material == null:
		return

	var mat: ShaderMaterial = sprite.material as ShaderMaterial
	if mat == null:
		return

	mat.set_shader_parameter("flash_amount", value)


func die() -> void:
	queue_free()
