extends Node

const ModifierEngineData = preload("res://scripts/game/ModifierEngine.gd")
const PlayerInventoryData = preload("res://scripts/game/PlayerInventory.gd")
const RecipeEngineData = preload("res://scripts/game/RecipeEngine.gd")
const PASSIVES_DATA_PATH = "res://data/passives.json"
const WEAPONS_DATA_PATH = "res://data/weapons.json"
const RUN_LENGTH_MIN := 5
const RUN_LENGTH_MAX := 7
const MAX_CONSECUTIVE_COMBATS := 3
const MIN_COMBAT_ROOMS_BEFORE_BOSS := 2
const BASE_GOLD_COMBAT := 2
const BASE_GOLD_ELITE := 3
const GOLD_PER_STEP := 0.5
const GAUNTLET_ROOM_CHANCE := 0.5
const MAP_COLUMN_COUNT := 5
const START_ROW_COLUMNS := [1, 2, 3]
const GLOBAL_PRIMARY_FIRE_INTERVAL_MULT := 0.8
const GLOBAL_SECONDARY_COOLDOWN_MULT := 0.8
const VALID_WEAPON_TAGS: Array = [
	"projectile", "spread", "explosive",
	"cone", "beam", "chain",
	"tick_damage", "heat", "knockback", "status"
]
const BEHAVIOR_TAGS: Array = ["projectile", "cone", "beam", "chain"]

var player_configs: Array = []
var player_health_states: Array = []
var node_map: Array = []
var current_step_index: int = 0
var current_node: Dictionary = {}
var current_node_id: String = ""
var visited_node_ids: Array = []
var reachable_node_ids: Array = []
var rooms_completed: int = 0
var gold: int = 0
var player_inventories: Array = []
var shop_offers_by_player: Dictionary = {}
var run_outcome: String = "in_progress"
var run_mode: String = "normal"
var debug_run_setup: Dictionary = {}

var _modifier_engine = ModifierEngineData.new()
var _recipe_engine = RecipeEngineData.new()
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _passives: Array = []
var _passives_by_id: Dictionary = {}
var _weapons: Array = []
var _weapons_by_id: Dictionary = {}
var _node_lookup: Dictionary = {}
var _selected_node_id: String = ""

func _ready() -> void:
	_load_passives()
	_load_weapons()

func start_new_run(configs: Array, debug_options: Dictionary = {}) -> void:
	_load_passives()
	_load_weapons()
	_random.randomize()
	_recipe_engine.reset_history()
	debug_run_setup = _build_default_debug_run_setup()
	_apply_debug_start_options(debug_options)
	player_configs = []
	for config in configs:
		player_configs.append(config)

	player_health_states = []
	for _index in range(player_configs.size()):
		player_health_states.append({
			"current": 50,
			"max": 50,
		})

	node_map = _generate_node_map()
	_rebuild_node_lookup()
	print("[RunState] Run seed: %d | Rows: %d" % [_random.seed, node_map.size()])
	current_step_index = 0
	current_node = {}
	current_node_id = ""
	_selected_node_id = ""
	visited_node_ids = []
	reachable_node_ids = _get_starting_reachable_node_ids()
	rooms_completed = 0
	run_mode = _normalize_run_mode(str(debug_options.get("run_mode", "normal")))
	player_inventories = _build_default_player_inventories(player_configs.size())
	shop_offers_by_player = {}
	_apply_debug_loadout_overrides()
	_sync_aggregate_gold()
	run_outcome = "in_progress"

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

func select_map_node(node_id: String) -> bool:
	if not reachable_node_ids.has(node_id):
		return false
	var node := get_map_node(node_id)
	if node.is_empty():
		return false
	current_node = node
	_selected_node_id = node_id
	return true

func resolve_current_noncombat_node() -> Dictionary:
	if current_node.is_empty():
		return _build_outcome("No node selected.", "No node selected.", "next")

	var room_type := str(current_node.get("room_type", "rest"))
	var room_title := str(current_node.get("title", "Room"))
	var room_description := str(current_node.get("description", ""))
	var outcome := _build_outcome(room_title, room_description, "next")

	match room_type:
		"shop":
			outcome["summary"] = "%s\nShop rooms now run in-world." % room_description
			outcome["button_text"] = "Enter Shop"
		_:
			var result_text := _apply_reward(current_node.get("reward", {}))
			_apply_post_room_recovery()
			if not is_debug_single_room_mode():
				_advance_progress()
			outcome["summary"] = "%s\n%s" % [room_description, result_text]

	if is_debug_single_room_mode():
		outcome["title"] = "Encounter Complete"
		outcome["post_action"] = "return_to_menu"
		outcome["button_text"] = "Return to Encounter Builder"

	return outcome

func resolve_current_combat_victory(health_states: Array, clear_context: Dictionary = {}) -> Dictionary:
	if current_node.is_empty():
		return _build_outcome("No combat node selected.", "No combat node selected.", "next")

	set_player_health_states(health_states)
	var room_title := str(current_node.get("title", "Room"))
	var room_type := str(current_node.get("room_type", "combat"))
	var summary_lines := ["Room cleared."]
	var outcome := _build_outcome(room_title, "", "next")
	var gold_gain := int(current_node.get("currency_reward", 0))
	if room_type == "shop":
		var shop_summary: String = str(clear_context.get("shop_summary", "")).strip_edges()
		if shop_summary.is_empty():
			shop_summary = "The team left the shop."
		outcome["summary"] = shop_summary
		_advance_progress()
		return outcome
	if gold_gain > 0:
		award_gold_to_all(gold_gain)
		summary_lines.append("Each player gained %d Gold." % gold_gain)
		summary_lines.append(get_gold_summary_text())
	_apply_post_room_recovery()

	outcome = _build_outcome(room_title, "\n".join(summary_lines), "next")
	var reward: Dictionary = current_node.get("reward", {}).duplicate(true)
	if str(reward.get("type", "")) == "loot_choice":
		var loot_summary: String = str(clear_context.get("loot_summary", "")).strip_edges()
		if loot_summary.is_empty():
			loot_summary = "Loot resolved."
		outcome["summary"] = "%s\n%s" % [outcome["summary"], loot_summary]
	else:
		var result_text := _apply_reward(reward)
		outcome["summary"] = "%s\n%s" % [outcome["summary"], result_text]

	if is_debug_single_room_mode():
		outcome["title"] = "Encounter Cleared"
		outcome["post_action"] = "return_to_menu"
		outcome["button_text"] = "Return to Encounter Builder"
		return outcome

	_advance_progress()
	if room_type == "boss" or is_run_complete():
		run_outcome = "won"
		outcome["title"] = "Run Victory"
		outcome["summary"] = "Boss defeated.\n%s" % get_run_summary_text()
		outcome["post_action"] = "return_to_menu"
		outcome["button_text"] = "Return to Menu"
	return outcome

func set_player_health_states(health_states: Array) -> void:
	player_health_states = []
	for state in health_states:
		player_health_states.append({
			"current": int(state.get("current", 1)),
			"max": int(state.get("max", 50)),
		})

func _apply_post_room_recovery() -> void:
	if not is_easy_mode():
		return
	for state in player_health_states:
		state["current"] = int(state.get("max", 50))

func _normalize_run_mode(value: String) -> String:
	return "easy" if value == "easy" else "normal"

func is_run_complete() -> bool:
	return reachable_node_ids.is_empty() and not current_node_id.is_empty()

func is_debug_single_room_mode() -> bool:
	return bool(debug_run_setup.get("enabled", false)) and str(debug_run_setup.get("launch_mode", "normal_run")) == "single_room"

func get_run_summary_text() -> String:
	var summary_lines: Array = ["Rooms cleared: %d" % rooms_completed, "Gold wallets:"]
	for inventory_index in range(player_inventories.size()):
		var inventory: PlayerInventoryData = player_inventories[inventory_index]
		summary_lines.append("P%d: %d" % [inventory_index + 1, inventory.gold])
	return "\n".join(summary_lines)

func get_player_runtime_loadout() -> Dictionary:
	return get_player_runtime_loadout_for(0)

func get_player_runtime_loadout_for(player_index: int) -> Dictionary:
	var inventory: PlayerInventoryData = _get_inventory(player_index)
	var global_effect_state: Dictionary = _build_global_effect_state(inventory)
	var global_trigger_passives: Array = _build_global_trigger_passives(inventory)
	var primary_slots: Array = _build_primary_runtime_slot_array(inventory.primary_slots, inventory, "rifle")
	var secondary_slots: Array = _build_secondary_runtime_slot_array(inventory.secondary_slots, inventory, "mine")
	var selected_primary_index: int = clampi(inventory.selected_primary, 0, max(primary_slots.size() - 1, 0))
	var selected_secondary_index: int = clampi(inventory.selected_secondary, 0, max(secondary_slots.size() - 1, 0))
	var selected_primary: Dictionary = primary_slots[selected_primary_index] if selected_primary_index < primary_slots.size() and primary_slots[selected_primary_index] is Dictionary else {}
	var selected_secondary: Dictionary = secondary_slots[selected_secondary_index] if selected_secondary_index < secondary_slots.size() and secondary_slots[selected_secondary_index] is Dictionary else {}
	var loadout: Dictionary = {
		"move_speed": 260.0 * float(global_effect_state.get("move_speed_mult", 1.0)),
		"global_trigger_passives": global_trigger_passives.duplicate(true),
		"primary_slots": primary_slots,
		"secondary_slots": secondary_slots,
		"selected_primary": selected_primary_index,
		"selected_secondary": selected_secondary_index,
		"primary_profile_name": str(selected_primary.get("primary_profile_name", selected_primary.get("label", "Rifle"))),
		"secondary_profile_name": str(selected_secondary.get("secondary_profile_name", selected_secondary.get("label", "Mine"))),
		"primary_behavior": str(selected_primary.get("primary_behavior", "projectile")),
		"primary_weapon_tags": (selected_primary.get("primary_weapon_tags", []) as Array).duplicate(true),
		"primary_trigger_passives": (selected_primary.get("primary_trigger_passives", []) as Array).duplicate(true),
		"primary_amount": int(selected_primary.get("primary_amount", 1)),
		"primary_projectile_count": int(selected_primary.get("primary_projectile_count", 1)),
		"primary_spread_radians": float(selected_primary.get("primary_spread_radians", 0.0)),
		"primary_fire_interval": float(selected_primary.get("primary_fire_interval", 0.27)),
		"projectile_speed": float(selected_primary.get("projectile_speed", 540.0)),
		"projectile_damage": int(selected_primary.get("projectile_damage", 1)),
		"primary_range": float(selected_primary.get("primary_range", 0.0)),
		"primary_area": float(selected_primary.get("primary_area", 0.0)),
		"secondary_projectile_count": int(selected_secondary.get("secondary_projectile_count", 1)),
		"secondary_spread_radians": float(selected_secondary.get("secondary_spread_radians", 0.0)),
		"secondary_cooldown": float(selected_secondary.get("secondary_cooldown", 4.0)),
		"secondary_projectile_speed": float(selected_secondary.get("secondary_projectile_speed", 0.0)),
		"secondary_damage": int(selected_secondary.get("secondary_damage", 1)),
		"secondary_projectile_kind": str(selected_secondary.get("secondary_projectile_kind", "mine")),
		"secondary_explosion_radius": float(selected_secondary.get("secondary_explosion_radius", 92.0)),
		"secondary_fuse_time": float(selected_secondary.get("secondary_fuse_time", 12.0)),
		"secondary_gravity_force": float(selected_secondary.get("secondary_gravity_force", 0.0)),
		"secondary_pulse_count": int(selected_secondary.get("secondary_pulse_count", 1)),
		"secondary_pulse_interval": float(selected_secondary.get("secondary_pulse_interval", 0.18)),
		"secondary_cluster_blast_count": int(selected_secondary.get("secondary_cluster_blast_count", 0)),
		"secondary_cluster_spread_radius": float(selected_secondary.get("secondary_cluster_spread_radius", 52.0)),
		"secondary_proximity_radius": float(selected_secondary.get("secondary_proximity_radius", 52.0)),
	}
	return loadout

func get_player_passive_display_data(player_index: int) -> Array:
	var inventory: PlayerInventoryData = _get_inventory(player_index)
	var passive_entries: Array = []
	if inventory == null:
		return passive_entries
	for passive_id in inventory.passives:
		var passive_entry: Dictionary = _get_catalog_entry(str(passive_id))
		var passive_name: String = str(passive_entry.get("name", str(passive_id))).strip_edges()
		if passive_name.is_empty():
			continue
		passive_entries.append({
			"id": str(passive_id),
			"name": passive_name,
		})
	return passive_entries

func prepare_shop_room_offers() -> void:
	shop_offers_by_player = {}
	for player_index in range(player_inventories.size()):
		shop_offers_by_player[player_index] = _roll_shop_offers_for_player(player_index, 3)

func get_shop_offers_for(player_index: int) -> Array:
	var clamped_index: int = clampi(player_index, 0, max(player_inventories.size() - 1, 0))
	if not shop_offers_by_player.has(clamped_index):
		shop_offers_by_player[clamped_index] = _roll_shop_offers_for_player(clamped_index, 3)
	return (shop_offers_by_player[clamped_index] as Array).duplicate(true)

func preview_shop_purchase(player_index: int, item_id: String) -> Dictionary:
	var entry: Dictionary = _get_catalog_entry(item_id)
	if entry.is_empty():
		return {"success": false, "summary": "That offer is no longer available."}
	var inventory: PlayerInventoryData = _get_inventory(player_index)
	var cost: int = _get_catalog_entry_cost(entry)
	if inventory.gold < cost:
		return {"success": false, "summary": "P%d needs %d Gold but only has %d." % [player_index + 1, cost, inventory.gold]}
	match str(entry.get("type", "")):
		"passive":
			if not bool(entry.get("stackable", false)) and inventory.has_passive(str(entry.get("id", ""))):
				return {"success": false, "summary": "%s is already owned." % str(entry.get("name", "Passive"))}
		"primary_weapon", "secondary_weapon":
			var weapon_id: String = str(entry.get("id", ""))
			var max_level: int = int(entry.get("max_level", 5))
			if not inventory.can_take_weapon(weapon_id, max_level):
				return {"success": false, "summary": "%s is already max level." % str(entry.get("name", "Weapon"))}
			if not inventory.owns_weapon(weapon_id):
				var slot_type: String = "secondary" if str(entry.get("type", "")) == "secondary_weapon" else "primary"
				var slot_group: Array = inventory.secondary_slots if slot_type == "secondary" else inventory.primary_slots
				var has_empty_slot: bool = false
				for slot_entry in slot_group:
					if slot_entry == null:
						has_empty_slot = true
						break
				if not has_empty_slot:
					return {
						"success": true,
						"requires_replacement": true,
						"slot_type": slot_type,
						"slot_count": slot_group.size(),
						"entry": entry.duplicate(true),
					}
	return {"success": true, "requires_replacement": false, "entry": entry.duplicate(true)}

func complete_shop_purchase(player_index: int, item_id: String, slot_type: String = "", slot_index: int = -1, cancel_purchase: bool = false) -> Dictionary:
	var entry: Dictionary = _get_catalog_entry(item_id)
	if entry.is_empty():
		return {"success": false, "summary": "That offer is no longer available."}
	if cancel_purchase:
		return {"success": false, "summary": "Purchase canceled."}
	var inventory: PlayerInventoryData = _get_inventory(player_index)
	var cost: int = _get_catalog_entry_cost(entry)
	if inventory.gold < cost:
		return {"success": false, "summary": "Not enough Gold."}
	inventory.gold -= cost
	var result_summary: String = ""
	match str(entry.get("type", "")):
		"passive":
			var passive_result: Dictionary = _apply_passive_to_player(player_index, entry, player_health_states[player_index] if player_index < player_health_states.size() and player_health_states[player_index] is Dictionary else {})
			result_summary = str(passive_result.get("summary", "%s purchased." % str(entry.get("name", "Passive"))))
		"primary_weapon", "secondary_weapon":
			if slot_index >= 0:
				var normalized_slot_type: String = "secondary" if slot_type == "secondary" else "primary"
				inventory.replace_weapon(normalized_slot_type, slot_index, str(entry.get("id", "")))
				result_summary = "Purchased %s and replaced %s slot %d." % [str(entry.get("name", "Weapon")), normalized_slot_type, slot_index + 1]
			else:
				var weapon_result: Dictionary = _apply_weapon_offer_to_player(player_index, entry)
				result_summary = str(weapon_result.get("summary", "%s purchased." % str(entry.get("name", "Weapon"))))
	_sync_aggregate_gold()
	_remove_shop_offer(player_index, item_id)
	return {
		"success": true,
		"summary": "%s\nP%d Gold: %d" % [result_summary, player_index + 1, inventory.gold],
	}

func roll_loot_drop() -> Dictionary:
	var choices: Array = _roll_item_choices("reward", 1)
	if choices.is_empty():
		return {}
	return (choices[0] as Dictionary).duplicate(true)

func resolve_loot_vote(votes: Dictionary, item: Dictionary, health_states: Array = []) -> Dictionary:
	if item.is_empty():
		return {
			"winner_index": -1,
			"results": [],
			"summary": "The loot drop vanished.",
			"health_states": health_states.duplicate(true),
		}

	var resolved_health_states: Array = []
	for state in health_states:
		if state is Dictionary:
			resolved_health_states.append((state as Dictionary).duplicate(true))

	var scrap_gold: int = max(1, int(item.get("scrap_gold_value", 1)))
	var resolved_votes: Dictionary = {}
	var takers: Array = []
	var blocked_players: Array = []

	for player_index in range(player_inventories.size()):
		var vote_value: String = str(votes.get(player_index, "scrap"))
		var final_vote: String = "take" if vote_value == "take" else "scrap"
		if final_vote == "take" and not _can_inventory_take_entry(player_index, item):
			final_vote = "scrap"
			blocked_players.append(player_index)
		resolved_votes[player_index] = final_vote
		if final_vote == "take":
			takers.append(player_index)

	var winner_index: int = -1
	var contested: bool = takers.size() > 1
	if takers.size() == 1:
		winner_index = int(takers[0])
	elif takers.size() > 1:
		winner_index = _roll_contested_loot_winner(takers)

	var results: Array = []
	var summary_lines: Array = ["Loot Drop: %s" % str(item.get("name", "Loot"))]
	var replacement_request: Dictionary = {}
	if contested:
		summary_lines.append("Contested roll winner: P%d." % (winner_index + 1))
	elif winner_index >= 0:
		summary_lines.append("P%d took the item." % (winner_index + 1))
	else:
		summary_lines.append("The item was scrapped.")

	if not blocked_players.is_empty():
		var blocked_labels: Array = []
		for player_value in blocked_players:
			blocked_labels.append("P%d" % (int(player_value) + 1))
		summary_lines.append("%s could not take this item and were treated as Scrap." % ", ".join(blocked_labels))

	for player_index in range(player_inventories.size()):
		var inventory: PlayerInventoryData = player_inventories[player_index]
		if player_index == winner_index:
			var player_health_state: Dictionary = {}
			if player_index < resolved_health_states.size() and resolved_health_states[player_index] is Dictionary:
				player_health_state = (resolved_health_states[player_index] as Dictionary).duplicate(true)
			var apply_result: Dictionary = _apply_catalog_entry_to_player(player_index, item, player_health_state)
			if player_index < resolved_health_states.size():
				resolved_health_states[player_index] = player_health_state
			results.append({
				"player_index": player_index,
				"outcome": str(apply_result.get("outcome", "took_item")),
				"gold_gained": 0,
			})
			if str(apply_result.get("outcome", "")) == "needs_replacement":
				replacement_request = {
					"player_index": player_index,
					"entry": item.duplicate(true),
					"slot_type": str(apply_result.get("slot_type", "")),
					"slot_count": int(apply_result.get("slot_count", 2)),
				}
			var player_summary: String = str(apply_result.get("summary", "")).strip_edges()
			if not player_summary.is_empty():
				summary_lines.append("P%d: %s" % [player_index + 1, player_summary])
		else:
			inventory.gold += scrap_gold
			results.append({
				"player_index": player_index,
				"outcome": "got_gold",
				"gold_gained": scrap_gold,
			})
			summary_lines.append("P%d gained %d Gold." % [player_index + 1, scrap_gold])

	_sync_aggregate_gold()
	if replacement_request.is_empty():
		summary_lines.append(get_gold_summary_text())
	return {
		"winner_index": winner_index,
		"results": results,
		"summary": "\n".join(summary_lines),
		"resolved_votes": resolved_votes,
		"health_states": resolved_health_states,
		"replacement_request": replacement_request,
	}

func _generate_node_map() -> Array:
	if is_debug_single_room_mode():
		return _build_debug_node_map()
	var preboss_row_count := _random.randi_range(RUN_LENGTH_MIN, RUN_LENGTH_MAX)
	var support_rows: Array = []
	for row_index in range(1, preboss_row_count):
		support_rows.append(row_index)
	if support_rows.size() < 2:
		print("[RunState] Support row generation underflow. Falling back to default pattern.")
		return _generate_fallback_node_map()
	support_rows.shuffle()
	var rest_row: int = int(support_rows.pop_back())
	var shop_row: int = int(support_rows.pop_back())

	var rows: Array = []
	var previous_columns: Array = START_ROW_COLUMNS.duplicate()
	rows.append(_build_row_nodes(0, previous_columns, _build_row_room_types(0, previous_columns.size(), -1, -1)))

	for row_index in range(1, preboss_row_count):
		var row_count := _random.randi_range(2, 4)
		var row_columns := _generate_row_columns(previous_columns, row_count)
		rows.append(_build_row_nodes(row_index, row_columns, _build_row_room_types(row_index, row_columns.size(), rest_row, shop_row)))
		previous_columns = row_columns

	rows.append([
		_build_node(preboss_row_count, 2, _build_room_template("boss")),
	])
	_link_row_connections(rows)

	if _validate_node_map(rows):
		return rows
	print("[RunState] Generated node map failed validation. Falling back to default pattern.")
	return _generate_fallback_node_map()

func _generate_fallback_node_map() -> Array:
	var row_columns := [
		[1, 2, 3],
		[1, 2, 3],
		[0, 1, 2],
		[1, 2],
		[1, 2, 3],
		[2],
	]
	var row_types := [
		["combat", "combat", "combat"],
		["combat", "rest", "combat"],
		["combat", "shop", "elite"],
		["elite", "combat"],
		["combat", "elite", "combat"],
		["boss"],
	]
	var rows: Array = []
	for row_index in range(row_types.size()):
		rows.append(_build_row_nodes(row_index, row_columns[row_index], row_types[row_index]))
	_link_row_connections(rows)
	return rows

func _build_room_template(room_type: String) -> Dictionary:
	match room_type:
		"combat", "elite":
			return {
				"room_type": room_type,
				"reward": {"type": "loot_choice", "label": "Resolve the loot drop"},
			}
		"rest":
			return {
				"room_type": "rest",
				"reward": {"type": "heal_all", "amount": 20, "label": "Recover 20 HP"},
			}
		"shop":
			return {
				"room_type": "shop",
				"reward": {"type": "shop", "label": "Personal shop offers"},
			}
		"boss":
			return {
				"room_type": "boss",
				"reward": {"type": "none", "label": "Defeat the boss"},
			}
		_:
			return {"room_type": room_type, "reward": {"type": "none", "label": "No reward"}}

func _normalize_primary_room_types(primary_types: Array) -> void:
	for index in range(primary_types.size()):
		if index < MAX_CONSECUTIVE_COMBATS:
			continue
		var sequence_is_pressure := true
		for check_index in range(index - MAX_CONSECUTIVE_COMBATS, index + 1):
			if not _is_pressure_room_type(str(primary_types[check_index])):
				sequence_is_pressure = false
				break
		if not sequence_is_pressure:
			continue
		var replacement_index := index - 1
		primary_types[replacement_index] = _pick_support_room_type(primary_types)

func _pick_support_room_type(primary_types: Array) -> String:
	var rest_count := 0
	var shop_count := 0
	for room_type_value in primary_types:
		var room_type: String = str(room_type_value)
		if room_type == "rest":
			rest_count += 1
		elif room_type == "shop":
			shop_count += 1
	if rest_count <= shop_count:
		return "rest"
	return "shop"

func _pick_alternative_type(primary_type: String) -> String:
	match primary_type:
		"combat":
			return _pick_random_room_type(["rest", "shop", "elite"])
		"elite":
			return _pick_random_room_type(["combat", "shop", "rest"])
		"rest":
			return _pick_random_room_type(["combat", "elite"])
		"shop":
			return _pick_random_room_type(["combat", "elite"])
		_:
			return primary_type

func _pick_random_room_type(room_types: Array) -> String:
	if room_types.is_empty():
		return "combat"
	return str(room_types[_random.randi_range(0, room_types.size() - 1)])

func _build_row_room_types(row_index: int, row_count: int, rest_row: int, shop_row: int) -> Array:
	var room_types: Array = []
	if row_index == 0:
		for _index in range(row_count):
			room_types.append("combat")
		return room_types

	for _index in range(row_count):
		room_types.append("elite" if _random.randf() < 0.3 else "combat")
	if row_index == rest_row:
		room_types[_random.randi_range(0, room_types.size() - 1)] = "rest"
	elif row_index == shop_row:
		room_types[_random.randi_range(0, room_types.size() - 1)] = "shop"
	return room_types

func _generate_row_columns(previous_columns: Array, row_count: int) -> Array:
	var candidate_starts: Array = []
	var previous_min := int(previous_columns.front())
	var previous_max := int(previous_columns.back())
	for start_column in range(MAP_COLUMN_COUNT - row_count + 1):
		var end_column := start_column + row_count - 1
		if start_column < previous_min - 1:
			continue
		if end_column > previous_max + 1:
			continue
		candidate_starts.append(start_column)
	if candidate_starts.is_empty():
		candidate_starts.append(clampi(previous_min, 0, MAP_COLUMN_COUNT - row_count))
	var chosen_start := int(candidate_starts[_random.randi_range(0, candidate_starts.size() - 1)])
	var columns: Array = []
	for offset in range(row_count):
		columns.append(chosen_start + offset)
	return columns

func _build_row_nodes(row_index: int, columns: Array, room_types: Array) -> Array:
	var row_nodes: Array = []
	for column_index in range(columns.size()):
		row_nodes.append(_build_node(row_index, int(columns[column_index]), _build_room_template(str(room_types[column_index]))))
	return row_nodes

func _link_row_connections(rows: Array) -> void:
	for row_index in range(rows.size() - 1):
		var current_row: Array = rows[row_index]
		var next_row: Array = rows[row_index + 1]
		for node in current_row:
			if not (node is Dictionary):
				continue
			var next_node_ids: Array = []
			var current_column := int(node.get("column", 0))
			for next_node in next_row:
				if not (next_node is Dictionary):
					continue
				if abs(current_column - int(next_node.get("column", 0))) <= 1:
					next_node_ids.append(str(next_node.get("id", "")))
			node["next_node_ids"] = next_node_ids

func _get_starting_reachable_node_ids() -> Array:
	if node_map.is_empty():
		return []
	var reachable: Array = []
	for node in node_map[0]:
		if node is Dictionary:
			reachable.append(str(node.get("id", "")))
	return reachable

func _compute_gold_reward(room_type: String, step_index: int) -> int:
	var step_bonus := int(floor(float(step_index) * GOLD_PER_STEP))
	match room_type:
		"combat":
			return BASE_GOLD_COMBAT + step_bonus
		"elite":
			return BASE_GOLD_ELITE + step_bonus
		_:
			return 0

func _compute_survival_duration(step_index: int, is_elite: bool) -> float:
	var duration := 16.0 + float(step_index) * 1.5
	if is_elite:
		duration += 4.0
	return duration

func _compute_spawn_interval(step_index: int, is_elite: bool) -> float:
	var interval := 4.0 - float(step_index) * 0.2
	if is_elite:
		interval -= 0.4
	return max(interval, 2.8)

func _roll_room_objective(step_index: int) -> String:
	if step_index < 2:
		return "survive"
	if _random.randf() < GAUNTLET_ROOM_CHANCE:
		return "capture_the_hill"
	return "survive"

func _compute_generator_spitter_chance(step_index: int, is_elite: bool) -> float:
	if is_elite:
		return 0.35 if step_index >= 4 else 0.25
	return 0.15 if step_index >= 4 else 0.0

func _validate_node_map(map: Array) -> bool:
	if map.is_empty():
		return false
	var last_step = map[map.size() - 1]
	if not (last_step is Array) or last_step.size() != 1:
		return false
	var boss_node = last_step[0]
	if not (boss_node is Dictionary) or str(boss_node.get("room_type", "")) != "boss":
		return false

	var pressure_nodes := 0
	var has_rest := false
	var has_shop := false
	var lookup: Dictionary = {}
	for row_index in range(map.size()):
		var step_options = map[row_index]
		if not (step_options is Array) or step_options.is_empty():
			return false
		for option in step_options:
			if not (option is Dictionary):
				return false
			var node_id := str(option.get("id", ""))
			if node_id.is_empty():
				return false
			lookup[node_id] = option
			var room_type := str(option.get("room_type", ""))
			if _is_pressure_room_type(room_type):
				pressure_nodes += 1
			elif room_type == "rest":
				has_rest = true
			elif room_type == "shop":
				has_shop = true
			if row_index < map.size() - 1 and (option.get("next_node_ids", []) as Array).is_empty():
				return false

	if pressure_nodes < MIN_COMBAT_ROOMS_BEFORE_BOSS:
		return false
	if not (has_rest and has_shop):
		return false
	var reachable_from_start := _collect_reachable_node_ids(map, _extract_row_node_ids(map[0]), lookup)
	return reachable_from_start.has(str(boss_node.get("id", ""))) and _contains_reachable_room_type(reachable_from_start, lookup, "rest") and _contains_reachable_room_type(reachable_from_start, lookup, "shop")

func _is_pressure_room_type(room_type: String) -> bool:
	return room_type == "combat" or room_type == "elite"

func _build_node(step_index: int, column: int, template: Dictionary) -> Dictionary:
	var room_type := str(template.get("room_type", "combat"))
	var reward: Dictionary = template.get("reward", {}).duplicate(true)
	var is_elite := room_type == "elite"
	var node := {
		"id": "row_%d_col_%d" % [step_index, column],
		"row": step_index,
		"column": column,
		"step_index": step_index,
		"room_type": room_type,
		"reward": reward,
		"reward_label": str(template.get("reward_label", reward.get("label", "No reward"))),
		"currency_reward": _compute_gold_reward(room_type, step_index),
		"next_node_ids": [],
	}

	match room_type:
		"combat":
			var recipe: Dictionary = _recipe_engine.get_recipe_for_room(step_index, _get_forced_recipe_id())
			var combat_objective := str(template.get("room_objective", recipe.get("objective_hint", _roll_room_objective(step_index))))
			var recipe_layout: String = _recipe_engine.pick_from_pool(recipe.get("layout_pool", []))
			var recipe_modifier_id: String = _recipe_engine.pick_from_pool(recipe.get("modifier_pool", []))
			node["title"] = "Combat Room"
			node["room_objective"] = combat_objective
			node["modifier"] = _resolve_recipe_modifier(template, step_index, recipe_modifier_id, combat_objective)
			node["layout_id"] = _resolve_recipe_layout_id(template, combat_objective, recipe_layout)
			node["recipe_id"] = str(recipe.get("id", ""))
			node["enemy_weight_hint"] = str(recipe.get("enemy_weight_hint", "default"))
			node["wave_size_bonus"] = int(recipe.get("wave_size_bonus", 0))
			if combat_objective == "destroy_generators":
				node["description"] = "Destroy the generators, sweep the room, and collect the drops."
				node["generator_count"] = int(template.get("generator_count", 2))
				node["generator_spawn_interval"] = float(template.get("generator_spawn_interval", 3.2))
				node["generator_enemy_cap"] = int(template.get("generator_enemy_cap", 6))
				node["generator_spitter_chance"] = float(template.get("generator_spitter_chance", _compute_generator_spitter_chance(step_index, false)))
			elif combat_objective == "capture_the_hill":
				node["description"] = "Hold the capture zone under pressure until the meter fills."
				node["hill_capture_required"] = float(template.get("hill_capture_required", 8.0))
				node["hill_radius"] = float(template.get("hill_radius", 132.0))
				var hill_spawn_interval: float = float(recipe.get("spawn_interval_override", _compute_spawn_interval(step_index, false)))
				node["enemy_spawn_interval"] = float(template.get("enemy_spawn_interval", hill_spawn_interval))
			else:
				node["description"] = "Survive the timer and hold the room."
				var base_survival_duration: float = _compute_survival_duration(step_index, false) + float(recipe.get("survival_duration_bonus", 0.0))
				var base_spawn_interval: float = float(recipe.get("spawn_interval_override", _compute_spawn_interval(step_index, false)))
				node["survival_duration"] = float(template.get("survival_duration", base_survival_duration))
				node["enemy_spawn_interval"] = float(template.get("enemy_spawn_interval", base_spawn_interval))
			node["reward_label"] = "+%d Gold each + loot drop" % node["currency_reward"]
		"elite":
			var elite_recipe: Dictionary = _recipe_engine.get_recipe_for_room(step_index, _get_forced_recipe_id())
			var elite_objective := str(template.get("room_objective", elite_recipe.get("objective_hint", _roll_room_objective(step_index))))
			var elite_recipe_layout: String = _recipe_engine.pick_from_pool(elite_recipe.get("layout_pool", []))
			var elite_recipe_modifier_id: String = _recipe_engine.pick_from_pool(elite_recipe.get("modifier_pool", []))
			node["title"] = "Elite Room"
			node["room_objective"] = elite_objective
			node["modifier"] = _resolve_recipe_modifier(template, step_index, elite_recipe_modifier_id, elite_objective)
			node["layout_id"] = _resolve_recipe_layout_id(template, elite_objective, elite_recipe_layout)
			node["recipe_id"] = str(elite_recipe.get("id", ""))
			node["enemy_weight_hint"] = str(elite_recipe.get("enemy_weight_hint", "default"))
			node["wave_size_bonus"] = int(elite_recipe.get("wave_size_bonus", 0))
			if elite_objective == "destroy_generators":
				node["description"] = "Break the generators under pressure, then wipe the room."
				node["generator_count"] = int(template.get("generator_count", 3))
				node["generator_spawn_interval"] = float(template.get("generator_spawn_interval", 2.6))
				node["generator_enemy_cap"] = int(template.get("generator_enemy_cap", 8))
				node["generator_spitter_chance"] = float(template.get("generator_spitter_chance", _compute_generator_spitter_chance(step_index, true)))
			elif elite_objective == "capture_the_hill":
				node["description"] = "Capture the zone while elite pressure keeps closing in."
				node["hill_capture_required"] = float(template.get("hill_capture_required", 10.0))
				node["hill_radius"] = float(template.get("hill_radius", 140.0))
				var elite_hill_spawn_interval: float = float(elite_recipe.get("spawn_interval_override", _compute_spawn_interval(step_index, is_elite)))
				node["enemy_spawn_interval"] = float(template.get("enemy_spawn_interval", elite_hill_spawn_interval))
			else:
				node["description"] = "Survive the elite timer and break through the pressure."
				var elite_survival_duration: float = _compute_survival_duration(step_index, is_elite) + float(elite_recipe.get("survival_duration_bonus", 0.0))
				var elite_spawn_interval: float = float(elite_recipe.get("spawn_interval_override", _compute_spawn_interval(step_index, is_elite)))
				node["survival_duration"] = float(template.get("survival_duration", elite_survival_duration))
				node["enemy_spawn_interval"] = float(template.get("enemy_spawn_interval", elite_spawn_interval))
			node["reward_label"] = "+%d Gold each + loot drop" % node["currency_reward"]
		"rest":
			node["title"] = "Rest Room"
			node["currency_reward"] = 0
			node["modifier"] = {}
			node["description"] = "Take a breather and patch everyone up."
			node["reward_label"] = "Recover 20 HP"
		"shop":
			node["title"] = "Shop Room"
			node["currency_reward"] = 0
			node["modifier"] = {}
			node["description"] = "Enter the shop, browse personal offers, and ready up when done."
			node["reward_label"] = "Personal offers"
		"boss":
			node["title"] = "Crimson Gate"
			node["currency_reward"] = 0
			node["modifier"] = {}
			node["description"] = "Final room. Defeat the placeholder boss to finish the run."
			node["layout_id"] = str(template.get("layout_id", "boss_gate"))
			node["reward_label"] = "Finish the run"
		_:
			node["title"] = "Unknown Room"
			node["modifier"] = {}

	return node

func _apply_reward(reward: Dictionary) -> String:
	var reward_type := str(reward.get("type", "none"))
	match reward_type:
		"heal_all":
			var amount := int(reward.get("amount", 0))
			for state in player_health_states:
				state["current"] = min(int(state.get("current", 0)) + amount, int(state.get("max", 50)))
			return str(reward.get("label", "Recovered health"))
		_:
			return str(reward.get("label", "No reward"))

func _build_default_global_effect_state() -> Dictionary:
	return {
		"move_speed_mult": 1.0,
	}

func _build_default_primary_effect_state() -> Dictionary:
	return {
		"fire_rate_mult": 1.0,
		"projectile_speed_mult": 1.0,
		"damage_mult": 1.0,
		"damage_add": 0.0,
		"range_mult": 1.0,
		"area_mult": 1.0,
		"amount_add": 0,
		"pierce_count_add": 0,
	}

func _build_default_secondary_effect_state() -> Dictionary:
	return {
		"secondary_cooldown_mult": 1.0,
		"secondary_projectile_speed_mult": 1.0,
		"secondary_damage_bonus": 0.0,
		"secondary_explosion_radius_mult": 1.0,
	}

func _build_default_player_inventories(player_count: int) -> Array:
	var inventories: Array = []
	for player_index in range(player_count):
		var inventory := PlayerInventoryData.new()
		inventory.player_index = player_index
		inventory.primary_slots[0] = {"weapon_id": "rifle", "level": 1}
		inventory.secondary_slots[0] = {"weapon_id": "mine", "level": 1}
		inventories.append(inventory)
	return inventories

func _get_inventory(player_index: int) -> PlayerInventoryData:
	if player_inventories.is_empty():
		var fallback := PlayerInventoryData.new()
		fallback.primary_slots[0] = {"weapon_id": "rifle", "level": 1}
		fallback.secondary_slots[0] = {"weapon_id": "mine", "level": 1}
		return fallback
	var clamped_index: int = clampi(player_index, 0, player_inventories.size() - 1)
	return player_inventories[clamped_index] as PlayerInventoryData

func _build_global_effect_state(inventory: PlayerInventoryData) -> Dictionary:
	var effect_state: Dictionary = _build_default_global_effect_state()
	if inventory == null:
		return effect_state
	for passive_id in inventory.passives:
		var passive := _get_catalog_entry(str(passive_id))
		if passive.is_empty():
			continue
		var passive_effects: Dictionary = passive.get("passive_effects", {})
		if passive_effects.has("move_speed_mult"):
			effect_state["move_speed_mult"] = float(effect_state.get("move_speed_mult", 1.0)) * float(passive_effects.get("move_speed_mult", 1.0))
	return effect_state

func _build_global_trigger_passives(inventory: PlayerInventoryData) -> Array:
	var trigger_passives: Array = []
	if inventory == null:
		return trigger_passives
	for passive_id in inventory.passives:
		var passive: Dictionary = _get_catalog_entry(str(passive_id))
		if passive.is_empty():
			continue
		var required_tags: Variant = passive.get("requires_tags", [])
		if required_tags is Array and not (required_tags as Array).is_empty():
			continue
		var trigger_entries: Array = _normalize_trigger_entries(passive.get("triggers", []))
		for trigger_entry in trigger_entries:
			if not _is_valid_trigger_entry(trigger_entry, str(passive.get("id", passive_id))):
				continue
			var compiled_trigger: Dictionary = trigger_entry.duplicate(true)
			compiled_trigger["passive_id"] = str(passive.get("id", passive_id))
			compiled_trigger["passive_name"] = str(passive.get("name", "Passive"))
			trigger_passives.append(compiled_trigger)
	return trigger_passives

func _build_primary_effect_state_for_slot(inventory: PlayerInventoryData, slot_entry: Dictionary, fallback_id: String) -> Dictionary:
	var effect_state: Dictionary = _build_default_primary_effect_state()
	if inventory == null:
		return effect_state
	var weapon_tags: Array = _get_weapon_tags(_get_resolved_slot_weapon_id(slot_entry, fallback_id))
	for passive_id in inventory.passives:
		var passive := _get_catalog_entry(str(passive_id))
		if passive.is_empty():
			continue
		var required_tags: Variant = passive.get("requires_tags", [])
		if required_tags is Array and not _weapon_has_all_tags(weapon_tags, required_tags as Array):
			continue
		var effects_variant: Variant = passive.get("effects", {})
		if effects_variant is Dictionary and not (effects_variant as Dictionary).is_empty():
			_apply_primary_effects_dict(effect_state, effects_variant as Dictionary)
			continue
	return effect_state

func _build_secondary_effect_state_for_slot(inventory: PlayerInventoryData, slot_entry: Dictionary, fallback_id: String) -> Dictionary:
	var effect_state: Dictionary = _build_default_secondary_effect_state()
	if inventory == null:
		return effect_state
	var weapon_tags: Array = _get_weapon_tags(_get_resolved_slot_weapon_id(slot_entry, fallback_id))
	for passive_id in inventory.passives:
		var passive := _get_catalog_entry(str(passive_id))
		if passive.is_empty():
			continue
		var required_tags: Variant = passive.get("requires_tags", [])
		if required_tags is Array and not _weapon_has_all_tags(weapon_tags, required_tags as Array):
			continue
		var passive_effects: Dictionary = passive.get("passive_effects", {})
		if passive_effects.has("secondary_cooldown_mult"):
			effect_state["secondary_cooldown_mult"] = float(effect_state.get("secondary_cooldown_mult", 1.0)) * float(passive_effects.get("secondary_cooldown_mult", 1.0))
		if passive_effects.has("secondary_projectile_speed_mult"):
			effect_state["secondary_projectile_speed_mult"] = float(effect_state.get("secondary_projectile_speed_mult", 1.0)) * float(passive_effects.get("secondary_projectile_speed_mult", 1.0))
		if passive_effects.has("secondary_damage_bonus"):
			effect_state["secondary_damage_bonus"] = float(effect_state.get("secondary_damage_bonus", 0.0)) + float(passive_effects.get("secondary_damage_bonus", 0.0))
		if passive_effects.has("secondary_explosion_radius_mult"):
			effect_state["secondary_explosion_radius_mult"] = float(effect_state.get("secondary_explosion_radius_mult", 1.0)) * float(passive_effects.get("secondary_explosion_radius_mult", 1.0))
	return effect_state

func _build_profile_from_inventory_slot(slot_entry: Dictionary, fallback_id: String) -> Dictionary:
	var weapon_id := str(slot_entry.get("weapon_id", fallback_id))
	var weapon_level: int = int(slot_entry.get("level", 1))
	var weapon_type := str((_weapons_by_id.get(weapon_id, {}) as Dictionary).get("type", ""))
	if weapon_type == "secondary_weapon":
		return _build_weapon_profile(weapon_id, "mine", weapon_level)
	return _build_weapon_profile(weapon_id, "rifle", weapon_level)

func _get_resolved_slot_weapon_id(slot_entry: Dictionary, fallback_id: String) -> String:
	var weapon_id := str(slot_entry.get("weapon_id", fallback_id))
	if _weapons_by_id.has(weapon_id):
		return weapon_id
	return fallback_id

func _weapon_has_all_tags(weapon_tags: Array, required_tags: Array) -> bool:
	for raw_required_tag in required_tags:
		var required_tag := str(raw_required_tag)
		if required_tag.is_empty():
			continue
		if not weapon_tags.has(required_tag):
			return false
	return true

func _get_weapon_tags(weapon_id: String) -> Array:
	var weapon: Dictionary = _weapons_by_id.get(weapon_id, {}) as Dictionary
	var raw_tags: Variant = weapon.get("tags", [])
	if not (raw_tags is Array):
		return []
	var normalized_tags: Array = []
	for raw_tag in raw_tags:
		var tag := str(raw_tag)
		if tag.is_empty():
			continue
		normalized_tags.append(tag)
	return normalized_tags

func _get_weapon_behavior(weapon_id: String) -> String:
	var weapon: Dictionary = _weapons_by_id.get(weapon_id, {}) as Dictionary
	if str(weapon.get("type", "")) != "primary_weapon":
		return ""
	var behavior := str(weapon.get("primary_behavior", "projectile"))
	if behavior.is_empty():
		push_warning("[RunState] Primary weapon '%s' is missing primary_behavior. Falling back to 'projectile'." % weapon_id)
		return "projectile"
	if not BEHAVIOR_TAGS.has(behavior):
		push_warning("[RunState] Primary weapon '%s' has unsupported primary_behavior '%s'. Falling back to 'projectile'." % [weapon_id, behavior])
		return "projectile"
	return behavior

func _validate_weapon_tags(weapon: Dictionary) -> void:
	var weapon_id := str(weapon.get("id", "unknown_weapon"))
	if str(weapon.get("type", "")) != "primary_weapon":
		return
	var raw_tags: Variant = weapon.get("tags", [])
	var tags: Array = raw_tags if raw_tags is Array else []
	var behavior_tag_count := 0
	for raw_tag in tags:
		var tag := str(raw_tag)
		if tag.is_empty():
			continue
		if not VALID_WEAPON_TAGS.has(tag):
			push_warning("[RunState] Weapon '%s' has unknown tag '%s'." % [weapon_id, tag])
		if BEHAVIOR_TAGS.has(tag):
			behavior_tag_count += 1
	if behavior_tag_count != 1:
		push_warning("[RunState] Primary weapon '%s' must declare exactly one behavior tag. Found %d." % [weapon_id, behavior_tag_count])
	_get_weapon_behavior(weapon_id)

func _build_primary_runtime_slot_array(slot_entries: Array, inventory: PlayerInventoryData, fallback_id: String) -> Array:
	var runtime_slots: Array = []
	for slot_entry in slot_entries:
		if slot_entry is Dictionary:
			var passive_state: Dictionary = _build_primary_effect_state_for_slot(inventory, slot_entry as Dictionary, fallback_id)
			var trigger_passives: Array = _build_primary_trigger_passives_for_slot(inventory, slot_entry as Dictionary, fallback_id)
			runtime_slots.append(_compile_slot_loadout(slot_entry as Dictionary, passive_state, trigger_passives, fallback_id))
		else:
			runtime_slots.append(null)
	return runtime_slots

func _build_secondary_runtime_slot_array(slot_entries: Array, inventory: PlayerInventoryData, fallback_id: String) -> Array:
	var runtime_slots: Array = []
	for slot_entry in slot_entries:
		if slot_entry is Dictionary:
			var passive_state: Dictionary = _build_secondary_effect_state_for_slot(inventory, slot_entry as Dictionary, fallback_id)
			runtime_slots.append(_compile_slot_loadout(slot_entry as Dictionary, passive_state, [], fallback_id))
		else:
			runtime_slots.append(null)
	return runtime_slots

func _compile_slot_loadout(slot_entry: Dictionary, passive_state: Dictionary, primary_trigger_passives: Array, fallback_id: String) -> Dictionary:
	var profile: Dictionary = _build_profile_from_inventory_slot(slot_entry, fallback_id)
	var weapon_id: String = str(slot_entry.get("weapon_id", fallback_id))
	var resolved_weapon_id: String = str(profile.get("id", weapon_id))
	var weapon_level: int = int(slot_entry.get("level", 1))
	var weapon_type: String = str(profile.get("type", "weapon"))
	var feedback_profile: String = _get_feedback_profile_for_weapon_id(weapon_id, str(profile.get("kind", "")))
	var impact_weight: float = _get_impact_weight_for_feedback_profile(feedback_profile)
	var slot_loadout: Dictionary = {
		"weapon_id": weapon_id,
		"weapon_level": weapon_level,
		"primary_behavior": _get_weapon_behavior(resolved_weapon_id),
		"primary_weapon_tags": _get_weapon_tags(resolved_weapon_id),
		"primary_trigger_passives": primary_trigger_passives.duplicate(true),
		"feedback_profile": feedback_profile,
		"impact_weight": impact_weight,
		"weapon_level_description": str(profile.get("level_description", "")),
		"primary_profile_name": str(profile.get("label", "Rifle")),
		"secondary_profile_name": str(profile.get("label", "Mine")),
		"secondary_projectile_count": int(profile.get("projectile_count", 1)),
		"secondary_spread_radians": float(profile.get("spread_radians", 0.0)),
		"secondary_cooldown": 4.0 * GLOBAL_SECONDARY_COOLDOWN_MULT * float(passive_state.get("secondary_cooldown_mult", 1.0)) * float(profile.get("cooldown_mult", 1.0)),
		"secondary_projectile_speed": float(profile.get("base_projectile_speed", 0.0)) * float(passive_state.get("secondary_projectile_speed_mult", 1.0)) * float(profile.get("projectile_speed_mult", 1.0)),
			"secondary_damage": max(1, int(round((30.0 + float(passive_state.get("secondary_damage_bonus", 0.0))) * float(profile.get("damage_mult", 1.0))))),
		"secondary_projectile_kind": str(profile.get("kind", "mine")),
		"secondary_explosion_radius": 92.0 * float(passive_state.get("secondary_explosion_radius_mult", 1.0)) * float(profile.get("explosion_radius_mult", 1.0)),
		"secondary_fuse_time": float(profile.get("base_fuse_time", 12.0)) * float(profile.get("fuse_time_mult", 1.0)),
		"secondary_gravity_force": float(profile.get("base_gravity_force", 0.0)) * float(profile.get("gravity_force_mult", 1.0)),
		"secondary_pulse_count": int(profile.get("pulse_count", 1)),
		"secondary_pulse_interval": float(profile.get("pulse_interval", 0.18)),
		"secondary_cluster_blast_count": int(profile.get("cluster_blast_count", 0)),
		"secondary_cluster_spread_radius": 52.0 * float(profile.get("cluster_spread_radius_mult", 1.0)),
		"secondary_proximity_radius": float(profile.get("base_proximity_radius", 52.0)) * float(profile.get("proximity_radius_mult", 1.0)),
	}
	if weapon_type == "primary_weapon":
		var primary_runtime: Dictionary = _compile_primary_runtime_from_new_stats(profile, passive_state)
		for runtime_key in primary_runtime.keys():
			slot_loadout[str(runtime_key)] = primary_runtime[runtime_key]
	return slot_loadout

func _compile_primary_runtime_from_new_stats(profile: Dictionary, passive_state: Dictionary) -> Dictionary:
	var current_fire_rate: float = max(float(profile.get("fire_rate", 1.0)), 0.001)
	var final_fire_rate: float = max(current_fire_rate * float(passive_state.get("fire_rate_mult", 1.0)), 0.001)
	var primary_fire_interval: float = 1.0 / final_fire_rate

	var projectile_speed: float = float(profile.get("projectile_speed", 540.0)) * float(passive_state.get("projectile_speed_mult", 1.0))
	var projectile_damage: int = max(1, int(round(
		float(profile.get("damage", 1.0))
		* float(passive_state.get("damage_mult", 1.0))
		+ float(passive_state.get("damage_add", 0.0))
	)))
	var primary_range: float = float(profile.get("range", 0.0)) * float(passive_state.get("range_mult", 1.0))
	var primary_area: float = float(profile.get("area", 0.0)) * float(passive_state.get("area_mult", 1.0))
	var primary_amount: int = max(1, int(profile.get("amount", 1)) + int(passive_state.get("amount_add", 0)))
	var primary_pierce_count: int = max(0, int(passive_state.get("pierce_count_add", 0)))

	return {
		"primary_amount": primary_amount,
		"primary_projectile_count": primary_amount,
		"primary_spread_radians": float(profile.get("spread_radians", 0.0)),
		"primary_fire_interval": primary_fire_interval,
		"projectile_speed": projectile_speed,
		"projectile_damage": projectile_damage,
		"primary_range": primary_range,
		"primary_area": primary_area,
		"primary_pierce_count": primary_pierce_count,
	}

func _apply_level_overrides_to_profile(profile: Dictionary, overrides: Dictionary) -> void:
	for override_key in overrides.keys():
		profile[str(override_key)] = overrides[override_key]

func _build_primary_trigger_passives_for_slot(inventory: PlayerInventoryData, slot_entry: Dictionary, fallback_id: String) -> Array:
	var trigger_passives: Array = []
	if inventory == null:
		return trigger_passives
	var weapon_id: String = _get_resolved_slot_weapon_id(slot_entry, fallback_id)
	var weapon_tags: Array = _get_weapon_tags(weapon_id)
	for passive_id in inventory.passives:
		var passive: Dictionary = _get_catalog_entry(str(passive_id))
		if passive.is_empty():
			continue
		var required_tags: Variant = passive.get("requires_tags", [])
		if required_tags is Array and (required_tags as Array).is_empty():
			continue
		if required_tags is Array and not _weapon_has_all_tags(weapon_tags, required_tags as Array):
			continue
		var trigger_entries: Array = _normalize_trigger_entries(passive.get("triggers", []))
		for trigger_entry in trigger_entries:
			if not _is_valid_trigger_entry(trigger_entry, str(passive.get("id", passive_id))):
				continue
			var compiled_trigger: Dictionary = trigger_entry.duplicate(true)
			compiled_trigger["passive_id"] = str(passive.get("id", passive_id))
			compiled_trigger["passive_name"] = str(passive.get("name", "Passive"))
			trigger_passives.append(compiled_trigger)
	return trigger_passives

func _normalize_trigger_entries(triggers_variant: Variant) -> Array:
	var normalized_entries: Array = []
	if triggers_variant is Dictionary:
		normalized_entries.append((triggers_variant as Dictionary).duplicate(true))
	elif triggers_variant is Array:
		for trigger_entry in triggers_variant:
			if trigger_entry is Dictionary:
				normalized_entries.append((trigger_entry as Dictionary).duplicate(true))
	return normalized_entries

func _is_valid_trigger_entry(trigger_entry: Dictionary, passive_id: String) -> bool:
	var hook: String = str(trigger_entry.get("hook", ""))
	if hook.is_empty():
		push_warning("[RunState] Passive '%s' trigger is missing hook." % passive_id)
		return false
	if not ["on_fire", "on_hit", "on_kill", "on_explosion"].has(hook):
		push_warning("[RunState] Passive '%s' trigger has unsupported hook '%s'." % [passive_id, hook])
		return false
	var action_variant: Variant = trigger_entry.get("action", {})
	if not (action_variant is Dictionary) or (action_variant as Dictionary).is_empty():
		push_warning("[RunState] Passive '%s' trigger '%s' is missing action data." % [passive_id, hook])
		return false
	return true

func _apply_primary_effects_dict(effect_state: Dictionary, effects: Dictionary) -> void:
	for raw_effect_key in effects.keys():
		var effect_key := str(raw_effect_key)
		var effect_value: Variant = effects[raw_effect_key]
		match effect_key:
			"fire_rate_mult":
				var fire_rate_mult: float = float(effect_value)
				effect_state["fire_rate_mult"] = float(effect_state.get("fire_rate_mult", 1.0)) * fire_rate_mult
			"projectile_speed_mult":
				var projectile_speed_mult: float = float(effect_value)
				effect_state["projectile_speed_mult"] = float(effect_state.get("projectile_speed_mult", 1.0)) * projectile_speed_mult
			"damage_mult":
				effect_state["damage_mult"] = float(effect_state.get("damage_mult", 1.0)) * float(effect_value)
			"damage_add":
				effect_state["damage_add"] = float(effect_state.get("damage_add", 0.0)) + float(effect_value)
			"range_mult":
				effect_state["range_mult"] = float(effect_state.get("range_mult", 1.0)) * float(effect_value)
			"area_mult":
				effect_state["area_mult"] = float(effect_state.get("area_mult", 1.0)) * float(effect_value)
			"amount_add":
				effect_state["amount_add"] = int(effect_state.get("amount_add", 0)) + int(effect_value)
			"pierce_count_add":
				effect_state["pierce_count_add"] = int(effect_state.get("pierce_count_add", 0)) + int(effect_value)
			_:
				push_warning("[RunState] Unsupported primary passive effect key '%s'." % effect_key)

func _apply_level_effects_to_profile(profile: Dictionary, effects: Dictionary) -> void:
	for raw_effect_key in effects.keys():
		var effect_key := str(raw_effect_key)
		var effect_value: Variant = effects[raw_effect_key]
		match effect_key:
			"damage_mult":
				if profile.has("damage"):
					profile["damage"] = float(profile.get("damage", 1.0)) * float(effect_value)
			"damage_add":
				if profile.has("damage"):
					profile["damage"] = float(profile.get("damage", 1.0)) + float(effect_value)
			"fire_rate_mult":
				if profile.has("fire_rate"):
					profile["fire_rate"] = float(profile.get("fire_rate", 1.0)) * float(effect_value)
			"range_mult":
				if profile.has("range"):
					profile["range"] = float(profile.get("range", 0.0)) * float(effect_value)
			"area_mult":
				if profile.has("area"):
					profile["area"] = float(profile.get("area", 0.0)) * float(effect_value)
			"amount_add":
				if profile.has("amount"):
					profile["amount"] = int(profile.get("amount", 1)) + int(effect_value)
			"projectile_speed_mult":
				if profile.has("projectile_speed"):
					profile["projectile_speed"] = float(profile.get("projectile_speed", 0.0)) * float(effect_value)
			_:
				continue

func _get_feedback_profile_for_weapon_id(weapon_id: String, projectile_kind: String = "") -> String:
	match weapon_id:
		"scatter", "spread":
			return "scatter"
		"slug":
			return "slug"
		"incinerator":
			return "scatter"
		"beam_lance", "arc_caster":
			return "slug"
		"cluster_grenade", "siege_grenade", "grenade":
			return "grenade"
		"shrapnel_mine", "heavy_mine", "mine":
			return "mine"
		_:
			match projectile_kind:
				"cluster_grenade", "siege_grenade", "grenade":
					return "grenade"
				"shrapnel_mine", "heavy_mine", "mine":
					return "mine"
				_:
					return "rifle"

func _get_impact_weight_for_feedback_profile(feedback_profile: String) -> float:
	match feedback_profile:
		"scatter":
			return 1.2
		"slug":
			return 1.8
		"grenade":
			return 1.6
		"mine":
			return 1.7
		_:
			return 1.0

func get_gold_summary_text(compact: bool = false) -> String:
	if player_inventories.is_empty():
		return "No wallets"
	var parts: Array = []
	for inventory_index in range(player_inventories.size()):
		var inventory: PlayerInventoryData = player_inventories[inventory_index]
		parts.append("P%d: %d" % [inventory_index + 1, inventory.gold])
	if compact:
		return " | ".join(parts)
	return "Gold Wallets\n%s" % "\n".join(parts)

func award_gold_to_all(value: int) -> void:
	for inventory in player_inventories:
		(inventory as PlayerInventoryData).gold += value
	_sync_aggregate_gold()

func _sync_aggregate_gold() -> void:
	gold = 0
	for inventory in player_inventories:
		gold += int((inventory as PlayerInventoryData).gold)

func _apply_debug_start_options(debug_options: Dictionary) -> void:
	if debug_options.is_empty():
		return
	if bool(debug_options.get("enabled", false)) == false:
		return

	debug_run_setup["enabled"] = true
	for key in debug_options.keys():
		debug_run_setup[key] = debug_options[key]

func _apply_debug_loadout_overrides() -> void:
	if player_inventories.is_empty():
		_sync_aggregate_gold()
		return
	if not bool(debug_run_setup.get("enabled", false)):
		for inventory in player_inventories:
			(inventory as PlayerInventoryData).gold = 0
		_sync_aggregate_gold()
		return

	var primary_profile := str(debug_run_setup.get("primary_profile", ""))
	var secondary_profile := str(debug_run_setup.get("secondary_profile", ""))
	var starting_gold: int = int(debug_run_setup.get("starting_gold", 0))
	for inventory_entry in player_inventories:
		var inventory: PlayerInventoryData = inventory_entry
		inventory.gold = starting_gold
		if not primary_profile.is_empty():
			inventory.primary_slots[0] = {"weapon_id": _normalize_primary_profile_id(primary_profile), "level": 1}
			inventory.selected_primary = 0
		if not secondary_profile.is_empty():
			inventory.secondary_slots[0] = {"weapon_id": _normalize_secondary_profile_id(secondary_profile), "level": 1}
			inventory.selected_secondary = 0
	_sync_aggregate_gold()

func _build_default_debug_run_setup() -> Dictionary:
	return {
		"enabled": false,
		"launch_mode": "normal_run",
		"primary_profile": "",
		"secondary_profile": "",
		"starting_gold": 0,
		"step_index": 0,
		"room_type": "combat",
		"room_objective": "survive",
		"modifier_mode": "random",
		"modifier_id": "random",
		"layout_id": "random",
		"test_recipe_id": "",
	}

func _build_debug_node_map() -> Array:
	return [[_build_debug_room_node()]]

func _build_debug_room_node() -> Dictionary:
	var step_index: int = int(debug_run_setup.get("step_index", 0))
	var room_type := str(debug_run_setup.get("room_type", "combat"))
	var forced_recipe_id: String = _get_forced_recipe_id()
	var template := _build_room_template(room_type)
	if room_type == "combat" or room_type == "elite":
		if forced_recipe_id.is_empty():
			template["room_objective"] = str(debug_run_setup.get("room_objective", "survive"))
		var room_objective: String = str(template.get("room_objective", "survive"))
		var debug_modifier: Dictionary = _resolve_debug_modifier(room_objective)
		if not debug_modifier.is_empty() or str(debug_run_setup.get("modifier_mode", "random")) == "none":
			template["modifier"] = debug_modifier
		var layout_id := str(debug_run_setup.get("layout_id", "random"))
		if layout_id != "random":
			template["layout_id"] = layout_id
		if room_objective == "destroy_generators":
			template["generator_count"] = 3 if room_type == "elite" else 2
			template["generator_spawn_interval"] = 2.6 if room_type == "elite" else 3.2
			template["generator_enemy_cap"] = 8 if room_type == "elite" else 6
			template["generator_spitter_chance"] = _compute_generator_spitter_chance(step_index, room_type == "elite")
		elif room_objective == "capture_the_hill":
			template["hill_capture_required"] = 10.0 if room_type == "elite" else 8.0
			template["hill_radius"] = 140.0 if room_type == "elite" else 132.0
			template["enemy_spawn_interval"] = _compute_spawn_interval(step_index, room_type == "elite")
		elif forced_recipe_id.is_empty():
			template["survival_duration"] = _compute_survival_duration(step_index, room_type == "elite")
			template["enemy_spawn_interval"] = _compute_spawn_interval(step_index, room_type == "elite")
	elif room_type == "boss":
		var boss_layout_id := str(debug_run_setup.get("layout_id", "boss_gate"))
		template["layout_id"] = "boss_gate" if boss_layout_id == "random" else boss_layout_id
	return _build_node(step_index, 2, template)

func _resolve_debug_modifier(room_objective: String = "survive") -> Dictionary:
	var modifier_mode := str(debug_run_setup.get("modifier_mode", "random"))
	var step_index: int = int(debug_run_setup.get("step_index", 0))
	match modifier_mode:
		"none":
			return {}
		"specific":
			var specific_modifier: Dictionary = _modifier_engine.get_modifier_by_id(str(debug_run_setup.get("modifier_id", "")))
			return specific_modifier if _is_modifier_allowed_for_objective(specific_modifier, room_objective) else {}
		_:
			var random_modifier: Dictionary = _modifier_engine.get_random_modifier(step_index)
			return random_modifier if _is_modifier_allowed_for_objective(random_modifier, room_objective) else {}

func _get_primary_profile(profile_id: String) -> Dictionary:
	var normalized_profile_id := _normalize_primary_profile_id(profile_id)
	return _build_weapon_profile(normalized_profile_id, "rifle", 1)

func _get_secondary_profile(profile_id: String) -> Dictionary:
	var normalized_profile_id := _normalize_secondary_profile_id(profile_id)
	return _build_weapon_profile(normalized_profile_id, "mine", 1)

func _build_weapon_profile(profile_id: String, fallback_id: String, level: int = 1) -> Dictionary:
	var resolved_id := profile_id if _weapons_by_id.has(profile_id) else fallback_id
	if not _weapons_by_id.has(resolved_id):
		return {}
	var weapon: Dictionary = (_weapons_by_id[resolved_id] as Dictionary).duplicate(true)
	var base_stats: Dictionary = weapon.get("base_stats", {}).duplicate(true)
	base_stats["id"] = str(weapon.get("id", resolved_id))
	base_stats["label"] = str(weapon.get("name", resolved_id.capitalize()))
	base_stats["type"] = str(weapon.get("type", "weapon"))
	var clamped_level: int = clampi(level, 1, int(weapon.get("max_level", 5)))
	base_stats["level"] = clamped_level
	var level_key := str(clamped_level)
	if base_stats["type"] == "primary_weapon":
		var levels_variant: Variant = weapon.get("levels", {})
		if levels_variant is Dictionary:
			var levels: Dictionary = levels_variant as Dictionary
			if levels.has(level_key) and levels[level_key] is Dictionary:
				var level_data: Dictionary = (levels[level_key] as Dictionary).duplicate(true)
				base_stats["level_description"] = str(level_data.get("description", ""))
				var overrides_variant: Variant = level_data.get("overrides", {})
				if overrides_variant is Dictionary:
					_apply_level_overrides_to_profile(base_stats, overrides_variant as Dictionary)
				var effects_variant: Variant = level_data.get("effects", {})
				if effects_variant is Dictionary:
					_apply_level_effects_to_profile(base_stats, (effects_variant as Dictionary).duplicate(true))
				return base_stats
		return base_stats
	var level_effects_variant: Variant = weapon.get("level_effects", {})
	if level_effects_variant is Dictionary:
		var level_effects: Dictionary = level_effects_variant as Dictionary
		if level_effects.has(level_key) and level_effects[level_key] is Dictionary:
			var level_effect: Dictionary = (level_effects[level_key] as Dictionary).duplicate(true)
			base_stats["level_description"] = str(level_effect.get("description", ""))
			for effect_key in level_effect.keys():
				if str(effect_key) == "description":
					continue
				base_stats[str(effect_key)] = level_effect[effect_key]
	return base_stats

func _normalize_primary_profile_id(profile_id: String) -> String:
	match profile_id:
		"":
			return "rifle"
		"spread":
			return "scatter"
		_:
			return profile_id

func _normalize_secondary_profile_id(profile_id: String) -> String:
	match profile_id:
		"":
			return "mine"
		"cluster":
			return "cluster_grenade"
		"siege":
			return "siege_grenade"
		"cluster_mine":
			return "shrapnel_mine"
		"siege_mine":
			return "heavy_mine"
		_:
			return profile_id

func _load_passives() -> void:
	_passives = []
	_passives_by_id = {}
	if not FileAccess.file_exists(PASSIVES_DATA_PATH):
		return

	var file := FileAccess.open(PASSIVES_DATA_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return

	var raw_passives = parsed.get("passives", [])
	if not (raw_passives is Array):
		return

	for entry in raw_passives:
		if not (entry is Dictionary):
			continue
		var passive: Dictionary = entry.duplicate(true)
		var passive_id := str(passive.get("id", ""))
		if passive_id.is_empty():
			continue
		_passives.append(passive)
		_passives_by_id[passive_id] = passive

func _load_weapons() -> void:
	_weapons = []
	_weapons_by_id = {}
	if not FileAccess.file_exists(WEAPONS_DATA_PATH):
		return

	var file := FileAccess.open(WEAPONS_DATA_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return

	var raw_weapons = parsed.get("weapons", [])
	if not (raw_weapons is Array):
		return

	for entry in raw_weapons:
		if not (entry is Dictionary):
			continue
		var weapon: Dictionary = entry.duplicate(true)
		var weapon_id := str(weapon.get("id", ""))
		if weapon_id.is_empty():
			continue
		_weapons.append(weapon)
		_weapons_by_id[weapon_id] = weapon
		_validate_weapon_tags(weapon)

func _roll_item_choices(pool_name: String, count: int) -> Array:
	var available: Array = []
	for passive in _passives:
		var passive_pools = passive.get("pools", [])
		if not (passive_pools is Array) or not passive_pools.has(pool_name):
			continue
		if not _is_catalog_entry_unlocked(passive):
			continue
		if not bool(passive.get("stackable", false)) and _all_inventories_have_passive(str(passive.get("id", ""))):
			continue
		available.append(_decorate_choice_entry(passive))
	for weapon in _weapons:
		var weapon_pools = weapon.get("pools", [])
		if not (weapon_pools is Array) or not weapon_pools.has(pool_name):
			continue
		if not _is_catalog_entry_unlocked(weapon):
			continue
		if _all_inventories_block_weapon(str(weapon.get("id", "")), int(weapon.get("max_level", 5))):
			continue
		available.append(_decorate_choice_entry(weapon))
		
	if available.is_empty():
		for passive in _passives:
			var passive_pools = passive.get("pools", [])
			if passive_pools is Array and passive_pools.has(pool_name) and _is_catalog_entry_unlocked(passive):
				available.append(_decorate_choice_entry(passive))
		for weapon in _weapons:
			var weapon_pools = weapon.get("pools", [])
			if weapon_pools is Array and weapon_pools.has(pool_name) and _is_catalog_entry_unlocked(weapon):
				available.append(_decorate_choice_entry(weapon))

	var choices: Array = []
	while choices.size() < count and not available.is_empty():
		var index := _random.randi_range(0, available.size() - 1)
		choices.append(available[index])
		available.remove_at(index)
	return choices

func _roll_shop_offers_for_player(player_index: int, count: int) -> Array:
	var available: Array = []
	var inventory: PlayerInventoryData = _get_inventory(player_index)
	for passive in _passives:
		var passive_pools = passive.get("pools", [])
		if not (passive_pools is Array) or not passive_pools.has("shop"):
			continue
		if not _is_catalog_entry_unlocked(passive):
			continue
		if not bool(passive.get("stackable", false)) and inventory.has_passive(str(passive.get("id", ""))):
			continue
		available.append(_decorate_choice_entry(passive))
	for weapon in _weapons:
		var weapon_pools = weapon.get("pools", [])
		if not (weapon_pools is Array) or not weapon_pools.has("shop"):
			continue
		if not _is_catalog_entry_unlocked(weapon):
			continue
		if not inventory.can_take_weapon(str(weapon.get("id", "")), int(weapon.get("max_level", 5))):
			continue
		available.append(_decorate_choice_entry(weapon))
	var offers: Array = []
	while offers.size() < count and not available.is_empty():
		var roll_index := _random.randi_range(0, available.size() - 1)
		offers.append(available[roll_index])
		available.remove_at(roll_index)
	return offers

func _remove_shop_offer(player_index: int, item_id: String) -> void:
	if not shop_offers_by_player.has(player_index):
		return
	var offers: Array = shop_offers_by_player[player_index]
	for offer_index in range(offers.size() - 1, -1, -1):
		var offer_value: Variant = offers[offer_index]
		if offer_value is Dictionary and str((offer_value as Dictionary).get("id", "")) == item_id:
			offers.remove_at(offer_index)
			break
	shop_offers_by_player[player_index] = offers

func _get_catalog_entry(entry_id: String) -> Dictionary:
	if _passives_by_id.has(entry_id):
		return (_passives_by_id[entry_id] as Dictionary).duplicate(true)
	if _weapons_by_id.has(entry_id):
		return (_weapons_by_id[entry_id] as Dictionary).duplicate(true)
	return {}

func _apply_catalog_entry_to_all_players(entry: Dictionary) -> String:
	match str(entry.get("type", "")):
		"primary_weapon", "secondary_weapon":
			return _apply_weapon_offer_to_all_players(entry)
		_:
			return _apply_passive_to_all_players(entry)

func _apply_catalog_entry_to_player(player_index: int, entry: Dictionary, health_state: Dictionary = {}) -> Dictionary:
	match str(entry.get("type", "")):
		"primary_weapon", "secondary_weapon":
			return _apply_weapon_offer_to_player(player_index, entry)
		_:
			return _apply_passive_to_player(player_index, entry, health_state)

func _apply_passive_to_player(player_index: int, passive: Dictionary, health_state: Dictionary = {}) -> Dictionary:
	var inventory: PlayerInventoryData = _get_inventory(player_index)
	var passive_id: String = str(passive.get("id", ""))
	if not bool(passive.get("stackable", false)) and inventory.has_passive(passive_id):
		return {
			"outcome": "already_owned",
			"summary": "%s was already owned, so the drop was converted to Gold." % str(passive.get("name", "Passive")),
		}
	inventory.add_passive(passive_id, bool(passive.get("stackable", false)))
	var effects: Dictionary = passive.get("passive_effects", {})
	if effects.has("max_health_bonus") and not health_state.is_empty():
		var max_health_bonus: int = int(effects.get("max_health_bonus", 0))
		health_state["max"] = int(health_state.get("max", 50)) + max_health_bonus
		health_state["current"] = int(health_state.get("current", 50)) + max_health_bonus
	return {
		"outcome": "took_item",
		"summary": "%s added." % str(passive.get("name", "Passive")),
	}

func _apply_weapon_offer_to_player(player_index: int, weapon: Dictionary) -> Dictionary:
	var inventory: PlayerInventoryData = _get_inventory(player_index)
	var weapon_id: String = str(weapon.get("id", ""))
	var weapon_type: String = str(weapon.get("type", ""))
	var max_level: int = int(weapon.get("max_level", 5))
	var result: String = inventory.add_weapon(weapon_id, weapon_type, max_level)
	if result == "slots_full":
		return {
			"outcome": "needs_replacement",
			"summary": "%s needs a slot replacement choice." % str(weapon.get("name", "Weapon")),
			"slot_type": "secondary" if weapon_type == "secondary_weapon" else "primary",
			"slot_count": inventory.secondary_slots.size() if weapon_type == "secondary_weapon" else inventory.primary_slots.size(),
		}
	if result == "leveled_up":
		return {
			"outcome": "leveled_up",
			"summary": "%s leveled up." % str(weapon.get("name", "Weapon")),
		}
	if result == "max_level":
		return {
			"outcome": "max_level",
			"summary": "%s was already max level." % str(weapon.get("name", "Weapon")),
		}
	return {
		"outcome": "took_item",
		"summary": "%s equipped." % str(weapon.get("name", "Weapon")),
	}

func resolve_weapon_replacement_choice(player_index: int, entry: Dictionary, slot_type: String, slot_index: int, cancel_instead: bool = false) -> Dictionary:
	var inventory: PlayerInventoryData = _get_inventory(player_index)
	var entry_id: String = str(entry.get("id", ""))
	if cancel_instead:
		var scrap_gold: int = max(1, int(entry.get("scrap_gold_value", 1)))
		inventory.gold += scrap_gold
		_sync_aggregate_gold()
		return {
			"outcome": "scrapped",
			"summary": "P%d scrapped %s for %d Gold." % [player_index + 1, str(entry.get("name", "Weapon")), scrap_gold],
			"gold_gained": scrap_gold,
		}
	var normalized_slot_type: String = "secondary" if slot_type == "secondary" else "primary"
	var slot_group: Array = inventory.secondary_slots if normalized_slot_type == "secondary" else inventory.primary_slots
	var resolved_slot_index: int = clampi(slot_index, 0, max(slot_group.size() - 1, 0))
	inventory.replace_weapon(normalized_slot_type, resolved_slot_index, entry_id)
	return {
		"outcome": "replaced",
		"summary": "P%d replaced %s slot %d with %s." % [
			player_index + 1,
			"secondary" if normalized_slot_type == "secondary" else "primary",
			resolved_slot_index + 1,
			str(entry.get("name", "Weapon"))
		],
		"gold_gained": 0,
	}

func get_player_weapon_slot_display(player_index: int, slot_type: String) -> Array:
	var inventory: PlayerInventoryData = _get_inventory(player_index)
	var slot_group: Array = inventory.secondary_slots if slot_type == "secondary" else inventory.primary_slots
	var display_rows: Array = []
	for slot_entry in slot_group:
		if slot_entry is Dictionary:
			var weapon_id: String = str((slot_entry as Dictionary).get("weapon_id", ""))
			var weapon_level: int = int((slot_entry as Dictionary).get("level", 1))
			var entry: Dictionary = _get_catalog_entry(weapon_id)
			display_rows.append({
				"weapon_id": weapon_id,
				"name": str(entry.get("name", weapon_id.capitalize())),
				"level": weapon_level,
			})
		else:
			display_rows.append({
				"weapon_id": "",
				"name": "---",
				"level": 0,
			})
	return display_rows

func _apply_passive_to_all_players(passive: Dictionary) -> String:
	var passive_id := str(passive.get("id", ""))
	for inventory in player_inventories:
		var player_inventory: PlayerInventoryData = inventory
		if bool(passive.get("stackable", false)) or not player_inventory.has_passive(passive_id):
			player_inventory.add_passive(passive_id, bool(passive.get("stackable", false)))
	var effects: Dictionary = passive.get("passive_effects", {})
	if effects.has("max_health_bonus"):
		var max_health_bonus := int(effects.get("max_health_bonus", 0))
		for state in player_health_states:
			state["max"] = int(state.get("max", 50)) + max_health_bonus
			state["current"] = int(state.get("current", 50)) + max_health_bonus

	return "%s\n%s" % [str(passive.get("name", "Upgrade")), str(passive.get("description", ""))]

func _apply_weapon_offer_to_all_players(weapon: Dictionary) -> String:
	var weapon_id := str(weapon.get("id", ""))
	var weapon_type := str(weapon.get("type", ""))
	var max_level: int = int(weapon.get("max_level", 5))
	for inventory in player_inventories:
		var player_inventory: PlayerInventoryData = inventory
		var result := player_inventory.add_weapon(weapon_id, weapon_type, max_level)
		if result == "slots_full":
			if weapon_type == "secondary_weapon":
				player_inventory.secondary_slots[0] = {"weapon_id": weapon_id, "level": 1}
				player_inventory.selected_secondary = 0
			else:
				player_inventory.primary_slots[0] = {"weapon_id": weapon_id, "level": 1}
				player_inventory.selected_primary = 0
	return "%s\n%s" % [str(weapon.get("name", "Weapon")), str(weapon.get("description", ""))]

func _is_catalog_entry_unlocked(entry: Dictionary) -> bool:
	var unlock_id := str(entry.get("unlock_id", str(entry.get("id", ""))))
	if unlock_id.is_empty():
		return true
	return ProfileState.has_item_unlock(unlock_id)

func _get_catalog_entry_cost(entry: Dictionary) -> int:
	var entry_type := str(entry.get("type", ""))
	if entry_type == "passive":
		return int(entry.get("shop_gold_cost", 0))
	return int(entry.get("shop_gold_cost", entry.get("cost", 0)))

func _decorate_choice_entry(entry: Dictionary) -> Dictionary:
	var decorated: Dictionary = entry.duplicate(true)
	var entry_type := str(decorated.get("type", ""))
	if not decorated.has("cost"):
		decorated["cost"] = _get_catalog_entry_cost(decorated)
	if not decorated.has("category"):
		match entry_type:
			"primary_weapon":
				decorated["category"] = "Primary Weapon"
			"secondary_weapon":
				decorated["category"] = "Secondary Weapon"
			_:
				decorated["category"] = "Passive"
	return decorated

func _all_inventories_have_passive(passive_id: String) -> bool:
	if player_inventories.is_empty():
		return false
	for inventory in player_inventories:
		if not (inventory as PlayerInventoryData).has_passive(passive_id):
			return false
	return true

func _all_inventories_block_weapon(weapon_id: String, max_level: int) -> bool:
	if player_inventories.is_empty():
		return false
	for inventory in player_inventories:
		if (inventory as PlayerInventoryData).can_take_weapon(weapon_id, max_level):
			return false
	return true

func _can_inventory_take_entry(player_index: int, entry: Dictionary) -> bool:
	var inventory: PlayerInventoryData = _get_inventory(player_index)
	match str(entry.get("type", "")):
		"primary_weapon", "secondary_weapon":
			return inventory.can_take_weapon(str(entry.get("id", "")), int(entry.get("max_level", 5)))
		_:
			return bool(entry.get("stackable", false)) or not inventory.has_passive(str(entry.get("id", "")))

func _roll_contested_loot_winner(takers: Array) -> int:
	if takers.is_empty():
		return -1
	if takers.size() == 1:
		return int(takers[0])
	if takers.size() == 2:
		var first_index: int = int(takers[0])
		var second_index: int = int(takers[1])
		var first_count: int = _get_inventory(first_index).get_total_item_count()
		var second_count: int = _get_inventory(second_index).get_total_item_count()
		if first_count == second_count:
			return first_index if _random.randf() < 0.5 else second_index
		var advantaged_index: int = first_index if first_count < second_count else second_index
		var disadvantaged_index: int = second_index if advantaged_index == first_index else first_index
		var item_gap: int = abs(first_count - second_count)
		var advantage_chance: float = clamp(0.5 + float(item_gap) * 0.1, 0.6, 0.7)
		return advantaged_index if _random.randf() < advantage_chance else disadvantaged_index

	var total_weight: float = 0.0
	var weights: Array = []
	for taker_value in takers:
		var taker_index: int = int(taker_value)
		var item_count: int = _get_inventory(taker_index).get_total_item_count()
		var weight: float = max(1.0, 6.0 - float(item_count))
		weights.append(weight)
		total_weight += weight
	var roll: float = _random.randf() * total_weight
	for weight_index in range(weights.size()):
		roll -= float(weights[weight_index])
		if roll <= 0.0:
			return int(takers[weight_index])
	return int(takers.back())

func _advance_progress() -> void:
	rooms_completed += 1
	if not _selected_node_id.is_empty() and not visited_node_ids.has(_selected_node_id):
		visited_node_ids.append(_selected_node_id)
	current_node_id = _selected_node_id
	reachable_node_ids = current_node.get("next_node_ids", []).duplicate()
	current_step_index = int(current_node.get("row", current_step_index)) + 1
	_selected_node_id = ""
	current_node = {}
	if reachable_node_ids.is_empty():
		current_step_index = node_map.size()

func _build_outcome(title: String, summary: String, action: String) -> Dictionary:
	return {
		"title": title,
		"summary": summary,
		"action": action,
		"post_action": "next",
		"button_text": "Continue",
		"choice_mode": "",
		"choices": [],
	}

func _get_random_layout_id() -> String:
	var layouts := ["default", "crossfire", "pinch", "offset", "pillars", "ring", "pockets"]
	return layouts[_random.randi_range(0, layouts.size() - 1)]

func _resolve_recipe_layout_id(template: Dictionary, room_objective: String, recipe_layout: String) -> String:
	if template.has("layout_id"):
		return str(template.get("layout_id", "default"))
	if not recipe_layout.is_empty():
		return recipe_layout
	if room_objective == "destroy_generators":
		return "gauntlet_pockets"
	if room_objective == "capture_the_hill":
		return "ring"
	return _get_random_layout_id()

func _resolve_recipe_modifier(template: Dictionary, step_index: int, recipe_modifier_id: String, room_objective: String) -> Dictionary:
	if template.has("modifier") and template.get("modifier", {}) is Dictionary:
		var template_modifier: Dictionary = template.get("modifier", {}).duplicate(true)
		return template_modifier if _is_modifier_allowed_for_objective(template_modifier, room_objective) else {}
	if not recipe_modifier_id.is_empty():
		var recipe_modifier: Dictionary = _modifier_engine.get_modifier_by_id(recipe_modifier_id)
		if not recipe_modifier.is_empty() and int(recipe_modifier.get("min_step", 0)) <= step_index and _is_modifier_allowed_for_objective(recipe_modifier, room_objective):
			return recipe_modifier
	return {}

func _is_modifier_allowed_for_objective(modifier: Dictionary, room_objective: String) -> bool:
	if modifier.is_empty():
		return true
	if room_objective == "destroy_generators" and not str(modifier.get("spawn_side", "")).strip_edges().is_empty():
		return false
	return true

func _get_forced_recipe_id() -> String:
	if not bool(debug_run_setup.get("enabled", false)):
		return ""
	return str(debug_run_setup.get("test_recipe_id", "")).strip_edges()

func _rebuild_node_lookup() -> void:
	_node_lookup = {}
	for row in node_map:
		if not (row is Array):
			continue
		for node in row:
			if node is Dictionary:
				_node_lookup[str(node.get("id", ""))] = node

func _extract_row_node_ids(row: Array) -> Array:
	var node_ids: Array = []
	for node in row:
		if node is Dictionary:
			node_ids.append(str(node.get("id", "")))
	return node_ids

func _collect_reachable_node_ids(_map: Array, starting_ids: Array, lookup: Dictionary) -> Array:
	var reachable: Array = []
	var queue: Array = starting_ids.duplicate()
	while not queue.is_empty():
		var node_id := str(queue.pop_front())
		if reachable.has(node_id) or not lookup.has(node_id):
			continue
		reachable.append(node_id)
		var node: Dictionary = lookup[node_id]
		for next_node_id in node.get("next_node_ids", []):
			var next_id := str(next_node_id)
			if not reachable.has(next_id):
				queue.append(next_id)
	return reachable

func _contains_reachable_room_type(reachable_ids: Array, lookup: Dictionary, room_type: String) -> bool:
	for node_id in reachable_ids:
		if not lookup.has(node_id):
			continue
		if str((lookup[node_id] as Dictionary).get("room_type", "")) == room_type:
			return true
	return false
