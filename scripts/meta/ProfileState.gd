extends Node

const SAVE_PATH := "user://profile_state.save"
const UNLOCK_TABLE := [
	{"id": "class:mobile", "kind": "class", "content_id": "mobile", "name": "Stormrunner", "cost": 0, "free": true},
	{"id": "class:tank", "kind": "class", "content_id": "tank", "name": "Tank", "cost": 0, "free": true},
	{"id": "class:controller", "kind": "class", "content_id": "controller", "name": "Controller", "cost": 0, "free": true},
	{"id": "class:risk", "kind": "class", "content_id": "risk", "name": "Risk", "cost": 0, "free": true},
	{"id": "weapon:rifle", "kind": "weapon", "content_id": "rifle", "name": "Rifle", "cost": 0, "free": true},
	{"id": "weapon:scattergun", "kind": "weapon", "content_id": "scattergun", "name": "Shotgun", "cost": 0, "free": true},
	{"id": "weapon:rocket", "kind": "weapon", "content_id": "rocket", "name": "Rocket Launcher", "cost": 0, "free": true},
	{"id": "weapon:beam", "kind": "weapon", "content_id": "beam", "name": "Beam", "cost": 0, "free": true},
	{"id": "weapon:whirlwind", "kind": "weapon", "content_id": "whirlwind", "name": "Whirlwind", "cost": 0, "free": true},
	{"id": "weapon:arc_wand", "kind": "weapon", "content_id": "arc_wand", "name": "Arc Wand", "cost": 0, "free": true},
	{"id": "weapon:flamethrower", "kind": "weapon", "content_id": "flamethrower", "name": "Flamethrower", "cost": 0, "free": true},
	{"id": "ability:overcharge", "kind": "ability", "content_id": "overcharge", "name": "Overcharge", "cost": 0, "free": true},
	{"id": "ability:dash", "kind": "ability", "content_id": "dash", "name": "Dash", "cost": 0, "free": true},
	{"id": "ability:shockwave", "kind": "ability", "content_id": "shockwave", "name": "Shockwave", "cost": 0, "free": true},
	{"id": "ability:shield", "kind": "ability", "content_id": "shield", "name": "Shield", "cost": 0, "free": true},
	{"id": "ability:turret", "kind": "ability", "content_id": "turret", "name": "Turret", "cost": 0, "free": true},
	{"id": "ability:minefield", "kind": "ability", "content_id": "minefield", "name": "Minefield", "cost": 0, "free": true},
	{"id": "ability:orbit", "kind": "ability", "content_id": "orbit", "name": "Orbit", "cost": 0, "free": true},
	{"id": "ability:afterburn", "kind": "ability", "content_id": "afterburn", "name": "Afterburn", "cost": 0, "free": true},
	{"id": "ability:momentum_burst", "kind": "ability", "content_id": "momentum_burst", "name": "Momentum Burst", "cost": 0, "free": true},
	{"id": "ability:deflect", "kind": "ability", "content_id": "deflect", "name": "Deflect", "cost": 0, "free": true},
	{"id": "ability:sonic_boom", "kind": "ability", "content_id": "sonic_boom", "name": "Sonic Boom", "cost": 0, "free": true},
	{"id": "ability:ground_slam", "kind": "ability", "content_id": "ground_slam", "name": "Ground Slam", "cost": 0, "free": true},
	{"id": "ability:quake", "kind": "ability", "content_id": "quake", "name": "Quake", "cost": 0, "free": true},
	{"id": "ability:blood_lance", "kind": "ability", "content_id": "blood_lance", "name": "Blood Lance", "cost": 0, "free": true},
	{"id": "ability:summon", "kind": "ability", "content_id": "summon", "name": "Summon", "cost": 0, "free": true},
	{"id": "ability:reinforce", "kind": "ability", "content_id": "reinforce", "name": "Reinforce", "cost": 0, "free": true},
	{"id": "ability:fireball", "kind": "ability", "content_id": "fireball", "name": "Fireball", "cost": 0, "free": true},
	{"id": "ability:ignite", "kind": "ability", "content_id": "ignite", "name": "Ignite", "cost": 0, "free": true},
	{"id": "ability:slipstream", "kind": "ability", "content_id": "slipstream", "name": "Slipstream", "cost": 0, "free": true},
	{"id": "ability:blood_frenzy", "kind": "ability", "content_id": "blood_frenzy", "name": "Blood Frenzy", "cost": 0, "free": true},
	{"id": "ability:overload_grid", "kind": "ability", "content_id": "overload_grid", "name": "Overload Grid", "cost": 0, "free": true},
	{"id": "ability:firestorm", "kind": "ability", "content_id": "firestorm", "name": "Firestorm", "cost": 0, "free": true},
	{"id": "mutation:accelerant", "kind": "mutation", "content_id": "accelerant", "name": "Accelerant", "cost": 2000},
	{"id": "mutation:virulent", "kind": "mutation", "content_id": "virulent", "name": "Virulent", "cost": 2100},
	{"id": "mutation:ember_spread", "kind": "mutation", "content_id": "ember_spread", "name": "Ember Spread", "cost": 2400},
	{"id": "mutation:cryo_shatter", "kind": "mutation", "content_id": "cryo_shatter", "name": "Cryo Shatter", "cost": 2500},
	{"id": "mutation:overclocked", "kind": "mutation", "content_id": "overclocked", "name": "Overclocked", "cost": 2600},
	{"id": "mutation:executioner", "kind": "mutation", "content_id": "executioner", "name": "Executioner", "cost": 2600},
	{"id": "mutation:overgrowth", "kind": "mutation", "content_id": "overgrowth", "name": "Overgrowth", "cost": 2600},
	{"id": "mutation:combustion", "kind": "mutation", "content_id": "combustion", "name": "Combustion", "cost": 2600},
	{"id": "mutation:chain_reaction", "kind": "mutation", "content_id": "chain_reaction", "name": "Chain Reaction", "cost": 2800},
	{"id": "mutation:momentum_surge", "kind": "mutation", "content_id": "momentum_surge", "name": "Momentum Surge", "cost": 3000},
	{"id": "mutation:overflow", "kind": "mutation", "content_id": "overflow", "name": "Overflow", "cost": 3000},
	{"id": "mutation:legion", "kind": "mutation", "content_id": "legion", "name": "Legion", "cost": 3000},
	{"id": "mutation:thermal_surge", "kind": "mutation", "content_id": "thermal_surge", "name": "Thermal Surge", "cost": 3000},
	{"id": "mutation:glass_cannon", "kind": "mutation", "content_id": "glass_cannon", "name": "Glass Cannon", "cost": 3200},
	{"id": "mutation:pyromaniac", "kind": "mutation", "content_id": "pyromaniac", "name": "Pyromaniac", "cost": 3400},
]

var screen_effect_level: String = "full"
var banked_score: int = 0
var unlocked_ids: Array[String] = []

func _ready() -> void:
	load_profile()

func load_profile() -> void:
	_apply_default_unlocks()
	if not FileAccess.file_exists(SAVE_PATH):
		save_profile()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		save_profile()
		return
	var data := parsed as Dictionary
	screen_effect_level = _sanitize_screen_effect_level(str(data.get("screen_effect_level", "full")))
	banked_score = max(int(data.get("banked_score", 0)), 0)
	unlocked_ids.clear()
	for id_variant in (data.get("unlocked_ids", []) as Array):
		var unlock_id := str(id_variant)
		if not unlock_id.is_empty() and _find_unlock_index(unlock_id) >= 0 and not unlocked_ids.has(unlock_id):
			unlocked_ids.append(unlock_id)
	_apply_default_unlocks()
	save_profile()

func save_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"screen_effect_level": screen_effect_level,
		"banked_score": banked_score,
		"unlocked_ids": unlocked_ids,
	}, "\t"))

func reset_profile() -> void:
	screen_effect_level = "full"
	banked_score = 0
	unlocked_ids.clear()
	_apply_default_unlocks()
	save_profile()

func add_score(amount: int) -> int:
	if amount <= 0:
		return banked_score
	banked_score += amount
	save_profile()
	return banked_score

func spend_score(amount: int) -> bool:
	if amount < 0 or banked_score < amount:
		return false
	banked_score -= amount
	save_profile()
	return true

func unlock(unlock_id: String) -> bool:
	if is_unlocked(unlock_id):
		return true
	var entry := get_unlock_entry(unlock_id)
	if entry.is_empty():
		return false
	var cost := int(entry.get("cost", 0))
	if not spend_score(cost):
		return false
	unlocked_ids.append(unlock_id)
	save_profile()
	return true

func is_unlocked(unlock_id: String) -> bool:
	if _find_unlock_index(unlock_id) < 0:
		push_warning("Unknown unlock id: %s" % unlock_id)
		return true
	return unlocked_ids.has(unlock_id)

func is_content_unlocked(kind: String, content_id: String) -> bool:
	var unlock_id := "%s:%s" % [kind, content_id]
	return is_unlocked(unlock_id)

func get_unlock_entry(unlock_id: String) -> Dictionary:
	var index := _find_unlock_index(unlock_id)
	if index < 0:
		return {}
	return (UNLOCK_TABLE[index] as Dictionary).duplicate(true)

func get_unlock_table() -> Array:
	var entries: Array = []
	for entry in UNLOCK_TABLE:
		entries.append((entry as Dictionary).duplicate(true))
	return entries

func get_locked_entries() -> Array:
	var entries: Array = []
	for entry_variant in UNLOCK_TABLE:
		var entry := entry_variant as Dictionary
		var unlock_id := str(entry.get("id", ""))
		if not is_unlocked(unlock_id):
			entries.append(entry.duplicate(true))
	return entries

func get_screen_effect_level() -> String:
	return "full"

func set_screen_effect_level(_level: String) -> void:
	screen_effect_level = "full"
	save_profile()

func _sanitize_screen_effect_level(_level: String) -> String:
	return "full"

func _apply_default_unlocks() -> void:
	for entry_variant in UNLOCK_TABLE:
		var entry := entry_variant as Dictionary
		if not bool(entry.get("free", false)):
			continue
		var unlock_id := str(entry.get("id", ""))
		if not unlock_id.is_empty() and not unlocked_ids.has(unlock_id):
			unlocked_ids.append(unlock_id)

func _find_unlock_index(unlock_id: String) -> int:
	for index in range(UNLOCK_TABLE.size()):
		if str((UNLOCK_TABLE[index] as Dictionary).get("id", "")) == unlock_id:
			return index
	return -1
