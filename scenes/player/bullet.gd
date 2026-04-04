extends Area2D

@export var speed: float = 400.0
@export var direction: int = 1


func _physics_process(delta: float) -> void:
	position.x += speed * direction * delta
