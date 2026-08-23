extends Node2D

@export var damage: int = 1
@export var travel_time: float = 2
@export var arc_height: float = 260.0
@export var explosion_radius: float = 92.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var explosion_area: Area2D = $ExplosionArea
@onready var explosion_shape: CollisionShape2D = $ExplosionArea/CollisionShape2D
@onready var explosion_sprite: AnimatedSprite2D = $ExplosionSprite


var start_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var exploded: bool = false
var warning: Node = null


func _ready() -> void:
	explosion_area.monitoring = false
	explosion_shape.disabled = true
	explosion_sprite.visible = false
	explosion_sprite.stop()
	var circle_shape := explosion_shape.shape as CircleShape2D
	if circle_shape != null:
		circle_shape.radius = explosion_radius


func setup(start_pos: Vector2, target_pos: Vector2, new_damage: int = 1, warning_node: Node = null) -> void:
	start_position = start_pos
	target_position = target_pos
	damage = new_damage
	warning = warning_node
	global_position = start_position


func _physics_process(delta: float) -> void:
	if exploded:
		return

	elapsed += delta
	var t: float = clamp(elapsed / travel_time, 0.0, 1.0)
	var pos := start_position.lerp(target_position, t)
	pos.y -= sin(t * PI) * arc_height
	global_position = pos

	if t >= 1.0:
		explode()


func explode() -> void:
	if exploded:
		return

	exploded = true
	sprite.visible = false
	explosion_sprite.visible = true
	explosion_sprite.play("explode")

	if is_instance_valid(warning):
		warning.queue_free()

	explosion_area.monitoring = true
	explosion_shape.disabled = false

	await get_tree().physics_frame
	for body in explosion_area.get_overlapping_bodies():
		_damage_body(body)

	await explosion_sprite.animation_finished
	queue_free()


func _damage_body(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	if body.has_method("take_damage"):
		body.take_damage(damage, false, &"enemy")
	elif body.has_method("die"):
		body.die()
