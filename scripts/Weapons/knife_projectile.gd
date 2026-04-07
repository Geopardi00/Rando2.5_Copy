extends Area2D

@export var speed: float = 260.0
@export var lifetime: float = 2.0
@export var direction: int = -1

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	update_visual()

	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta: float) -> void:
	global_position.x += direction * speed * delta

func update_visual() -> void:
	# Knife sprite faces LEFT by default
	sprite.flip_h = direction > 0

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("die"):
			body.die()
		queue_free()
		return

	queue_free()
