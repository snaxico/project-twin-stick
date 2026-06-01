extends Control

const PlayerConfigData = preload("res://scripts/player/PlayerConfig.gd")
const AbilityRegistryData = preload("res://scripts/game/AbilityRegistry.gd")
const IconFactoryData = preload("res://scripts/ui/IconFactory.gd")
const RUN_FLOW_SCENE = preload("res://scenes/ui/RunFlow.tscn")
const MUTATIONS_DATA_PATH := "res://data/mutations.json"
const MODIFIERS_DATA_PATH := "res://data/modifiers.json"

@onready var game_container: Control = $GameContainer
@onready var sfx_engine = $SfxEngine
@onready var home_panel: Panel = $HomePanel
@onready var home_status_label: Label = $HomePanel/MarginContainer/HomeLayout/HomeStatusLabel
@onready var home_play_button: Button = $HomePanel/MarginContainer/HomeLayout/PlayButton
@onready var home_meta_button: Button = $HomePanel/MarginContainer/HomeLayout/MetaButton
@onready var home_settings_button: Button = $HomePanel/MarginContainer/HomeLayout/SettingsButton
@onready var home_debug_button: Button = $HomePanel/MarginContainer/HomeLayout/DebugButton
@onready var menu_panel: Panel = $MenuPanel
@onready var menu_layout: VBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout
@onready var setup_title_label: Label = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/Title
@onready var setup_subtitle_label: Label = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/Subtitle
@onready var player_count_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/PlayerCountRow/PlayerCountOption
@onready var run_mode_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/RunModeRow
@onready var run_mode_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/RunModeRow/RunModeOption
@onready var player_1_control_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/Player1ControlRow/Player1ControlOption
@onready var player_2_control_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/Player2ControlRow/Player2ControlOption
@onready var player_3_control_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/Player3ControlRow
@onready var player_4_control_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/Player4ControlRow
@onready var debug_primary_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugPrimaryRow
@onready var debug_primary_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugPrimaryRow/DebugPrimaryOption
@onready var debug_secondary_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugSecondaryRow
@onready var debug_secondary_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugSecondaryRow/DebugSecondaryOption
@onready var debug_room_type_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugRoomTypeRow
@onready var debug_room_type_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugRoomTypeRow/DebugRoomTypeOption
@onready var debug_room_objective_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugRoomObjectiveRow
@onready var debug_room_objective_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugRoomObjectiveRow/DebugRoomObjectiveOption
@onready var debug_step_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugStepRow
@onready var debug_step_spinbox: SpinBox = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugStepRow/DebugStepSpinBox
@onready var debug_mode_check: CheckBox = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugModeCheck
@onready var debug_launch_mode_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugLaunchModeRow
@onready var debug_room_modifiers_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugRoomModifiersRow
@onready var debug_modifier_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugModifierRow
@onready var debug_modifier_label: Label = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugModifierRow/DebugModifierLabel
@onready var debug_modifier_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugModifierRow/DebugModifierOption
@onready var debug_layout_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugLayoutRow
@onready var debug_layout_label: Label = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugLayoutRow/DebugLayoutLabel
@onready var debug_layout_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugLayoutRow/DebugLayoutOption
@onready var setup_back_button: Button = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/SetupBackButton
@onready var settings_button: Button = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/SettingsButton
@onready var meta_button: Button = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/MetaButton
@onready var reset_profile_button: Button = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/ResetProfileButton
@onready var start_button: Button = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/StartButton
@onready var status_label: Label = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/StatusLabel
@onready var settings_panel: Panel = $SettingsPanel
@onready var settings_screen_effect_option: OptionButton = $SettingsPanel/MarginContainer/SettingsLayout/ScreenEffectsRow/ScreenEffectsOption
@onready var settings_player_1_row: HBoxContainer = $SettingsPanel/MarginContainer/SettingsLayout/Player1AimRow
@onready var settings_player_1_option: OptionButton = $SettingsPanel/MarginContainer/SettingsLayout/Player1AimRow/Player1AimOption
@onready var settings_player_2_row: HBoxContainer = $SettingsPanel/MarginContainer/SettingsLayout/Player2AimRow
@onready var settings_player_2_option: OptionButton = $SettingsPanel/MarginContainer/SettingsLayout/Player2AimRow/Player2AimOption
@onready var settings_player_3_row: HBoxContainer = $SettingsPanel/MarginContainer/SettingsLayout/Player3AimRow
@onready var settings_player_4_row: HBoxContainer = $SettingsPanel/MarginContainer/SettingsLayout/Player4AimRow
@onready var settings_back_button: Button = $SettingsPanel/MarginContainer/SettingsLayout/SettingsBackButton
@onready var meta_panel: Panel = $MetaPanel

var _active_game = null
var _player_tints := [
	Color(0.2, 0.9, 1.0, 1.0),
	Color(1.0, 0.2, 0.8, 1.0),
]
var _mutation_definitions: Array = []
var _debug_mutation_toggles: Array = []
var _modifier_definitions: Array = []
var _debug_modifier_toggles: Array = []
var _setup_mode: String = "play"
var _ability_registry = AbilityRegistryData.new()
var _ability_rows: Array = []

func _ready() -> void:
	_load_mutation_definitions()
	_load_modifier_definitions()
	_populate_menu()
	home_play_button.pressed.connect(_on_home_play_button_pressed)
	home_debug_button.pressed.connect(_on_home_debug_button_pressed)
	player_count_option.item_selected.connect(_refresh_menu_state)
	run_mode_option.item_selected.connect(_refresh_menu_state)
	debug_room_type_option.item_selected.connect(_refresh_menu_state)
	debug_room_objective_option.item_selected.connect(_refresh_menu_state)
	debug_step_spinbox.value_changed.connect(_on_debug_step_changed)
	setup_back_button.pressed.connect(_on_setup_back_button_pressed)
	start_button.pressed.connect(_on_start_pressed)
	home_meta_button.visible = false
	home_settings_button.visible = false
	meta_panel.visible = false
	meta_button.visible = false
	settings_button.visible = false
	reset_profile_button.visible = false
	player_3_control_row.visible = false
	player_4_control_row.visible = false
	debug_mode_check.visible = false
	debug_launch_mode_row.visible = false
	debug_room_modifiers_row.visible = false
	debug_modifier_row.visible = false
	debug_layout_row.visible = false
	settings_player_3_row.visible = false
	settings_player_4_row.visible = false
	home_debug_button.text = "Encounter Builder"
	home_panel.visible = true
	menu_panel.visible = false
	settings_panel.visible = false
	_refresh_menu_state()
	_refresh_home_panel()
	call_deferred("_focus_home_panel")

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if menu_panel.visible:
		_on_setup_back_button_pressed()
		get_viewport().set_input_as_handled()

func _populate_menu() -> void:
	_configure_debug_builder_rows()
	player_count_option.clear()
	player_count_option.add_item("1 Player")
	player_count_option.add_item("2 Players")
	player_count_option.select(0)
	_populate_profile_option(run_mode_option, [
		{"label": "Structured", "value": "structured"},
		{"label": "Endless", "value": "endless"},
	], "structured")
	_populate_control_option(player_1_control_option, "gamepad")
	_populate_control_option(player_2_control_option, "keyboard")
	_populate_profile_option(debug_primary_option, [{"label": "Rifle", "value": "rifle"}], "rifle")
	_populate_profile_option(debug_secondary_option, [{"label": "Mixed", "value": "mixed"}], "mixed")
	_populate_profile_option(debug_room_type_option, [
		{"label": "Combat", "value": "combat"},
		{"label": "Elite", "value": "elite"},
		{"label": "Boss", "value": "boss"},
	], "combat")
	_populate_profile_option(debug_room_objective_option, [
		{"label": "Kill All", "value": "kill_all"},
	], "kill_all")
	_populate_profile_option(debug_layout_option, [
		{"label": "Mixed", "value": "mixed"},
		{"label": "Chasers Only", "value": "chaser_only"},
		{"label": "Chargers Only", "value": "charger_only"},
	], "mixed")
	debug_step_spinbox.min_value = 0
	debug_step_spinbox.max_value = 12
	debug_step_spinbox.step = 1
	debug_step_spinbox.value = 0
	_build_ability_rows()

func _populate_control_option(option_button: OptionButton, default_value: String) -> void:
	option_button.clear()
	option_button.add_item("Keyboard")
	option_button.set_item_metadata(0, "keyboard")
	option_button.add_item("Gamepad")
	option_button.set_item_metadata(1, "gamepad")
	for index in range(option_button.item_count):
		if option_button.get_item_metadata(index) == default_value:
			option_button.select(index)
			break

func _populate_profile_option(option_button: OptionButton, entries: Array, default_value: String) -> void:
	option_button.clear()
	for index in range(entries.size()):
		option_button.add_item(str(entries[index]["label"]))
		option_button.set_item_metadata(index, str(entries[index]["value"]))
		if str(entries[index]["value"]) == default_value:
			option_button.select(index)

func _refresh_menu_state(_unused: Variant = null) -> void:
	var encounter_builder_mode := _setup_mode == "encounter_builder"
	var player_count := get_selected_player_count()
	run_mode_row.visible = not encounter_builder_mode
	player_2_control_option.get_parent().visible = player_count > 1
	debug_primary_row.visible = encounter_builder_mode
	debug_secondary_row.visible = false
	debug_room_type_row.visible = encounter_builder_mode
	debug_room_objective_row.visible = encounter_builder_mode and str(debug_room_type_option.get_selected_metadata()) == "combat"
	debug_step_row.visible = encounter_builder_mode
	debug_room_modifiers_row.visible = encounter_builder_mode
	debug_modifier_row.visible = encounter_builder_mode
	debug_layout_row.visible = encounter_builder_mode and str(debug_room_type_option.get_selected_metadata()) == "combat"
	settings_player_2_row.visible = player_count > 1
	setup_title_label.text = "Encounter Builder" if encounter_builder_mode else "Run Setup"
	setup_subtitle_label.text = "Pick one room, one objective, and iterate fast." if encounter_builder_mode else "Choose players, controls, and run mode before the run starts."
	var summary_lines: Array = []
	summary_lines.append("Players: %d" % player_count)
	if not encounter_builder_mode:
		summary_lines.append("Run Mode: %s" % run_mode_option.get_item_text(run_mode_option.selected))
		summary_lines.append("Focus: bigger arena, one weapon, mutation snowball.")
	else:
		summary_lines.append("Encounter: %s" % debug_room_type_option.get_item_text(debug_room_type_option.selected))
		if debug_room_objective_row.visible:
			summary_lines.append("Objective: %s" % debug_room_objective_option.get_item_text(debug_room_objective_option.selected))
		if debug_layout_row.visible:
			summary_lines.append("Enemy Mix: %s" % debug_layout_option.get_item_text(debug_layout_option.selected))
		summary_lines.append("Room Modifiers: %d" % _get_selected_room_modifiers().size())
		var selected_mutations: Array = _get_selected_starting_mutations()
		summary_lines.append("Starting Mutations: %d" % selected_mutations.size())
		summary_lines.append("Depth: %d" % int(debug_step_spinbox.value))
	for player_index in range(player_count):
		var selected_abilities := _get_player_ability_pair(player_index)
		summary_lines.append("P%d Abilities: %s / %s" % [player_index + 1, _format_name(selected_abilities[0]), _format_name(selected_abilities[1])])
	status_label.text = "\n".join(summary_lines)
	start_button.text = "Launch Encounter" if encounter_builder_mode else "Start Run"
	for row_index in range(_ability_rows.size()):
		var row_data: Dictionary = _ability_rows[row_index]
		var container: Control = row_data["container"]
		container.visible = row_index < player_count
		_sync_ability_row_buttons(row_index)
	start_button.disabled = not _can_start_run(player_count)
	_refresh_home_panel()

func get_selected_player_count() -> int:
	return player_count_option.selected + 1

func _on_debug_step_changed(_value: float) -> void:
	_refresh_menu_state()

func _on_start_pressed() -> void:
	_launch_game(_build_player_configs())

func _on_home_play_button_pressed() -> void:
	_open_setup_panel("play")

func _on_home_debug_button_pressed() -> void:
	_open_setup_panel("encounter_builder")

func _build_player_configs() -> Array:
	var configs: Array = []
	var control_options := [player_1_control_option, player_2_control_option]
	for index in range(get_selected_player_count()):
		var control_source := str(control_options[index].get_selected_metadata())
		configs.append(PlayerConfigData.new(index + 1, control_source, _player_tints[index]))
	return configs

func _build_debug_start_options() -> Dictionary:
	var options := {
		"run_mode": str(run_mode_option.get_selected_metadata()),
		"enabled": _setup_mode == "encounter_builder",
		"launch_mode": "single_room" if _setup_mode == "encounter_builder" else "normal_run",
		"primary_profile": "rifle",
		"secondary_profile": "mixed",
		"enemy_mix": "mixed",
		"starting_mutations": [],
		"player_abilities": _build_player_ability_selection(),
	}
	if not options["enabled"]:
		return options
	options["step_index"] = int(debug_step_spinbox.value)
	options["room_type"] = str(debug_room_type_option.get_selected_metadata())
	options["room_objective"] = str(debug_room_objective_option.get_selected_metadata())
	options["enemy_mix"] = str(debug_layout_option.get_selected_metadata())
	options["modifiers"] = _get_selected_room_modifiers()
	options["starting_mutations"] = _get_selected_starting_mutations()
	return options

func _launch_game(player_configs: Array) -> void:
	if _active_game != null and is_instance_valid(_active_game):
		_active_game.queue_free()
	RunState.start_new_run(player_configs, _build_debug_start_options())
	_active_game = RUN_FLOW_SCENE.instantiate()
	_active_game.return_to_menu_requested.connect(_on_return_to_menu_requested)
	game_container.add_child(_active_game)
	_set_panel_state(home_panel, false)
	_set_panel_state(menu_panel, false)
	_set_panel_state(settings_panel, false)

func _on_return_to_menu_requested(_open_meta_menu: bool = false) -> void:
	if _active_game != null and is_instance_valid(_active_game):
		_active_game.queue_free()
	_active_game = null
	if _setup_mode == "encounter_builder":
		_open_setup_panel("encounter_builder")
		return
	_open_home_panel()

func _on_setup_back_button_pressed() -> void:
	_open_home_panel()

func _open_home_panel() -> void:
	_refresh_menu_state()
	_set_panel_state(menu_panel, false)
	_set_panel_state(settings_panel, false)
	_set_panel_state(home_panel, true)
	call_deferred("_focus_home_panel")

func _open_setup_panel(mode: String) -> void:
	_setup_mode = mode
	_refresh_menu_state()
	_set_panel_state(home_panel, false)
	_set_panel_state(settings_panel, false)
	_set_panel_state(menu_panel, true)
	call_deferred("_focus_menu_panel")

func _refresh_home_panel() -> void:
	home_status_label.text = "V3 content branch\nCurrent Run Mode: %s\nTarget: 1-2 players only" % [
		run_mode_option.get_item_text(run_mode_option.selected),
	]

func _focus_home_panel() -> void:
	home_play_button.grab_focus()

func _focus_menu_panel() -> void:
	if _setup_mode == "encounter_builder":
		debug_room_type_option.grab_focus()
	else:
		run_mode_option.grab_focus()

func _set_panel_state(panel: Control, should_show: bool) -> void:
	panel.visible = should_show

func _configure_debug_builder_rows() -> void:
	debug_layout_label.text = "Enemy Mix"
	debug_room_modifiers_row.visible = false
	var debug_room_modifiers_label: Label = debug_room_modifiers_row.get_node("DebugRoomModifiersLabel") as Label
	if debug_room_modifiers_label != null:
		debug_room_modifiers_label.text = "Room Modifiers"
	var debug_room_modifiers_spinbox: SpinBox = debug_room_modifiers_row.get_node("DebugRoomModifiersSpinBox") as SpinBox
	if debug_room_modifiers_spinbox != null:
		debug_room_modifiers_spinbox.visible = false
	_create_modifier_selector()
	debug_modifier_label.text = "Starting Mutations"
	debug_modifier_option.visible = false
	if debug_modifier_row.get_node_or_null("MutationScroll") != null:
		return
	var mutation_scroll := ScrollContainer.new()
	mutation_scroll.name = "MutationScroll"
	mutation_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mutation_scroll.custom_minimum_size = Vector2(0.0, 156.0)
	debug_modifier_row.add_child(mutation_scroll)
	var mutation_grid := GridContainer.new()
	mutation_grid.name = "MutationGrid"
	mutation_grid.columns = 2
	mutation_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mutation_grid.add_theme_constant_override("h_separation", 10)
	mutation_grid.add_theme_constant_override("v_separation", 6)
	mutation_scroll.add_child(mutation_grid)
	_debug_mutation_toggles.clear()
	for mutation in _mutation_definitions:
		var mutation_id: String = str((mutation as Dictionary).get("id", ""))
		var mutation_name: String = str((mutation as Dictionary).get("name", mutation_id.capitalize()))
		var toggle := CheckBox.new()
		toggle.text = mutation_name
		toggle.tooltip_text = str((mutation as Dictionary).get("description", ""))
		toggle.set_meta("mutation_id", mutation_id)
		toggle.toggled.connect(_on_debug_mutation_toggled)
		mutation_grid.add_child(toggle)
		_debug_mutation_toggles.append(toggle)

func _build_ability_rows() -> void:
	if not _ability_rows.is_empty():
		return
	var insert_before := status_label
	var ability_defs := _ability_registry.get_all()
	for player_index in range(2):
		var container := VBoxContainer.new()
		container.name = "AbilityRowsP%d" % (player_index + 1)
		container.add_theme_constant_override("separation", 10)
		menu_layout.add_child(container)
		menu_layout.move_child(container, insert_before.get_index())
		var header := Label.new()
		header.text = "Player %d Abilities" % (player_index + 1)
		header.add_theme_font_size_override("font_size", 17)
		container.add_child(header)
		var helper := Label.new()
		helper.text = "Pick exactly 2. First pick maps to Slot 1, second pick maps to Slot 2."
		helper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		helper.modulate = Color(0.82, 0.88, 0.96, 0.82)
		container.add_child(helper)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		container.add_child(grid)
		var cards: Dictionary = {}
		for ability_def in ability_defs:
			var ability_definition: Dictionary = ability_def as Dictionary
			var ability_id := str(ability_definition.get("id", ""))
			if ability_id.is_empty():
				continue
			var card := Button.new()
			card.toggle_mode = true
			card.custom_minimum_size = Vector2(0.0, 44.0)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.alignment = HORIZONTAL_ALIGNMENT_LEFT
			card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card.icon = null
			card.text = "%s — %s" % [
				str(ability_definition.get("name", _format_name(ability_id))),
				_shorten_text(str(ability_definition.get("description", "")), 40),
			]
			card.tooltip_text = str(ability_definition.get("description", ""))
			card.toggled.connect(_on_ability_card_toggled.bind(player_index, ability_id))
			grid.add_child(card)
			cards[ability_id] = card
		var summary := Label.new()
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(summary)
		_ability_rows.append({
			"container": container,
			"cards": cards,
			"summary": summary,
			"selection_order": ["shockwave", "dash"],
		})
		_sync_ability_row_buttons(player_index)

func _build_player_ability_selection() -> Array:
	var selections: Array = []
	for player_index in range(get_selected_player_count()):
		selections.append(_get_player_ability_pair(player_index))
	return selections

func _get_player_ability_pair(player_index: int) -> Array:
	if player_index < 0 or player_index >= _ability_rows.size():
		return ["shockwave", "dash"]
	var row_data: Dictionary = _ability_rows[player_index]
	var selection_order: Array = (row_data.get("selection_order", ["shockwave", "dash"]) as Array).duplicate()
	if selection_order.is_empty():
		selection_order.append("shockwave")
	if selection_order.size() == 1:
		selection_order.append("dash" if str(selection_order[0]) != "dash" else "shockwave")
	return [str(selection_order[0]), str(selection_order[1])]

func _on_ability_card_toggled(pressed: bool, player_index: int, ability_id: String) -> void:
	if player_index < 0 or player_index >= _ability_rows.size():
		return
	var row_data: Dictionary = _ability_rows[player_index]
	var selection_order: Array = (row_data.get("selection_order", []) as Array).duplicate()
	if pressed:
		if not selection_order.has(ability_id):
			if selection_order.size() >= 2:
				selection_order.pop_back()
			selection_order.append(ability_id)
	else:
		selection_order.erase(ability_id)
	row_data["selection_order"] = selection_order
	_ability_rows[player_index] = row_data
	_sync_ability_row_buttons(player_index)
	_refresh_menu_state()

func _sync_ability_row_buttons(player_index: int) -> void:
	if player_index < 0 or player_index >= _ability_rows.size():
		return
	var row_data: Dictionary = _ability_rows[player_index]
	var cards: Dictionary = row_data.get("cards", {}) as Dictionary
	var selection_order: Array = row_data.get("selection_order", []) as Array
	for ability_id_variant in cards.keys():
		var ability_id := str(ability_id_variant)
		var button: Button = cards[ability_id]
		if button == null:
			continue
		var slot_index := selection_order.find(ability_id)
		button.set_pressed_no_signal(slot_index >= 0)
		_style_ability_card(button, slot_index)
	var summary: Label = row_data.get("summary", null)
	if summary != null:
		if selection_order.size() >= 2:
			summary.text = "Selected: Slot 1 %s  |  Slot 2 %s" % [
				_format_name(str(selection_order[0])),
				_format_name(str(selection_order[1])),
			]
			summary.modulate = Color(0.84, 0.92, 1.0, 0.92)
		else:
			summary.text = "Select one more ability to finish the loadout."
			summary.modulate = Color(1.0, 0.8, 0.42, 0.96)

func _style_ability_card(button: Button, slot_index: int) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.09, 0.13, 0.96)
	normal.border_color = Color(0.24, 0.3, 0.4, 0.72)
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	normal.set_content_margin_all(10)
	var hover := normal.duplicate()
	hover.border_color = Color(0.42, 0.5, 0.64, 0.9)
	var pressed := normal.duplicate()
	if slot_index == 0:
		pressed.bg_color = Color(0.08, 0.18, 0.24, 0.98)
		pressed.border_color = Color(0.3, 0.92, 1.0, 0.98)
	elif slot_index == 1:
		pressed.bg_color = Color(0.18, 0.11, 0.2, 0.98)
		pressed.border_color = Color(1.0, 0.56, 0.86, 0.98)
	else:
		pressed.bg_color = normal.bg_color
		pressed.border_color = normal.border_color
	pressed.set_border_width_all(2 if slot_index >= 0 else 1)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("focus", pressed)

func _can_start_run(player_count: int) -> bool:
	for player_index in range(player_count):
		var row_data: Dictionary = _ability_rows[player_index]
		var selection_order: Array = row_data.get("selection_order", []) as Array
		if selection_order.size() < 2:
			return false
	return true

func _shorten_text(text: String, max_length: int) -> String:
	if text.length() <= max_length:
		return text
	return "%s..." % text.substr(0, max_length - 3).rstrip(" ")

func _format_name(raw_id: String) -> String:
	var parts: Array = []
	for part in raw_id.split("_"):
		if not part.is_empty():
			parts.append(part.capitalize())
	return " ".join(parts)

func _create_modifier_selector() -> void:
	if debug_room_modifiers_row.get_node_or_null("ModifierScroll") != null:
		return
	var modifier_scroll := ScrollContainer.new()
	modifier_scroll.name = "ModifierScroll"
	modifier_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modifier_scroll.custom_minimum_size = Vector2(0.0, 128.0)
	debug_room_modifiers_row.add_child(modifier_scroll)
	var modifier_grid := GridContainer.new()
	modifier_grid.name = "ModifierGrid"
	modifier_grid.columns = 2
	modifier_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modifier_grid.add_theme_constant_override("h_separation", 10)
	modifier_grid.add_theme_constant_override("v_separation", 6)
	modifier_scroll.add_child(modifier_grid)
	_debug_modifier_toggles.clear()
	for modifier in _modifier_definitions:
		var modifier_id := str((modifier as Dictionary).get("id", ""))
		var modifier_name := str((modifier as Dictionary).get("name", modifier_id.capitalize()))
		var toggle := CheckBox.new()
		toggle.text = modifier_name
		toggle.tooltip_text = str((modifier as Dictionary).get("description", ""))
		toggle.set_meta("modifier_id", modifier_id)
		toggle.toggled.connect(_on_debug_modifier_toggled.bind(toggle))
		modifier_grid.add_child(toggle)
		_debug_modifier_toggles.append(toggle)

func _load_mutation_definitions() -> void:
	_mutation_definitions.clear()
	if not FileAccess.file_exists(MUTATIONS_DATA_PATH):
		return
	var file := FileAccess.open(MUTATIONS_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	var mutations: Array = (parsed as Dictionary).get("mutations", []) as Array
	for mutation in mutations:
		if mutation is Dictionary:
			_mutation_definitions.append((mutation as Dictionary).duplicate(true))

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
	var modifiers: Array = (parsed as Dictionary).get("modifiers", []) as Array
	for modifier in modifiers:
		if modifier is Dictionary:
			_modifier_definitions.append((modifier as Dictionary).duplicate(true))

func _get_selected_starting_mutations() -> Array:
	var selected: Array = []
	for toggle in _debug_mutation_toggles:
		if toggle == null or not is_instance_valid(toggle) or not toggle.button_pressed:
			continue
		selected.append(str(toggle.get_meta("mutation_id", "")))
	return selected

func _on_debug_mutation_toggled(_pressed: bool) -> void:
	_refresh_menu_state()

func _get_selected_room_modifiers() -> Array:
	var selected: Array = []
	for toggle in _debug_modifier_toggles:
		if toggle == null or not is_instance_valid(toggle) or not toggle.button_pressed:
			continue
		selected.append(str(toggle.get_meta("modifier_id", "")))
	return selected

func _on_debug_modifier_toggled(_pressed: bool, toggle: CheckBox) -> void:
	if _get_selected_room_modifiers().size() <= 3:
		_refresh_menu_state()
		return
	toggle.button_pressed = false
	_refresh_menu_state()
