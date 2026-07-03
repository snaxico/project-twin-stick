class_name AbilityRegistry
extends RefCounted

const ABILITIES_DATA_PATH := "res://data/abilities.json"
const DEFAULT_OFF_ABILITY := "overcharge"
const DEFAULT_DEF_ABILITY := "dash"
const DEFAULT_LOADOUT := ["overcharge", "dash", "shockwave", "minefield"]

var _definitions: Array = []
var _definition_map: Dictionary = {}

func _init() -> void:
	_load_definitions()

func get_all() -> Array:
	var results: Array = []
	for definition in _definitions:
		results.append((definition as Dictionary).duplicate(true))
	return results

func get_ids() -> Array:
	var ids: Array = []
	for definition in _definitions:
		ids.append(str((definition as Dictionary).get("id", "")))
	return ids

func get_definition(ability_id: String) -> Dictionary:
	if not _definition_map.has(ability_id):
		return {}
	return (_definition_map[ability_id] as Dictionary).duplicate(true)

func has(ability_id: String) -> bool:
	return _definition_map.has(ability_id)

func get_slot(ability_id: String) -> String:
	if not _definition_map.has(ability_id):
		return ""
	return str((_definition_map[ability_id] as Dictionary).get("slot", ""))

func get_ids_by_slot(slot: String) -> Array:
	var ids: Array = []
	for definition in _definitions:
		var ability_definition: Dictionary = definition as Dictionary
		if str(ability_definition.get("slot", "")) == slot:
			ids.append(str(ability_definition.get("id", "")))
	return ids

func get_default_loadout() -> Array:
	return DEFAULT_LOADOUT.duplicate()

func normalize_loadout(ability_ids: Array, desired_count: int = 4) -> Array:
	var normalized: Array = []
	for ability_id_variant in ability_ids:
		var ability_id := str(ability_id_variant)
		if ability_id.is_empty() or not has(ability_id) or normalized.has(ability_id):
			continue
		normalized.append(ability_id)
	for default_id in DEFAULT_LOADOUT:
		if normalized.size() >= desired_count:
			break
		if has(default_id) and not normalized.has(default_id):
			normalized.append(default_id)
	for definition in _definitions:
		if normalized.size() >= desired_count:
			break
		var fallback_id := str((definition as Dictionary).get("id", ""))
		if not fallback_id.is_empty() and not normalized.has(fallback_id):
			normalized.append(fallback_id)
	while normalized.size() < desired_count:
		normalized.append("")
	return normalized.slice(0, desired_count)

func _load_definitions() -> void:
	_definitions.clear()
	_definition_map.clear()
	if not FileAccess.file_exists(ABILITIES_DATA_PATH):
		return
	var file := FileAccess.open(ABILITIES_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	for entry in ((parsed as Dictionary).get("abilities", []) as Array):
		if not (entry is Dictionary):
			continue
		var definition: Dictionary = (entry as Dictionary).duplicate(true)
		var ability_id := str(definition.get("id", ""))
		if ability_id.is_empty():
			continue
		_definitions.append(definition)
		_definition_map[ability_id] = definition
