extends CharacterBody2D

@export var move_speed: float = 100.0
@export var gravity: float = 1000.0
@export var move_direction: int = -1

@export var max_hp: int = 2

@onready var sprite: Sprite2D = $Sprite2D
@onready var wall_check_left: RayCast2D = $WallCheckLeft
@onready var wall_check_right: RayCast2D = $WallCheckRight
@onready var floor_check_left: RayCast2D = $FloorCheckLeft
@onready var floor_check_right: RayCast2D = $FloorCheckRight

var hp: int 
var player: Node2D

func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp
	player = get_tree().get_first_node_in_group("player") as Node2D

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


func take_damage(amount: int = 1) -> void:
	hp -= amount
	if hp <= 0:
		die()


func die() -> void:

	queue_free()


func _get_state_of_game() -> Node:
	return get_node_or_null("/root/StateOfGame")
