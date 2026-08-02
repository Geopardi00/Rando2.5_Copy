extends Node

@export var follow_target_group: StringName = &"player"
@export var camera_priority: int = 10
@export var follow_offset: Vector2 = Vector2(52.0, -137.0)

@export_group("Landing Shake")
@export var landing_shake_enabled: bool = true
@export_range(0.0, 20.0, 0.1) var landing_shake_amplitude: float = 4.0
@export_range(0.0, 30.0, 0.1) var landing_shake_frequency: float = 8.0
@export_range(0.001, 1.0, 0.001, "suffix:s") var landing_shake_duration: float = 0.04
@export_range(0.001, 1.0, 0.001, "suffix:s") var landing_shake_decay: float = 0.12
@export_range(0.0, 1.0, 0.01) var landing_shake_horizontal_strength: float = 0.35
@export_range(0.0, 1.0, 0.01) var landing_shake_vertical_strength: float = 1.0

@onready var phantom_camera_2d: Node2D = $PhantomCamera2D
@onready var landing_shake_emitter: Node2D = $LandingShakeEmitter


func _ready() -> void:
	_configure_landing_shake()
	_bind_follow_target.call_deferred()


func _bind_follow_target() -> void:
	var target := get_tree().get_first_node_in_group(follow_target_group) as Node2D
	if target == null:
		await get_tree().process_frame
		target = get_tree().get_first_node_in_group(follow_target_group) as Node2D

	if target == null:
		push_warning("CameraRig could not find a Node2D in group '%s'." % follow_target_group)
		return

	phantom_camera_2d.set("follow_target", target)
	phantom_camera_2d.set("follow_offset", follow_offset)
	phantom_camera_2d.set("priority", camera_priority)
	var hard_landed_callback := Callable(self, "_on_follow_target_hard_landed")
	if target.has_signal(&"hard_landed") and not target.is_connected(&"hard_landed", hard_landed_callback):
		target.connect(&"hard_landed", hard_landed_callback)
	if phantom_camera_2d.has_method("teleport_position"):
		phantom_camera_2d.call("teleport_position")


func _configure_landing_shake() -> void:
	landing_shake_emitter.set("continuous", false)
	landing_shake_emitter.set("growth_time", 0.001)
	landing_shake_emitter.set("duration", landing_shake_duration)
	landing_shake_emitter.set("decay_time", landing_shake_decay)

	var noise := landing_shake_emitter.get("noise") as Resource
	if noise == null:
		push_warning("CameraRig landing shake emitter has no noise resource.")
		return

	noise.set("amplitude", landing_shake_amplitude)
	noise.set("frequency", landing_shake_frequency)
	noise.set("positional_noise", true)
	noise.set("rotational_noise", false)
	noise.set("positional_multiplier_x", landing_shake_horizontal_strength)
	noise.set("positional_multiplier_y", landing_shake_vertical_strength)


func _on_follow_target_hard_landed() -> void:
	if landing_shake_enabled and landing_shake_emitter.has_method("emit"):
		landing_shake_emitter.call("emit")
