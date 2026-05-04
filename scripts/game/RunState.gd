extends Node

const ModifierEngineData = preload("res://scripts/game/ModifierEngine.gd")
const ITEMS_DATA_PATH = "res://data/items.json"

var player_configs: Array = []
var player_health_states: Array = []
var node_map: Array = []
var current_step_index: int = 0
var current_node: Dictionary = {}
var rooms_completed: int = 0
var gold: int = 0
var acquired_item_ids: Array = []
var build_state: Dictionary = {}
var run_outcome: String = "in_progress"

var _modifier_engine = ModifierEngineData.new()
var _random := RandomNumberGenerator.new()
var _items: Array = []
var _items_by_id: Dictionary = {}

func _ready() -> void:
	_random.randomize()
	_load_items()

func start_new_run(configs: Array) -> void:
	_load_items()
	player_configs = []
	for config in configs:
		player_configs.append(config)

	player_health_states = []
	for _index in range(player_configs.size()):
		player_health_states.append({
			"current": 5,
			"max": 5,
		})

	node_map = _generate_node_map()
	current_step_index = 0
	current_node = {}
	rooms_completed = 0
	gold = 0
	acquired_item_ids = []
	build_state = _build_default_build_state()
	run_outcome = "in_progress"

func get_current_options() -> Array:
	if current_step_index < 0 or current_step_index >= node_map.size():
		return []
	return node_map[current_step_index]

func set_current_node(node: Dictionary) -> void:
	current_node = node.duplicate(true)

func resolve_current_noncombat_node() -> Dictionary:
	if current_node.is_empty():
		return _build_outcome("No node selected.", "No node selected.", "next")

	var room_type := str(current_node.get("room_type", "rest"))
	var room_title := str(current_node.get("title", "Room"))
	var room_description := str(current_node.get("description", ""))
	var outcome := _build_outcome(room_title, room_description, "next")

	match room_type:
		"shop":
			_advance_progress()
			outcome["summary"] = "Shared Gold: %d\nChoose one shared prototype upgrade or leave the shop." % gold
			outcome["action"] = "shop"
			outcome["button_text"] = "Open Shop"
			outcome["choice_mode"] = "shop"
			outcome["choices"] = _roll_item_choices("shop", 3)
		_:
			var result_text := _apply_reward(current_node.get("reward", {}))
			_advance_progress()
			outcome["summary"] = "%s\n%s" % [room_description, result_text]

	return outcome

func resolve_current_combat_victory(health_states: Array) -> Dictionary:
	if current_node.is_empty():
		return _build_outcome("No combat node selected.", "No combat node selected.", "next")

	set_player_health_states(health_states)
	var room_title := str(current_node.get("title", "Room"))
	var summary_lines := ["Room cleared."]
	var gold_gain := int(current_node.get("currency_reward", 0))
	if gold_gain > 0:
		gold += gold_gain
		summary_lines.append("Gained %d Gold. Shared total: %d." % [gold_gain, gold])

	var outcome := _build_outcome(room_title, "\n".join(summary_lines), "next")
	var reward: Dictionary = current_node.get("reward", {}).duplicate(true)
	if str(reward.get("type", "")) == "loot_choice":
		outcome["summary"] = "%s\nChoose one shared upgrade." % outcome["summary"]
		outcome["action"] = "reward"
		outcome["button_text"] = "Choose Upgrade"
		outcome["choice_mode"] = "reward"
		outcome["choices"] = _roll_item_choices("reward", 3)
	else:
		var result_text := _apply_reward(reward)
		outcome["summary"] = "%s\n%s" % [outcome["summary"], result_text]

	_advance_progress()
	if str(current_node.get("room_type", "")) == "boss" or is_run_complete():
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
			"max": int(state.get("max", 5)),
		})

func is_run_complete() -> bool:
	return current_step_index >= node_map.size()

func get_run_summary_text() -> String:
	return "Rooms cleared: %d\nShared Gold: %d" % [rooms_completed, gold]

func get_player_runtime_loadout() -> Dictionary:
	var primary_profile := _get_primary_profile(str(build_state.get("primary_profile", "rifle")))
	var secondary_profile := _get_secondary_profile(str(build_state.get("secondary_profile", "grenade")))
	var loadout := {
		"move_speed": 260.0 * float(build_state.get("move_speed_mult", 1.0)),
		"primary_profile_name": str(primary_profile.get("label", "Rifle")),
		"secondary_profile_name": str(secondary_profile.get("label", "Grenade")),
		"primary_projectile_count": int(primary_profile.get("projectile_count", 1)),
		"primary_spread_radians": float(primary_profile.get("spread_radians", 0.0)),
		"primary_fire_interval": 0.18 * float(build_state.get("primary_fire_interval_mult", 1.0)) * float(primary_profile.get("fire_interval_mult", 1.0)),
		"projectile_speed": 540.0 * float(build_state.get("projectile_speed_mult", 1.0)) * float(primary_profile.get("projectile_speed_mult", 1.0)),
		"projectile_damage": max(1, int(round((1.0 + float(build_state.get("projectile_damage_bonus", 0.0))) * float(primary_profile.get("damage_mult", 1.0))))),
		"secondary_projectile_count": int(secondary_profile.get("projectile_count", 1)),
		"secondary_spread_radians": float(secondary_profile.get("spread_radians", 0.0)),
		"secondary_cooldown": 4.0 * float(build_state.get("secondary_cooldown_mult", 1.0)) * float(secondary_profile.get("cooldown_mult", 1.0)),
		"secondary_projectile_speed": 320.0 * float(build_state.get("secondary_projectile_speed_mult", 1.0)) * float(secondary_profile.get("projectile_speed_mult", 1.0)),
		"secondary_damage": max(1, int(round((3.0 + float(build_state.get("secondary_damage_bonus", 0.0))) * float(secondary_profile.get("damage_mult", 1.0))))),
		"secondary_projectile_kind": "grenade",
		"secondary_explosion_radius": 92.0 * float(build_state.get("secondary_explosion_radius_mult", 1.0)) * float(secondary_profile.get("explosion_radius_mult", 1.0)),
		"secondary_fuse_time": 1.0 * float(secondary_profile.get("fuse_time_mult", 1.0)),
		"secondary_gravity_force": 520.0 * float(secondary_profile.get("gravity_force_mult", 1.0)),
	}
	return loadout

func claim_reward_item(item_id: String) -> Dictionary:
	var item := _get_item(item_id)
	if item.is_empty():
		return {"success": false, "title": "Upgrade Missing", "summary": "The selected reward item no longer exists."}
	var summary := _apply_item(item)
	return {"success": true, "title": "Upgrade Acquired", "summary": summary}

func purchase_shop_item(item_id: String) -> Dictionary:
	var item := _get_item(item_id)
	if item.is_empty():
		return {"success": false, "title": "Shop Error", "summary": "The selected shop item no longer exists."}

	var cost := int(item.get("cost", 0))
	if cost > gold:
		return {"success": false, "title": "Not Enough Gold", "summary": "Need %d Gold. Current shared total: %d." % [cost, gold]}

	gold -= cost
	var summary := "%s\nShared Gold left: %d." % [_apply_item(item), gold]
	return {"success": true, "title": "Purchase Complete", "summary": summary}

func _generate_node_map() -> Array:
	var steps: Array = []
	var room_patterns := [
		[
			{"room_type": "combat", "currency_reward": 2, "reward": {"type": "loot_choice", "label": "Choose 1 shared upgrade"}, "reward_label": "+2 Gold + shared upgrade"},
			{"room_type": "rest", "reward": {"type": "heal_all", "amount": 2, "label": "Recover 2 HP"}},
		],
		[
			{"room_type": "combat", "currency_reward": 2, "reward": {"type": "loot_choice", "label": "Choose 1 shared upgrade"}, "reward_label": "+2 Gold + shared upgrade"},
			{"room_type": "shop", "reward": {"type": "shop", "label": "Spend shared Gold on one upgrade"}, "reward_label": "Spend shared Gold"},
		],
		[
			{"room_type": "elite", "currency_reward": 3, "reward": {"type": "loot_choice", "label": "Choose 1 shared upgrade"}, "reward_label": "+3 Gold + shared upgrade"},
			{"room_type": "combat", "currency_reward": 2, "reward": {"type": "loot_choice", "label": "Choose 1 shared upgrade"}, "reward_label": "+2 Gold + shared upgrade"},
		],
		[
			{"room_type": "elite", "currency_reward": 3, "reward": {"type": "loot_choice", "label": "Choose 1 shared upgrade"}, "reward_label": "+3 Gold + shared upgrade"},
			{"room_type": "rest", "reward": {"type": "heal_all", "amount": 2, "label": "Recover 2 HP"}},
		],
		[
			{"room_type": "combat", "currency_reward": 3, "reward": {"type": "loot_choice", "label": "Choose 1 shared upgrade"}, "reward_label": "+3 Gold + shared upgrade"},
			{"room_type": "elite", "currency_reward": 4, "reward": {"type": "loot_choice", "label": "Choose 1 shared upgrade"}, "reward_label": "+4 Gold + shared upgrade"},
		],
		[
			{"room_type": "boss", "reward": {"type": "none", "label": "Defeat the boss"}, "reward_label": "Finish the run"},
		],
	]

	for step_index in range(room_patterns.size()):
		var options: Array = []
		for option_index in range(room_patterns[step_index].size()):
			options.append(_build_node(step_index, option_index, room_patterns[step_index][option_index]))
		steps.append(options)

	return steps

func _build_node(step_index: int, option_index: int, template: Dictionary) -> Dictionary:
	var room_type := str(template.get("room_type", "combat"))
	var reward: Dictionary = template.get("reward", {}).duplicate(true)
	var node := {
		"id": "step_%d_option_%d" % [step_index, option_index],
		"step_index": step_index,
		"room_type": room_type,
		"reward": reward,
		"reward_label": str(template.get("reward_label", reward.get("label", "No reward"))),
		"currency_reward": int(template.get("currency_reward", 0)),
	}

	match room_type:
		"combat":
			node["title"] = "Combat Room"
			node["survival_duration"] = 18.0
			node["enemy_spawn_interval"] = 4.0
			node["modifier"] = _modifier_engine.get_random_modifier()
			node["layout_id"] = _get_random_layout_id()
		"elite":
			node["title"] = "Elite Room"
			node["survival_duration"] = 24.0
			node["enemy_spawn_interval"] = 3.4
			node["modifier"] = _modifier_engine.get_random_modifier()
			node["layout_id"] = _get_random_layout_id()
		"rest":
			node["title"] = "Rest Room"
			node["modifier"] = {}
			node["description"] = "Take a breather and patch everyone up."
		"shop":
			node["title"] = "Shop Room"
			node["modifier"] = {}
			node["description"] = "Spend shared Gold on one prototype upgrade."
		"boss":
			node["title"] = "Crimson Gate"
			node["modifier"] = {}
			node["description"] = "Final room. Defeat the placeholder boss to finish the run."
			node["layout_id"] = "boss_gate"
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
				state["current"] = min(int(state.get("current", 0)) + amount, int(state.get("max", 5)))
			return str(reward.get("label", "Recovered health"))
		_:
			return str(reward.get("label", "No reward"))

func _build_default_build_state() -> Dictionary:
	return {
		"primary_profile": "rifle",
		"secondary_profile": "grenade",
		"move_speed_mult": 1.0,
		"primary_fire_interval_mult": 1.0,
		"projectile_speed_mult": 1.0,
		"projectile_damage_bonus": 0.0,
		"secondary_cooldown_mult": 1.0,
		"secondary_projectile_speed_mult": 1.0,
		"secondary_damage_bonus": 0.0,
		"secondary_explosion_radius_mult": 1.0,
	}

func _get_primary_profile(profile_id: String) -> Dictionary:
	var profiles := {
		"rifle": {"label": "Rifle", "projectile_count": 1, "spread_radians": 0.0, "fire_interval_mult": 1.0, "projectile_speed_mult": 1.0, "damage_mult": 1.0},
		"spread": {"label": "Scatter", "projectile_count": 3, "spread_radians": 0.18, "fire_interval_mult": 1.15, "projectile_speed_mult": 0.95, "damage_mult": 0.65},
		"slug": {"label": "Slug", "projectile_count": 1, "spread_radians": 0.0, "fire_interval_mult": 1.7, "projectile_speed_mult": 1.2, "damage_mult": 2.4},
	}
	return profiles.get(profile_id, profiles["rifle"]).duplicate(true)

func _get_secondary_profile(profile_id: String) -> Dictionary:
	var profiles := {
		"grenade": {"label": "Grenade", "projectile_count": 1, "spread_radians": 0.0, "cooldown_mult": 1.0, "projectile_speed_mult": 1.0, "damage_mult": 1.0, "explosion_radius_mult": 1.0, "fuse_time_mult": 1.0, "gravity_force_mult": 1.0},
		"cluster": {"label": "Cluster", "projectile_count": 2, "spread_radians": 0.2, "cooldown_mult": 1.15, "projectile_speed_mult": 1.0, "damage_mult": 0.7, "explosion_radius_mult": 0.8, "fuse_time_mult": 0.95, "gravity_force_mult": 1.0},
		"siege": {"label": "Siege", "projectile_count": 1, "spread_radians": 0.0, "cooldown_mult": 1.35, "projectile_speed_mult": 0.85, "damage_mult": 1.7, "explosion_radius_mult": 1.35, "fuse_time_mult": 1.15, "gravity_force_mult": 1.0},
	}
	return profiles.get(profile_id, profiles["grenade"]).duplicate(true)

func _load_items() -> void:
	_items = []
	_items_by_id = {}
	if not FileAccess.file_exists(ITEMS_DATA_PATH):
		return

	var file := FileAccess.open(ITEMS_DATA_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return

	var raw_items = parsed.get("items", [])
	if not (raw_items is Array):
		return

	for entry in raw_items:
		if not (entry is Dictionary):
			continue
		var item: Dictionary = entry.duplicate(true)
		var item_id := str(item.get("id", ""))
		if item_id.is_empty():
			continue
		_items.append(item)
		_items_by_id[item_id] = item

func _roll_item_choices(pool_name: String, count: int) -> Array:
	var available: Array = []
	for item in _items:
		var item_id := str(item.get("id", ""))
		var item_pools = item.get("pools", [])
		var repeatable := bool(item.get("repeatable", false))
		if not (item_pools is Array) or not item_pools.has(pool_name):
			continue
		if not ProfileState.has_item_unlock(item_id):
			continue
		if not repeatable and acquired_item_ids.has(item_id):
			continue
		available.append(item.duplicate(true))
		
	if available.is_empty():
		for item in _items:
			var item_id := str(item.get("id", ""))
			var item_pools = item.get("pools", [])
			if item_pools is Array and item_pools.has(pool_name) and ProfileState.has_item_unlock(item_id):
				available.append(item.duplicate(true))

	var choices: Array = []
	while choices.size() < count and not available.is_empty():
		var index := _random.randi_range(0, available.size() - 1)
		choices.append(available[index])
		available.remove_at(index)
	return choices

func _get_item(item_id: String) -> Dictionary:
	if not _items_by_id.has(item_id):
		return {}
	return _items_by_id[item_id].duplicate(true)

func _apply_item(item: Dictionary) -> String:
	var item_id := str(item.get("id", ""))
	if not bool(item.get("repeatable", false)) and not acquired_item_ids.has(item_id):
		acquired_item_ids.append(item_id)

	var effects: Dictionary = item.get("effects", {})
	if effects.has("set_primary_profile"):
		build_state["primary_profile"] = str(effects.get("set_primary_profile", "rifle"))
	if effects.has("set_secondary_profile"):
		build_state["secondary_profile"] = str(effects.get("set_secondary_profile", "grenade"))
	if effects.has("primary_fire_interval_mult"):
		build_state["primary_fire_interval_mult"] = float(build_state.get("primary_fire_interval_mult", 1.0)) * float(effects.get("primary_fire_interval_mult", 1.0))
	if effects.has("projectile_speed_mult"):
		build_state["projectile_speed_mult"] = float(build_state.get("projectile_speed_mult", 1.0)) * float(effects.get("projectile_speed_mult", 1.0))
	if effects.has("projectile_damage_bonus"):
		build_state["projectile_damage_bonus"] = float(build_state.get("projectile_damage_bonus", 0.0)) + float(effects.get("projectile_damage_bonus", 0.0))
	if effects.has("secondary_cooldown_mult"):
		build_state["secondary_cooldown_mult"] = float(build_state.get("secondary_cooldown_mult", 1.0)) * float(effects.get("secondary_cooldown_mult", 1.0))
	if effects.has("secondary_projectile_speed_mult"):
		build_state["secondary_projectile_speed_mult"] = float(build_state.get("secondary_projectile_speed_mult", 1.0)) * float(effects.get("secondary_projectile_speed_mult", 1.0))
	if effects.has("secondary_damage_bonus"):
		build_state["secondary_damage_bonus"] = float(build_state.get("secondary_damage_bonus", 0.0)) + float(effects.get("secondary_damage_bonus", 0.0))
	if effects.has("secondary_explosion_radius_mult"):
		build_state["secondary_explosion_radius_mult"] = float(build_state.get("secondary_explosion_radius_mult", 1.0)) * float(effects.get("secondary_explosion_radius_mult", 1.0))
	if effects.has("max_health_bonus"):
		var max_health_bonus := int(effects.get("max_health_bonus", 0))
		for state in player_health_states:
			state["max"] = int(state.get("max", 5)) + max_health_bonus
			state["current"] = int(state.get("current", 5)) + max_health_bonus

	return "%s\n%s" % [str(item.get("name", "Upgrade")), str(item.get("description", ""))]

func _advance_progress() -> void:
	rooms_completed += 1
	current_step_index += 1

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
	var layouts := ["default", "crossfire", "pinch", "offset"]
	return layouts[_random.randi_range(0, layouts.size() - 1)]
