extends CharacterBody2D

const BLOOD_BURST_SCENE: PackedScene = preload("res://scenes/fx/blood_burst.tscn")
const DAMAGE_SOURCE_ENEMY: StringName = &"enemy"

enum State {
	PATROL,
	WIND_UP,
	FIRING,
	COOLDOWN,
}

@export_group("Patrol")
@export var patrol_speed: float = 60.0
@export var gravity: float = 1000.0
@export var move_direction: int = 1
@export var patrol_distance: float = 200.0

@export_group("Health")
@export var max_hp: int = 3
@export var contact_damage: int = 1

@export_group("Detection")
@export var detection_range: float = 340.0
@export var vertical_tolerance: float = 64.0
@export var lose_range: float = 420.0
@export var player_detection_offset: Vector2 = Vector2(0.0, -8.0)
@export_flags_2d_physics var vision_block_mask: int = 1

@export_group("Flame Attack")
@export var wind_up_time: float = 0.65
@export var flame_range: float = 260.0
@export var flame_width: float = 28.0
@export var firing_duration: float = 2.0
@export var flame_damage: int = 1
@export var damage_interval: float = 0.15
@export var attack_cooldown: float = 1.5
@export var flame_particle_speed: float = 360.0
@export var flame_damage_initial_range: float = 16.0
@export_range(0.1, 2.0, 0.05) var flame_damage_growth_speed_multiplier: float = 1.0

@export_group("Burning Ground")
@export var burning_ground_scene: PackedScene = preload("res://scenes/Hazards/burning_ground.tscn")
@export var ground_fire_spawn_delay: float = 0.25
@export var ground_probe_depth: float = 72.0
@export var ground_patch_duplicate_radius: float = 60.0
@export var max_ground_patches_per_burst: int = 1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var wall_check_left: RayCast2D = $WallCheckLeft
@onready var wall_check_right: RayCast2D = $WallCheckRight
@onready var floor_check_left: RayCast2D = $FloorCheckLeft
@onready var floor_check_right: RayCast2D = $FloorCheckRight
@onready var sight_origin: Marker2D = $SightOrigin
@onready var flame_pivot: Node2D = $FlamePivot
@onready var flame_origin: Node2D = $FlamePivot/FlameOrigin
@onready var nozzle_glow: PointLight2D = $FlamePivot/FlameOrigin/NozzleGlow
@onready var flame_particles: GPUParticles2D = $FlamePivot/FlameOrigin/FlameParticles
@onready var flame_reach_ray: RayCast2D = $FlamePivot/FlameOrigin/FlameReachRay
@onready var flame_damage_area: Area2D = $FlamePivot/FlameOrigin/FlameDamageArea
@onready var flame_damage_shape: CollisionShape2D = $FlamePivot/FlameOrigin/FlameDamageArea/CollisionShape2D
@onready var ground_ray_far: RayCast2D = $FlamePivot/FlameOrigin/GroundRayFar
@onready var damage_tick_timer: Timer = $DamageTickTimer
@onready var hit_sound: AudioStreamPlayer2D = $HitSound
@onready var wind_up_sound: AudioStreamPlayer2D = get_node_or_null("WindUpSound") as AudioStreamPlayer2D
@onready var flame_loop_sound: AudioStreamPlayer2D = get_node_or_null("FlameLoopSound") as AudioStreamPlayer2D

var state: State = State.PATROL
var hp: int = 0
var player: Node2D = null
var patrol_origin_x: float = 0.0
var state_time_remaining: float = 0.0
var locked_fire_direction: int = 1
var effective_flame_range: float = 0.0
var current_flame_damage_range: float = 0.0
var ground_fire_spawn_timer: float = 0.0
var ground_patches_spawned_this_burst: int = 0
var is_dying: bool = false

var flame_damage_rectangle: RectangleShape2D = null
var flame_pivot_base_scale: Vector2 = Vector2.ONE
var ground_ray_base_y: float = 0.0
var nozzle_glow_base_energy: float = 0.0


func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp
	patrol_origin_x = global_position.x
	move_direction = normalize_direction(move_direction)
	locked_fire_direction = move_direction
	player = get_tree().get_first_node_in_group("player") as Node2D

	flame_pivot_base_scale = Vector2(absf(flame_pivot.scale.x), flame_pivot.scale.y)
	ground_ray_base_y = ground_ray_far.position.y
	nozzle_glow_base_energy = nozzle_glow.energy

	if animated_sprite.material != null:
		animated_sprite.material = animated_sprite.material.duplicate()
		_set_flash_amount(0.0)

	var authored_damage_shape := flame_damage_shape.shape as RectangleShape2D
	if authored_damage_shape != null:
		flame_damage_rectangle = authored_damage_shape

	var particle_material := flame_particles.process_material as ParticleProcessMaterial
	if particle_material != null:
		particle_material = particle_material.duplicate() as ParticleProcessMaterial
		particle_material.initial_velocity_min = flame_particle_speed * 0.9
		particle_material.initial_velocity_max = flame_particle_speed * 1.1
		flame_particles.process_material = particle_material

	damage_tick_timer.one_shot = false
	damage_tick_timer.wait_time = maxf(damage_interval, 0.05)
	if not damage_tick_timer.timeout.is_connected(apply_flame_damage_tick):
		damage_tick_timer.timeout.connect(apply_flame_damage_tick)

	flame_reach_ray.target_position = Vector2(maxf(flame_range, 1.0), 0.0)
	ground_ray_far.target_position = Vector2(0.0, maxf(ground_probe_depth, 1.0))
	update_facing_visual()
	update_attack_geometry(flame_range)
	set_flame_active(false, true)
	set_nozzle_glow(false)
	play_animation_safe(&"walk", &"idle")


func _physics_process(delta: float) -> void:
	if is_dying:
		return

	apply_gravity(delta)
	refresh_player_reference()

	match state:
		State.PATROL:
			run_patrol()
		State.WIND_UP:
			run_wind_up(delta)
		State.FIRING:
			run_firing(delta)
		State.COOLDOWN:
			run_cooldown(delta)

	move_and_slide()


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0


func run_patrol() -> void:
	if can_detect_player():
		enter_wind_up()
		return

	if reached_patrol_limit() or should_turn_around():
		turn_around()

	velocity.x = move_direction * patrol_speed
	update_facing_visual()
	play_animation_safe(&"walk", &"idle")


func run_wind_up(delta: float) -> void:
	velocity.x = 0.0
	if not has_wind_up_target():
		enter_patrol()
		return

	state_time_remaining -= delta
	update_wind_up_glow()
	if state_time_remaining <= 0.0:
		enter_firing()


func run_firing(delta: float) -> void:
	velocity.x = 0.0
	if not is_player_alive():
		enter_cooldown()
		return

	update_flame_damage_reach(delta)
	state_time_remaining -= delta
	ground_fire_spawn_timer -= delta
	if ground_patches_spawned_this_burst < maxi(max_ground_patches_per_burst, 0) and ground_fire_spawn_timer <= 0.0:
		try_spawn_ground_fire()

	if state_time_remaining <= 0.0:
		enter_cooldown()


func run_cooldown(delta: float) -> void:
	velocity.x = 0.0
	state_time_remaining -= delta
	if state_time_remaining <= 0.0:
		enter_patrol()


func reached_patrol_limit() -> bool:
	if patrol_distance <= 0.0:
		return false

	var offset_from_origin := global_position.x - patrol_origin_x
	if move_direction < 0:
		return offset_from_origin <= -patrol_distance

	return offset_from_origin >= patrol_distance


func should_turn_around() -> bool:
	if move_direction < 0:
		return wall_check_left.is_colliding() or not floor_check_left.is_colliding()

	return wall_check_right.is_colliding() or not floor_check_right.is_colliding()


func turn_around() -> void:
	move_direction *= -1
	update_facing_visual()


func refresh_player_reference() -> void:
	if is_instance_valid(player):
		return

	player = get_tree().get_first_node_in_group("player") as Node2D


func is_player_alive() -> bool:
	return is_instance_valid(player) and not bool(player.get("is_dead"))


func is_player_detectable() -> bool:
	if not is_player_alive():
		return false

	if player.has_method("is_detectable_by_enemies"):
		return bool(player.call("is_detectable_by_enemies"))

	return true


func can_detect_player() -> bool:
	if not is_player_detectable():
		return false

	var to_player := player.global_position - global_position
	if absf(to_player.x) > detection_range or absf(to_player.y) > vertical_tolerance:
		return false
	if not is_target_in_direction(move_direction):
		return false

	return has_clear_line_to_player()


func has_wind_up_target() -> bool:
	if not is_player_detectable():
		return false

	var to_player := player.global_position - global_position
	if absf(to_player.x) > lose_range or absf(to_player.y) > vertical_tolerance:
		return false
	if not is_target_in_direction(locked_fire_direction):
		return false

	return has_clear_line_to_player()


func is_target_in_direction(direction: int) -> bool:
	if not is_instance_valid(player):
		return false

	var horizontal_delta := player.global_position.x - global_position.x
	if is_zero_approx(horizontal_delta):
		return true

	return signi(horizontal_delta) == normalize_direction(direction)


func has_clear_line_to_player() -> bool:
	if not is_instance_valid(player):
		return false

	var query := PhysicsRayQueryParameters2D.create(sight_origin.global_position, get_player_detection_point())
	query.collision_mask = vision_block_mask
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true

	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func get_player_detection_point() -> Vector2:
	return player.global_position + player_detection_offset


func enter_wind_up() -> void:
	if not is_player_detectable():
		return

	var horizontal_delta := player.global_position.x - global_position.x
	if not is_zero_approx(horizontal_delta):
		move_direction = 1 if horizontal_delta > 0.0 else -1

	locked_fire_direction = move_direction
	state = State.WIND_UP
	state_time_remaining = maxf(wind_up_time, 0.0)
	velocity.x = 0.0
	update_facing_visual()
	set_nozzle_glow(true)
	play_animation_safe(&"wind_up", &"idle")
	if wind_up_sound != null and wind_up_sound.stream != null:
		wind_up_sound.play()


func enter_firing() -> void:
	state = State.FIRING
	state_time_remaining = maxf(firing_duration, 0.0)
	ground_fire_spawn_timer = maxf(ground_fire_spawn_delay, 0.0)
	ground_patches_spawned_this_burst = 0
	move_direction = normalize_direction(locked_fire_direction)
	velocity.x = 0.0
	update_facing_visual()
	calculate_effective_flame_range()
	current_flame_damage_range = minf(maxf(flame_damage_initial_range, 1.0), maxf(effective_flame_range, 1.0))
	update_flame_damage_geometry(current_flame_damage_range)
	play_animation_safe(&"fire", &"idle")
	set_nozzle_glow(true)
	set_flame_active(true)


func enter_cooldown() -> void:
	stop_direct_flame_attack()
	state = State.COOLDOWN
	state_time_remaining = maxf(attack_cooldown, 0.0)
	velocity.x = 0.0
	set_nozzle_glow(false)
	play_animation_safe(&"cooldown", &"idle")


func enter_patrol() -> void:
	stop_direct_flame_attack()
	state = State.PATROL
	state_time_remaining = 0.0
	velocity.x = 0.0
	set_nozzle_glow(false)
	play_animation_safe(&"walk", &"idle")


func stop_direct_flame_attack() -> void:
	set_flame_active(false)
	if wind_up_sound != null:
		wind_up_sound.stop()


func calculate_effective_flame_range() -> void:
	flame_reach_ray.target_position = Vector2(maxf(flame_range, 1.0), 0.0)
	flame_pivot.force_update_transform()
	flame_reach_ray.force_raycast_update()

	effective_flame_range = maxf(flame_range, 0.0)
	if flame_reach_ray.is_colliding():
		var collision_point := flame_reach_ray.get_collision_point()
		effective_flame_range = minf(effective_flame_range, flame_origin.global_position.distance_to(collision_point))

	update_attack_geometry(effective_flame_range)


func update_attack_geometry(attack_range: float) -> void:
	var safe_range := maxf(attack_range, 1.0)
	update_flame_damage_geometry(safe_range)

	ground_ray_far.position = Vector2(safe_range * 0.82, ground_ray_base_y)
	ground_ray_far.target_position = Vector2(0.0, maxf(ground_probe_depth, 1.0))

	var safe_particle_speed := maxf(flame_particle_speed, 1.0)
	flame_particles.lifetime = clampf(safe_range / safe_particle_speed, 0.08, 2.0)


func update_flame_damage_reach(delta: float) -> void:
	var growth_speed := maxf(flame_particle_speed, 1.0) * maxf(flame_damage_growth_speed_multiplier, 0.1)
	current_flame_damage_range = minf(
		current_flame_damage_range + growth_speed * maxf(delta, 0.0),
		maxf(effective_flame_range, 1.0)
	)
	update_flame_damage_geometry(current_flame_damage_range)


func update_flame_damage_geometry(damage_range: float) -> void:
	var safe_range := maxf(damage_range, 1.0)
	if flame_damage_rectangle != null:
		flame_damage_rectangle.size = Vector2(safe_range, maxf(flame_width, 1.0))
	flame_damage_shape.position = Vector2(safe_range * 0.5, 0.0)


func set_flame_active(active: bool, immediate: bool = false) -> void:
	if active:
		flame_particles.restart()
		flame_particles.emitting = true
		damage_tick_timer.start(maxf(damage_interval, 0.05))
		if flame_loop_sound != null and flame_loop_sound.stream != null and not flame_loop_sound.playing:
			flame_loop_sound.play()
	else:
		flame_particles.emitting = false
		damage_tick_timer.stop()
		if flame_loop_sound != null:
			flame_loop_sound.stop()

	if immediate:
		if active:
			flame_damage_shape.disabled = false
			flame_damage_area.monitoring = true
		else:
			flame_damage_area.monitoring = false
			flame_damage_shape.disabled = true
	elif active:
		flame_damage_shape.set_deferred("disabled", false)
		flame_damage_area.set_deferred("monitoring", true)
	else:
		flame_damage_area.set_deferred("monitoring", false)
		flame_damage_shape.set_deferred("disabled", true)


func apply_flame_damage_tick() -> void:
	if state != State.FIRING or flame_damage_shape.disabled:
		return

	for body in get_flame_damage_targets():
		if body.has_method("take_damage"):
			body.call("take_damage", flame_damage, false, DAMAGE_SOURCE_ENEMY)


func get_flame_damage_targets() -> Array[Node2D]:
	var targets: Array[Node2D] = []
	if flame_damage_shape.disabled or flame_damage_shape.shape == null:
		return targets

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = flame_damage_shape.shape
	query.transform = flame_damage_shape.global_transform
	query.collision_mask = flame_damage_area.collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]

	var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(query, 32)
	for result: Dictionary in results:
		var body := result.get("collider") as Node2D
		if body == null or not body.is_in_group("player") or targets.has(body):
			continue
		targets.append(body)

	return targets


func try_spawn_ground_fire() -> bool:
	if state != State.FIRING:
		return false
	if ground_patches_spawned_this_burst >= maxi(max_ground_patches_per_burst, 0):
		return false

	ground_patches_spawned_this_burst += 1
	if burning_ground_scene == null or effective_flame_range < 48.0:
		return false

	flame_pivot.force_update_transform()
	ground_ray_far.force_raycast_update()
	if not ground_ray_far.is_colliding():
		return false

	var collision_normal := ground_ray_far.get_collision_normal()
	if collision_normal.dot(Vector2.UP) < 0.7:
		return false

	var spawn_position := ground_ray_far.get_collision_point() + collision_normal * 2.0
	for candidate in get_tree().get_nodes_in_group("burning_ground"):
		var existing_patch := candidate as Node2D
		if not is_instance_valid(existing_patch):
			continue
		if existing_patch.global_position.distance_to(spawn_position) > ground_patch_duplicate_radius:
			continue

		if existing_patch.has_method("refresh_lifetime"):
			existing_patch.call("refresh_lifetime")
		return true

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return false

	var patch := burning_ground_scene.instantiate() as Node2D
	if patch == null:
		return false

	current_scene.add_child(patch)
	patch.global_position = spawn_position
	return true


func update_facing_visual() -> void:
	move_direction = normalize_direction(move_direction)
	animated_sprite.flip_h = move_direction < 0
	flame_pivot.scale = Vector2(flame_pivot_base_scale.x * move_direction, flame_pivot_base_scale.y)


func update_wind_up_glow() -> void:
	if nozzle_glow == null:
		return

	var elapsed := maxf(wind_up_time - state_time_remaining, 0.0)
	var pulse := 0.65 + sin(elapsed * 18.0) * 0.2
	nozzle_glow.energy = nozzle_glow_base_energy * pulse


func set_nozzle_glow(enabled: bool) -> void:
	if nozzle_glow == null:
		return

	nozzle_glow.enabled = enabled
	nozzle_glow.energy = nozzle_glow_base_energy


func play_animation_safe(animation_name: StringName, fallback: StringName) -> void:
	if animated_sprite.sprite_frames == null:
		return

	var selected := animation_name
	if not animated_sprite.sprite_frames.has_animation(selected):
		selected = fallback
	if not animated_sprite.sprite_frames.has_animation(selected):
		return
	if animated_sprite.animation != selected or not animated_sprite.is_playing():
		animated_sprite.play(selected)


func normalize_direction(direction: int) -> int:
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
	if animated_sprite.material == null:
		return

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


func die() -> void:
	if is_dying:
		return

	is_dying = true
	velocity = Vector2.ZERO
	stop_direct_flame_attack()
	set_nozzle_glow(false)
	spawn_death_fx()

	var state_of_game := get_node_or_null("/root/StateOfGame")
	if state_of_game != null and state_of_game.has_method("register_enemy_defeated"):
		state_of_game.call("register_enemy_defeated")

	queue_free()


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


func spawn_death_fx() -> void:
	if BLOOD_BURST_SCENE == null or get_tree().current_scene == null:
		return

	var effect := BLOOD_BURST_SCENE.instantiate() as Node2D
	if effect == null:
		return

	effect.global_position = global_position
	get_tree().current_scene.add_child(effect)


func _exit_tree() -> void:
	if damage_tick_timer != null:
		damage_tick_timer.stop()
	if flame_particles != null:
		flame_particles.emitting = false
	if flame_damage_area != null:
		flame_damage_area.monitoring = false
	if flame_damage_shape != null:
		flame_damage_shape.disabled = true
	if flame_loop_sound != null:
		flame_loop_sound.stop()
