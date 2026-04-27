extends Node2D

@export var camera_shake_time: float = 0.22
@export var camera_shake_strength: float = 12.0

@onready var camera: Camera2D = $Camera2D
@onready var boss: Node = $Boss

var shake_time_remaining: float = 0.0
var shake_strength: float = 0.0
var base_camera_offset: Vector2 = Vector2.ZERO
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	base_camera_offset = camera.offset

	if boss != null and boss.has_signal("stomp_landed"):
		boss.stomp_landed.connect(_on_boss_stomp_landed)


func _process(delta: float) -> void:
	update_camera_shake(delta)


func update_camera_shake(delta: float) -> void:
	if shake_time_remaining <= 0.0:
		camera.offset = base_camera_offset
		return

	shake_time_remaining -= delta
	var shake_ratio: float = max(shake_time_remaining / camera_shake_time, 0.0)
	camera.offset = base_camera_offset + Vector2(
		rng.randf_range(-shake_strength, shake_strength),
		rng.randf_range(-shake_strength, shake_strength)
	) * shake_ratio


func _on_boss_stomp_landed(_position: Vector2) -> void:
	shake_time_remaining = camera_shake_time
	shake_strength = camera_shake_strength
