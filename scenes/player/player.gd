extends CharacterBody2D

signal health_changed(current_hp: int, max_hp: int)
signal ammo_changed(current_ammo: int, max_ammo: int)

@export var move_speed: float = 220.0
@export var jump_velocity: float = -400.0
@export var gravity: float = 1100.0

const PUSH_FORCE = 100
const BLOCK_MAX_VELOCITY = 180
const ONE_WAY_PLATFORM_LAYER = 14
const PLAYER_UNDERWATER_SHADER: Shader = preload("res://shaders/player_underwater.gdshader")

@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.10

@export var enable_double_jump: bool = true
@export var extra_jumps: int = 1
@export var drop_through_duration: float = 0.25
@export var drop_through_min_fall_speed: float = 180.0

@export var bullet_scene: PackedScene
@export var muzzle_flash_scene: PackedScene = preload("res://scenes/props/muzzle_flash.tscn")
@export var fire_rate: float = 0.2
@export var bullet_offset: Vector2 = Vector2(16, 12)
@export var muzzle_flash_offset: Vector2 = Vector2(18, 12)
@export var max_ammo: int = 30
@export var starting_ammo: int = 30
@export var max_hp: int = 3
@export var invulnerability_time: float = 0.75
@export var debug_enabled: bool = false
@export var slap_range: float = 46.0
@export var slap_height: float = 34.0
@export var slap_duration: float = 0.10
@export var slap_cooldown: float = 0.25
@export var mosquito_immunity_time: float = 1.0

@export_group("Melee Attack")
@export var melee_damage: int = 2
@export var melee_range: float = 52.0
@export var melee_height: float = 38.0
@export var melee_forward_offset: float = 14.0
@export var melee_vertical_offset: float = 8.0
@export var melee_ground_stop_time: float = 0.12
@export var melee_attack_duration: float = 0.32
@export var melee_hitbox_start_time: float = 0.08
@export var melee_hitbox_duration: float = 0.10

@export_group("Hard Landing")
@export var hard_landing_min_fall_speed: float = 520.0
@export var hard_landing_stop_time: float = 0.08
@export var hard_landing_animation_time: float = 0.22

@export_group("Zipline")
@export var zipline_reattach_cooldown_time: float = 0.18

@export_group("Water")
@export var water_debug_enabled: bool = false
@export var swimming_speed: float = 143.0
@export var water_gravity: float = 220.0
@export var swim_jump_height: float = 18.0
@export var surface_float_offset: float = 12.0
@export var surface_capture_distance: float = 6.0
@export var surface_jump_distance: float = 20.0
@export var surface_entry_max_fall_speed: float = 80.0
@export var surface_exit_recovery_time: float = 0.25
@export var surface_jump_exit_grace_time: float = 0.35
@export var water_state_debug_lines: bool = true

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var fire_timer: Timer = $FireRateTimer
@onready var hurtbox: Area2D = $Hurtbox
@onready var shoot_sound: AudioStreamPlayer2D = $ShootSound
@onready var muzzle_marker: Marker2D = $MuzzleMarker
@onready var body_collision_shape: CollisionShape2D = $CollisionShape2D
@onready var melee_hitbox: Area2D = $MeleeHitbox
@onready var melee_hitbox_shape: CollisionShape2D = $MeleeHitbox/CollisionShape2D

var facing: int = 1
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var air_jumps_left: int = 0
var is_dead: bool = false
var current_hp: int = 0
var current_ammo: int = 0
var invulnerability_timer: float = 0.0
var blink_timer: float = 0.0
var slap_cooldown_timer: float = 0.0
var slap_animation_timer: float = 0.0
var swatting_timer: float = 0.0
var mosquito_immunity_timer: float = 0.0
var is_swatting: bool = false
var max_fall_speed: float = 0.0
var landing_animation_timer: float = 0.0
var landing_stop_timer: float = 0.0
var nearby_ziplines: Array[Node] = []
var active_zipline: Node = null
var is_riding_zipline: bool = false
var zipline_progress: float = 0.0
var zipline_speed: float = 0.0
var zipline_reattach_timer: float = 0.0
var is_melee_attacking: bool = false
var melee_attack_timer: float = 0.0
var melee_ground_stop_timer: float = 0.0
var melee_hitbox_active: bool = false
var melee_started_on_floor: bool = false
var melee_hit_targets: Array[Node] = []
var drop_through_timer: float = 0.0
var drop_through_floor_y: float = 0.0
var drop_through_mask_was_enabled: bool = false
var active_water_bodies: Array[Node] = []
var submerged_head_water_bodies: Array[Node] = []
var breath_elapsed: float = 0.0
var next_drowning_damage_time: float = 5.0
var water_debug_label: Label = null
var is_surface_swimming: bool = false
var surface_jump_active: bool = false
var surface_water_body: Node = null
var surface_recovery_water_body: Node = null
var surface_recovery_timer: float = 0.0
var surface_jump_exit_timer: float = 0.0
var debug_surface_water_body: Node = null
var default_animated_sprite_material: Material = null
var player_underwater_material: ShaderMaterial = null
var player_underwater_shader_active: bool = false


func _ready() -> void:
	add_to_group("player")
	current_hp = max_hp
	current_ammo = clampi(starting_ammo, 0, max_ammo)
	health_changed.emit(current_hp, max_hp)
	ammo_changed.emit(current_ammo, max_ammo)

	fire_timer.wait_time = fire_rate
	fire_timer.one_shot = true

	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	melee_hitbox.area_entered.connect(_on_melee_hitbox_area_entered)
	disable_melee_hitbox()
	update_melee_hitbox_geometry()

	air_jumps_left = extra_jumps
	setup_player_underwater_shader()
	setup_water_debug_display()


func _physics_process(delta: float) -> void:
	update_invulnerability(delta)
	update_mosquito_immunity(delta)
	update_slap_timers(delta)
	update_landing_timers(delta)
	update_zipline_timers(delta)
	update_melee_attack(delta)
	update_drop_through(delta)
	update_water_breath(delta)
	update_surface_recovery(delta)
	surface_jump_exit_timer = maxf(surface_jump_exit_timer - delta, 0.0)

	if is_dead:
		force_detach_from_zipline()
		velocity.x = 0.0

		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			velocity.y = 0.0

		move_and_slide()
		update_animation()
		return

	reconcile_water_overlaps()
	update_player_underwater_shader()

	if is_riding_zipline:
		if Input.is_action_just_pressed("jump"):
			var launch_velocity := get_zipline_launch_velocity(true)
			detach_from_zipline(launch_velocity)
			update_animation()
			return
		else:
			update_zipline_movement(delta)
			update_animation()
			return

	if is_swatting:
		force_detach_from_zipline()
		update_swatting(delta)
		move_and_slide()
		update_animation()
		return

	if surface_jump_active and is_in_water() and velocity.y >= 0.0:
		surface_jump_active = false

	if is_in_water() and not surface_jump_active:
		update_swimming(delta)
		update_player_underwater_shader()
		move_and_slide()
		update_animation()
		return

	var input_axis: float = Input.get_axis("move_left", "move_right")
	var jump_pressed: bool = Input.is_action_just_pressed("jump")
	var drop_requested: bool = jump_pressed and Input.is_action_pressed("move_down")
	var was_on_floor: bool = is_on_floor()

	if Input.is_action_just_pressed("melee_attack"):
		try_melee_attack()

	if Input.is_action_just_pressed("interact"):
		try_attach_to_nearest_zipline()

	# Facing
	if input_axis > 0.0:
		facing = 1
	elif input_axis < 0.0:
		facing = -1

	animated_sprite.flip_h = facing < 0
	update_melee_hitbox_geometry()

	# Horizontal movement
	if landing_stop_timer > 0.0 or melee_ground_stop_timer > 0.0:
		velocity.x = 0.0
	elif input_axis != 0.0:
		velocity.x = input_axis * move_speed
	else:
		velocity.x = 0.0

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	# Ground reset
	if is_on_floor():
		coyote_timer = coyote_time
		air_jumps_left = extra_jumps
	else:
		coyote_timer -= delta

	if drop_requested and try_start_drop_through():
		jump_pressed = false

	# Jump buffer
	if jump_pressed:
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	# Ground / coyote jump
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		cancel_landing()
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0

	# Double jump
	elif jump_pressed and enable_double_jump and not is_on_floor() and air_jumps_left > 0:
		cancel_landing()
		velocity.y = jump_velocity
		air_jumps_left -= 1
		jump_buffer_timer = 0.0

	if not is_on_floor():
		max_fall_speed = maxf(max_fall_speed, velocity.y)

	# Shooting
	if Input.is_action_just_pressed("shoot"):
		try_shoot()

	if Input.is_action_just_pressed("slap"):
		try_slap()

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collision_crate = collision.get_collider()
		if collision_crate.is_in_group("Crate") and abs(collision_crate.linear_velocity.x) < BLOCK_MAX_VELOCITY:
			collision_crate.apply_central_impulse(collision.get_normal() * -PUSH_FORCE)


	move_and_slide()
	update_hard_landing(was_on_floor)
	update_animation()


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
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	cancel_landing()

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
		finish_drop_through()


func finish_drop_through() -> void:
	drop_through_timer = 0.0
	set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, drop_through_mask_was_enabled)


func get_body_top_y() -> float:
	if body_collision_shape == null:
		return global_position.y

	var rectangle := body_collision_shape.shape as RectangleShape2D
	if rectangle != null:
		return body_collision_shape.global_position.y - rectangle.size.y * 0.5 * abs(body_collision_shape.global_scale.y)

	return body_collision_shape.global_position.y


func enter_water(water_body: Node) -> void:
	if water_body == null:
		return
	if bool(water_body.get("has_visible_surface")):
		debug_surface_water_body = water_body
	if active_water_bodies.has(water_body):
		if surface_recovery_water_body == water_body:
			surface_recovery_water_body = null
			surface_recovery_timer = 0.0
		try_capture_water_surface()
		update_player_underwater_shader()
		return

	var was_dry := active_water_bodies.is_empty()
	active_water_bodies.append(water_body)
	if not was_dry:
		try_capture_water_surface()
		update_player_underwater_shader()
		return

	surface_jump_active = false
	surface_jump_exit_timer = 0.0
	is_surface_swimming = false
	surface_water_body = null
	force_detach_from_zipline()
	cancel_landing()
	if is_melee_attacking or melee_hitbox_active:
		call_deferred("cancel_melee_attack")
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	air_jumps_left = extra_jumps
	max_fall_speed = 0.0

	var max_fall := get_water_float(&"maximum_underwater_fall_speed", 130.0)
	var vertical_speed := get_water_float(&"vertical_swim_speed", move_speed * 0.55)
	var entry_speed_limit := maxf(move_speed * 1.1, swimming_speed * 1.5)
	velocity.x = clampf(velocity.x, -entry_speed_limit, entry_speed_limit)
	velocity.y = clampf(velocity.y, -vertical_speed * 1.4, max_fall)
	try_capture_water_surface()
	update_player_underwater_shader()


func exit_water(water_body: Node, _surface_y: float, exited_through_surface: bool) -> void:
	if not active_water_bodies.has(water_body):
		return

	if exited_through_surface and not surface_jump_active and surface_jump_exit_timer > 0.0 and bool(water_body.get("has_visible_surface")):
		var exit_boost := get_water_float_from(water_body, &"surface_exit_boost", absf(jump_velocity) * 0.7)
		velocity.y = minf(velocity.y, -maxf(exit_boost, 0.0))
		surface_jump_exit_timer = 0.0
		finish_water_exit(water_body)
		return

	if exited_through_surface and not surface_jump_active and bool(water_body.get("has_visible_surface")):
		surface_water_body = water_body
		is_surface_swimming = true
		surface_recovery_water_body = water_body
		surface_recovery_timer = maxf(surface_exit_recovery_time, 0.0)
		velocity.y = maxf(velocity.y, 0.0)
		return

	finish_water_exit(water_body)


func finish_water_exit(water_body: Node) -> void:
	active_water_bodies.erase(water_body)
	if surface_water_body == water_body:
		is_surface_swimming = false
		surface_water_body = null
	if surface_recovery_water_body == water_body:
		surface_recovery_water_body = null
		surface_recovery_timer = 0.0
	prune_water_bodies()
	update_player_underwater_shader()
	if not active_water_bodies.is_empty():
		return

	surface_jump_active = false
	surface_jump_exit_timer = 0.0
	submerged_head_water_bodies.clear()
	reset_breath_timers()


func set_head_submerged(water_body: Node, submerged: bool) -> void:
	if submerged:
		if not submerged_head_water_bodies.has(water_body):
			submerged_head_water_bodies.append(water_body)
		if submerged_head_water_bodies.size() == 1:
			breath_elapsed = 0.0
			next_drowning_damage_time = get_water_float_from(water_body, &"breath_duration", 5.0)
	else:
		submerged_head_water_bodies.erase(water_body)
		prune_water_bodies()
		if submerged_head_water_bodies.is_empty():
			reset_breath_timers()


func is_in_water() -> bool:
	prune_water_bodies()
	return not active_water_bodies.is_empty()


func is_head_submerged() -> bool:
	prune_water_bodies()
	return not submerged_head_water_bodies.is_empty()


func reconcile_water_overlaps() -> void:
	if get_tree() == null:
		return

	for water_body in get_tree().get_nodes_in_group("water_body"):
		if not is_instance_valid(water_body) or not water_body.has_method("contains_body"):
			continue
		var geometrically_inside := bool(water_body.call("contains_body", self))
		if geometrically_inside:
			if not active_water_bodies.has(water_body):
				enter_water(water_body)
			if water_body.has_method("contains_head_sensor"):
				set_head_submerged(water_body, bool(water_body.call("contains_head_sensor", self)))
			continue
		set_head_submerged(water_body, false)
		if not active_water_bodies.has(water_body) or surface_recovery_water_body == water_body:
			continue

		var exited_through_surface := false
		if water_body.has_method("is_body_above_surface"):
			exited_through_surface = bool(water_body.call("is_body_above_surface", self))
		exit_water(water_body, get_water_surface_y(water_body), exited_through_surface)


func update_swimming(delta: float) -> void:
	var input_axis := Input.get_axis("move_left", "move_right")
	var vertical_axis := Input.get_axis("move_up", "move_down")
	var speed_multiplier := get_water_float(&"swim_speed_multiplier", 1.0)
	var acceleration_multiplier := get_water_float(&"swim_acceleration_multiplier", 0.5)
	var gravity_multiplier := get_water_float(&"gravity_multiplier", 1.0)
	var max_fall := get_water_float(&"maximum_underwater_fall_speed", 130.0)
	var vertical_speed := get_water_float(&"vertical_swim_speed", move_speed * 0.55)
	var drag := get_water_float(&"water_drag", 220.0)
	var effective_swim_speed := swimming_speed * speed_multiplier
	var effective_water_gravity := water_gravity * gravity_multiplier
	var jump_pressed := Input.is_action_just_pressed("jump")
	var holding_up := vertical_axis < 0.0
	var jump_surface := get_nearby_jump_surface() if jump_pressed else null
	if jump_pressed:
		surface_jump_exit_timer = maxf(surface_jump_exit_grace_time, 0.0)

	if input_axis > 0.0:
		facing = 1
	elif input_axis < 0.0:
		facing = -1
	animated_sprite.flip_h = facing < 0
	update_melee_hitbox_geometry()

	var target_x := input_axis * effective_swim_speed
	var horizontal_acceleration := maxf(swimming_speed, 1.0) * 8.0 * acceleration_multiplier
	velocity.x = move_toward(velocity.x, target_x, horizontal_acceleration * delta)
	if is_zero_approx(input_axis):
		velocity.x = move_toward(velocity.x, 0.0, drag * delta)

	if is_surface_swimming and not holding_up and not jump_pressed:
		is_surface_swimming = false
		surface_water_body = null
	elif not is_surface_swimming and holding_up:
		try_capture_water_surface()

	if jump_surface != null:
		start_surface_jump(jump_surface)
	elif is_surface_swimming:
		update_surface_float(delta, vertical_speed)
	elif not is_zero_approx(vertical_axis):
		velocity.y = move_toward(velocity.y, vertical_axis * vertical_speed, vertical_speed * 5.0 * delta)
	else:
		velocity.y = move_toward(velocity.y, 0.0, drag * 0.35 * delta)

	if not surface_jump_active:
		velocity.y += effective_water_gravity * delta

	if jump_pressed and not is_surface_swimming and not surface_jump_active:
		var swim_jump_velocity := sqrt(2.0 * maxf(effective_water_gravity, 1.0) * maxf(swim_jump_height, 0.0))
		velocity.y = minf(velocity.y, -swim_jump_velocity)

	if not surface_jump_active:
		velocity.y = clampf(velocity.y, -vertical_speed * 1.4, max_fall)
	prevent_unintentional_surface_exit(delta, vertical_speed)
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	max_fall_speed = 0.0

	if Input.is_action_just_pressed("shoot"):
		try_shoot()
	if Input.is_action_just_pressed("slap"):
		try_slap()


func try_capture_water_surface() -> bool:
	if not Input.is_action_pressed("move_up"):
		return false

	var candidate := get_nearest_surface_water()
	if candidate == null or velocity.y > surface_entry_max_fall_speed:
		return false

	var target_y := get_surface_target_y(candidate)
	if global_position.y > target_y + surface_capture_distance:
		return false

	surface_water_body = candidate
	is_surface_swimming = true
	return true


func update_surface_float(delta: float, vertical_speed: float) -> void:
	if surface_water_body == null or not is_instance_valid(surface_water_body):
		is_surface_swimming = false
		surface_water_body = null
		return

	var distance := get_surface_target_y(surface_water_body) - global_position.y
	if absf(distance) <= 0.05:
		velocity.y = 0.0
		return

	velocity.y = clampf(distance / maxf(delta, 0.0001), -vertical_speed, vertical_speed)


func prevent_unintentional_surface_exit(delta: float, vertical_speed: float) -> void:
	if surface_jump_active or is_surface_swimming or velocity.y >= 0.0 or not Input.is_action_pressed("move_up"):
		return

	var candidate := get_nearest_surface_water()
	if candidate == null:
		return

	var capture_y := get_surface_target_y(candidate) + surface_capture_distance
	if global_position.y + velocity.y * delta > capture_y:
		return

	surface_water_body = candidate
	is_surface_swimming = true
	update_surface_float(delta, vertical_speed)


func update_surface_recovery(delta: float) -> void:
	if surface_recovery_water_body == null:
		return
	if not is_instance_valid(surface_recovery_water_body):
		surface_recovery_water_body = null
		surface_recovery_timer = 0.0
		return

	surface_recovery_timer -= delta
	if surface_recovery_timer > 0.0:
		return

	var expired_water := surface_recovery_water_body
	surface_recovery_water_body = null
	surface_recovery_timer = 0.0
	finish_water_exit(expired_water)


func start_surface_jump(water_body: Node) -> void:
	var exit_boost := get_water_float_from(water_body, &"surface_exit_boost", absf(jump_velocity) * 0.7)
	is_surface_swimming = false
	surface_jump_active = true
	surface_water_body = null
	velocity.y = -maxf(exit_boost, 0.0)


func get_nearby_jump_surface() -> Node:
	var candidate := get_nearest_surface_water()
	if candidate == null:
		return null

	var maximum_y := get_water_surface_y(candidate) + maxf(surface_jump_distance, 0.0)
	return candidate if get_body_top_y() <= maximum_y else null


func get_nearest_surface_water() -> Node:
	prune_water_bodies()
	var nearest: Node = null
	var nearest_distance := INF
	for water_body in active_water_bodies:
		if not bool(water_body.get("has_visible_surface")):
			continue
		var distance := absf(global_position.y - get_water_surface_y(water_body))
		if distance < nearest_distance:
			nearest = water_body
			nearest_distance = distance
	return nearest


func get_water_surface_y(water_body: Node) -> float:
	var water_node := water_body as Node2D
	return water_node.global_position.y if water_node != null else global_position.y


func get_surface_target_y(water_body: Node) -> float:
	return get_water_surface_y(water_body) - maxf(surface_float_offset, 0.0)


func get_applied_gravity() -> float:
	if is_in_water() and not surface_jump_active:
		return water_gravity * get_water_float(&"gravity_multiplier", 1.0)
	if not is_on_floor():
		return gravity
	return 0.0


func update_water_breath(delta: float) -> void:
	if is_dead or not is_head_submerged():
		return

	breath_elapsed += delta
	while breath_elapsed >= next_drowning_damage_time and not is_dead:
		var water_body := get_active_head_water()
		var damage := roundi(get_water_float_from(water_body, &"damage_amount", 1.0))
		take_damage(maxi(damage, 1), true)
		next_drowning_damage_time += maxf(get_water_float_from(water_body, &"damage_interval", 3.0), 0.1)


func reset_breath_timers() -> void:
	breath_elapsed = 0.0
	var water_body := get_active_head_water()
	next_drowning_damage_time = get_water_float_from(water_body, &"breath_duration", 5.0)


func reset_water_state() -> void:
	active_water_bodies.clear()
	submerged_head_water_bodies.clear()
	is_surface_swimming = false
	surface_jump_active = false
	surface_jump_exit_timer = 0.0
	surface_water_body = null
	surface_recovery_water_body = null
	surface_recovery_timer = 0.0
	debug_surface_water_body = null
	reset_breath_timers()
	update_player_underwater_shader()


func prune_water_bodies() -> void:
	for index in range(active_water_bodies.size() - 1, -1, -1):
		if not is_instance_valid(active_water_bodies[index]):
			active_water_bodies.remove_at(index)
	for index in range(submerged_head_water_bodies.size() - 1, -1, -1):
		if not is_instance_valid(submerged_head_water_bodies[index]):
			submerged_head_water_bodies.remove_at(index)
	if surface_water_body != null and not is_instance_valid(surface_water_body):
		is_surface_swimming = false
		surface_water_body = null


func get_active_water() -> Node:
	prune_water_bodies()
	return active_water_bodies.back() if not active_water_bodies.is_empty() else null


func setup_player_underwater_shader() -> void:
	default_animated_sprite_material = animated_sprite.material
	player_underwater_material = ShaderMaterial.new()
	player_underwater_material.shader = PLAYER_UNDERWATER_SHADER


func update_player_underwater_shader() -> void:
	if animated_sprite == null or player_underwater_material == null:
		return

	var water_body := get_active_water()
	var should_enable := (
		water_body != null
		and bool(water_body.get("player_underwater_shader_enabled"))
		and not is_surface_swimming
		and not surface_jump_active
	)
	if should_enable:
		player_underwater_material.set_shader_parameter(&"underwater_tint", water_body.get("player_underwater_tint"))
		player_underwater_material.set_shader_parameter(&"tint_strength", water_body.get("player_underwater_tint_strength"))
		player_underwater_material.set_shader_parameter(&"shimmer_strength", water_body.get("player_underwater_shimmer_strength"))
		player_underwater_material.set_shader_parameter(&"shimmer_frequency", water_body.get("player_underwater_shimmer_frequency"))
		player_underwater_material.set_shader_parameter(&"shimmer_speed", water_body.get("player_underwater_shimmer_speed"))
		player_underwater_material.set_shader_parameter(&"wobble_strength", water_body.get("player_underwater_wobble_strength"))
		player_underwater_material.set_shader_parameter(&"wobble_frequency", water_body.get("player_underwater_wobble_frequency"))
		player_underwater_material.set_shader_parameter(&"wobble_speed", water_body.get("player_underwater_wobble_speed"))
		if animated_sprite.material != player_underwater_material:
			animated_sprite.material = player_underwater_material
	elif animated_sprite.material == player_underwater_material:
		animated_sprite.material = default_animated_sprite_material

	player_underwater_shader_active = should_enable


func get_active_head_water() -> Node:
	prune_water_bodies()
	return submerged_head_water_bodies.back() if not submerged_head_water_bodies.is_empty() else get_active_water()


func get_water_float(property_name: StringName, fallback: float) -> float:
	return get_water_float_from(get_active_water(), property_name, fallback)


func get_water_float_from(water_body: Node, property_name: StringName, fallback: float) -> float:
	if water_body == null or not is_instance_valid(water_body):
		return fallback

	var value: Variant = water_body.get(property_name)
	return float(value) if value != null else fallback


func setup_water_debug_display() -> void:
	if not water_debug_enabled:
		return

	var canvas := CanvasLayer.new()
	canvas.name = "WaterDebugCanvas"
	canvas.layer = 20
	add_child(canvas)

	water_debug_label = Label.new()
	water_debug_label.position = Vector2(18.0, 170.0)
	water_debug_label.add_theme_color_override("font_color", Color(0.82, 0.96, 1.0))
	water_debug_label.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.12, 0.95))
	water_debug_label.add_theme_constant_override("outline_size", 5)
	water_debug_label.add_theme_font_size_override("font_size", 18)
	canvas.add_child(water_debug_label)


func _process(_delta: float) -> void:
	if water_debug_enabled and water_state_debug_lines:
		queue_redraw()
	if water_debug_label == null:
		return

	var movement_state := "GROUND"
	if is_dead:
		movement_state = "DEAD"
	elif is_riding_zipline:
		movement_state = "ZIPLINE"
	elif is_swatting:
		movement_state = "SWATTING"
	elif surface_jump_active:
		movement_state = "AIRBORNE"
	elif is_surface_swimming:
		movement_state = "SURFACE"
	elif is_in_water():
		movement_state = "SWIMMING"
	elif not is_on_floor():
		movement_state = "AIRBORNE"

	var breath_duration := get_water_float_from(get_active_head_water(), &"breath_duration", 5.0)
	var breath_remaining := maxf(breath_duration - breath_elapsed, 0.0)
	var damage_remaining := maxf(next_drowning_damage_time - breath_elapsed, 0.0)
	var geometry_overlap := false
	var area_overlap := false
	if debug_surface_water_body != null and is_instance_valid(debug_surface_water_body):
		if debug_surface_water_body.has_method("contains_body"):
			geometry_overlap = bool(debug_surface_water_body.call("contains_body", self))
		if debug_surface_water_body.has_method("is_body_reported_inside"):
			area_overlap = bool(debug_surface_water_body.call("is_body_reported_inside", self))
	water_debug_label.text = "State: %s\nIn water: %s  Head submerged: %s\nGeometry overlap: %s  Area overlap: %s\nBreath: %.2fs  Next damage: %.2fs\nVelocity: (%.1f, %.1f)  Swim: %.1f  Applied gravity: %.1f\nLines: surface cyan | capture yellow | float green | body white" % [
		movement_state,
		str(is_in_water()),
		str(is_head_submerged()),
		str(geometry_overlap),
		str(area_overlap),
		breath_remaining,
		damage_remaining,
		velocity.x,
		velocity.y,
		swimming_speed * get_water_float(&"swim_speed_multiplier", 1.0),
		get_applied_gravity(),
	]


func _draw() -> void:
	if not water_debug_enabled or not water_state_debug_lines:
		return
	if debug_surface_water_body == null or not is_instance_valid(debug_surface_water_body):
		return
	if not bool(debug_surface_water_body.get("has_visible_surface")):
		return

	var half_width := 90.0
	var surface_y := get_water_surface_y(debug_surface_water_body) - global_position.y
	var float_y := surface_y - maxf(surface_float_offset, 0.0)
	var capture_y := float_y + maxf(surface_capture_distance, 0.0)
	var body_bottom_y := get_body_bottom_y() - global_position.y
	draw_line(Vector2(-half_width, surface_y), Vector2(half_width, surface_y), Color(0.1, 0.9, 1.0), 2.0)
	draw_line(Vector2(-half_width, capture_y), Vector2(half_width, capture_y), Color(1.0, 0.82, 0.15), 2.0)
	draw_line(Vector2(-half_width, float_y), Vector2(half_width, float_y), Color(0.2, 1.0, 0.35), 2.0)
	draw_line(Vector2(-30.0, body_bottom_y), Vector2(30.0, body_bottom_y), Color.WHITE, 2.0)


func get_body_bottom_y() -> float:
	if body_collision_shape == null:
		return global_position.y

	var rectangle := body_collision_shape.shape as RectangleShape2D
	if rectangle != null:
		return body_collision_shape.global_position.y + rectangle.size.y * 0.5 * abs(body_collision_shape.global_scale.y)

	return body_collision_shape.global_position.y


func play_animation_safe(name: StringName, fallback: StringName = &"idle") -> void:
	var frames: SpriteFrames = animated_sprite.sprite_frames

	if frames == null:
		return

	if frames.has_animation(name):
		if animated_sprite.animation != name:
			animated_sprite.play(name)
		return

	if frames.has_animation(fallback):
		if animated_sprite.animation != fallback:
			animated_sprite.play(fallback)


func update_animation() -> void:
	if is_dead:
		animated_sprite.speed_scale = 1.0
		play_animation_safe(&"death", &"idle")
		return

	if is_swatting:
		animated_sprite.speed_scale = 1.0
		play_animation_safe(&"swatting", &"idle")
		return

	if is_melee_attacking:
		animated_sprite.speed_scale = 1.0
		play_melee_animation()
		return

	if slap_animation_timer > 0.0:
		animated_sprite.speed_scale = 1.0
		play_animation_safe(&"slap", &"idle")
		return

	if is_riding_zipline:
		animated_sprite.speed_scale = 1.0
		play_animation_safe(&"zipline", &"jump")
		return

	if landing_animation_timer > 0.0:
		animated_sprite.speed_scale = 1.0
		play_animation_safe(&"landing", &"idle")
		return

	if is_in_water() and not surface_jump_active:
		var swim_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if not swim_input.is_zero_approx():
			animated_sprite.speed_scale = 0.75
			play_animation_safe(&"swim", &"idle")
		else:
			animated_sprite.speed_scale = 1.0
			play_animation_safe(&"swim_idle", &"idle")
		return

	if not is_on_floor():
		animated_sprite.speed_scale = 1.0

		if velocity.y < 0.0:
			play_animation_safe(&"jump", &"idle")
		else:
			play_animation_safe(&"fall", &"jump")
		return

	if abs(velocity.x) > 5.0:
		play_animation_safe(&"walk", &"idle")
		animated_sprite.speed_scale = clamp(abs(velocity.x) / move_speed, 0.85, 1.15)
	else:
		play_animation_safe(&"idle")
		animated_sprite.speed_scale = 1.0


func try_shoot() -> void:
	if is_swatting or is_melee_attacking:
		return

	if bullet_scene == null:
		return

	if current_ammo <= 0:
		return

	if not fire_timer.is_stopped():
		return

	fire_timer.start()
	consume_ammo(1)
	fire_bullet()


func fire_bullet() -> void:
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	bullet.global_position = get_muzzle_global_position()
	bullet.direction = facing
	spawn_muzzle_flash()

	shoot_sound.play()


func consume_ammo(amount: int) -> void:
	if amount <= 0:
		return

	current_ammo = maxi(current_ammo - amount, 0)
	ammo_changed.emit(current_ammo, max_ammo)


func add_ammo(amount: int) -> void:
	if amount <= 0:
		return

	var previous_ammo := current_ammo
	current_ammo = clampi(current_ammo + amount, 0, max_ammo)

	if current_ammo != previous_ammo:
		ammo_changed.emit(current_ammo, max_ammo)


func try_slap() -> void:
	if is_dead or is_swatting or is_melee_attacking or slap_cooldown_timer > 0.0:
		return

	slap_cooldown_timer = slap_cooldown
	slap_animation_timer = slap_duration
	play_animation_safe(&"slap", &"idle")
	spawn_slap_hitbox()


func spawn_slap_hitbox() -> void:
	var hitbox := Area2D.new()
	hitbox.name = "SlapHitbox"
	hitbox.collision_layer = 0
	hitbox.collision_mask = 16
	hitbox.monitoring = true
	hitbox.monitorable = false

	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(slap_range, slap_height)
	shape.shape = rectangle
	hitbox.add_child(shape)

	var hit_enemies: Array[Node] = []
	hitbox.area_entered.connect(_on_slap_hitbox_area_entered.bind(hit_enemies))

	get_tree().current_scene.add_child(hitbox)
	hitbox.global_position = global_position + Vector2((slap_range * 0.5 + 12.0) * facing, 8.0)

	await get_tree().create_timer(slap_duration).timeout
	if is_instance_valid(hitbox):
		hitbox.queue_free()


func _on_slap_hitbox_area_entered(area: Area2D, hit_enemies: Array[Node]) -> void:
	if not area.is_in_group("enemy_hurtbox"):
		return

	var enemy := area.get_parent()
	if enemy == null or hit_enemies.has(enemy):
		return

	hit_enemies.append(enemy)

	if enemy.has_method("slapped"):
		enemy.slapped()
	elif enemy.has_method("take_damage"):
		enemy.take_damage(1)


func try_melee_attack() -> void:
	if is_dead or is_swatting or is_riding_zipline or is_melee_attacking:
		return

	start_melee_attack()


func start_melee_attack() -> void:
	is_melee_attacking = true
	melee_attack_timer = 0.0
	melee_hitbox_active = false
	melee_started_on_floor = is_on_floor()
	melee_hit_targets.clear()
	update_melee_hitbox_geometry()

	if melee_started_on_floor:
		melee_ground_stop_timer = melee_ground_stop_time
		velocity.x = 0.0

	play_melee_animation()


func update_melee_attack(delta: float) -> void:
	if melee_ground_stop_timer > 0.0:
		melee_ground_stop_timer = maxf(melee_ground_stop_timer - delta, 0.0)

	if not is_melee_attacking:
		return

	melee_attack_timer += delta

	var hitbox_end_time := melee_hitbox_start_time + melee_hitbox_duration
	if not melee_hitbox_active and melee_attack_timer >= melee_hitbox_start_time and melee_attack_timer < hitbox_end_time:
		enable_melee_hitbox()
	elif melee_hitbox_active and melee_attack_timer >= hitbox_end_time:
		disable_melee_hitbox()

	if melee_attack_timer >= melee_attack_duration:
		finish_melee_attack()


func enable_melee_hitbox() -> void:
	update_melee_hitbox_geometry()
	melee_hitbox_active = true
	melee_hitbox.monitoring = true
	melee_hitbox_shape.disabled = false

	for area in melee_hitbox.get_overlapping_areas():
		_on_melee_hitbox_area_entered(area)


func disable_melee_hitbox() -> void:
	melee_hitbox_active = false
	melee_hitbox.monitoring = false
	melee_hitbox_shape.disabled = true


func finish_melee_attack() -> void:
	disable_melee_hitbox()
	is_melee_attacking = false
	melee_attack_timer = 0.0
	melee_ground_stop_timer = 0.0
	melee_hit_targets.clear()


func cancel_melee_attack() -> void:
	disable_melee_hitbox()
	is_melee_attacking = false
	melee_attack_timer = 0.0
	melee_ground_stop_timer = 0.0
	melee_hit_targets.clear()


func update_melee_hitbox_geometry() -> void:
	var rectangle := melee_hitbox_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = Vector2(melee_range, melee_height)

	melee_hitbox.position = Vector2((melee_range * 0.5 + melee_forward_offset) * facing, melee_vertical_offset)


func _on_melee_hitbox_area_entered(area: Area2D) -> void:
	if not melee_hitbox_active:
		return

	var is_enemy_hurtbox := area.is_in_group("enemy_hurtbox")
	var is_destroyable_hurtbox := area.is_in_group("destroyable_prop_hurtbox")
	if not is_enemy_hurtbox and not is_destroyable_hurtbox:
		return

	var target := find_melee_target(area, is_destroyable_hurtbox)
	if target == null or melee_hit_targets.has(target):
		return

	melee_hit_targets.append(target)

	if target.has_method("machete_hit"):
		if is_destroyable_hurtbox:
			target.machete_hit(melee_damage, melee_hitbox.global_position)
		else:
			target.machete_hit(melee_damage)
	elif target.has_method("take_damage"):
		if is_destroyable_hurtbox:
			target.take_damage(melee_damage, melee_hitbox.global_position, &"machete")
		else:
			target.take_damage(melee_damage)


func find_melee_target(area: Area2D, is_destroyable_hurtbox: bool) -> Node:
	var target := area.get_parent()
	var target_group := "destroyable_prop" if is_destroyable_hurtbox else "enemy"

	while target != null and target != self:
		if target.is_in_group(target_group):
			return target
		target = target.get_parent()

	return null


func play_melee_animation() -> void:
	if melee_started_on_floor:
		if play_animation_if_available(&"melee_ground"):
			return
	else:
		if play_animation_if_available(&"melee_air"):
			return
		if play_animation_if_available(&"melee_ground"):
			return

	play_animation_safe(&"melee_attack", &"idle")


func play_animation_if_available(name: StringName) -> bool:
	var frames: SpriteFrames = animated_sprite.sprite_frames
	if frames == null or not frames.has_animation(name):
		return false

	if animated_sprite.animation != name:
		animated_sprite.play(name)

	return true


func spawn_muzzle_flash() -> void:
	if muzzle_flash_scene == null:
		return

	var flash := muzzle_flash_scene.instantiate() as Node2D
	if flash == null:
		return

	add_child(flash)
	flash.position = get_muzzle_local_position()
	flash.scale.x = abs(flash.scale.x) * facing


func get_muzzle_local_position() -> Vector2:
	if muzzle_marker != null:
		return Vector2(abs(muzzle_marker.position.x) * facing, muzzle_marker.position.y)

	return Vector2(muzzle_flash_offset.x * facing, muzzle_flash_offset.y)


func get_muzzle_global_position() -> Vector2:
	if muzzle_marker != null:
		return to_global(get_muzzle_local_position())

	return global_position + Vector2(bullet_offset.x * facing, bullet_offset.y)

func _on_hurtbox_body_entered(body: Node) -> void:
	if not body.is_in_group("enemy"):
		return

	var damage := 1
	if body.get("contact_damage") != null:
		damage = int(body.get("contact_damage"))

	take_damage(damage)


func take_damage(amount: int = 1, ignore_invulnerability: bool = false) -> void:
	if is_dead or (invulnerability_timer > 0.0 and not ignore_invulnerability):
		return

	current_hp -= amount

	if debug_enabled:
		print("Player damage received: ", amount, " HP: ", current_hp, "/", max_hp)

	if current_hp <= 0:
		die()
		return

	health_changed.emit(current_hp, max_hp)
	invulnerability_timer = invulnerability_time
	blink_timer = 0.0


func update_invulnerability(delta: float) -> void:
	if invulnerability_timer <= 0.0:
		animated_sprite.visible = true
		return

	invulnerability_timer -= delta
	blink_timer -= delta

	if blink_timer <= 0.0:
		animated_sprite.visible = not animated_sprite.visible
		blink_timer = 0.08

	if invulnerability_timer <= 0.0:
		animated_sprite.visible = true


func update_mosquito_immunity(delta: float) -> void:
	if mosquito_immunity_timer > 0.0:
		mosquito_immunity_timer -= delta


func update_slap_timers(delta: float) -> void:
	if slap_cooldown_timer > 0.0:
		slap_cooldown_timer -= delta

	if slap_animation_timer > 0.0:
		slap_animation_timer -= delta


func update_landing_timers(delta: float) -> void:
	if landing_animation_timer > 0.0:
		landing_animation_timer -= delta

	if landing_stop_timer > 0.0:
		landing_stop_timer -= delta


func update_zipline_timers(delta: float) -> void:
	if zipline_reattach_timer > 0.0:
		zipline_reattach_timer -= delta


func register_nearby_zipline(zipline: Node) -> void:
	if not nearby_ziplines.has(zipline):
		nearby_ziplines.append(zipline)


func unregister_nearby_zipline(zipline: Node) -> void:
	nearby_ziplines.erase(zipline)


func try_attach_to_nearest_zipline() -> void:
	if is_dead or is_swatting or is_melee_attacking or is_riding_zipline or zipline_reattach_timer > 0.0:
		return

	var closest_zipline: Node = null
	var closest_progress := 0.0
	var closest_distance := INF

	for zipline in nearby_ziplines:
		if zipline == null or not is_instance_valid(zipline):
			continue

		if not zipline.has_method("get_closest_progress_to_world_position"):
			continue

		var progress: float = zipline.call("get_closest_progress_to_world_position", global_position)
		var cable_position: Vector2 = zipline.call("get_world_position_at_progress", progress)
		var distance := global_position.distance_squared_to(cable_position)

		if distance < closest_distance:
			closest_distance = distance
			closest_progress = progress
			closest_zipline = zipline

	if closest_zipline != null:
		attach_to_zipline(closest_zipline, closest_progress)


func attach_to_zipline(zipline: Node, progress: float) -> void:
	if zipline == null or not is_instance_valid(zipline):
		return

	active_zipline = zipline
	is_riding_zipline = true
	zipline_progress = clamp(progress, 0.0, 1.0)
	cancel_landing()
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	air_jumps_left = extra_jumps

	var tangent: Vector2 = active_zipline.call("get_world_tangent_at_progress", zipline_progress)
	var projected_speed := velocity.dot(tangent)
	var downhill_direction: float = active_zipline.call("get_downhill_progress_direction")
	var minimum_speed: float = active_zipline.get("minimum_downhill_speed")
	var fallback_speed: float = active_zipline.get("initial_ride_speed")

	if abs(projected_speed) < minimum_speed:
		projected_speed = max(minimum_speed, fallback_speed) * downhill_direction

	zipline_speed = projected_speed
	active_zipline.call("attach_player", self, zipline_progress)
	active_zipline.call("set_rider_progress", zipline_progress)
	global_position = active_zipline.call("get_world_position_at_progress", zipline_progress) + active_zipline.get("player_hang_offset")
	velocity = tangent * zipline_speed


func update_zipline_movement(delta: float) -> void:
	if active_zipline == null or not is_instance_valid(active_zipline):
		force_detach_from_zipline()
		return

	var tangent: Vector2 = active_zipline.call("get_world_tangent_at_progress", zipline_progress)
	var acceleration: float = active_zipline.get("ride_acceleration")
	var maximum_speed: float = active_zipline.get("maximum_ride_speed")
	var downhill_direction: float = active_zipline.call("get_downhill_progress_direction")
	var minimum_speed: float = active_zipline.get("minimum_downhill_speed")
	var cable_length: float = active_zipline.call("get_cable_length")
	var gravity_acceleration := Vector2(0.0, gravity).dot(tangent)

	zipline_speed += gravity_acceleration * acceleration / gravity * delta
	zipline_speed = clamp(zipline_speed, -maximum_speed, maximum_speed)

	if signf(zipline_speed) == downhill_direction and abs(zipline_speed) < minimum_speed:
		zipline_speed = minimum_speed * downhill_direction
	elif abs(zipline_speed) < 1.0:
		zipline_speed = minimum_speed * downhill_direction

	zipline_progress += (zipline_speed / cable_length) * delta

	var reached_start := zipline_progress <= 0.0
	var reached_end := zipline_progress >= 1.0
	zipline_progress = clamp(zipline_progress, 0.0, 1.0)
	active_zipline.call("set_rider_progress", zipline_progress)

	var target_position: Vector2 = active_zipline.call("get_world_position_at_progress", zipline_progress) + active_zipline.get("player_hang_offset")
	velocity = (target_position - global_position) / max(delta, 0.001)

	if velocity.x > 5.0:
		facing = 1
	elif velocity.x < -5.0:
		facing = -1
	animated_sprite.flip_h = facing < 0

	move_and_slide()

	if reached_start or reached_end:
		detach_from_zipline(get_zipline_launch_velocity(false))


func get_zipline_launch_velocity(include_jump: bool) -> Vector2:
	if active_zipline == null or not is_instance_valid(active_zipline):
		return velocity

	var tangent: Vector2 = active_zipline.call("get_world_tangent_at_progress", zipline_progress)
	var launch_velocity := tangent * zipline_speed

	if include_jump:
		launch_velocity.y -= active_zipline.get("detach_jump_velocity")
	else:
		launch_velocity *= active_zipline.get("end_launch_multiplier")

	return launch_velocity


func detach_from_zipline(launch_velocity: Vector2) -> void:
	if active_zipline != null and is_instance_valid(active_zipline):
		active_zipline.call("detach_player", self)

	active_zipline = null
	is_riding_zipline = false
	zipline_speed = 0.0
	zipline_reattach_timer = zipline_reattach_cooldown_time
	velocity = launch_velocity


func force_detach_from_zipline() -> void:
	if not is_riding_zipline:
		return

	detach_from_zipline(velocity)


func update_hard_landing(was_on_floor: bool) -> void:
	if is_dead or is_swatting:
		max_fall_speed = 0.0
		return

	if was_on_floor:
		max_fall_speed = 0.0
		return

	if not is_on_floor():
		return

	if max_fall_speed >= hard_landing_min_fall_speed:
		start_hard_landing()

	max_fall_speed = 0.0


func start_hard_landing() -> void:
	landing_animation_timer = hard_landing_animation_time
	landing_stop_timer = hard_landing_stop_time
	velocity.x = 0.0


func cancel_landing() -> void:
	landing_animation_timer = 0.0
	landing_stop_timer = 0.0


func mosquito_attack() -> void:
	if is_dead or is_swatting or mosquito_immunity_timer > 0.0:
		return

	force_detach_from_zipline()
	cancel_melee_attack()
	is_swatting = true
	swatting_timer = 1.0
	slap_animation_timer = 0.0
	if is_on_floor():
		velocity.x = 0.0
	play_animation_safe(&"swatting", &"idle")


func update_swatting(delta: float) -> void:
	swatting_timer -= delta

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.x = 0.0
		velocity.y = 0.0

	if swatting_timer <= 0.0:
		is_swatting = false
		mosquito_immunity_timer = mosquito_immunity_time


func die() -> void:
	if is_dead:
		return

	force_detach_from_zipline()
	cancel_melee_attack()
	reset_water_state()
	is_dead = true
	current_hp = 0
	health_changed.emit(current_hp, max_hp)
	hurtbox.monitoring = false
	animated_sprite.visible = true
	velocity.x = 0.0

	if velocity.y < 0.0:
		velocity.y = 0.0

	play_animation_safe(&"death", &"idle")
	respawn_after_delay()


func respawn_after_delay() -> void:
	await get_tree().create_timer(1.5).timeout
	respawn()


func respawn() -> void:
	get_tree().reload_current_scene()
