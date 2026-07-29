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
@export var splash_minimum_entry_speed: float = 120.0
@export var splash_strength_multiplier: float = 0.035
@export var splash_cooldown: float = 0.22

@export_group("Ripple")
@export var ripple_enabled: bool = true
@export_range(4, 64, 1) var ripple_point_count: int = 28
@export var ripple_strength: float = 0.32
@export_range(0.8, 0.999, 0.001) var ripple_damping: float = 0.94
@export var ripple_spread: float = 22.0

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
var submerged_players: Array[Node2D] = []
var splash_cooldowns: Dictionary = {}


func _ready() -> void:
	water_area.body_entered.connect(_on_body_entered)
	water_area.body_exited.connect(_on_body_exited)
	water_head_area.area_entered.connect(_on_area_entered)
	water_head_area.area_exited.connect(_on_area_exited)
	configure_particles()
	configure_volume()


func _physics_process(delta: float) -> void:
	update_splash_cooldowns(delta)
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
	ripple_heights.fill(0.0)
	ripple_velocities.fill(0.0)
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
	var splash_material := ParticleProcessMaterial.new()
	splash_material.direction = Vector3(0.0, -1.0, 0.0)
	splash_material.spread = 48.0
	splash_material.gravity = Vector3(0.0, 260.0, 0.0)
	splash_material.initial_velocity_min = 90.0
	splash_material.initial_velocity_max = 150.0
	splash_material.scale_min = 1.4
	splash_material.scale_max = 3.2
	splash_material.color = Color(0.65, 0.92, 1.0, 0.9)
	splash_particles.process_material = splash_material
	splash_particles.amount = 18
	splash_particles.lifetime = 0.65
	splash_particles.one_shot = true
	splash_particles.explosiveness = 0.9
	splash_particles.emitting = false

	var bubble_material := ParticleProcessMaterial.new()
	bubble_material.direction = Vector3(0.0, -1.0, 0.0)
	bubble_material.spread = 24.0
	bubble_material.gravity = Vector3(0.0, -18.0, 0.0)
	bubble_material.initial_velocity_min = 8.0
	bubble_material.initial_velocity_max = 22.0
	bubble_material.scale_min = 0.8
	bubble_material.scale_max = 2.1
	bubble_material.color = Color(0.75, 0.95, 1.0, 0.72)
	bubble_particles.process_material = bubble_material
	bubble_particles.amount = 10
	bubble_particles.lifetime = 1.3
	bubble_particles.randomness = 0.7
	bubble_particles.emitting = false


func update_ripple(delta: float) -> void:
	if not has_visible_surface or not ripple_enabled or ripple_heights.is_empty():
		return

	var frame_damping := pow(ripple_damping, delta * 60.0)
	for index in ripple_heights.size():
		var acceleration := -ripple_heights[index] * 24.0
		ripple_velocities[index] = (ripple_velocities[index] + acceleration * delta) * frame_damping
		ripple_heights[index] = clampf(ripple_heights[index] + ripple_velocities[index] * delta, -18.0, 18.0)

	for iteration in 2:
		var velocity_changes := PackedFloat32Array()
		velocity_changes.resize(ripple_heights.size())
		velocity_changes.fill(0.0)
		for index in ripple_heights.size():
			if index > 0:
				velocity_changes[index - 1] += (ripple_heights[index] - ripple_heights[index - 1]) * ripple_spread * delta
			if index < ripple_heights.size() - 1:
				velocity_changes[index + 1] += (ripple_heights[index] - ripple_heights[index + 1]) * ripple_spread * delta
		for index in ripple_velocities.size():
			ripple_velocities[index] += velocity_changes[index]

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


func apply_ripple_impulse(world_x: float, strength: float) -> void:
	if not has_visible_surface or not ripple_enabled or ripple_velocities.is_empty():
		return

	var local_x := clampf(to_local(Vector2(world_x, global_position.y)).x, -water_size.x * 0.5, water_size.x * 0.5)
	var ratio := inverse_lerp(-water_size.x * 0.5, water_size.x * 0.5, local_x)
	var index := clampi(roundi(ratio * float(ripple_velocities.size() - 1)), 0, ripple_velocities.size() - 1)
	ripple_velocities[index] += clampf(strength * ripple_strength, 2.0, 90.0)


func create_surface_splash(body: Node2D, entering: bool) -> void:
	if not has_visible_surface or splash_cooldowns.has(body):
		return

	var vertical_speed: float = 0.0
	var character_body := body as CharacterBody2D
	if character_body != null:
		vertical_speed = character_body.velocity.y
	if entering and vertical_speed < splash_minimum_entry_speed:
		return
	if not entering and vertical_speed >= -splash_minimum_entry_speed * 0.65:
		return

	var local_body := to_local(body.global_position)
	if absf(local_body.y) > 72.0:
		return

	var strength := absf(vertical_speed) * splash_strength_multiplier
	if not entering:
		strength *= 0.6

	splash_cooldowns[body] = splash_cooldown
	splash_particles.position = Vector2(clampf(local_body.x, -water_size.x * 0.5, water_size.x * 0.5), 0.0)
	splash_particles.amount = clampi(roundi(8.0 + strength * 2.0), 8, 36)
	var material := splash_particles.process_material as ParticleProcessMaterial
	if material != null:
		material.initial_velocity_min = 70.0 + strength * 10.0
		material.initial_velocity_max = 105.0 + strength * 18.0
	splash_particles.restart()
	splash_particles.emitting = true
	apply_ripple_impulse(body.global_position.x, strength)
	if splash_audio.stream != null:
		splash_audio.play()
	surface_crossed.emit(body, Vector2(body.global_position.x, global_position.y), strength, entering)


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
	create_surface_splash(body, true)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player") or not body.has_method("exit_water"):
		return

	var exited_through_surface := has_visible_surface and absf(to_local(body.global_position).y) <= 72.0
	create_surface_splash(body, false)
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
