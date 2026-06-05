class_name PlayerInventory
extends RefCounted

var player_index: int = 0
var weapon_id: String = "rifle"
var weapon_level: int = 1
var ability_slot_1: String = "overcharge"
var ability_slot_2: String = "dash"
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
