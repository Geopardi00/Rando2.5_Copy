extends Control

@export_file("*.tscn") var start_scene_path: String = "res://scenes/levels/level_01.tscn"

@onready var start_button: TextureButton = $CenterContainer/VBoxContainer/StartButton
@onready var options_button: TextureButton = $CenterContainer/VBoxContainer/OptionsButton
@onready var exit_button: TextureButton = $CenterContainer/VBoxContainer/ExitButton
@onready var options_panel: PanelContainer = $OptionsPanel
@onready var close_button: TextureButton = $OptionsPanel/VBoxContainer/CloseButton

@onready var click_sound: AudioStreamPlayer2D = $ClickSound
@onready var menu_music: AudioStreamPlayer = $MainMenuMusic

@onready var background: TextureRect = $Background
@onready var darken: ColorRect = $Darken

var button_tweens: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.offset_left = 0
	background.offset_top = 0
	background.offset_right = 0
	background.offset_bottom = 0

	darken.set_anchors_preset(Control.PRESET_FULL_RECT)
	darken.offset_left = 0
	darken.offset_top = 0
	darken.offset_right = 0
	darken.offset_bottom = 0

	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	
	options_panel.visible = false

	if not menu_music.playing:
		menu_music.play()

	await get_tree().process_frame

	prepare_button(start_button)
	prepare_button(options_button)
	prepare_button(exit_button)

	connect_hover(start_button)
	connect_hover(options_button)
	connect_hover(exit_button)

	start_button.pressed.connect(_on_start_pressed)
	options_button.pressed.connect(_on_options_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	close_button.pressed.connect(_on_close_options_pressed)


func prepare_button(button: TextureButton) -> void:
	button.pivot_offset = button.size * 0.5


func connect_hover(button: TextureButton) -> void:
	button.mouse_entered.connect(func() -> void:
		tween_button_scale(button, Vector2(1.04, 1.04), 0.08)
	)

	button.mouse_exited.connect(func() -> void:
		tween_button_scale(button, Vector2.ONE, 0.08)
	)


func tween_button_scale(button: Control, target_scale: Vector2, duration: float) -> void:
	if button_tweens.has(button) and is_instance_valid(button_tweens[button]):
		button_tweens[button].kill()

	var tween := create_tween()
	button_tweens[button] = tween
	tween.tween_property(button, "scale", target_scale, duration)


func animate_button_press(button: TextureButton) -> void:
	if button_tweens.has(button) and is_instance_valid(button_tweens[button]):
		button_tweens[button].kill()

	var tween := create_tween()
	button_tweens[button] = tween
	tween.tween_property(button, "scale", Vector2(0.96, 0.96), 0.05)
	tween.tween_property(button, "scale", Vector2.ONE, 0.08)


func _on_start_pressed() -> void:
	click_sound.play()
	animate_button_press(start_button)
	await get_tree().create_timer(0.10).timeout
	get_tree().change_scene_to_file(start_scene_path)


func _on_options_pressed() -> void:
	click_sound.play()
	animate_button_press(options_button)
	await get_tree().create_timer(0.08).timeout
	options_panel.visible = true


func _on_exit_pressed() -> void:
	click_sound.play()
	animate_button_press(exit_button)
	await get_tree().create_timer(0.10).timeout
	get_tree().quit()


func _on_close_options_pressed() -> void:
	animate_button_press(close_button)
	await get_tree().create_timer(0.08).timeout
	options_panel.visible = false
