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

func get_compiled_weapon_stats(player_index: int, base_stats: Dictionary) -> Dictionary:
	var compiled: Dictionary = base_stats.duplicate(true)
	var split_count := get_mutation_level(player_index, "split_shot")
	if split_count > 0:
		compiled["split_extra_count"] = split_count * int(_get_param("split_shot", "extra_count", 1))
		compiled["split_spread_degrees"] = float(_get_param("split_shot", "spread_degrees", 15.0))
	var big_shot_count := get_mutation_level(player_index, "big_shot")
	if big_shot_count > 0:
		var size_mult := 1.0 + float(big_shot_count) * float(_get_param("big_shot", "size_bonus_per_level", 0.333))
		compiled["area"] = float(compiled.get("area", 4.0)) * size_mult
	var rapid_fire_count := get_mutation_level(player_index, "rapid_fire")
	compiled["rapid_fire_level"] = rapid_fire_count
	if rapid_fire_count > 0:
		compiled["fire_rate"] = float(compiled.get("fire_rate", 1.0)) * (1.0 + float(rapid_fire_count) * float(_get_param("rapid_fire", "fire_rate_bonus_per_level", 0.333)))
	var velocity_count := get_mutation_level(player_index, "velocity")
	compiled["velocity_level"] = velocity_count
	if velocity_count > 0:
		compiled["projectile_speed"] = float(compiled.get("projectile_speed", 850.0)) * (1.0 + float(velocity_count) * float(_get_param("velocity", "speed_bonus_per_level", 0.333)))
	var pierce_count := get_mutation_level(player_index, "pierce")
	if pierce_count > 0:
		compiled["pierce_count"] = pierce_count * int(_get_param("pierce", "pierce_count", 1))
	var ricochet_count := get_mutation_level(player_index, "ricochet")
	if ricochet_count > 0:
		compiled["ricochet_count"] = ricochet_count * int(_get_param("ricochet", "bounce_count", 1))
		compiled["ricochet_range"] = float(_get_param("ricochet", "bounce_range", 200.0))
	if has_mutation(player_index, "fire_trail"):
		compiled["leaves_fire_trail"] = true
		compiled["trail_lifetime"] = float(_get_param("fire_trail", "trail_lifetime", 1.5))
		compiled["trail_tick_interval"] = float(_get_param("fire_trail", "tick_interval", 0.5))
		compiled["trail_damage_percent"] = float(_get_param("fire_trail", "damage_percent", 0.3))
		compiled["impact_pool_radius"] = float(_get_param("fire_trail", "impact_pool_radius", 90.0))
		compiled["impact_pool_lifetime"] = float(_get_param("fire_trail", "impact_pool_lifetime", 3.0))
		compiled["impact_pool_damage_percent"] = float(_get_param("fire_trail", "impact_pool_damage_percent", 0.5))
	if has_mutation(player_index, "explosive_rounds"):
		compiled["explosion_radius"] = float(_get_param("explosive_rounds", "explosion_radius", 82.0))
		compiled["explosion_damage_percent"] = float(_get_param("explosive_rounds", "damage_percent", 0.65))
	if has_mutation(player_index, "freeze_shot"):
		compiled["slow_multiplier"] = float(_get_param("freeze_shot", "slow_multiplier", 0.5))
		compiled["slow_duration"] = float(_get_param("freeze_shot", "slow_duration", 1.0))
	if has_mutation(player_index, "poison"):
		compiled["poison_dps"] = float(_get_param("poison", "poison_dps", 8.0))
		compiled["poison_duration"] = float(_get_param("poison", "poison_duration", 2.5))
	var knockback_count := get_mutation_level(player_index, "knockback")
	compiled["knockback_level"] = knockback_count
	if knockback_count > 0:
		compiled["knockback_force"] = 300.0 * (1.0 + float(knockback_count) * float(_get_param("knockback", "force_bonus_per_level", 0.333)))
	return compiled

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

func get_knockback_multiplier(player_index: int) -> float:
	var level := get_mutation_level(player_index, "knockback")
	if level <= 0:
		return 1.0
	return 1.0 + float(level) * float(_get_param("knockback", "force_bonus_per_level", 0.333))

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
	if _is_stackable(mutation_id):
		return get_mutation_level(player_index, mutation_id) < _get_max_level(mutation_id)
	return not has_mutation(player_index, mutation_id)

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

func _pop_option(pool: Array) -> Dictionary:
	if pool.is_empty():
		return {}
	var option: Dictionary = pool[0] as Dictionary
	pool.remove_at(0)
	return option
