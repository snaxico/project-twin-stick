extends RefCounted

static func format_room_type(room_type: String) -> String:
	match room_type:
		"elite":
			return "Champion"
		"boss":
			return "Champion"
		_:
			return "Combat"


static func format_boss_type(raw_boss_type: String) -> String:
	var boss_type := raw_boss_type
	if boss_type.is_empty():
		return ""
	if boss_type.begins_with("boss_"):
		boss_type = boss_type.trim_prefix("boss_")
	if boss_type.begins_with("elite_"):
		boss_type = boss_type.trim_prefix("elite_")
	var words := boss_type.split("_")
	var parts: Array = []
	for word in words:
		if not word.is_empty():
			parts.append(word.capitalize())
	return " ".join(parts)


static func format_modifier_display_name(mod_id: String, modifier_definitions: Dictionary) -> String:
	var definition := modifier_definitions.get(mod_id, {}) as Dictionary
	if not definition.is_empty():
		return str(definition.get("name", mod_id))
	var parts: Array = []
	for word in mod_id.split("_"):
		if not word.is_empty():
			parts.append(word.capitalize())
	return " ".join(parts)


static func format_buff_name(buff_type: String) -> String:
	match buff_type:
		"attack_speed":
			return "Attack Speed"
		"damage":
			return "Damage"
		_:
			return "Speed"


static func get_modifier_chip_color(mod_id: String, modifier_definitions: Dictionary) -> Color:
	var category := str((modifier_definitions.get(mod_id, {}) as Dictionary).get("category", "minor"))
	return Color(0.86, 0.32, 0.22, 0.62) if category == "major" else Color(0.9, 0.68, 0.22, 0.62)


static func overbright_color(color: Color, multiplier: float) -> Color:
	return Color(color.r * multiplier, color.g * multiplier, color.b * multiplier, color.a)


static func get_slot_color(player_tint: Color, slot_index: int, slot_2_color: Color) -> Color:
	if slot_index == 0:
		return player_tint.lightened(0.12)
	return slot_2_color


static func rarity_rank(rarity: String) -> int:
	match rarity:
		"signature":
			return 2
		"rare":
			return 1
		_:
			return 0
