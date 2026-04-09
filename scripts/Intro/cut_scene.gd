extends Control

@export var slides: Array[Texture2D]
@export var slide_durations: Array[float] = []
@export var fade_time: float = 0.35
@export_file("*.tscn") var next_scene_path: String = ""

@onready var image: TextureRect = $SlideHolder/TextureRect
@onready var fade: ColorRect = $ColorRect
@onready var voice: AudioStreamPlayer = $Voice
@onready var skip_label: Label = $SkipLabel

var current_index: int = 0
var is_skipping: bool = false
var fade_tween: Tween


func _ready() -> void:
	if slides.is_empty():
		push_warning("No slides assigned.")
		return

	if slide_durations.size() != slides.size():
		push_warning("slide_durations size must match slides size.")
		return

	fade.color = Color.BLACK
	fade.modulate.a = 1.0

	if is_instance_valid(skip_label):
		skip_label.modulate.a = 0.0
		fade_in_skip_label()

	show_slide(0)
	voice.play()
	play_cutscene()


func show_slide(index: int) -> void:
	if index < 0 or index >= slides.size():
		return

	current_index = index
	image.texture = slides[index]


func play_cutscene() -> void:
	while current_index < slides.size() and not is_skipping:
		await fade_in()

		if is_skipping:
			return

		await get_tree().create_timer(slide_durations[current_index]).timeout

		if is_skipping:
			return

		await fade_out()

		if is_skipping:
			return

		current_index += 1

		if current_index < slides.size():
			show_slide(current_index)

	end_cutscene()


func fade_in() -> void:
	if fade_tween:
		fade_tween.kill()

	fade_tween = create_tween()
	fade_tween.tween_property(fade, "modulate:a", 0.0, fade_time)
	await fade_tween.finished


func fade_out() -> void:
	if fade_tween:
		fade_tween.kill()

	fade_tween = create_tween()
	fade_tween.tween_property(fade, "modulate:a", 1.0, fade_time)
	await fade_tween.finished


func fade_in_skip_label() -> void:
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(skip_label, "modulate:a", 0.75, 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		skip_cutscene()
	elif event is InputEventMouseButton and event.pressed:
		skip_cutscene()
	elif event is InputEventJoypadButton and event.pressed:
		skip_cutscene()


func skip_cutscene() -> void:
	if is_skipping:
		return

	is_skipping = true

	if fade_tween:
		fade_tween.kill()

	if voice.playing:
		voice.stop()

	end_cutscene()


func end_cutscene() -> void:
	if next_scene_path != "":
		get_tree().change_scene_to_file(next_scene_path)
	else:
		queue_free()
