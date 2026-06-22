class_name MutationSystem
extends RefCounted

const MUTATIONS_DATA_PATH := "res://data/mutations.json"
const PER_TAG_RATE := 0.12

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

static func get_base_projectile_visual(projectile_kind: String) -> Dictionary:
	match projectile_kind:
		"bullet":
			return {"projectile_shape": "small_orb", "trail_style": "thin", "impact_sfx": "hit"}
		"pellet":
			return {"projectile_shape": "small_orb", "trail_style": "short", "impact_sfx": "spread"}
		"slug":
			return {"projectile_shape": "large_orb", "trail_style": "heavy_slow", "impact_sfx": "thump"}
		"lance":
			return {"projectile_shape": "lance", "trail_style": "sharp", "impact_sfx": "zip"}
		"boomerang":
			return {"projectile_shape": "diamond", "trail_style": "sharp", "impact_sfx": "ping"}
		"rocket":
			return {"projectile_shape": "ember_orb", "trail_style": "embers", "impact_sfx": "boom"}
		"beam":
			return {"projectile_shape": "lance", "trail_style": "beam", "impact_sfx": "beam"}
		_:
			return {"projectile_shape": "small_orb", "trail_style": "thin", "impact_sfx": "hit"}

func get_compiled_weapon_stats(player_index: int, base_stats: Dictionary) -> Dictionary:
	var compiled: Dictionary = base_stats.duplicate(true)
	var tag_power := _compute_tag_power(player_index)
	if str(compiled.get("projectile_kind", "bullet")) == "beam":
		return _get_compiled_beam_stats(player_index, compiled, tag_power)
	var rapid_fire_count := get_mutation_level(player_index, "rapid_fire")
	compiled["rapid_fire_level"] = rapid_fire_count
	if rapid_fire_count > 0:
		compiled["fire_rate_bonus"] = float(rapid_fire_count) * float(_get_param("rapid_fire", "fire_rate_bonus_per_level", 0.30))
	var velocity_count := get_mutation_level(player_index, "velocity")
	compiled["velocity_level"] = velocity_count
	if velocity_count > 0:
		compiled["projectile_speed"] = _apply_additive_percent(float(compiled.get("projectile_speed", 850.0)), [float(velocity_count) * float(_get_param("velocity", "speed_bonus_per_level", 0.333))])
	var high_caliber_count := get_mutation_level(player_index, "high_caliber")
	if high_caliber_count > 0:
		compiled["damage_bonus"] = float(high_caliber_count) * float(_get_param("high_caliber", "damage_bonus_per_level", 0.20))
	var range_count := get_mutation_level(player_index, "range")
	if range_count > 0:
		compiled["range"] = _apply_additive_percent(float(compiled.get("range", 950.0)), [float(range_count) * float(_get_param("range", "range_bonus_per_level", 0.20))])
	if has_mutation(player_index, "ricochet"):
		compiled["split_count"] = int(_get_param("ricochet", "split_count", 1))
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
	_apply_tag_power_to_weapon_effects(compiled, tag_power)
	_apply_signature_weapon_flags(player_index, compiled)
	_map_weapon_stats_to_projectile_keys(compiled)
	return compiled

func _get_compiled_beam_stats(player_index: int, compiled: Dictionary, tag_power: Dictionary) -> Dictionary:
	var rapid_fire_count := get_mutation_level(player_index, "rapid_fire")
	compiled["rapid_fire_level"] = rapid_fire_count
	var dps_bonuses := []
	var ramp_bonuses := []
	var high_caliber_count := get_mutation_level(player_index, "high_caliber")
	if high_caliber_count > 0:
		dps_bonuses.append(float(high_caliber_count) * float(_get_param("high_caliber", "damage_bonus_per_level", 0.20)))
	if rapid_fire_count > 0:
		var rapid_fire_bonus := float(rapid_fire_count) * float(_get_param("rapid_fire", "fire_rate_bonus_per_level", 0.30))
		dps_bonuses.append(rapid_fire_bonus)
		ramp_bonuses.append(rapid_fire_bonus)
	if not dps_bonuses.is_empty():
		compiled["max_damage_per_second"] = _apply_additive_percent(float(compiled.get("max_damage_per_second", 120.0)), dps_bonuses)
	if not ramp_bonuses.is_empty():
		compiled["ramp_seconds"] = maxf(0.1, float(compiled.get("ramp_seconds", 1.5)) / (1.0 + _sum_percent_bonuses(ramp_bonuses)))
	var range_count := get_mutation_level(player_index, "range")
	if range_count > 0:
		compiled["range"] = _apply_additive_percent(float(compiled.get("range", 750.0)), [float(range_count) * float(_get_param("range", "range_bonus_per_level", 0.20))])
	if has_mutation(player_index, "fire_trail"):
		compiled["leaves_fire_trail"] = true
		compiled["trail_tick_interval"] = float(_get_param("fire_trail", "tick_interval", 0.5))
		compiled["impact_pool_radius"] = float(_get_param("fire_trail", "impact_pool_radius", 90.0))
		compiled["impact_pool_lifetime"] = float(_get_param("fire_trail", "impact_pool_lifetime", 3.0))
		compiled["impact_pool_damage_percent"] = float(_get_param("fire_trail", "impact_pool_damage_percent", 0.5))
		compiled["beam_fire_pool_cooldown"] = 0.5
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
	_apply_tag_power_to_weapon_effects(compiled, tag_power)
	_apply_signature_weapon_flags(player_index, compiled)
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
	return 1.0 + get_move_speed_bonus(player_index)

func get_move_speed_bonus(player_index: int) -> float:
	var level := get_mutation_level(player_index, "move_speed")
	if level <= 0:
		return 0.0
	var values: Array = _get_param("move_speed", "move_speed_values", [0.15, 0.3, 0.45]) as Array
	return float(values[mini(level - 1, values.size() - 1)])

func get_max_health_multiplier(player_index: int) -> float:
	var level := get_mutation_level(player_index, "tough")
	var multiplier := 1.0
	if level <= 0:
		multiplier = 1.0
	else:
		var values: Array = _get_param("tough", "max_health_values", [0.2, 0.4, 0.6]) as Array
		multiplier = 1.0 + float(values[mini(level - 1, values.size() - 1)])
	for mutation_id in RunState.get_mutations(player_index):
		if not _definition_map.has(str(mutation_id)):
			continue
		var params: Dictionary = (_definition_map[str(mutation_id)] as Dictionary).get("params", {}) as Dictionary
		multiplier += float(params.get("max_health_mult", 0.0))
	return maxf(multiplier, 0.1)

func is_healing_disabled(player_index: int) -> bool:
	for mutation_id in RunState.get_mutations(player_index):
		if not _definition_map.has(str(mutation_id)):
			continue
		var params: Dictionary = (_definition_map[str(mutation_id)] as Dictionary).get("params", {}) as Dictionary
		if bool(params.get("heal_disabled", false)):
			return true
	return false

func roll_mutation_options(player_index: int, count: int, rare_chance: float = 0.0, force_rare: bool = false, signature_share: float = 0.0) -> Array:
	var common_pool: Array = []
	var rare_pool: Array = []
	var signature_pool: Array = []
	for mutation in _definitions:
		var mutation_dict: Dictionary = mutation as Dictionary
		var mutation_id := str(mutation_dict.get("id", ""))
		if mutation_id.is_empty():
			continue
		if not _is_mutation_unlocked(mutation_id):
			continue
		if not _can_still_pick(player_index, mutation_id):
			continue
		var rarity := _get_rarity(mutation_id)
		if rarity == "signature":
			signature_pool.append(mutation_dict.duplicate(true))
		elif rarity == "rare":
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
	signature_pool.shuffle()
	var selected: Array = []
	var clamped_rare_chance := clampf(rare_chance, 0.0, 1.0)
	var clamped_signature_share := clampf(signature_share, 0.0, 1.0)
	if force_rare and (not rare_pool.is_empty() or not signature_pool.is_empty()):
		selected.append(_pop_rare_or_better_option(rare_pool, signature_pool, clamped_signature_share))
	while selected.size() < count:
		var use_rare := false
		if not rare_pool.is_empty() or not signature_pool.is_empty():
			use_rare = common_pool.is_empty() or _random.randf() < clamped_rare_chance
		if use_rare:
			selected.append(_pop_rare_or_better_option(rare_pool, signature_pool, clamped_signature_share))
		elif not common_pool.is_empty():
			selected.append(_pop_option(common_pool))
		elif not rare_pool.is_empty() or not signature_pool.is_empty():
			selected.append(_pop_rare_or_better_option(rare_pool, signature_pool, clamped_signature_share))
		else:
			break
	_remove_empty_options(selected)
	_enforce_parasite_choice_invariant(selected, common_pool, rare_pool, signature_pool)
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
	if not _is_mutation_unlocked(mutation_id):
		return false
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

func _is_mutation_unlocked(mutation_id: String) -> bool:
	return ProfileState == null or ProfileState.is_content_unlocked("mutation", mutation_id)

func _get_param(mutation_id: String, param_name: String, default_value: Variant) -> Variant:
	if not _definition_map.has(mutation_id):
		return default_value
	var params: Dictionary = (_definition_map[mutation_id] as Dictionary).get("params", {})
	return params.get(param_name, default_value)

func _compute_tag_power(player_index: int) -> Dictionary:
	var tag_counts: Dictionary = {}
	for mutation_id_variant in RunState.get_mutations(player_index):
		var mutation_id := str(mutation_id_variant)
		if not _definition_map.has(mutation_id):
			continue
		var definition: Dictionary = _definition_map[mutation_id] as Dictionary
		for tag_variant in (definition.get("tags", []) as Array):
			var tag := str(tag_variant)
			tag_counts[tag] = int(tag_counts.get(tag, 0)) + 1
		var params: Dictionary = definition.get("params", {}) as Dictionary
		var tag_stacks: Dictionary = params.get("tag_stacks", {}) as Dictionary
		for tag_variant in tag_stacks.keys():
			var tag := str(tag_variant)
			tag_counts[tag] = int(tag_counts.get(tag, 0)) + int(tag_stacks[tag_variant])
	var tag_power: Dictionary = {}
	for tag_variant in tag_counts.keys():
		var tag := str(tag_variant)
		tag_power[tag] = 1.0 + float(tag_counts[tag]) * PER_TAG_RATE
	return tag_power

func _apply_tag_power_to_weapon_effects(compiled: Dictionary, tag_power: Dictionary) -> void:
	var fire_power := float(tag_power.get("fire", 1.0))
	if fire_power > 1.0:
		if compiled.has("trail_damage_percent"):
			compiled["trail_damage_percent"] = float(compiled.get("trail_damage_percent", 0.0)) * fire_power
		if compiled.has("impact_pool_damage_percent"):
			compiled["impact_pool_damage_percent"] = float(compiled.get("impact_pool_damage_percent", 0.0)) * fire_power
	var toxic_power := float(tag_power.get("toxic", 1.0))
	if toxic_power > 1.0:
		if compiled.has("poison_dps"):
			compiled["poison_dps"] = float(compiled.get("poison_dps", 0.0)) * toxic_power
		if compiled.has("poison_duration"):
			compiled["poison_duration"] = float(compiled.get("poison_duration", 0.0)) * toxic_power
	var frost_power := float(tag_power.get("frost", 1.0))
	if frost_power > 1.0:
		if compiled.has("slow_step"):
			var slow_step := float(compiled.get("slow_step", 1.0))
			compiled["slow_step"] = clampf(1.0 - ((1.0 - slow_step) * frost_power), 0.01, 1.0)
		if compiled.has("slow_duration"):
			compiled["slow_duration"] = float(compiled.get("slow_duration", 0.0)) * frost_power
	var split_power := float(tag_power.get("split", 1.0))
	if split_power > 1.0 and compiled.has("split_count"):
		compiled["split_count"] = int(compiled.get("split_count", 0)) + int(round((split_power - 1.0) / PER_TAG_RATE))

func _apply_signature_weapon_flags(player_index: int, compiled: Dictionary) -> void:
	if has_mutation(player_index, "chain_reaction"):
		compiled["split_count"] = int(compiled.get("split_count", 0)) + int(_get_param("chain_reaction", "split_count_bonus", 1))
		compiled["split_can_split"] = true
	if has_mutation(player_index, "ember_spread"):
		compiled["ignite_on_death"] = true
		compiled["ignite_radius"] = float(_get_param("ember_spread", "ignite_radius", 130.0))
		compiled["ignite_damage_percent"] = float(_get_param("ember_spread", "ignite_damage_percent", 0.55))
	if has_mutation(player_index, "cryo_shatter"):
		compiled["shatter_on_frozen_death"] = true
		compiled["shatter_radius"] = float(_get_param("cryo_shatter", "shatter_radius", 125.0))
		compiled["shatter_damage_percent"] = float(_get_param("cryo_shatter", "shatter_damage_percent", 0.5))
	if has_mutation(player_index, "momentum_surge"):
		compiled["pierce_at_max_momentum"] = int(_get_param("momentum_surge", "pierce_at_max_momentum", 3))
	if has_mutation(player_index, "glass_cannon"):
		compiled["damage_bonus"] = float(compiled.get("damage_bonus", 0.0)) + float(_get_param("glass_cannon", "damage_bonus", 0.8))

func _sum_percent_bonuses(percent_bonuses: Array) -> float:
	var total := 0.0
	for bonus in percent_bonuses:
		total += float(bonus)
	return total

func _apply_additive_percent(base_value: float, percent_bonuses: Array) -> float:
	return base_value * (1.0 + _sum_percent_bonuses(percent_bonuses))

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
	if bool(compiled.get("infinite_pierce", false)):
		compiled["infinite_pierce"] = true
	if compiled.has("blast_radius"):
		compiled["explosion_radius"] = float(compiled.get("blast_radius", 0.0))
	if compiled.has("blast_damage_percent"):
		compiled["explosion_damage_percent"] = float(compiled.get("blast_damage_percent", 0.0))
	var projectile_kind := str(compiled.get("projectile_kind", "bullet"))
	var visual := get_base_projectile_visual(projectile_kind)
	compiled["projectile_shape"] = str(visual.get("projectile_shape", "small_orb"))
	compiled["trail_style"] = str(visual.get("trail_style", "thin"))
	compiled["impact_sfx"] = str(visual.get("impact_sfx", "hit"))

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

func _pop_rare_or_better_option(rare_pool: Array, signature_pool: Array, signature_share: float) -> Dictionary:
	var prefer_signature := _random.randf() < clampf(signature_share, 0.0, 1.0)
	if prefer_signature:
		if not signature_pool.is_empty():
			return _pop_option(signature_pool)
		if not rare_pool.is_empty():
			return _pop_option(rare_pool)
	else:
		if not rare_pool.is_empty():
			return _pop_option(rare_pool)
		if not signature_pool.is_empty():
			return _pop_option(signature_pool)
	return {}

func _remove_empty_options(options: Array) -> void:
	for index in range(options.size() - 1, -1, -1):
		if not (options[index] is Dictionary) or (options[index] as Dictionary).is_empty():
			options.remove_at(index)

func _enforce_parasite_choice_invariant(selected: Array, common_pool: Array, rare_pool: Array, signature_pool: Array) -> void:
	if selected.is_empty():
		return
	for option_variant in selected:
		var option := option_variant as Dictionary
		if not bool(option.get("is_parasite", false)):
			return
	var selected_ids: Dictionary = {}
	for option_variant in selected:
		var option := option_variant as Dictionary
		selected_ids[str(option.get("id", ""))] = true
	var replacement := _pop_first_non_parasite(common_pool, selected_ids)
	if replacement.is_empty():
		replacement = _pop_first_non_parasite(rare_pool, selected_ids)
	if replacement.is_empty():
		replacement = _pop_first_non_parasite(signature_pool, selected_ids)
	if replacement.is_empty():
		return
	selected[0] = replacement

func _pop_first_non_parasite(pool: Array, excluded_ids: Dictionary) -> Dictionary:
	for index in range(pool.size()):
		var option := pool[index] as Dictionary
		var option_id := str(option.get("id", ""))
		if excluded_ids.has(option_id):
			continue
		if bool(option.get("is_parasite", false)):
			continue
		pool.remove_at(index)
		return option
	return {}
