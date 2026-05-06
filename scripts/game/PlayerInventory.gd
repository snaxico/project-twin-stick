class_name PlayerInventory
extends RefCounted

var player_index: int = 0
var gold: int = 0
var primary_slots: Array = [null, null]
var secondary_slots: Array = [null, null]
var selected_primary: int = 0
var selected_secondary: int = 0
var passives: Array = []

func get_selected_primary_weapon() -> Dictionary:
	return _get_slot_entry(primary_slots, selected_primary)

func get_selected_secondary_weapon() -> Dictionary:
	return _get_slot_entry(secondary_slots, selected_secondary)

func get_total_item_count() -> int:
	var count: int = passives.size()
	count += _count_filled_slots(primary_slots)
	count += _count_filled_slots(secondary_slots)
	return count

func owns_weapon(weapon_id: String) -> bool:
	return get_weapon_level(weapon_id) > 0

func get_weapon_level(weapon_id: String) -> int:
	for slot_entry in primary_slots:
		if _matches_weapon_id(slot_entry, weapon_id):
			return int((slot_entry as Dictionary).get("level", 1))
	for slot_entry in secondary_slots:
		if _matches_weapon_id(slot_entry, weapon_id):
			return int((slot_entry as Dictionary).get("level", 1))
	return 0

func can_take_weapon(weapon_id: String, max_level: int = 5) -> bool:
	var current_level: int = get_weapon_level(weapon_id)
	return current_level <= 0 or current_level < max_level

func add_weapon(weapon_id: String, weapon_type: String, max_level: int = 5) -> String:
	var slot_group: Array = secondary_slots if weapon_type == "secondary_weapon" else primary_slots
	var selected_field := "selected_secondary" if weapon_type == "secondary_weapon" else "selected_primary"
	for slot_index in range(slot_group.size()):
		var slot_entry: Variant = slot_group[slot_index]
		if _matches_weapon_id(slot_entry, weapon_id):
			var current_level: int = int((slot_entry as Dictionary).get("level", 1))
			if current_level >= max_level:
				return "max_level"
			level_up_weapon(weapon_id)
			return "leveled_up"
	for slot_index in range(slot_group.size()):
		if slot_group[slot_index] != null:
			continue
		slot_group[slot_index] = {
			"weapon_id": weapon_id,
			"level": 1,
		}
		var current_selected: int = selected_secondary if selected_field == "selected_secondary" else selected_primary
		if current_selected < 0 or current_selected >= slot_group.size() or slot_group[current_selected] == null:
			if selected_field == "selected_secondary":
				selected_secondary = slot_index
			else:
				selected_primary = slot_index
		return "equipped"
	return "slots_full"

func level_up_weapon(weapon_id: String) -> void:
	for slot_index in range(primary_slots.size()):
		if not _matches_weapon_id(primary_slots[slot_index], weapon_id):
			continue
		var slot_entry: Dictionary = (primary_slots[slot_index] as Dictionary).duplicate(true)
		slot_entry["level"] = int(slot_entry.get("level", 1)) + 1
		primary_slots[slot_index] = slot_entry
		return
	for slot_index in range(secondary_slots.size()):
		if not _matches_weapon_id(secondary_slots[slot_index], weapon_id):
			continue
		var slot_entry: Dictionary = (secondary_slots[slot_index] as Dictionary).duplicate(true)
		slot_entry["level"] = int(slot_entry.get("level", 1)) + 1
		secondary_slots[slot_index] = slot_entry
		return

func replace_weapon(slot_type: String, slot_index: int, new_weapon_id: String) -> void:
	var is_secondary: bool = slot_type == "secondary" or slot_type == "secondary_weapon"
	var slot_group: Array = secondary_slots if is_secondary else primary_slots
	if slot_index < 0 or slot_index >= slot_group.size():
		return
	slot_group[slot_index] = {
		"weapon_id": new_weapon_id,
		"level": 1,
	}
	if is_secondary:
		selected_secondary = slot_index
	else:
		selected_primary = slot_index

func add_passive(passive_id: String, allow_duplicate: bool = false) -> void:
	if not allow_duplicate and has_passive(passive_id):
		return
	passives.append(passive_id)

func has_passive(passive_id: String) -> bool:
	return passives.has(passive_id)

func _count_filled_slots(slot_group: Array) -> int:
	var count: int = 0
	for slot_entry in slot_group:
		if slot_entry != null:
			count += 1
	return count

func _get_slot_entry(slot_group: Array, slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= slot_group.size():
		return {}
	var slot_entry: Variant = slot_group[slot_index]
	if not (slot_entry is Dictionary):
		return {}
	return (slot_entry as Dictionary).duplicate(true)

func _matches_weapon_id(slot_entry: Variant, weapon_id: String) -> bool:
	return slot_entry is Dictionary and str((slot_entry as Dictionary).get("weapon_id", "")) == weapon_id
