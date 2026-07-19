extends Node2D

@onready var boss: Node = $Boss2
@onready var boss_health_label: Label = $BossDebugUI/BossHealthLabel


func _ready() -> void:
	if boss != null:
		if boss.has_signal("health_changed"):
			boss.health_changed.connect(_on_boss_health_changed)
			_on_boss_health_changed(int(boss.get("hp")), int(boss.get("max_hp")))

		if boss.has_signal("boss_defeated"):
			boss.boss_defeated.connect(_on_boss_defeated)


func _on_boss_health_changed(current_hp: int, max_hp: int) -> void:
	boss_health_label.visible = true
	boss_health_label.text = "BOSS 2  %d/%d" % [current_hp, max_hp]


func _on_boss_defeated() -> void:
	boss_health_label.text = "BOSS 2 DEFEATED"
