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
@onready var gate_shake_emitter: Node2D = $GateShakeEmitter

var authored_zoom: Vector2 = Vector2.ONE
var gate_zoom_tween: Tween


func _ready() -> void:
	authored_zoom = phantom_camera_2d.get("zoom")
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


func play_gate_opening_effect(
	duration: float,
	shake_amplitude: float,
	shake_frequency: float,
	zoom_multiplier: float,
	zoom_in_duration: float,
	zoom_out_duration: float
) -> void:
	_configure_gate_shake(duration, shake_amplitude, shake_frequency)
	if shake_amplitude > 0.0 and gate_shake_emitter.has_method("emit"):
		gate_shake_emitter.call("emit")

	if gate_zoom_tween != null and gate_zoom_tween.is_valid():
		gate_zoom_tween.kill()
	phantom_camera_2d.set("zoom", authored_zoom)

	var zoom_in_time := maxf(zoom_in_duration, 0.01)
	var zoom_out_time := maxf(zoom_out_duration, 0.01)
	var hold_time := maxf(duration - zoom_in_time - zoom_out_time, 0.0)
	var target_zoom := authored_zoom * maxf(zoom_multiplier, 1.0)
	gate_zoom_tween = create_tween()
	gate_zoom_tween.tween_property(phantom_camera_2d, "zoom", target_zoom, zoom_in_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hold_time > 0.0:
		gate_zoom_tween.tween_interval(hold_time)
	gate_zoom_tween.tween_property(phantom_camera_2d, "zoom", authored_zoom, zoom_out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _configure_gate_shake(duration: float, amplitude: float, frequency: float) -> void:
	gate_shake_emitter.set("continuous", false)
	gate_shake_emitter.set("growth_time", 0.04)
	gate_shake_emitter.set("duration", maxf(duration - 0.2, 0.01))
	gate_shake_emitter.set("decay_time", minf(0.2, maxf(duration * 0.35, 0.01)))

	var noise := gate_shake_emitter.get("noise") as Resource
	if noise == null:
		push_warning("CameraRig gate shake emitter has no noise resource.")
		return
	noise.set("amplitude", maxf(amplitude, 0.0))
	noise.set("frequency", maxf(frequency, 0.0))
	noise.set("positional_noise", true)
	noise.set("rotational_noise", false)
	noise.set("positional_multiplier_x", 0.45)
	noise.set("positional_multiplier_y", 1.0)
