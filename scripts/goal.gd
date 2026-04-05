extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	print("goal ready")


func _on_body_entered(body: Node) -> void:
	print("goal touched by:", body.name)

	if body.name != "Player":
		return

	print("LEVEL COMPLETE")
