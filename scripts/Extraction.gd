extends Area2D

@export var active := true

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not active:
		return
	if body is CharacterBody2D:
		var nodes := get_tree().get_nodes_in_group("game")
		if nodes.size() > 0:
			nodes[0].handle_win()
