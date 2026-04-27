extends Area2D

@export var speed: float = 520.0
@export var damage: int = 1
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.LEFT
var lifetime_remaining: float = 0.0


func _ready() -> void:
	lifetime_remaining = lifetime
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta

	lifetime_remaining -= delta
	if lifetime_remaining <= 0.0:
		queue_free()


func setup(new_direction: Vector2, new_damage: int = 1) -> void:
	direction = new_direction.normalized()
	damage = new_damage
	rotation = direction.angle()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		elif body.has_method("die"):
			body.die()

	queue_free()


func _on_area_entered(area: Area2D) -> void:
	var owner := area.get_parent()
	if owner != null and owner.is_in_group("player"):
		if owner.has_method("take_damage"):
			owner.take_damage(damage)
		queue_free()


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
