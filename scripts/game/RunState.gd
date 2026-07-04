extends Node

signal level_up(new_level: int)

const PlayerInventoryData = preload("res://scripts/game/PlayerInventory.gd")
const AbilityRegistryData = preload("res://scripts/game/AbilityRegistry.gd")
const ClassRegistryData = preload("res://scripts/game/ClassRegistry.gd")

const WEAPONS_DATA_PATH := "res://data/weapons.json"
const MODIFIERS_DATA_PATH := "res://data/modifiers.json"
const RUN_LENGTH := 10
const CONTINUATION_PROGRESS_CAP := 1.65
const RARE_NUDGE := 0.06
const RARE_CHANCE_CAP := 0.60
const CHAMPION_INTERVAL_BANDS := [
	{"until_depth": 10, "interval": 5},
	{"until_depth": 20, "interval": 4},
	{"until_depth": -1, "interval": 3},
]
const TRAIT_FALLBACK := {"label": "Open room", "icon": "open"}

var player_configs: Array = []
var player_health_states: Array = []
var node_map: Array = []
var current_step_index: int = 0
var current_node: Dictionary = {}
var current_node_id: String = ""
var reachable_node_ids: Array = []
var rooms_completed: int = 0
var run_outcome: String = "in_progress"
var debug_run_setup: Dictionary = {}
var debug_profiling: bool = false  # dev: PerfRunner sets this so players are immortal during a profile run
var player_inventories: Array = []
var xp_current: int = 0
var xp_level: int = 0
var xp_to_next_level: int = 200
var xp_pending_levelups: int = 0
var run_score: int = 0
var run_score_banked: bool = false
var momentum_progress_by_player: Array = []
var momentum_tier_by_player: Array = []

var _random := RandomNumberGenerator.new()
var _node_lookup: Dictionary = {}
var _weapons_by_id: Dictionary = {}
var _modifiers_by_id: Dictionary = {}
var _ability_registry = AbilityRegistryData.new()
var _class_registry = ClassRegistryData.new()
var _structured_mid_boss_type := "warden"
var _structured_final_boss_type := "hydra"
var _structured_total_combat_depth := 1
var _last_champion_depth := 0
var _champion_bag: Array[String] = []

func _ready() -> void:
	_random.randomize()
	_load_weapons()
	_load_modifiers()
	_class_registry.reload()

func start_new_run(configs: Array, debug_options: Dictionary = {}) -> void:
	_random.randomize()
	_load_weapons()
	_load_modifiers()
	_class_registry.reload()
	debug_run_setup = _build_default_debug_run_setup()
	debug_run_setup.merge(debug_options, true)
	player_configs = configs.duplicate()
	run_outcome = "in_progress"
	rooms_completed = 0
	current_step_index = 0
	current_node = {}
	current_node_id = ""
	player_health_states.clear()
	player_inventories = _build_default_player_inventories(
		player_configs.size(),
		debug_run_setup.get("player_classes", []) as Array,
		debug_run_setup.get("player_abilities", []) as Array,
		debug_run_setup.get("player_weapons", []) as Array
	)
	xp_current = 0
	xp_level = 0
	xp_to_next_level = 200
	xp_pending_levelups = 0
	run_score = 0
	run_score_banked = false
	momentum_progress_by_player.clear()
	momentum_tier_by_player.clear()
	_apply_debug_starting_progress()
	_structured_total_combat_depth = RUN_LENGTH
	_last_champion_depth = 0
	_apply_debug_starting_mutations()
	for _index in range(player_configs.size()):
		player_health_states.append({"current": 100, "max": 100})
		momentum_progress_by_player.append(0)
		momentum_tier_by_player.append(0)
	_assign_structured_boss_types()
	_reset_champion_bag()
	if is_debug_single_room_mode():
		node_map = _build_single_room_map()
	else:
		node_map = [_build_choice_step(1)]
	_rebuild_node_lookup()
	reachable_node_ids = _get_current_step_node_ids()

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
	return _build_outcome("Room", "Nothing happened.", "next")

func resolve_current_combat_victory(health_states: Array, clear_context: Dictionary = {}) -> Dictionary:
	if current_node.is_empty():
		return _build_outcome("No combat node selected.", "No combat node selected.", "next")
	set_player_health_states(health_states)
	rooms_completed += 1
	var objective_name := _format_objective(str(current_node.get("objective", "kill_all")))
	var summary: String = str(clear_context.get("summary", "Room cleared.\nObjective: %s." % objective_name))
	var completed_title := str(current_node.get("title", "Room Cleared"))
	if is_debug_single_room_mode():
		return _build_outcome("Encounter Cleared", summary, "return_to_menu", "Return to Encounter Builder")
	_advance_to_next_step()
	if rooms_completed == RUN_LENGTH and run_outcome != "won":
		run_outcome = "won"
		return _build_outcome(
			"Run Milestone Cleared",
			"%s\nScore: %d.\nContinue into endless scaling?" % [summary, run_score],
			"win_milestone",
			"Continue"
		)
	return _build_outcome(completed_title, summary, "next")

func set_player_health_states(health_states: Array) -> void:
	player_health_states.clear()
	for state in health_states:
		player_health_states.append({
			"current": int(state.get("current", 1)),
			"max": int(state.get("max", 100)),
		})

func get_run_summary_text() -> String:
	var xp_progress := get_xp_progress()
	var lines := []
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
	_normalize_inventory_loadout(inventory)
	return (_weapons_by_id.get(inventory.weapon_id, {}) as Dictionary).duplicate(true)

func get_weapon_level(player_index: int) -> int:
	var inventory = get_player_inventory(player_index)
	if inventory == null:
		return 1
	return clampi(int(inventory.weapon_level), 1, 5)

func get_active_weapon_id(player_index: int) -> String:
	var inventory = get_player_inventory(player_index)
	if inventory == null:
		return "rifle"
	_normalize_inventory_loadout(inventory)
	return str(inventory.weapon_id)

func get_class_catalog() -> Array:
	var catalog: Array = []
	for class_definition in _class_registry.get_all():
		var class_data: Dictionary = class_definition as Dictionary
		var class_id := str(class_data.get("id", ""))
		if class_id.is_empty():
			continue
		catalog.append({
			"id": class_id,
			"name": str(class_data.get("name", _format_name(class_id))),
			"hp": int(class_data.get("hp", 100)),
			"move_speed": int(class_data.get("move_speed", 560)),
			"passive": str(class_data.get("passive", "")),
			"ultimate": str(class_data.get("ultimate", "")),
			"tags": (class_data.get("tags", []) as Array).duplicate(),
		})
	return catalog

func get_class_definition(class_id: String) -> Dictionary:
	return _class_registry.get_definition(_normalize_class_id(class_id))

func get_weapon_catalog_for_class(class_id: String) -> Array:
	var catalog: Array = []
	for weapon_id_variant in _class_registry.get_weapon_pool(_normalize_class_id(class_id)):
		var weapon_id := str(weapon_id_variant)
		if not _weapons_by_id.has(weapon_id):
			continue
		var weapon: Dictionary = _weapons_by_id[weapon_id] as Dictionary
		catalog.append({
			"id": weapon_id,
			"name": str(weapon.get("name", _format_name(weapon_id))),
			"description": str(weapon.get("description", "")),
		})
	return catalog

func get_ability_catalog_for_class(class_id: String) -> Array:
	var catalog: Array = []
	for ability_id_variant in _class_registry.get_ability_pool(_normalize_class_id(class_id)):
		var ability_id := str(ability_id_variant)
		var ability := _ability_registry.get_definition(ability_id)
		if ability.is_empty():
			continue
		catalog.append({
			"id": ability_id,
			"name": str(ability.get("name", _format_name(ability_id))),
			"description": str(ability.get("description", "")),
			"tags": (ability.get("tags", []) as Array).duplicate(),
		})
	return catalog

func level_up_weapon(player_index: int) -> void:
	var inventory = get_player_inventory(player_index)
	if inventory == null:
		return
	inventory.weapon_level = clampi(int(inventory.weapon_level) + 1, 1, 5)

func set_active_weapon(player_index: int, weapon_id: String) -> void:
	var inventory = get_player_inventory(player_index)
	if inventory == null:
		return
	if ProfileState != null and not ProfileState.is_content_unlocked("weapon", weapon_id):
		return
	if not _is_weapon_in_class_pool(str(inventory.class_id), weapon_id):
		return
	var weapon: Dictionary = _weapons_by_id[weapon_id] as Dictionary
	if str(weapon.get("type", "weapon")) != "weapon":
		return
	inventory.weapon_id = weapon_id

func get_weapon_catalog() -> Array:
	var catalog: Array = []
	var class_pool_weapon_ids := {}
	for class_definition in _class_registry.get_all():
		for weapon_id_variant in ((class_definition as Dictionary).get("weapon_pool", []) as Array):
			class_pool_weapon_ids[str(weapon_id_variant)] = true
	for weapon_id_variant in class_pool_weapon_ids.keys():
		if not _weapons_by_id.has(weapon_id_variant):
			continue
		var weapon: Dictionary = _weapons_by_id[weapon_id_variant] as Dictionary
		var weapon_id := str(weapon.get("id", weapon_id_variant))
		if ProfileState != null and not ProfileState.is_content_unlocked("weapon", weapon_id):
			continue
		if str(weapon.get("type", "weapon")) != "weapon":
			continue
		catalog.append({
			"id": weapon_id,
			"name": str(weapon.get("name", weapon_id_variant)),
			"description": str(weapon.get("description", "")),
		})
	catalog.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0
	)
	return catalog

func get_ability(player_index: int, slot_index: int) -> Dictionary:
	var inventory = get_player_inventory(player_index)
	if inventory == null:
		return {}
	_normalize_inventory_ability_slots(inventory)
	var ability_ids: Array = inventory.get_ability_ids()
	if slot_index < 0 or slot_index >= ability_ids.size():
		return {}
	var ability_id: String = str(ability_ids[slot_index])
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
	if weapon.is_empty():
		weapon = {"id": "rifle", "name": "Rifle", "stats": {}}
	var weapon_level := get_weapon_level(player_index)
	var weapon_stats := _resolve_weapon_stats(weapon, weapon_level)
	var ability_ids: Array = inventory.get_ability_ids() if inventory != null else _ability_registry.get_default_loadout()
	var class_definition := _class_registry.get_definition(str(inventory.class_id)) if inventory != null else {}
	var loadout := {
		"class_id": str(inventory.class_id if inventory != null else _class_registry.get_first_class_id()),
		"passive_id": str(inventory.passive_id if inventory != null else ""),
		"ultimate_id": str(inventory.ultimate_id if inventory != null else ""),
		"weapon_id": str(weapon.get("id", "rifle")),
		"weapon_name": str(weapon.get("name", "Rifle")),
		"weapon_level": weapon_level,
		"weapon_stats": weapon_stats,
		"mutations": get_mutations(player_index),
		"move_speed": float(class_definition.get("move_speed", 560.0)) if not class_definition.is_empty() else 560.0,
		"max_health": int(class_definition.get("hp", 100)) if not class_definition.is_empty() else 100,
	}
	for slot_index in range(4):
		var ability_id := str(ability_ids[slot_index]) if slot_index < ability_ids.size() else ""
		loadout["ability_slot_%d_id" % (slot_index + 1)] = ability_id
		loadout["ability_slot_%d" % (slot_index + 1)] = get_ability(player_index, slot_index).duplicate(true)
	return loadout

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

func get_current_score() -> int:
	return run_score

func add_run_score(delta: int) -> void:
	if delta <= 0:
		return
	run_score += delta

func spend_run_score(amount: int) -> bool:
	if amount <= 0:
		return true
	if run_score < amount:
		return false
	run_score -= amount
	return true

func bank_run_score_once() -> int:
	if run_score_banked:
		return 0
	run_score_banked = true
	return run_score

func get_momentum_state(player_index: int) -> Dictionary:
	if player_index < 0 or player_index >= momentum_tier_by_player.size():
		return {"tier": 0, "progress": 0}
	return {
		"tier": int(momentum_tier_by_player[player_index]),
		"progress": int(momentum_progress_by_player[player_index]),
	}

func set_momentum_state(player_index: int, tier: int, progress: int) -> void:
	if player_index < 0:
		return
	while momentum_tier_by_player.size() <= player_index:
		momentum_tier_by_player.append(0)
		momentum_progress_by_player.append(0)
	momentum_tier_by_player[player_index] = max(tier, 0)
	momentum_progress_by_player[player_index] = max(progress, 0)

func get_run_progress() -> float:
	if is_debug_single_room_mode():
		var debug_depth := maxi(1, int(debug_run_setup.get("step_index", 0)) + 1)
		return _progress_for_depth(debug_depth)
	var global_depth := maxi(current_step_index + 1, 1)
	if not current_node.is_empty():
		global_depth = int(current_node.get("depth", global_depth))
	return _progress_for_depth(global_depth)

func _progress_for_depth(depth: int) -> float:
	var denominator := float(maxi(_structured_total_combat_depth - 1, 1))
	var clamped_depth := maxi(depth, 1)
	if clamped_depth <= RUN_LENGTH:
		return clampf(float(clamped_depth - 1) / denominator, 0.0, 1.0)
	var continuation_progress := 1.0 + float(clamped_depth - RUN_LENGTH) / 30.0
	return clampf(continuation_progress, 1.0, CONTINUATION_PROGRESS_CAP)

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

func _resolve_weapon_stats(weapon_def: Dictionary, weapon_level: int) -> Dictionary:
	var resolved: Dictionary = (weapon_def.get("stats", {}) as Dictionary).duplicate(true)
	var level_index := clampi(weapon_level, 1, 5) - 1
	var per_level: Dictionary = (weapon_def.get("per_level", {}) as Dictionary)
	for stat_key_variant in per_level.keys():
		var stat_key := str(stat_key_variant)
		var values: Array = per_level[stat_key_variant] as Array
		if values.is_empty():
			continue
		var value_index := mini(level_index, values.size() - 1)
		resolved[stat_key] = values[value_index]
	resolved["projectile_kind"] = str(weapon_def.get("projectile_kind", resolved.get("projectile_kind", "bullet")))
	return resolved

func _build_default_player_inventories(player_count: int, selected_classes: Array, selected_abilities: Array, selected_weapons: Array = []) -> Array:
	var inventories: Array = []
	for index in range(player_count):
		var inventory := PlayerInventoryData.new()
		inventory.player_index = index
		var selected_class := str(selected_classes[index]) if index < selected_classes.size() else ""
		inventory.class_id = _normalize_class_id(selected_class)
		var class_definition := _class_registry.get_definition(inventory.class_id)
		inventory.passive_id = str(class_definition.get("passive", ""))
		inventory.ultimate_id = str(class_definition.get("ultimate", ""))
		inventory.weapon_id = _first_class_weapon_id(inventory.class_id)
		if index < selected_weapons.size():
			var selected_weapon := str(selected_weapons[index])
			if _is_weapon_in_class_pool(inventory.class_id, selected_weapon):
				inventory.weapon_id = selected_weapon
		var chosen: Array = []
		if index < selected_abilities.size() and selected_abilities[index] is Array:
			chosen = (selected_abilities[index] as Array).duplicate()
		var normalized := _normalize_class_ability_loadout(inventory.class_id, chosen)
		inventory.set_ability_ids(normalized)
		inventories.append(inventory)
	return inventories

func _normalize_inventory_ability_slots(inventory) -> void:
	if inventory == null:
		return
	_normalize_inventory_loadout(inventory)

func _normalize_inventory_loadout(inventory) -> void:
	if inventory == null:
		return
	inventory.class_id = _normalize_class_id(str(inventory.class_id))
	var class_definition := _class_registry.get_definition(inventory.class_id)
	inventory.passive_id = str(class_definition.get("passive", ""))
	inventory.ultimate_id = str(class_definition.get("ultimate", ""))
	if not _is_weapon_in_class_pool(inventory.class_id, str(inventory.weapon_id)):
		inventory.weapon_id = _first_class_weapon_id(inventory.class_id)
	var normalized := _normalize_class_ability_loadout(inventory.class_id, inventory.get_chosen_ability_ids())
	inventory.set_ability_ids(normalized)

func _first_unlocked_weapon_id() -> String:
	if _weapons_by_id.has("rifle") and (ProfileState == null or ProfileState.is_content_unlocked("weapon", "rifle")):
		return "rifle"
	for weapon_id_variant in _weapons_by_id.keys():
		var weapon_id := str(weapon_id_variant)
		if ProfileState == null or ProfileState.is_content_unlocked("weapon", weapon_id):
			return weapon_id
	return "rifle"

func _normalize_class_id(class_id: String) -> String:
	if _class_registry.has(class_id):
		return class_id
	var first_class_id := _class_registry.get_first_class_id()
	return first_class_id if not first_class_id.is_empty() else "mobile"

func _first_class_weapon_id(class_id: String) -> String:
	for weapon_id_variant in _class_registry.get_weapon_pool(_normalize_class_id(class_id)):
		var weapon_id := str(weapon_id_variant)
		if _weapons_by_id.has(weapon_id):
			return weapon_id
	return _first_unlocked_weapon_id()

func _is_weapon_in_class_pool(class_id: String, weapon_id: String) -> bool:
	return _class_registry.get_weapon_pool(_normalize_class_id(class_id)).has(weapon_id) and _weapons_by_id.has(weapon_id)

func _normalize_class_ability_loadout(class_id: String, chosen_abilities: Array) -> Array:
	var normalized_class_id := _normalize_class_id(class_id)
	var ability_pool := _class_registry.get_ability_pool(normalized_class_id)
	var chosen: Array = []
	for ability_id_variant in chosen_abilities:
		var ability_id := str(ability_id_variant)
		if ability_pool.has(ability_id) and _ability_registry.has(ability_id) and not chosen.has(ability_id):
			chosen.append(ability_id)
		if chosen.size() >= 3:
			break
	for ability_id_variant in ability_pool:
		if chosen.size() >= 3:
			break
		var ability_id := str(ability_id_variant)
		if _ability_registry.has(ability_id) and not chosen.has(ability_id):
			chosen.append(ability_id)
	while chosen.size() < 3:
		chosen.append("")
	var ultimate_id := _class_registry.get_ultimate_id(normalized_class_id)
	chosen.append(ultimate_id if _ability_registry.has(ultimate_id) else "")
	return chosen

func _filter_unlocked_abilities(ability_ids: Array) -> Array:
	var filtered: Array = []
	for ability_id_variant in ability_ids:
		var ability_id := str(ability_id_variant)
		if ability_id.is_empty():
			continue
		if ProfileState != null and not ProfileState.is_content_unlocked("ability", ability_id):
			continue
		filtered.append(ability_id)
	return filtered

func _build_single_room_map() -> Array:
	var room_type := str(debug_run_setup.get("room_type", "combat"))
	var room_depth: int = maxi(1, int(debug_run_setup.get("step_index", 0)) + 1)
	if room_type == "elite":
		room_type = "combat"
	var node := _build_run_node(room_depth, room_type, "single_room")
	node["id"] = "single_room"
	node["title"] = "Encounter Builder"
	node["description"] = "Single-room debug encounter."
	node["objective"] = str(debug_run_setup.get("room_objective", "kill_all"))
	node["side_objective"] = str(debug_run_setup.get("side_objective", node.get("side_objective", "")))
	node["modifiers"] = (debug_run_setup.get("modifiers", []) as Array).duplicate()
	node["next_node_ids"] = []
	node["enemy_pool"] = _enemy_pool_from_debug_mix(str(debug_run_setup.get("enemy_mix", "mixed")), room_depth)
	if room_type == "boss":
		node["boss_type"] = str(debug_run_setup.get("boss_type", "warden"))
		node["side_objective"] = ""
		if debug_run_setup.has("boss_spawn_delay"):
			node["boss_spawn_delay"] = maxf(0.0, float(debug_run_setup.get("boss_spawn_delay", 0.0)))
	return [[node]]

func _assign_structured_boss_types() -> void:
	var boss_pool := ["warden", "hydra", "hive", "pulsar"]
	boss_pool.shuffle()
	_structured_mid_boss_type = str(boss_pool[0])
	_structured_final_boss_type = str(boss_pool[1])

func _reset_champion_bag() -> void:
	_champion_bag = ["warden", "hydra", "hive", "pulsar", "elite_charger", "elite_spitter", "elite_support"]
	_champion_bag.shuffle()

func _build_choice_step(room_number: int) -> Array:
	if _is_champion_step(room_number):
		_last_champion_depth = room_number
		return [_build_run_node(room_number, "boss", "champion")]
	var options: Array = [
		_build_run_node(room_number, "combat", "a"),
		_build_run_node(room_number, "combat", "b"),
	]
	_ensure_route_traits_differ(options)
	_ensure_route_options_differ(options)
	_assign_route_rare_bonus(options)
	return options

func _build_run_node(room_number: int, room_type: String, slot: String) -> Dictionary:
	var is_champion := room_type != "combat"
	var node := {
		"id": "room_%d_%s" % [room_number, slot],
		"room_type": room_type,
		"depth": room_number,
		"title": ("Champion - Room %d" if is_champion else "Room %d") % room_number,
		"description": "Forced champion encounter." if is_champion else "Choose this room.",
		"objective": "kill_all",
		"side_objective": "" if is_champion else _roll_side_objective("combat"),
		"enemy_pool": _get_endless_enemy_pool(room_number),
		"boss_type": _champion_boss_type(room_number) if is_champion else "",
		"modifiers": _roll_modifiers_for_depth(room_number, room_type),
		"next_node_ids": [],
	}
	_refresh_route_metadata(node)
	return node

func _interval_for_depth(depth: int) -> int:
	for band in CHAMPION_INTERVAL_BANDS:
		var until_depth := int((band as Dictionary).get("until_depth", -1))
		if until_depth < 0 or depth <= until_depth:
			return maxi(1, int((band as Dictionary).get("interval", 3)))
	return 3

func _is_champion_step(room_number: int) -> bool:
	if room_number == RUN_LENGTH:
		return true
	if room_number <= 1:
		return false
	var last := _last_champion_depth
	return room_number == last + _interval_for_depth(maxi(last, 1))

func _champion_boss_type(room_number: int) -> String:
	if room_number == _interval_for_depth(1) and room_number < RUN_LENGTH:
		_remove_from_champion_bag(_structured_mid_boss_type)
		return _structured_mid_boss_type
	if room_number == RUN_LENGTH:
		_remove_from_champion_bag(_structured_final_boss_type)
		return _structured_final_boss_type
	return _draw_champion_boss_type()

func _draw_champion_boss_type() -> String:
	if _champion_bag.is_empty():
		_reset_champion_bag()
	return str(_champion_bag.pop_front())

func _remove_from_champion_bag(boss_type: String) -> void:
	if _champion_bag.has(boss_type):
		_champion_bag.erase(boss_type)

func _get_endless_enemy_pool(room_number: int) -> Array[String]:
	if room_number <= 2:
		return ["chaser"]
	if room_number <= 5:
		return ["chaser", "charger"]
	if room_number <= 10:
		return ["chaser", "charger", "spitter", "splitter"]
	if room_number <= 20:
		return ["chaser", "charger", "spitter", "splitter", "bomber"]
	if room_number <= 30:
		return ["chaser", "charger", "charger", "spitter", "spitter", "splitter", "bomber"]
	return ["chaser", "charger", "charger", "spitter", "spitter", "splitter", "bomber", "bomber"]

func _roll_side_objective(room_type: String) -> String:
	if room_type == "boss" or _random.randf() >= 0.5:
		return ""
	var objective_pool := ["hold_zone", "kill_streak", "collector"]
	return str(objective_pool[_random.randi_range(0, objective_pool.size() - 1)])

func _enemy_pool_from_debug_mix(enemy_mix: String, depth: int) -> Array[String]:
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
			return _get_endless_enemy_pool(depth)

func _ensure_route_options_differ(row: Array) -> void:
	var seen_signatures: Dictionary = {}
	for node_index in range(row.size()):
		if not (row[node_index] is Dictionary):
			continue
		var node: Dictionary = row[node_index]
		var signature := _build_route_option_signature(node)
		if not seen_signatures.has(signature):
			seen_signatures[signature] = true
			continue
		var replacement_modifiers := _build_distinct_modifier_load(node, seen_signatures)
		if not replacement_modifiers.is_empty():
			node["modifiers"] = replacement_modifiers
			_refresh_route_metadata(node)
			row[node_index] = node
			seen_signatures[_build_route_option_signature(node)] = true

func _ensure_route_traits_differ(row: Array) -> void:
	if row.size() < 2:
		return
	var first := row[0] as Dictionary
	var second := row[1] as Dictionary
	if str(first.get("trait_label", "")) != str(second.get("trait_label", "")):
		return
	for _attempt in range(4):
		second["modifiers"] = _roll_modifiers_for_depth(int(second.get("depth", 1)), str(second.get("room_type", "combat")))
		_refresh_route_metadata(second)
		if str(first.get("trait_label", "")) != str(second.get("trait_label", "")):
			row[1] = second
			return
	row[1] = second

func _assign_route_rare_bonus(row: Array) -> void:
	if row.size() < 2:
		for node_index in range(row.size()):
			if row[node_index] is Dictionary:
				var single_node: Dictionary = row[node_index]
				single_node["rare_bonus"] = 0.0
				single_node["rare_chance"] = _rare_chance_for_depth(int(single_node.get("depth", 1)), 0.0)
				row[node_index] = single_node
		return
	var best_index := -1
	var best_score := -1
	var tied := false
	for node_index in range(row.size()):
		if not (row[node_index] is Dictionary):
			continue
		var node: Dictionary = row[node_index]
		var score := int(node.get("danger_score", 0))
		if score > best_score:
			best_score = score
			best_index = node_index
			tied = false
		elif score == best_score:
			tied = true
	for node_index in range(row.size()):
		if not (row[node_index] is Dictionary):
			continue
		var node: Dictionary = row[node_index]
		var bonus := RARE_NUDGE if not tied and node_index == best_index else 0.0
		node["rare_bonus"] = bonus
		node["rare_chance"] = _rare_chance_for_depth(int(node.get("depth", 1)), bonus)
		row[node_index] = node

func _refresh_route_metadata(node: Dictionary) -> void:
	var danger_score := _danger_score_for(node)
	var route_trait := _trait_for(node)
	node["danger_score"] = danger_score
	node["danger_pips"] = _danger_pips_for_score(danger_score)
	node["trait_label"] = str(route_trait.get("label", TRAIT_FALLBACK["label"]))
	node["trait_icon"] = str(route_trait.get("icon", TRAIT_FALLBACK["icon"]))
	node["rare_bonus"] = float(node.get("rare_bonus", 0.0))
	node["rare_chance"] = _rare_chance_for_depth(int(node.get("depth", 1)), float(node.get("rare_bonus", 0.0)))

func _danger_score_for(node: Dictionary) -> int:
	var minor_mods := 0
	var major_mods := 0
	for mod_id_variant in (node.get("modifiers", []) as Array):
		var mod_id := str(mod_id_variant)
		var category := str((_modifiers_by_id.get(mod_id, {}) as Dictionary).get("category", "minor"))
		if category == "major":
			major_mods += 1
		else:
			minor_mods += 1
	var enemy_pool: Array = node.get("enemy_pool", []) as Array
	return minor_mods + major_mods * 2 + clampi(enemy_pool.size() - 2, 0, 2)

func _danger_pips_for_score(danger_score: int) -> int:
	if danger_score <= 1:
		return 1
	if danger_score <= 3:
		return 2
	return 3

func _trait_for(node: Dictionary) -> Dictionary:
	var modifiers: Array = node.get("modifiers", []) as Array
	for mod_id in ["fire_floor", "ice_zone", "mine_field", "shrinking_arena"]:
		if modifiers.has(mod_id):
			return _trait_for_modifier(mod_id)
	for mod_id in ["swarm", "shielded", "enemy_speed", "accelerating_waves", "explosive_death"]:
		if modifiers.has(mod_id):
			return _trait_for_modifier(mod_id)
	return TRAIT_FALLBACK.duplicate()

func _trait_for_modifier(mod_id: String) -> Dictionary:
	match mod_id:
		"fire_floor":
			return {"label": "Hazard zone", "icon": "flame"}
		"ice_zone":
			return {"label": "Frost field", "icon": "snow"}
		"mine_field":
			return {"label": "Scanlines", "icon": "scan"}
		"shrinking_arena":
			return {"label": "Closing walls", "icon": "shrink"}
		"swarm":
			return {"label": "Swarm", "icon": "swarm"}
		"shielded":
			return {"label": "Fortified", "icon": "shield"}
		"enemy_speed":
			return {"label": "Frenzied", "icon": "bolt"}
		"accelerating_waves":
			return {"label": "Escalating", "icon": "rising"}
		"explosive_death":
			return {"label": "Volatile", "icon": "bomb"}
		_:
			return TRAIT_FALLBACK.duplicate()

func _rare_chance_for_depth(depth: int, rare_bonus: float = 0.0) -> float:
	var base_chance := lerpf(0.20, 0.45, clampf(float(depth - 1) / 19.0, 0.0, 1.0))
	return clampf(base_chance + rare_bonus, 0.0, RARE_CHANCE_CAP)

func _build_route_option_signature(node: Dictionary) -> String:
	var enemy_pool: Array = (node.get("enemy_pool", []) as Array).duplicate()
	enemy_pool.sort()
	var modifiers: Array = (node.get("modifiers", []) as Array).duplicate()
	modifiers.sort()
	return "%s|%s|%s" % [
		str(node.get("room_type", "combat")),
		",".join(PackedStringArray(enemy_pool)),
		",".join(PackedStringArray(modifiers)),
	]

func _build_distinct_modifier_load(node: Dictionary, seen_signatures: Dictionary) -> Array:
	var base_modifiers: Array = (node.get("modifiers", []) as Array).duplicate()
	var candidate_ids := _get_modifier_ids_by_category("minor")
	candidate_ids.append_array(_get_modifier_ids_by_category("major"))
	candidate_ids.sort()
	for modifier_id in candidate_ids:
		if base_modifiers.has(modifier_id):
			continue
		var candidate_modifiers := base_modifiers.duplicate()
		candidate_modifiers.append(modifier_id)
		var candidate_node := node.duplicate(true)
		candidate_node["modifiers"] = candidate_modifiers
		var signature := _build_route_option_signature(candidate_node)
		if not seen_signatures.has(signature):
			return candidate_modifiers
	return []

func _roll_modifiers_for_depth(room_number: int, room_type: String) -> Array:
	if room_type == "combat" and room_number <= 1:
		return []
	var depth_ratio := clampf(float(room_number) / 20.0, 0.0, 1.0)
	var minor_max := 1 + int(round(depth_ratio))
	var major_min := int(floor(depth_ratio + 0.0001))
	var major_max := 1 + int(round(depth_ratio))
	if room_type != "combat":
		major_min += 1
	return _roll_modifier_selection(1, minor_max, major_min, major_max)

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

func _get_current_step_node_ids() -> Array:
	var reachable: Array = []
	if node_map.is_empty():
		return reachable
	var step_index := clampi(current_step_index, 0, node_map.size() - 1)
	for node in node_map[step_index]:
		if node is Dictionary:
			reachable.append(str((node as Dictionary).get("id", "")))
	return reachable

func _advance_to_next_step() -> void:
	current_step_index += 1
	# Keep only the current step so node_map / _node_lookup stay bounded over a long
	# continuation run (the clamp in _get_current_step_node_ids handles the >0 step index).
	node_map = [_build_choice_step(current_step_index + 1)]
	_rebuild_node_lookup()
	reachable_node_ids = _get_current_step_node_ids()
	current_node = {}
	current_node_id = ""

func _build_default_debug_run_setup() -> Dictionary:
	return {
		"enabled": false,
		"launch_mode": "normal_run",
		"room_type": "combat",
		"room_objective": "kill_all",
		"enemy_mix": "mixed",
		"modifiers": [],
		"starting_mutations": [],
		"starting_level": 0,
		"starting_xp": 0,
		"player_classes": [],
		"player_weapons": [],
		"player_abilities": [],
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

func _apply_debug_starting_progress() -> void:
	if not bool(debug_run_setup.get("enabled", false)):
		return
	xp_level = max(int(debug_run_setup.get("starting_level", 0)), 0)
	xp_to_next_level = 200 + (xp_level * 150)
	xp_current = max(int(debug_run_setup.get("starting_xp", 0)), 0)
	while xp_current >= xp_to_next_level:
		xp_current -= xp_to_next_level
		xp_level += 1
		xp_pending_levelups += 1
		xp_to_next_level = 200 + (xp_level * 150)

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
