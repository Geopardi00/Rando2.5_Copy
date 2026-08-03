extends Node2D

enum State { SCAN, ALERT, TRACK, HOLD }

@export var bullet_scene: PackedScene = preload("res://scenes/projectiles/boss_bullet.tscn")
@export var min_vision_range: float = 120.0
@export var vision_range: float = 700.0
@export var cone_half_angle_degrees: float = 12.0
@export var min_scan_angle_degrees: float = -125.0
@export var max_scan_angle_degrees: float = -55.0
@export var scan_speed_degrees: float = 45.0
@export var alert_delay: float = 0.25
@export var fire_cooldown: float = 1.2
@export var hold_last_seen_time: float = 1.5
@export var player_aim_offset: Vector2 = Vector2(0, 32)
@export var player_detection_offsets: Array[Vector2] = [
	Vector2(0, -12),
	Vector2(0, 8),
	Vector2(0, 24),
]
@export var spotlight_ground_limit_y: float = 0.0
@export var spotlight_ground_fade_distance: float = 48.0
@export var bullet_speed: float = 650.0
@export var bullet_damage: int = 3
@export_flags_2d_physics var vision_block_mask: int = 1

@onready var shoot_point: Marker2D = $ShootPoint
@onready var vision_pivot: Node2D = $VisionPivot
@onready var spotlight: PointLight2D = get_node_or_null("VisionPivot/Spotlight")
@onready var fire_cooldown_timer: Timer = $FireCooldownTimer
@onready var alert_sound: AudioStreamPlayer2D = get_node_or_null("AlertSound")
@onready var shout_sound: AudioStreamPlayer2D = get_node_or_null("ShoutSound")

var state: State = State.SCAN
var scan_direction: float = -1.0
var alert_timer: float = 0.0
var hold_timer: float = 0.0
var player: Node2D = null
var base_spotlight_energy: float = 0.0


func _ready() -> void:
	add_to_group("enemy")
	if spotlight != null:
		base_spotlight_energy = spotlight.energy

	vision_pivot.rotation = deg_to_rad(max_scan_angle_degrees)
	fire_cooldown_timer.wait_time = fire_cooldown
	fire_cooldown_timer.one_shot = true
	fire_cooldown_timer.timeout.connect(_on_fire_cooldown_timeout)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if not is_player_detectable():
		reset_to_scan_after_target_loss()
		_update_scan(delta)
		update_spotlight_ground_fade()
		return

	match state:
		State.SCAN:
			_update_scan(delta)
			if can_see_player():
				_enter_alert()
		State.ALERT:
			aim_vision_at_player()
			alert_timer -= delta
			if not has_clear_line_to_player():
				_enter_hold()
				return

			if alert_timer <= 0.0:
				shoot_at_player()
				state = State.TRACK
				fire_cooldown_timer.start(fire_cooldown)
		State.TRACK:
			aim_vision_at_player()
			if not has_clear_line_to_player():
				_enter_hold()
				return

			if fire_cooldown_timer.is_stopped():
				shoot_at_player()
				fire_cooldown_timer.start(fire_cooldown)
		State.HOLD:
			hold_timer -= delta
			if has_clear_line_to_player():
				_enter_alert()
				return

			if hold_timer <= 0.0:
				state = State.SCAN

	update_spotlight_ground_fade()


func _update_scan(delta: float) -> void:
	var min_angle := deg_to_rad(min_scan_angle_degrees)
	var max_angle := deg_to_rad(max_scan_angle_degrees)
	var next_angle := vision_pivot.rotation + deg_to_rad(scan_speed_degrees) * scan_direction * delta

	if next_angle <= min_angle:
		next_angle = min_angle
		scan_direction = 1.0
	elif next_angle >= max_angle:
		next_angle = max_angle
		scan_direction = -1.0

	vision_pivot.rotation = next_angle


func can_see_player() -> bool:
	if not is_player_detectable():
		return false

	var origin := vision_pivot.global_position
	var scan_direction_vector := Vector2.RIGHT.rotated(vision_pivot.global_rotation)

	for target in get_player_detection_points():
		var to_player := target - origin
		var distance := to_player.length()

		if distance < min_vision_range or distance > vision_range:
			continue

		var angle_to_player: float = abs(rad_to_deg(scan_direction_vector.angle_to(to_player.normalized())))
		if angle_to_player > cone_half_angle_degrees:
			continue

		if not is_blocked_by_cover(origin, target):
			return true

	return false


func has_clear_line_to_player() -> bool:
	if not is_player_detectable():
		return false

	var origin := vision_pivot.global_position

	for target in get_player_detection_points():
		var distance := origin.distance_to(target)
		if distance < min_vision_range or distance > vision_range:
			continue

		if not is_blocked_by_cover(origin, target):
			return true

	return false


func aim_vision_at_player() -> void:
	if not is_player_detectable():
		return

	var to_player := get_player_aim_point() - vision_pivot.global_position
	if to_player == Vector2.ZERO:
		return

	vision_pivot.global_rotation = to_player.angle()


func update_spotlight_ground_fade() -> void:
	if spotlight == null or spotlight_ground_limit_y <= 0.0:
		return

	var fade_distance: float = max(spotlight_ground_fade_distance, 1.0)
	var fade_amount: float = clamp((spotlight.global_position.y - spotlight_ground_limit_y) / fade_distance, 0.0, 1.0)
	spotlight.energy = base_spotlight_energy * (1.0 - fade_amount)


func get_player_aim_point() -> Vector2:
	return player.global_position + player_aim_offset


func get_player_detection_points() -> Array[Vector2]:
	var points: Array[Vector2] = []

	for offset in player_detection_offsets:
		points.append(player.global_position + offset)

	if points.is_empty():
		points.append(player.global_position)

	return points


func is_blocked_by_cover(origin: Vector2, target: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(origin, target)
	query.collision_mask = vision_block_mask
	query.exclude = [self]
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty()


func _enter_alert() -> void:
	if not is_player_detectable():
		reset_to_scan_after_target_loss()
		return

	state = State.ALERT
	alert_timer = alert_delay
	print("Sniper: Hey!")

	if alert_sound != null:
		alert_sound.play()
	elif shout_sound != null:
		shout_sound.play()


func _enter_hold() -> void:
	state = State.HOLD
	hold_timer = hold_last_seen_time


func shoot_at_player() -> void:
	if bullet_scene == null or not is_player_detectable():
		return

	var bullet := bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	var aim_direction := (player.global_position - shoot_point.global_position).normalized()
	bullet.global_position = shoot_point.global_position

	if bullet.has_method("setup"):
		bullet.setup(aim_direction, bullet_damage)
	else:
		bullet.set("direction", aim_direction)

	if bullet.get("speed") != null:
		bullet.set("speed", bullet_speed)

	if bullet.get("damage") != null:
		bullet.set("damage", bullet_damage)


func _on_fire_cooldown_timeout() -> void:
	pass


func is_player_detectable() -> bool:
	if not is_instance_valid(player) or bool(player.get("is_dead")):
		return false

	if player.has_method("is_detectable_by_enemies"):
		return bool(player.call("is_detectable_by_enemies"))

	return true


func reset_to_scan_after_target_loss() -> void:
	if state == State.SCAN:
		return

	state = State.SCAN
	alert_timer = 0.0
	hold_timer = 0.0
	fire_cooldown_timer.stop()
