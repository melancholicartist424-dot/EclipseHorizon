extends Node2D

const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"interact": [KEY_E],
	"attack": [KEY_SPACE],
	"eat": [KEY_F],
	"forage": [KEY_R],
	"capture": [KEY_C],
	"place_snare": [KEY_Q],
	"craft_net": [KEY_Z],
	"craft_snare": [KEY_X],
}

@export var hunger_max := 100.0
@export var hunger_decay_per_second := 2.0
@export var eat_restore := 25.0
@export var hunger_death_time := 6.0
@export var hp_max := 10
@export var temperature_max := 255.0
@export var temperature_adjust_rate := 18.0
@export var wetness_chill_threshold := 120
@export var wetness_chill_rate := 8.0
@export var hypothermia_threshold := 80.0
@export var hypothermia_recover_rate := 0.5
@export var cold_map_threshold := 120
@export var cold_lethal_threshold := 40.0
@export var cold_death_grace := 6.0
@export var stamina_max := 100.0
@export var stamina_regen_per_second := 18.0
@export var sprint_stamina_cost_per_second := 24.0
@export var attack_stamina_cost := 18.0
@export var forage_material_id := 1
@export var forage_yield_meat := 1
@export var forage_cooldown := 6.0
@export var net_capture_power := 45
@export var snare_capture_power := 60
@export var capture_noise_intensity := 45
@export var capture_failure_resist_bonus := 10
@export var capture_success_bonus := 15
@export var net_craft_cost := 2
@export var snare_craft_cost := 3

var hunger := 100.0
var _hunger_zero_timer := 0.0
var _is_dead := false
var hp := 10
var temperature := 0.0
var _cold_zero_timer := 0.0
var stamina := 100.0
var _forage_timer := 0.0
var hypothermia_tier := 0
var _last_wetness := 0
var _last_cold := 0
var inventory := {
	"meat": 0,
	"essence": 0,
	"net": 1,
	"snare": 1,
}
var party: Array[String] = []
var _has_won := false

@onready var hunger_label: Label = get_node_or_null("UI/HungerLabel")
@onready var inventory_label: Label = get_node_or_null("UI/InventoryLabel")
@onready var party_label: Label = get_node_or_null("UI/PartyLabel")
@onready var _map_stack: Node = get_node_or_null("World/MapStack")
@onready var _player: Node2D = get_node_or_null("Player")

func _ready() -> void:
	add_to_group("game")
	_setup_input()
	_initialize_temperature()
	_initialize_hp()
	_update_ui()

func _process(delta: float) -> void:
	if _is_dead:
		return
	hunger = max(0.0, hunger - hunger_decay_per_second * delta)
	var stamina_regen := stamina_regen_per_second
	if hypothermia_tier > 0:
		stamina_regen *= max(0.2, 1.0 - (0.2 * hypothermia_tier))
	stamina = min(stamina_max, stamina + stamina_regen * delta)
	_forage_timer = max(0.0, _forage_timer - delta)
	_update_temperature(delta)
	_update_hypothermia(delta)
	if hunger <= 0.0:
		_hunger_zero_timer += delta
		if _hunger_zero_timer >= hunger_death_time:
			_handle_death("starved")
	else:
		_hunger_zero_timer = 0.0
	if temperature <= cold_lethal_threshold:
		_cold_zero_timer += delta
		if _cold_zero_timer >= cold_death_grace:
			_handle_death("frozen")
	else:
		_cold_zero_timer = 0.0
	if Input.is_action_just_pressed("eat"):
		_consume_food()
	if Input.is_action_just_pressed("craft_net"):
		_try_craft("net", net_craft_cost)
	if Input.is_action_just_pressed("craft_snare"):
		_try_craft("snare", snare_craft_cost)
	_update_ui()

func _setup_input() -> void:
	for action_name in ACTIONS.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		InputMap.action_erase_events(action_name)
		for keycode in ACTIONS[action_name]:
			var event := InputEventKey.new()
			event.keycode = keycode
			InputMap.action_add_event(action_name, event)

func add_resource(resource_name: String, amount: int) -> void:
	if not inventory.has(resource_name):
		inventory[resource_name] = 0
	inventory[resource_name] += amount
	_update_ui()

func add_tamed_mon(mon_name: String) -> void:
	if not party.has(mon_name):
		party.append(mon_name)
	_update_ui()

func _consume_food() -> void:
	if inventory.get("meat", 0) <= 0:
		return
	inventory["meat"] -= 1
	hunger = clamp(hunger + eat_restore, 0.0, hunger_max)

func _update_ui() -> void:
	if hunger_label:
		var status := ""
		if _has_won:
			status = " (Extracted)"
		elif _is_dead:
			status = " (Dead)"
		hunger_label.text = "HP: %d/%d | Hunger: %d/%d | Stamina: %d/%d | Temp: %d/%d | Hypo: %d%s" % [hp, hp_max, int(hunger), int(hunger_max), int(stamina), int(stamina_max), int(temperature), int(temperature_max), hypothermia_tier, status]
	if inventory_label:
		inventory_label.text = "Inventory: Meat %d | Essence %d | Net %d | Snare %d" % [inventory.get("meat", 0), inventory.get("essence", 0), inventory.get("net", 0), inventory.get("snare", 0)]
	if party_label:
		var party_text := "Party: "
		party_text += party.join(", ") if party.size() > 0 else "None"
		party_label.text = party_text

func _handle_death(reason: String) -> void:
	_is_dead = true
	if hunger_label:
		hunger_label.text = "HP: %d/%d | Hunger: 0/%d | Stamina: %d/%d | Temp: %d/%d (Dead: %s)" % [hp, hp_max, int(hunger_max), int(stamina), int(stamina_max), int(temperature), int(temperature_max), reason]

func handle_win() -> void:
	if _is_dead or _has_won:
		return
	_has_won = true
	_update_ui()

func consume_stamina(amount: float) -> void:
	if amount <= 0.0:
		return
	stamina = clamp(stamina - amount, 0.0, stamina_max)
	_update_ui()

func can_sprint() -> bool:
	return stamina > 0.0

func can_attack() -> bool:
	return stamina >= attack_stamina_cost

func try_consume_attack_stamina() -> bool:
	if not can_attack():
		return false
	consume_stamina(attack_stamina_cost)
	return true

func try_forage(cell: Vector2i) -> bool:
	if _forage_timer > 0.0:
		return false
	if _map_stack == null:
		return false
	var material := _map_stack.get_material(cell)
	if material != forage_material_id:
		return false
	add_resource("meat", forage_yield_meat)
	_forage_timer = forage_cooldown
	return true

func try_capture(target: Node, use_snare: bool) -> bool:
	if target == null:
		return false
	if _map_stack == null:
		return false
	var item_key := "snare" if use_snare else "net"
	if inventory.get(item_key, 0) <= 0:
		return false
	var base_power := snare_capture_power if use_snare else net_capture_power
	if not target.has_method("apply_capture_attempt"):
		return false
	var capture_result := target.apply_capture_attempt(base_power, capture_success_bonus)
	if capture_result:
		inventory[item_key] -= 1
		_update_ui()
		return true
	inventory[item_key] = max(0, inventory[item_key] - 1)
	_update_ui()
	var cell := _map_stack.world_to_cell(_player.global_position) if _player else Vector2i.ZERO
	_map_stack.deposit_noise(cell, capture_noise_intensity, 3)
	if target.has_method("add_capture_resistance"):
		target.add_capture_resistance(capture_failure_resist_bonus)
	return false

func _try_craft(item_key: String, essence_cost: int) -> void:
	if _is_dead or _has_won:
		return
	if inventory.get("essence", 0) < essence_cost:
		return
	inventory["essence"] -= essence_cost
	inventory[item_key] = inventory.get(item_key, 0) + 1
	_update_ui()

func apply_damage(amount: int) -> void:
	if _is_dead:
		return
	if amount <= 0:
		return
	hp = max(0, hp - amount)
	_update_ui()
	if hp <= 0:
		_handle_death("slain")

func _initialize_temperature() -> void:
	if _map_stack:
		temperature = _map_stack.ambient_temperature
	else:
		temperature = temperature_max

func _initialize_hp() -> void:
	hp = hp_max
	_try_spawn_player()

func _try_spawn_player() -> void:
	if _map_stack and _player and _map_stack.has_method("get_spawn_cell"):
		var cell := _map_stack.get_spawn_cell()
		_player.global_position = _map_stack.cell_center_world(cell)

func _update_temperature(delta: float) -> void:
	var target_temp := temperature_max
	var wetness := 0
	if _map_stack and _player:
		var cell := _map_stack.world_to_cell(_player.global_position)
		var heat := _map_stack.get_heat(cell)
		target_temp = float(heat.x)
		wetness = heat.y
		_last_cold = _map_stack.get_cold(cell)
	_last_wetness = wetness
	var delta_temp := target_temp - temperature
	if abs(delta_temp) > 0.01:
		var step := temperature_adjust_rate * delta
		if delta_temp > 0.0:
			temperature = min(target_temp, temperature + step)
		else:
			temperature = max(target_temp, temperature - step)
	if wetness >= wetness_chill_threshold and temperature > 0.0:
		temperature = max(0.0, temperature - wetness_chill_rate * delta)
	temperature = clamp(temperature, 0.0, temperature_max)

func _update_hypothermia(delta: float) -> void:
	if temperature <= hypothermia_threshold and temperature > 0.0 and _last_wetness >= wetness_chill_threshold and _last_cold >= cold_map_threshold:
		var gain := int(ceil(delta))
		hypothermia_tier = clamp(hypothermia_tier + gain, 0, 3)
	else:
		if hypothermia_tier > 0:
			hypothermia_tier = max(0, hypothermia_tier - int(ceil(delta * hypothermia_recover_rate)))
