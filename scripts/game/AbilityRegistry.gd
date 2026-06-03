class_name AbilityRegistry
extends RefCounted

const ABILITIES_DATA_PATH := "res://data/abilities.json"
const DEFAULT_OFF_ABILITY := "overcharge"
const DEFAULT_DEF_ABILITY := "dash"

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
	return [DEFAULT_OFF_ABILITY, DEFAULT_DEF_ABILITY]

func normalize_loadout(ability_ids: Array) -> Array:
	var off_id := ""
	var def_id := ""
	for ability_id_variant in ability_ids:
		var ability_id := str(ability_id_variant)
		match get_slot(ability_id):
			"off":
				if off_id.is_empty():
					off_id = ability_id
			"def":
				if def_id.is_empty():
					def_id = ability_id
	if off_id.is_empty():
		off_id = DEFAULT_OFF_ABILITY
	if def_id.is_empty():
		def_id = DEFAULT_DEF_ABILITY
	return [off_id, def_id]

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
