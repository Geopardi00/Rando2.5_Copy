extends CharacterBody2D

@export var move_speed: float = 220.0
@export var jump_velocity: float = -400.0
@export var gravity: float = 1100.0

const PUSH_FORCE = 100
const BLOCK_MAX_VELOCITY = 180

@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.10

@export var enable_double_jump: bool = true
@export var extra_jumps: int = 1

@export var bullet_scene: PackedScene
@export var muzzle_flash_scene: PackedScene = preload("res://scenes/props/muzzle_flash.tscn")
@export var fire_rate: float = 0.2
@export var bullet_offset: Vector2 = Vector2(16, 12)
@export var muzzle_flash_offset: Vector2 = Vector2(18, 12)
@export var max_hp: int = 3
@export var invulnerability_time: float = 0.75
@export var debug_enabled: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var fire_timer: Timer = $FireRateTimer
@onready var hurtbox: Area2D = $Hurtbox
@onready var shoot_sound: AudioStreamPlayer2D = $ShootSound
@onready var muzzle_marker: Marker2D = $MuzzleMarker

var facing: int = 1
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var air_jumps_left: int = 0
var is_dead: bool = false
var current_hp: int = 0
var invulnerability_timer: float = 0.0
var blink_timer: float = 0.0


func _ready() -> void:
	add_to_group("player")
	current_hp = max_hp

	fire_timer.wait_time = fire_rate
	fire_timer.one_shot = true

	hurtbox.body_entered.connect(_on_hurtbox_body_entered)

	air_jumps_left = extra_jumps


func _physics_process(delta: float) -> void:
	update_invulnerability(delta)

	if is_dead:
		velocity.x = 0.0

		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			velocity.y = 0.0

		move_and_slide()
		update_animation()
		return

	var input_axis: float = Input.get_axis("move_left", "move_right")
	var jump_pressed: bool = Input.is_action_just_pressed("jump")

	# Facing
	if input_axis > 0.0:
		facing = 1
	elif input_axis < 0.0:
		facing = -1

	animated_sprite.flip_h = facing < 0

	# Horizontal movement
	if input_axis != 0.0:
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

	# Jump buffer
	if jump_pressed:
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	# Ground / coyote jump
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0

	# Double jump
	elif jump_pressed and enable_double_jump and not is_on_floor() and air_jumps_left > 0:
		velocity.y = jump_velocity
		air_jumps_left -= 1
		jump_buffer_timer = 0.0

	# Shooting
	if Input.is_action_just_pressed("shoot"):
		try_shoot()

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collision_crate = collision.get_collider()
		if collision_crate.is_in_group("Crate") and abs(collision_crate.linear_velocity.x) < BLOCK_MAX_VELOCITY:
			collision_crate.apply_central_impulse(collision.get_normal() * -PUSH_FORCE)


	move_and_slide()
	update_animation()


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
	if bullet_scene == null:
		return

	if not fire_timer.is_stopped():
		return

	fire_timer.start()
	fire_bullet()


func fire_bullet() -> void:
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	bullet.global_position = get_muzzle_global_position()
	bullet.direction = facing
	spawn_muzzle_flash()

	shoot_sound.play()

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


func take_damage(amount: int = 1) -> void:
	if is_dead or invulnerability_timer > 0.0:
		return

	current_hp -= amount

	if debug_enabled:
		print("Player damage received: ", amount, " HP: ", current_hp, "/", max_hp)

	if current_hp <= 0:
		die()
		return

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


func die() -> void:
	if is_dead:
		return

	is_dead = true
	current_hp = 0
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
