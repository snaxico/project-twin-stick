extends Control

const GAME_WORLD_SCENE = preload("res://scenes/game/GameWorld.tscn")
const MODIFIERS_DATA_PATH := "res://data/modifiers.json"
const WHERE_DISPLAY := {
	"fire_grid": "Fire Hazard Floor",
	"frost_grid": "Frost Hazard Floor",
	"mine_grid": "Mine Hazard Floor",
	"pinwheel": "Roaming Sawblades",
	"tesla_arcs": "Tesla Arcs",
	"drifting_clouds": "Drifting Clouds",
	"bastion": "Bastion",
	"popup_pillars": "Pop-up Pillars",
	"drifting_cover": "Drifting Cover",
}

signal return_to_menu_requested(open_meta_menu: bool)

@onready var next_room_panel: Panel = $NextRoomPanel
@onready var next_room_title_label: Label = $NextRoomPanel/MarginContainer/NextRoomLayout/NextRoomTitle
@onready var next_room_status_label: Label = $NextRoomPanel/MarginContainer/NextRoomLayout/NextRoomStatus
@onready var next_room_card_row: HBoxContainer = $NextRoomPanel/MarginContainer/NextRoomLayout/NextRoomCardRow
@onready var resolution_panel: Panel = $ResolutionPanel
@onready var resolution_title_label: Label = $ResolutionPanel/MarginContainer/ResolutionLayout/ResolutionTitle
@onready var resolution_detail_label: Label = $ResolutionPanel/MarginContainer/ResolutionLayout/ResolutionDetail
@onready var resolution_button: Button = $ResolutionPanel/MarginContainer/ResolutionLayout/ResolutionButton
@onready var resolution_secondary_button: Button = $ResolutionPanel/MarginContainer/ResolutionLayout/ResolutionSecondaryButton
@onready var run_summary_panel: Panel = $RunSummaryPanel
@onready var game_container: Control = $GameContainer

var _active_game = null
var _post_resolution_action: String = "next"
var _secondary_resolution_action: String = ""
var _modifier_definitions: Dictionary = {}

func _ready() -> void:
	_load_modifier_definitions()
	next_room_panel.visible = false
	run_summary_panel.visible = false
	resolution_panel.visible = false
	resolution_button.pressed.connect(_on_resolution_button_pressed)
	resolution_secondary_button.pressed.connect(_on_resolution_secondary_button_pressed)
	if RunState.is_debug_single_room_mode():
		call_deferred("_launch_single_debug_room")
		return
	call_deferred("_show_next_room_choice")

func _show_next_room_choice() -> void:
	_set_music_context("map")
	next_room_panel.visible = true
	resolution_panel.visible = false
	run_summary_panel.visible = false
	_clear_active_game()
	_clear_next_room_cards()
	var options: Array = RunState.get_current_options()
	if options.is_empty():
		_show_resolution("Route Missing", "No next room was available.", "Return to Menu")
		_post_resolution_action = "return_to_menu"
		return
	var xp_progress: Dictionary = RunState.get_xp_progress()
	var room_number := int(options[0].get("depth", RunState.rooms_completed + 1))
	next_room_title_label.text = "Choose Next Room"
	next_room_status_label.text = "Room %d  |  Score %d  |  Lv %d  |  XP %d/%d  |  Pending Picks %d" % [
		room_number,
		RunState.get_current_score(),
		int(xp_progress.get("level", 0)),
		int(xp_progress.get("current", 0)),
		int(xp_progress.get("needed", 80)),
		int(xp_progress.get("pending", 0)),
	]
	var first_button: Button = null
	for option in options:
		var button := _build_route_card(option as Dictionary)
		next_room_card_row.add_child(button)
		if first_button == null:
			first_button = button
	if first_button != null:
		call_deferred("_focus_route_card", first_button)

func _clear_next_room_cards() -> void:
	for child in next_room_card_row.get_children():
		child.queue_free()

func _build_route_card(node: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(252.0, 196.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.text = ""
	var rare_bonus := float(node.get("rare_bonus", 0.0))
	_apply_route_card_style(button, rare_bonus)
	button.mouse_entered.connect(_on_route_card_mouse_entered.bind(button))
	button.focus_entered.connect(_on_route_card_focus_entered.bind(button))
	button.resized.connect(_update_route_card_pivot.bind(button))
	_set_route_card_active(button, false)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	button.add_child(margin)
	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var room_type := str(node.get("room_type", "combat"))
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_theme_constant_override("separation", 8)
	layout.add_child(title_row)
	var trait_label := Label.new()
	trait_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trait_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var trait_text := "Champion: %s" % _format_boss_name(str(node.get("boss_type", "Champion"))) if room_type == "boss" else str(node.get("trait_label", "Open room"))
	trait_label.text = trait_text
	trait_label.add_theme_font_size_override("font_size", 17)
	trait_label.add_theme_color_override("font_color", Color(0.88, 0.98, 1.0, 0.96))
	title_row.add_child(trait_label)
	var danger_label := Label.new()
	danger_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	danger_label.text = _danger_pips_text(int(node.get("danger_pips", 1)))
	danger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	danger_label.add_theme_font_size_override("font_size", 15)
	danger_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.28, 0.96))
	title_row.add_child(danger_label)

	var chip_flow := HFlowContainer.new()
	chip_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_flow.add_theme_constant_override("h_separation", 5)
	chip_flow.add_theme_constant_override("v_separation", 5)
	layout.add_child(chip_flow)
	if room_type == "boss":
		chip_flow.add_child(_build_modifier_chip("Champion"))
	else:
		var chips: Array = []
		var where_id := str(node.get("where", "open"))
		if where_id != "open" and not where_id.is_empty():
			chips.append(_format_where_name(where_id))
		var modifiers: Array = node.get("modifiers", []) as Array
		for mod_id_variant in modifiers:
			if chips.size() >= 2:
				break
			chips.append(_format_modifier_name(str(mod_id_variant)))
		for chip_text in chips:
			chip_flow.add_child(_build_modifier_chip(str(chip_text)))

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	var rare_label := Label.new()
	rare_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rare_label.add_theme_font_size_override("font_size", 12)
	rare_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.36, 0.96) if rare_bonus > 0.0 else Color(0.74, 0.86, 0.92, 0.9))
	var rare_text := "Rare odds %d%%" % int(round(float(node.get("rare_chance", 0.0)) * 100.0))
	if rare_bonus > 0.0:
		rare_text += "  +%d%%" % int(round(rare_bonus * 100.0))
	rare_label.text = rare_text
	layout.add_child(rare_label)

	button.pressed.connect(_on_next_room_card_pressed.bind(str(node.get("id", ""))))
	return button

func _apply_route_card_style(button: Button, rare_bonus: float) -> void:
	var border_color := Color(0.32, 0.86, 1.0, 0.72)
	if rare_bonus > 0.0:
		border_color = Color(1.0, 0.80, 0.26, 0.96)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		var is_active_state: bool = state == "hover" or state == "focus"
		style.bg_color = Color(0.025, 0.04, 0.055, 0.88)
		if is_active_state:
			style.bg_color = Color(0.07, 0.13, 0.17, 0.99)
		elif state == "pressed":
			style.bg_color = Color(0.025, 0.045, 0.065, 0.98)
		style.border_color = border_color.lightened(0.28) if is_active_state else Color(border_color.r, border_color.g, border_color.b, border_color.a * 0.48)
		style.set_border_width_all(3 if is_active_state else (2 if rare_bonus > 0.0 else 1))
		if is_active_state:
			style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.42)
			style.shadow_size = 8
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		button.add_theme_stylebox_override(state, style)


func _on_route_card_mouse_entered(button: Button) -> void:
	_focus_route_card(button)


func _focus_route_card(button: Button) -> void:
	button.grab_focus()
	_on_route_card_focus_entered(button)


func _on_route_card_focus_entered(button: Button) -> void:
	for child in next_room_card_row.get_children():
		if child is Button:
			_set_route_card_active(child as Button, child == button)


func _set_route_card_active(button: Button, active: bool) -> void:
	button.modulate = Color.WHITE if active else Color(0.72, 0.76, 0.82, 0.86)
	button.scale = Vector2.ONE * (1.03 if active else 1.0)


func _update_route_card_pivot(button: Button) -> void:
	button.pivot_offset = button.size * 0.5

func _build_modifier_chip(display_name: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.18, 0.22, 0.82)
	style.border_color = Color(0.42, 0.82, 0.95, 0.52)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	chip.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 3)
	chip.add_child(margin)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = display_name
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0, 0.94))
	margin.add_child(label)
	return chip

func _danger_pips_text(pip_count: int) -> String:
	var filled := ""
	for _index in range(clampi(pip_count, 1, 3)):
		filled += "●"
	return filled

func _on_next_room_card_pressed(node_id: String) -> void:
	if not RunState.select_map_node(node_id):
		return
	var node: Dictionary = RunState.get_map_node(node_id)
	match str(node.get("room_type", "combat")):
		"combat", "boss":
			_launch_room(node)
		_:
			_show_outcome(RunState.resolve_current_noncombat_node())

func _launch_room(node: Dictionary) -> void:
	var room_type := str(node.get("room_type", "combat"))
	_set_music_context("boss" if room_type == "boss" else "combat")
	next_room_panel.visible = false
	resolution_panel.visible = false
	_clear_active_game()
	_active_game = GAME_WORLD_SCENE.instantiate()
	_active_game.configure_players(RunState.player_configs)
	_active_game.configure_room(node)
	game_container.add_child(_active_game)
	_active_game.room_cleared.connect(_on_room_cleared)
	_active_game.all_players_dead.connect(_on_room_failed)
	_active_game.return_to_menu_requested.connect(_on_game_return_to_menu_requested)

func _on_room_cleared(health_states: Array, clear_context: Dictionary = {}) -> void:
	var outcome := RunState.resolve_current_combat_victory(health_states, clear_context)
	_show_outcome(outcome)

func _on_room_failed() -> void:
	if RunState.run_outcome != "won":
		RunState.run_outcome = "failed"
	var bank_context := _bank_run_score_once()
	_show_resolution("Run Failed", "The party was defeated.\nReached room %d.\n%s\n%s" % [
		max(RunState.rooms_completed + 1, 1),
		RunState.get_run_summary_text(),
		_format_banked_score_text(bank_context),
	], "Return to Menu")
	_post_resolution_action = "return_to_menu"

func _on_game_return_to_menu_requested() -> void:
	_bank_run_score_once()
	_clear_active_game()
	return_to_menu_requested.emit(false)

func _show_outcome(outcome: Dictionary) -> void:
	_post_resolution_action = str(outcome.get("post_action", "next"))
	_show_resolution(str(outcome.get("title", "Result")), str(outcome.get("summary", "")), str(outcome.get("button_text", "Continue")))
	if _post_resolution_action == "win_milestone":
		_secondary_resolution_action = "return_to_menu"
		resolution_secondary_button.text = "End Run"
		resolution_secondary_button.visible = true

func _show_resolution(title: String, detail: String, button_text: String) -> void:
	_set_music_context("map")
	next_room_panel.visible = false
	resolution_panel.visible = true
	run_summary_panel.visible = false
	_clear_active_game()
	resolution_title_label.text = title
	resolution_detail_label.text = detail
	resolution_button.text = button_text
	_secondary_resolution_action = ""
	resolution_secondary_button.visible = false
	call_deferred("_focus_resolution_panel")

func _on_resolution_button_pressed() -> void:
	match _post_resolution_action:
		"return_to_menu":
			return_to_menu_requested.emit(false)
		"win_milestone":
			_show_next_room_choice()
		_:
			_show_next_room_choice()

func _on_resolution_secondary_button_pressed() -> void:
	if _secondary_resolution_action == "return_to_menu":
		_bank_run_score_once()
		return_to_menu_requested.emit(true)

func _bank_run_score_once() -> Dictionary:
	if RunState.is_debug_single_room_mode():
		return {"earned": 0, "total": ProfileState.banked_score if ProfileState != null else 0}
	var earned := RunState.bank_run_score_once()
	var total := ProfileState.banked_score if ProfileState != null else 0
	if earned > 0 and ProfileState != null:
		total = ProfileState.add_score(earned)
	return {"earned": earned, "total": total}

func _format_banked_score_text(bank_context: Dictionary) -> String:
	return "Score earned: %d\nBanked total: %d" % [
		int(bank_context.get("earned", 0)),
		int(bank_context.get("total", 0)),
	]

func _launch_single_debug_room() -> void:
	var options: Array = RunState.get_current_options()
	if options.is_empty():
		_show_resolution("Encounter Missing", "No single-room encounter was configured.", "Return to Encounter Builder")
		_post_resolution_action = "return_to_menu"
		return
	var node: Dictionary = options[0]
	if not RunState.select_map_node(str(node.get("id", ""))):
		_show_resolution("Encounter Missing", "The configured encounter could not be selected.", "Return to Encounter Builder")
		_post_resolution_action = "return_to_menu"
		return
	_launch_room(node)

func _clear_active_game() -> void:
	if _active_game != null and is_instance_valid(_active_game):
		_active_game.queue_free()
	_active_game = null

func _set_music_context(context: String) -> void:
	if MusicEngine != null and MusicEngine.has_method("set_context"):
		MusicEngine.set_context(context)

func _format_modifier_name(mod_id: String) -> String:
	if mod_id.is_empty():
		return ""
	var definition := _modifier_definitions.get(mod_id, {}) as Dictionary
	if not definition.is_empty():
		return str(definition.get("name", mod_id))
	var words := mod_id.split("_")
	var parts: Array = []
	for word in words:
		if word.is_empty():
			continue
		parts.append(word.capitalize())
	return " ".join(parts)

func _format_where_name(where_id: String) -> String:
	if WHERE_DISPLAY.has(where_id):
		return str(WHERE_DISPLAY[where_id])
	return _format_modifier_name(where_id)

func _format_boss_name(boss_type: String) -> String:
	if boss_type.is_empty():
		return "Champion"
	return boss_type.capitalize()

func _load_modifier_definitions() -> void:
	_modifier_definitions.clear()
	if not FileAccess.file_exists(MODIFIERS_DATA_PATH):
		return
	var file := FileAccess.open(MODIFIERS_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	for entry in ((parsed as Dictionary).get("modifiers", []) as Array):
		if not (entry is Dictionary):
			continue
		var definition: Dictionary = (entry as Dictionary).duplicate(true)
		var modifier_id := str(definition.get("id", ""))
		if modifier_id.is_empty():
			continue
		_modifier_definitions[modifier_id] = definition

func _focus_resolution_panel() -> void:
	resolution_button.grab_focus()
