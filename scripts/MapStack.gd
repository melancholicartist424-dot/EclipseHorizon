extends Node

@export var grid_size := Vector2i(40, 22)
@export var ambient_temperature := 110
@export var ambient_wetness := 20
@export var temperature_drift_rate := 12.0
@export var phase_count := 4
@export var phase_interval := 0.5
@export var cell_area_sqft := 5.0
@export var tile_size_world := 32.0
@export var max_speed_feet := 18.0

var tile_material: PackedByteArray = PackedByteArray()
var tile_flags: PackedByteArray = PackedByteArray()
var tile_cost: PackedByteArray = PackedByteArray()
var tile_height: PackedByteArray = PackedByteArray()

var occ_id: PackedInt32Array = PackedInt32Array()
var occ_type: PackedInt32Array = PackedInt32Array()
var init_phase: PackedByteArray = PackedByteArray()

var heat_temp: PackedByteArray = PackedByteArray()
var heat_wet: PackedByteArray = PackedByteArray()
var heat_age: PackedByteArray = PackedByteArray()
var cold_strength: PackedByteArray = PackedByteArray()

var noise_intensity: PackedByteArray = PackedByteArray()
var noise_type: PackedByteArray = PackedByteArray()
var noise_age: PackedByteArray = PackedByteArray()

var scent_strength: PackedByteArray = PackedByteArray()
var scent_type: PackedByteArray = PackedByteArray()
var scent_age: PackedByteArray = PackedByteArray()

var blood_strength: PackedByteArray = PackedByteArray()
var blood_type: PackedByteArray = PackedByteArray()
var blood_age: PackedByteArray = PackedByteArray()
var blood_tag: PackedByteArray = PackedByteArray()

var vis_block: PackedByteArray = PackedByteArray()

var flow_vx: PackedByteArray = PackedByteArray()
var flow_vy: PackedByteArray = PackedByteArray()
var flow_mag: PackedByteArray = PackedByteArray()

var vel_vx: PackedByteArray = PackedByteArray()
var vel_vy: PackedByteArray = PackedByteArray()
var vel_speed: PackedByteArray = PackedByteArray()

var friction_drag: PackedByteArray = PackedByteArray()
var friction_slip: PackedByteArray = PackedByteArray()
var friction_tax: PackedByteArray = PackedByteArray()

var current_phase := 0
var _phase_timer := 0.0
var _spawn_cell := Vector2i.ZERO
var _deep_cell := Vector2i.ZERO

func _ready() -> void:
	add_to_group("map_stack")
	_initialize_maps()
	_generate_terrain()

func _initialize_maps() -> void:
	var size := grid_size.x * grid_size.y
	tile_material.resize(size)
	tile_flags.resize(size)
	tile_cost.resize(size)
	tile_height.resize(size)
	occ_id.resize(size)
	occ_type.resize(size)
	init_phase.resize(size)
	heat_temp.resize(size)
	heat_wet.resize(size)
	heat_age.resize(size)
	cold_strength.resize(size)
	noise_intensity.resize(size)
	noise_type.resize(size)
	noise_age.resize(size)
	scent_strength.resize(size)
	scent_type.resize(size)
	scent_age.resize(size)
	blood_strength.resize(size)
	blood_type.resize(size)
	blood_age.resize(size)
	blood_tag.resize(size)
	vis_block.resize(size)
	flow_vx.resize(size)
	flow_vy.resize(size)
	flow_mag.resize(size)
	vel_vx.resize(size)
	vel_vy.resize(size)
	vel_speed.resize(size)
	friction_drag.resize(size)
	friction_slip.resize(size)
	friction_tax.resize(size)
	for i in range(size):
		tile_material[i] = 0
		tile_flags[i] = 0
		tile_cost[i] = 1
		tile_height[i] = 0
		occ_id[i] = 0
		occ_type[i] = 0
		init_phase[i] = 0
		heat_temp[i] = ambient_temperature
		heat_wet[i] = ambient_wetness
		heat_age[i] = 0
		cold_strength[i] = 0
		noise_intensity[i] = 0
		noise_type[i] = 0
		noise_age[i] = 255
		scent_strength[i] = 0
		scent_type[i] = 0
		scent_age[i] = 255
		blood_strength[i] = 0
		blood_type[i] = 0
		blood_age[i] = 255
		blood_tag[i] = 0
		vis_block[i] = 0
		flow_vx[i] = 128
		flow_vy[i] = 128
		flow_mag[i] = 0
		vel_vx[i] = 128
		vel_vy[i] = 128
		vel_speed[i] = 0
		friction_drag[i] = 0
		friction_slip[i] = 0
		friction_tax[i] = 0

func _generate_terrain() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var cold_wet_width := int(grid_size.x * 0.3)
	var cold_wet_height := int(grid_size.y * 0.3)
	_spawn_cell = Vector2i(2, int(grid_size.y * 0.5))
	_deep_cell = Vector2i(grid_size.x - 4, int(grid_size.y * 0.5))
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var index := _index(x, y)
			var roll := rng.randf()
			if roll < 0.08:
				tile_material[index] = 2
				tile_height[index] = 3
				tile_cost[index] = 4
				vis_block[index] = 220
			elif roll < 0.3:
				tile_material[index] = 1
				tile_height[index] = 1
				tile_cost[index] = 2
				vis_block[index] = 80
			else:
				tile_material[index] = 0
				tile_height[index] = 0
				tile_cost[index] = 1
				vis_block[index] = 0
			friction_drag[index] = min(255, tile_cost[index] * 20)
			friction_slip[index] = 10 if tile_material[index] == 2 else 2
			friction_tax[index] = min(255, tile_cost[index] * 12)
			init_phase[index] = int(rng.randi_range(0, max(0, phase_count - 1)))
			if roll > 0.92:
				heat_wet[index] = min(255, ambient_wetness + 80)
			if roll < 0.15:
				heat_temp[index] = min(255, ambient_temperature + 40)
			if x < cold_wet_width and y < cold_wet_height:
				heat_wet[index] = min(255, ambient_wetness + 140)
				heat_temp[index] = max(0, ambient_temperature - 40)
				cold_strength[index] = min(255, 180)
	_carve_room(_spawn_cell, Vector2i(4, 3))
	_carve_room(_deep_cell, Vector2i(4, 3))
	_carve_corridor(_spawn_cell, _deep_cell)
	_apply_safe_room_warmth(_spawn_cell, Vector2i(4, 3))

func _carve_room(center: Vector2i, half_extents: Vector2i) -> void:
	for y in range(center.y - half_extents.y, center.y + half_extents.y + 1):
		for x in range(center.x - half_extents.x, center.x + half_extents.x + 1):
			if _in_bounds(x, y):
				var index := _index(x, y)
				tile_material[index] = 0
				tile_cost[index] = 1
				tile_height[index] = 0
				vis_block[index] = 0

func _carve_corridor(start: Vector2i, end: Vector2i) -> void:
	var x := start.x
	var y := start.y
	while x != end.x:
		_set_floor_cell(Vector2i(x, y))
		x += 1 if end.x > x else -1
	while y != end.y:
		_set_floor_cell(Vector2i(x, y))
		y += 1 if end.y > y else -1
	_set_floor_cell(end)

func _set_floor_cell(cell: Vector2i) -> void:
	if not _in_bounds(cell.x, cell.y):
		return
	var index := _index(cell.x, cell.y)
	tile_material[index] = 0
	tile_cost[index] = 1
	tile_height[index] = 0
	vis_block[index] = 0

func _apply_safe_room_warmth(center: Vector2i, half_extents: Vector2i) -> void:
	for y in range(center.y - half_extents.y, center.y + half_extents.y + 1):
		for x in range(center.x - half_extents.x, center.x + half_extents.x + 1):
			if _in_bounds(x, y):
				var index := _index(x, y)
				heat_temp[index] = min(255, ambient_temperature + 25)
				heat_wet[index] = max(0, ambient_wetness - 10)
				cold_strength[index] = 0

func step_simulation(delta: float) -> void:
	_step_phase(delta)
	_step_intent(delta)
	_step_resolve(delta)
	_step_deposit(delta)
	_step_evolve(delta)
	_step_cleanup(delta)

func _step_phase(delta: float) -> void:
	_phase_timer += delta
	if _phase_timer >= phase_interval:
		_phase_timer = 0.0
		current_phase = (current_phase + 1) % max(1, phase_count)

func _step_environment(delta: float) -> void:
	var size := grid_size.x * grid_size.y
	for i in range(size):
		heat_temp[i] = _drift_toward(heat_temp[i], ambient_temperature, delta)
		heat_wet[i] = _drift_toward(heat_wet[i], ambient_wetness, delta)
		heat_age[i] = min(255, heat_age[i] + 1)
		cold_strength[i] = _fade_value(cold_strength[i], delta * 0.5)
		noise_intensity[i] = _fade_value(noise_intensity[i], delta)
		noise_age[i] = min(255, noise_age[i] + 1)
		scent_strength[i] = _fade_value(scent_strength[i], delta * 0.5)
		scent_age[i] = min(255, scent_age[i] + 1)
		blood_strength[i] = _fade_value(blood_strength[i], delta * 0.25)
		blood_age[i] = min(255, blood_age[i] + 1)

func _step_intent(_delta: float) -> void:
	pass

func _step_resolve(_delta: float) -> void:
	pass

func _step_deposit(_delta: float) -> void:
	pass

func _step_evolve(delta: float) -> void:
	_step_environment(delta)
	_diffuse_field(noise_intensity, 0.12)
	_diffuse_field(scent_strength, 0.08)
	_diffuse_field(blood_strength, 0.05)
	_advect_field(noise_intensity, 0.1)
	_advect_field(scent_strength, 0.1)
	_advect_field(blood_strength, 0.05)

func _step_cleanup(_delta: float) -> void:
	pass

func _diffuse_field(field: PackedByteArray, rate: float) -> void:
	var size := grid_size.x * grid_size.y
	var copy := field.duplicate()
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var index := _index(x, y)
			var total := int(copy[index])
			var count := 1
			var neighbors := [
				Vector2i(1, 0),
				Vector2i(-1, 0),
				Vector2i(0, 1),
				Vector2i(0, -1),
			]
			for n in neighbors:
				var nx := x + n.x
				var ny := y + n.y
				if _in_bounds(nx, ny):
					total += int(copy[_index(nx, ny)])
					count += 1
			var average := int(total / max(1, count))
			var blended := int(lerp(float(copy[index]), float(average), rate))
			field[index] = clamp(blended, 0, 255)

func _advect_field(field: PackedByteArray, rate: float) -> void:
	var copy := field.duplicate()
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var index := _index(x, y)
			var flow_dir := Vector2(
				_unpack_vector_component(flow_vx[index]),
				_unpack_vector_component(flow_vy[index])
			).normalized()
			if flow_dir == Vector2.ZERO:
				continue
			var nx := x + int(sign(flow_dir.x))
			var ny := y + int(sign(flow_dir.y))
			if not _in_bounds(nx, ny):
				continue
			var neighbor_index := _index(nx, ny)
			var blended := int(lerp(float(copy[index]), float(copy[neighbor_index]), rate))
			field[index] = clamp(blended, 0, 255)

func deposit_heat(cell: Vector2i, temperature_delta: int, wetness_delta: int) -> void:
	if not _in_bounds(cell.x, cell.y):
		return
	var index := _index(cell.x, cell.y)
	heat_temp[index] = clamp(heat_temp[index] + temperature_delta, 0, 255)
	heat_wet[index] = clamp(heat_wet[index] + wetness_delta, 0, 255)
	heat_age[index] = 0

func deposit_cold(cell: Vector2i, strength_delta: int) -> void:
	if not _in_bounds(cell.x, cell.y):
		return
	var index := _index(cell.x, cell.y)
	cold_strength[index] = clamp(cold_strength[index] + strength_delta, 0, 255)

func deposit_noise(cell: Vector2i, intensity: int, noise_kind: int) -> void:
	if not _in_bounds(cell.x, cell.y):
		return
	var index := _index(cell.x, cell.y)
	noise_intensity[index] = clamp(noise_intensity[index] + intensity, 0, 255)
	noise_type[index] = noise_kind
	noise_age[index] = 0

func deposit_scent(cell: Vector2i, strength: int, scent_kind: int) -> void:
	if not _in_bounds(cell.x, cell.y):
		return
	var index := _index(cell.x, cell.y)
	scent_strength[index] = clamp(scent_strength[index] + strength, 0, 255)
	scent_type[index] = scent_kind
	scent_age[index] = 0

func deposit_blood(cell: Vector2i, strength: int, blood_kind: int, tag: int) -> void:
	if not _in_bounds(cell.x, cell.y):
		return
	var index := _index(cell.x, cell.y)
	blood_strength[index] = clamp(blood_strength[index] + strength, 0, 255)
	blood_type[index] = blood_kind
	blood_tag[index] = tag
	blood_age[index] = 0

func set_occupancy(cell: Vector2i, entity_id: int, entity_type: int) -> void:
	if not _in_bounds(cell.x, cell.y):
		return
	var index := _index(cell.x, cell.y)
	occ_id[index] = entity_id
	occ_type[index] = entity_type

func clear_occupancy(cell: Vector2i, entity_id: int) -> void:
	if not _in_bounds(cell.x, cell.y):
		return
	var index := _index(cell.x, cell.y)
	if occ_id[index] == entity_id:
		occ_id[index] = 0
		occ_type[index] = 0

func set_velocity(cell: Vector2i, direction: Vector2, speed_feet: float) -> void:
	if not _in_bounds(cell.x, cell.y):
		return
	var index := _index(cell.x, cell.y)
	var normalized := direction.normalized() if direction.length() > 0.001 else Vector2.ZERO
	vel_vx[index] = _pack_vector_component(normalized.x)
	vel_vy[index] = _pack_vector_component(normalized.y)
	vel_speed[index] = _pack_speed(speed_feet)

func clear_velocity(cell: Vector2i) -> void:
	if not _in_bounds(cell.x, cell.y):
		return
	var index := _index(cell.x, cell.y)
	vel_vx[index] = 128
	vel_vy[index] = 128
	vel_speed[index] = 0

func get_velocity_feet(cell: Vector2i) -> Vector2:
	if not _in_bounds(cell.x, cell.y):
		return Vector2.ZERO
	var index := _index(cell.x, cell.y)
	if vel_speed[index] == 0:
		return Vector2.ZERO
	var direction := Vector2(_unpack_vector_component(vel_vx[index]), _unpack_vector_component(vel_vy[index]))
	var speed := _unpack_speed(vel_speed[index])
	return direction.normalized() * speed

func get_velocity_world(cell: Vector2i) -> Vector2:
	var velocity_feet := get_velocity_feet(cell)
	if velocity_feet == Vector2.ZERO:
		return Vector2.ZERO
	var speed_world := feet_to_world_units(velocity_feet.length())
	return velocity_feet.normalized() * speed_world

func get_height(cell: Vector2i) -> int:
	if not _in_bounds(cell.x, cell.y):
		return 0
	return tile_height[_index(cell.x, cell.y)]

func get_material(cell: Vector2i) -> int:
	if not _in_bounds(cell.x, cell.y):
		return 0
	return tile_material[_index(cell.x, cell.y)]

func get_heat(cell: Vector2i) -> Vector2i:
	if not _in_bounds(cell.x, cell.y):
		return Vector2i(ambient_temperature, ambient_wetness)
	var index := _index(cell.x, cell.y)
	return Vector2i(heat_temp[index], heat_wet[index])

func get_cold(cell: Vector2i) -> int:
	if not _in_bounds(cell.x, cell.y):
		return 0
	return cold_strength[_index(cell.x, cell.y)]

func get_temperature(cell: Vector2i) -> int:
	if not _in_bounds(cell.x, cell.y):
		return ambient_temperature
	return heat_temp[_index(cell.x, cell.y)]

func _drift_toward(value: int, target: int, delta: float) -> int:
	var drift := temperature_drift_rate * delta
	if value < target:
		return min(target, int(value + drift))
	if value > target:
		return max(target, int(value - drift))
	return value

func _fade_value(value: int, delta: float) -> int:
	var decay := int(20.0 * delta)
	return max(0, value - decay)

func _pack_vector_component(value: float) -> int:
	return clamp(int((value + 1.0) * 127.5), 0, 255)

func _pack_speed(speed_feet: float) -> int:
	if max_speed_feet <= 0.0:
		return 0
	return clamp(int((speed_feet / max_speed_feet) * 255.0), 0, 255)

func _unpack_vector_component(value: int) -> float:
	return (float(value) / 127.5) - 1.0

func _unpack_speed(value: int) -> float:
	return (float(value) / 255.0) * max_speed_feet

func _index(x: int, y: int) -> int:
	return y * grid_size.x + x

func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < grid_size.x and y < grid_size.y

func cell_side_feet() -> float:
	return sqrt(cell_area_sqft)

func world_units_per_foot() -> float:
	return tile_size_world / max(0.01, cell_side_feet())

func feet_to_world_units(feet: float) -> float:
	return feet * world_units_per_foot()

func world_units_to_feet(units: float) -> float:
	return units / max(0.01, world_units_per_foot())

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / tile_size_world)), int(floor(world_pos.y / tile_size_world)))

func in_bounds(cell: Vector2i) -> bool:
	return _in_bounds(cell.x, cell.y)

func get_spawn_cell() -> Vector2i:
	return _spawn_cell

func get_deep_cell() -> Vector2i:
	return _deep_cell

func cell_center_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * tile_size_world, (cell.y + 0.5) * tile_size_world)
