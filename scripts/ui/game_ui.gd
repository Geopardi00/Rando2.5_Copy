extends CanvasLayer

@export var player_head_texture: Texture2D = preload("res://art/ui/ui_player_head.png")
@export var heart_full_texture: Texture2D = preload("res://art/ui/ui_heart_full.png")
@export var heart_empty_texture: Texture2D = preload("res://art/ui/ui_heart_empty.png")
@export var ammo_icon_texture: Texture2D = preload("res://art/props/magazine.png")

@export_group("Checkpoint Message")
@export var checkpoint_message_time: float = 1.4
@export var checkpoint_font: Font
@export var checkpoint_font_size: int = 32
@export var checkpoint_text_color: Color = Color.WHITE
@export var checkpoint_outline_size: int = 6
@export var checkpoint_outline_color: Color = Color.BLACK
@export var checkpoint_glow_enabled: bool = true
@export var checkpoint_glow_color: Color = Color(1.0, 0.58, 0.18, 0.55)
@export var checkpoint_glow_scale: float = 1.16
@export var checkpoint_particles_enabled: bool = true

@export_group("Screen Effects")
@export var damage_vignette_time: float = 0.25

@onready var head_icon: TextureRect = $HUD/HealthUI/HeadIcon
@onready var hearts_container: HBoxContainer = $HUD/HealthUI/HeartsContainer
@onready var speedrun_timer_ui: Control = $HUD/SpeedrunTimerUI
@onready var timer_label: Label = $HUD/SpeedrunTimerUI/TimerLabel
@onready var ammo_ui: Control = $AmmoUI
@onready var ammo_icon: TextureRect = $AmmoUI/AmmoIcon
@onready var ammo_label: Label = $AmmoUI/AmmoLabel
@onready var message_ui: Control = $MessageUI
@onready var checkpoint_text: Label = $MessageUI/CheckpointText
@onready var checkpoint_glow_text: Label = get_node_or_null("MessageUI/CheckpointGlowText") as Label
@onready var checkpoint_particles: CPUParticles2D = get_node_or_null("MessageUI/CheckpointParticles") as CPUParticles2D
@onready var damage_vignette: CanvasItem = $ScreenEffects/DamageVignette

var bound_player: Node = null
var last_hp: int = -1
var checkpoint_tween: Tween = null


func _ready() -> void:
	head_icon.texture = player_head_texture
	ammo_icon.texture = ammo_icon_texture
	ammo_ui.visible = false
	message_ui.visible = false
	speedrun_timer_ui.visible = false
	damage_vignette.visible = true
	damage_vignette.modulate.a = 0.0
	_apply_checkpoint_text_style()


func bind_player(player: Node) -> void:
	if bound_player != null and bound_player.has_signal("health_changed"):
		var health_callable := Callable(self, "_on_player_health_changed")
		if bound_player.is_connected("health_changed", health_callable):
			bound_player.disconnect("health_changed", health_callable)
	if bound_player != null and bound_player.has_signal("ammo_changed"):
		var ammo_callable := Callable(self, "_on_player_ammo_changed")
		if bound_player.is_connected("ammo_changed", ammo_callable):
			bound_player.disconnect("ammo_changed", ammo_callable)

	bound_player = player

	if bound_player == null:
		return

	if bound_player.has_signal("health_changed"):
		var new_health_callable := Callable(self, "_on_player_health_changed")
		if not bound_player.is_connected("health_changed", new_health_callable):
			bound_player.connect("health_changed", new_health_callable)
	if bound_player.has_signal("ammo_changed"):
		var new_ammo_callable := Callable(self, "_on_player_ammo_changed")
		if not bound_player.is_connected("ammo_changed", new_ammo_callable):
			bound_player.connect("ammo_changed", new_ammo_callable)

	var current_hp := int(bound_player.get("current_hp"))
	var max_hp := int(bound_player.get("max_hp"))
	update_health(current_hp, max_hp)

	var current_ammo = bound_player.get("current_ammo")
	var max_ammo = bound_player.get("max_ammo")
	if current_ammo != null and max_ammo != null:
		update_ammo(int(current_ammo), int(max_ammo))
	else:
		ammo_ui.visible = false


func update_health(current_hp: int, max_hp: int) -> void:
	rebuild_hearts(max_hp)

	var clamped_hp := clampi(current_hp, 0, max_hp)
	for i in hearts_container.get_child_count():
		var heart := hearts_container.get_child(i) as TextureRect
		if heart == null:
			continue

		heart.texture = heart_full_texture if i < clamped_hp else heart_empty_texture

	last_hp = clamped_hp


func rebuild_hearts(max_hp: int) -> void:
	var desired_count := max_hp if max_hp > 0 else 0

	while hearts_container.get_child_count() < desired_count:
		hearts_container.add_child(_create_heart_rect())

	while hearts_container.get_child_count() > desired_count:
		var heart := hearts_container.get_child(hearts_container.get_child_count() - 1)
		hearts_container.remove_child(heart)
		heart.queue_free()


func update_ammo(current_ammo: int, max_ammo: int) -> void:
	ammo_ui.visible = true
	ammo_label.text = "%d/%d" % [maxi(current_ammo, 0), maxi(max_ammo, 0)]


func show_checkpoint_message(text := "CHECKPOINT") -> void:
	if checkpoint_tween != null and checkpoint_tween.is_valid():
		checkpoint_tween.kill()

	checkpoint_text.text = text
	if checkpoint_glow_text != null:
		checkpoint_glow_text.text = text
		checkpoint_glow_text.visible = checkpoint_glow_enabled

	_apply_checkpoint_text_style()

	message_ui.visible = true
	message_ui.modulate.a = 0.0
	message_ui.scale = Vector2(0.86, 0.86)
	checkpoint_text.scale = Vector2.ONE

	if checkpoint_particles != null and checkpoint_particles_enabled:
		checkpoint_particles.restart()
		checkpoint_particles.emitting = true

	if checkpoint_glow_text != null:
		checkpoint_glow_text.scale = Vector2(checkpoint_glow_scale, checkpoint_glow_scale)

	checkpoint_tween = create_tween()
	checkpoint_tween.set_parallel(true)
	checkpoint_tween.tween_property(message_ui, "modulate:a", 1.0, 0.12)
	checkpoint_tween.tween_property(message_ui, "scale", Vector2(1.08, 1.08), 0.12)
	if checkpoint_glow_text != null and checkpoint_glow_enabled:
		checkpoint_tween.tween_property(checkpoint_glow_text, "modulate:a", checkpoint_glow_color.a, 0.12)

	checkpoint_tween.chain()
	checkpoint_tween.set_parallel(false)
	checkpoint_tween.tween_property(message_ui, "scale", Vector2.ONE, 0.12)
	checkpoint_tween.tween_interval(checkpoint_message_time)
	checkpoint_tween.tween_property(message_ui, "modulate:a", 0.0, 0.25)
	checkpoint_tween.tween_callback(_hide_checkpoint_message)


func _hide_checkpoint_message() -> void:
	message_ui.visible = false
	if checkpoint_particles != null:
		checkpoint_particles.emitting = false


func flash_damage_vignette() -> void:
	damage_vignette.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(damage_vignette, "modulate:a", 0.45, damage_vignette_time * 0.35)
	tween.tween_property(damage_vignette, "modulate:a", 0.0, damage_vignette_time * 0.65)


func set_timer_visible(enabled: bool) -> void:
	speedrun_timer_ui.visible = enabled


func set_timer_text(text: String) -> void:
	timer_label.text = text


func _apply_checkpoint_text_style() -> void:
	_apply_checkpoint_label_style(checkpoint_text, checkpoint_text_color)
	_apply_checkpoint_label_style(checkpoint_glow_text, checkpoint_glow_color)


func _apply_checkpoint_label_style(label: Label, color: Color) -> void:
	if label == null:
		return

	if checkpoint_font != null:
		label.add_theme_font_override("font", checkpoint_font)

	label.add_theme_font_size_override("font_size", checkpoint_font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", checkpoint_outline_size)
	label.add_theme_color_override("font_outline_color", checkpoint_outline_color)
	label.modulate.a = color.a


func _on_player_health_changed(current_hp: int, max_hp: int) -> void:
	if last_hp >= 0 and current_hp < last_hp:
		flash_damage_vignette()

	update_health(current_hp, max_hp)


func _on_player_ammo_changed(current_ammo: int, max_ammo: int) -> void:
	update_ammo(current_ammo, max_ammo)


func _create_heart_rect() -> TextureRect:
	var heart := TextureRect.new()
	heart.custom_minimum_size = Vector2(28, 28)
	heart.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return heart
