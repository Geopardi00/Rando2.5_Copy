extends Area2D

func _ready() -> void:
	print("Spike ready")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	print("Spike touched by: ", body.name)

	if body.is_in_group("player"):
		print("Player hit spike")

		if body.has_method("die"):
			body.die()
		elif body.has_method("respawn"):
			body.respawn()
