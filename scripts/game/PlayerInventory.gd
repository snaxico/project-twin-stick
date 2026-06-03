class_name PlayerInventory
extends RefCounted

var player_index: int = 0
var weapon_id: String = "rifle"
var ability_slot_1: String = "overcharge"
var ability_slot_2: String = "dash"
var mutations: Array = []

func get_selected_weapon() -> Dictionary:
	return {
		"weapon_id": weapon_id,
	}

func get_selected_primary_skill() -> Dictionary:
	return {
		"skill_id": ability_slot_1,
	}
