extends Node2D

@export var grid_size := Vector2i(40, 22)
@export var tile_size := 32

@onready var map_stack: Node = $MapStack

var _tiles: Array[int] = []

func _ready() -> void:
	if map_stack:
		grid_size = map_stack.grid_size
		tile_size = map_stack.tile_size_world
	_generate_tiles()
	queue_redraw()

func _process(delta: float) -> void:
	if map_stack:
		map_stack.step_simulation(delta)
	queue_redraw()

func _generate_tiles() -> void:
	_tiles.clear()
	_tiles.resize(grid_size.x * grid_size.y)
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var tile := 0
			if map_stack:
				tile = map_stack.get_material(Vector2i(x, y))
			_tiles[y * grid_size.x + x] = tile

func _draw() -> void:
	var colors := [
		Color(0.08, 0.08, 0.12),
		Color(0.12, 0.11, 0.18),
		Color(0.18, 0.14, 0.24),
	]
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var index := y * grid_size.x + x
			var tile := _tiles[index]
			var heat_color := 0.0
			if map_stack:
				var heat := map_stack.get_heat(Vector2i(x, y))
				heat_color = clamp((heat.x - map_stack.ambient_temperature) / 120.0, -0.5, 0.5)
			var base_color := colors[tile]
			base_color = base_color.lightened(max(0.0, heat_color))
			base_color = base_color.darkened(max(0.0, -heat_color))
			var rect := Rect2(Vector2(x * tile_size, y * tile_size), Vector2(tile_size, tile_size))
			draw_rect(rect, base_color)
