extends Node

const SAVE_PATH := "user://profile_state.save"
const UNLOCK_TABLE := [
	{"id": "weapon:rifle", "kind": "weapon", "content_id": "rifle", "name": "Rifle", "cost": 0, "free": true},
	{"id": "weapon:scattergun", "kind": "weapon", "content_id": "scattergun", "name": "Shotgun", "cost": 0, "free": true},
	{"id": "weapon:rocket", "kind": "weapon", "content_id": "rocket", "name": "Rocket Launcher", "cost": 700},
	{"id": "weapon:cannon", "kind": "weapon", "content_id": "cannon", "name": "Cannon", "cost": 900},
	{"id": "weapon:boomerang", "kind": "weapon", "content_id": "boomerang", "name": "Boomerang", "cost": 1200},
	{"id": "weapon:railgun", "kind": "weapon", "content_id": "railgun", "name": "Railgun", "cost": 1700},
	{"id": "weapon:beam", "kind": "weapon", "content_id": "beam", "name": "Beam", "cost": 2200},
	{"id": "ability:overcharge", "kind": "ability", "content_id": "overcharge", "name": "Overcharge", "cost": 0, "free": true},
	{"id": "ability:dash", "kind": "ability", "content_id": "dash", "name": "Dash", "cost": 0, "free": true},
	{"id": "ability:shockwave", "kind": "ability", "content_id": "shockwave", "name": "Shockwave", "cost": 600},
	{"id": "ability:blink", "kind": "ability", "content_id": "blink", "name": "Blink", "cost": 800},
	{"id": "ability:shield", "kind": "ability", "content_id": "shield", "name": "Shield", "cost": 950},
	{"id": "ability:turret", "kind": "ability", "content_id": "turret", "name": "Turret", "cost": 1100},
	{"id": "ability:minefield", "kind": "ability", "content_id": "minefield", "name": "Minefield", "cost": 1300},
	{"id": "ability:orbit", "kind": "ability", "content_id": "orbit", "name": "Orbit", "cost": 1500},
	{"id": "ability:decoy", "kind": "ability", "content_id": "decoy", "name": "Decoy", "cost": 1600},
	{"id": "mutation:rapid_fire", "kind": "mutation", "content_id": "rapid_fire", "name": "Rapid Fire", "cost": 0, "free": true},
	{"id": "mutation:velocity", "kind": "mutation", "content_id": "velocity", "name": "Velocity", "cost": 0, "free": true},
	{"id": "mutation:high_caliber", "kind": "mutation", "content_id": "high_caliber", "name": "High Caliber", "cost": 0, "free": true},
	{"id": "mutation:range", "kind": "mutation", "content_id": "range", "name": "Range", "cost": 0, "free": true},
	{"id": "mutation:quick_reflexes", "kind": "mutation", "content_id": "quick_reflexes", "name": "Quick Reflexes", "cost": 0, "free": true},
	{"id": "mutation:wide_pulse", "kind": "mutation", "content_id": "wide_pulse", "name": "Wide Pulse", "cost": 0, "free": true},
	{"id": "mutation:duration", "kind": "mutation", "content_id": "duration", "name": "Duration", "cost": 0, "free": true},
	{"id": "mutation:move_speed", "kind": "mutation", "content_id": "move_speed", "name": "Move Speed", "cost": 0, "free": true},
	{"id": "mutation:tough", "kind": "mutation", "content_id": "tough", "name": "Tough", "cost": 0, "free": true},
	{"id": "mutation:ricochet", "kind": "mutation", "content_id": "ricochet", "name": "Split", "cost": 700},
	{"id": "mutation:fire_trail", "kind": "mutation", "content_id": "fire_trail", "name": "Fire Bullets", "cost": 800},
	{"id": "mutation:freeze_shot", "kind": "mutation", "content_id": "freeze_shot", "name": "Freeze Shot", "cost": 900},
	{"id": "mutation:poison", "kind": "mutation", "content_id": "poison", "name": "Poison", "cost": 900},
	{"id": "mutation:oc_piercing_overdrive", "kind": "mutation", "content_id": "oc_piercing_overdrive", "name": "Piercing Overdrive", "cost": 900},
	{"id": "mutation:dash_shockdash", "kind": "mutation", "content_id": "dash_shockdash", "name": "Shockdash", "cost": 950},
	{"id": "mutation:sw_resonance", "kind": "mutation", "content_id": "sw_resonance", "name": "Shockwave Resonance", "cost": 1100},
	{"id": "mutation:blink_twin_charge", "kind": "mutation", "content_id": "blink_twin_charge", "name": "Twin Charge", "cost": 1200},
	{"id": "mutation:shield_aegis_burst", "kind": "mutation", "content_id": "shield_aegis_burst", "name": "Aegis Burst", "cost": 1300},
	{"id": "mutation:turret_twin", "kind": "mutation", "content_id": "turret_twin", "name": "Twin Turret", "cost": 1400},
	{"id": "mutation:mf_extra_mines", "kind": "mutation", "content_id": "mf_extra_mines", "name": "Extra Mines", "cost": 1500},
	{"id": "mutation:orbit_expanding", "kind": "mutation", "content_id": "orbit_expanding", "name": "Expanding Orbit", "cost": 1600},
	{"id": "mutation:decoy_volatile", "kind": "mutation", "content_id": "decoy_volatile", "name": "Volatile Decoy", "cost": 1600},
	{"id": "mutation:accelerant", "kind": "mutation", "content_id": "accelerant", "name": "Accelerant", "cost": 2000},
	{"id": "mutation:virulent", "kind": "mutation", "content_id": "virulent", "name": "Virulent", "cost": 2100},
	{"id": "mutation:ember_spread", "kind": "mutation", "content_id": "ember_spread", "name": "Ember Spread", "cost": 2400},
	{"id": "mutation:cryo_shatter", "kind": "mutation", "content_id": "cryo_shatter", "name": "Cryo Shatter", "cost": 2500},
	{"id": "mutation:chain_reaction", "kind": "mutation", "content_id": "chain_reaction", "name": "Chain Reaction", "cost": 2800},
	{"id": "mutation:momentum_surge", "kind": "mutation", "content_id": "momentum_surge", "name": "Momentum Surge", "cost": 3000},
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
		if not unlock_id.is_empty() and not unlocked_ids.has(unlock_id):
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
