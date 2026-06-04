class_name MutationSystem
extends RefCounted

const MUTATIONS_DATA_PATH := "res://data/mutations.json"

var _definitions: Array = []
var _definition_map: Dictionary = {}
var _random := RandomNumberGenerator.new()

func _init() -> void:
	_random.randomize()
	_load_definitions()

func _load_definitions() -> void:
	_definitions.clear()
	_definition_map.clear()
	if not FileAccess.file_exists(MUTATIONS_DATA_PATH):
		return
	var file := FileAccess.open(MUTATIONS_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	var raw_mutations = parsed.get("mutations", [])
	if not (raw_mutations is Array):
		return
	for entry in raw_mutations:
		if not (entry is Dictionary):
			continue
		var mutation: Dictionary = (entry as Dictionary).duplicate(true)
		var mutation_id := str(mutation.get("id", ""))
		if mutation_id.is_empty():
			continue
		_definitions.append(mutation)
		_definition_map[mutation_id] = mutation

func apply_mutation(player_index: int, mutation_id: String) -> void:
	if mutation_id == "__weapon_levelup":
		RunState.level_up_weapon(player_index)
		return
	if mutation_id.begins_with("__weapon_change__"):
		RunState.set_active_weapon(player_index, mutation_id.trim_prefix("__weapon_change__"))
		return
	if not _definition_map.has(mutation_id):
		return
	if not _can_still_pick(player_index, mutation_id):
		return
	var inventory = RunState.get_player_inventory(player_index)
	if inventory == null:
		return
	inventory.mutations.append(mutation_id)

func has_mutation(player_index: int, mutation_id: String) -> bool:
	return get_mutation_count(player_index, mutation_id) > 0

func get_mutation_count(player_index: int, mutation_id: String) -> int:
	var count := 0
	for entry in RunState.get_mutations(player_index):
		if str(entry) == mutation_id:
			count += 1
	return count

func get_mutation_level(player_index: int, mutation_id: String) -> int:
	return mini(get_mutation_count(player_index, mutation_id), _get_max_level(mutation_id))

func get_active_mutations(player_index: int) -> Array:
	var active: Array = []
	for mutation_id in RunState.get_mutations(player_index):
		if _definition_map.has(str(mutation_id)):
			active.append((_definition_map[str(mutation_id)] as Dictionary).duplicate(true))
	return active

func get_definition(mutation_id: String) -> Dictionary:
	if not _definition_map.has(mutation_id):
		return {}
	return (_definition_map[mutation_id] as Dictionary).duplicate(true)

func get_compiled_weapon_stats(player_index: int, base_stats: Dictionary) -> Dictionary:
	var compiled: Dictionary = base_stats.duplicate(true)
	var rapid_fire_count := get_mutation_level(player_index, "rapid_fire")
	compiled["rapid_fire_level"] = rapid_fire_count
	if rapid_fire_count > 0:
		compiled["fire_rate"] = float(compiled.get("fire_rate", 1.0)) * (1.0 + float(rapid_fire_count) * float(_get_param("rapid_fire", "fire_rate_bonus_per_level", 0.30)))
	var velocity_count := get_mutation_level(player_index, "velocity")
	compiled["velocity_level"] = velocity_count
	if velocity_count > 0:
		compiled["projectile_speed"] = float(compiled.get("projectile_speed", 850.0)) * (1.0 + float(velocity_count) * float(_get_param("velocity", "speed_bonus_per_level", 0.333)))
	var high_caliber_count := get_mutation_level(player_index, "high_caliber")
	if high_caliber_count > 0:
		compiled["damage"] = float(compiled.get("damage", 10.0)) * (1.0 + float(high_caliber_count) * float(_get_param("high_caliber", "damage_bonus_per_level", 0.20)))
	var range_count := get_mutation_level(player_index, "range")
	if range_count > 0:
		compiled["range"] = float(compiled.get("range", 950.0)) * (1.0 + float(range_count) * float(_get_param("range", "range_bonus_per_level", 0.20)))
	if has_mutation(player_index, "ricochet"):
		compiled["ricochet_count"] = int(_get_param("ricochet", "bounce_count", 1))
		compiled["ricochet_range"] = float(_get_param("ricochet", "bounce_range", 200.0))
		_apply_projectile_visual_fields(compiled, "ricochet")
	if has_mutation(player_index, "fire_trail"):
		compiled["leaves_fire_trail"] = true
		compiled["trail_lifetime"] = float(_get_param("fire_trail", "trail_lifetime", 1.5))
		compiled["trail_tick_interval"] = float(_get_param("fire_trail", "tick_interval", 0.5))
		compiled["trail_damage_percent"] = float(_get_param("fire_trail", "damage_percent", 0.3))
		compiled["impact_pool_radius"] = float(_get_param("fire_trail", "impact_pool_radius", 90.0))
		compiled["impact_pool_lifetime"] = float(_get_param("fire_trail", "impact_pool_lifetime", 3.0))
		compiled["impact_pool_damage_percent"] = float(_get_param("fire_trail", "impact_pool_damage_percent", 0.5))
		_apply_projectile_visual_fields(compiled, "fire_trail")
	if has_mutation(player_index, "freeze_shot"):
		compiled["slow_step"] = float(_get_param("freeze_shot", "slow_step", 0.8))
		compiled["slow_floor"] = float(_get_param("freeze_shot", "slow_floor", 0.15))
		compiled["slow_duration"] = float(_get_param("freeze_shot", "slow_duration", 1.0))
		_apply_projectile_visual_fields(compiled, "freeze_shot")
	if has_mutation(player_index, "poison"):
		compiled["poison_dps"] = float(_get_param("poison", "poison_dps", 8.0))
		compiled["poison_duration"] = float(_get_param("poison", "poison_duration", 2.5))
		_apply_projectile_visual_fields(compiled, "poison")
	var knockback_count := get_mutation_level(player_index, "knockback")
	compiled["knockback_level"] = knockback_count
	var base_knockback := float(compiled.get("knockback", compiled.get("knockback_force", 0.0)))
	var knockback_bonus := get_knockback_bonus(player_index)
	if base_knockback + knockback_bonus > 0.0:
		compiled["knockback_force"] = base_knockback + knockback_bonus
	_map_weapon_stats_to_projectile_keys(compiled)
	return compiled

func get_ability_rare_effects(player_index: int, ability_id: String) -> Dictionary:
	var effects: Dictionary = {}
	for mutation_id_variant in RunState.get_mutations(player_index):
		var mutation_id := str(mutation_id_variant)
		if not _definition_map.has(mutation_id):
			continue
		var mutation: Dictionary = _definition_map[mutation_id] as Dictionary
		if str(mutation.get("category", "")) != "ability":
			continue
		if str(mutation.get("requires_ability", "")) != ability_id:
			continue
		var params: Dictionary = (mutation.get("params", {}) as Dictionary).duplicate(true)
		for key in params.keys():
			effects[str(key)] = params[key]
		effects[str(mutation_id)] = true
	return effects

func get_ability_area_multiplier(player_index: int) -> float:
	return 1.0 + float(get_mutation_level(player_index, "wide_pulse")) * float(_get_param("wide_pulse", "area_bonus_per_level", 0.333))

func get_ability_cooldown_reduction(player_index: int) -> float:
	var level := get_mutation_level(player_index, "quick_reflexes")
	if level <= 0:
		return 0.0
	var values: Array = _get_param("quick_reflexes", "cooldown_values", [0.2, 0.35, 0.5]) as Array
	if values.is_empty():
		return 0.0
	return float(values[mini(level - 1, values.size() - 1)])

func get_ability_duration_multiplier(player_index: int) -> float:
	return 1.0 + float(get_mutation_level(player_index, "duration")) * float(_get_param("duration", "duration_bonus_per_level", 0.333))

func get_move_speed_multiplier(player_index: int) -> float:
	var level := get_mutation_level(player_index, "move_speed")
	if level <= 0:
		return 1.0
	var values: Array = _get_param("move_speed", "move_speed_values", [0.15, 0.3, 0.45]) as Array
	return 1.0 + float(values[mini(level - 1, values.size() - 1)])

func get_max_health_multiplier(player_index: int) -> float:
	var level := get_mutation_level(player_index, "tough")
	if level <= 0:
		return 1.0
	var values: Array = _get_param("tough", "max_health_values", [0.2, 0.4, 0.6]) as Array
	return 1.0 + float(values[mini(level - 1, values.size() - 1)])

func get_knockback_multiplier(_player_index: int) -> float:
	return 1.0

func get_knockback_bonus(player_index: int) -> float:
	var level := get_mutation_level(player_index, "knockback")
	if level <= 0:
		return 0.0
	return float(level) * float(_get_param("knockback", "force_per_level", 120.0))

func roll_mutation_options(player_index: int, count: int, rare_chance: float = 0.0, force_rare: bool = false) -> Array:
	var common_pool: Array = []
	var rare_pool: Array = []
	for mutation in _definitions:
		var mutation_dict: Dictionary = mutation as Dictionary
		var mutation_id := str(mutation_dict.get("id", ""))
		if mutation_id.is_empty():
			continue
		if not _can_still_pick(player_index, mutation_id):
			continue
		if _get_rarity(mutation_id) == "rare":
			rare_pool.append(mutation_dict.duplicate(true))
		else:
			common_pool.append(mutation_dict.duplicate(true))
	var weapon_cards := _build_weapon_cards(player_index)
	for weapon_common in (weapon_cards.get("common", []) as Array):
		common_pool.append((weapon_common as Dictionary).duplicate(true))
	for weapon_rare in (weapon_cards.get("rare", []) as Array):
		rare_pool.append((weapon_rare as Dictionary).duplicate(true))
	common_pool.shuffle()
	rare_pool.shuffle()
	var selected: Array = []
	var clamped_rare_chance := clampf(rare_chance, 0.0, 1.0)
	if force_rare and not rare_pool.is_empty():
		selected.append(_pop_option(rare_pool))
	while selected.size() < count:
		var use_rare := false
		if not rare_pool.is_empty():
			use_rare = common_pool.is_empty() or _random.randf() < clamped_rare_chance
		if use_rare:
			selected.append(_pop_option(rare_pool))
		elif not common_pool.is_empty():
			selected.append(_pop_option(common_pool))
		elif not rare_pool.is_empty():
			selected.append(_pop_option(rare_pool))
		else:
			break
	selected.shuffle()
	return selected

func reset(player_index: int) -> void:
	var inventory = RunState.get_player_inventory(player_index)
	if inventory == null:
		return
	inventory.mutations.clear()

func _is_stackable(mutation_id: String) -> bool:
	return _get_rarity(mutation_id) == "common"

func _can_still_pick(player_index: int, mutation_id: String) -> bool:
	if not _required_ability_is_equipped(player_index, mutation_id):
		return false
	if _is_stackable(mutation_id):
		return get_mutation_level(player_index, mutation_id) < _get_max_level(mutation_id)
	return not has_mutation(player_index, mutation_id)

func _required_ability_is_equipped(player_index: int, mutation_id: String) -> bool:
	if not _definition_map.has(mutation_id):
		return false
	var required_ability := str((_definition_map[mutation_id] as Dictionary).get("requires_ability", ""))
	if required_ability.is_empty():
		return true
	var inventory = RunState.get_player_inventory(player_index)
	if inventory == null:
		return false
	return str(inventory.ability_slot_1) == required_ability or str(inventory.ability_slot_2) == required_ability

func _get_rarity(mutation_id: String) -> String:
	if not _definition_map.has(mutation_id):
		return "common"
	return str((_definition_map[mutation_id] as Dictionary).get("rarity", "common"))

func _get_max_level(mutation_id: String) -> int:
	if not _definition_map.has(mutation_id):
		return 1
	return max(int((_definition_map[mutation_id] as Dictionary).get("max_level", 1)), 1)

func _get_param(mutation_id: String, param_name: String, default_value: Variant) -> Variant:
	if not _definition_map.has(mutation_id):
		return default_value
	var params: Dictionary = (_definition_map[mutation_id] as Dictionary).get("params", {})
	return params.get(param_name, default_value)

func _apply_projectile_visual_fields(compiled: Dictionary, mutation_id: String) -> void:
	if not _definition_map.has(mutation_id):
		return
	var definition: Dictionary = _definition_map[mutation_id] as Dictionary
	compiled["projectile_shape"] = str(definition.get("projectile_shape", compiled.get("projectile_shape", "orb")))
	compiled["trail_style"] = str(definition.get("trail_style", compiled.get("trail_style", "default")))
	compiled["impact_sfx"] = str(definition.get("impact_sfx", compiled.get("impact_sfx", "hit")))
	compiled["accent_color"] = _parse_color(definition.get("accent_color", compiled.get("accent_color", Color.WHITE)), Color.WHITE)

func _map_weapon_stats_to_projectile_keys(compiled: Dictionary) -> void:
	if compiled.has("pellet_count"):
		compiled["split_extra_count"] = maxi(0, int(compiled.get("pellet_count", 1)) - 1)
	if compiled.has("spread_degrees"):
		compiled["split_spread_degrees"] = float(compiled.get("spread_degrees", 0.0))
	if compiled.has("pierce"):
		compiled["pierce_count"] = int(compiled.get("pierce", 0))
	if compiled.has("blast_radius"):
		compiled["explosion_radius"] = float(compiled.get("blast_radius", 0.0))
	if compiled.has("blast_damage_percent"):
		compiled["explosion_damage_percent"] = float(compiled.get("blast_damage_percent", 0.0))
	if compiled.has("knockback") and not compiled.has("knockback_force"):
		compiled["knockback_force"] = float(compiled.get("knockback", 0.0))
	var projectile_kind := str(compiled.get("projectile_kind", "bullet"))
	match projectile_kind:
		"bullet":
			compiled["projectile_shape"] = "small_orb"
			compiled["trail_style"] = "thin"
			compiled["impact_sfx"] = "hit"
		"pellet":
			compiled["projectile_shape"] = "small_orb"
			compiled["trail_style"] = "short"
			compiled["impact_sfx"] = "spread"
		"slug":
			compiled["projectile_shape"] = "large_orb"
			compiled["trail_style"] = "heavy_slow"
			compiled["impact_sfx"] = "thump"
		"lance":
			compiled["projectile_shape"] = "lance"
			compiled["trail_style"] = "sharp"
			compiled["impact_sfx"] = "zip"
		"rocket":
			compiled["projectile_shape"] = "ember_orb"
			compiled["trail_style"] = "embers"
			compiled["impact_sfx"] = "boom"

func _build_weapon_cards(player_index: int) -> Dictionary:
	var common: Array = []
	var rare: Array = []
	var weapon_level := RunState.get_weapon_level(player_index)
	var active_weapon_id := RunState.get_active_weapon_id(player_index)
	var active_weapon_name := _get_weapon_name(active_weapon_id)
	if weapon_level < 5:
		common.append({
			"id": "__weapon_levelup",
			"name": "Level Up Weapon",
			"description": "Raise %s to Lv%d. Weapon level carries when switching." % [active_weapon_name, weapon_level + 1],
			"icon": active_weapon_id,
			"category": "weapon",
			"group": "weapon",
			"rarity": "common",
		})
	for weapon in RunState.get_weapon_catalog():
		var weapon_id := str((weapon as Dictionary).get("id", ""))
		if weapon_id.is_empty() or weapon_id == active_weapon_id:
			continue
		rare.append({
			"id": "__weapon_change__%s" % weapon_id,
			"name": "Switch: %s" % str((weapon as Dictionary).get("name", weapon_id)),
			"description": "Switch to %s at Lv%d." % [str((weapon as Dictionary).get("name", weapon_id)), weapon_level],
			"icon": weapon_id,
			"category": "weapon",
			"group": "weapon",
			"rarity": "rare",
		})
	return {"common": common, "rare": rare}

func _get_weapon_name(weapon_id: String) -> String:
	for weapon in RunState.get_weapon_catalog():
		var weapon_dict: Dictionary = weapon as Dictionary
		if str(weapon_dict.get("id", "")) == weapon_id:
			return str(weapon_dict.get("name", weapon_id))
	return weapon_id.capitalize()

func _parse_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array:
		var parts: Array = value as Array
		if parts.size() >= 3:
			return Color(float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3]) if parts.size() > 3 else 1.0)
	if value is String:
		return Color.html(str(value))
	return fallback

func _pop_option(pool: Array) -> Dictionary:
	if pool.is_empty():
		return {}
	var option: Dictionary = pool[0] as Dictionary
	pool.remove_at(0)
	return option
