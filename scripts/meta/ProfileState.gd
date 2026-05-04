extends Node

const SAVE_PATH := "user://profile_state.save"
const UNLOCKS_DATA_PATH := "res://data/unlocks.json"

var meta_gold: int = 0
var unlocked_item_ids: Array = []

var _unlock_definitions: Array = []
var _unlock_map: Dictionary = {}
var _starting_unlocked_item_ids: Array = []

func _ready() -> void:
	_load_unlock_definitions()
	load_profile()

func load_profile() -> void:
	_load_unlock_definitions()
	if not FileAccess.file_exists(SAVE_PATH):
		_reset_to_defaults(false)
		save_profile()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_reset_to_defaults(false)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_reset_to_defaults(false)
		return

	meta_gold = max(0, int(parsed.get("meta_gold", 0)))
	unlocked_item_ids = []
	var raw_unlocks = parsed.get("unlocked_item_ids", [])
	if raw_unlocks is Array:
		for entry in raw_unlocks:
			var item_id := str(entry)
			if item_id.is_empty():
				continue
			if not unlocked_item_ids.has(item_id):
				unlocked_item_ids.append(item_id)

	for item_id in _starting_unlocked_item_ids:
		if not unlocked_item_ids.has(item_id):
			unlocked_item_ids.append(item_id)

func save_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return

	var payload := {
		"meta_gold": meta_gold,
		"unlocked_item_ids": unlocked_item_ids,
	}
	file.store_string(JSON.stringify(payload, "\t"))

func reset_profile() -> void:
	_reset_to_defaults(true)

func has_item_unlock(item_id: String) -> bool:
	return unlocked_item_ids.has(item_id)

func get_profile_summary_text() -> String:
	return "Meta Gold: %d\nUnlocked upgrades: %d / %d" % [meta_gold, unlocked_item_ids.size(), _unlock_definitions.size()]

func get_available_unlocks() -> Array:
	var available: Array = []
	for unlock in _unlock_definitions:
		var unlock_id := str(unlock.get("id", ""))
		if unlocked_item_ids.has(unlock_id):
			continue
		available.append(unlock.duplicate(true))
	return available

func get_affordable_unlocks() -> Array:
	var affordable: Array = []
	for unlock in get_available_unlocks():
		var cost := int(unlock.get("cost", 0))
		if cost <= meta_gold:
			affordable.append(unlock)
	return affordable

func purchase_unlock(unlock_id: String) -> Dictionary:
	if unlocked_item_ids.has(unlock_id):
		return {
			"success": false,
			"title": "Already Unlocked",
			"summary": "That upgrade is already available in future runs.",
		}

	if not _unlock_map.has(unlock_id):
		return {
			"success": false,
			"title": "Unlock Missing",
			"summary": "The selected unlock no longer exists.",
		}

	var unlock: Dictionary = _unlock_map[unlock_id]
	var cost := int(unlock.get("cost", 0))
	if cost > meta_gold:
		return {
			"success": false,
			"title": "Not Enough Meta Gold",
			"summary": "Need %d Meta Gold. Current total: %d." % [cost, meta_gold],
		}

	meta_gold -= cost
	unlocked_item_ids.append(unlock_id)
	save_profile()
	return {
		"success": true,
		"title": "Unlock Purchased",
		"summary": "%s\n%s\nMeta Gold left: %d." % [
			str(unlock.get("name", "Upgrade")),
			str(unlock.get("description", "")),
			meta_gold,
		],
	}

func award_run_meta_gold(run_outcome: String, rooms_completed: int) -> Dictionary:
	var affordable_before := _get_unlock_ids(get_affordable_unlocks())
	var reward: int = max(1, rooms_completed)
	if run_outcome == "won":
		reward += 4
	else:
		reward += 1

	meta_gold += reward
	var affordable_after := get_affordable_unlocks()
	var newly_affordable_names: Array = []
	for unlock in affordable_after:
		var unlock_id := str(unlock.get("id", ""))
		if affordable_before.has(unlock_id):
			continue
		newly_affordable_names.append(str(unlock.get("name", "Unlock")))
	save_profile()
	return {
		"title": "Run Complete",
		"summary": "Meta Gold earned: %d\nCurrent total: %d" % [reward, meta_gold],
		"amount": reward,
		"newly_affordable_unlock_names": newly_affordable_names,
		"affordable_unlock_count": affordable_after.size(),
	}

func _load_unlock_definitions() -> void:
	_unlock_definitions = []
	_unlock_map = {}
	_starting_unlocked_item_ids = []
	if not FileAccess.file_exists(UNLOCKS_DATA_PATH):
		return

	var file := FileAccess.open(UNLOCKS_DATA_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return

	var raw_starting = parsed.get("starting_unlocked_item_ids", [])
	if raw_starting is Array:
		for entry in raw_starting:
			var item_id := str(entry)
			if item_id.is_empty():
				continue
			_starting_unlocked_item_ids.append(item_id)

	var raw_unlocks = parsed.get("unlocks", [])
	if not (raw_unlocks is Array):
		return

	for entry in raw_unlocks:
		if not (entry is Dictionary):
			continue
		var unlock: Dictionary = entry.duplicate(true)
		var unlock_id := str(unlock.get("id", ""))
		if unlock_id.is_empty():
			continue
		_unlock_definitions.append(unlock)
		_unlock_map[unlock_id] = unlock

func _reset_to_defaults(save_after_reset: bool) -> void:
	meta_gold = 0
	unlocked_item_ids = []
	for item_id in _starting_unlocked_item_ids:
		if not unlocked_item_ids.has(item_id):
			unlocked_item_ids.append(item_id)
	if save_after_reset:
		save_profile()

func _get_unlock_ids(unlocks: Array) -> Array:
	var ids: Array = []
	for unlock in unlocks:
		if not (unlock is Dictionary):
			continue
		var unlock_id := str(unlock.get("id", ""))
		if unlock_id.is_empty():
			continue
		ids.append(unlock_id)
	return ids
