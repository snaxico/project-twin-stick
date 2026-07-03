class_name PlayerInventory
extends RefCounted

var player_index: int = 0
var weapon_id: String = "rifle"
var weapon_level: int = 1
var ability_slot_1: String = "overcharge"
var ability_slot_2: String = "dash"
var ability_slot_3: String = "shockwave"
var ability_slot_4: String = "minefield"
var mutations: Array = []
var rare_dry_streak: int = 0

func get_selected_weapon() -> Dictionary:
	return {
		"weapon_id": weapon_id,
		"weapon_level": weapon_level,
	}

func get_selected_primary_skill() -> Dictionary:
	return {
		"skill_id": ability_slot_1,
	}

func get_ability_ids() -> Array:
	return [ability_slot_1, ability_slot_2, ability_slot_3, ability_slot_4]

func set_ability_ids(ability_ids: Array) -> void:
	var ids := ability_ids.duplicate()
	while ids.size() < 4:
		ids.append("")
	ability_slot_1 = str(ids[0])
	ability_slot_2 = str(ids[1])
	ability_slot_3 = str(ids[2])
	ability_slot_4 = str(ids[3])
