extends Area2D

@export var temperature_delta := 40
@export var wetness_delta := -30

@onready var _map_stack: Node = get_tree().get_first_node_in_group("map_stack")

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D and _map_stack:
		var cell := _map_stack.world_to_cell(global_position)
		_map_stack.deposit_heat(cell, temperature_delta, wetness_delta)
