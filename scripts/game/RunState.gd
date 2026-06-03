extends Node

signal level_up(new_level: int)

const PlayerInventoryData = preload("res://scripts/game/PlayerInventory.gd")
const AbilityRegistryData = preload("res://scripts/game/AbilityRegistry.gd")

const WEAPONS_DATA_PATH := "res://data/weapons.json"
const MODIFIERS_DATA_PATH := "res://data/modifiers.json"
const ACT_1_ROW_MIN := 3
const ACT_1_ROW_MAX := 4
const ACT_2_ROW_MIN := 6
const ACT_2_ROW_MAX := 7
const MAP_COLUMN_COUNT := 5
const START_ROW_COLUMNS := [1, 2, 3]
const ENDLESS_BOSS_INTERVAL := 5

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
var run_mode: String = "structured"
var debug_run_setup: Dictionary = {}
var player_inventories: Array = []
var xp_current: int = 0
var xp_level: int = 0
var xp_to_next_level: int = 200
var xp_pending_levelups: int = 0
var current_act: int = 1
var endless_room_index: int = 1

var _random := RandomNumberGenerator.new()
var _node_lookup: Dictionary = {}
var _weapons_by_id: Dictionary = {}
var _modifiers_by_id: Dictionary = {}
var _ability_registry = AbilityRegistryData.new()
var _structured_mid_boss_type := "warden"
var _structured_final_boss_type := "hydra"

func _ready() -> void:
	_random.randomize()
	_load_weapons()
	_load_modifiers()

func start_new_run(configs: Array, debug_options: Dictionary = {}) -> void:
	_random.randomize()
	_load_weapons()
	_load_modifiers()
	debug_run_setup = _build_default_debug_run_setup()
	debug_run_setup.merge(debug_options, true)
	player_configs = configs.duplicate()
	run_mode = _normalize_run_mode(str(debug_options.get("run_mode", "structured")))
	run_outcome = "in_progress"
	rooms_completed = 0
	current_step_index = 0
	current_node = {}
	current_node_id = ""
	visited_node_ids.clear()
	player_health_states.clear()
	player_inventories = _build_default_player_inventories(player_configs.size(), debug_run_setup.get("player_abilities", []) as Array)
	xp_current = 0
	xp_level = 0
	xp_to_next_level = 200
	xp_pending_levelups = 0
	current_act = 1
	endless_room_index = 1
	_apply_debug_starting_mutations()
	for _index in range(player_configs.size()):
		player_health_states.append({"current": 50, "max": 50})
	if is_debug_single_room_mode():
		node_map = _build_single_room_map()
	elif is_endless_mode():
		node_map = [[_build_endless_node(endless_room_index)]]
	else:
		_assign_structured_boss_types()
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
	return false

func is_endless_mode() -> bool:
	return run_mode == "endless"

func is_run_complete() -> bool:
	if is_endless_mode():
		return false
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
	current_act = int(node.get("act", current_act))
	return true

func resolve_current_noncombat_node() -> Dictionary:
	if current_node.is_empty():
		return _build_outcome("No node selected.", "No node selected.", "next")
	if not is_debug_single_room_mode() and not is_endless_mode():
		_advance_progress()
	return _build_outcome("Room", "Nothing happened.", "next")

func resolve_current_combat_victory(health_states: Array, clear_context: Dictionary = {}) -> Dictionary:
	if current_node.is_empty():
		return _build_outcome("No combat node selected.", "No combat node selected.", "next")
	set_player_health_states(health_states)
	current_act = int(current_node.get("act", current_act))
	rooms_completed += 1
	var objective_name := _format_objective(str(current_node.get("objective", "kill_all")))
	var summary: String = str(clear_context.get("summary", "Room cleared.\nObjective: %s." % objective_name))
	if is_debug_single_room_mode():
		return _build_outcome("Encounter Cleared", summary, "return_to_menu", "Return to Encounter Builder")
	if is_endless_mode():
		endless_room_index = rooms_completed + 1
		node_map = [[_build_endless_node(endless_room_index)]]
		_rebuild_node_lookup()
		reachable_node_ids = _get_starting_reachable_node_ids()
		current_step_index = 0
		current_node = {}
		current_node_id = ""
		return _build_outcome("Continue", summary, "endless_next")
	_advance_progress()
	var room_type := str(current_node.get("room_type", "combat"))
	var is_final_boss := room_type == "boss" and int(current_node.get("act", 1)) >= 2
	if is_final_boss or is_run_complete():
		run_outcome = "won"
		return _build_outcome("Run Victory", "%s\n%s" % [summary, get_run_summary_text()], "return_to_menu", "Return to Menu")
	return _build_outcome(str(current_node.get("title", "Room Cleared")), summary, "next")

func set_player_health_states(health_states: Array) -> void:
	player_health_states.clear()
	for state in health_states:
		player_health_states.append({
			"current": int(state.get("current", 1)),
			"max": int(state.get("max", 50)),
		})

func get_run_summary_text() -> String:
	var xp_progress := get_xp_progress()
	var lines := []
	if is_endless_mode():
		lines.append("Score: %d rooms" % rooms_completed)
	else:
		lines.append("Rooms cleared: %d" % rooms_completed)
	lines.append("Level: %d" % int(xp_progress.get("level", 0)))
	lines.append("XP: %d/%d" % [int(xp_progress.get("current", 0)), int(xp_progress.get("needed", 80))])
	lines.append("Pending picks: %d" % int(xp_progress.get("pending", 0)))
	for index in range(player_health_states.size()):
		var state: Dictionary = player_health_states[index]
		lines.append("P%d HP: %d/%d" % [index + 1, int(state.get("current", 0)), int(state.get("max", 50))])
	return "\n".join(lines)

func get_player_inventory(player_index: int):
	if player_index < 0 or player_index >= player_inventories.size():
		return null
	return player_inventories[player_index]

func get_weapon(player_index: int) -> Dictionary:
	var inventory = get_player_inventory(player_index)
	if inventory == null:
		return {}
	return (_weapons_by_id.get(inventory.weapon_id, {}) as Dictionary).duplicate(true)

func get_ability(player_index: int, slot_index: int) -> Dictionary:
	var inventory = get_player_inventory(player_index)
	if inventory == null:
		return {}
	var ability_id: String = inventory.ability_slot_1 if slot_index == 0 else inventory.ability_slot_2
	return _ability_registry.get_definition(ability_id)

func get_primary_skill(player_index: int) -> Dictionary:
	return get_ability(player_index, 0)

func get_mutations(player_index: int) -> Array:
	var inventory = get_player_inventory(player_index)
	if inventory == null:
		return []
	return inventory.mutations.duplicate()

func get_player_runtime_loadout_for(player_index: int) -> Dictionary:
	var inventory = get_player_inventory(player_index)
	var weapon: Dictionary = get_weapon(player_index)
	var ability_slot_1: Dictionary = get_ability(player_index, 0)
	var ability_slot_2: Dictionary = get_ability(player_index, 1)
	if weapon.is_empty():
		weapon = {"id": "rifle", "name": "Rifle", "stats": {}}
	return {
		"weapon_id": str(weapon.get("id", "rifle")),
		"weapon_name": str(weapon.get("name", "Rifle")),
		"weapon_stats": (weapon.get("stats", {}) as Dictionary).duplicate(true),
		"ability_slot_1_id": str(inventory.ability_slot_1 if inventory != null else "shockwave"),
		"ability_slot_2_id": str(inventory.ability_slot_2 if inventory != null else "dash"),
		"ability_slot_1": ability_slot_1.duplicate(true),
		"ability_slot_2": ability_slot_2.duplicate(true),
		"mutations": get_mutations(player_index),
		"move_speed": 488.0,
		"max_health": 50,
	}

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp_current += amount
	while xp_current >= xp_to_next_level:
		xp_current -= xp_to_next_level
		xp_level += 1
		xp_pending_levelups += 1
		xp_to_next_level = 200 + (xp_level * 150)
		level_up.emit(xp_level)

func get_pending_levelups() -> int:
	return xp_pending_levelups

func spend_levelup() -> void:
	xp_pending_levelups = max(xp_pending_levelups - 1, 0)

func get_xp_progress() -> Dictionary:
	return {
		"current": xp_current,
		"needed": xp_to_next_level,
		"level": xp_level,
		"pending": xp_pending_levelups,
	}

func get_current_act() -> int:
	return current_act

func set_current_act(act: int) -> void:
	current_act = maxi(act, 1)

func get_current_score() -> int:
	return rooms_completed

func _load_weapons() -> void:
	_weapons_by_id.clear()
	if not FileAccess.file_exists(WEAPONS_DATA_PATH):
		return
	var file := FileAccess.open(WEAPONS_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	for entry in ((parsed as Dictionary).get("weapons", []) as Array):
		if not (entry is Dictionary):
			continue
		var weapon: Dictionary = (entry as Dictionary).duplicate(true)
		var weapon_id := str(weapon.get("id", ""))
		if weapon_id.is_empty():
			continue
		if str(weapon.get("type", "weapon")) != "weapon":
			continue
		_weapons_by_id[weapon_id] = weapon

func _build_default_player_inventories(player_count: int, selected_abilities: Array) -> Array:
	var inventories: Array = []
	for index in range(player_count):
		var inventory := PlayerInventoryData.new()
		inventory.player_index = index
		inventory.weapon_id = "rifle"
		var chosen: Array = []
		if index < selected_abilities.size() and selected_abilities[index] is Array:
			chosen = (selected_abilities[index] as Array).duplicate()
		inventory.ability_slot_1 = str(chosen[0]) if chosen.size() > 0 else "shockwave"
		inventory.ability_slot_2 = str(chosen[1]) if chosen.size() > 1 else "dash"
		inventories.append(inventory)
	return inventories

func _build_single_room_map() -> Array:
	var room_type := str(debug_run_setup.get("room_type", "combat"))
	var room_depth: int = maxi(1, int(debug_run_setup.get("step_index", 0)) + 1)
	var act: int = 1 if room_depth <= 5 else 2
	var node := _build_map_node(0, 2, room_type, act, room_depth, 0, 1)
	node["id"] = "single_room"
	node["title"] = "Encounter Builder"
	node["description"] = "Single-room debug encounter."
	node["objective"] = str(debug_run_setup.get("room_objective", "kill_all"))
	node["side_objective"] = str(debug_run_setup.get("side_objective", node.get("side_objective", "")))
	node["modifiers"] = (debug_run_setup.get("modifiers", []) as Array).duplicate()
	node["next_node_ids"] = []
	node["enemy_pool"] = _enemy_pool_from_debug_mix(str(debug_run_setup.get("enemy_mix", "mixed")), act, room_depth)
	node["wave_count"] = 1 if room_type == "boss" else max(int(debug_run_setup.get("wave_count", node.get("wave_count", 3))), 1)
	node["debug_boss_add_waves"] = bool(debug_run_setup.get("debug_boss_add_waves", false))
	if room_type == "boss":
		node["boss_type"] = str(debug_run_setup.get("boss_type", "warden"))
	return [[node]]

func _generate_node_map() -> Array:
	var rows: Array = []
	var act_1_rows := _random.randi_range(ACT_1_ROW_MIN, ACT_1_ROW_MAX)
	var act_2_rows := _random.randi_range(ACT_2_ROW_MIN, ACT_2_ROW_MAX)
	var global_depth := 1
	for act_row_index in range(act_1_rows):
		rows.append(_build_branching_row(rows.size(), 1, act_row_index, act_1_rows, global_depth))
		global_depth += 1
	rows.append([_build_boss_node(rows.size(), 1, global_depth, true)])
	global_depth += 1
	for act_row_index in range(act_2_rows):
		rows.append(_build_branching_row(rows.size(), 2, act_row_index, act_2_rows, global_depth))
		global_depth += 1
	rows.append([_build_boss_node(rows.size(), 2, global_depth, false)])
	_link_rows(rows)
	_assign_modifiers_to_map(rows)
	return rows

func _assign_structured_boss_types() -> void:
	var boss_pool := ["warden", "hydra", "hive", "pulsar"]
	boss_pool.shuffle()
	_structured_mid_boss_type = str(boss_pool[0])
	_structured_final_boss_type = str(boss_pool[1])

func _build_branching_row(row_index: int, act: int, act_row_index: int, act_total_rows: int, depth: int) -> Array:
	var columns: Array = START_ROW_COLUMNS.duplicate() if row_index == 0 else _roll_row_columns()
	var nodes_in_row: Array = []
	var elite_column := -1
	if _should_place_elite_node(act, act_row_index, act_total_rows, columns.size()):
		elite_column = int(columns[0]) if _random.randf() < 0.5 else int(columns[columns.size() - 1])
	for column_variant in columns:
		var column := int(column_variant)
		var room_type := "elite" if column == elite_column else "combat"
		nodes_in_row.append(_build_map_node(row_index, column, room_type, act, depth, act_row_index, act_total_rows))
	return nodes_in_row

func _build_boss_node(row_index: int, act: int, depth: int, is_mid_boss: bool) -> Dictionary:
	var boss_type := _structured_mid_boss_type if is_mid_boss else _structured_final_boss_type
	var node := _build_map_node(row_index, 2, "boss", act, depth, 0, 1)
	node["title"] = ("%s Mid-Boss" if is_mid_boss else "%s Final Boss") % _format_name(boss_type)
	node["description"] = "Break through the act gate." if is_mid_boss else "Finish the run."
	node["boss_type"] = boss_type
	node["wave_count"] = 1
	node["enemy_pool"] = []
	node["side_objective"] = ""
	return node

func _build_endless_node(room_number: int) -> Dictionary:
	var act := 1
	if room_number >= 6:
		act = 2
	if room_number >= 11:
		act = 3
	var is_boss := room_number % ENDLESS_BOSS_INTERVAL == 0
	var room_type := "boss" if is_boss else "combat"
	var node := {
		"id": "endless_%d" % room_number,
		"row": 0,
		"column": 2,
		"room_type": room_type,
		"act": 2 if act >= 2 else 1,
		"title": "Room %d" % room_number,
		"description": "Endless pressure keeps climbing.",
		"objective": "kill_all",
		"side_objective": "" if is_boss else _roll_side_objective("combat"),
		"depth": room_number,
		"wave_count": _get_endless_wave_count(room_number, is_boss),
		"enemy_pool": [] if is_boss else _get_endless_enemy_pool(room_number),
		"boss_type": _roll_boss_type() if is_boss else "",
		"modifiers": _roll_endless_modifiers(room_number, is_boss),
		"next_node_ids": [],
	}
	return node

func _get_endless_wave_count(room_number: int, is_boss: bool) -> int:
	if is_boss:
		return 1
	if room_number <= 5:
		return _random.randi_range(2, 3)
	if room_number <= 10:
		return _random.randi_range(3, 4)
	if room_number < 20:
		return _random.randi_range(4, 5)
	return _random.randi_range(5, 6)

func _get_endless_enemy_pool(room_number: int) -> Array[String]:
	if room_number <= 2:
		return ["chaser"]
	if room_number <= 5:
		return ["chaser", "charger"]
	if room_number <= 10:
		return ["chaser", "charger", "spitter", "splitter"]
	return ["chaser", "charger", "spitter", "splitter", "bomber"]

func _roll_endless_modifiers(room_number: int, is_boss: bool) -> Array:
	if room_number <= 1:
		return []
	if room_number <= 5:
		return _roll_modifier_selection(0, 1, 0, 0 if not is_boss else 1)
	if room_number <= 10:
		return _roll_modifier_selection(1, 1, 0, 1)
	if room_number < 20:
		return _roll_modifier_selection(1, 2, 1, 1)
	return _roll_modifier_selection(2, 2, 2, 2)

func _roll_boss_type() -> String:
	var boss_pool := ["warden", "hydra", "hive", "pulsar"]
	return str(boss_pool[_random.randi_range(0, boss_pool.size() - 1)])

func _should_place_elite_node(act: int, act_row_index: int, act_total_rows: int, column_count: int) -> bool:
	if column_count <= 1:
		return false
	if act_row_index == 0:
		return false
	var phase_ratio := float(act_row_index + 1) / float(max(act_total_rows, 1))
	var elite_chance := 0.25 if act == 1 else 0.4
	if phase_ratio >= 0.66:
		elite_chance += 0.1
	return _random.randf() < elite_chance

func _roll_row_columns() -> Array:
	var desired_count := _random.randi_range(2, 3)
	var columns: Array = []
	while columns.size() < desired_count:
		var candidate := _random.randi_range(0, MAP_COLUMN_COUNT - 1)
		if not columns.has(candidate):
			columns.append(candidate)
	columns.sort()
	return columns

func _build_map_node(row_index: int, column: int, room_type: String, act: int, depth: int, act_row_index: int, act_total_rows: int) -> Dictionary:
	return {
		"id": "r%d_c%d" % [row_index, column],
		"row": row_index,
		"column": column,
		"room_type": room_type,
		"act": act,
		"title": _build_room_title(room_type, act, depth),
		"description": _build_room_description(room_type, act),
		"objective": "kill_all",
		"side_objective": _roll_side_objective(room_type),
		"depth": depth,
		"wave_count": _determine_wave_count(act, room_type, act_row_index, act_total_rows),
		"enemy_pool": _build_enemy_pool(act, act_row_index, act_total_rows),
		"boss_type": "",
		"modifiers": [],
		"next_node_ids": [],
	}

func _build_room_title(room_type: String, act: int, depth: int) -> String:
	match room_type:
		"boss":
			return "Act %d Boss" % act
		"elite":
			return "Act %d Elite %d" % [act, depth]
		_:
			return "Act %d Combat %d" % [act, depth]

func _build_room_description(room_type: String, act: int) -> String:
	match room_type:
		"boss":
			return "Clear the boss arena and push into the next phase." if act == 1 else "Final boss. End the structured run."
		"elite":
			return "Harder room. Bonus guaranteed-rare pick on clear."
		_:
			return "Clear every wave to advance."

func _roll_side_objective(room_type: String) -> String:
	if room_type == "boss" or _random.randf() >= 0.5:
		return ""
	var objective_pool := ["hold_zone", "kill_streak", "collector"]
	return str(objective_pool[_random.randi_range(0, objective_pool.size() - 1)])

func _determine_wave_count(act: int, room_type: String, act_row_index: int, _act_total_rows: int) -> int:
	if room_type == "boss":
		return 1
	if act == 1:
		if room_type == "elite":
			return _random.randi_range(3, 4)
		return 2 if act_row_index == 0 else _random.randi_range(2, 3)
	if room_type == "elite":
		return _random.randi_range(4, 5)
	return _random.randi_range(3, 4)

func _build_enemy_pool(act: int, act_row_index: int, act_total_rows: int) -> Array[String]:
	if act == 1:
		if act_row_index == 0:
			return ["chaser"]
		return ["chaser", "charger"]
	var phase_ratio := float(act_row_index + 1) / float(max(act_total_rows, 1))
	if phase_ratio < 0.34:
		return ["chaser", "charger", "spitter"]
	if phase_ratio < 0.67:
		return ["chaser", "charger", "spitter", "splitter"]
	return ["chaser", "charger", "spitter", "splitter", "bomber"]

func _enemy_pool_from_debug_mix(enemy_mix: String, act: int, depth: int) -> Array[String]:
	match enemy_mix:
		"chaser_only":
			return ["chaser"]
		"charger_only":
			return ["charger"]
		"charger_heavy":
			return ["chaser", "charger", "charger"]
		"mixed_act_2":
			return _get_endless_enemy_pool(max(depth, 6))
		_:
			return _build_enemy_pool(act, 1, 3)

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

func _assign_modifiers_to_map(rows: Array) -> void:
	for row_index in range(rows.size()):
		var row: Array = rows[row_index]
		for node_index in range(row.size()):
			if not (row[node_index] is Dictionary):
				continue
			var node: Dictionary = row[node_index]
			node["modifiers"] = _roll_modifiers_for_node(node)
			row[node_index] = node
		rows[row_index] = row

func _roll_modifiers_for_node(node: Dictionary) -> Array:
	var room_type := str(node.get("room_type", "combat"))
	var act := int(node.get("act", 1))
	var depth := int(node.get("depth", 1))
	if room_type == "combat" and act == 1 and depth <= 1:
		return []
	if room_type == "boss" and act == 1:
		return _roll_modifier_selection(1, 2, 1, 1)
	if room_type == "boss":
		return _roll_modifier_selection(1, 2, 1, 2)
	if act == 1:
		return _roll_modifier_selection(1, 1, 0, 1)
	return _roll_modifier_selection(1, 2, 1, 2)

func _roll_modifier_selection(minor_min: int, minor_max: int, major_min: int, major_max: int) -> Array:
	var results: Array = []
	var minor_ids := _get_modifier_ids_by_category("minor")
	var major_ids := _get_modifier_ids_by_category("major")
	var desired_minor := _random.randi_range(minor_min, max(minor_min, minor_max)) if minor_max > 0 else 0
	var desired_major := _random.randi_range(major_min, max(major_min, major_max)) if major_max > 0 else 0
	minor_ids.shuffle()
	major_ids.shuffle()
	for index in range(min(desired_minor, minor_ids.size())):
		results.append(minor_ids[index])
	for index in range(min(desired_major, major_ids.size())):
		results.append(major_ids[index])
	return results

func _get_modifier_ids_by_category(category: String) -> Array:
	var ids: Array = []
	for modifier_id in _modifiers_by_id.keys():
		var definition: Dictionary = _modifiers_by_id[modifier_id] as Dictionary
		if str(definition.get("category", "")) == category:
			ids.append(str(modifier_id))
	return ids

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

func _normalize_run_mode(value: String) -> String:
	return "endless" if value == "endless" else "structured"

func _build_default_debug_run_setup() -> Dictionary:
	return {
		"enabled": false,
		"launch_mode": "normal_run",
		"room_type": "combat",
		"room_objective": "kill_all",
		"enemy_mix": "mixed",
		"modifiers": [],
		"starting_mutations": [],
		"player_abilities": [],
		"debug_boss_add_waves": false,
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
		"kill_streak":
			return "Kill Streak"
		"collector":
			return "Collector"
		_:
			return "Kill All"

func _load_modifiers() -> void:
	_modifiers_by_id.clear()
	if not FileAccess.file_exists(MODIFIERS_DATA_PATH):
		return
	var file := FileAccess.open(MODIFIERS_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	for entry in ((parsed as Dictionary).get("modifiers", []) as Array):
		if not (entry is Dictionary):
			continue
		var modifier: Dictionary = (entry as Dictionary).duplicate(true)
		var modifier_id := str(modifier.get("id", ""))
		if modifier_id.is_empty():
			continue
		_modifiers_by_id[modifier_id] = modifier

func _format_name(raw_name: String) -> String:
	var parts: Array = []
	for word in raw_name.split("_"):
		if not word.is_empty():
			parts.append(word.capitalize())
	return " ".join(parts)
