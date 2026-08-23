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

@export_group("Underwater Damage Vignette")
@export var underwater_vignette_color: Color = Color(0.04, 0.3, 1.0, 0.48)
@export_range(1, 12, 1) var underwater_vignette_pulse_count: int = 3
@export_range(0.05, 3.0, 0.05) var underwater_vignette_pulse_duration: float = 0.45

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
@onready var damage_vignette: ColorRect = $ScreenEffects/DamageVignette
@onready var stealth_prompt: Control = $StealthPrompt
@onready var stealth_prompt_label: Label = $StealthPrompt/PromptLabel

var bound_player: Node = null
var last_hp: int = -1
var checkpoint_tween: Tween = null
var damage_vignette_tween: Tween = null
var default_damage_vignette_color: Color = Color(0.9, 0.0, 0.0, 0.35)


func _ready() -> void:
	head_icon.texture = player_head_texture
	ammo_icon.texture = ammo_icon_texture
	ammo_ui.visible = false
	message_ui.visible = false
	speedrun_timer_ui.visible = false
	stealth_prompt.visible = false
	damage_vignette.visible = true
	damage_vignette.modulate.a = 0.0
	default_damage_vignette_color = damage_vignette.color
	_apply_checkpoint_text_style()


func bind_player(player: Node) -> void:
	if bound_player != null and bound_player.has_signal("health_changed"):
		var health_callable := Callable(self, "_on_player_health_changed")
		if bound_player.is_connected("health_changed", health_callable):
			bound_player.disconnect("health_changed", health_callable)
	if bound_player != null and bound_player.has_signal("damage_taken"):
		var damage_callable := Callable(self, "_on_player_damage_taken")
		if bound_player.is_connected("damage_taken", damage_callable):
			bound_player.disconnect("damage_taken", damage_callable)
	if bound_player != null and bound_player.has_signal("ammo_changed"):
		var ammo_callable := Callable(self, "_on_player_ammo_changed")
		if bound_player.is_connected("ammo_changed", ammo_callable):
			bound_player.disconnect("ammo_changed", ammo_callable)
	if bound_player != null and bound_player.has_signal("stealth_availability_changed"):
		var availability_callable := Callable(self, "_on_stealth_availability_changed")
		if bound_player.is_connected("stealth_availability_changed", availability_callable):
			bound_player.disconnect("stealth_availability_changed", availability_callable)
	if bound_player != null and bound_player.has_signal("stealth_changed"):
		var stealth_callable := Callable(self, "_on_stealth_changed")
		if bound_player.is_connected("stealth_changed", stealth_callable):
			bound_player.disconnect("stealth_changed", stealth_callable)

	bound_player = player

	if bound_player == null:
		stealth_prompt.visible = false
		return

	if bound_player.has_signal("health_changed"):
		var new_health_callable := Callable(self, "_on_player_health_changed")
		if not bound_player.is_connected("health_changed", new_health_callable):
			bound_player.connect("health_changed", new_health_callable)
	if bound_player.has_signal("damage_taken"):
		var new_damage_callable := Callable(self, "_on_player_damage_taken")
		if not bound_player.is_connected("damage_taken", new_damage_callable):
			bound_player.connect("damage_taken", new_damage_callable)
	if bound_player.has_signal("ammo_changed"):
		var new_ammo_callable := Callable(self, "_on_player_ammo_changed")
		if not bound_player.is_connected("ammo_changed", new_ammo_callable):
			bound_player.connect("ammo_changed", new_ammo_callable)
	if bound_player.has_signal("stealth_availability_changed"):
		var new_availability_callable := Callable(self, "_on_stealth_availability_changed")
		if not bound_player.is_connected("stealth_availability_changed", new_availability_callable):
			bound_player.connect("stealth_availability_changed", new_availability_callable)
	if bound_player.has_signal("stealth_changed"):
		var new_stealth_callable := Callable(self, "_on_stealth_changed")
		if not bound_player.is_connected("stealth_changed", new_stealth_callable):
			bound_player.connect("stealth_changed", new_stealth_callable)

	var current_hp := int(bound_player.get("current_hp"))
	var max_hp := int(bound_player.get("max_hp"))
	update_health(current_hp, max_hp)

	var current_ammo = bound_player.get("current_ammo")
	var max_ammo = bound_player.get("max_ammo")
	if current_ammo != null and max_ammo != null:
		update_ammo(int(current_ammo), int(max_ammo))
	else:
		ammo_ui.visible = false

	refresh_stealth_prompt()


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
	_prepare_damage_vignette(default_damage_vignette_color)

	damage_vignette_tween = create_tween()
	damage_vignette_tween.tween_property(damage_vignette, "modulate:a", 0.45, damage_vignette_time * 0.35)
	damage_vignette_tween.tween_property(damage_vignette, "modulate:a", 0.0, damage_vignette_time * 0.65)
	damage_vignette_tween.tween_callback(_finish_damage_vignette)


func pulse_underwater_damage_vignette() -> void:
	_prepare_damage_vignette(underwater_vignette_color)

	var half_pulse_duration := maxf(underwater_vignette_pulse_duration, 0.05) * 0.5
	damage_vignette_tween = create_tween()
	for _pulse_index in maxi(underwater_vignette_pulse_count, 1):
		damage_vignette_tween.tween_property(damage_vignette, "modulate:a", 1.0, half_pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		damage_vignette_tween.tween_property(damage_vignette, "modulate:a", 0.0, half_pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	damage_vignette_tween.tween_callback(_finish_damage_vignette)


func _prepare_damage_vignette(color: Color) -> void:
	if damage_vignette_tween != null and damage_vignette_tween.is_valid():
		damage_vignette_tween.kill()

	damage_vignette_tween = null
	damage_vignette.color = color
	damage_vignette.modulate.a = 0.0


func _finish_damage_vignette() -> void:
	damage_vignette.modulate.a = 0.0
	damage_vignette.color = default_damage_vignette_color
	damage_vignette_tween = null


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
	# Compatibility fallback for player-like test doubles and older controllers
	# that do not expose the source-aware damage signal.
	if last_hp >= 0 and current_hp < last_hp and (bound_player == null or not bound_player.has_signal("damage_taken")):
		flash_damage_vignette()

	update_health(current_hp, max_hp)


func _on_player_damage_taken(_amount: int, _source_category: StringName, underwater: bool) -> void:
	if underwater:
		pulse_underwater_damage_vignette()
	else:
		flash_damage_vignette()


func _on_player_ammo_changed(current_ammo: int, max_ammo: int) -> void:
	update_ammo(current_ammo, max_ammo)


func _on_stealth_availability_changed(_available: bool) -> void:
	refresh_stealth_prompt()


func _on_stealth_changed(_active: bool) -> void:
	refresh_stealth_prompt()


func refresh_stealth_prompt() -> void:
	if bound_player == null or not is_instance_valid(bound_player):
		stealth_prompt.visible = false
		return

	var available := false
	var active := false
	if bound_player.has_method("is_stealth_available"):
		available = bool(bound_player.call("is_stealth_available"))
	if bound_player.has_method("is_stealth_active"):
		active = bool(bound_player.call("is_stealth_active"))

	stealth_prompt.visible = available
	stealth_prompt_label.text = "Q / RB: LEAVE STEALTH" if active else "Q / RB: ENTER STEALTH"


func _create_heart_rect() -> TextureRect:
	var heart := TextureRect.new()
	heart.custom_minimum_size = Vector2(28, 28)
	heart.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return heart
