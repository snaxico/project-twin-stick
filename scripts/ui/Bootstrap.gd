extends Control

const PlayerConfigData = preload("res://scripts/player/PlayerConfig.gd")
const ModifierEngineData = preload("res://scripts/game/ModifierEngine.gd")
const RUN_FLOW_SCENE = preload("res://scenes/ui/RunFlow.tscn")
@onready var game_container: Control = $GameContainer
@onready var sfx_engine = $SfxEngine
@onready var home_panel: Panel = $HomePanel
@onready var home_status_label: Label = $HomePanel/MarginContainer/HomeLayout/HomeStatusLabel
@onready var home_play_button: Button = $HomePanel/MarginContainer/HomeLayout/PlayButton
@onready var home_meta_button: Button = $HomePanel/MarginContainer/HomeLayout/MetaButton
@onready var home_settings_button: Button = $HomePanel/MarginContainer/HomeLayout/SettingsButton
@onready var home_debug_button: Button = $HomePanel/MarginContainer/HomeLayout/DebugButton
@onready var menu_panel: Panel = $MenuPanel
@onready var setup_title_label: Label = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/Title
@onready var setup_subtitle_label: Label = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/Subtitle
@onready var player_count_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/PlayerCountRow/PlayerCountOption
@onready var run_mode_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/RunModeRow
@onready var run_mode_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/RunModeRow/RunModeOption
@onready var player_1_control_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/Player1ControlRow/Player1ControlOption
@onready var player_2_control_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/Player2ControlRow/Player2ControlOption
@onready var player_3_control_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/Player3ControlRow/Player3ControlOption
@onready var player_4_control_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/Player4ControlRow/Player4ControlOption
@onready var debug_mode_check: CheckBox = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugModeCheck
@onready var debug_launch_mode_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugLaunchModeRow
@onready var debug_launch_mode_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugLaunchModeRow/DebugLaunchModeOption
@onready var debug_primary_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugPrimaryRow
@onready var debug_primary_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugPrimaryRow/DebugPrimaryOption
@onready var debug_secondary_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugSecondaryRow
@onready var debug_secondary_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugSecondaryRow/DebugSecondaryOption
@onready var debug_starting_gold_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugStartingGoldRow
@onready var debug_starting_gold_spinbox: SpinBox = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugStartingGoldRow/DebugStartingGoldSpinBox
@onready var debug_room_type_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugRoomTypeRow
@onready var debug_room_type_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugRoomTypeRow/DebugRoomTypeOption
@onready var debug_room_objective_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugRoomObjectiveRow
@onready var debug_room_objective_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugRoomObjectiveRow/DebugRoomObjectiveOption
@onready var debug_modifier_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugModifierRow
@onready var debug_modifier_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugModifierRow/DebugModifierOption
@onready var debug_layout_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugLayoutRow
@onready var debug_layout_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugLayoutRow/DebugLayoutOption
@onready var debug_step_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugStepRow
@onready var debug_step_spinbox: SpinBox = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/DebugStepRow/DebugStepSpinBox
@onready var setup_back_button: Button = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/SetupBackButton
@onready var settings_button: Button = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/SettingsButton
@onready var meta_button: Button = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/MetaButton
@onready var reset_profile_button: Button = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/ResetProfileButton
@onready var start_button: Button = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/StartButton
@onready var player_2_control_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/Player2ControlRow
@onready var player_3_control_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/Player3ControlRow
@onready var player_4_control_row: HBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/Player4ControlRow
@onready var status_label: Label = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/StatusLabel
@onready var settings_panel: Panel = $SettingsPanel
@onready var settings_screen_effect_row: HBoxContainer = $SettingsPanel/MarginContainer/SettingsLayout/ScreenEffectsRow
@onready var settings_screen_effect_option: OptionButton = $SettingsPanel/MarginContainer/SettingsLayout/ScreenEffectsRow/ScreenEffectsOption
@onready var settings_player_1_row: HBoxContainer = $SettingsPanel/MarginContainer/SettingsLayout/Player1AimRow
@onready var settings_player_1_option: OptionButton = $SettingsPanel/MarginContainer/SettingsLayout/Player1AimRow/Player1AimOption
@onready var settings_player_2_row: HBoxContainer = $SettingsPanel/MarginContainer/SettingsLayout/Player2AimRow
@onready var settings_player_2_option: OptionButton = $SettingsPanel/MarginContainer/SettingsLayout/Player2AimRow/Player2AimOption
@onready var settings_player_3_row: HBoxContainer = $SettingsPanel/MarginContainer/SettingsLayout/Player3AimRow
@onready var settings_player_3_option: OptionButton = $SettingsPanel/MarginContainer/SettingsLayout/Player3AimRow/Player3AimOption
@onready var settings_player_4_row: HBoxContainer = $SettingsPanel/MarginContainer/SettingsLayout/Player4AimRow
@onready var settings_player_4_option: OptionButton = $SettingsPanel/MarginContainer/SettingsLayout/Player4AimRow/Player4AimOption
@onready var settings_back_button: Button = $SettingsPanel/MarginContainer/SettingsLayout/SettingsBackButton
@onready var meta_panel: Panel = $MetaPanel
@onready var meta_status_label: Label = $MetaPanel/MarginContainer/MetaLayout/MetaStatusLabel
@onready var unlock_button_1: Button = $MetaPanel/MarginContainer/MetaLayout/UnlockButton1
@onready var unlock_button_2: Button = $MetaPanel/MarginContainer/MetaLayout/UnlockButton2
@onready var unlock_button_3: Button = $MetaPanel/MarginContainer/MetaLayout/UnlockButton3
@onready var unlock_button_4: Button = $MetaPanel/MarginContainer/MetaLayout/UnlockButton4
@onready var meta_back_button: Button = $MetaPanel/MarginContainer/MetaLayout/MetaBackButton

var _active_game = null
var _meta_unlocks: Array = []
var _panel_base_positions: Dictionary = {}
var _player_tints := [
	Color(0.15, 0.92, 0.25, 1.0),
	Color(0.18, 0.42, 1.0, 1.0),
	Color(1.0, 0.88, 0.12, 1.0),
	Color(1.0, 0.5, 0.12, 1.0),
]
var _player_aim_modes := [
	PlayerConfigData.AimMode.HEAVY_AUTO,
	PlayerConfigData.AimMode.FULL_AUTO,
	PlayerConfigData.AimMode.FULL_AUTO,
	PlayerConfigData.AimMode.FULL_AUTO,
]
var _settings_rows: Array = []
var _settings_options: Array = []
var _modifier_engine = ModifierEngineData.new()
var _modifier_definitions: Array = []
var _setup_mode: String = "play"
var _return_panel: String = "home"

func _ready() -> void:
	_player_aim_modes[0] = PlayerConfigData.AimMode.HEAVY_AUTO
	_settings_rows = [
		settings_player_1_row,
		settings_player_2_row,
		settings_player_3_row,
		settings_player_4_row,
	]
	_settings_options = [
		settings_player_1_option,
		settings_player_2_option,
		settings_player_3_option,
		settings_player_4_option,
	]
	_populate_menu()
	home_play_button.pressed.connect(_on_home_play_button_pressed)
	home_meta_button.pressed.connect(_on_home_meta_button_pressed)
	home_settings_button.pressed.connect(_on_home_settings_button_pressed)
	home_debug_button.pressed.connect(_on_home_debug_button_pressed)
	player_count_option.item_selected.connect(_on_player_count_changed)
	run_mode_option.item_selected.connect(_on_run_mode_changed)
	debug_mode_check.toggled.connect(_on_debug_mode_toggled)
	debug_launch_mode_option.item_selected.connect(_on_debug_loadout_changed)
	debug_primary_option.item_selected.connect(_on_debug_loadout_changed)
	debug_secondary_option.item_selected.connect(_on_debug_loadout_changed)
	debug_room_type_option.item_selected.connect(_on_debug_loadout_changed)
	debug_room_objective_option.item_selected.connect(_on_debug_loadout_changed)
	debug_modifier_option.item_selected.connect(_on_debug_loadout_changed)
	debug_layout_option.item_selected.connect(_on_debug_loadout_changed)
	debug_step_spinbox.value_changed.connect(_on_debug_numeric_value_changed)
	debug_starting_gold_spinbox.value_changed.connect(_on_debug_numeric_value_changed)
	setup_back_button.pressed.connect(_on_setup_back_button_pressed)
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	meta_button.pressed.connect(_on_meta_button_pressed)
	reset_profile_button.pressed.connect(_on_reset_profile_button_pressed)
	unlock_button_1.pressed.connect(_on_unlock_button_1_pressed)
	unlock_button_2.pressed.connect(_on_unlock_button_2_pressed)
	unlock_button_3.pressed.connect(_on_unlock_button_3_pressed)
	unlock_button_4.pressed.connect(_on_unlock_button_4_pressed)
	settings_screen_effect_option.item_selected.connect(_on_settings_screen_effect_selected)
	for index in range(_settings_options.size()):
		_settings_options[index].item_selected.connect(_on_settings_aim_mode_selected.bind(index))
	settings_back_button.pressed.connect(_on_settings_back_button_pressed)
	meta_back_button.pressed.connect(_on_meta_back_button_pressed)
	_register_button_animations()
	_configure_menu_focus()
	home_panel.visible = true
	menu_panel.visible = false
	settings_panel.visible = false
	meta_panel.visible = false
	debug_mode_check.visible = false
	home_debug_button.text = "Encounter Builder"
	_refresh_menu_state()
	_refresh_home_panel()
	call_deferred("_focus_home_panel")

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if settings_panel.visible:
		_on_settings_back_button_pressed()
		get_viewport().set_input_as_handled()
		return
	if meta_panel.visible:
		_on_meta_back_button_pressed()
		get_viewport().set_input_as_handled()
		return
	if menu_panel.visible:
		_on_setup_back_button_pressed()
		get_viewport().set_input_as_handled()

func _populate_menu() -> void:
	player_count_option.clear()
	player_count_option.add_item("1 Player")
	player_count_option.add_item("2 Players")
	player_count_option.add_item("3 Players")
	player_count_option.add_item("4 Players")
	player_count_option.select(0)
	_populate_profile_option(run_mode_option, [
		{"label": "Normal", "value": "normal"},
		{"label": "Easy", "value": "easy"},
	], "normal")

	_populate_control_option(player_1_control_option, "gamepad")
	_populate_control_option(player_2_control_option, "keyboard")
	_populate_control_option(player_3_control_option, "keyboard")
	_populate_control_option(player_4_control_option, "keyboard")
	_populate_profile_option(debug_primary_option, [
		{"label": "Rifle", "value": "rifle"},
		{"label": "Scatter", "value": "spread"},
		{"label": "Slug", "value": "slug"},
	], "rifle")
	_populate_profile_option(debug_secondary_option, [
		{"label": "Grenade", "value": "grenade"},
		{"label": "Cluster Grenade", "value": "cluster_grenade"},
		{"label": "Siege Grenade", "value": "siege_grenade"},
		{"label": "Mine", "value": "mine"},
		{"label": "Shrapnel Mine", "value": "shrapnel_mine"},
		{"label": "Heavy Mine", "value": "heavy_mine"},
	], "mine")
	_populate_profile_option(debug_launch_mode_option, [
		{"label": "Normal Run", "value": "normal_run"},
		{"label": "Single Room", "value": "single_room"},
	], "normal_run")
	_populate_profile_option(debug_room_type_option, [
		{"label": "Combat", "value": "combat"},
		{"label": "Elite", "value": "elite"},
		{"label": "Boss", "value": "boss"},
	], "combat")
	_refresh_debug_room_objective_options()
	_modifier_definitions = _modifier_engine.get_modifiers()
	_populate_modifier_option()
	_populate_profile_option(debug_layout_option, [
		{"label": "Random", "value": "random"},
		{"label": "Default", "value": "default"},
		{"label": "Lane", "value": "lane"},
		{"label": "Pillars", "value": "pillars"},
		{"label": "Ring", "value": "ring"},
		{"label": "Pockets", "value": "pockets"},
		{"label": "Crossfire (Legacy)", "value": "crossfire"},
		{"label": "Pinch (Legacy)", "value": "pinch"},
		{"label": "Offset (Legacy)", "value": "offset"},
		{"label": "Gauntlet Pockets (Legacy)", "value": "gauntlet_pockets"},
		{"label": "Boss Gate", "value": "boss_gate"},
	], "random")
	debug_step_spinbox.min_value = 0
	debug_step_spinbox.max_value = 12
	debug_step_spinbox.step = 1
	debug_step_spinbox.value = 0
	debug_starting_gold_spinbox.min_value = 0
	debug_starting_gold_spinbox.max_value = 99
	debug_starting_gold_spinbox.step = 1
	debug_starting_gold_spinbox.value = 0
	_populate_screen_effect_option(settings_screen_effect_option, ProfileState.get_screen_effect_level())
	for index in range(_settings_options.size()):
		_populate_aim_mode_option(_settings_options[index], _player_aim_modes[index])

func _populate_modifier_option() -> void:
	debug_modifier_option.clear()
	var entries: Array = [
		{"label": "Random", "value": "random"},
		{"label": "None", "value": "none"},
	]
	for modifier in _modifier_definitions:
		if modifier is Dictionary:
			entries.append({
				"label": str(modifier.get("name", "Modifier")),
				"value": "specific:%s" % str(modifier.get("id", "")),
			})
	_populate_profile_option(debug_modifier_option, entries, "random")

func _refresh_debug_room_objective_options() -> void:
	var selected_value := "survive"
	if debug_room_objective_option != null and debug_room_objective_option.item_count > 0:
		selected_value = str(debug_room_objective_option.get_selected_metadata())
	var entries: Array = [
		{"label": "Survive", "value": "survive"},
		{"label": "Capture The Hill", "value": "capture_the_hill"},
	]
	if _setup_mode != "encounter_builder":
		entries.append({"label": "Destroy Generators", "value": "destroy_generators"})
	if selected_value == "destroy_generators" and _setup_mode == "encounter_builder":
		selected_value = "survive"
	_populate_profile_option(debug_room_objective_option, entries, selected_value)

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
		var entry: Dictionary = entries[index]
		option_button.add_item(str(entry.get("label", "Option")))
		option_button.set_item_metadata(index, str(entry.get("value", "")))

	for index in range(option_button.item_count):
		if option_button.get_item_metadata(index) == default_value:
			option_button.select(index)
			break

func _populate_aim_mode_option(option_button: OptionButton, selected_aim_mode: int) -> void:
	option_button.clear()
	var entries := [
		{"label": "Heavy Auto", "value": PlayerConfigData.AimMode.HEAVY_AUTO},
		{"label": "Full Auto", "value": PlayerConfigData.AimMode.FULL_AUTO},
		{"label": "Manual", "value": PlayerConfigData.AimMode.MANUAL},
	]
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		option_button.add_item(str(entry.get("label", "Aim")))
		option_button.set_item_metadata(index, int(entry.get("value", PlayerConfigData.AimMode.HEAVY_AUTO)))
	_select_option_by_metadata(option_button, selected_aim_mode)

func _populate_screen_effect_option(option_button: OptionButton, selected_level: String) -> void:
	option_button.clear()
	var entries := [
		{"label": "Off", "value": "off"},
		{"label": "Minimal", "value": "minimal"},
		{"label": "Full", "value": "full"},
	]
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		option_button.add_item(str(entry.get("label", "Effects")))
		option_button.set_item_metadata(index, str(entry.get("value", "off")))
	_select_string_option_by_metadata(option_button, selected_level)

func _select_option_by_metadata(option_button: OptionButton, target_value: int) -> void:
	for index in range(option_button.item_count):
		if option_button.get_item_metadata(index) == target_value:
			option_button.select(index)
			return
	if option_button.item_count > 0:
		option_button.select(0)

func _select_string_option_by_metadata(option_button: OptionButton, target_value: String) -> void:
	for index in range(option_button.item_count):
		if str(option_button.get_item_metadata(index)) == target_value:
			option_button.select(index)
			return
	if option_button.item_count > 0:
		option_button.select(0)

func _refresh_menu_state() -> void:
	var player_count := get_selected_player_count()
	var encounter_builder_mode := _setup_mode == "encounter_builder"
	player_2_control_row.visible = player_count > 1
	player_3_control_row.visible = player_count > 2
	player_4_control_row.visible = player_count > 3
	var debug_enabled := encounter_builder_mode or debug_mode_check.button_pressed
	var single_room_mode := encounter_builder_mode or _get_debug_launch_mode() == "single_room"
	var room_type := _get_debug_room_type()
	var combat_room := room_type == "combat" or room_type == "elite"
	var supports_layout := combat_room or room_type == "boss"
	run_mode_row.visible = not encounter_builder_mode
	debug_mode_check.visible = false
	debug_launch_mode_row.visible = debug_enabled and not encounter_builder_mode
	debug_primary_row.visible = debug_enabled
	debug_secondary_row.visible = debug_enabled
	debug_starting_gold_row.visible = debug_enabled
	debug_room_type_row.visible = debug_enabled and single_room_mode
	debug_room_objective_row.visible = debug_enabled and single_room_mode and combat_room
	debug_modifier_row.visible = debug_enabled and single_room_mode and combat_room
	debug_layout_row.visible = debug_enabled and single_room_mode and supports_layout
	debug_step_row.visible = debug_enabled and single_room_mode
	meta_button.visible = debug_enabled and not encounter_builder_mode
	reset_profile_button.visible = debug_enabled and not encounter_builder_mode
	_refresh_settings_panel()
	var summary_lines: Array = []
	summary_lines.append("Players: %d" % player_count)
	if not encounter_builder_mode:
		var run_mode_name := run_mode_option.get_item_text(run_mode_option.selected)
		summary_lines.append("Run Mode: %s" % run_mode_name)
	summary_lines.append("Screen Effects: %s" % ProfileState.get_screen_effect_level().capitalize())
	if debug_enabled:
		if encounter_builder_mode:
			summary_lines.append("Encounter Builder: one room, then return here.")
		else:
			summary_lines.append("Start Mode: %s" % debug_launch_mode_option.get_item_text(debug_launch_mode_option.selected))
		summary_lines.append("Loadout: %s / %s" % [
			debug_primary_option.get_item_text(debug_primary_option.selected),
			debug_secondary_option.get_item_text(debug_secondary_option.selected),
		])
		summary_lines.append("Starting Gold: %d" % int(debug_starting_gold_spinbox.value))
		if single_room_mode:
			var room_summary := "Encounter: %s" % debug_room_type_option.get_item_text(debug_room_type_option.selected)
			if combat_room:
				room_summary += " | %s | %s" % [
					debug_room_objective_option.get_item_text(debug_room_objective_option.selected),
					debug_modifier_option.get_item_text(debug_modifier_option.selected),
				]
			if supports_layout:
				room_summary += " | %s" % debug_layout_option.get_item_text(debug_layout_option.selected)
			room_summary += " | Step %d" % int(debug_step_spinbox.value)
			summary_lines.append(room_summary)
	else:
		summary_lines.append("Health carries between rooms in Normal; Easy fully restores the team after every clear.")
		summary_lines.append("Players 3 and 4 are still best with gamepads in the current prototype.")
	status_label.text = "\n".join(summary_lines)
	if encounter_builder_mode:
		start_button.text = "Launch Encounter"
	else:
		start_button.text = "Launch Debug Room" if debug_enabled and single_room_mode else ("Start Debug Run" if debug_enabled else "Start Run")
	_refresh_setup_copy()
	_refresh_home_panel()

func _refresh_settings_panel() -> void:
	settings_screen_effect_row.visible = true
	_select_string_option_by_metadata(settings_screen_effect_option, ProfileState.get_screen_effect_level())
	var player_count := get_selected_player_count()
	var settings_slot_count := mini(_settings_rows.size(), _settings_options.size())
	for index in range(settings_slot_count):
		_settings_rows[index].visible = index < player_count
		_select_option_by_metadata(_settings_options[index], _player_aim_modes[index])

func get_selected_player_count() -> int:
	return player_count_option.selected + 1

func _on_player_count_changed(_index: int) -> void:
	_play_ui_click()
	_refresh_menu_state()

func _on_run_mode_changed(_index: int) -> void:
	_play_ui_click()
	_refresh_menu_state()

func _on_debug_mode_toggled(_enabled: bool) -> void:
	_play_ui_click()
	_refresh_menu_state()

func _on_debug_loadout_changed(_index: int) -> void:
	_play_ui_click()
	_refresh_menu_state()

func _on_debug_numeric_value_changed(_value: float) -> void:
	_refresh_menu_state()

func _on_start_pressed() -> void:
	_play_ui_click()
	var player_configs := _build_player_configs()
	_launch_game(player_configs)

func _on_home_play_button_pressed() -> void:
	_play_ui_click()
	_open_setup_panel("play")

func _on_home_meta_button_pressed() -> void:
	_play_ui_click()
	_return_panel = "home"
	_set_panel_state(home_panel, false)
	_set_panel_state(menu_panel, false)
	_set_panel_state(settings_panel, false)
	_set_panel_state(meta_panel, true)
	_refresh_meta_panel("")
	call_deferred("_focus_meta_panel")

func _on_home_settings_button_pressed() -> void:
	_play_ui_click()
	_return_panel = "home"
	_refresh_settings_panel()
	_set_panel_state(home_panel, false)
	_set_panel_state(menu_panel, false)
	_set_panel_state(meta_panel, false)
	_set_panel_state(settings_panel, true)
	call_deferred("_focus_settings_panel")

func _on_home_debug_button_pressed() -> void:
	_play_ui_click()
	_open_setup_panel("encounter_builder")

func _on_settings_button_pressed() -> void:
	_play_ui_click()
	_return_panel = "setup"
	_refresh_settings_panel()
	_set_panel_state(home_panel, false)
	_set_panel_state(menu_panel, false)
	_set_panel_state(meta_panel, false)
	_set_panel_state(settings_panel, true)
	call_deferred("_focus_settings_panel")

func _build_player_configs() -> Array:
	var configs: Array = []
	var player_count := get_selected_player_count()
	var control_options := [
		player_1_control_option,
		player_2_control_option,
		player_3_control_option,
		player_4_control_option,
	]
	var available_player_slots := mini(
		player_count,
		mini(control_options.size(), mini(_player_aim_modes.size(), _player_tints.size()))
	)
	var connected_gamepads: Array = Input.get_connected_joypads()
	var remaining_gamepad_slots: int = connected_gamepads.size()

	for index in range(available_player_slots):
		var option_button: OptionButton = control_options[index]
		var control_source := str(option_button.get_selected_metadata())
		if control_source == "gamepad":
			if remaining_gamepad_slots > 0:
				remaining_gamepad_slots -= 1
			else:
				control_source = "keyboard"
		var aim_mode: int = int(_player_aim_modes[index])
		var tint: Color = _player_tints[index]
		configs.append(PlayerConfigData.new(index + 1, control_source, tint, aim_mode))

	return configs

func _build_debug_start_options() -> Dictionary:
	var encounter_builder_mode := _setup_mode == "encounter_builder"
	var options := {
		"run_mode": str(run_mode_option.get_selected_metadata()),
		"enabled": encounter_builder_mode or debug_mode_check.button_pressed,
		"launch_mode": "single_room" if encounter_builder_mode else _get_debug_launch_mode(),
		"primary_profile": str(debug_primary_option.get_selected_metadata()),
		"secondary_profile": str(debug_secondary_option.get_selected_metadata()),
		"starting_gold": int(debug_starting_gold_spinbox.value),
	}
	if not options["enabled"]:
		return options
	if str(options["launch_mode"]) != "single_room":
		return options

	options["step_index"] = int(debug_step_spinbox.value)
	options["room_type"] = _get_debug_room_type()
	options["room_objective"] = str(debug_room_objective_option.get_selected_metadata())
	options["layout_id"] = str(debug_layout_option.get_selected_metadata())
	var modifier_selection := str(debug_modifier_option.get_selected_metadata())
	if modifier_selection == "none":
		options["modifier_mode"] = "none"
		options["modifier_id"] = ""
	elif modifier_selection.begins_with("specific:"):
		options["modifier_mode"] = "specific"
		options["modifier_id"] = modifier_selection.trim_prefix("specific:")
	else:
		options["modifier_mode"] = "random"
		options["modifier_id"] = ""
	return options

func _get_debug_launch_mode() -> String:
	return str(debug_launch_mode_option.get_selected_metadata())

func _get_debug_room_type() -> String:
	return str(debug_room_type_option.get_selected_metadata())

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
	_set_panel_state(meta_panel, false)

func _on_return_to_menu_requested(open_meta_menu: bool = false) -> void:
	if _active_game != null and is_instance_valid(_active_game):
		_active_game.queue_free()
	_active_game = null
	_refresh_menu_state()
	if open_meta_menu:
		_set_panel_state(home_panel, false)
		_set_panel_state(menu_panel, false)
		_set_panel_state(settings_panel, false)
		_set_panel_state(meta_panel, true)
		_refresh_meta_panel("")
		call_deferred("_focus_meta_panel")
		return
	if _setup_mode == "encounter_builder":
		_open_setup_panel("encounter_builder")
		return
	_open_home_panel()

func _on_setup_back_button_pressed() -> void:
	_play_ui_click()
	_open_home_panel()

func _open_home_panel() -> void:
	_refresh_menu_state()
	_refresh_home_panel()
	_set_panel_state(menu_panel, false)
	_set_panel_state(settings_panel, false)
	_set_panel_state(meta_panel, false)
	_set_panel_state(home_panel, true)
	call_deferred("_focus_home_panel")

func _open_setup_panel(mode: String) -> void:
	_setup_mode = mode
	debug_mode_check.button_pressed = mode == "debug" or mode == "encounter_builder"
	_refresh_debug_room_objective_options()
	if mode == "encounter_builder":
		_select_string_option_by_metadata(debug_launch_mode_option, "single_room")
	_refresh_menu_state()
	_set_panel_state(home_panel, false)
	_set_panel_state(settings_panel, false)
	_set_panel_state(meta_panel, false)
	_set_panel_state(menu_panel, true)
	call_deferred("_focus_menu_panel")

func _on_meta_button_pressed() -> void:
	_play_ui_click()
	_return_panel = "setup"
	_set_panel_state(home_panel, false)
	_set_panel_state(menu_panel, false)
	_set_panel_state(settings_panel, false)
	_set_panel_state(meta_panel, true)
	_refresh_meta_panel("")
	call_deferred("_focus_meta_panel")

func _on_reset_profile_button_pressed() -> void:
	_play_ui_click()
	ProfileState.reset_profile()
	_refresh_menu_state()

func _on_unlock_button_pressed(index: int) -> void:
	if index < 0 or index >= _meta_unlocks.size():
		return
	_play_ui_click()
	var unlock: Dictionary = _meta_unlocks[index]
	var result := ProfileState.purchase_unlock(str(unlock.get("id", "")))
	var extra_text := str(result.get("summary", ""))
	_refresh_menu_state()
	_refresh_meta_panel(extra_text)

func _on_unlock_button_1_pressed() -> void:
	_on_unlock_button_pressed(0)

func _on_unlock_button_2_pressed() -> void:
	_on_unlock_button_pressed(1)

func _on_unlock_button_3_pressed() -> void:
	_on_unlock_button_pressed(2)

func _on_unlock_button_4_pressed() -> void:
	_on_unlock_button_pressed(3)

func _on_meta_back_button_pressed() -> void:
	_play_ui_click()
	_set_panel_state(meta_panel, false)
	_restore_return_panel()

func _on_settings_aim_mode_selected(selected_index: int, player_index: int) -> void:
	if player_index < 0 or player_index >= _player_aim_modes.size() or player_index >= _settings_options.size():
		return
	_play_ui_click()
	_player_aim_modes[player_index] = int(_settings_options[player_index].get_item_metadata(selected_index))
	_refresh_settings_panel()

func _on_settings_screen_effect_selected(selected_index: int) -> void:
	if settings_screen_effect_option == null:
		return
	_play_ui_click()
	ProfileState.set_screen_effect_level(str(settings_screen_effect_option.get_item_metadata(selected_index)))
	_refresh_settings_panel()

func _on_settings_back_button_pressed() -> void:
	_play_ui_click()
	_set_panel_state(settings_panel, false)
	_restore_return_panel()

func _restore_return_panel() -> void:
	if _return_panel == "setup":
		_refresh_menu_state()
		_set_panel_state(home_panel, false)
		_set_panel_state(menu_panel, true)
		call_deferred("_focus_menu_panel")
		return
	_open_home_panel()

func _refresh_home_panel() -> void:
	var available_unlocks: int = ProfileState.get_available_unlocks().size()
	var run_mode_name := run_mode_option.get_item_text(run_mode_option.selected)
	home_status_label.text = "%s\nCurrent Run Mode: %s\nScreen Effects: %s\nAvailable Unlocks: %d" % [
		ProfileState.get_profile_summary_text(),
		run_mode_name,
		ProfileState.get_screen_effect_level().capitalize(),
		available_unlocks,
	]

func _refresh_setup_copy() -> void:
	if _setup_mode == "encounter_builder":
		setup_title_label.text = "Encounter Builder"
		setup_subtitle_label.text = "Pick one room, one layout, and one modifier combination. The test ends after that encounter."
		return
	if _setup_mode == "debug":
		setup_title_label.text = "Debug Setup"
		setup_subtitle_label.text = "Configure a full run or jump straight into a single room."
		return
	setup_title_label.text = "Run Setup"
	setup_subtitle_label.text = "Choose players, controls, and run mode before the run starts."

func _refresh_meta_panel(extra_text: String) -> void:
	_meta_unlocks = ProfileState.get_available_unlocks()
	var header := "%s\nUnlocks add new run upgrades to future reward and shop pools." % ProfileState.get_profile_summary_text()
	if not extra_text.is_empty():
		header = "%s\n\n%s" % [header, extra_text]
	meta_status_label.text = header
	_configure_unlock_button(unlock_button_1, _meta_unlocks[0] if _meta_unlocks.size() > 0 else {})
	_configure_unlock_button(unlock_button_2, _meta_unlocks[1] if _meta_unlocks.size() > 1 else {})
	_configure_unlock_button(unlock_button_3, _meta_unlocks[2] if _meta_unlocks.size() > 2 else {})
	_configure_unlock_button(unlock_button_4, _meta_unlocks[3] if _meta_unlocks.size() > 3 else {})

func _configure_unlock_button(button: Button, unlock: Dictionary) -> void:
	if unlock.is_empty():
		button.visible = false
		button.disabled = true
		return

	button.visible = true
	button.disabled = int(unlock.get("cost", 0)) > ProfileState.meta_gold
	button.text = "%s\n%s\nCost: %d Meta Gold" % [
		str(unlock.get("name", "Unlock")),
		str(unlock.get("description", "")),
		int(unlock.get("cost", 0)),
	]

func _play_ui_click() -> void:
	if sfx_engine != null:
		sfx_engine.play_ui_click()

func _register_button_animations() -> void:
	var controls := [
		home_play_button,
		home_meta_button,
		home_settings_button,
		home_debug_button,
		player_count_option,
		run_mode_option,
		player_1_control_option,
		player_2_control_option,
		player_3_control_option,
		player_4_control_option,
		debug_mode_check,
		debug_launch_mode_option,
		debug_primary_option,
		debug_secondary_option,
		debug_starting_gold_spinbox,
		debug_room_type_option,
		debug_room_objective_option,
		debug_modifier_option,
		debug_layout_option,
		debug_step_spinbox,
		setup_back_button,
		settings_button,
		meta_button,
		reset_profile_button,
		start_button,
		settings_screen_effect_option,
		settings_player_1_option,
		settings_player_2_option,
		settings_player_3_option,
		settings_player_4_option,
		settings_back_button,
		unlock_button_1,
		unlock_button_2,
		unlock_button_3,
		unlock_button_4,
		meta_back_button,
	]
	for control in controls:
		_register_button_animation(control)

func _configure_menu_focus() -> void:
	var controls := [
		home_play_button,
		home_meta_button,
		home_settings_button,
		home_debug_button,
		player_count_option,
		run_mode_option,
		player_1_control_option,
		player_2_control_option,
		player_3_control_option,
		player_4_control_option,
		debug_mode_check,
		debug_launch_mode_option,
		debug_primary_option,
		debug_secondary_option,
		debug_starting_gold_spinbox,
		debug_room_type_option,
		debug_room_objective_option,
		debug_modifier_option,
		debug_layout_option,
		debug_step_spinbox,
		setup_back_button,
		settings_button,
		meta_button,
		reset_profile_button,
		start_button,
		settings_screen_effect_option,
		settings_player_1_option,
		settings_player_2_option,
		settings_player_3_option,
		settings_player_4_option,
		settings_back_button,
		unlock_button_1,
		unlock_button_2,
		unlock_button_3,
		unlock_button_4,
		meta_back_button,
	]
	for control in controls:
		if control == null:
			continue
		control.focus_mode = Control.FOCUS_ALL

func _focus_menu_panel() -> void:
	if _setup_mode == "encounter_builder":
		debug_room_type_option.grab_focus()
		return
	if debug_mode_check.button_pressed and _get_debug_launch_mode() == "single_room":
		debug_room_type_option.grab_focus()
		return
	if debug_mode_check.button_pressed:
		debug_launch_mode_option.grab_focus()
		return
	run_mode_option.grab_focus()

func _focus_home_panel() -> void:
	home_play_button.grab_focus()

func _focus_meta_panel() -> void:
	if unlock_button_1.visible and not unlock_button_1.disabled:
		unlock_button_1.grab_focus()
		return
	meta_back_button.grab_focus()

func _focus_settings_panel() -> void:
	if settings_screen_effect_row.visible:
		settings_screen_effect_option.grab_focus()
		return
	var settings_slot_count := mini(_settings_rows.size(), _settings_options.size())
	for index in range(settings_slot_count):
		if _settings_rows[index].visible:
			_settings_options[index].grab_focus()
			return
	settings_back_button.grab_focus()

func _register_button_animation(control: Control) -> void:
	if control == null:
		return
	control.pivot_offset = control.size * 0.5
	control.mouse_entered.connect(_on_button_hovered.bind(control))
	control.mouse_exited.connect(_on_button_unhovered.bind(control))
	var button := control as BaseButton
	if button != null:
		button.button_down.connect(_on_button_pressed.bind(control))
		button.button_up.connect(_on_button_released.bind(control))

func _on_button_hovered(control: Control) -> void:
	_animate_button_scale(control, Vector2.ONE * 1.04, 0.12)

func _on_button_unhovered(control: Control) -> void:
	_animate_button_scale(control, Vector2.ONE, 0.12)

func _on_button_pressed(control: Control) -> void:
	_animate_button_scale(control, Vector2.ONE * 0.97, 0.06)

func _on_button_released(control: Control) -> void:
	_animate_button_scale(control, Vector2.ONE * 1.03, 0.08)

func _animate_button_scale(control: Control, target_scale: Vector2, duration: float) -> void:
	if control == null:
		return
	var tween := create_tween()
	tween.tween_property(control, "scale", target_scale, duration)

func _set_panel_state(panel: Control, should_show: bool) -> void:
	if panel == null:
		return
	if not _panel_base_positions.has(panel):
		_panel_base_positions[panel] = panel.position
	var base_position: Vector2 = _panel_base_positions[panel]
	if should_show:
		panel.visible = true
		panel.position = base_position + Vector2(0.0, 16.0)
		panel.modulate.a = 0.0
		var tween_in := create_tween()
		tween_in.set_parallel(true)
		tween_in.tween_property(panel, "position", base_position, 0.18)
		tween_in.tween_property(panel, "modulate:a", 1.0, 0.18)
		return
	if not panel.visible:
		return
	var tween_out := create_tween()
	tween_out.set_parallel(true)
	tween_out.tween_property(panel, "position", base_position + Vector2(0.0, 12.0), 0.14)
	tween_out.tween_property(panel, "modulate:a", 0.0, 0.14)
	tween_out.set_parallel(false)
	tween_out.tween_callback(func() -> void:
		panel.visible = false
		panel.position = base_position
		panel.modulate.a = 1.0
	)
