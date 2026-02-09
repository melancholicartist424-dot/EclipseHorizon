extends Area2D

@export var mon_name := "Wisp"
@export var max_health := 3
@export var tame_threshold := 1
@export var wander_radius_feet := 6.0
@export var wander_speed_feet := 3.0
@export var flee_speed_feet := 8.0
@export var cold_tolerance := 90
@export var heat_tolerance := 200
@export var touch_damage := 1
@export var attack_interval := 1.1
@export var capture_resistance := 25
@export var mass := 1
@export var exhaustion_resistance := 1
@export var recovery := 1
@export var composure := 1
@export var drop_meat := 1
@export var drop_essence := 1

var health := 3
var tamed := false
var exhaustion_tier := 0
var fatigue_tier := 0
var hypothermia_tier := 0
var panic_tier := 0
var bleeding_tier := 0
var immobilize_tier := 0
var stagger_tier := 0
var infection_tier := 0
var rage_tier := 0
var _home_position := Vector2.ZERO
var _time := 0.0
var _map_stack: Node
var _last_cell := Vector2i(-1, -1)
var _last_position := Vector2.ZERO
var _attack_timer := 0.0
var _capture_resist_bonus := 0

func _ready() -> void:
	add_to_group("interactable")
	health = max_health
	_home_position = position
	_last_position = position
	_map_stack = _get_map_stack()
	_update_occupancy(Vector2.ZERO)

func _process(delta: float) -> void:
	if tamed:
		if _map_stack:
			var cell := _map_stack.world_to_cell(global_position)
			_map_stack.clear_velocity(cell)
		return
	_attack_timer = max(0.0, _attack_timer - delta)
	if _map_stack == null:
		_map_stack = _get_map_stack()
	var move_delta := Vector2.ZERO
	var cell := _map_stack.world_to_cell(global_position) if _map_stack else Vector2i.ZERO
	var temperature := _map_stack.get_temperature(cell) if _map_stack else 128
	var cold := _map_stack.get_cold(cell) if _map_stack else 0
	_update_hypothermia(temperature, cold, delta)
	if temperature < cold_tolerance or temperature > heat_tolerance:
		var seek_warmer := temperature < cold_tolerance
		var flee_direction := _find_temperature_flee_direction(cell, temperature, seek_warmer)
		if _map_stack:
			_map_stack.set_velocity(cell, flee_direction, _get_speed(flee_speed_feet))
	else:
		_time += delta
		var speed_scale := wander_speed_feet / max(0.01, wander_radius_feet)
		var direction := Vector2(
			cos(_time * speed_scale),
			sin(_time * speed_scale * 0.8)
		).normalized()
		if _map_stack:
			var radius_world := _map_stack.feet_to_world_units(wander_radius_feet)
			if _home_position.distance_to(global_position) > radius_world:
				direction = (_home_position - global_position).normalized()
			_map_stack.set_velocity(cell, direction, _get_speed(wander_speed_feet))
	if _map_stack:
		var velocity_world := _map_stack.get_velocity_world(cell)
		move_delta = velocity_world * delta
		position += move_delta
	_last_position = position
	_update_occupancy(move_delta)
	_update_statuses(delta)
	_attempt_attack()

func interact(_player: Node) -> void:
	if tamed:
		return
	if health <= tame_threshold:
		_tame()

func take_hit(_player: Node) -> void:
	if tamed:
		return
	health = max(0, health - 1)
	_add_exhaustion(1)
	_apply_status("bleeding", 1)
	_apply_status("stagger", 1)
	if health == 0:
		_harvest()

func _tame() -> void:
	tamed = true
	if _map_stack:
		var cell := _map_stack.world_to_cell(global_position)
		_map_stack.clear_velocity(cell)
	var game := _get_game()
	if game:
		game.add_tamed_mon(mon_name)

func _harvest() -> void:
	var game := _get_game()
	if game:
		game.add_resource("meat", drop_meat)
		game.add_resource("essence", drop_essence)
	_clear_occupancy()
	queue_free()

func _get_game() -> Node:
	var nodes := get_tree().get_nodes_in_group("game")
	return nodes[0] if nodes.size() > 0 else null

func _update_occupancy(move_delta: Vector2) -> void:
	if _map_stack == null:
		return
	var cell := _map_stack.world_to_cell(global_position)
	if cell != _last_cell:
		if _last_cell.x >= 0:
			_map_stack.clear_occupancy(_last_cell, get_instance_id())
			_map_stack.clear_velocity(_last_cell)
		_map_stack.set_occupancy(cell, get_instance_id(), 2)
		_last_cell = cell
	if move_delta.length() > 0.01:
		_map_stack.deposit_noise(cell, 12, 2)
		_map_stack.deposit_scent(cell, 8, 2)

func _clear_occupancy() -> void:
	if _map_stack == null:
		return
	if _last_cell.x >= 0:
		_map_stack.clear_occupancy(_last_cell, get_instance_id())
		_map_stack.clear_velocity(_last_cell)
		_last_cell = Vector2i(-1, -1)

func _get_map_stack() -> Node:
	var nodes := get_tree().get_nodes_in_group("map_stack")
	return nodes[0] if nodes.size() > 0 else null

func _attempt_attack() -> void:
	if _attack_timer > 0.0:
		return
	if touch_damage <= 0:
		return
	var game := _get_game()
	if game == null:
		return
	for body in get_overlapping_bodies():
		if body is CharacterBody2D:
			game.apply_damage(touch_damage)
			_attack_timer = attack_interval
			return

func apply_capture_attempt(item_power: int, success_bonus: int) -> bool:
	if tamed:
		return false
	var state_bonus := success_bonus
	state_bonus += exhaustion_tier * 5
	state_bonus += fatigue_tier * 6
	state_bonus += hypothermia_tier * 6
	state_bonus += panic_tier * 4
	state_bonus += bleeding_tier * 4
	state_bonus += immobilize_tier * 8
	state_bonus += stagger_tier * 6
	var target_resist := capture_resistance + _capture_resist_bonus + mass
	var roll := randi() % 100
	var chance := clamp(item_power + state_bonus - target_resist, 5, 95)
	if roll < chance:
		_tame()
		queue_free()
		return true
	return false

func add_capture_resistance(amount: int) -> void:
	_capture_resist_bonus = min(50, _capture_resist_bonus + amount)

func _add_exhaustion(amount: int) -> void:
	exhaustion_tier = clamp(exhaustion_tier + amount, 0, 4)
	fatigue_tier = clamp(fatigue_tier + 1, 0, 3)

func _update_hypothermia(temperature: int, cold: int, delta: float) -> void:
	if temperature < cold_tolerance and cold > 0:
		var gain := int(ceil(delta * 1.0))
		hypothermia_tier = clamp(hypothermia_tier + gain, 0, 3)
		if hypothermia_tier >= 2:
			_add_exhaustion(1)
	else:
		if hypothermia_tier > 0 and randi() % 100 < int(recovery * 5):
			hypothermia_tier = max(0, hypothermia_tier - 1)

func _apply_status(name: String, tier_delta: int) -> void:
	match name:
		"bleeding":
			bleeding_tier = clamp(bleeding_tier + tier_delta, 0, 3)
		"immobilize":
			immobilize_tier = clamp(immobilize_tier + tier_delta, 0, 3)
		"stagger":
			stagger_tier = clamp(stagger_tier + tier_delta, 0, 3)
		"infection":
			infection_tier = clamp(infection_tier + tier_delta, 0, 3)
		"panic":
			panic_tier = clamp(panic_tier + tier_delta, 0, 3)
		"rage":
			rage_tier = clamp(rage_tier + tier_delta, 0, 3)

func _update_statuses(delta: float) -> void:
	if bleeding_tier > 0 and randi() % 100 < 20:
		health = max(0, health - 1)
		if health == 0:
			_harvest()
			return
	if infection_tier > 0 and randi() % 100 < 10:
		_add_exhaustion(1)
	if panic_tier > 0 and randi() % 100 < int(composure * 5):
		panic_tier = max(0, panic_tier - 1)
	if stagger_tier > 0:
		stagger_tier = max(0, stagger_tier - int(ceil(delta)))

func _get_speed(base_speed: float) -> float:
	var speed := base_speed
	if fatigue_tier > 0:
		speed *= max(0.4, 1.0 - (0.15 * fatigue_tier))
	if hypothermia_tier > 0:
		speed *= max(0.3, 1.0 - (0.2 * hypothermia_tier))
	if immobilize_tier >= 2:
		speed *= 0.2
	return speed

func _find_temperature_flee_direction(cell: Vector2i, temperature: int, seek_warmer: bool) -> Vector2:
	if _map_stack == null:
		return Vector2.ZERO
	var best_cell := cell
	var best_temp := temperature
	var directions := [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]
	for dir in directions:
		var neighbor := cell + dir
		if _map_stack.in_bounds(neighbor):
			var neighbor_temp := _map_stack.get_temperature(neighbor)
			if seek_warmer:
				if neighbor_temp > best_temp:
					best_temp = neighbor_temp
					best_cell = neighbor
			else:
				if neighbor_temp < best_temp:
					best_temp = neighbor_temp
					best_cell = neighbor
	if best_cell == cell:
		return Vector2.ZERO
	return (Vector2(best_cell - cell)).normalized()
