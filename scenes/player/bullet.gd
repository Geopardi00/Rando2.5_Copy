extends Area2D

@export var speed: float = 400.0
@export var direction: int = 1:
	set(value):
		direction = value
		_update_sprite_flip()

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_update_sprite_flip()


func _physics_process(delta: float) -> void:
	position.x += speed * direction * delta


func _update_sprite_flip() -> void:
	var bullet_sprite: Sprite2D = sprite
	if bullet_sprite == null:
		bullet_sprite = get_node_or_null("Sprite2D") as Sprite2D

	if bullet_sprite != null:
		bullet_sprite.flip_h = direction < 0
