@tool
extends Area2D

@export var area_size: Vector2 = Vector2(180.0, 96.0):
	set(value):
		area_size = Vector2(maxf(value.x, 8.0), maxf(value.y, 8.0))
		if is_node_ready():
			_update_geometry()
@export var show_shadow_tint: bool = true:
	set(value):
		show_shadow_tint = value
		if is_node_ready():
			_update_visual()
@export var shadow_tint_color: Color = Color(0.03, 0.05, 0.12, 0.32):
	set(value):
		shadow_tint_color = value
		if is_node_ready():
			_update_visual()

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var shadow_tint: Polygon2D = $ShadowTint

var tracked_players: Array[Node] = []


func _ready() -> void:
	_update_geometry()
	_update_visual()

	if Engine.is_editor_hint():
		return

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	for player in tracked_players.duplicate():
		if is_instance_valid(player) and player.has_method("unregister_shadow_area"):
			player.call("unregister_shadow_area", self)

	tracked_players.clear()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or not body.has_method("register_shadow_area"):
		return

	if not tracked_players.has(body):
		tracked_players.append(body)

	body.call("register_shadow_area", self)


func _on_body_exited(body: Node) -> void:
	if not tracked_players.has(body):
		return

	tracked_players.erase(body)
	if is_instance_valid(body) and body.has_method("unregister_shadow_area"):
		body.call("unregister_shadow_area", self)


func _update_geometry() -> void:
	if collision_shape == null:
		return

	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = area_size

	if shadow_tint != null:
		var half_size := area_size * 0.5
		shadow_tint.polygon = PackedVector2Array([
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y),
		])


func _update_visual() -> void:
	if shadow_tint == null:
		return

	shadow_tint.visible = show_shadow_tint
	shadow_tint.color = shadow_tint_color
