class_name ModifierEngine
extends RefCounted

var _modifiers: Array = []
var _random := RandomNumberGenerator.new()

func _init(definitions_path: String = "res://data/modifiers.json") -> void:
	_random.randomize()
	_load_modifiers(definitions_path)

func get_random_modifier() -> Dictionary:
	if _modifiers.is_empty():
		return {}
	return _modifiers[_random.randi_range(0, _modifiers.size() - 1)].duplicate(true)

func get_tint_color(modifier: Dictionary) -> Color:
	var tint_values = modifier.get("tint", [1.0, 1.0, 1.0, 1.0])
	if tint_values is Array and tint_values.size() == 4:
		return Color(tint_values[0], tint_values[1], tint_values[2], tint_values[3])
	return Color.WHITE

func get_enemy_speed_multiplier(modifier: Dictionary) -> float:
	return float(modifier.get("enemy_speed_multiplier", 1.0))

func get_enemy_fire_interval_multiplier(modifier: Dictionary) -> float:
	return float(modifier.get("enemy_fire_interval_multiplier", 1.0))

func get_spawn_interval_multiplier(modifier: Dictionary) -> float:
	return float(modifier.get("spawn_interval_multiplier", 1.0))

func get_enemy_bonus_health(modifier: Dictionary) -> int:
	return int(modifier.get("enemy_bonus_health", 0))

func get_stationary_damage_interval(modifier: Dictionary) -> float:
	return float(modifier.get("stationary_damage_interval", 0.0))

func get_death_explosion_radius(modifier: Dictionary) -> float:
	return float(modifier.get("death_explosion_radius", 0.0))

func get_death_explosion_damage(modifier: Dictionary) -> int:
	return int(modifier.get("death_explosion_damage", 0))

func get_enemy_contact_damage_bonus(modifier: Dictionary) -> int:
	return int(modifier.get("enemy_contact_damage_bonus", 0))

func _load_modifiers(definitions_path: String) -> void:
	var file := FileAccess.open(definitions_path, FileAccess.READ)
	if file == null:
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return

	var raw_modifiers = parsed.get("modifiers", [])
	if raw_modifiers is Array:
		for modifier in raw_modifiers:
			if modifier is Dictionary:
				_modifiers.append(modifier.duplicate(true))
