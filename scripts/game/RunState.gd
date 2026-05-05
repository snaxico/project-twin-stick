extends Node

const ModifierEngineData = preload("res://scripts/game/ModifierEngine.gd")
const ITEMS_DATA_PATH = "res://data/items.json"
const RUN_LENGTH_MIN := 5
const RUN_LENGTH_MAX := 7
const MAX_CONSECUTIVE_COMBATS := 3
const MIN_COMBAT_ROOMS_BEFORE_BOSS := 2
const BASE_GOLD_COMBAT := 2
const BASE_GOLD_ELITE := 3
const GOLD_PER_STEP := 0.5

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
	_load_items()

func start_new_run(configs: Array, debug_options: Dictionary = {}) -> void:
	_load_items()
	_random.randomize()
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
	print("[RunState] Run seed: %d | Steps: %d" % [_random.seed, node_map.size()])
	current_step_index = 0
	current_node = {}
	rooms_completed = 0
	gold = 0
	acquired_item_ids = []
	build_state = _build_default_build_state()
	_apply_debug_start_options(debug_options)
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
	var secondary_profile := _get_secondary_profile(str(build_state.get("secondary_profile", "mine")))
	var loadout := {
		"move_speed": 260.0 * float(build_state.get("move_speed_mult", 1.0)),
		"primary_profile_name": str(primary_profile.get("label", "Rifle")),
		"secondary_profile_name": str(secondary_profile.get("label", "Mine")),
		"primary_projectile_count": int(primary_profile.get("projectile_count", 1)),
		"primary_spread_radians": float(primary_profile.get("spread_radians", 0.0)),
		"primary_fire_interval": 0.27 * float(build_state.get("primary_fire_interval_mult", 1.0)) * float(primary_profile.get("fire_interval_mult", 1.0)),
		"projectile_speed": 540.0 * float(build_state.get("projectile_speed_mult", 1.0)) * float(primary_profile.get("projectile_speed_mult", 1.0)),
		"projectile_damage": max(1, int(round((1.0 + float(build_state.get("projectile_damage_bonus", 0.0))) * float(primary_profile.get("damage_mult", 1.0))))),
		"secondary_projectile_count": int(secondary_profile.get("projectile_count", 1)),
		"secondary_spread_radians": float(secondary_profile.get("spread_radians", 0.0)),
		"secondary_cooldown": 4.0 * float(build_state.get("secondary_cooldown_mult", 1.0)) * float(secondary_profile.get("cooldown_mult", 1.0)),
		"secondary_projectile_speed": float(secondary_profile.get("base_projectile_speed", 0.0)) * float(build_state.get("secondary_projectile_speed_mult", 1.0)) * float(secondary_profile.get("projectile_speed_mult", 1.0)),
		"secondary_damage": max(1, int(round((3.0 + float(build_state.get("secondary_damage_bonus", 0.0))) * float(secondary_profile.get("damage_mult", 1.0))))),
		"secondary_projectile_kind": str(secondary_profile.get("kind", "mine")),
		"secondary_explosion_radius": 92.0 * float(build_state.get("secondary_explosion_radius_mult", 1.0)) * float(secondary_profile.get("explosion_radius_mult", 1.0)),
		"secondary_fuse_time": float(secondary_profile.get("base_fuse_time", 12.0)) * float(secondary_profile.get("fuse_time_mult", 1.0)),
		"secondary_gravity_force": float(secondary_profile.get("base_gravity_force", 0.0)) * float(secondary_profile.get("gravity_force_mult", 1.0)),
		"secondary_pulse_count": int(secondary_profile.get("pulse_count", 1)),
		"secondary_pulse_interval": float(secondary_profile.get("pulse_interval", 0.18)),
		"secondary_cluster_blast_count": int(secondary_profile.get("cluster_blast_count", 0)),
		"secondary_cluster_spread_radius": 52.0 * float(secondary_profile.get("cluster_spread_radius_mult", 1.0)),
		"secondary_proximity_radius": float(secondary_profile.get("base_proximity_radius", 52.0)) * float(secondary_profile.get("proximity_radius_mult", 1.0)),
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
	var run_length := _random.randi_range(RUN_LENGTH_MIN, RUN_LENGTH_MAX)
	var primary_types: Array = []
	for _index in range(run_length):
		primary_types.append("combat")

	var support_slots: Array = []
	for slot_index in range(1, run_length):
		support_slots.append(slot_index)
	if support_slots.size() < 2:
		print("[RunState] Support slot generation underflow. Falling back to default pattern.")
		return _generate_fallback_node_map()
	support_slots.shuffle()
	var rest_slot: int = int(support_slots.pop_back())
	var shop_slot: int = int(support_slots.pop_back())

	for step_index in range(run_length):
		if step_index == rest_slot:
			primary_types[step_index] = "rest"
		elif step_index == shop_slot:
			primary_types[step_index] = "shop"
		else:
			primary_types[step_index] = "elite" if _random.randf() < 0.3 else "combat"

	_normalize_primary_room_types(primary_types)

	var steps: Array = []
	for step_index in range(run_length):
		var primary_type: String = str(primary_types[step_index])
		var alternative_type: String = _pick_alternative_type(primary_type)
		var options: Array = [
			_build_node(step_index, 0, _build_room_template(primary_type)),
			_build_node(step_index, 1, _build_room_template(alternative_type)),
		]
		steps.append(options)

	steps.append([
		_build_node(run_length, 0, _build_room_template("boss")),
	])

	if _validate_node_map(steps):
		return steps
	print("[RunState] Generated node map failed validation. Falling back to default pattern.")
	return _generate_fallback_node_map()

func _generate_fallback_node_map() -> Array:
	var room_patterns := [
		[
			_build_room_template("combat"),
			_build_room_template("rest"),
		],
		[
			_build_room_template("combat"),
			_build_room_template("shop"),
		],
		[
			_build_room_template("elite"),
			_build_room_template("combat"),
		],
		[
			_build_room_template("elite"),
			_build_room_template("rest"),
		],
		[
			_build_room_template("combat"),
			_build_room_template("elite"),
		],
		[
			_build_room_template("boss"),
		],
	]
	var steps: Array = []
	for step_index in range(room_patterns.size()):
		var options: Array = []
		for option_index in range(room_patterns[step_index].size()):
			options.append(_build_node(step_index, option_index, room_patterns[step_index][option_index]))
		steps.append(options)
	return steps

func _build_room_template(room_type: String) -> Dictionary:
	match room_type:
		"combat", "elite":
			return {
				"room_type": room_type,
				"reward": {"type": "loot_choice", "label": "Choose 1 shared upgrade"},
			}
		"rest":
			return {
				"room_type": "rest",
				"reward": {"type": "heal_all", "amount": 2, "label": "Recover 2 HP"},
			}
		"shop":
			return {
				"room_type": "shop",
				"reward": {"type": "shop", "label": "Spend shared Gold on one upgrade"},
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

func _validate_node_map(map: Array) -> bool:
	if map.is_empty():
		return false
	var last_step = map[map.size() - 1]
	if not (last_step is Array) or last_step.size() != 1:
		return false
	var boss_node = last_step[0]
	if not (boss_node is Dictionary) or str(boss_node.get("room_type", "")) != "boss":
		return false

	var pressure_options := 0
	var has_rest := false
	var has_shop := false
	for step_index in range(map.size() - 1):
		var step_options = map[step_index]
		if not (step_options is Array) or step_options.is_empty():
			return false
		for option in step_options:
			if not (option is Dictionary):
				return false
			var room_type := str(option.get("room_type", ""))
			if _is_pressure_room_type(room_type):
				pressure_options += 1
			elif room_type == "rest":
				has_rest = true
			elif room_type == "shop":
				has_shop = true

	if pressure_options < MIN_COMBAT_ROOMS_BEFORE_BOSS:
		return false
	return has_rest and has_shop

func _is_pressure_room_type(room_type: String) -> bool:
	return room_type == "combat" or room_type == "elite"

func _build_node(step_index: int, option_index: int, template: Dictionary) -> Dictionary:
	var room_type := str(template.get("room_type", "combat"))
	var reward: Dictionary = template.get("reward", {}).duplicate(true)
	var is_elite := room_type == "elite"
	var node := {
		"id": "step_%d_option_%d" % [step_index, option_index],
		"step_index": step_index,
		"room_type": room_type,
		"reward": reward,
		"reward_label": str(template.get("reward_label", reward.get("label", "No reward"))),
		"currency_reward": _compute_gold_reward(room_type, step_index),
	}

	match room_type:
		"combat":
			node["title"] = "Combat Room"
			node["survival_duration"] = _compute_survival_duration(step_index, false)
			node["enemy_spawn_interval"] = _compute_spawn_interval(step_index, false)
			node["modifier"] = _modifier_engine.get_random_modifier()
			node["layout_id"] = _get_random_layout_id()
			node["reward_label"] = "+%d Gold + shared upgrade" % node["currency_reward"]
		"elite":
			node["title"] = "Elite Room"
			node["survival_duration"] = _compute_survival_duration(step_index, is_elite)
			node["enemy_spawn_interval"] = _compute_spawn_interval(step_index, is_elite)
			node["modifier"] = _modifier_engine.get_random_modifier()
			node["layout_id"] = _get_random_layout_id()
			node["reward_label"] = "+%d Gold + shared upgrade" % node["currency_reward"]
		"rest":
			node["title"] = "Rest Room"
			node["currency_reward"] = 0
			node["modifier"] = {}
			node["description"] = "Take a breather and patch everyone up."
			node["reward_label"] = "Recover 2 HP"
		"shop":
			node["title"] = "Shop Room"
			node["currency_reward"] = 0
			node["modifier"] = {}
			node["description"] = "Spend shared Gold on one prototype upgrade."
			node["reward_label"] = "Spend shared Gold"
		"boss":
			node["title"] = "Crimson Gate"
			node["currency_reward"] = 0
			node["modifier"] = {}
			node["description"] = "Final room. Defeat the placeholder boss to finish the run."
			node["layout_id"] = "boss_gate"
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
				state["current"] = min(int(state.get("current", 0)) + amount, int(state.get("max", 5)))
			return str(reward.get("label", "Recovered health"))
		_:
			return str(reward.get("label", "No reward"))

func _build_default_build_state() -> Dictionary:
	return {
		"primary_profile": "rifle",
		"secondary_profile": "mine",
		"move_speed_mult": 1.0,
		"primary_fire_interval_mult": 1.0,
		"projectile_speed_mult": 1.0,
		"projectile_damage_bonus": 0.0,
		"secondary_cooldown_mult": 1.0,
		"secondary_projectile_speed_mult": 1.0,
		"secondary_damage_bonus": 0.0,
		"secondary_explosion_radius_mult": 1.0,
	}

func _apply_debug_start_options(debug_options: Dictionary) -> void:
	if debug_options.is_empty():
		return
	if bool(debug_options.get("enabled", false)) == false:
		return

	var primary_profile := str(debug_options.get("primary_profile", ""))
	var secondary_profile := str(debug_options.get("secondary_profile", ""))
	if not primary_profile.is_empty():
		build_state["primary_profile"] = primary_profile
	if not secondary_profile.is_empty():
		build_state["secondary_profile"] = secondary_profile

func _get_primary_profile(profile_id: String) -> Dictionary:
	var profiles := {
		"rifle": {"label": "Rifle", "projectile_count": 1, "spread_radians": 0.0, "fire_interval_mult": 1.0, "projectile_speed_mult": 1.0, "damage_mult": 1.0},
		"spread": {"label": "Scatter", "projectile_count": 3, "spread_radians": 0.18, "fire_interval_mult": 1.35, "projectile_speed_mult": 0.95, "damage_mult": 0.65},
		"slug": {"label": "Slug", "projectile_count": 1, "spread_radians": 0.0, "fire_interval_mult": 2.1, "projectile_speed_mult": 1.2, "damage_mult": 2.4},
	}
	return profiles.get(profile_id, profiles["rifle"]).duplicate(true)

func _get_secondary_profile(profile_id: String) -> Dictionary:
	var normalized_profile_id := _normalize_secondary_profile_id(profile_id)
	var profiles := {
		"grenade": {"label": "Grenade", "kind": "grenade", "projectile_count": 1, "spread_radians": 0.0, "cooldown_mult": 1.0, "base_projectile_speed": 125.0, "projectile_speed_mult": 1.0, "damage_mult": 1.0, "explosion_radius_mult": 1.0, "base_fuse_time": 1.0, "fuse_time_mult": 1.0, "base_gravity_force": 520.0, "gravity_force_mult": 1.0, "pulse_count": 1, "pulse_interval": 0.18, "cluster_blast_count": 0, "cluster_spread_radius_mult": 1.0, "base_proximity_radius": 0.0, "proximity_radius_mult": 1.0},
		"cluster_grenade": {"label": "Cluster Grenade", "kind": "cluster_grenade", "projectile_count": 1, "spread_radians": 0.0, "cooldown_mult": 0.92, "base_projectile_speed": 125.0, "projectile_speed_mult": 1.0, "damage_mult": 0.8, "explosion_radius_mult": 0.78, "base_fuse_time": 1.0, "fuse_time_mult": 1.0, "base_gravity_force": 520.0, "gravity_force_mult": 1.0, "pulse_count": 1, "pulse_interval": 0.18, "cluster_blast_count": 4, "cluster_spread_radius_mult": 1.0, "base_proximity_radius": 0.0, "proximity_radius_mult": 1.0},
		"siege_grenade": {"label": "Siege Grenade", "kind": "siege_grenade", "projectile_count": 1, "spread_radians": 0.0, "cooldown_mult": 1.35, "base_projectile_speed": 125.0, "projectile_speed_mult": 1.0, "damage_mult": 1.1, "explosion_radius_mult": 1.35, "base_fuse_time": 1.0, "fuse_time_mult": 1.0, "base_gravity_force": 520.0, "gravity_force_mult": 1.0, "pulse_count": 3, "pulse_interval": 0.18, "cluster_blast_count": 0, "cluster_spread_radius_mult": 1.0, "base_proximity_radius": 0.0, "proximity_radius_mult": 1.0},
		"mine": {"label": "Mine", "kind": "mine", "projectile_count": 1, "spread_radians": 0.0, "cooldown_mult": 1.0, "base_projectile_speed": 0.0, "projectile_speed_mult": 0.0, "damage_mult": 1.0, "explosion_radius_mult": 1.0, "base_fuse_time": 12.0, "fuse_time_mult": 1.0, "base_gravity_force": 0.0, "gravity_force_mult": 0.0, "pulse_count": 1, "pulse_interval": 0.18, "cluster_blast_count": 0, "cluster_spread_radius_mult": 1.0, "base_proximity_radius": 52.0, "proximity_radius_mult": 1.0},
		"shrapnel_mine": {"label": "Shrapnel Mine", "kind": "shrapnel_mine", "projectile_count": 1, "spread_radians": 0.0, "cooldown_mult": 0.92, "base_projectile_speed": 0.0, "projectile_speed_mult": 0.0, "damage_mult": 0.82, "explosion_radius_mult": 0.82, "base_fuse_time": 12.0, "fuse_time_mult": 1.0, "base_gravity_force": 0.0, "gravity_force_mult": 0.0, "pulse_count": 1, "pulse_interval": 0.18, "cluster_blast_count": 4, "cluster_spread_radius_mult": 1.0, "base_proximity_radius": 52.0, "proximity_radius_mult": 0.95},
		"heavy_mine": {"label": "Heavy Mine", "kind": "heavy_mine", "projectile_count": 1, "spread_radians": 0.0, "cooldown_mult": 1.3, "base_projectile_speed": 0.0, "projectile_speed_mult": 0.0, "damage_mult": 1.15, "explosion_radius_mult": 1.35, "base_fuse_time": 12.0, "fuse_time_mult": 1.0, "base_gravity_force": 0.0, "gravity_force_mult": 0.0, "pulse_count": 3, "pulse_interval": 0.18, "cluster_blast_count": 0, "cluster_spread_radius_mult": 1.0, "base_proximity_radius": 52.0, "proximity_radius_mult": 1.2},
	}
	return profiles.get(normalized_profile_id, profiles["mine"]).duplicate(true)

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
		build_state["secondary_profile"] = _normalize_secondary_profile_id(str(effects.get("set_secondary_profile", "mine")))
	if effects.has("primary_fire_interval_mult"):
		build_state["primary_fire_interval_mult"] = float(build_state.get("primary_fire_interval_mult", 1.0)) * float(effects.get("primary_fire_interval_mult", 1.0))
	if effects.has("projectile_speed_mult"):
		build_state["projectile_speed_mult"] = float(build_state.get("projectile_speed_mult", 1.0)) * float(effects.get("projectile_speed_mult", 1.0))
	if effects.has("projectile_damage_bonus"):
		build_state["projectile_damage_bonus"] = float(build_state.get("projectile_damage_bonus", 0.0)) + float(effects.get("projectile_damage_bonus", 0.0))
	if effects.has("move_speed_mult"):
		build_state["move_speed_mult"] = float(build_state.get("move_speed_mult", 1.0)) * float(effects.get("move_speed_mult", 1.0))
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
