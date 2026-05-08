class_name RecipeEngine
extends RefCounted

var _recipes: Array = []
var _weight_hints: Dictionary = {}
var _random: RandomNumberGenerator = RandomNumberGenerator.new()

func _init(definitions_path: String = "res://data/recipes.json") -> void:
	_random.randomize()
	_load_recipes(definitions_path)

func get_recipe_for_room(step_index: int) -> Dictionary:
	var eligible: Array = []
	for recipe in _recipes:
		if not (recipe is Dictionary):
			continue
		var min_step: int = int(recipe.get("min_step", 0))
		var max_step: int = int(recipe.get("max_step", 99))
		if step_index >= min_step and step_index <= max_step:
			eligible.append(recipe)
	if eligible.is_empty():
		return {}
	return eligible[_random.randi_range(0, eligible.size() - 1)].duplicate(true)

func get_weight_hint(hint_name: String) -> Array:
	if hint_name.is_empty() or hint_name == "default":
		return []
	var hint: Variant = _weight_hints.get(hint_name, [])
	if hint is Array and not (hint as Array).is_empty():
		return (hint as Array).duplicate()
	return []

func pick_from_pool(pool: Array) -> String:
	if pool.is_empty():
		return ""
	return str(pool[_random.randi_range(0, pool.size() - 1)])

func _load_recipes(definitions_path: String) -> void:
	var file: FileAccess = FileAccess.open(definitions_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	var raw_recipes: Variant = parsed.get("recipes", [])
	if raw_recipes is Array:
		for recipe in raw_recipes:
			if recipe is Dictionary:
				_recipes.append(recipe.duplicate(true))
	var raw_hints: Variant = parsed.get("enemy_weight_hints", {})
	if raw_hints is Dictionary:
		_weight_hints = raw_hints.duplicate(true)
