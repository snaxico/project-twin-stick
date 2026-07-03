class_name ClassRegistry
extends RefCounted

const CLASSES_DATA_PATH := "res://data/classes.json"

var _definitions: Array = []
var _definition_map: Dictionary = {}

func _init() -> void:
	reload()

func reload() -> void:
	_definitions.clear()
	_definition_map.clear()
	if not FileAccess.file_exists(CLASSES_DATA_PATH):
		push_error("Missing class data: %s" % CLASSES_DATA_PATH)
		return
	var file := FileAccess.open(CLASSES_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open class data: %s" % CLASSES_DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("Invalid class data JSON: %s" % CLASSES_DATA_PATH)
		return
	for entry in ((parsed as Dictionary).get("classes", []) as Array):
		if not (entry is Dictionary):
			continue
		var definition: Dictionary = (entry as Dictionary).duplicate(true)
		var class_id := str(definition.get("id", ""))
		if class_id.is_empty():
			continue
		_definitions.append(definition)
		_definition_map[class_id] = definition

func get_all() -> Array:
	var results: Array = []
	for definition in _definitions:
		results.append((definition as Dictionary).duplicate(true))
	return results

func get_definition(class_id: String) -> Dictionary:
	if not _definition_map.has(class_id):
		return {}
	return (_definition_map[class_id] as Dictionary).duplicate(true)

func has(class_id: String) -> bool:
	return _definition_map.has(class_id)
