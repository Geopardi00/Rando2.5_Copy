extends CharacterBody2D

signal health_changed(current_hp: int, max_hp: int)
signal boss_defeated
signal attack_started(attack_name: StringName)

const BOSS_BULLET_SCENE := preload("res://scenes/projectiles/boss_bullet.tscn")
const FINAL_BOSS_GRENADE_SCENE := preload("res://scenes/projectiles/final_boss_grenade.tscn")
const ONE_WAY_PLATFORM_LAYER = 14
const NAV_TIER_FLOOR = 0
const NAV_TIER_BOX = 1
const NAV_TIER_PLATFORM = 2
const NAV_SIDE_LEFT = -1
const NAV_SIDE_CENTER = 0
const NAV_SIDE_RIGHT = 1

enum State {
	INACTIVE,
	DECIDE,
	RUN,
	JUMP_TO_PLATFORM,
	DROP_THROUGH,
	RIFLE_TELEGRAPH,
	RIFLE_BURST,
	KNIFE_TELEGRAPH,
	KNIFE_ACTIVE,
	GRENADE_TELEGRAPH,
	GRENADE_RELEASE,
	RECOVERY,
	DEFEATED
}

@export var fight_starts_automatically: bool = true
@export var max_hp: int = 24
@export var move_speed: float = 150.0
@export var gravity: float = 1100.0
@export var jump_velocity: float = -470.0
@export var jump_horizontal_speed: float = 210.0
@export var jump_launch_distance: float = 72.0
@export var arrival_distance: float = 12.0
@export var same_level_tolerance: float = 48.0
@export var ledge_check_distance: float = 28.0

@export_group("Navigation")
@export var navigation_root_path: NodePath

@export_group("Drop Through")
@export var drop_through_duration: float = 0.28
@export var drop_through_min_fall_speed: float = 180.0

@export_group("Rifle")
@export var rifle_range: float = 620.0
@export var rifle_min_range: float = 96.0
@export var rifle_vertical_tolerance: float = 44.0
@export var rifle_telegraph_time: float = 0.35
@export var rifle_shot_count: int = 4
@export var rifle_shot_interval: float = 0.16
@export var rifle_recovery_time: float = 0.55
@export var rifle_damage: int = 1

@export_group("Knife")
@export var knife_range: float = 78.0
@export var knife_vertical_tolerance: float = 42.0
@export var knife_telegraph_time: float = 0.25
@export var knife_active_time: float = 0.18
@export var knife_recovery_time: float = 0.55
@export var knife_damage: int = 1

@export_group("Grenade")
@export var grenade_cooldown: float = 4.2
@export var grenade_telegraph_time: float = 0.55
@export var grenade_release_time: float = 0.12
@export var grenade_recovery_time: float = 0.5
@export var grenade_damage: int = 1
@export var grenade_fuse_time: float = 2.1
@export var grenade_warning_duration: float = 0.7
@export var grenade_max_bounces: int = 2
@export var grenade_bounce_damping: float = 0.55
@export var grenade_gravity: float = 950.0
@export var grenade_flight_time: float = 0.95
@export var grenade_prediction_time: float = 0.35
@export var grenade_target_inaccuracy: float = 55.0
@export var grenade_explosion_radius: float = 92.0
@export var grenade_explosion_active_duration: float = 0.12
@export var max_active_grenades: int = 1
@export var grenade_left_limit_path: NodePath
@export var grenade_right_limit_path: NodePath

@export_group("AI")
@export var decision_delay: float = 0.25
@export var reposition_cooldown_time: float = 0.2
@export var debug_enabled: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var body_collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var muzzle_marker: Marker2D = $MuzzleMarker
@onready var grenade_throw_marker: Marker2D = $GrenadeThrowMarker
@onready var held_grenade_sprite: Sprite2D = $HeldGrenadeSprite
@onready var knife_hitbox: Area2D = $KnifeHitbox
@onready var knife_hitbox_shape: CollisionShape2D = $KnifeHitbox/CollisionShape2D
@onready var telegraph: ColorRect = $Telegraph
@onready var floor_check_left: RayCast2D = $FloorCheckLeft
@onready var floor_check_right: RayCast2D = $FloorCheckRight
@onready var wall_check_left: RayCast2D = $WallCheckLeft
@onready var wall_check_right: RayCast2D = $WallCheckRight

var state: State = State.INACTIVE
var hp: int = 0
var player: Node2D = null
var facing: int = -1
var state_timer: float = 0.0
var shot_timer: float = 0.0
var shots_fired: int = 0
var attack_direction: int = -1
var target_marker: Marker2D = null
var target_x: float = 0.0
var jump_has_left_floor: bool = false
var drop_through_timer: float = 0.0
var drop_through_floor_y: float = 0.0
var drop_through_mask_was_enabled: bool = false
var grenade_cooldown_timer: float = 0.0
var grenade_locked_target: Vector2 = Vector2.ZERO
var grenade_initial_velocity: Vector2 = Vector2.ZERO
var active_grenade: Node = null
var damaged_by_current_knife: Array[Node] = []
var last_attack: StringName = &""
var base_sprite_scale: Vector2 = Vector2.ONE
var flash_timer: float = 0.0
var jump_start_animation_active: bool = false
var landing_animation_active: bool = false


func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp
	base_sprite_scale = get_visual_scale()
	health_changed.emit(hp, max_hp)

	if animated_sprite != null:
		sprite.visible = false
		animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
		animated_sprite.play(&"idle")

	knife_hitbox.monitoring = false
	knife_hitbox_shape.disabled = true
	knife_hitbox.body_entered.connect(_on_knife_hitbox_body_entered)
	telegraph.visible = false
	held_grenade_sprite.visible = false

	update_facing(facing)
	refresh_player()

	if fight_starts_automatically:
		start_fight()


func _physics_process(delta: float) -> void:
	refresh_player()
	update_flash(delta)
	update_drop_through(delta)
	update_grenade_cooldown(delta)

	if state == State.DEFEATED:
		return

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	match state:
		State.INACTIVE:
			velocity.x = 0.0
		State.DECIDE:
			update_decide(delta)
		State.RUN:
			update_run()
		State.JUMP_TO_PLATFORM:
			update_jump_to_platform()
		State.DROP_THROUGH:
			update_drop_state()
		State.RIFLE_TELEGRAPH:
			update_rifle_telegraph(delta)
		State.RIFLE_BURST:
			update_rifle_burst(delta)
		State.KNIFE_TELEGRAPH:
			update_knife_telegraph(delta)
		State.KNIFE_ACTIVE:
			update_knife_active(delta)
		State.GRENADE_TELEGRAPH:
			update_grenade_telegraph(delta)
		State.GRENADE_RELEASE:
			update_grenade_release(delta)
		State.RECOVERY:
			update_recovery(delta)

	update_animation()
	move_and_slide()

	if state == State.JUMP_TO_PLATFORM and not jump_has_left_floor and not is_on_floor():
		jump_has_left_floor = true
	elif state == State.JUMP_TO_PLATFORM and jump_has_left_floor and is_on_floor() and velocity.y >= 0.0 and not landing_animation_active:
		play_land_animation()


func start_fight() -> void:
	if state != State.INACTIVE:
		return

	enter_decide(decision_delay)


func update_decide(delta: float) -> void:
	velocity.x = 0.0
	face_player()
	state_timer -= delta

	if state_timer <= 0.0:
		choose_next_action()


func choose_next_action() -> void:
	if not is_instance_valid(player):
		enter_decide(decision_delay)
		return
	if player.get("is_dead") == true:
		enter_decide(decision_delay)
		return

	var dx := player.global_position.x - global_position.x
	var abs_dx := absf(dx)
	var abs_dy := absf(player.global_position.y - global_position.y)

	if abs_dy <= knife_vertical_tolerance and abs_dx <= knife_range and last_attack != &"knife":
		start_knife()
		return

	if can_start_grenade() and should_select_grenade(abs_dx, abs_dy):
		start_grenade()
		return

	if abs_dy <= rifle_vertical_tolerance and abs_dx >= rifle_min_range and abs_dx <= rifle_range and last_attack != &"rifle":
		start_rifle()
		return

	if abs_dy <= rifle_vertical_tolerance and abs_dx >= rifle_min_range and abs_dx <= rifle_range:
		start_rifle()
		return

	if can_start_grenade():
		start_grenade()
		return

	reposition_toward_player()


func reposition_toward_player() -> void:
	target_marker = pick_route_target_marker()
	if target_marker == null:
		enter_decide(decision_delay)
		return

	target_x = target_marker.global_position.x
	var target_y := target_marker.global_position.y

	if is_target_above_current(target_y) and should_jump_to_target_now():
		start_jump_to_marker()
	elif is_target_below_current(target_y) and try_start_drop_through():
		state = State.DROP_THROUGH
	else:
		state = State.RUN

	debug_print("Boss 2 target: %s" % target_marker.name)


func update_run() -> void:
	if target_marker == null:
		enter_decide(decision_delay)
		return

	face_player()
	var dx := target_x - global_position.x
	if is_target_above_current(target_marker.global_position.y) and should_jump_to_target_now():
		start_jump_to_marker()
		return

	if absf(dx) <= arrival_distance:
		velocity.x = 0.0
		enter_decide(decision_delay)
		return

	var dir := signf(dx)
	if dir == 0.0:
		dir = 1.0

	if is_path_blocked(dir):
		if is_target_above_current(target_marker.global_position.y):
			start_jump_to_marker()
		else:
			velocity.x = 0.0
			enter_decide(decision_delay)
		return

	velocity.x = dir * move_speed


func start_jump_to_marker() -> void:
	state = State.JUMP_TO_PLATFORM
	jump_has_left_floor = false
	landing_animation_active = false
	velocity.y = jump_velocity

	var dir := signf(target_x - global_position.x)
	if dir == 0.0:
		dir = 1.0

	velocity.x = dir * jump_horizontal_speed
	play_jump_start_animation()


func update_jump_to_platform() -> void:
	if landing_animation_active:
		velocity.x = 0.0
		return

	var dx := target_x - global_position.x
	var dir := signf(dx)
	if dir == 0.0:
		dir = 1.0

	if absf(dx) <= arrival_distance:
		velocity.x = move_toward(velocity.x, 0.0, 20.0)
	else:
		velocity.x = dir * jump_horizontal_speed


func update_drop_state() -> void:
	if landing_animation_active:
		velocity.x = 0.0
		return

	face_player()
	if not is_on_floor() and target_marker != null:
		var dx := target_x - global_position.x
		velocity.x = signf(dx) * move_speed if absf(dx) > arrival_distance else 0.0
	elif drop_through_timer <= 0.0 and is_on_floor():
		play_land_animation()


func is_target_above_current(target_y: float) -> bool:
	return target_y < global_position.y - same_level_tolerance


func is_target_below_current(target_y: float) -> bool:
	return target_y > global_position.y + same_level_tolerance


func should_jump_to_target_now() -> bool:
	return absf(target_x - global_position.x) <= jump_launch_distance


func start_rifle() -> void:
	state = State.RIFLE_TELEGRAPH
	state_timer = rifle_telegraph_time
	attack_direction = get_player_direction()
	update_facing(attack_direction)
	velocity.x = 0.0
	telegraph.visible = true
	telegraph.color = Color(1.0, 0.15, 0.08, 0.65)
	attack_started.emit(&"rifle")


func update_rifle_telegraph(delta: float) -> void:
	velocity.x = 0.0
	state_timer -= delta
	pulse_telegraph()

	if state_timer <= 0.0:
		state = State.RIFLE_BURST
		shot_timer = 0.0
		shots_fired = 0
		telegraph.visible = false


func update_rifle_burst(delta: float) -> void:
	velocity.x = 0.0
	shot_timer -= delta

	if shot_timer <= 0.0 and shots_fired < rifle_shot_count:
		fire_rifle_shot()
		shots_fired += 1
		shot_timer = rifle_shot_interval

	if shots_fired >= rifle_shot_count and shot_timer <= 0.0:
		last_attack = &"rifle"
		enter_recovery(rifle_recovery_time)


func fire_rifle_shot() -> void:
	var bullet := BOSS_BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle_marker.global_position

	if bullet.has_method("setup"):
		bullet.setup(Vector2(attack_direction, 0.0), rifle_damage)
	else:
		bullet.set("direction", Vector2(attack_direction, 0.0))


func start_knife() -> void:
	state = State.KNIFE_TELEGRAPH
	state_timer = knife_telegraph_time
	attack_direction = get_player_direction()
	update_facing(attack_direction)
	velocity.x = 0.0
	telegraph.visible = true
	telegraph.color = Color(1.0, 1.0, 1.0, 0.55)
	attack_started.emit(&"knife")


func update_knife_telegraph(delta: float) -> void:
	velocity.x = 0.0
	state_timer -= delta
	pulse_telegraph()

	if state_timer <= 0.0:
		state = State.KNIFE_ACTIVE
		state_timer = knife_active_time
		damaged_by_current_knife.clear()
		update_knife_hitbox_direction()
		knife_hitbox.monitoring = true
		knife_hitbox_shape.disabled = false
		telegraph.visible = false

		for body in knife_hitbox.get_overlapping_bodies():
			damage_with_knife(body)


func update_knife_active(delta: float) -> void:
	velocity.x = 0.0
	state_timer -= delta

	if state_timer <= 0.0:
		knife_hitbox.monitoring = false
		knife_hitbox_shape.disabled = true
		last_attack = &"knife"
		enter_recovery(knife_recovery_time)


func start_grenade() -> void:
	if not lock_grenade_target():
		reposition_toward_player()
		return

	state = State.GRENADE_TELEGRAPH
	state_timer = grenade_telegraph_time
	attack_direction = get_player_direction()
	update_facing(attack_direction)
	velocity.x = 0.0
	telegraph.visible = true
	telegraph.color = Color(1.0, 0.75, 0.05, 0.6)
	held_grenade_sprite.visible = true
	attack_started.emit(&"grenade")


func update_grenade_telegraph(delta: float) -> void:
	velocity.x = 0.0
	state_timer -= delta
	pulse_telegraph()

	if state_timer <= 0.0:
		state = State.GRENADE_RELEASE
		state_timer = grenade_release_time
		set_visual_scale(base_sprite_scale)
		telegraph.visible = false
		spawn_grenade()


func update_grenade_release(delta: float) -> void:
	velocity.x = 0.0
	state_timer -= delta

	if state_timer <= 0.0:
		last_attack = &"grenade"
		held_grenade_sprite.visible = false
		enter_recovery(grenade_recovery_time)


func can_start_grenade() -> bool:
	if grenade_cooldown_timer > 0.0:
		return false
	if max_active_grenades <= 0:
		return false
	if is_instance_valid(active_grenade):
		return false
	if not is_instance_valid(player):
		return false
	if player.get("is_dead") == true:
		return false

	return true


func should_select_grenade(abs_dx: float, abs_dy: float) -> bool:
	if abs_dx <= knife_range:
		return false
	if last_attack == &"grenade":
		return false
	if abs_dy > rifle_vertical_tolerance:
		return true
	if is_player_on_platform_tier():
		return true
	if is_boss_waiting_on_box_for_player():
		return true

	return false


func lock_grenade_target() -> bool:
	if not is_instance_valid(player):
		return false

	var start_position := grenade_throw_marker.global_position
	grenade_locked_target = get_predicted_grenade_target()
	grenade_initial_velocity = calculate_grenade_velocity(start_position, grenade_locked_target)
	return true


func get_predicted_grenade_target() -> Vector2:
	var target := player.global_position
	var player_velocity = player.get("velocity")
	if player_velocity is Vector2:
		var prediction: Vector2 = player_velocity * grenade_prediction_time
		prediction.x = clampf(prediction.x, -140.0, 140.0)
		prediction.y = clampf(prediction.y, -90.0, 90.0)
		target += prediction

	target.x += randf_range(-grenade_target_inaccuracy, grenade_target_inaccuracy)
	target.y += randf_range(-grenade_target_inaccuracy * 0.35, grenade_target_inaccuracy * 0.35)

	var limits := get_grenade_x_limits()
	target.x = clampf(target.x, limits.x, limits.y)
	return target


func calculate_grenade_velocity(start_position: Vector2, target_position: Vector2) -> Vector2:
	var flight_time := maxf(grenade_flight_time, 0.1)
	var displacement := target_position - start_position
	return Vector2(displacement.x / flight_time, (displacement.y - 0.5 * grenade_gravity * flight_time * flight_time) / flight_time)


func spawn_grenade() -> void:
	if is_instance_valid(active_grenade):
		return

	var grenade := FINAL_BOSS_GRENADE_SCENE.instantiate()
	grenade.set("gravity", grenade_gravity)
	grenade.set("fuse_time", grenade_fuse_time)
	grenade.set("warning_duration", grenade_warning_duration)
	grenade.set("max_bounces", grenade_max_bounces)
	grenade.set("bounce_damping", grenade_bounce_damping)
	grenade.set("explosion_radius", grenade_explosion_radius)
	grenade.set("explosion_active_duration", grenade_explosion_active_duration)
	if grenade.has_method("setup"):
		grenade.setup(grenade_throw_marker.global_position, grenade_initial_velocity, grenade_damage, self)

	active_grenade = grenade
	if grenade.has_signal("finished"):
		grenade.finished.connect(_on_active_grenade_finished.bind(grenade))
	grenade.tree_exited.connect(_on_active_grenade_tree_exited.bind(grenade))
	get_tree().current_scene.add_child(grenade)
	grenade_cooldown_timer = grenade_cooldown


func update_grenade_cooldown(delta: float) -> void:
	if grenade_cooldown_timer > 0.0:
		grenade_cooldown_timer = maxf(grenade_cooldown_timer - delta, 0.0)


func get_grenade_x_limits() -> Vector2:
	var left_marker := get_node_or_null(grenade_left_limit_path) as Node2D
	var right_marker := get_node_or_null(grenade_right_limit_path) as Node2D
	if left_marker != null and right_marker != null:
		return Vector2(minf(left_marker.global_position.x, right_marker.global_position.x), maxf(left_marker.global_position.x, right_marker.global_position.x))

	var min_x := INF
	var max_x := -INF
	for marker in get_navigation_markers():
		min_x = minf(min_x, marker.global_position.x)
		max_x = maxf(max_x, marker.global_position.x)

	if min_x < INF and max_x > -INF:
		return Vector2(min_x - 80.0, max_x + 80.0)

	return Vector2(global_position.x - 700.0, global_position.x + 700.0)


func is_player_on_platform_tier() -> bool:
	var player_marker := get_nearest_navigation_marker(player.global_position)
	return player_marker != null and get_marker_tier(player_marker) == NAV_TIER_PLATFORM


func is_boss_waiting_on_box_for_player() -> bool:
	var boss_marker := get_nearest_navigation_marker(global_position)
	var player_marker := get_nearest_navigation_marker(player.global_position)
	if boss_marker == null or player_marker == null:
		return false

	return get_marker_tier(boss_marker) == NAV_TIER_BOX and get_marker_tier(player_marker) != NAV_TIER_BOX


func enter_recovery(duration: float) -> void:
	state = State.RECOVERY
	state_timer = duration
	velocity.x = 0.0
	jump_start_animation_active = false
	landing_animation_active = false
	set_visual_scale(base_sprite_scale)
	telegraph.visible = false
	held_grenade_sprite.visible = false


func update_recovery(delta: float) -> void:
	velocity.x = 0.0
	face_player()
	state_timer -= delta

	if state_timer <= 0.0:
		enter_decide(decision_delay)


func enter_decide(delay: float) -> void:
	state = State.DECIDE
	state_timer = delay
	target_marker = null
	velocity.x = 0.0
	jump_start_animation_active = false
	landing_animation_active = false
	set_visual_scale(base_sprite_scale)
	telegraph.visible = false
	held_grenade_sprite.visible = false
	knife_hitbox.monitoring = false
	knife_hitbox_shape.disabled = true


func pick_route_target_marker() -> Marker2D:
	var markers := get_navigation_markers()
	if markers.is_empty() or not is_instance_valid(player):
		return null

	var boss_marker := get_nearest_navigation_marker(global_position)
	var player_marker := get_nearest_navigation_marker(player.global_position)
	if boss_marker == null or player_marker == null:
		return pick_target_marker()

	var boss_tier := get_marker_tier(boss_marker)
	var player_tier := get_marker_tier(player_marker)
	var player_side := get_marker_side(player_marker)
	if player_side == NAV_SIDE_CENTER:
		player_side = get_side_for_position(player.global_position)

	var target_side := get_counter_platform_side(player_tier, player_side)

	if player_tier > boss_tier:
		return pick_next_marker_up(boss_tier, target_side)

	if player_tier < boss_tier:
		return pick_next_marker_down(player_tier, target_side)

	if player_tier == NAV_TIER_PLATFORM:
		return find_navigation_marker(NAV_TIER_PLATFORM, target_side)

	return pick_marker_on_tier_near_position(player_tier, player.global_position, target_side)


func pick_next_marker_up(current_tier: int, side: int) -> Marker2D:
	if current_tier <= NAV_TIER_FLOOR:
		return find_navigation_marker(NAV_TIER_BOX, side)

	if current_tier == NAV_TIER_BOX:
		return find_navigation_marker(NAV_TIER_PLATFORM, side)

	return find_navigation_marker(NAV_TIER_PLATFORM, side)


func pick_next_marker_down(player_tier: int, side: int) -> Marker2D:
	if player_tier <= NAV_TIER_FLOOR:
		var floor_marker := find_navigation_marker(NAV_TIER_FLOOR, side)
		if floor_marker != null:
			return floor_marker

		return find_navigation_marker(NAV_TIER_FLOOR, NAV_SIDE_CENTER)

	if player_tier == NAV_TIER_BOX:
		return find_navigation_marker(NAV_TIER_BOX, side)

	return pick_marker_on_tier_near_position(player_tier, player.global_position, side)


func pick_target_marker() -> Marker2D:
	return pick_marker_on_tier_near_position(NAV_TIER_FLOOR, player.global_position, get_side_for_position(player.global_position))


func pick_marker_on_tier_near_position(tier: int, position: Vector2, preferred_side: int = NAV_SIDE_CENTER) -> Marker2D:
	var markers := get_navigation_markers()
	var best_marker: Marker2D = null
	var best_score := INF
	for marker in markers:
		if get_marker_tier(marker) != tier:
			continue

		var horizontal_score := absf(marker.global_position.x - position.x)
		var side_penalty := 0.0
		var marker_side := get_marker_side(marker)
		if preferred_side != NAV_SIDE_CENTER and marker_side != NAV_SIDE_CENTER and marker_side != preferred_side:
			side_penalty = 240.0

		var self_penalty := 180.0 if global_position.distance_squared_to(marker.global_position) < 900.0 else 0.0
		var score := horizontal_score + side_penalty + self_penalty

		if score < best_score:
			best_score = score
			best_marker = marker

	return best_marker


func find_navigation_marker(tier: int, side: int) -> Marker2D:
	var fallback: Marker2D = null
	for marker in get_navigation_markers():
		if get_marker_tier(marker) != tier:
			continue

		var marker_side := get_marker_side(marker)
		if marker_side == side:
			return marker

		if fallback == null or marker_side == NAV_SIDE_CENTER:
			fallback = marker

	return fallback


func get_nearest_navigation_marker(position: Vector2) -> Marker2D:
	var best_marker: Marker2D = null
	var best_distance := INF
	for marker in get_navigation_markers():
		var distance := marker.global_position.distance_squared_to(position)
		if distance < best_distance:
			best_distance = distance
			best_marker = marker

	return best_marker


func get_marker_tier(marker: Marker2D) -> int:
	if marker.name.begins_with("Platform"):
		return NAV_TIER_PLATFORM

	if marker.name.begins_with("Box"):
		return NAV_TIER_BOX

	return NAV_TIER_FLOOR


func get_marker_side(marker: Marker2D) -> int:
	if marker.name.ends_with("Left"):
		return NAV_SIDE_LEFT

	if marker.name.ends_with("Right"):
		return NAV_SIDE_RIGHT

	return NAV_SIDE_CENTER


func get_side_for_position(position: Vector2) -> int:
	var navigation_root := get_node_or_null(navigation_root_path)
	if navigation_root == null:
		return NAV_SIDE_RIGHT if position.x > global_position.x else NAV_SIDE_LEFT

	var center_x: float = navigation_root.global_position.x
	var center_marker := navigation_root.get_node_or_null("FloorCenter") as Marker2D
	if center_marker != null:
		center_x = center_marker.global_position.x

	return NAV_SIDE_RIGHT if position.x >= center_x else NAV_SIDE_LEFT


func get_counter_platform_side(player_tier: int, player_side: int) -> int:
	if player_tier == NAV_TIER_PLATFORM and player_side != NAV_SIDE_CENTER:
		return -player_side

	return player_side


func get_navigation_markers() -> Array[Marker2D]:
	var markers: Array[Marker2D] = []
	var navigation_root := get_node_or_null(navigation_root_path)
	if navigation_root == null:
		return markers

	for child in navigation_root.get_children():
		var marker := child as Marker2D
		if marker != null:
			markers.append(marker)

	return markers


func try_start_drop_through() -> bool:
	if drop_through_timer > 0.0:
		return true

	var floor_y := get_one_way_floor_y()
	if floor_y == INF:
		return false

	drop_through_mask_was_enabled = get_collision_mask_value(ONE_WAY_PLATFORM_LAYER)
	drop_through_floor_y = floor_y
	drop_through_timer = drop_through_duration
	set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, false)
	velocity.y = maxf(velocity.y, drop_through_min_fall_speed)

	return true


func get_one_way_floor_y() -> float:
	if not is_on_floor():
		return INF

	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_normal().dot(up_direction) < 0.7:
			continue

		var collider := collision.get_collider() as CollisionObject2D
		if collider != null and collider.get_collision_layer_value(ONE_WAY_PLATFORM_LAYER):
			return collision.get_position().y

	return INF


func update_drop_through(delta: float) -> void:
	if drop_through_timer <= 0.0:
		return

	drop_through_timer -= delta

	if get_body_top_y() > drop_through_floor_y or drop_through_timer <= 0.0:
		drop_through_timer = 0.0
		set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, drop_through_mask_was_enabled)


func get_body_top_y() -> float:
	if body_collision_shape == null:
		return global_position.y

	var rectangle := body_collision_shape.shape as RectangleShape2D
	if rectangle != null:
		return body_collision_shape.global_position.y - rectangle.size.y * 0.5 * abs(body_collision_shape.global_scale.y)

	return body_collision_shape.global_position.y


func is_path_blocked(direction: float) -> bool:
	if direction < 0.0:
		return wall_check_left.is_colliding() or not floor_check_left.is_colliding()

	return wall_check_right.is_colliding() or not floor_check_right.is_colliding()


func refresh_player() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D


func face_player() -> void:
	if not is_instance_valid(player):
		return

	update_facing(get_player_direction())


func get_player_direction() -> int:
	if not is_instance_valid(player):
		return facing

	if player.global_position.x >= global_position.x:
		return 1

	return -1


func update_facing(direction: int) -> void:
	if direction == 0:
		return

	facing = direction
	sprite.flip_h = facing < 0
	if animated_sprite != null:
		animated_sprite.flip_h = facing < 0
	muzzle_marker.position.x = abs(muzzle_marker.position.x) * facing
	grenade_throw_marker.position.x = abs(grenade_throw_marker.position.x) * facing
	held_grenade_sprite.position.x = abs(held_grenade_sprite.position.x) * facing
	update_knife_hitbox_direction()


func update_knife_hitbox_direction() -> void:
	knife_hitbox.position.x = abs(knife_hitbox.position.x) * attack_direction


func pulse_telegraph() -> void:
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.04) * 0.08
	set_visual_scale(Vector2(base_sprite_scale.x * pulse, base_sprite_scale.y * (2.0 - pulse)))


func take_damage(amount: int = 1) -> void:
	if state == State.DEFEATED:
		return

	hp = maxi(hp - amount, 0)
	health_changed.emit(hp, max_hp)
	flash_timer = 0.08

	if hp <= 0:
		die()


func update_flash(delta: float) -> void:
	var flash_color := Color(1.0, 1.0, 1.0, 1.0)
	if flash_timer > 0.0:
		flash_timer -= delta
		flash_color = Color(1.0, 0.45, 0.45, 1.0)

	sprite.modulate = flash_color
	if animated_sprite != null:
		animated_sprite.modulate = flash_color


func update_animation() -> void:
	if animated_sprite == null:
		return
	if landing_animation_active or jump_start_animation_active:
		return

	var next_animation := &"idle"
	if state == State.JUMP_TO_PLATFORM:
		next_animation = &"jump_air"
	elif state == State.RUN:
		next_animation = &"run"

	if animated_sprite.animation != next_animation:
		animated_sprite.play(next_animation)
	elif not animated_sprite.is_playing():
		animated_sprite.play()


func get_visual_scale() -> Vector2:
	if animated_sprite != null:
		return animated_sprite.scale

	return sprite.scale


func set_visual_scale(new_scale: Vector2) -> void:
	sprite.scale = new_scale
	if animated_sprite != null:
		animated_sprite.scale = new_scale


func play_jump_start_animation() -> void:
	if animated_sprite == null or not animated_sprite.sprite_frames.has_animation(&"jump_start"):
		jump_start_animation_active = false
		return

	jump_start_animation_active = true
	landing_animation_active = false
	animated_sprite.play(&"jump_start")


func play_land_animation() -> void:
	velocity.x = 0.0
	jump_start_animation_active = false

	if animated_sprite == null or not animated_sprite.sprite_frames.has_animation(&"land"):
		enter_decide(reposition_cooldown_time)
		return

	landing_animation_active = true
	set_visual_scale(base_sprite_scale)
	animated_sprite.play(&"land")


func _on_animated_sprite_animation_finished() -> void:
	if animated_sprite == null:
		return

	if animated_sprite.animation == &"jump_start" and jump_start_animation_active:
		jump_start_animation_active = false
		if state == State.JUMP_TO_PLATFORM and not landing_animation_active:
			animated_sprite.play(&"jump_air")
	elif animated_sprite.animation == &"land" and landing_animation_active:
		landing_animation_active = false
		if state == State.JUMP_TO_PLATFORM or state == State.DROP_THROUGH:
			enter_decide(reposition_cooldown_time)


func die() -> void:
	state = State.DEFEATED
	velocity = Vector2.ZERO
	jump_start_animation_active = false
	landing_animation_active = false
	hurtbox.monitoring = false
	hurtbox_shape.disabled = true
	knife_hitbox.monitoring = false
	knife_hitbox_shape.disabled = true
	telegraph.visible = false
	held_grenade_sprite.visible = false
	clear_active_grenade()
	boss_defeated.emit()
	queue_free()


func _on_knife_hitbox_body_entered(body: Node) -> void:
	damage_with_knife(body)


func damage_with_knife(body: Node) -> void:
	if not body.is_in_group("player") or damaged_by_current_knife.has(body):
		return

	damaged_by_current_knife.append(body)
	if body.has_method("take_damage"):
		body.take_damage(knife_damage, false, &"enemy")
	elif body.has_method("die"):
		body.die()


func debug_print(message: String) -> void:
	if debug_enabled:
		print(message)


func _on_active_grenade_finished(grenade: Node) -> void:
	if active_grenade == grenade:
		active_grenade = null


func _on_active_grenade_tree_exited(grenade: Node) -> void:
	if active_grenade == grenade:
		active_grenade = null


func clear_active_grenade() -> void:
	if is_instance_valid(active_grenade):
		active_grenade.queue_free()
	active_grenade = null
