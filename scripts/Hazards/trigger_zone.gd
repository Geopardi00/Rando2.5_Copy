extends Area2D

@export var stalactite_path: NodePath

@onready var stalactite: Node = get_node_or_null(stalactite_path)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	if stalactite != null and stalactite.has_method("trigger_fall"):
		stalactite.trigger_fall()

	queue_free()
