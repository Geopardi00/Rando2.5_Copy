extends CharacterBody2D

const BLOOD_BURST_SCENE := preload("res://scenes/fx/blood_burst.tscn")
const GAMEPLAY_FREEZE := preload("res://scripts/gameplay_freeze.gd")

enum State {
	PATROL,
	CHARGE,
	ATTACH,
	ESCAPE
}

enum ChargeMode {
	LOCK_TARGET,
	LIMITED_HOMING,
	FULL_HOMING
}

@export var patrol_speed: float = 70.0
@export var patrol_distance: float = 120.0
@export var bob_height: float = 10.0
@export var bob_speed: float = 4.0
@export var detection_range: float = 180.0
@export var charge_mode: ChargeMode = ChargeMode.FULL_HOMING
@export var charge_speed: float = 310.0
@export var homing_strength: float = 9.0
@export var homing_duration: float = 0.15
@export var attach_duration: float = 0.12
@export var escape_duration: float = 0.95
@export var debug_draw: bool = false:
	set(value):
		debug_draw = value
		queue_redraw()

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var hit_sound: AudioStreamPlayer2D = $HitSound

var state: State = State.PATROL
var player: Node2D = null
var patrol_origin: Vector2 = Vector2.ZERO
var patrol_direction: int = 1
var bob_time: float = 0.0
var charge_target: Vector2 = Vector2.ZERO
var charge_direction: Vector2 = Vector2.RIGHT
var charge_time: float = 0.0
var charge_max_time: float = 1.4
var hit_player_this_charge: bool = false
var attach_timer: float = 0.0
var attach_offset: Vector2 = Vector2.ZERO
var escape_timer: float = 0.0
var escape_start: Vector2 = Vector2.ZERO
var escape_end: Vector2 = Vector2.ZERO
var escape_side: int = -1


func _ready() -> void:
	add_to_group("enemy")
	patrol_origin = global_position
	player = get_tree().get_first_node_in_group("player") as Node2D
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_area.monitoring = true
	play_animation(&"idle")


func _physics_process(delta: float) -> void:
	refresh_player_reference()
	bob_time += delta

	match state:
		State.PATROL:
			run_patrol(delta)
		State.CHARGE:
			run_charge(delta)
		State.ATTACH:
			run_attach(delta)
		State.ESCAPE:
			run_escape(delta)

	update_visual()
	if debug_draw:
		queue_redraw()


func refresh_player_reference() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D


func run_patrol(delta: float) -> void:
	play_animation(&"idle")
	hit_player_this_charge = false
	attack_area.monitoring = true

	global_position.x += patrol_direction * patrol_speed * delta
	var distance_from_origin := global_position.x - patrol_origin.x
	if abs(distance_from_origin) >= patrol_distance:
		patrol_direction *= -1
		global_position.x = patrol_origin.x + clamp(distance_from_origin, -patrol_distance, patrol_distance)

	global_position.y = patrol_origin.y + sin(bob_time * bob_speed) * bob_height

	if is_instance_valid(player) and global_position.distance_to(player.global_position) <= detection_range:
		start_charge()


func start_charge() -> void:
	state = State.CHARGE
	charge_time = 0.0
	hit_player_this_charge = false
	charge_target = get_player_target()
	charge_direction = (charge_target - global_position).normalized()
	if charge_direction == Vector2.ZERO:
		charge_direction = Vector2.RIGHT * patrol_direction
	play_animation(&"charge")


func run_charge(delta: float) -> void:
	charge_time += delta

	if charge_mode == ChargeMode.FULL_HOMING:
		steer_toward(get_player_target(), delta)
	elif charge_mode == ChargeMode.LIMITED_HOMING and charge_time <= homing_duration:
		steer_toward(get_player_target(), delta)
	elif charge_time <= delta:
		charge_target = get_player_target()

	velocity = charge_direction * charge_speed
	global_position += velocity * delta
	check_player_overlap()

	if should_escape_after_miss():
		start_escape()


func steer_toward(target: Vector2, delta: float) -> void:
	charge_target = target
	var desired := (target - global_position).normalized()
	if desired == Vector2.ZERO:
		return

	var weight: float = clamp(homing_strength * delta, 0.0, 1.0)
	charge_direction = charge_direction.lerp(desired, weight).normalized()


func should_escape_after_miss() -> bool:
	if charge_time >= charge_max_time:
		return true

	var to_target := charge_target - global_position
	if to_target.length() <= 10.0:
		return true

	return charge_direction.dot(to_target.normalized()) < -0.1


func run_attach(delta: float) -> void:
	attach_timer -= delta
	velocity = Vector2.ZERO

	if is_instance_valid(player):
		global_position = player.global_position + attach_offset

	if attach_timer <= 0.0:
		start_escape()


func start_escape() -> void:
	if state == State.ESCAPE:
		return

	state = State.ESCAPE
	attack_area.monitoring = false
	escape_timer = 0.0
	escape_start = global_position

	var away_from_player := -patrol_direction
	if is_instance_valid(player):
		away_from_player = -1 if player.global_position.x > global_position.x else 1

	escape_side = away_from_player
	escape_end = global_position + Vector2(escape_side * 120.0, -96.0)
	play_animation(&"idle")


func run_escape(delta: float) -> void:
	escape_timer += delta
	var t: float = clamp(escape_timer / escape_duration, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	var arc_lift: float = sin(t * PI) * 44.0

	global_position = escape_start.lerp(escape_end, eased) + Vector2(0.0, -arc_lift)

	if t >= 1.0:
		state = State.PATROL
		patrol_origin = global_position
		patrol_direction = -escape_side
		attack_area.monitoring = true


func get_player_target() -> Vector2:
	if is_instance_valid(player):
		return player.global_position + Vector2(0.0, 0.0)

	return charge_target


func update_visual() -> void:
	var facing_dir := patrol_direction
	if state == State.CHARGE and abs(charge_direction.x) > 0.01:
		facing_dir = 1 if charge_direction.x > 0.0 else -1
	elif state == State.ESCAPE:
		facing_dir = escape_side

	# Mosquito art faces left by default.
	animated_sprite.flip_h = facing_dir > 0


func play_animation(animation_name: StringName) -> void:
	if animated_sprite.sprite_frames == null:
		return

	if animated_sprite.sprite_frames.has_animation(animation_name) and animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)


func take_damage(_amount: int = 1) -> void:
	die()


func slapped() -> void:
	GAMEPLAY_FREEZE.freeze(0.05)
	die()


func die() -> void:
	spawn_death_fx()
	spawn_hit_sound()

	var state_node := get_node_or_null("/root/StateOfGame")
	if state_node != null and state_node.has_method("register_enemy_defeated"):
		state_node.register_enemy_defeated()

	queue_free()


func spawn_death_fx() -> void:
	var fx := BLOOD_BURST_SCENE.instantiate()
	fx.global_position = global_position
	get_tree().current_scene.add_child(fx)


func spawn_hit_sound() -> void:
	if hit_sound == null or hit_sound.stream == null:
		return

	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = hit_sound.stream
	sfx.volume_db = hit_sound.volume_db
	sfx.pitch_scale = hit_sound.pitch_scale
	sfx.global_position = global_position

	get_tree().current_scene.add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	sfx.play()


func check_player_overlap() -> void:
	for body in attack_area.get_overlapping_bodies():
		try_hit_player(body)


func _on_attack_area_body_entered(body: Node) -> void:
	try_hit_player(body)


func try_hit_player(body: Node) -> void:
	if state != State.CHARGE or hit_player_this_charge:
		return

	if not body.is_in_group("player") or not body.has_method("mosquito_attack"):
		return

	hit_player_this_charge = true
	body.mosquito_attack()
	GAMEPLAY_FREEZE.freeze(0.05)
	state = State.ATTACH
	attach_timer = attach_duration
	attach_offset = global_position - body.global_position
	velocity = Vector2.ZERO


func _draw() -> void:
	if not debug_draw:
		return

	var origin_local := to_local(patrol_origin)
	draw_line(
		origin_local + Vector2(-patrol_distance, 0.0),
		origin_local + Vector2(patrol_distance, 0.0),
		Color(0.2, 0.8, 1.0, 0.9),
		2.0
	)
	draw_circle(origin_local, detection_range, Color(1.0, 0.85, 0.2, 0.16))
	draw_arc(origin_local, detection_range, 0.0, TAU, 48, Color(1.0, 0.85, 0.2, 0.85), 1.0)

	if state == State.CHARGE:
		var target_local := to_local(charge_target)
		draw_line(target_local + Vector2(-7.0, 0.0), target_local + Vector2(7.0, 0.0), Color.RED, 2.0)
		draw_line(target_local + Vector2(0.0, -7.0), target_local + Vector2(0.0, 7.0), Color.RED, 2.0)
