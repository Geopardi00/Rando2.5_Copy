extends Node

const SIMPLE_FOLLOW_MODE := 2

@export var follow_target_group: StringName = &"player"
@export var camera_priority: int = 10
@export var follow_offset: Vector2 = Vector2(52.0, -137.0)

@onready var phantom_camera_2d: Node2D = $PhantomCamera2D


func _ready() -> void:
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
	phantom_camera_2d.set("follow_mode", SIMPLE_FOLLOW_MODE)
	phantom_camera_2d.set("follow_offset", follow_offset)
	phantom_camera_2d.set("priority", camera_priority)
	if phantom_camera_2d.has_method("teleport_position"):
		phantom_camera_2d.call("teleport_position")
