extends Area2D

@export var checkpoint_spawn_path: NodePath = NodePath("CheckpointSpawn")
@export var level_id_override: String = ""

@onready var checkpoint_spawn: Marker2D = get_node_or_null(checkpoint_spawn_path) as Marker2D

var activated: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if activated:
		return

	if not body.is_in_group("player"):
		return

	var state := get_node_or_null("/root/StateOfGame")
	if state == null or not state.has_method("activate_checkpoint"):
		return

	activated = true
	state.activate_checkpoint(_get_level_id(), _get_checkpoint_position())
	show_checkpoint_message()
	print("checkpoint reached")


func _get_level_id() -> String:
	if level_id_override != "":
		return level_id_override

	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.scene_file_path != "":
		return current_scene.scene_file_path.get_file().get_basename()

	if owner != null and owner.scene_file_path != "":
		return owner.scene_file_path.get_file().get_basename()

	return ""


func _get_checkpoint_position() -> Vector2:
	if checkpoint_spawn != null:
		return checkpoint_spawn.global_position

	return global_position


func show_checkpoint_message() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var game_ui := current_scene.get_node_or_null("GameUI")
	if game_ui != null and game_ui.has_method("show_checkpoint_message"):
		game_ui.call("show_checkpoint_message")
