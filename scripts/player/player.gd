extends CharacterBody2D

@export var move_speed: float = 220.0
@export var jump_velocity: float = -420.0
@export var gravity: float = 1100.0

@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.10

@export var bullet_scene: PackedScene
@export var fire_rate: float = 0.2
@export var bullet_offset: Vector2 = Vector2(16, -4)

@onready var fire_timer: Timer = $FireRateTimer

@onready var sprite: Sprite2D = $Sprite2D

var facing: int = 1
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0


func _ready():
	fire_timer.wait_time = fire_rate
	fire_timer.one_shot = true


func _physics_process(delta: float) -> void:
	var input_axis = Input.get_axis("move_left", "move_right")

	# Facing + flip
	if input_axis > 0:
		facing = 1
	elif input_axis < 0:
		facing = -1

	sprite.flip_h = facing < 0

	# Horizontal
	if input_axis != 0:
		velocity.x = input_axis * move_speed
	else:
		velocity.x = 0

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	# Coyote
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta

	# Jump buffer
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	# Jump
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0
		coyote_timer = 0

	# Shooting
	if Input.is_action_just_pressed("shoot"):
		try_shoot()

	move_and_slide()


func try_shoot():
	if bullet_scene == null:
		return

	if not fire_timer.is_stopped():
		return

	fire_timer.start()
	fire_bullet()


func fire_bullet():
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	var spawn_pos = global_position + Vector2(bullet_offset.x * facing, bullet_offset.y)

	bullet.global_position = spawn_pos
	bullet.direction = facing
