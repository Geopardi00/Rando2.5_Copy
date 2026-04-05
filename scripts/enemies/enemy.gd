extends CharacterBody2D

@export var move_speed: float = 60.0
@export var gravity: float = 1000.0
@export var move_direction: int = -1

@onready var sprite: Sprite2D = $Sprite2D
@onready var wall_check_left: RayCast2D = $WallCheckLeft
@onready var wall_check_right: RayCast2D = $WallCheckRight
@onready var floor_check_left: RayCast2D = $FloorCheckLeft
@onready var floor_check_right: RayCast2D = $FloorCheckRight


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	if should_turn_around():
		turn_around()

	velocity.x = move_direction * move_speed
	move_and_slide()

	sprite.flip_h = move_direction > 0


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


func take_damage(_amount: int) -> void:
	var state := _get_state_of_game()
	if state != null and state.has_method("register_enemy_defeated"):
		state.register_enemy_defeated()

	queue_free()


func _get_state_of_game() -> Node:
	return get_node_or_null("/root/StateOfGame")
