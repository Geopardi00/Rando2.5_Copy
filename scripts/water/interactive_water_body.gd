@tool
class_name InteractiveWaterBody2D
extends WaterBody2D

const DEFAULT_SPLASH_SCENE: PackedScene = preload("res://scenes/fx/water_splash_particles.tscn")

@export_group("Perspective Surface")
@export_range(0.0, 160.0, 1.0) var perspective_height: float = 48.0:
	set(value):
		perspective_height = maxf(value, 0.0)
		_refresh_dynamic_geometry()
@export_range(0.0, 1.0, 0.01) var back_wave_scale: float = 0.42:
	set(value):
		back_wave_scale = clampf(value, 0.0, 1.0)
		_refresh_dynamic_geometry()
@export_range(1.0, 32.0, 0.5) var rear_band_depth: float = 8.0:
	set(value):
		rear_band_depth = maxf(value, 1.0)
		_refresh_dynamic_geometry()
@export var rear_water_color: Color = Color(0.16, 0.58, 0.75, 0.76):
	set(value):
		rear_water_color = value
		_refresh_dynamic_colors()
@export var front_water_color: Color = Color(0.035, 0.34, 0.56, 0.5):
	set(value):
		front_water_color = value
		_refresh_dynamic_colors()
@export var edge_color: Color = Color(0.68, 0.94, 1.0, 0.92):
	set(value):
		edge_color = value
		_refresh_dynamic_colors()

@export_group("Top Surface Shader")
@export var top_surface_color: Color = Color(0.1, 0.58, 0.79, 0.76):
	set(value):
		top_surface_color = value
		_refresh_surface_shader()
@export var top_highlight_color: Color = Color(0.72, 0.95, 1.0, 0.92):
	set(value):
		top_highlight_color = value
		_refresh_surface_shader()
@export_range(0.0, 6.0, 0.05) var surface_ripple_speed: float = 1.15:
	set(value):
		surface_ripple_speed = maxf(value, 0.0)
		_refresh_surface_shader()
@export_range(0.002, 0.12, 0.001) var surface_ripple_scale: float = 0.028:
	set(value):
		surface_ripple_scale = maxf(value, 0.002)
		_refresh_surface_shader()
@export_range(0.0, 12.0, 0.1) var surface_distortion_strength: float = 2.4:
	set(value):
		surface_distortion_strength = maxf(value, 0.0)
		_refresh_surface_shader()
@export_range(-100.0, 100.0, 0.5) var surface_horizontal_flow_speed: float = 12.0:
	set(value):
		surface_horizontal_flow_speed = value
		_refresh_surface_shader()
@export_range(0.0, 1.0, 0.01) var surface_noise_strength: float = 0.18:
	set(value):
		surface_noise_strength = clampf(value, 0.0, 1.0)
		_refresh_surface_shader()
@export_range(0.0, 1.0, 0.01) var surface_opacity: float = 0.82:
	set(value):
		surface_opacity = clampf(value, 0.0, 1.0)
		_refresh_surface_shader()

@export_group("Reusable Splash")
@export var water_splash_scene: PackedScene = DEFAULT_SPLASH_SCENE
@export var splash_particles_enabled: bool = true
@export_range(0.0, 600.0, 1.0) var max_splash_force: float = 260.0
@export_range(0.0, 1.0, 0.01) var adjacent_splash_ratio: float = 0.3
@export_range(0.0, 200.0, 1.0) var minimum_particle_force: float = 8.0
@export_range(1.0, 600.0, 1.0) var full_particle_force: float = 180.0

@onready var back_water_visual: Node2D = $BackWaterVisual
@onready var rear_water_strip: Polygon2D = $BackWaterVisual/RearWaterStrip
@onready var rear_water_edge: Line2D = $BackWaterVisual/RearWaterEdge
@onready var top_surface_visual: Polygon2D = $TopSurfaceVisual
@onready var front_water_visual: Node2D = $FrontWaterVisual
@onready var front_water_body: Polygon2D = $FrontWaterVisual/WaterBody
@onready var front_water_edge: Line2D = $FrontWaterVisual/FrontWaterEdge

var _front_edge_points := PackedVector2Array()
var _back_edge_points := PackedVector2Array()
var _top_polygon_points := PackedVector2Array()
var _rear_strip_points := PackedVector2Array()
var _front_body_points := PackedVector2Array()


func _ready() -> void:
	super()
	water_fill.visible = false
	water_surface.visible = false
	_refresh_dynamic_colors()
	_refresh_surface_shader()
	update_surface_geometry()


func configure_volume() -> void:
	super()
	_refresh_dynamic_geometry()


func update_visuals() -> void:
	super()
	_refresh_dynamic_colors()
	_refresh_surface_shader()


func update_surface_geometry() -> void:
	super()
	if not is_node_ready() or top_surface_visual == null:
		return

	var point_count := maxi(ripple_heights.size(), 2)
	_front_edge_points.resize(point_count)
	_back_edge_points.resize(point_count)
	_top_polygon_points.resize(point_count * 2)
	_rear_strip_points.resize(point_count * 2)
	_front_body_points.resize(point_count + 2)

	var half_width := water_size.x * 0.5
	for index in point_count:
		var ratio := float(index) / float(point_count - 1)
		var spring_height := 0.0
		if has_visible_surface and ripple_enabled and index < ripple_heights.size():
			spring_height = ripple_heights[index]
		var x_position := lerpf(-half_width, half_width, ratio)
		var front_point := Vector2(x_position, spring_height)
		var back_point := Vector2(
			x_position,
			-perspective_height + spring_height * back_wave_scale
		)
		_front_edge_points[index] = front_point
		_back_edge_points[index] = back_point
		_top_polygon_points[index] = back_point
		_top_polygon_points[point_count + index] = _front_edge_points[point_count - 1 - index]
		_rear_strip_points[index] = back_point
		_rear_strip_points[point_count + index] = (
			_back_edge_points[point_count - 1 - index] + Vector2(0.0, rear_band_depth)
		)
		_front_body_points[index] = front_point

	_front_body_points[point_count] = Vector2(half_width, water_size.y)
	_front_body_points[point_count + 1] = Vector2(-half_width, water_size.y)

	rear_water_strip.polygon = _rear_strip_points
	rear_water_edge.points = _back_edge_points
	top_surface_visual.polygon = _top_polygon_points
	front_water_body.polygon = _front_body_points
	front_water_edge.points = _front_edge_points

	back_water_visual.visible = has_visible_surface
	top_surface_visual.visible = has_visible_surface
	front_water_edge.visible = has_visible_surface


func update_surface_crossings() -> void:
	# This variant uses WaterArea entry/exit for every CharacterBody2D and
	# RigidBody2D. Disable the base player/Crate polling path so a slow-moving
	# body cannot create a second splash when its origin crosses the surface.
	pass


func apply_ripple_impulse(world_x: float, impact_velocity: float, mass: float = 1.0) -> float:
	var scaled_force := impact_velocity * maxf(mass, 0.0) * ripple_impact_scale
	return _apply_spring_impulse(world_x, scaled_force)


func splash(global_x_position: float, force: float, spawn_particles: bool = true) -> float:
	var applied_force := _apply_spring_impulse(global_x_position, force)
	if spawn_particles and not is_zero_approx(applied_force):
		_spawn_splash_particles(global_x_position, absf(applied_force))
	return applied_force


func create_surface_splash(body: Node2D, entering: bool, impact_velocity: float = NAN) -> float:
	var applied_force := super(body, entering, impact_velocity)
	if not is_zero_approx(applied_force):
		_spawn_splash_particles(body.global_position.x, absf(applied_force))
	return applied_force


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D or body is RigidBody2D:
		create_surface_splash(body, true)
	super(body)


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D or body is RigidBody2D:
		create_surface_splash(body, false)
	super(body)


func get_surface_global_position(global_x_position: float) -> Vector2:
	if ripple_heights.is_empty():
		return to_global(Vector2(to_local(Vector2(global_x_position, global_position.y)).x, 0.0))

	var local_x := clampf(
		to_local(Vector2(global_x_position, global_position.y)).x,
		-water_size.x * 0.5,
		water_size.x * 0.5
	)
	var ratio := inverse_lerp(-water_size.x * 0.5, water_size.x * 0.5, local_x)
	var index := clampi(roundi(ratio * float(ripple_heights.size() - 1)), 0, ripple_heights.size() - 1)
	var surface_height := ripple_heights[index] if ripple_enabled and has_visible_surface else 0.0
	return to_global(Vector2(local_x, surface_height))


func _apply_spring_impulse(global_x_position: float, force: float) -> float:
	if not has_visible_surface or not ripple_enabled or ripple_velocities.is_empty():
		return 0.0

	var local_x := to_local(Vector2(global_x_position, global_position.y)).x
	if absf(local_x) > water_size.x * 0.5:
		return 0.0

	var ratio := inverse_lerp(-water_size.x * 0.5, water_size.x * 0.5, local_x)
	var spring_index := clampi(roundi(ratio * float(ripple_velocities.size() - 1)), 0, ripple_velocities.size() - 1)
	var force_limit := minf(maxf(max_splash_force, 0.0), maxf(ripple_maximum_impact_speed, 0.0))
	var clamped_force := clampf(force, -force_limit, force_limit)
	var previous_velocity := ripple_velocities[spring_index]
	ripple_velocities[spring_index] = clampf(
		previous_velocity + clamped_force,
		-force_limit,
		force_limit
	)

	var neighbour_force := clamped_force * clampf(adjacent_splash_ratio, 0.0, 1.0)
	if spring_index > 0:
		ripple_velocities[spring_index - 1] = clampf(
			ripple_velocities[spring_index - 1] + neighbour_force,
			-force_limit,
			force_limit
		)
	if spring_index < ripple_velocities.size() - 1:
		ripple_velocities[spring_index + 1] = clampf(
			ripple_velocities[spring_index + 1] + neighbour_force,
			-force_limit,
			force_limit
		)

	ripple_is_active = ripple_is_active or not is_zero_approx(clamped_force)
	return ripple_velocities[spring_index] - previous_velocity


func _spawn_splash_particles(global_x_position: float, force: float) -> void:
	if (
		not splash_particles_enabled
		or water_splash_scene == null
		or force < maxf(minimum_particle_force, 0.0)
		or get_tree() == null
	):
		return

	# Keep the short-lived effect under the WaterBody. The level root may still
	# be assembling children when an initial Area overlap notification arrives.
	if not is_inside_tree() or not is_node_ready():
		return

	var effect := water_splash_scene.instantiate() as GPUParticles2D
	if effect == null:
		return

	add_child(effect)
	effect.global_position = get_surface_global_position(global_x_position)
	var force_range := maxf(full_particle_force - minimum_particle_force, 1.0)
	var intensity := clampf((force - minimum_particle_force) / force_range, 0.0, 1.0)
	if effect.has_method("emit_splash"):
		effect.call("emit_splash", intensity)
	else:
		effect.restart()
		effect.emitting = true


func _refresh_dynamic_geometry() -> void:
	if is_node_ready():
		update_surface_geometry()


func _refresh_dynamic_colors() -> void:
	if not is_node_ready() or rear_water_strip == null:
		return
	rear_water_strip.color = rear_water_color
	rear_water_edge.default_color = edge_color.darkened(0.12)
	front_water_body.color = front_water_color
	front_water_edge.default_color = edge_color


func _refresh_surface_shader() -> void:
	if not is_node_ready() or top_surface_visual == null:
		return
	var shader_material := top_surface_visual.material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter(&"surface_color", top_surface_color)
	shader_material.set_shader_parameter(&"highlight_color", top_highlight_color)
	shader_material.set_shader_parameter(&"ripple_speed", surface_ripple_speed)
	shader_material.set_shader_parameter(&"ripple_scale", surface_ripple_scale)
	shader_material.set_shader_parameter(&"distortion_strength", surface_distortion_strength)
	shader_material.set_shader_parameter(&"horizontal_flow_speed", surface_horizontal_flow_speed)
	shader_material.set_shader_parameter(&"noise_strength", surface_noise_strength)
	shader_material.set_shader_parameter(&"surface_opacity", surface_opacity)
