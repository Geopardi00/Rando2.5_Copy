class_name WaterBody2D
extends Node2D

signal surface_crossed(body: Node2D, world_position: Vector2, strength: float, entering: bool)

@export_group("Volume")
@export var water_size: Vector2 = Vector2(800.0, 360.0):
	set(value):
		water_size = Vector2(maxf(value.x, 32.0), maxf(value.y, 32.0))
		if is_node_ready():
			configure_volume()

@export_group("Visuals")
@export var water_color: Color = Color(0.08, 0.55, 0.82, 1.0):
	set(value):
		water_color = value
		if is_node_ready():
			update_visuals()
@export_range(0.0, 1.0, 0.01) var water_opacity: float = 0.68:
	set(value):
		water_opacity = clampf(value, 0.0, 1.0)
		if is_node_ready():
			update_visuals()
@export var has_visible_surface: bool = true:
	set(value):
		has_visible_surface = value
		if is_node_ready():
			configure_ripple()

@export_group("Swimming")
@export_range(0.05, 1.5, 0.05) var swim_speed_multiplier: float = 1.0
@export_range(0.05, 1.5, 0.05) var swim_acceleration_multiplier: float = 0.5
@export_range(0.0, 1.5, 0.05) var gravity_multiplier: float = 1.0
@export var maximum_underwater_fall_speed: float = 130.0
@export var vertical_swim_speed: float = 120.0
@export var water_drag: float = 220.0
@export var surface_exit_boost: float = 280.0

@export_group("Breath")
@export var breath_duration: float = 5.0
@export var damage_interval: float = 3.0
@export var damage_amount: int = 1

@export_group("Splash")
@export var splash_cooldown: float = 0.22

@export_group("Ripple")
@export var ripple_enabled: bool = true
@export_range(16, 256, 1) var ripple_point_count: int = 128
@export_range(0.0, 80.0, 0.5) var ripple_tension: float = 24.0
@export_range(0.0, 20.0, 0.1) var ripple_damping: float = 3.0
@export_range(0.0, 30.0, 0.1) var ripple_spread: float = 8.0
@export_range(1, 16, 1) var ripple_propagation_passes: int = 8
@export_range(0.0, 20.0, 0.01) var ripple_impact_scale: float = 0.65
@export var ripple_maximum_impact_speed: float = 220.0
@export var ripple_maximum_height: float = 24.0

@onready var water_area: Area2D = $WaterArea
@onready var water_shape: CollisionShape2D = $WaterArea/CollisionShape2D
@onready var water_head_area: Area2D = $WaterHeadArea
@onready var water_head_shape: CollisionShape2D = $WaterHeadArea/CollisionShape2D
@onready var water_fill: Polygon2D = $WaterFill
@onready var water_surface: Line2D = $WaterSurface
@onready var splash_particles: GPUParticles2D = $SplashEffects
@onready var bubble_particles: GPUParticles2D = $BubbleParticles
@onready var splash_audio: AudioStreamPlayer2D = $AudioStreamPlayer2D

var ripple_heights: PackedFloat32Array = PackedFloat32Array()
var ripple_velocities: PackedFloat32Array = PackedFloat32Array()
var ripple_left_deltas: PackedFloat32Array = PackedFloat32Array()
var ripple_right_deltas: PackedFloat32Array = PackedFloat32Array()
var ripple_is_active: bool = false
var submerged_players: Array[Node2D] = []
var splash_cooldowns: Dictionary = {}
var tracked_surface_positions: Dictionary = {}


func _ready() -> void:
	add_to_group("water_body")
	water_area.body_entered.connect(_on_body_entered)
	water_area.body_exited.connect(_on_body_exited)
	water_head_area.area_entered.connect(_on_area_entered)
	water_head_area.area_exited.connect(_on_area_exited)
	configure_particles()
	configure_volume()


func contains_body(body: Node2D) -> bool:
	if body == null:
		return false

	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	return contains_collision_shape(shape_node, body.global_position)


func contains_head_sensor(body: Node2D) -> bool:
	if body == null:
		return false

	var shape_node := body.get_node_or_null("WaterHeadSensor/CollisionShape2D") as CollisionShape2D
	return contains_collision_shape(shape_node, body.global_position)


func contains_collision_shape(shape_node: CollisionShape2D, fallback_center: Vector2) -> bool:
	var body_center := fallback_center
	var body_half_size := Vector2.ZERO
	if shape_node != null:
		body_center = shape_node.global_position
		var rectangle := shape_node.shape as RectangleShape2D
		if rectangle != null:
			body_half_size = rectangle.size * 0.5 * shape_node.global_scale.abs()

	var corners := [
		body_center + Vector2(-body_half_size.x, -body_half_size.y),
		body_center + Vector2(body_half_size.x, -body_half_size.y),
		body_center + Vector2(body_half_size.x, body_half_size.y),
		body_center + Vector2(-body_half_size.x, body_half_size.y),
	]
	var local_min := Vector2(INF, INF)
	var local_max := Vector2(-INF, -INF)
	for corner in corners:
		var local_corner := to_local(corner)
		local_min.x = minf(local_min.x, local_corner.x)
		local_min.y = minf(local_min.y, local_corner.y)
		local_max.x = maxf(local_max.x, local_corner.x)
		local_max.y = maxf(local_max.y, local_corner.y)

	var half_width := water_size.x * 0.5
	return local_max.x >= -half_width and local_min.x <= half_width and local_max.y >= 0.0 and local_min.y <= water_size.y


func is_body_above_surface(body: Node2D) -> bool:
	if body == null or not has_visible_surface:
		return false
	var local_body := to_local(body.global_position)
	return local_body.y <= 0.0 and absf(local_body.x) <= water_size.x * 0.5 + 4.0


func is_body_reported_inside(body: Node2D) -> bool:
	return body != null and water_area.overlaps_body(body)


func _physics_process(delta: float) -> void:
	update_splash_cooldowns(delta)
	update_surface_crossings()
	update_ripple(delta)
	update_bubbles()


func configure_volume() -> void:
	var rectangle := water_shape.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		water_shape.shape = rectangle

	rectangle.size = water_size
	water_shape.position = Vector2(0.0, water_size.y * 0.5)

	var head_rectangle := water_head_shape.shape as RectangleShape2D
	if head_rectangle == null:
		head_rectangle = RectangleShape2D.new()
		water_head_shape.shape = head_rectangle
	head_rectangle.size = water_size
	water_head_shape.position = Vector2(0.0, water_size.y * 0.5)
	configure_ripple()
	update_visuals()


func configure_ripple() -> void:
	water_surface.visible = has_visible_surface
	var point_count := maxi(ripple_point_count, 4)
	ripple_heights.resize(point_count)
	ripple_velocities.resize(point_count)
	ripple_left_deltas.resize(point_count)
	ripple_right_deltas.resize(point_count)
	ripple_heights.fill(0.0)
	ripple_velocities.fill(0.0)
	ripple_left_deltas.fill(0.0)
	ripple_right_deltas.fill(0.0)
	ripple_is_active = false
	update_surface_geometry()


func update_visuals() -> void:
	var fill_color := water_color
	fill_color.a *= water_opacity
	water_fill.color = fill_color

	var surface_color := water_color.lightened(0.42)
	surface_color.a = minf(water_opacity + 0.22, 1.0)
	water_surface.default_color = surface_color
	update_surface_geometry()


func configure_particles() -> void:
	splash_particles.emitting = false
	splash_particles.process_mode = Node.PROCESS_MODE_DISABLED

	var bubble_material := ParticleProcessMaterial.new()
	bubble_material.direction = Vector3(0.0, -1.0, 0.0)
	bubble_material.spread = 24.0
	bubble_material.gravity = Vector3(0.0, -18.0, 0.0)
	bubble_material.initial_velocity_min = 8.0
	bubble_material.initial_velocity_max = 22.0
	bubble_material.scale_min = 0.01
	bubble_material.scale_max = 1.0
	bubble_material.color = Color(0.75, 0.95, 1.0, 0.72)
	bubble_particles.process_material = bubble_material
	bubble_particles.amount = 10
	bubble_particles.lifetime = 1.3
	bubble_particles.randomness = 0.7
	bubble_particles.emitting = false


func update_ripple(delta: float, refresh_surface_geometry: bool = true) -> void:
	if not has_visible_surface or not ripple_enabled or ripple_heights.is_empty() or not ripple_is_active:
		return

	var simulation_delta := minf(delta, 1.0 / 30.0)
	var maximum_impact := maxf(ripple_maximum_impact_speed, 0.0)
	var maximum_height := maxf(ripple_maximum_height, 0.0)
	for index in ripple_heights.size():
		var acceleration := -ripple_tension * ripple_heights[index] - ripple_damping * ripple_velocities[index]
		ripple_velocities[index] = clampf(
			ripple_velocities[index] + acceleration * simulation_delta,
			-maximum_impact,
			maximum_impact
		)
		ripple_heights[index] = clampf(
			ripple_heights[index] + ripple_velocities[index] * simulation_delta,
			-maximum_height,
			maximum_height
		)

	var propagation_scale := ripple_spread * simulation_delta / float(maxi(ripple_propagation_passes, 1))
	for iteration in ripple_propagation_passes:
		ripple_left_deltas.fill(0.0)
		ripple_right_deltas.fill(0.0)
		for index in ripple_heights.size():
			if index > 0:
				ripple_left_deltas[index] = propagation_scale * (ripple_heights[index] - ripple_heights[index - 1])
				ripple_velocities[index - 1] += ripple_left_deltas[index]
			if index < ripple_heights.size() - 1:
				ripple_right_deltas[index] = propagation_scale * (ripple_heights[index] - ripple_heights[index + 1])
				ripple_velocities[index + 1] += ripple_right_deltas[index]

		for index in ripple_heights.size():
			if index > 0:
				ripple_heights[index - 1] += ripple_left_deltas[index]
			if index < ripple_heights.size() - 1:
				ripple_heights[index + 1] += ripple_right_deltas[index]

		for index in ripple_heights.size():
			ripple_velocities[index] = clampf(ripple_velocities[index], -maximum_impact, maximum_impact)
			ripple_heights[index] = clampf(ripple_heights[index], -maximum_height, maximum_height)

	ripple_is_active = false
	for index in ripple_heights.size():
		if absf(ripple_heights[index]) > 0.01 or absf(ripple_velocities[index]) > 0.05:
			ripple_is_active = true
			break
	if not ripple_is_active:
		ripple_heights.fill(0.0)
		ripple_velocities.fill(0.0)

	if refresh_surface_geometry:
		update_surface_geometry()


func update_surface_geometry() -> void:
	if water_fill == null or water_surface == null:
		return

	var half_width := water_size.x * 0.5
	var surface_points := PackedVector2Array()
	var fill_points := PackedVector2Array()
	var point_count := maxi(ripple_heights.size(), 2)

	for index in point_count:
		var ratio := float(index) / float(point_count - 1)
		var height := ripple_heights[index] if index < ripple_heights.size() and ripple_enabled and has_visible_surface else 0.0
		var point := Vector2(lerpf(-half_width, half_width, ratio), height)
		surface_points.append(point)
		fill_points.append(point)

	fill_points.append(Vector2(half_width, water_size.y))
	fill_points.append(Vector2(-half_width, water_size.y))
	water_surface.points = surface_points
	water_fill.polygon = fill_points


func apply_ripple_impulse(world_x: float, impact_velocity: float, mass: float = 1.0) -> float:
	if not has_visible_surface or not ripple_enabled or ripple_velocities.is_empty():
		return 0.0

	var local_x := to_local(Vector2(world_x, global_position.y)).x
	if absf(local_x) > water_size.x * 0.5:
		return 0.0

	var ratio := inverse_lerp(-water_size.x * 0.5, water_size.x * 0.5, local_x)
	var index := clampi(roundi(ratio * float(ripple_velocities.size() - 1)), 0, ripple_velocities.size() - 1)
	var maximum_impact := maxf(ripple_maximum_impact_speed, 0.0)
	var impulse := clampf(impact_velocity * maxf(mass, 0.0) * ripple_impact_scale, -maximum_impact, maximum_impact)
	var previous_velocity := ripple_velocities[index]
	ripple_velocities[index] = clampf(previous_velocity + impulse, -maximum_impact, maximum_impact)
	ripple_is_active = ripple_is_active or not is_zero_approx(ripple_velocities[index])
	return ripple_velocities[index] - previous_velocity


func create_surface_splash(body: Node2D, entering: bool, impact_velocity: float = NAN) -> float:
	if not has_visible_surface or splash_cooldowns.has(body):
		return 0.0

	var vertical_speed := get_body_vertical_velocity(body) if is_nan(impact_velocity) else impact_velocity
	var rigid_body := body as RigidBody2D
	var impact_mass := rigid_body.mass if rigid_body != null else 1.0

	var local_body := to_local(body.global_position)
	if absf(local_body.x) > water_size.x * 0.5 or absf(local_body.y) > 72.0:
		return 0.0

	splash_cooldowns[body] = splash_cooldown
	var applied_impulse := apply_ripple_impulse(body.global_position.x, vertical_speed, impact_mass)
	var strength := absf(applied_impulse)
	if splash_audio.stream != null:
		splash_audio.play()
	surface_crossed.emit(body, Vector2(body.global_position.x, global_position.y), strength, entering)
	return applied_impulse


func update_surface_crossings() -> void:
	if not has_visible_surface or get_tree() == null:
		tracked_surface_positions.clear()
		return

	var tracked_bodies: Array[Node] = []
	tracked_bodies.append_array(get_tree().get_nodes_in_group("player"))
	tracked_bodies.append_array(get_tree().get_nodes_in_group("Crate"))

	var seen_bodies: Dictionary = {}
	for node in tracked_bodies:
		var body := node as Node2D
		if body == null or not is_instance_valid(body) or seen_bodies.has(body):
			continue
		seen_bodies[body] = true

		var local_root := to_local(body.global_position)
		var current_velocity := get_body_vertical_velocity(body)
		var current_positions := Vector3(local_root.y, get_body_bottom_local_y(body), current_velocity)
		if tracked_surface_positions.has(body):
			var previous_positions: Vector3 = tracked_surface_positions[body]
			var downward_velocity := maxf(previous_positions.z, current_velocity)
			var upward_velocity := minf(previous_positions.z, current_velocity)
			var within_surface_width := absf(local_root.x) <= water_size.x * 0.5 + 16.0
			if within_surface_width and previous_positions.y < 0.0 and current_positions.y >= 0.0 and downward_velocity >= 0.0:
				create_surface_splash(body, true, downward_velocity)
			elif within_surface_width and previous_positions.x > 0.0 and current_positions.x <= 0.0 and upward_velocity < 0.0:
				create_surface_splash(body, false, upward_velocity)

		tracked_surface_positions[body] = current_positions

	for body in tracked_surface_positions.keys():
		if not seen_bodies.has(body) or not is_instance_valid(body):
			tracked_surface_positions.erase(body)


func get_body_vertical_velocity(body: Node2D) -> float:
	var character_body := body as CharacterBody2D
	if character_body != null:
		return character_body.velocity.y

	var rigid_body := body as RigidBody2D
	if rigid_body != null:
		return rigid_body.linear_velocity.y

	return 0.0


func get_body_bottom_local_y(body: Node2D) -> float:
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return to_local(body.global_position).y

	var bottom_position := shape_node.global_position
	var rectangle := shape_node.shape as RectangleShape2D
	if rectangle != null:
		bottom_position.y += rectangle.size.y * 0.5 * absf(shape_node.global_scale.y)
	return to_local(bottom_position).y


func update_splash_cooldowns(delta: float) -> void:
	for body in splash_cooldowns.keys():
		var remaining: float = splash_cooldowns[body] - delta
		if remaining <= 0.0 or not is_instance_valid(body):
			splash_cooldowns.erase(body)
		else:
			splash_cooldowns[body] = remaining


func update_bubbles() -> void:
	for index in range(submerged_players.size() - 1, -1, -1):
		if not is_instance_valid(submerged_players[index]):
			submerged_players.remove_at(index)

	if submerged_players.is_empty():
		bubble_particles.emitting = false
		return

	bubble_particles.global_position = submerged_players[0].global_position + Vector2(0.0, -12.0)
	bubble_particles.emitting = true


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or not body.has_method("enter_water"):
		return

	body.call("enter_water", self)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player") or not body.has_method("exit_water"):
		return

	var local_body := to_local(body.global_position)
	var exited_through_surface := has_visible_surface and local_body.y <= 0.0 and absf(local_body.x) <= water_size.x * 0.5 + 4.0
	body.call("exit_water", self, global_position.y, exited_through_surface)


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("water_head_sensor"):
		return

	var player := area.get_parent() as Node2D
	if player == null or not player.has_method("set_head_submerged"):
		return

	if not submerged_players.has(player):
		submerged_players.append(player)
	player.call("set_head_submerged", self, true)


func _on_area_exited(area: Area2D) -> void:
	if not area.is_in_group("water_head_sensor"):
		return

	var player := area.get_parent() as Node2D
	if player == null:
		return

	submerged_players.erase(player)
	if player.has_method("set_head_submerged"):
		player.call("set_head_submerged", self, false)
