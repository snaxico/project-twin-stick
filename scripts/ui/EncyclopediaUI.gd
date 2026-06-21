class_name EncyclopediaUI
extends Control

const WEAPONS_DATA_PATH := "res://data/weapons.json"
const ABILITIES_DATA_PATH := "res://data/abilities.json"
const MUTATIONS_DATA_PATH := "res://data/mutations.json"
const MODIFIERS_DATA_PATH := "res://data/modifiers.json"

const ENEMY_ENTRIES := [
	{"id": "chaser", "name": "Chaser", "description": "Fast melee enemy that pressures player movement."},
	{"id": "charger", "name": "Charger", "description": "Telegraphs a rush, then commits to a straight charge."},
	{"id": "spitter", "name": "Spitter", "description": "Ranged enemy that fires enemy projectiles from outside melee range."},
	{"id": "splitter", "name": "Splitter", "description": "Breaks into smaller enemies when destroyed."},
	{"id": "bomber", "name": "Bomber", "description": "Closes distance and detonates to deny space."},
	{"id": "elite_charger", "name": "Champion Charger", "description": "Champion that chains charge-slams and radial bursts."},
	{"id": "elite_spitter", "name": "Champion Spitter", "description": "Champion that mixes rapid aimed fire with pressure shockwaves."},
	{"id": "elite_support", "name": "Champion Support", "description": "Champion that buffs nearby wave enemies and casts shockwaves."},
	{"id": "boss_warden", "name": "Champion Warden", "description": "Champion that uses charge-combos and ground-pounds."},
	{"id": "boss_hydra", "name": "Champion Hydra", "description": "Champion that uses rotating arm-fire and sweeping projectile arcs."},
	{"id": "boss_hive", "name": "Champion Hive", "description": "Champion that uses deflectors and poison clouds."},
	{"id": "boss_pulsar", "name": "Champion Pulsar", "description": "Champion that teleports, casts EMP, and drops shockwave hazards."},
]

var _tabs: HBoxContainer = null
var _list: VBoxContainer = null
var _detail_title: Label = null
var _detail_meta: Label = null
var _detail_body: Label = null
var _entries_by_category: Dictionary = {}
var _active_category := "Weapons"
var _active_index := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_entries()
	_build()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()

func _load_entries() -> void:
	_entries_by_category = {
		"Weapons": _load_array_entries(WEAPONS_DATA_PATH, "weapons"),
		"Abilities": _load_array_entries(ABILITIES_DATA_PATH, "abilities"),
		"Mutations": _load_array_entries(MUTATIONS_DATA_PATH, "mutations"),
		"Modifiers": _load_array_entries(MODIFIERS_DATA_PATH, "modifiers"),
		"Enemies": ENEMY_ENTRIES.duplicate(true),
	}

func _load_array_entries(path: String, key: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return []
	var source: Array = (parsed as Dictionary).get(key, []) as Array
	var entries: Array = []
	for entry in source:
		if entry is Dictionary:
			entries.append((entry as Dictionary).duplicate(true))
	return entries

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.018, 0.026, 0.94)
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var title := Label.new()
	title.text = "Encyclopedia"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "Back"
	close_button.pressed.connect(queue_free)
	header.add_child(close_button)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	root.add_child(_tabs)
	for category in _entries_by_category.keys():
		var button := Button.new()
		button.text = str(category)
		button.toggle_mode = true
		button.pressed.connect(_select_category.bind(str(category)))
		_tabs.add_child(button)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size = Vector2(300.0, 0.0)
	body.add_child(list_panel)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	list_panel.add_child(_list)

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(detail_panel)
	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 18)
	detail_margin.add_theme_constant_override("margin_top", 16)
	detail_margin.add_theme_constant_override("margin_right", 18)
	detail_margin.add_theme_constant_override("margin_bottom", 16)
	detail_panel.add_child(detail_margin)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 10)
	detail_margin.add_child(detail)
	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", 24)
	detail.add_child(_detail_title)
	_detail_meta = Label.new()
	_detail_meta.modulate = Color(0.78, 0.88, 1.0, 0.76)
	detail.add_child(_detail_meta)
	_detail_body = Label.new()
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.add_theme_font_size_override("font_size", 15)
	detail.add_child(_detail_body)
	_refresh_tabs()
	_refresh_list()

func _select_category(category: String) -> void:
	_active_category = category
	_active_index = 0
	_refresh_tabs()
	_refresh_list()

func _refresh_tabs() -> void:
	for child in _tabs.get_children():
		if child is Button:
			(child as Button).set_pressed_no_signal((child as Button).text == _active_category)

func _refresh_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var entries: Array = _entries_by_category.get(_active_category, []) as Array
	for index in range(entries.size()):
		var entry: Dictionary = entries[index] as Dictionary
		var button := Button.new()
		button.text = str(entry.get("name", entry.get("id", "Entry")))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.set_pressed_no_signal(index == _active_index)
		button.pressed.connect(_select_entry.bind(index))
		_list.add_child(button)
	_refresh_detail()

func _select_entry(index: int) -> void:
	_active_index = index
	_refresh_list()

func _refresh_detail() -> void:
	var entries: Array = _entries_by_category.get(_active_category, []) as Array
	if entries.is_empty():
		_detail_title.text = "No Entries"
		_detail_meta.text = ""
		_detail_body.text = ""
		return
	var entry: Dictionary = entries[clampi(_active_index, 0, entries.size() - 1)] as Dictionary
	_detail_title.text = str(entry.get("name", entry.get("id", "Entry")))
	_detail_meta.text = _build_meta_line(entry)
	_detail_body.text = _build_body_text(entry)

func _build_meta_line(entry: Dictionary) -> String:
	var parts: Array = [_active_category]
	for key in ["slot", "type", "group", "rarity", "category"]:
		if entry.has(key):
			parts.append(str(entry[key]).capitalize())
	if _active_category == "Abilities":
		parts.append(_format_ability_duration(entry))
		if entry.has("cooldown"):
			parts.append("Cooldown: %s" % _format_seconds(float(entry.get("cooldown", 0.0))))
	return " | ".join(parts)

func _format_ability_duration(entry: Dictionary) -> String:
	var duration := float(entry.get("duration", 0.0))
	if duration <= 0.0:
		return "Instant"
	return "Active: %s" % _format_seconds(duration)

func _format_seconds(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%ds" % int(roundf(value))
	return "%.1fs" % value

func _build_body_text(entry: Dictionary) -> String:
	var lines: Array = [str(entry.get("description", "No description available."))]
	if entry.has("stats") and entry["stats"] is Dictionary:
		lines.append("")
		lines.append(_format_dictionary("Stats", entry["stats"] as Dictionary))
	if entry.has("per_level") and entry["per_level"] is Dictionary:
		lines.append("")
		lines.append(_format_dictionary("Per Level", entry["per_level"] as Dictionary))
	return "\n".join(lines)

func _format_dictionary(title: String, values: Dictionary) -> String:
	var lines: Array = [title]
	for key in values.keys():
		lines.append("%s: %s" % [str(key).replace("_", " ").capitalize(), str(values[key])])
	return "\n".join(lines)
