extends RefCounted

static func champion_enemy_id(champion_id: String) -> String:
	if champion_id.begins_with("elite_") or champion_id.begins_with("boss_"):
		return champion_id
	return "boss_%s" % champion_id


static func is_champion(enemy_type_name: String) -> bool:
	return enemy_type_name.begins_with("boss_") or enemy_type_name.begins_with("elite_")
