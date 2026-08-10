extends CharacterBody2D

const IDLE_ANIMATION: StringName = &"idle_flying"
const RELEASE_ANIMATION: StringName = &"release"
const DEFAULT_GRENADE_SCENE: PackedScene = preload("res://scenes/projectiles/drone_grenade.tscn")
const CONE_TEXTURE_LENGTH: float = 256.0
const CONE_TEXTURE_HALF_WIDTH: float = 88.0

enum State {
	PATROL,
	TURN_PAUSE,
	ATTACK,
}

@export_group("Patrol")
@export var patrol_speed: float = 70.0
@export var patrol_distance: float = 180.0
@export var turn_pause_duration: float = 0.45
@export_enum("Left:-1", "Right:1") var move_direction: int = -1

@export_group("Presentation")
@export var max_lean_angle_degrees: float = 7.0
@export var lean_speed_degrees: float = 60.0
@export var cone_move_offset_degrees: float = 12.0
@export var cone_turn_speed_degrees: float = 70.0
@export var cone_length: float = 320.0
@export var cone_half_width: float = 110.0

@export_group("Detection")
@export var detection_confirmation_time: float = 0.25
@export var detection_decay_multiplier: float = 2.0
@export var player_detection_offset: Vector2 = Vector2(0.0, -12.0)
@export_flags_2d_physics var vision_block_mask: int = 1

@export_group("Attack")
@export var grenade_scene: PackedScene = DEFAULT_GRENADE_SCENE
@export var grenade_release_frame: int = 7
@export var grenade_damage: int = 1
@export var attack_cooldown: float = 3.0

@export_group("Health")
@export var max_hp: int = 3
@export var contact_damage: int = 1

@export_group("Debug")
@export var debug_draw_detection: bool = false
@export var debug_draw_los: bool = false
@export var debug_detection_color: Color = Color(1.0, 0.08, 0.04, 0.16)

@onready var body_collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var visual_pivot: Node2D = $VisualPivot
@onready var animated_sprite: AnimatedSprite2D = $VisualPivot/AnimatedSprite2D
@onready var grenade_spawn_point: Marker2D = $VisualPivot/GrenadeSpawnPoint
@onready var search_cone_pivot: Node2D = $SearchConePivot
@onready var cone_light: PointLight2D = $SearchConePivot/ConeLight
@onready var front_dot_glow: PointLight2D = $SearchConePivot/FrontDotGlow
@onready var detection_area: Area2D = $SearchConePivot/DetectionArea
@onready var detection_polygon: CollisionPolygon2D = $SearchConePivot/DetectionArea/CollisionPolygon2D
@onready var turn_pause_timer: Timer = $TurnPauseTimer
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer
@onready var hit_sound: AudioStreamPlayer2D = $HitSound

var state: State = State.PATROL
var hp: int = 0
var patrol_origin_x: float = 0.0
var detection_progress: float = 0.0
var grenade_spawned_this_attack: bool = false
var pending_turn: bool = false
var player: Node2D = null
var is_dying: bool = false

var _players_in_detection_area: Array[Node2D] = []
var _search_origin_left: Vector2 = Vector2.ZERO
var _grenade_spawn_position_left: Vector2 = Vector2.ZERO
var _locked_cone_global_rotation: float = 0.0
var _front_dot_base_energy: float = 0.0
var _attack_elapsed: float = 0.0


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("enemy")
	hp = max_hp
	patrol_origin_x = global_position.x
	move_direction = _normalize_direction(move_direction)
	player = get_tree().get_first_node_in_group("player") as Node2D

	_search_origin_left = search_cone_pivot.position
	_grenade_spawn_position_left = grenade_spawn_point.position
	_front_dot_base_energy = front_dot_glow.energy
	_configure_search_cone()
	_update_facing()

	turn_pause_timer.one_shot = true
	turn_pause_timer.wait_time = maxf(turn_pause_duration, 0.001)
	attack_cooldown_timer.one_shot = true
	attack_cooldown_timer.wait_time = maxf(attack_cooldown, 0.001)

	if not turn_pause_timer.timeout.is_connected(_on_turn_pause_timer_timeout):
		turn_pause_timer.timeout.connect(_on_turn_pause_timer_timeout)
	if not detection_area.body_entered.is_connected(_on_detection_area_body_entered):
		detection_area.body_entered.connect(_on_detection_area_body_entered)
	if not detection_area.body_exited.is_connected(_on_detection_area_body_exited):
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	if not animated_sprite.frame_changed.is_connected(_on_animated_sprite_frame_changed):
		animated_sprite.frame_changed.connect(_on_animated_sprite_frame_changed)
	if not animated_sprite.animation_finished.is_connected(_on_animated_sprite_animation_finished):
		animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)

	if animated_sprite.material != null:
		animated_sprite.material = animated_sprite.material.duplicate()
		_set_flash_amount(0.0)

	animated_sprite.play(IDLE_ANIMATION)


func _physics_process(delta: float) -> void:
	if is_dying:
		return

	_refresh_player_reference()
	_prune_detection_candidates()

	match state:
		State.PATROL:
			_run_patrol()
		State.TURN_PAUSE:
			velocity = Vector2.ZERO
		State.ATTACK:
			_run_attack(delta)

	if state != State.ATTACK:
		_update_detection(delta)

	_update_presentation(delta)
	move_and_slide()

	if state == State.PATROL and _has_horizontal_world_collision():
		enter_turn_pause()

	if debug_draw_detection or debug_draw_los:
		queue_redraw()


func _run_patrol() -> void:
	if _reached_patrol_limit():
		enter_turn_pause()
		return

	velocity = Vector2(move_direction * maxf(patrol_speed, 0.0), 0.0)


func _run_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	_attack_elapsed += delta

	if not grenade_spawned_this_attack and not is_player_detectable():
		_cancel_unreleased_attack()
		return

	var pulse := 1.25 + sin(_attack_elapsed * 18.0) * 0.35
	front_dot_glow.energy = _front_dot_base_energy * pulse


func _update_detection(delta: float) -> void:
	if can_accumulate_detection():
		detection_progress += delta
		if detection_progress >= maxf(detection_confirmation_time, 0.0):
			detection_progress = 0.0
			start_attack()
		return

	if not is_player_detectable():
		detection_progress = 0.0
	else:
		var decay_speed := maxf(detection_decay_multiplier, 0.0)
		detection_progress = maxf(detection_progress - delta * decay_speed, 0.0)


func can_accumulate_detection() -> bool:
	if state == State.ATTACK or not attack_cooldown_timer.is_stopped():
		return false
	if not is_player_detectable() or not is_player_inside_detection_area():
		return false
	return has_clear_line_to_player()


func is_player_inside_detection_area() -> bool:
	if not is_instance_valid(player):
		return false
	if _players_in_detection_area.has(player):
		return true
	return detection_area.overlaps_body(player)


func is_player_detectable() -> bool:
	if not is_instance_valid(player) or bool(player.get("is_dead")):
		return false
	if player.has_method("is_detectable_by_enemies"):
		return bool(player.call("is_detectable_by_enemies"))
	return true


func has_clear_line_to_player() -> bool:
	if not is_player_detectable():
		return false

	var query := PhysicsRayQueryParameters2D.create(
		search_cone_pivot.global_position,
		player.global_position + player_detection_offset
	)
	query.collision_mask = vision_block_mask
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func enter_turn_pause() -> void:
	if state == State.ATTACK or is_dying:
		return

	state = State.TURN_PAUSE
	pending_turn = true
	velocity = Vector2.ZERO
	turn_pause_timer.start(maxf(turn_pause_duration, 0.001))


func start_attack() -> void:
	if state == State.ATTACK or is_dying or not is_player_detectable():
		return

	state = State.ATTACK
	velocity = Vector2.ZERO
	detection_progress = 0.0
	grenade_spawned_this_attack = false
	_attack_elapsed = 0.0
	_locked_cone_global_rotation = search_cone_pivot.global_rotation
	turn_pause_timer.stop()
	animated_sprite.play(RELEASE_ANIMATION)
	animated_sprite.frame = 0
	animated_sprite.frame_progress = 0.0


func spawn_grenade() -> Node2D:
	if grenade_scene == null or get_tree().current_scene == null:
		return null

	var grenade := grenade_scene.instantiate() as Node2D
	if grenade == null:
		return null

	get_tree().current_scene.add_child(grenade)
	if grenade.has_method("setup"):
		grenade.call(
			"setup",
			grenade_spawn_point.global_position,
			Vector2.ZERO,
			grenade_damage,
			self
		)
	else:
		grenade.global_position = grenade_spawn_point.global_position
	return grenade


func _finish_attack(start_cooldown: bool) -> void:
	if state != State.ATTACK:
		return

	state = State.PATROL
	velocity = Vector2.ZERO
	_attack_elapsed = 0.0
	front_dot_glow.energy = _front_dot_base_energy
	animated_sprite.play(IDLE_ANIMATION)

	if start_cooldown:
		attack_cooldown_timer.start(maxf(attack_cooldown, 0.001))
	if pending_turn:
		_complete_pending_turn()


func _cancel_unreleased_attack() -> void:
	if state != State.ATTACK or grenade_spawned_this_attack:
		return
	grenade_spawned_this_attack = true
	_finish_attack(false)


func _complete_pending_turn() -> void:
	move_direction *= -1
	move_direction = _normalize_direction(move_direction)
	pending_turn = false
	turn_pause_timer.stop()
	_update_facing()


func _on_turn_pause_timer_timeout() -> void:
	if state != State.TURN_PAUSE:
		return
	_complete_pending_turn()
	state = State.PATROL


func _on_animated_sprite_frame_changed() -> void:
	if state != State.ATTACK or animated_sprite.animation != RELEASE_ANIMATION:
		return
	if grenade_spawned_this_attack or animated_sprite.frame < grenade_release_frame:
		return
	if not is_player_detectable():
		_cancel_unreleased_attack()
		return

	grenade_spawned_this_attack = true
	spawn_grenade()


func _on_animated_sprite_animation_finished() -> void:
	if state != State.ATTACK or animated_sprite.animation != RELEASE_ANIMATION:
		return

	if not grenade_spawned_this_attack:
		if is_player_detectable():
			grenade_spawned_this_attack = true
			spawn_grenade()
		else:
			_cancel_unreleased_attack()
			return

	_finish_attack(true)


func _on_detection_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not _players_in_detection_area.has(body):
		_players_in_detection_area.append(body)
	player = body


func _on_detection_area_body_exited(body: Node2D) -> void:
	_players_in_detection_area.erase(body)


func _refresh_player_reference() -> void:
	if is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player") as Node2D


func _prune_detection_candidates() -> void:
	for index in range(_players_in_detection_area.size() - 1, -1, -1):
		if not is_instance_valid(_players_in_detection_area[index]):
			_players_in_detection_area.remove_at(index)


func _reached_patrol_limit() -> bool:
	if patrol_distance <= 0.0:
		return false
	var offset := global_position.x - patrol_origin_x
	return offset <= -patrol_distance if move_direction < 0 else offset >= patrol_distance


func _has_horizontal_world_collision() -> bool:
	for index in range(get_slide_collision_count()):
		var collision := get_slide_collision(index)
		if collision != null and absf(collision.get_normal().x) > 0.5:
			return true
	return false


func _update_presentation(delta: float) -> void:
	_update_facing()

	var target_lean := 0.0
	if state == State.PATROL and not is_zero_approx(velocity.x):
		target_lean = deg_to_rad(max_lean_angle_degrees) * move_direction
	visual_pivot.rotation = rotate_toward(
		visual_pivot.rotation,
		target_lean,
		deg_to_rad(maxf(lean_speed_degrees, 0.0)) * delta
	)

	var mirrored_search_origin := Vector2(
		absf(_search_origin_left.x) * move_direction,
		_search_origin_left.y
	)
	search_cone_pivot.position = mirrored_search_origin.rotated(visual_pivot.rotation)

	if state == State.ATTACK:
		search_cone_pivot.global_rotation = _locked_cone_global_rotation
		return

	var target_cone_rotation := 0.0
	if state == State.PATROL and not is_zero_approx(velocity.x):
		target_cone_rotation = deg_to_rad(-move_direction * cone_move_offset_degrees)
	search_cone_pivot.global_rotation = rotate_toward(
		search_cone_pivot.global_rotation,
		target_cone_rotation,
		deg_to_rad(maxf(cone_turn_speed_degrees, 0.0)) * delta
	)


func _update_facing() -> void:
	move_direction = _normalize_direction(move_direction)
	# The authored drone artwork faces left.
	animated_sprite.flip_h = move_direction > 0
	grenade_spawn_point.position = Vector2(
		_grenade_spawn_position_left.x if move_direction < 0 else -_grenade_spawn_position_left.x,
		_grenade_spawn_position_left.y
	)


func _configure_search_cone() -> void:
	var safe_length := maxf(cone_length, 1.0)
	var safe_half_width := maxf(cone_half_width, 1.0)
	var near_half_width := maxf(safe_half_width * 0.07, 2.0)
	var near_y := minf(16.0, safe_length * 0.1)
	detection_polygon.polygon = PackedVector2Array([
		Vector2(-near_half_width, near_y),
		Vector2(near_half_width, near_y),
		Vector2(safe_half_width, safe_length),
		Vector2(-safe_half_width, safe_length),
	])

	cone_light.texture_scale = safe_length / CONE_TEXTURE_LENGTH
	var natural_half_width := CONE_TEXTURE_HALF_WIDTH * cone_light.texture_scale
	cone_light.scale = Vector2(safe_half_width / maxf(natural_half_width, 1.0), 1.0)


func _normalize_direction(direction: int) -> int:
	return -1 if direction < 0 else 1


func take_damage(amount: int = 1) -> void:
	if is_dying or amount <= 0:
		return
	hp -= amount
	flash_hit()
	spawn_hit_sound()
	if hp <= 0:
		die()


func slapped() -> void:
	take_damage(1)


func machete_hit(amount: int = 1) -> void:
	take_damage(amount)


func flash_hit() -> void:
	var material := animated_sprite.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("flash_amount", 1.0)
	var tween := create_tween()
	tween.tween_method(_set_flash_amount, 1.0, 0.0, 0.08)


func _set_flash_amount(value: float) -> void:
	var material := animated_sprite.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("flash_amount", value)


func spawn_hit_sound() -> void:
	if hit_sound == null or hit_sound.stream == null or get_tree().current_scene == null:
		return

	var one_shot := AudioStreamPlayer2D.new()
	one_shot.stream = hit_sound.stream
	one_shot.volume_db = hit_sound.volume_db
	one_shot.pitch_scale = hit_sound.pitch_scale
	one_shot.bus = hit_sound.bus
	one_shot.global_position = global_position
	get_tree().current_scene.add_child(one_shot)
	one_shot.finished.connect(one_shot.queue_free)
	one_shot.play()


func die() -> void:
	if is_dying:
		return
	is_dying = true
	velocity = Vector2.ZERO
	turn_pause_timer.stop()
	attack_cooldown_timer.stop()
	detection_area.set_deferred("monitoring", false)

	var state_of_game := get_node_or_null("/root/StateOfGame")
	if state_of_game != null and state_of_game.has_method("register_enemy_defeated"):
		state_of_game.call("register_enemy_defeated")
	queue_free()


func _draw() -> void:
	if debug_draw_detection:
		var points := PackedVector2Array()
		for point in detection_polygon.polygon:
			points.append(to_local(search_cone_pivot.to_global(point)))
		if points.size() >= 3:
			draw_colored_polygon(points, debug_detection_color)
			var outline := points.duplicate()
			outline.append(points[0])
			draw_polyline(outline, Color.RED, 1.0)

	if debug_draw_los and is_instance_valid(player):
		draw_line(
			to_local(search_cone_pivot.global_position),
			to_local(player.global_position + player_detection_offset),
			Color.LIME_GREEN if has_clear_line_to_player() else Color.ORANGE_RED,
			1.0
		)
