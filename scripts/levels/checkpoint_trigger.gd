extends Area2D

@export var checkpoint_spawn_path: NodePath = NodePath("Spawnpoint")
@export var checkpoint_sprite_path: NodePath = NodePath("../Flag")
@export var checkpoint_light_path: NodePath = NodePath("../Glow")
@export var checkpoint_light_fade_time: float = 0.35
@export var checkpoint_light_flicker_amount: float = 0.08
@export var checkpoint_light_flicker_speed: float = 18.0
@export var level_id_override: String = ""

@onready var checkpoint_spawn: Marker2D = get_node_or_null(checkpoint_spawn_path) as Marker2D
@onready var checkpoint_sprite: AnimatedSprite2D = get_node_or_null(checkpoint_sprite_path) as AnimatedSprite2D
@onready var checkpoint_light: PointLight2D = get_node_or_null(checkpoint_light_path) as PointLight2D

var activated: bool = false
var checkpoint_light_target_energy: float = 0.5
var checkpoint_light_base_energy: float = 0.0
var checkpoint_light_flicker_time: float = 0.0


func _process(delta: float) -> void:
	update_checkpoint_light_flicker(delta)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	setup_checkpoint_light()
	play_checkpoint_idle()


func _on_body_entered(body: Node) -> void:
	if activated:
		return

	if not body.is_in_group("player"):
		return

	var state := get_node_or_null("/root/StateOfGame")
	if state == null or not state.has_method("activate_checkpoint"):
		return

	activated = true
	state.activate_checkpoint(_get_level_id(), _get_checkpoint_position())
	activate_checkpoint_flag()
	show_checkpoint_message()
	print("checkpoint reached")


func _get_level_id() -> String:
	if level_id_override != "":
		return level_id_override

	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.scene_file_path != "":
		return current_scene.scene_file_path.get_file().get_basename()

	if owner != null and owner.scene_file_path != "":
		return owner.scene_file_path.get_file().get_basename()

	return ""


func _get_checkpoint_position() -> Vector2:
	if checkpoint_spawn != null:
		return checkpoint_spawn.global_position

	return global_position


func show_checkpoint_message() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var game_ui := current_scene.get_node_or_null("GameUI")
	if game_ui != null and game_ui.has_method("show_checkpoint_message"):
		game_ui.call("show_checkpoint_message")


func play_checkpoint_idle() -> void:
	if not _checkpoint_has_animation(&"idle"):
		return

	checkpoint_sprite.play(&"idle")


func activate_checkpoint_flag() -> void:
	if checkpoint_sprite == null:
		return

	if _checkpoint_has_animation(&"ignition"):
		checkpoint_sprite.play(&"ignition")
		fade_checkpoint_light()
		await checkpoint_sprite.animation_finished
	else:
		fade_checkpoint_light()

	if is_instance_valid(checkpoint_sprite) and _checkpoint_has_animation(&"burn"):
		checkpoint_sprite.play(&"burn")


func _checkpoint_has_animation(animation_name: StringName) -> bool:
	if checkpoint_sprite == null or checkpoint_sprite.sprite_frames == null:
		return false

	return checkpoint_sprite.sprite_frames.has_animation(animation_name)


func setup_checkpoint_light() -> void:
	if checkpoint_light == null:
		return

	checkpoint_light_target_energy = checkpoint_light.energy
	checkpoint_light.enabled = true
	checkpoint_light.energy = 0.0
	checkpoint_light_base_energy = 0.0


func fade_checkpoint_light() -> void:
	if checkpoint_light == null:
		return

	var tween := create_tween()
	tween.tween_method(_set_checkpoint_light_base_energy, checkpoint_light_base_energy, checkpoint_light_target_energy, checkpoint_light_fade_time)


func _set_checkpoint_light_base_energy(value: float) -> void:
	checkpoint_light_base_energy = value
	apply_checkpoint_light_energy()


func update_checkpoint_light_flicker(delta: float) -> void:
	if checkpoint_light == null or not activated:
		return

	checkpoint_light_flicker_time += delta
	apply_checkpoint_light_energy()


func apply_checkpoint_light_energy() -> void:
	if checkpoint_light == null:
		return

	var flicker_scale := clampf(checkpoint_light_base_energy / maxf(checkpoint_light_target_energy, 0.001), 0.0, 1.0)
	var flicker := sin(checkpoint_light_flicker_time * checkpoint_light_flicker_speed) * checkpoint_light_flicker_amount * flicker_scale
	flicker += sin(checkpoint_light_flicker_time * checkpoint_light_flicker_speed * 2.17) * checkpoint_light_flicker_amount * 0.35 * flicker_scale
	checkpoint_light.energy = maxf(checkpoint_light_base_energy + flicker, 0.0)
