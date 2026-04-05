extends Area2D

@export var speed: float = 400.0
@export var direction: int = 1


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position.x += speed * direction * delta


func _on_area_entered(area: Area2D) -> void:
	print("bullet hit area:", area.name)

	if not area.is_in_group("enemy_hurtbox"):
		print("area is not enemy_hurtbox")
		return

	print("enemy hurtbox hit")
	var enemy := area.get_parent()
	if enemy != null and enemy.has_method("take_damage"):
		enemy.take_damage(1)

	var state := _get_state_of_game()
	if state != null and state.has_method("register_bullet_hit"):
		state.register_bullet_hit()

	queue_free()


func _get_state_of_game() -> Node:
	return get_node_or_null("/root/StateOfGame")
