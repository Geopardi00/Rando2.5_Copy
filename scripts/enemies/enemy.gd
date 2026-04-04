extends CharacterBody2D

@export var move_speed: float = 60.0
@export var gravity: float = 1000.0
@export var move_direction: int = -1

@onready var sprite: Sprite2D = $Sprite2D
@onready var wall_check_left: RayCast2D = $WallCheckLeft
@onready var wall_check_right: RayCast2D = $WallCheckRight


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	velocity.x = move_direction * move_speed

	if move_direction < 0 and wall_check_left.is_colliding():
		turn_around()
	elif move_direction > 0 and wall_check_right.is_colliding():
		turn_around()

	move_and_slide()

	sprite.flip_h = move_direction > 0


func turn_around() -> void:
	move_direction *= -1


func take_damage(_amount: int) -> void:
	queue_free()
