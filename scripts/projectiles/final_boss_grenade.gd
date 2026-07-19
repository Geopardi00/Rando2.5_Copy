extends CharacterBody2D

signal exploded
signal finished

@export var damage: int = 1
@export var gravity: float = 950.0
@export var fuse_time: float = 2.1
@export var warning_duration: float = 0.7
@export var max_bounces: int = 2
@export var bounce_damping: float = 0.55
@export var bounce_min_speed: float = 85.0
@export var explosion_radius: float = 92.0
@export var explosion_active_duration: float = 0.12
@export var cleanup_delay: float = 0.65
@export var debug_draw_damage_radius: bool = true
@export var debug_damage_fill_color: Color = Color(1.0, 0.05, 0.0, 0.18)
@export var debug_damage_outline_color: Color = Color(1.0, 0.95, 0.15, 0.9)

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var explosion_area: Area2D = $ExplosionArea
@onready var explosion_shape: CollisionShape2D = $ExplosionArea/CollisionShape2D
@onready var explosion_sprite: AnimatedSprite2D = $ExplosionSprite
@onready var explosion_sound: AudioStreamPlayer2D = get_node_or_null("ExplosionSound") as AudioStreamPlayer2D

var fuse_timer: float = 0.0
var explosion_timer: float = 0.0
var cleanup_timer: float = 0.0
var bounce_count: int = 0
var has_exploded: bool = false
var damaged_bodies: Array[Node] = []
var boss_owner: Node = null


func _ready() -> void:
	fuse_timer = fuse_time
	explosion_timer = 0.0
	cleanup_timer = cleanup_delay
	explosion_area.monitoring = false
	explosion_shape.disabled = true
	explosion_sprite.visible = false
	explosion_sprite.stop()
	explosion_area.body_entered.connect(_on_explosion_area_body_entered)

	var circle_shape := explosion_shape.shape as CircleShape2D
	if circle_shape != null:
		circle_shape.radius = explosion_radius


func setup(start_position: Vector2, initial_velocity: Vector2, new_damage: int = 1, new_owner: Node = null) -> void:
	global_position = start_position
	velocity = initial_velocity
	damage = new_damage
	boss_owner = new_owner


func _physics_process(delta: float) -> void:
	if has_exploded:
		update_explosion(delta)
		queue_redraw()
		return

	fuse_timer -= delta
	velocity.y += gravity * delta
	sprite.rotation += velocity.x * delta * 0.03

	var collision := move_and_collide(velocity * delta)
	if collision != null:
		bounce_count += 1
		velocity = velocity.bounce(collision.get_normal()) * bounce_damping
		if bounce_count > max_bounces or velocity.length() <= bounce_min_speed:
			explode()
			return

	update_warning_flash()
	queue_redraw()

	if fuse_timer <= 0.0:
		explode()


func update_warning_flash() -> void:
	if fuse_timer > warning_duration:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return

	var warning_progress := 1.0 - clampf(fuse_timer / warning_duration, 0.0, 1.0)
	var flash_speed := lerpf(10.0, 32.0, warning_progress)
	var flash := 0.5 + sin(Time.get_ticks_msec() * 0.001 * flash_speed) * 0.5
	sprite.modulate = Color(1.0, lerpf(0.25, 1.0, flash), lerpf(0.25, 1.0, flash), 1.0)


func explode() -> void:
	if has_exploded:
		return

	has_exploded = true
	velocity = Vector2.ZERO
	sprite.visible = false
	collision_shape.disabled = true
	explosion_area.monitoring = true
	explosion_shape.disabled = false
	explosion_sprite.visible = true
	explosion_sprite.play("explode")
	if explosion_sound != null:
		explosion_sound.play()

	queue_redraw()
	exploded.emit()
	damage_overlapping_bodies()


func update_explosion(delta: float) -> void:
	if explosion_timer < explosion_active_duration:
		explosion_timer += delta
		damage_overlapping_bodies()
		if explosion_timer >= explosion_active_duration:
			explosion_area.monitoring = false
			explosion_shape.disabled = true

	cleanup_timer -= delta
	if cleanup_timer <= 0.0:
		finished.emit()
		queue_free()


func _draw() -> void:
	if not debug_draw_damage_radius or not should_draw_damage_radius():
		return

	draw_circle(Vector2.ZERO, explosion_radius, debug_damage_fill_color)
	draw_arc(Vector2.ZERO, explosion_radius, 0.0, TAU, 72, debug_damage_outline_color, 3.0, true)


func should_draw_damage_radius() -> bool:
	return has_exploded or fuse_timer <= warning_duration


func damage_overlapping_bodies() -> void:
	for body in explosion_area.get_overlapping_bodies():
		damage_body(body)


func damage_body(body: Node) -> void:
	if not body.is_in_group("player") or damaged_bodies.has(body):
		return

	damaged_bodies.append(body)
	if body.has_method("take_damage"):
		body.take_damage(damage)
	elif body.has_method("die"):
		body.die()


func _on_explosion_area_body_entered(body: Node) -> void:
	if has_exploded:
		damage_body(body)
