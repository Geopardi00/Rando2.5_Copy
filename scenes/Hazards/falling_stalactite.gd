extends Node2D

@export var fall_speed: float = 420.0
@export var trigger_delay: float = 0.35
@export var destroy_on_ground_hit: bool = true

@onready var hitbox: Area2D = $Hitbox
@onready var ground_check: RayCast2D = $GroundCheck
@onready var sprite: Sprite2D = $Sprite2D

var is_triggered: bool = false
var is_falling: bool = false


func _ready() -> void:
	# Only dangerous while falling
	hitbox.monitoring = false
	hitbox.body_entered.connect(_on_hitbox_body_entered)


func _process(delta: float) -> void:
	if not is_falling:
		return

	global_position.y += fall_speed * delta

	if ground_check.is_colliding():
		on_ground_hit()


func trigger_fall() -> void:
	if is_triggered or is_falling:
		return

	is_triggered = true
	_start_warning_and_fall()


func _start_warning_and_fall() -> void:
	# Tiny wobble warning
	var start_x: float = sprite.position.x

	var tween := create_tween()
	tween.tween_property(sprite, "position:x", start_x - 2.0, 0.04)
	tween.tween_property(sprite, "position:x", start_x + 2.0, 0.04)
	tween.tween_property(sprite, "position:x", start_x, 0.04)

	await get_tree().create_timer(trigger_delay).timeout

	is_falling = true
	hitbox.monitoring = true


func _on_hitbox_body_entered(body: Node) -> void:
	if not is_falling:
		return

	if body.is_in_group("player") and body.has_method("die"):
		body.die()


func on_ground_hit() -> void:
	is_falling = false
	hitbox.monitoring = false

	if destroy_on_ground_hit:
		queue_free()
