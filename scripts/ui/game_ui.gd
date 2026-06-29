extends CanvasLayer

@export var player_head_texture: Texture2D = preload("res://art/ui/ui_player_head.png")
@export var heart_full_texture: Texture2D = preload("res://art/ui/ui_heart_full.png")
@export var heart_empty_texture: Texture2D = preload("res://art/ui/ui_heart_empty.png")
@export var checkpoint_message_time: float = 1.4
@export var damage_vignette_time: float = 0.25

@onready var head_icon: TextureRect = $HUD/HealthUI/HeadIcon
@onready var hearts_container: HBoxContainer = $HUD/HealthUI/HeartsContainer
@onready var speedrun_timer_ui: Control = $HUD/SpeedrunTimerUI
@onready var timer_label: Label = $HUD/SpeedrunTimerUI/TimerLabel
@onready var message_ui: Control = $MessageUI
@onready var checkpoint_text: Label = $MessageUI/CheckpointText
@onready var damage_vignette: CanvasItem = $ScreenEffects/DamageVignette

var bound_player: Node = null
var last_hp: int = -1


func _ready() -> void:
	head_icon.texture = player_head_texture
	message_ui.visible = false
	speedrun_timer_ui.visible = false
	damage_vignette.visible = true
	damage_vignette.modulate.a = 0.0


func bind_player(player: Node) -> void:
	if bound_player != null and bound_player.has_signal("health_changed"):
		var callable := Callable(self, "_on_player_health_changed")
		if bound_player.is_connected("health_changed", callable):
			bound_player.disconnect("health_changed", callable)

	bound_player = player

	if bound_player == null:
		return

	if bound_player.has_signal("health_changed"):
		var callable := Callable(self, "_on_player_health_changed")
		if not bound_player.is_connected("health_changed", callable):
			bound_player.connect("health_changed", callable)

	var current_hp := int(bound_player.get("current_hp"))
	var max_hp := int(bound_player.get("max_hp"))
	update_health(current_hp, max_hp)


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


func show_checkpoint_message(text := "CHECKPOINT") -> void:
	checkpoint_text.text = text
	message_ui.visible = true
	message_ui.modulate.a = 1.0

	var tween := create_tween()
	tween.tween_interval(checkpoint_message_time)
	tween.tween_property(message_ui, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void: message_ui.visible = false)


func flash_damage_vignette() -> void:
	damage_vignette.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(damage_vignette, "modulate:a", 0.45, damage_vignette_time * 0.35)
	tween.tween_property(damage_vignette, "modulate:a", 0.0, damage_vignette_time * 0.65)


func set_timer_visible(enabled: bool) -> void:
	speedrun_timer_ui.visible = enabled


func set_timer_text(text: String) -> void:
	timer_label.text = text


func _on_player_health_changed(current_hp: int, max_hp: int) -> void:
	if last_hp >= 0 and current_hp < last_hp:
		flash_damage_vignette()

	update_health(current_hp, max_hp)


func _create_heart_rect() -> TextureRect:
	var heart := TextureRect.new()
	heart.custom_minimum_size = Vector2(28, 28)
	heart.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return heart
