extends Node2D

const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
}

func _ready() -> void:
	_setup_input()

func _setup_input() -> void:
	for action_name in ACTIONS.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		InputMap.action_erase_events(action_name)
		for keycode in ACTIONS[action_name]:
			var event := InputEventKey.new()
			event.keycode = keycode
			InputMap.action_add_event(action_name, event)
