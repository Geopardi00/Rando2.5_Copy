extends AudioStreamPlayer2D

func _ready() -> void:
	bus = &"Sound Effects"
	finished.connect(queue_free)
	play()
