extends Node2D

@export var map_stack_path: NodePath
@export var player_path: NodePath
@export var view_size := Vector2(520, 260)
@export var fov_degrees := 70.0
@export var max_distance_feet := 60.0
@export var column_count := 120
@export var wall_color := Color(0.6, 0.55, 0.7)
@export var floor_color := Color(0.1, 0.1, 0.14)
@export var ceiling_color := Color(0.04, 0.04, 0.06)

var _map_stack: Node
var _player: Node

func _ready() -> void:
	_map_stack = get_node_or_null(map_stack_path) if map_stack_path != NodePath() else null
	_player = get_node_or_null(player_path) if player_path != NodePath() else null
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	_draw_background()
	if not _map_stack or not _player:
		return
	var max_distance_cells := max_distance_feet / max(0.01, _map_stack.cell_side_feet())
	var origin := _player.global_position
	var facing := _player.get_facing() if _player.has_method("get_facing") else Vector2.RIGHT
	if facing.length() < 0.01:
		facing = Vector2.RIGHT
	var fov := deg_to_rad(fov_degrees)
	var step := fov / float(column_count)
	for column in range(column_count):
		var angle := -fov * 0.5 + step * column
		var direction := facing.rotated(angle).normalized()
		var hit := _cast_ray(origin, direction, max_distance_cells)
		_draw_column(column, hit, max_distance_cells)

func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, view_size), floor_color)
	draw_rect(Rect2(Vector2.ZERO, Vector2(view_size.x, view_size.y * 0.5)), ceiling_color)

func _cast_ray(origin: Vector2, direction: Vector2, max_distance_cells: float) -> Dictionary:
	var tile_size := _map_stack.tile_size_world
	var map_origin := origin / tile_size
	var pos := Vector2(map_origin.x, map_origin.y)
	var distance := 0.0
	var hit_height := 0
	while distance < max_distance_cells:
		var cell := Vector2i(floor(pos.x), floor(pos.y))
		hit_height = _map_stack.get_height(cell)
		if hit_height > 0:
			break
		pos += direction * 0.25
		distance += 0.25
	return {
		"distance": max(0.1, distance),
		"height": hit_height,
	}

func _draw_column(column: int, hit: Dictionary, max_distance_cells: float) -> void:
	var distance := float(hit["distance"])
	var height := int(hit["height"])
	var normalized := clamp(1.0 - (distance / max_distance_cells), 0.0, 1.0)
	var wall_height := view_size.y * normalized * (0.35 + 0.2 * height)
	var column_width := view_size.x / float(column_count)
	var x := column * column_width
	var y := (view_size.y * 0.5) - (wall_height * 0.5)
	var shade := clamp(0.4 + normalized * 0.6, 0.0, 1.0)
	var color := wall_color * shade
	draw_rect(Rect2(Vector2(x, y), Vector2(column_width + 1.0, wall_height)), color)
