class_name AbilityRegistry
extends RefCounted

const ABILITIES_DATA_PATH := "res://data/abilities.json"

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
