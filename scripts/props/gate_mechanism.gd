@tool
class_name GateMechanism
extends Node2D

signal lever_activated
signal opening_started
signal opened

@export_group("Gate Opening")
@export var opening_distance: float = 360.0
@export var opening_duration: float = 1.2
@export var opening_transition: Tween.TransitionType = Tween.TRANS_SINE
@export var opening_ease: Tween.EaseType = Tween.EASE_IN_OUT

@export_group("Lever Feedback")
@export var lever_active_angle_degrees: float = 45.0
@export var lever_animation_duration: float = 0.25

@onready var gate_assembly: Node2D = $GateAssembly
@onready var moving_gate: Node2D = $GateAssembly/MovingGate
@onready var gate_sprite: Sprite2D = $GateAssembly/MovingGate/Gate
@onready var gate_body: StaticBody2D = $GateAssembly/MovingGate/GateBody
@onready var gate_collision: CollisionShape2D = $GateAssembly/MovingGate/GateBody/CollisionShape2D
@onready var clip_line: Node2D = $GateAssembly/ClipLine
@onready var clip_guide: Line2D = $GateAssembly/ClipLine/EditorGuide
@onready var lever_visual_pivot: Node2D = $LeverVisualPivot
@onready var lever_hit_area: Area2D = $LeverHitArea
@onready var lever_hit_shape: CollisionShape2D = $LeverHitArea/CollisionShape2D

var activated: bool = false
var is_opening: bool = false
var is_open: bool = false
var open_progress: float = 0.0
var closed_gate_position: Vector2 = Vector2.ZERO
var closed_lever_rotation: float = 0.0
var gate_tween: Tween


func _ready() -> void:
	closed_gate_position = moving_gate.position
	closed_lever_rotation = lever_visual_pivot.rotation
	clip_guide.visible = Engine.is_editor_hint()

	if not Engine.is_editor_hint():
		var authored_material := gate_sprite.material as ShaderMaterial
		if authored_material != null:
			gate_sprite.material = authored_material.duplicate()

	_set_open_progress(0.0)
	if Engine.is_editor_hint():
		set_process(true)
	else:
		set_process(false)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_update_clip_cutoff()


func slapped() -> void:
	if Engine.is_editor_hint() or activated or is_opening or is_open:
		return
	open_gate()


func open_gate(immediate: bool = false) -> void:
	if Engine.is_editor_hint() or is_opening or is_open:
		return

	if not activated:
		activated = true
		lever_activated.emit()
	_disable_lever_interaction()
	is_opening = true
	opening_started.emit()

	var target_rotation := closed_lever_rotation + deg_to_rad(lever_active_angle_degrees)
	if immediate or opening_duration <= 0.0:
		lever_visual_pivot.rotation = target_rotation
		_set_open_progress(1.0)
		_finish_opening()
		return

	gate_tween = create_tween().set_parallel(true)
	gate_tween.tween_method(_set_open_progress, open_progress, 1.0, opening_duration).set_trans(opening_transition).set_ease(opening_ease)
	gate_tween.tween_property(lever_visual_pivot, "rotation", target_rotation, maxf(lever_animation_duration, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await gate_tween.finished
	_finish_opening()


func is_gate_open() -> bool:
	return is_open


func _set_open_progress(value: float) -> void:
	open_progress = clampf(value, 0.0, 1.0)
	moving_gate.position = closed_gate_position + Vector2.UP * opening_distance * open_progress
	_update_clip_cutoff()


func _update_clip_cutoff() -> void:
	if gate_sprite == null or gate_sprite.texture == null:
		return
	var shader_material := gate_sprite.material as ShaderMaterial
	if shader_material == null:
		return

	var texture_height := float(gate_sprite.texture.get_height())
	if texture_height <= 0.0:
		return
	var clip_y_in_gate := gate_sprite.to_local(clip_line.global_position).y
	var clip_uv_y := clampf(clip_y_in_gate / texture_height + 0.5, 0.0, 1.0)
	shader_material.set_shader_parameter(&"clip_uv_y", clip_uv_y)


func _disable_lever_interaction() -> void:
	lever_hit_area.collision_layer = 0
	lever_hit_area.monitorable = false
	lever_hit_shape.set_deferred("disabled", true)


func _finish_opening() -> void:
	if not is_opening:
		return
	is_opening = false
	is_open = true
	_set_open_progress(1.0)
	gate_body.collision_layer = 0
	gate_body.collision_mask = 0
	gate_collision.set_deferred("disabled", true)
	gate_sprite.visible = false
	opened.emit()
