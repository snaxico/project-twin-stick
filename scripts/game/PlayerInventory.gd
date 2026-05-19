class_name PlayerInventory
extends RefCounted

var player_index: int = 0
var primary_weapon_id: String = "rifle"
var secondary_weapon_id: String = "shockwave"
var mutations: Array = []

func get_selected_primary_weapon() -> Dictionary:
	return {
		"weapon_id": primary_weapon_id,
	}

func get_selected_secondary_weapon() -> Dictionary:
	return {
		"weapon_id": secondary_weapon_id,
	}
