extends CharacterBody2D

const BLOOD_BURST_SCENE := preload("res://scenes/fx/blood_burst.tscn")

enum State {
	PATROL,
	CHASE,
	BARK
}

@export var patrol_speed: float = 60.0
@export var chase_speed: float = 240.0
@export var gravity: float = 1000.0
@export var move_direction: int = -1

@export var aggro_range: float = 220.0
@export var lose_range: float = 320.0
@export var vertical_tolerance: float = 90.0
@export var chase_reacquire_delay: float = 1.1

@export var max_hp: int = 2
@export var contact_damage: int = 3

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var wall_check_left: RayCast2D = $WallCheckLeft
@onready var wall_check_right: RayCast2D = $WallCheckRight
@onready var floor_check_left: RayCast2D = $FloorCheckLeft
@onready var floor_check_right: RayCast2D = $FloorCheckRight
@onready var hit_sound: AudioStreamPlayer2D = $HitSound

var state: State = State.PATROL
var hp: int = 0
var player: Node2D = null
var chase_lock_timer: float = 0.0


func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp
	player = get_tree().get_first_node_in_group("player") as Node2D

	# Give this dog instance its own flash material.
	if animated_sprite.material != null:
		animated_sprite.material = animated_sprite.material.duplicate()
		_set_flash_amount(0.0)

	update_animation()


func _physics_process(delta: float) -> void:
	if chase_lock_timer > 0.0:
		chase_lock_timer -= delta

	apply_gravity(delta)
	refresh_player_reference()
	update_state()

	match state:
		State.PATROL:
			run_patrol()
		State.CHASE:
			run_chase()
		State.BARK:
			run_bark()

	move_and_slide()
	update_visual()
	update_animation()


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0


func refresh_player_reference() -> void:
	if is_player_targetable():
		return

	player = null
	for candidate in get_tree().get_nodes_in_group("player"):
		var candidate_player := candidate as Node2D
		if is_candidate_detectable(candidate_player):
			player = candidate_player
			return


func is_player_targetable() -> bool:
	return is_candidate_detectable(player)


func is_candidate_detectable(candidate: Node2D) -> bool:
	if not is_instance_valid(candidate) or bool(candidate.get("is_dead")):
		return false

	if candidate.has_method("is_detectable_by_enemies"):
		return bool(candidate.call("is_detectable_by_enemies"))

	return true


func update_state() -> void:
	if state == State.BARK:
		return

	if not is_player_targetable():
		state = State.PATROL
		return

	var dx: float = player.global_position.x - global_position.x
	var dy: float = abs(player.global_position.y - global_position.y)

	match state:
		State.PATROL:
			if chase_lock_timer <= 0.0 and abs(dx) <= aggro_range and dy <= vertical_tolerance:
				state = State.CHASE

		State.CHASE:
			if abs(dx) > lose_range or dy > vertical_tolerance:
				state = State.PATROL


func run_patrol() -> void:
	if should_turn_around():
		turn_around()

	velocity.x = move_direction * patrol_speed


func run_chase() -> void:
	if not is_player_targetable():
		state = State.PATROL
		velocity.x = move_direction * patrol_speed
		return

	var dx: float = player.global_position.x - global_position.x

	if dx < 0.0:
		move_direction = -1
	else:
		move_direction = 1

	if should_turn_around():
		state = State.PATROL
		chase_lock_timer = chase_reacquire_delay
		turn_around()
		velocity.x = move_direction * patrol_speed
		return

	velocity.x = move_direction * chase_speed


func run_bark() -> void:
	velocity.x = 0.0


func on_player_killed(victim: Node2D) -> void:
	var dx := victim.global_position.x - global_position.x
	if not is_zero_approx(dx):
		move_direction = 1 if dx > 0.0 else -1

	player = victim
	state = State.BARK
	velocity.x = 0.0
	update_visual()
	update_animation()


func should_turn_around() -> bool:
	if move_direction < 0:
		if wall_check_left.is_colliding():
			return true
		if not floor_check_left.is_colliding():
			return true

	if move_direction > 0:
		if wall_check_right.is_colliding():
			return true
		if not floor_check_right.is_colliding():
			return true

	return false


func turn_around() -> void:
	move_direction *= -1


func update_visual() -> void:
	# Assumes dog art faces LEFT by default.
	# If your art faces RIGHT by default, change this to:
	# animated_sprite.flip_h = move_direction < 0
	animated_sprite.flip_h = move_direction > 0


func update_animation() -> void:
	match state:
		State.CHASE:
			if animated_sprite.animation != &"charge":
				animated_sprite.play(&"charge")
		State.BARK:
			if animated_sprite.animation != &"bark":
				animated_sprite.play(&"bark")
		_:
			if animated_sprite.animation != &"walk":
				animated_sprite.play(&"walk")


func take_damage(amount: int = 1) -> void:
	hp -= amount
	flash_hit()
	spawn_hit_sound()

	if hp <= 0:
		die()


func flash_hit() -> void:
	if animated_sprite.material == null:
		return

	var mat: ShaderMaterial = animated_sprite.material as ShaderMaterial
	if mat == null:
		return

	mat.set_shader_parameter("flash_amount", 1.0)

	var tween := create_tween()
	tween.tween_method(_set_flash_amount, 1.0, 0.0, 0.08)


func _set_flash_amount(value: float) -> void:
	if animated_sprite.material == null:
		return

	var mat: ShaderMaterial = animated_sprite.material as ShaderMaterial
	if mat == null:
		return

	mat.set_shader_parameter("flash_amount", value)


func die() -> void:
	spawn_death_fx()

	var state_node: Node = _get_state_of_game()
	if state_node != null and state_node.has_method("register_enemy_defeated"):
		state_node.register_enemy_defeated()

	queue_free()


func spawn_hit_sound() -> void:
	if hit_sound == null:
		return

	if hit_sound.stream == null:
		return

	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = hit_sound.stream
	sfx.volume_db = hit_sound.volume_db
	sfx.pitch_scale = hit_sound.pitch_scale
	sfx.bus = hit_sound.bus
	sfx.global_position = global_position

	get_tree().current_scene.add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	sfx.play()


func spawn_death_fx() -> void:
	if BLOOD_BURST_SCENE == null:
		return

	var fx = BLOOD_BURST_SCENE.instantiate()
	fx.global_position = global_position
	get_tree().current_scene.add_child(fx)


func _get_state_of_game() -> Node:
	return get_node_or_null("/root/StateOfGame")
