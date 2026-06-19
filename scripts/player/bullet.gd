extends Area2D

@export var speed: float = 600.0
@export var direction: int = 1:
	set(value):
		direction = value
		_update_sprite_flip()
@export var lifetime: float = 3.0

@onready var sprite: Sprite2D = $Sprite2D

var lifetime_remaining: float = 0.0


func _ready() -> void:
	lifetime_remaining = lifetime
	_update_sprite_flip()

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position.x += speed * direction * delta

	lifetime_remaining -= delta
	if lifetime_remaining <= 0.0:
		queue_free()


func _on_body_entered(_body: Node) -> void:
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy_hurtbox"):
		return

	var enemy := area.get_parent()
	if enemy != null and enemy.has_method("take_damage"):
		enemy.take_damage(1)

	queue_free()


func _update_sprite_flip() -> void:
	var bullet_sprite: Sprite2D = sprite
	if bullet_sprite == null:
		bullet_sprite = get_node_or_null("Sprite2D") as Sprite2D

	if bullet_sprite != null:
		bullet_sprite.flip_h = direction < 0
