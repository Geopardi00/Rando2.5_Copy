extends Area2D

@export var ammo_amount: int = 10
@export var bob_distance: float = 6.0
@export var bob_time: float = 0.75

var start_y: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	start_y = position.y
	start_bob_tween()


func start_bob_tween() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position:y", start_y - bob_distance, bob_time)
	tween.tween_property(self, "position:y", start_y + bob_distance, bob_time)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	if body.has_method("add_ammo"):
		body.add_ammo(ammo_amount)
		queue_free()
