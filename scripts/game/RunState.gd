extends Node

const PlayerInventoryData = preload("res://scripts/game/PlayerInventory.gd")
const WEAPONS_DATA_PATH := "res://data/weapons.json"
const RUN_LENGTH_MIN := 5
const RUN_LENGTH_MAX := 7
const MAP_COLUMN_COUNT := 5
const START_ROW_COLUMNS := [1, 2, 3]
const REST_HEAL_AMOUNT := 20

var player_configs: Array = []
var player_health_states: Array = []
var node_map: Array = []
var current_step_index: int = 0
var current_node: Dictionary = {}
var current_node_id: String = ""
var visited_node_ids: Array = []
var reachable_node_ids: Array = []
var rooms_completed: int = 0
var run_outcome: String = "in_progress"
var run_mode: String = "normal"
var debug_run_setup: Dictionary = {}
var player_inventories: Array = []

var _random := RandomNumberGenerator.new()
var _node_lookup: Dictionary = {}
var _weapons_by_id: Dictionary = {}

func _ready() -> void:
	_random.randomize()
	_load_weapons()

func start_new_run(configs: Array, debug_options: Dictionary = {}) -> void:
	_random.randomize()
	_load_weapons()
	debug_run_setup = _build_default_debug_run_setup()
	debug_run_setup.merge(debug_options, true)
	player_configs = configs.duplicate()
	run_mode = _normalize_run_mode(str(debug_options.get("run_mode", "normal")))
	run_outcome = "in_progress"
	rooms_completed = 0
	current_step_index = 0
	current_node = {}
	current_node_id = ""
	visited_node_ids.clear()
	player_health_states.clear()
	player_inventories = _build_default_player_inventories(player_configs.size())
	_apply_debug_starting_mutations()
	for _index in range(player_configs.size()):
		player_health_states.append({"current": 50, "max": 50})
	if is_debug_single_room_mode():
		node_map = _build_single_room_map()
	else:
		node_map = _generate_node_map()
	_rebuild_node_lookup()
	reachable_node_ids = _get_starting_reachable_node_ids()

func get_current_options() -> Array:
	var options: Array = []
	for node_id in reachable_node_ids:
		var node := get_map_node(str(node_id))
		if not node.is_empty():
			options.append(node)
	return options

func get_map_rows() -> Array:
	return node_map.duplicate(true)

func get_map_node(node_id: String) -> Dictionary:
	if not _node_lookup.has(node_id):
		return {}
	return (_node_lookup[node_id] as Dictionary).duplicate(true)

func get_reachable_node_ids() -> Array:
	return reachable_node_ids.duplicate()

func get_visited_node_ids() -> Array:
	return visited_node_ids.duplicate()

func is_easy_mode() -> bool:
	return run_mode == "easy"

func is_run_complete() -> bool:
	return reachable_node_ids.is_empty() and not current_node_id.is_empty()

func is_debug_single_room_mode() -> bool:
	return bool(debug_run_setup.get("enabled", false)) and str(debug_run_setup.get("launch_mode", "normal_run")) == "single_room"

func select_map_node(node_id: String) -> bool:
	if not reachable_node_ids.has(node_id):
		return false
	var node := get_map_node(node_id)
	if node.is_empty():
		return false
	current_node = node
	current_node_id = node_id
	return true

func resolve_current_noncombat_node() -> Dictionary:
	if current_node.is_empty():
		return _build_outcome("No node selected.", "No node selected.", "next")
	var room_type := str(current_node.get("room_type", "rest"))
	match room_type:
		"rest":
			_apply_rest_heal()
			if not is_debug_single_room_mode():
				_advance_progress()
			var summary := "The team catches its breath."
			if is_easy_mode():
				summary += "\nEasy mode still fully restores after combat rooms."
			if is_debug_single_room_mode():
				return _build_outcome("Encounter Complete", summary, "return_to_menu", "Return to Encounter Builder")
			return _build_outcome("Rest Site", summary, "next")
		_:
			return _build_outcome("Room", "Nothing happened.", "next")

func resolve_current_combat_victory(health_states: Array, clear_context: Dictionary = {}) -> Dictionary:
	if current_node.is_empty():
		return _build_outcome("No combat node selected.", "No combat node selected.", "next")
	set_player_health_states(health_states)
	rooms_completed += 1
	_apply_post_room_recovery()
	var objective_name := _format_objective(str(current_node.get("objective", "survive")))
	var summary: String = str(clear_context.get("summary", "Room cleared.\nObjective: %s." % objective_name))
	if is_debug_single_room_mode():
		return _build_outcome("Encounter Cleared", summary, "return_to_menu", "Return to Encounter Builder")
	_advance_progress()
	if str(current_node.get("room_type", "combat")) == "boss" or is_run_complete():
		run_outcome = "won"
		return _build_outcome("Run Victory", "Boss defeated.\n%s" % get_run_summary_text(), "return_to_menu", "Return to Menu")
	return _build_outcome(str(current_node.get("title", "Room Cleared")), summary, "next")

func set_player_health_states(health_states: Array) -> void:
	player_health_states.clear()
	for state in health_states:
		player_health_states.append({
			"current": int(state.get("current", 1)),
			"max": int(state.get("max", 50)),
		})

func get_run_summary_text() -> String:
	var lines := ["Rooms cleared: %d" % rooms_completed]
	for index in range(player_health_states.size()):
		var state: Dictionary = player_health_states[index]
		lines.append("P%d HP: %d/%d" % [index + 1, int(state.get("current", 0)), int(state.get("max", 50))])
	return "\n".join(lines)

func get_player_inventory(player_index: int):
	if player_index < 0 or player_index >= player_inventories.size():
		return null
	return player_inventories[player_index]

func get_primary_weapon(player_index: int) -> Dictionary:
	var inventory = get_player_inventory(player_index)
	if inventory == null:
		return {}
	return (_weapons_by_id.get(inventory.primary_weapon_id, {}) as Dictionary).duplicate(true)

func get_secondary_weapon(player_index: int) -> Dictionary:
	var inventory = get_player_inventory(player_index)
	if inventory == null:
		return {}
	return (_weapons_by_id.get(inventory.secondary_weapon_id, {}) as Dictionary).duplicate(true)

func get_mutations(player_index: int) -> Array:
	var inventory = get_player_inventory(player_index)
	if inventory == null:
		return []
	return inventory.mutations.duplicate()

func get_player_runtime_loadout_for(player_index: int) -> Dictionary:
	var primary_weapon: Dictionary = get_primary_weapon(player_index)
	var secondary_weapon: Dictionary = get_secondary_weapon(player_index)
	if primary_weapon.is_empty():
		primary_weapon = {"id": "rifle", "name": "Rifle", "stats": {}}
	if secondary_weapon.is_empty():
		secondary_weapon = {"id": "shockwave", "name": "Shockwave", "stats": {}}
	return {
		"primary_weapon_id": str(primary_weapon.get("id", "rifle")),
		"primary_name": str(primary_weapon.get("name", "Rifle")),
		"primary_stats": (primary_weapon.get("stats", {}) as Dictionary).duplicate(true),
		"secondary_weapon_id": str(secondary_weapon.get("id", "shockwave")),
		"secondary_name": str(secondary_weapon.get("name", "Shockwave")),
		"secondary_stats": (secondary_weapon.get("stats", {}) as Dictionary).duplicate(true),
		"mutations": get_mutations(player_index),
		"move_speed": 390.0,
	}

func _load_weapons() -> void:
	_weapons_by_id.clear()
	if not FileAccess.file_exists(WEAPONS_DATA_PATH):
		return
	var file := FileAccess.open(WEAPONS_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	var weapons = parsed.get("weapons", [])
	if not (weapons is Array):
		return
	for entry in weapons:
		if not (entry is Dictionary):
			continue
		var weapon: Dictionary = (entry as Dictionary).duplicate(true)
		var weapon_id := str(weapon.get("id", ""))
		if weapon_id.is_empty():
			continue
		_weapons_by_id[weapon_id] = weapon

func _build_default_player_inventories(player_count: int) -> Array:
	var inventories: Array = []
	for index in range(player_count):
		var inventory := PlayerInventoryData.new()
		inventory.player_index = index
		inventory.primary_weapon_id = "rifle"
		inventory.secondary_weapon_id = "shockwave"
		inventories.append(inventory)
	return inventories

func _build_single_room_map() -> Array:
	var room_type := str(debug_run_setup.get("room_type", "combat"))
	if room_type == "elite":
		room_type = "combat"
	var node := {
		"id": "single_room",
		"row": 0,
		"column": 2,
		"room_type": room_type,
		"title": "Encounter Builder",
		"description": "Single-room debug encounter.",
		"objective": str(debug_run_setup.get("room_objective", "survive")),
		"depth": max(int(debug_run_setup.get("step_index", 0)) + 1, 1),
		"enemy_mix": str(debug_run_setup.get("enemy_mix", "mixed")),
		"next_node_ids": [],
	}
	return [[node]]

func _generate_node_map() -> Array:
	var rows: Array = []
	var pre_boss_rows := _random.randi_range(RUN_LENGTH_MIN, RUN_LENGTH_MAX)
	var rest_row := _random.randi_range(1, max(pre_boss_rows - 1, 1))
	for row_index in range(pre_boss_rows):
		var nodes_in_row: Array = []
		var columns: Array = _roll_row_columns(row_index)
		for column in columns:
			var room_type := "rest" if row_index == rest_row else "combat"
			nodes_in_row.append(_build_map_node(row_index, int(column), room_type, row_index + 1))
		rows.append(nodes_in_row)
	rows.append([_build_map_node(pre_boss_rows, 2, "boss", pre_boss_rows + 1)])
	_link_rows(rows)
	return rows

func _roll_row_columns(row_index: int) -> Array:
	if row_index == 0:
		return START_ROW_COLUMNS.duplicate()
	var desired_count := _random.randi_range(2, 4)
	var columns: Array = []
	while columns.size() < desired_count:
		var candidate := _random.randi_range(0, MAP_COLUMN_COUNT - 1)
		if not columns.has(candidate):
			columns.append(candidate)
	columns.sort()
	return columns

func _build_map_node(row_index: int, column: int, room_type: String, depth: int) -> Dictionary:
	var objective := "survive"
	if room_type == "combat" and depth >= 2:
		objective = "capture_the_hill" if depth % 2 == 0 else "survive"
	return {
		"id": "r%d_c%d" % [row_index, column],
		"row": row_index,
		"column": column,
		"room_type": room_type,
		"title": _build_room_title(room_type, depth),
		"description": _build_room_description(room_type, objective),
		"objective": objective,
		"depth": depth,
		"enemy_mix": "mixed",
		"next_node_ids": [],
	}

func _build_room_title(room_type: String, depth: int) -> String:
	match room_type:
		"boss":
			return "Boss Arena"
		"rest":
			return "Rest Site"
		_:
			return "Depth %d" % depth

func _build_room_description(room_type: String, objective: String) -> String:
	match room_type:
		"boss":
			return "Final fight. Bring the whole build."
		"rest":
			return "Recover before the next push."
		_:
			return "Survive the room and complete %s." % _format_objective(objective).to_lower()

func _link_rows(rows: Array) -> void:
	for row_index in range(rows.size() - 1):
		var current_row: Array = rows[row_index]
		var next_row: Array = rows[row_index + 1]
		for node_index in range(current_row.size()):
			var node: Dictionary = current_row[node_index]
			var current_column := int(node.get("column", 0))
			var next_node_ids: Array = []
			for next_node in next_row:
				var next_column := int((next_node as Dictionary).get("column", 0))
				if abs(next_column - current_column) <= 1 or next_row.size() <= 2:
					next_node_ids.append(str((next_node as Dictionary).get("id", "")))
			if next_node_ids.is_empty() and not next_row.is_empty():
				next_node_ids.append(str((next_row[0] as Dictionary).get("id", "")))
			node["next_node_ids"] = next_node_ids
			current_row[node_index] = node
		rows[row_index] = current_row

func _rebuild_node_lookup() -> void:
	_node_lookup.clear()
	for row in node_map:
		for node in row:
			if node is Dictionary:
				_node_lookup[str(node.get("id", ""))] = (node as Dictionary).duplicate(true)

func _get_starting_reachable_node_ids() -> Array:
	var reachable: Array = []
	if node_map.is_empty():
		return reachable
	for node in node_map[0]:
		if node is Dictionary:
			reachable.append(str((node as Dictionary).get("id", "")))
	return reachable

func _advance_progress() -> void:
	if current_node_id.is_empty():
		return
	if not visited_node_ids.has(current_node_id):
		visited_node_ids.append(current_node_id)
	reachable_node_ids = (current_node.get("next_node_ids", []) as Array).duplicate()
	current_step_index = int(current_node.get("row", current_step_index))

func _apply_post_room_recovery() -> void:
	if not is_easy_mode():
		return
	for state in player_health_states:
		state["current"] = int(state.get("max", 50))

func _apply_rest_heal() -> void:
	for state in player_health_states:
		var max_health := int(state.get("max", 50))
		var current_health := int(state.get("current", max_health))
		state["current"] = min(current_health + REST_HEAL_AMOUNT, max_health)

func _normalize_run_mode(value: String) -> String:
	return "easy" if value == "easy" else "normal"

func _build_default_debug_run_setup() -> Dictionary:
	return {
		"enabled": false,
		"launch_mode": "normal_run",
		"room_type": "combat",
		"room_objective": "survive",
		"enemy_mix": "mixed",
		"starting_mutations": [],
		"step_index": 0,
	}

func _apply_debug_starting_mutations() -> void:
	if not bool(debug_run_setup.get("enabled", false)):
		return
	var starting_mutations: Array = (debug_run_setup.get("starting_mutations", []) as Array).duplicate()
	if starting_mutations.is_empty():
		return
	for inventory in player_inventories:
		if inventory == null:
			continue
		for mutation_id in starting_mutations:
			inventory.mutations.append(str(mutation_id))

func _build_outcome(title: String, summary: String, post_action: String, button_text: String = "Continue") -> Dictionary:
	return {
		"title": title,
		"summary": summary,
		"post_action": post_action,
		"button_text": button_text,
	}

func _format_objective(objective: String) -> String:
	match objective:
		"capture_the_hill":
			return "Hold Zone"
		_:
			return "Survive"
