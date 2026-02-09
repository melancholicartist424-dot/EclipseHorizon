extends CharacterBody2D

@export var move_speed_feet: float = 12.0
@export var sprint_multiplier: float = 1.5

@onready var interaction_area: Area2D = $InteractionArea

var facing := Vector2.RIGHT
var _map_stack: Node
var _last_cell := Vector2i(-1, -1)
var _game: Node

func _physics_process(delta: float) -> void:
	if _map_stack == null:
		_map_stack = _get_map_stack()
	if _game == null:
		_game = _get_game()
	var direction := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if direction.length() > 1.0:
		direction = direction.normalized()
	if direction.length() > 0.01:
		facing = direction

	var speed_feet := move_speed_feet
	if _game and Input.is_key_pressed(KEY_SHIFT):
		if _game.can_sprint():
			speed_feet *= sprint_multiplier
			_game.consume_stamina(_game.sprint_stamina_cost_per_second * delta)
	if _map_stack:
		var cell := _map_stack.world_to_cell(global_position)
		if direction.length() > 0.01:
			_map_stack.set_velocity(cell, direction, speed_feet)
		else:
			_map_stack.set_velocity(cell, Vector2.ZERO, 0.0)
		velocity = _map_stack.get_velocity_world(cell)
	else:
		velocity = direction * speed_feet
	move_and_slide()
	_update_occupancy(direction)

	if Input.is_action_just_pressed("interact"):
		_try_interact()
	if Input.is_action_just_pressed("attack"):
		_try_attack()
	if Input.is_action_just_pressed("forage"):
		_try_forage()
	if Input.is_action_just_pressed("capture"):
		_try_capture(false)
	if Input.is_action_just_pressed("place_snare"):
		_try_capture(true)

func _try_interact() -> void:
	for area in interaction_area.get_overlapping_areas():
		if area.has_method("interact"):
			area.interact(self)
			return

func _try_attack() -> void:
	if _game and not _game.try_consume_attack_stamina():
		return
	for area in interaction_area.get_overlapping_areas():
		if area.has_method("take_hit"):
			area.take_hit(self)
			return

func _try_forage() -> void:
	if _game == null or _map_stack == null:
		return
	var cell := _map_stack.world_to_cell(global_position)
	_game.try_forage(cell)

func _try_capture(use_snare: bool) -> void:
	if _game == null:
		return
	for area in interaction_area.get_overlapping_areas():
		if area.has_method("apply_capture_attempt"):
			_game.try_capture(area, use_snare)
			return

func get_facing() -> Vector2:
	return facing

func _update_occupancy(direction: Vector2) -> void:
	if _map_stack == null:
		return
	var cell := _map_stack.world_to_cell(global_position)
	if cell != _last_cell:
		if _last_cell.x >= 0:
			_map_stack.clear_occupancy(_last_cell, get_instance_id())
			_map_stack.clear_velocity(_last_cell)
		_map_stack.set_occupancy(cell, get_instance_id(), 1)
		_last_cell = cell
	if direction.length() > 0.01:
		_map_stack.deposit_noise(cell, 20, 1)
		_map_stack.deposit_scent(cell, 5, 1)

func _get_map_stack() -> Node:
	var nodes := get_tree().get_nodes_in_group("map_stack")
	return nodes[0] if nodes.size() > 0 else null

func _get_game() -> Node:
	var nodes := get_tree().get_nodes_in_group("game")
	return nodes[0] if nodes.size() > 0 else null
