@tool
extends Node2D

signal rider_attached(player: Node)
signal rider_detached(player: Node)

@export_category("Cable")
@export_range(4, 96, 1) var cable_samples: int = 24:
	set(value):
		cable_samples = max(value, 4)
		update_cable()
@export var cable_width: float = 4.0:
	set(value):
		cable_width = max(value, 1.0)
		update_cable()
@export var cable_outline_width: float = 2.0:
	set(value):
		cable_outline_width = max(value, 0.0)
		update_cable()
@export var cable_color: Color = Color(0.46, 0.46, 0.46, 1.0):
	set(value):
		cable_color = value
		update_cable()
@export var cable_outline_color: Color = Color(0.03, 0.03, 0.03, 1.0):
	set(value):
		cable_outline_color = value
		update_cable()
@export var natural_sag: float = 12.0:
	set(value):
		natural_sag = value
		update_cable()

@export_category("Player Bend")
@export var rider_bend_amount: float = 28.0
@export_range(0.05, 0.5) var rider_bend_radius: float = 0.2
@export var bend_response_speed: float = 10.0

@export_category("Interaction")
@export var grab_area_thickness: float = 40.0:
	set(value):
		grab_area_thickness = max(value, 4.0)
		update_grab_area()
@export var player_hang_offset: Vector2 = Vector2(0.0, 20.0)

@export_category("Movement")
@export var initial_ride_speed: float = 100.0
@export var ride_acceleration: float = 500.0
@export var maximum_ride_speed: float = 650.0
@export var minimum_downhill_speed: float = 80.0
@export var detach_jump_velocity: float = 320.0
@export var end_launch_multiplier: float = 1.0

@export_category("Debug")
@export var debug_enabled: bool = false:
	set(value):
		debug_enabled = value
		queue_redraw()

@onready var start_anchor: Marker2D = $StartAnchor
@onready var end_anchor: Marker2D = $EndAnchor
@onready var cable_outline: Line2D = $CableOutline
@onready var cable: Line2D = $Cable
@onready var grab_area: Area2D = $GrabArea
@onready var grab_shape: CollisionShape2D = $GrabArea/CollisionShape2D

var attached_player: Node = null
var rider_progress: float = 0.5
var current_bend_amount: float = 0.0


func _ready() -> void:
	update_cable()
	update_grab_area()

	if not Engine.is_editor_hint():
		if not grab_area.body_entered.is_connected(_on_grab_area_body_entered):
			grab_area.body_entered.connect(_on_grab_area_body_entered)
		if not grab_area.body_exited.is_connected(_on_grab_area_body_exited):
			grab_area.body_exited.connect(_on_grab_area_body_exited)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		update_cable()
		update_grab_area()
		return

	update_bend(delta)
	update_cable()


func update_bend(delta: float) -> void:
	if attached_player != null and not is_instance_valid(attached_player):
		detach_player(attached_player)

	var target_bend: float = 0.0
	if attached_player != null:
		target_bend = rider_bend_amount

	var weight: float = clamp(bend_response_speed * delta, 0.0, 1.0)
	current_bend_amount = lerpf(current_bend_amount, target_bend, weight)


func update_cable() -> void:
	if not is_node_ready():
		return

	cable_outline.width = cable_width + cable_outline_width * 2.0
	cable_outline.default_color = cable_outline_color
	cable_outline.clear_points()

	cable.width = cable_width
	cable.default_color = cable_color
	cable.clear_points()

	for index in cable_samples:
		var progress: float = float(index) / float(cable_samples - 1)
		var cable_position := get_cable_local_position(progress)
		cable_outline.add_point(cable_position)
		cable.add_point(cable_position)

	queue_redraw()


func update_grab_area() -> void:
	if not is_node_ready():
		return

	var start_position: Vector2 = start_anchor.position
	var end_position: Vector2 = end_anchor.position
	var difference: Vector2 = end_position - start_position
	var length: float = difference.length()

	if length <= 0.01:
		return

	var rectangle := grab_shape.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		grab_shape.shape = rectangle

	grab_area.position = start_position + difference * 0.5
	grab_area.rotation = difference.angle()
	rectangle.size = Vector2(length, grab_area_thickness + abs(natural_sag) + abs(rider_bend_amount))


func get_cable_local_position(progress: float) -> Vector2:
	progress = clamp(progress, 0.0, 1.0)

	var start_position: Vector2 = start_anchor.position
	var end_position: Vector2 = end_anchor.position
	var base_position: Vector2 = start_position.lerp(end_position, progress)
	var natural_weight: float = sin(PI * progress)
	var local_position: Vector2 = base_position + Vector2.DOWN * natural_sag * natural_weight

	if current_bend_amount > 0.01:
		var distance_from_rider: float = abs(progress - rider_progress)
		var rider_weight: float = 1.0 - clamp(distance_from_rider / rider_bend_radius, 0.0, 1.0)
		rider_weight = rider_weight * rider_weight * (3.0 - 2.0 * rider_weight)
		rider_weight *= natural_weight
		local_position += Vector2.DOWN * current_bend_amount * rider_weight

	return local_position


func get_world_position_at_progress(progress: float) -> Vector2:
	return to_global(get_cable_local_position(progress))


func get_world_tangent_at_progress(progress: float) -> Vector2:
	var before: Vector2 = get_cable_local_position(clamp(progress - 0.01, 0.0, 1.0))
	var after: Vector2 = get_cable_local_position(clamp(progress + 0.01, 0.0, 1.0))
	var tangent: Vector2 = to_global(after) - to_global(before)

	if tangent.length() <= 0.01:
		return Vector2.RIGHT

	return tangent.normalized()


func get_cable_length() -> float:
	return max(start_anchor.global_position.distance_to(end_anchor.global_position), 1.0)


func get_closest_progress_to_world_position(world_position: Vector2) -> float:
	var closest_progress: float = 0.0
	var closest_distance: float = INF
	var search_samples: int = max(cable_samples * 4, 32)

	for index in search_samples:
		var progress: float = float(index) / float(search_samples - 1)
		var distance: float = world_position.distance_squared_to(get_world_position_at_progress(progress))
		if distance < closest_distance:
			closest_distance = distance
			closest_progress = progress

	return closest_progress


func get_downhill_progress_direction() -> float:
	if end_anchor.global_position.y >= start_anchor.global_position.y:
		return 1.0

	return -1.0


func attach_player(player: Node, progress: float) -> void:
	if attached_player != null and attached_player != player:
		return

	attached_player = player
	rider_progress = clamp(progress, 0.0, 1.0)
	rider_attached.emit(player)


func detach_player(player: Node) -> void:
	if attached_player != player:
		return

	var previous_player := attached_player
	attached_player = null
	rider_detached.emit(previous_player)


func set_rider_progress(progress: float) -> void:
	rider_progress = clamp(progress, 0.0, 1.0)


func _on_grab_area_body_entered(body: Node) -> void:
	if body.has_method("register_nearby_zipline"):
		body.register_nearby_zipline(self)


func _on_grab_area_body_exited(body: Node) -> void:
	if body.has_method("unregister_nearby_zipline"):
		body.unregister_nearby_zipline(self)


func _draw() -> void:
	if not debug_enabled:
		return

	draw_circle(start_anchor.position, 6.0, Color.GREEN)
	draw_circle(end_anchor.position, 6.0, Color.RED)

	if attached_player != null:
		var rider_position := get_cable_local_position(rider_progress)
		var tangent := get_world_tangent_at_progress(rider_progress)
		draw_circle(rider_position, 5.0, Color.YELLOW)
		draw_line(rider_position, rider_position + tangent * 36.0, Color.YELLOW, 2.0)
