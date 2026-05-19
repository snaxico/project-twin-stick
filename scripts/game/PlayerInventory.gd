class_name PlayerInventory
extends RefCounted

var player_index: int = 0
var weapon_id: String = "rifle"
var primary_skill_id: String = "shockwave"
var mutations: Array = []

func get_selected_weapon() -> Dictionary:
	return {
		"weapon_id": weapon_id,
	}

func get_selected_primary_skill() -> Dictionary:
	return {
		"skill_id": primary_skill_id,
	}
