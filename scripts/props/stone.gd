extends RigidBody2D

@export var max_horizontal_speed: float = 45.0
@export var stop_threshold: float = 2.0

func _ready() -> void:
	lock_rotation = true

func _physics_process(_delta: float) -> void:
	rotation = 0.0
	angular_velocity = 0.0

	if abs(linear_velocity.x) > max_horizontal_speed:
		linear_velocity.x = sign(linear_velocity.x) * max_horizontal_speed

	# Kill tiny sideways drift when almost settled
	if abs(linear_velocity.x) < stop_threshold and abs(linear_velocity.y) < 5.0:
		linear_velocity.x = 0.0
