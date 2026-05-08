class_name RecipeEngine
extends RefCounted

var _recipes: Array = []
var _weight_hints: Dictionary = {}
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _recent_recipe_ids: Array = []

func _init(definitions_path: String = "res://data/recipes.json") -> void:
	_random.randomize()
	_load_recipes(definitions_path)

func get_recipe_for_room(step_index: int, forced_recipe_id: String = "") -> Dictionary:
	if not forced_recipe_id.is_empty():
		var forced_recipe: Dictionary = _get_recipe_by_id(forced_recipe_id)
		if not forced_recipe.is_empty():
			_record_recipe_pick(str(forced_recipe.get("id", "")))
			return forced_recipe
	var eligible: Array = []
	for recipe in _recipes:
		if not (recipe is Dictionary):
			continue
		if not _matches_step_bucket(recipe as Dictionary, step_index):
			continue
		var min_step: int = int(recipe.get("min_step", 0))
		var max_step: int = int(recipe.get("max_step", 99))
		if step_index >= min_step and step_index <= max_step:
			eligible.append(recipe)
	if eligible.is_empty():
		return {}
	var non_repeating: Array = []
	for recipe_variant in eligible:
		var recipe: Dictionary = recipe_variant as Dictionary
		if not _recent_recipe_ids.has(str(recipe.get("id", ""))):
			non_repeating.append(recipe)
	var pick_pool: Array = non_repeating if not non_repeating.is_empty() else eligible
	var selected_recipe: Dictionary = (pick_pool[_random.randi_range(0, pick_pool.size() - 1)] as Dictionary).duplicate(true)
	_record_recipe_pick(str(selected_recipe.get("id", "")))
	return selected_recipe

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

func reset_history() -> void:
	_recent_recipe_ids.clear()

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

func _get_recipe_by_id(recipe_id: String) -> Dictionary:
	for recipe_variant in _recipes:
		if not (recipe_variant is Dictionary):
			continue
		var recipe: Dictionary = recipe_variant as Dictionary
		if str(recipe.get("id", "")) == recipe_id:
			return recipe.duplicate(true)
	return {}

func _record_recipe_pick(recipe_id: String) -> void:
	if recipe_id.is_empty():
		return
	_recent_recipe_ids.append(recipe_id)
	while _recent_recipe_ids.size() > 2:
		_recent_recipe_ids.remove_at(0)

func _matches_step_bucket(recipe: Dictionary, step_index: int) -> bool:
	var step_bucket: String = str(recipe.get("step_bucket", "")).strip_edges()
	if step_bucket.is_empty():
		return true
	match step_bucket:
		"early":
			return step_index >= 0 and step_index <= 2
		"mid":
			return step_index >= 2 and step_index <= 4
		"late":
			return step_index >= 4
		_:
			return true
