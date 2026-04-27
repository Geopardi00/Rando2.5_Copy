extends CharacterBody2D

signal boss_defeated
signal stomp_landed(position: Vector2)

const BOSS_BULLET_SCENE := preload("res://scenes/projectiles/boss_bullet.tscn")
const BOSS_GRENADE_SCENE := preload("res://scenes/projectiles/boss_grenade.tscn")
const GRENADE_WARNING_SCENE := preload("res://scenes/fx/grenade_warning.tscn")
const BLOOD_BURST_SCENE := preload("res://scenes/fx/blood_burst.tscn")

enum BossState {
	IDLE,
	SHOOTING,
	RELOADING,
	JUMPING,
	STOMPING,
	THROWING_GRENADES,
	HURT,
	DEAD
}

@export var max_hp: int = 30
@export var contact_damage: int = 1
@export var bullet_damage: int = 1
@export var grenade_damage: int = 1
@export var stomp_damage: int = 1
@export var attack_delay: float = 1.0
@export var gravity: float = 1100.0
@export var jump_velocity_y: float = -650.0
@export var jump_speed_x: float = 360.0
@export var stomp_min_travel_distance: float = 260.0
@export var stomp_damage_time: float = 0.25
@export var shoot_burst_count: int = 2
@export var bullets_per_burst: int = 3
@export var burst_delay: float = 0.35
@export var reload_time: float = 1.0
@export var grenade_count: int = 2
@export var grenade_warning_time: float = 0.75
@export var grenade_air_time: float = 0.5
@export var debug_enabled: bool = false
@export var boss_left_limit_path: NodePath
@export var boss_right_limit_path: NodePath
@export var grenade_left_limit_path: NodePath
@export var grenade_right_limit_path: NodePath
@export var fight_starts_automatically: bool = true

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_state: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var contact_damage_area: Area2D = $ContactDamageArea
@onready var contact_damage_shape: CollisionShape2D = $ContactDamageArea/CollisionShape2D
@onready var muzzle_marker: Marker2D = $MuzzleMarker
@onready var grenade_throw_marker: Marker2D = $GrenadeThrowMarker
@onready var stomp_damage_area: Area2D = $StompDamageArea
@onready var stomp_damage_shape: CollisionShape2D = $StompDamageArea/CollisionShape2D
@onready var attack_timer: Timer = $AttackTimer
@export var sprite_faces_right_by_default: bool = true

var state: BossState = BossState.IDLE
var hp: int = 0
var player: Node2D = null
var fight_started: bool = false
var first_attack_done: bool = false
var stomp_target_x: float = 0.0
var stomp_jump_direction: float = 1.0
var stomp_has_left_floor: bool = false
var damaged_by_current_stomp: Array[Node] = []
var current_contact_targets: Array[Node] = []


func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp
	randomize()

	animation_tree.active = false
	contact_damage_area.body_entered.connect(_on_contact_damage_body_entered)
	contact_damage_area.body_exited.connect(_on_contact_damage_body_exited)
	stomp_damage_area.body_entered.connect(_on_stomp_damage_body_entered)
	stomp_damage_shape.disabled = true
	stomp_damage_area.monitoring = false

	if animated_sprite.material != null:
		animated_sprite.material = animated_sprite.material.duplicate()
		_set_flash_amount(0.0)

	player = get_tree().get_first_node_in_group("player") as Node2D
	travel(&"idle")

	if fight_starts_automatically:
		start_fight()


func _physics_process(delta: float) -> void:
	refresh_player()
	face_player()

	if state == BossState.DEAD:
		return

	if state == BossState.JUMPING:
		if velocity.y < 0.0 or not is_on_floor():
			velocity.y += gravity * delta
		else:
			velocity.y = 0.0

		run_stomp_jump()
	else:
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			velocity.y = 0.0

		velocity.x = 0.0

	move_and_slide()

	if state == BossState.JUMPING and not stomp_has_left_floor and not is_on_floor():
		stomp_has_left_floor = true

	if state == BossState.JUMPING and stomp_has_left_floor and is_on_floor() and velocity.y >= 0.0:
		land_stomp()


func start_fight() -> void:
	if fight_started or state == BossState.DEAD:
		return

	fight_started = true
	debug_print("Boss fight started")
	await get_tree().create_timer(0.35).timeout

	if can_attack():
		do_shoot_attack()


func choose_next_attack() -> void:
	if not can_attack():
		return

	set_state(BossState.IDLE)
	travel(&"idle")
	await get_tree().create_timer(attack_delay).timeout

	if not can_attack():
		return

	var roll := randi_range(1, 100)
	if roll <= 40:
		debug_print("Chosen attack: shoot")
		do_shoot_attack()
	elif roll <= 75:
		debug_print("Chosen attack: grenade")
		do_grenade_attack()
	else:
		debug_print("Chosen attack: stomp")
		do_jump_stomp()


func do_shoot_attack() -> void:
	if not can_attack():
		return

	set_state(BossState.SHOOTING)
	travel(&"shoot")
	face_player()

	for burst in shoot_burst_count:
		if not can_attack():
			return

		fire_burst()
		if burst < shoot_burst_count - 1:
			await get_tree().create_timer(burst_delay).timeout

	first_attack_done = true
	do_reload()


func do_reload() -> void:
	if state == BossState.DEAD:
		return

	set_state(BossState.RELOADING)
	travel(&"reload")
	await get_tree().create_timer(reload_time).timeout

	if can_attack():
		choose_next_attack()


func do_jump_stomp() -> void:
	if not can_attack():
		return

	set_state(BossState.JUMPING)
	travel(&"jump")
	face_player()

	var left_x := get_marker_x(boss_left_limit_path, 260.0)
	var right_x := get_marker_x(boss_right_limit_path, 1660.0)
	var mid_x := (left_x + right_x) * 0.5
	var current_x := global_position.x

	if current_x <= mid_x:
		stomp_target_x = right_x
	else:
		stomp_target_x = left_x

	if abs(stomp_target_x - current_x) < stomp_min_travel_distance:
		stomp_target_x = left_x if stomp_target_x == right_x else right_x

	stomp_has_left_floor = false

	var dir: float = sign(stomp_target_x - global_position.x)
	if dir == 0.0:
		dir = 1.0

	stomp_jump_direction = dir
	velocity.x = stomp_jump_direction * jump_speed_x
	velocity.y = jump_velocity_y


func do_grenade_attack() -> void:
	if not can_attack():
		return

	set_state(BossState.THROWING_GRENADES)
	travel(&"throw")
	face_player()

	var targets: Array[Vector2] = pick_grenade_targets()
	for target in targets:
		if not can_attack():
			return

		throw_grenade_at(target)
		await get_tree().create_timer(0.25).timeout

	await get_tree().create_timer(grenade_warning_time + 0.15).timeout

	if can_attack():
		choose_next_attack()


func fire_burst() -> void:
	var base_direction := Vector2.LEFT
	if is_instance_valid(player):
		base_direction = (player.global_position - muzzle_marker.global_position).normalized()

	var directions: Array[Vector2] = [base_direction]
	if bullets_per_burst >= 2:
		directions.append(base_direction.rotated(deg_to_rad(-10.0)))
	if bullets_per_burst >= 3:
		directions.append(base_direction.rotated(deg_to_rad(10.0)))

	for i in range(min(bullets_per_burst, directions.size())):
		var bullet = BOSS_BULLET_SCENE.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = muzzle_marker.global_position
		bullet.setup(directions[i], bullet_damage)


func run_stomp_jump() -> void:
	var dx: float = stomp_target_x - global_position.x
	if sign(dx) != stomp_jump_direction or abs(dx) <= 12.0:
		velocity.x = move_toward(velocity.x, 0.0, 40.0)
	else:
		velocity.x = stomp_jump_direction * jump_speed_x

	if animated_sprite.animation != &"jump":
		travel(&"jump")


func land_stomp() -> void:
	set_state(BossState.STOMPING)
	travel(&"stomp")
	velocity.x = 0.0
	damaged_by_current_stomp.clear()

	stomp_damage_area.monitoring = true
	stomp_damage_shape.disabled = false
	stomp_landed.emit(global_position)

	for body in stomp_damage_area.get_overlapping_bodies():
		_damage_with_stomp(body)

	await get_tree().create_timer(stomp_damage_time).timeout
	stomp_damage_area.monitoring = false
	stomp_damage_shape.disabled = true

	if can_attack():
		choose_next_attack()


func throw_grenade_at(target: Vector2) -> void:
	var warning = GRENADE_WARNING_SCENE.instantiate()
	get_tree().current_scene.add_child(warning)
	warning.global_position = target

	var grenade = BOSS_GRENADE_SCENE.instantiate()
	get_tree().current_scene.add_child(grenade)
	grenade.travel_time = grenade_air_time
	grenade.setup(grenade_throw_marker.global_position, target, grenade_damage, warning)


func pick_grenade_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	var left_x := get_marker_x(grenade_left_limit_path, 220.0)
	var right_x := get_marker_x(grenade_right_limit_path, 1700.0)
	var ground_y := global_position.y + 10.0

	if is_instance_valid(player):
		targets.append(Vector2(clamp(player.global_position.x + randf_range(-160.0, 160.0), left_x, right_x), ground_y))

	while targets.size() < grenade_count:
		var x := randf_range(left_x, right_x)
		if targets.is_empty() or abs(x - targets[0].x) > 180.0:
			targets.append(Vector2(x, ground_y))

	return targets


func take_damage(amount: int = 1) -> void:
	if state == BossState.DEAD:
		return

	hp -= amount
	debug_print("Boss HP: %s/%s" % [hp, max_hp])
	flash_hit()
	spawn_death_fx(false)

	if hp <= 0:
		die()


func die() -> void:
	if state == BossState.DEAD:
		return

	set_state(BossState.DEAD)
	travel(&"death")
	boss_defeated.emit()
	hurtbox.monitoring = false
	hurtbox_shape.disabled = true
	contact_damage_area.monitoring = false
	contact_damage_shape.disabled = true
	stomp_damage_area.monitoring = false
	stomp_damage_shape.disabled = true
	velocity = Vector2.ZERO
	spawn_death_fx(true)

	await get_tree().create_timer(0.8).timeout
	queue_free()


func can_attack() -> bool:
	if state == BossState.DEAD:
		return false
	if not is_instance_valid(player):
		return false
	if player.get("is_dead") == true:
		return false
	return true


func refresh_player() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D


func face_player() -> void:
	if not is_instance_valid(player):
		return

	var should_face_right := player.global_position.x > global_position.x

	if sprite_faces_right_by_default:
		animated_sprite.flip_h = not should_face_right
	else:
		animated_sprite.flip_h = should_face_right

	var marker_x_sign := 1.0 if should_face_right else -1.0
	muzzle_marker.position.x = abs(muzzle_marker.position.x) * marker_x_sign
	grenade_throw_marker.position.x = abs(grenade_throw_marker.position.x) * marker_x_sign


func travel(animation_name: StringName) -> void:
	var frames := animated_sprite.sprite_frames
	var fallback := &"shoot" if animation_name == &"throw" else &"idle"

	if frames != null and frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
	elif frames != null and frames.has_animation(fallback):
		animated_sprite.play(fallback)



func set_state(new_state: BossState) -> void:
	state = new_state
	debug_print("Boss state: " + BossState.keys()[state])


func flash_hit() -> void:
	if animated_sprite.material == null:
		return

	var mat := animated_sprite.material as ShaderMaterial
	if mat == null:
		return

	mat.set_shader_parameter("flash_amount", 1.0)
	var tween := create_tween()
	tween.tween_method(_set_flash_amount, 1.0, 0.0, 0.08)


func _set_flash_amount(value: float) -> void:
	if animated_sprite.material == null:
		return

	var mat := animated_sprite.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("flash_amount", value)


func spawn_death_fx(is_death: bool) -> void:
	if not is_death:
		return

	var fx = BLOOD_BURST_SCENE.instantiate()
	fx.global_position = global_position
	get_tree().current_scene.add_child(fx)


func get_marker_x(path: NodePath, fallback: float) -> float:
	var marker := get_node_or_null(path) as Node2D
	return marker.global_position.x if marker != null else fallback


func _on_contact_damage_body_entered(body: Node) -> void:
	if state == BossState.DEAD or not body.is_in_group("player"):
		return

	current_contact_targets.append(body)
	if body.has_method("take_damage"):
		body.take_damage(contact_damage)
	elif body.has_method("die"):
		body.die()


func _on_contact_damage_body_exited(body: Node) -> void:
	current_contact_targets.erase(body)


func _on_stomp_damage_body_entered(body: Node) -> void:
	_damage_with_stomp(body)


func _damage_with_stomp(body: Node) -> void:
	if not body.is_in_group("player") or damaged_by_current_stomp.has(body):
		return

	damaged_by_current_stomp.append(body)
	if body.has_method("take_damage"):
		body.take_damage(stomp_damage)
	elif body.has_method("die"):
		body.die()


func debug_print(message: String) -> void:
	if debug_enabled:
		print(message)
