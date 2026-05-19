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

func get_active_mutations(player_index: int) -> Array:
	var active: Array = []
	for mutation_id in RunState.get_mutations(player_index):
		if _definition_map.has(str(mutation_id)):
			active.append((_definition_map[str(mutation_id)] as Dictionary).duplicate(true))
	return active

func get_compiled_weapon_stats(player_index: int, base_stats: Dictionary) -> Dictionary:
	var compiled: Dictionary = base_stats.duplicate(true)
	var split_count := get_mutation_count(player_index, "split_shot")
	if split_count > 0:
		compiled["split_extra_count"] = split_count * int(_get_param("split_shot", "extra_count", 2))
		compiled["split_spread_degrees"] = float(_get_param("split_shot", "spread_degrees", 15.0))
	var big_shot_count := get_mutation_count(player_index, "big_shot")
	if big_shot_count > 0:
		var size_mult: float = 1.0
		for _index in range(big_shot_count):
			size_mult *= float(_get_param("big_shot", "size_mult", 2.0))
		compiled["area"] = float(compiled.get("area", 4.0)) * size_mult
		compiled["damage"] = float(compiled.get("damage", 1.0)) * (1.0 + 0.5 * float(big_shot_count))
	var rapid_fire_count := get_mutation_count(player_index, "rapid_fire")
	if rapid_fire_count > 0:
		compiled["fire_rate"] = float(compiled.get("fire_rate", 1.0)) * pow(float(_get_param("rapid_fire", "fire_rate_mult", 2.0)), rapid_fire_count)
	var pierce_count := get_mutation_count(player_index, "pierce")
	if pierce_count > 0:
		compiled["pierce_count"] = pierce_count * int(_get_param("pierce", "pierce_count", 1))
	var ricochet_count := get_mutation_count(player_index, "ricochet")
	if ricochet_count > 0:
		compiled["ricochet_count"] = ricochet_count * int(_get_param("ricochet", "bounce_count", 1))
		compiled["ricochet_range"] = float(_get_param("ricochet", "bounce_range", 200.0))
	if has_mutation(player_index, "fire_trail"):
		compiled["leaves_fire_trail"] = true
		compiled["trail_lifetime"] = float(_get_param("fire_trail", "trail_lifetime", 1.5))
		compiled["trail_tick_interval"] = float(_get_param("fire_trail", "tick_interval", 0.5))
		compiled["trail_damage_percent"] = float(_get_param("fire_trail", "damage_percent", 0.3))
	var knockback_count := get_mutation_count(player_index, "knockback")
	if knockback_count > 0:
		compiled["knockback_force"] = float(_get_param("knockback", "force", 300.0)) * knockback_count
	return compiled

func get_secondary_radius_multiplier(player_index: int) -> float:
	return 1.0 + 0.5 * float(get_mutation_count(player_index, "shockwave_radius"))

func get_shockwave_cooldown_reduction(player_index: int) -> float:
	return float(get_mutation_count(player_index, "shockwave_cooldown")) * float(_get_param("shockwave_cooldown", "cooldown_reduction", 2.0))

func get_dash_damage_multiplier(player_index: int) -> float:
	return float(_get_param("dash_damage", "damage_percent", 1.0)) if has_mutation(player_index, "dash_damage") else 0.0

func roll_mutation_options(player_index: int, count: int) -> Array:
	var options: Array = []
	var pool: Array = _definitions.duplicate(true)
	pool.shuffle()
	var owned_counts: Dictionary = {}
	for mutation_id in RunState.get_mutations(player_index):
		var normalized_id := str(mutation_id)
		owned_counts[normalized_id] = int(owned_counts.get(normalized_id, 0)) + 1
	for mutation in pool:
		if options.size() >= count:
			break
		var mutation_id := str((mutation as Dictionary).get("id", ""))
		if mutation_id.is_empty():
			continue
		var current_count: int = int(owned_counts.get(mutation_id, 0))
		if current_count > 0 and not _is_stackable(mutation_id):
			continue
		options.append((mutation as Dictionary).duplicate(true))
	while options.size() < count and not _definitions.is_empty():
		options.append((_definitions[options.size() % _definitions.size()] as Dictionary).duplicate(true))
	return options

func reset(player_index: int) -> void:
	var inventory = RunState.get_player_inventory(player_index)
	if inventory == null:
		return
	inventory.mutations.clear()

func _is_stackable(mutation_id: String) -> bool:
	match mutation_id:
		"split_shot", "big_shot", "rapid_fire", "shockwave_cooldown":
			return true
		_:
			return false

func _get_param(mutation_id: String, param_name: String, default_value: Variant) -> Variant:
	if not _definition_map.has(mutation_id):
		return default_value
	var params: Dictionary = (_definition_map[mutation_id] as Dictionary).get("params", {})
	return params.get(param_name, default_value)
