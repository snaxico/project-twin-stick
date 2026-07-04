extends Control

const PlayerConfigData = preload("res://scripts/player/PlayerConfig.gd")
const AbilityRegistryData = preload("res://scripts/game/AbilityRegistry.gd")
const HudPaletteData = preload("res://scripts/game/HudPalette.gd")
const IconFactoryData = preload("res://scripts/ui/IconFactory.gd")
const AudioBusConfigData = preload("res://scripts/juice/AudioBusConfig.gd")
const EncyclopediaUIData = preload("res://scripts/ui/EncyclopediaUI.gd")
const RUN_FLOW_SCENE = preload("res://scenes/ui/RunFlow.tscn")
const MUTATIONS_DATA_PATH := "res://data/mutations.json"
const MODIFIERS_DATA_PATH := "res://data/modifiers.json"
const INPUT_BINDINGS_PATH := "user://input_bindings.cfg"
const VIDEO_SETTINGS_PATH := "user://video_settings.cfg"
const AUDIO_SETTINGS_PATH := "user://audio_settings.cfg"
const INPUT_BINDING_ACTIONS := [
	{"label": "Move Left", "suffix": "move_left"},
	{"label": "Move Right", "suffix": "move_right"},
	{"label": "Move Up", "suffix": "move_up"},
	{"label": "Move Down", "suffix": "move_down"},
	{"label": "Aim Left", "suffix": "aim_left"},
	{"label": "Aim Right", "suffix": "aim_right"},
	{"label": "Aim Up", "suffix": "aim_up"},
	{"label": "Aim Down", "suffix": "aim_down"},
	{"label": "Fire", "suffix": "fire"},
	{"label": "Ability 1 A", "suffix": "ability_1"},
	{"label": "Ability 2 X", "suffix": "ability_2"},
	{"label": "Ability 3 Y", "suffix": "ability_3"},
	{"label": "Ability 4 B", "suffix": "ability_4"},
]
const MENU_BINDING_ACTIONS := [
	{"label": "Menu Accept", "action": "ui_accept"},
	{"label": "Menu Back", "action": "ui_cancel"},
	{"label": "Debug Overlay", "action": "debug_overlay_toggle"},
]

@onready var game_container: Control = $GameContainer
@onready var sfx_engine = $SfxEngine
@onready var home_panel: Panel = $HomePanel
@onready var home_status_label: Label = $HomePanel/MarginContainer/HomeLayout/HomeStatusLabel
@onready var home_play_button: Button = $HomePanel/MarginContainer/HomeLayout/PlayButton
@onready var home_meta_button: Button = $HomePanel/MarginContainer/HomeLayout/MetaButton
@onready var home_settings_button: Button = $HomePanel/MarginContainer/HomeLayout/SettingsButton
@onready var home_debug_button: Button = $HomePanel/MarginContainer/HomeLayout/DebugButton
@onready var menu_panel: Panel = $MenuPanel
@onready var menu_scroll: ScrollContainer = $MenuPanel/MarginContainer/MenuScroll
@onready var menu_layout: VBoxContainer = $MenuPanel/MarginContainer/MenuScroll/MenuLayout
@onready var setup_title_label: Label = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/Title
@onready var setup_subtitle_label: Label = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/Subtitle
@onready var player_count_option: OptionButton = $MenuPanel/MarginContainer/MenuScroll/MenuLayout/PlayerCountRow/PlayerCountOption
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
@onready var settings_layout: VBoxContainer = $SettingsPanel/MarginContainer/SettingsLayout
@onready var settings_detail_label: Label = $SettingsPanel/MarginContainer/SettingsLayout/SettingsDetail
@onready var meta_panel: Panel = $MetaPanel
@onready var meta_layout: VBoxContainer = $MetaPanel/MarginContainer/MetaLayout
@onready var meta_status_label: Label = $MetaPanel/MarginContainer/MetaLayout/MetaStatusLabel
@onready var meta_back_button: Button = $MetaPanel/MarginContainer/MetaLayout/MetaBackButton

var _active_game = null
var _player_tints := [
	Color(0.25, 1.0, 0.3, 1.0),
	Color(1.0, 0.2, 0.8, 1.0),
]
var _mutation_definitions: Array = []
var _debug_mutation_toggles: Array = []
var _modifier_definitions: Array = []
var _debug_modifier_toggles: Array = []
var _debug_perf_option: OptionButton = null
var _debug_perf_button: Button = null
var _home_encyclopedia_button: Button = null
var _setup_mode: String = "play"
var _ability_registry = AbilityRegistryData.new()
var _class_rows: Array = []
var _weapon_rows: Array = []
var _ability_rows: Array = []
var _settings_binding_buttons: Dictionary = {}
var _settings_return_panel: Control = null
var _meta_return_panel: Control = null
var _settings_vsync_check: CheckBox = null
var _settings_audio_sliders: Dictionary = {}
var _loadout_columns: HBoxContainer = null
var _pending_binding_action := ""
var _pending_binding_kind := ""
var _pending_binding_button: Button = null
var _default_input_events: Dictionary = {}

func _ready() -> void:
	_ensure_default_controller_bindings()
	_ensure_debug_input_binding()
	_cache_default_input_events()
	_load_input_bindings()
	_load_video_settings()
	_load_audio_settings()
	_load_mutation_definitions()
	_load_modifier_definitions()
	_populate_menu()
	_configure_aim_mode_options()
	_configure_setup_panel_layout()
	home_play_button.pressed.connect(_on_home_play_button_pressed)
	home_meta_button.pressed.connect(_open_meta_from_home)
	home_settings_button.pressed.connect(_open_settings_from_home)
	home_debug_button.pressed.connect(_on_home_debug_button_pressed)
	_add_home_encyclopedia_button()
	player_count_option.item_selected.connect(_refresh_menu_state)
	debug_room_type_option.item_selected.connect(_refresh_menu_state)
	debug_room_objective_option.item_selected.connect(_refresh_menu_state)
	setup_back_button.pressed.connect(_on_setup_back_button_pressed)
	settings_button.pressed.connect(_open_settings_from_setup)
	meta_button.pressed.connect(_open_meta_from_setup)
	reset_profile_button.pressed.connect(_on_reset_profile_pressed)
	settings_back_button.pressed.connect(_on_settings_back_pressed)
	meta_back_button.pressed.connect(_on_meta_back_pressed)
	start_button.pressed.connect(_on_start_pressed)
	_configure_meta_panel()
	_wire_ui_click_sfx(self)
	home_meta_button.visible = true
	home_settings_button.visible = true
	meta_panel.visible = false
	meta_button.visible = true
	settings_button.visible = true
	reset_profile_button.visible = true
	player_3_control_row.visible = false
	player_4_control_row.visible = false
	debug_mode_check.visible = false
	debug_launch_mode_row.visible = false
	debug_room_modifiers_row.visible = false
	debug_modifier_row.visible = false
	debug_layout_row.visible = false
	debug_primary_row.visible = false
	debug_step_row.visible = false
	settings_player_3_row.visible = false
	settings_player_4_row.visible = false
	_configure_settings_panel()
	home_debug_button.text = "Encounter Builder"
	home_debug_button.visible = _is_debug_menu_enabled()
	home_panel.visible = true
	menu_panel.visible = false
	settings_panel.visible = false
	_set_music_context("menu")
	_refresh_menu_state()
	_refresh_home_panel()
	call_deferred("_focus_home_panel")

func _input(event: InputEvent) -> void:
	if _pending_binding_action.is_empty():
		return
	if _try_capture_binding_event(event):
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if settings_panel.visible:
		if not _pending_binding_action.is_empty():
			_cancel_pending_binding()
		else:
			_on_settings_back_pressed()
		get_viewport().set_input_as_handled()
		return
	if meta_panel.visible:
		_on_meta_back_pressed()
		get_viewport().set_input_as_handled()
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
	_populate_control_option(player_1_control_option, "gamepad")
	_populate_player_2_control_option()
	_populate_profile_option(debug_primary_option, [{"label": "Rifle", "value": "rifle"}], "rifle")
	_populate_profile_option(debug_secondary_option, [
		{"label": "Warden", "value": "warden"},
		{"label": "Hydra", "value": "hydra"},
		{"label": "Hive", "value": "hive"},
		{"label": "Pulsar", "value": "pulsar"},
		{"label": "Charger", "value": "elite_charger"},
		{"label": "Spitter", "value": "elite_spitter"},
		{"label": "Support", "value": "elite_support"},
	], "warden")
	_populate_profile_option(debug_room_type_option, [
		{"label": "Combat", "value": "combat"},
		{"label": "Champion", "value": "boss"},
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
	_build_class_rows()
	_build_weapon_rows()
	_build_ability_rows()

func _configure_setup_panel_layout() -> void:
	menu_panel.anchor_left = 0.0
	menu_panel.anchor_top = 0.0
	menu_panel.anchor_right = 1.0
	menu_panel.anchor_bottom = 1.0
	menu_panel.offset_left = 30.0
	menu_panel.offset_top = 18.0
	menu_panel.offset_right = -30.0
	menu_panel.offset_bottom = -18.0
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_layout.add_theme_constant_override("separation", 7)
	setup_title_label.add_theme_font_size_override("font_size", 22)
	setup_subtitle_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.custom_minimum_size = Vector2.ZERO

func _add_home_encyclopedia_button() -> void:
	if _home_encyclopedia_button != null and is_instance_valid(_home_encyclopedia_button):
		return
	_home_encyclopedia_button = Button.new()
	_home_encyclopedia_button.name = "EncyclopediaButton"
	_home_encyclopedia_button.text = "Encyclopedia"
	_home_encyclopedia_button.pressed.connect(_open_encyclopedia_overlay)
	home_debug_button.get_parent().add_child(_home_encyclopedia_button)
	home_debug_button.get_parent().move_child(_home_encyclopedia_button, home_settings_button.get_index())

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

func _populate_player_2_control_option() -> void:
	_populate_control_option(player_2_control_option, "gamepad")

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
	player_2_control_option.get_parent().visible = player_count > 1
	debug_primary_row.visible = false
	debug_secondary_row.visible = encounter_builder_mode and str(debug_room_type_option.get_selected_metadata()) == "boss"
	debug_room_type_row.visible = encounter_builder_mode
	debug_room_objective_row.visible = encounter_builder_mode and str(debug_room_type_option.get_selected_metadata()) == "combat"
	debug_step_row.visible = false
	debug_room_modifiers_row.visible = encounter_builder_mode
	debug_modifier_row.visible = false
	debug_layout_row.visible = encounter_builder_mode and str(debug_room_type_option.get_selected_metadata()) == "combat"
	var perf_row := menu_layout.get_node_or_null("PerfScenarioRow")
	if perf_row != null:
		perf_row.visible = encounter_builder_mode and _is_debug_menu_enabled()
	var launch_cheat_row := menu_layout.get_node_or_null("LaunchCheatRow")
	if launch_cheat_row != null:
		launch_cheat_row.visible = false
	settings_player_2_row.visible = false
	setup_title_label.text = "Encounter Builder" if encounter_builder_mode else "Run Setup"
	setup_subtitle_label.text = "Pick one room, one objective, and iterate fast." if encounter_builder_mode else "Choose players, controls, and loadout before the run starts."
	var summary_lines: Array = []
	summary_lines.append("Players: %d" % player_count)
	if not encounter_builder_mode:
		summary_lines.append("Run: room choices, champion checks, mutation snowball.")
	else:
		summary_lines.append("Encounter: %s" % debug_room_type_option.get_item_text(debug_room_type_option.selected))
		if debug_secondary_row.visible:
			summary_lines.append("Champion: %s" % debug_secondary_option.get_item_text(debug_secondary_option.selected))
		if debug_room_objective_row.visible:
			summary_lines.append("Objective: %s" % debug_room_objective_option.get_item_text(debug_room_objective_option.selected))
		if debug_layout_row.visible:
			summary_lines.append("Enemy Mix: %s" % debug_layout_option.get_item_text(debug_layout_option.selected))
		summary_lines.append("Room Modifiers: %d" % _get_selected_room_modifiers().size())
	summary_lines.append("Pick class, class weapon, and three abilities; the ultimate fills B.")
	status_label.text = "\n".join(summary_lines)
	start_button.text = "Launch Encounter" if encounter_builder_mode else "Start Run"
	for row_index in range(_class_rows.size()):
		var row_data: Dictionary = _class_rows[row_index]
		var container: Control = row_data["container"]
		container.visible = row_index < player_count
		_sync_class_row_buttons(row_index)
	for row_index in range(_ability_rows.size()):
		var row_data: Dictionary = _ability_rows[row_index]
		var container: Control = row_data["container"]
		container.visible = row_index < player_count
		_sync_ability_row_buttons(row_index)
	for row_index in range(_weapon_rows.size()):
		var row_data: Dictionary = _weapon_rows[row_index]
		var container: Control = row_data["container"]
		container.visible = row_index < player_count
		_sync_weapon_row_buttons(row_index)
	_sync_loadout_columns(player_count)
	start_button.disabled = not _can_start_run(player_count)
	_refresh_home_panel()

func get_selected_player_count() -> int:
	return player_count_option.selected + 1

func _on_debug_step_changed(_value: float) -> void:
	_refresh_menu_state()

func _get_debug_start_level() -> int:
	return 0

func _get_debug_start_xp() -> int:
	return 0

func _on_start_pressed() -> void:
	_launch_game(_build_player_configs())

func _on_home_play_button_pressed() -> void:
	_open_setup_panel("play")

func _on_home_debug_button_pressed() -> void:
	_open_setup_panel("encounter_builder")

func _build_player_configs() -> Array:
	var configs: Array = []
	var control_options := [player_1_control_option, player_2_control_option]
	var aim_options := [settings_player_1_option, settings_player_2_option]
	for index in range(get_selected_player_count()):
		var control_source := str(control_options[index].get_selected_metadata())
		var config = PlayerConfigData.new(index + 1, control_source, _player_tints[index])
		config.aim_mode = str(aim_options[index].get_selected_metadata()) if index < aim_options.size() else "auto"
		configs.append(config)
	return configs

func _build_debug_start_options() -> Dictionary:
	var options := {
		"enabled": _setup_mode == "encounter_builder",
		"launch_mode": "single_room" if _setup_mode == "encounter_builder" else "normal_run",
		"primary_profile": "rifle",
		"secondary_profile": "mixed",
		"enemy_mix": "mixed",
		"player_classes": _build_player_class_selection(),
		"player_weapons": _build_player_weapon_selection(),
		"player_abilities": _build_player_ability_selection(),
	}
	if not options["enabled"]:
		return options
	options["room_type"] = str(debug_room_type_option.get_selected_metadata())
	options["room_objective"] = str(debug_room_objective_option.get_selected_metadata())
	options["enemy_mix"] = str(debug_layout_option.get_selected_metadata())
	if str(options["room_type"]) == "boss":
		options["boss_type"] = str(debug_secondary_option.get_selected_metadata())
	options["modifiers"] = _get_selected_room_modifiers()
	return options

func _launch_game(player_configs: Array) -> void:
	if _active_game != null and is_instance_valid(_active_game):
		_active_game.queue_free()
	_set_music_context("map")
	RunState.start_new_run(player_configs, _build_debug_start_options())
	_active_game = RUN_FLOW_SCENE.instantiate()
	_active_game.return_to_menu_requested.connect(_on_return_to_menu_requested)
	game_container.add_child(_active_game)
	_set_panel_state(home_panel, false)
	_set_panel_state(menu_panel, false)
	_set_panel_state(settings_panel, false)
	_set_panel_state(meta_panel, false)

func _on_return_to_menu_requested(_open_meta_menu: bool = false) -> void:
	if _active_game != null and is_instance_valid(_active_game):
		_active_game.queue_free()
	_active_game = null
	if _setup_mode == "encounter_builder":
		_open_setup_panel("encounter_builder")
		return
	if _open_meta_menu:
		_open_meta_panel(home_panel)
		return
	_open_home_panel()

func _on_setup_back_button_pressed() -> void:
	_open_home_panel()

func _open_home_panel() -> void:
	_set_music_context("menu")
	_refresh_menu_state()
	_set_panel_state(menu_panel, false)
	_set_panel_state(settings_panel, false)
	_set_panel_state(meta_panel, false)
	_set_panel_state(home_panel, true)
	call_deferred("_focus_home_panel")

func _open_setup_panel(mode: String) -> void:
	_setup_mode = mode
	_set_music_context("menu")
	_refresh_menu_state()
	_set_panel_state(home_panel, false)
	_set_panel_state(settings_panel, false)
	_set_panel_state(meta_panel, false)
	_set_panel_state(menu_panel, true)
	call_deferred("_focus_menu_panel")

func _open_settings_from_home() -> void:
	_open_settings_panel(home_panel)

func _open_settings_from_setup() -> void:
	_open_settings_panel(menu_panel)

func _open_meta_from_home() -> void:
	_open_meta_panel(home_panel)

func _open_meta_from_setup() -> void:
	_open_meta_panel(menu_panel)

func _open_encyclopedia_overlay() -> void:
	var existing := get_node_or_null("EncyclopediaUI")
	if existing != null:
		existing.queue_free()
	var encyclopedia := EncyclopediaUIData.new()
	encyclopedia.name = "EncyclopediaUI"
	add_child(encyclopedia)

func _open_settings_panel(return_panel: Control) -> void:
	_set_music_context("menu")
	_settings_return_panel = return_panel
	_cancel_pending_binding()
	_refresh_binding_buttons()
	_set_panel_state(home_panel, false)
	_set_panel_state(menu_panel, false)
	_set_panel_state(meta_panel, false)
	_set_panel_state(settings_panel, true)
	settings_back_button.grab_focus()

func _on_settings_back_pressed() -> void:
	_cancel_pending_binding()
	_set_panel_state(settings_panel, false)
	if _settings_return_panel == menu_panel:
		_set_panel_state(menu_panel, true)
		call_deferred("_focus_menu_panel")
	else:
		_set_panel_state(home_panel, true)
		call_deferred("_focus_home_panel")

func _open_meta_panel(return_panel: Control) -> void:
	_set_music_context("menu")
	_meta_return_panel = return_panel
	_rebuild_unlock_menu()
	_set_panel_state(home_panel, false)
	_set_panel_state(menu_panel, false)
	_set_panel_state(settings_panel, false)
	_set_panel_state(meta_panel, true)
	meta_back_button.grab_focus()

func _on_meta_back_pressed() -> void:
	_set_panel_state(meta_panel, false)
	_rebuild_loadout_rows()
	if _meta_return_panel == menu_panel:
		_set_panel_state(menu_panel, true)
		call_deferred("_focus_menu_panel")
	else:
		_set_panel_state(home_panel, true)
		call_deferred("_focus_home_panel")

func _on_reset_profile_pressed() -> void:
	if ProfileState != null:
		ProfileState.reset_profile()
	_rebuild_loadout_rows()
	_rebuild_unlock_menu()
	_refresh_menu_state()

func _configure_meta_panel() -> void:
	for child in meta_layout.get_children():
		if str(child.name).begins_with("UnlockButton"):
			meta_layout.remove_child(child)
			child.queue_free()
	meta_panel.anchor_left = 0.5
	meta_panel.anchor_top = 0.5
	meta_panel.anchor_right = 0.5
	meta_panel.anchor_bottom = 0.5
	meta_panel.offset_left = -380.0
	meta_panel.offset_top = -330.0
	meta_panel.offset_right = 380.0
	meta_panel.offset_bottom = 330.0
	if meta_layout.get_node_or_null("UnlockScroll") == null:
		var scroll := ScrollContainer.new()
		scroll.name = "UnlockScroll"
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size = Vector2(0.0, 430.0)
		meta_layout.add_child(scroll)
		meta_layout.move_child(scroll, meta_back_button.get_index())
		var list := VBoxContainer.new()
		list.name = "UnlockList"
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 8)
		scroll.add_child(list)
	var reset_button := meta_layout.get_node_or_null("MetaResetButton") as Button
	if reset_button == null:
		reset_button = Button.new()
		reset_button.name = "MetaResetButton"
		reset_button.text = "Reset Meta Profile"
		reset_button.pressed.connect(_on_reset_profile_pressed)
		meta_layout.add_child(reset_button)
		meta_layout.move_child(reset_button, meta_back_button.get_index())
		_wire_ui_click_sfx(reset_button)

func _rebuild_unlock_menu() -> void:
	if ProfileState == null:
		meta_status_label.text = "Profile unavailable."
		return
	var list := meta_layout.get_node_or_null("UnlockScroll/UnlockList") as VBoxContainer
	if list == null:
		return
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var locked_entries := ProfileState.get_locked_entries()
	locked_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var cost_compare := int(a.get("cost", 0)) - int(b.get("cost", 0))
		if cost_compare != 0:
			return cost_compare < 0
		return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0
	)
	meta_status_label.text = "Banked score: %d\nUnlocked: %d / %d" % [
		int(ProfileState.banked_score),
		ProfileState.unlocked_ids.size(),
		ProfileState.get_unlock_table().size(),
	]
	if locked_entries.is_empty():
		var complete_label := Label.new()
		complete_label.text = "All unlocks purchased."
		complete_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(complete_label)
		return
	for entry in locked_entries:
		list.add_child(_create_unlock_row(entry as Dictionary))

func _create_unlock_row(entry: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.105, 0.96)
	style.border_color = Color(0.26, 0.34, 0.46, 0.78)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	row.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	row.add_child(margin)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(text_box)
	var title := Label.new()
	title.text = "%s  |  %s" % [str(entry.get("name", "Unlock")), _format_name(str(entry.get("kind", "")))]
	title.add_theme_font_size_override("font_size", 14)
	text_box.add_child(title)
	var detail := Label.new()
	detail.text = "Adds this upgrade to future reward pools." if str(entry.get("kind", "")) == "mutation" else "Adds this item to future run pools."
	detail.add_theme_font_size_override("font_size", 11)
	detail.modulate = Color(0.78, 0.86, 0.94, 0.86)
	text_box.add_child(detail)
	var button := Button.new()
	var cost := int(entry.get("cost", 0))
	button.text = "%d" % cost
	button.custom_minimum_size = Vector2(92.0, 34.0)
	button.disabled = ProfileState == null or ProfileState.banked_score < cost
	button.tooltip_text = "Spend score to unlock permanently."
	button.pressed.connect(_on_unlock_pressed.bind(str(entry.get("id", ""))))
	layout.add_child(button)
	_wire_ui_click_sfx(row)
	return row

func _on_unlock_pressed(unlock_id: String) -> void:
	if ProfileState == null:
		return
	if ProfileState.unlock(unlock_id):
		_rebuild_loadout_rows()
		_rebuild_unlock_menu()
		_refresh_menu_state()

func _rebuild_loadout_rows() -> void:
	if _loadout_columns != null and is_instance_valid(_loadout_columns):
		for column in _loadout_columns.get_children():
			for child in column.get_children():
				column.remove_child(child)
				child.queue_free()
	_class_rows.clear()
	_weapon_rows.clear()
	_ability_rows.clear()
	_build_class_rows()
	_build_weapon_rows()
	_build_ability_rows()

func _refresh_home_panel() -> void:
	home_status_label.text = "V3 structure rework\nRun: linear room choices + champion checks\nBanked score: %d\nTarget: 1-2 players only" % int(ProfileState.banked_score if ProfileState != null else 0)

func _focus_home_panel() -> void:
	if not is_inside_tree():
		return
	home_play_button.grab_focus()

func _focus_menu_panel() -> void:
	if not is_inside_tree():
		return
	if _setup_mode == "encounter_builder":
		debug_room_type_option.grab_focus()
	else:
		player_count_option.grab_focus()

func _set_panel_state(panel: Control, should_show: bool) -> void:
	panel.visible = should_show

func _configure_settings_panel() -> void:
	settings_panel.offset_left = -420.0
	settings_panel.offset_top = -360.0
	settings_panel.offset_right = 420.0
	settings_panel.offset_bottom = 360.0
	settings_detail_label.text = "Change display, gameplay keybindings, and controller bindings. Pick a Bind button, then press the next key, controller button, or controller axis direction."
	settings_screen_effect_option.get_parent().visible = false
	settings_player_1_row.visible = true
	settings_player_2_row.visible = true
	settings_player_3_row.visible = false
	settings_player_4_row.visible = false
	if settings_layout.get_node_or_null("BindingScroll") != null:
		return
	_add_video_settings_rows()
	_add_audio_settings_rows()
	var scroll := ScrollContainer.new()
	scroll.name = "BindingScroll"
	scroll.custom_minimum_size = Vector2(0.0, 430.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_layout.add_child(scroll)
	settings_layout.move_child(scroll, settings_back_button.get_index())
	var list := VBoxContainer.new()
	list.name = "BindingList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	_add_settings_section(list, "Menu")
	for entry in MENU_BINDING_ACTIONS:
		_add_binding_row(list, str(entry["label"]), str(entry["action"]))
	for player_id in [1, 2]:
		_add_settings_section(list, "Player %d Gameplay" % player_id)
		for entry in INPUT_BINDING_ACTIONS:
			_add_binding_row(list, str(entry["label"]), "p%d_%s" % [player_id, str(entry["suffix"])])
	var reset_button := Button.new()
	reset_button.name = "ResetBindingsButton"
	reset_button.text = "Reset Bindings to Defaults"
	reset_button.pressed.connect(_reset_input_bindings_to_defaults)
	settings_layout.add_child(reset_button)
	settings_layout.move_child(reset_button, settings_back_button.get_index())
	_wire_ui_click_sfx(reset_button)
	_refresh_binding_buttons()

func _configure_aim_mode_options() -> void:
	for option in [settings_player_1_option, settings_player_2_option]:
		if option == null:
			continue
		_populate_profile_option(option, [
			{"label": "Auto + Manual", "value": "auto"},
			{"label": "Movement", "value": "movement"},
			{"label": "Manual Only", "value": "manual"},
		], "auto")

func _add_video_settings_rows() -> void:
	var section_label := Label.new()
	section_label.text = "Display"
	section_label.add_theme_font_size_override("font_size", 15)
	section_label.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0, 0.92))
	settings_layout.add_child(section_label)
	settings_layout.move_child(section_label, settings_back_button.get_index())
	var row := HBoxContainer.new()
	row.name = "VSyncRow"
	row.add_theme_constant_override("separation", 12)
	settings_layout.add_child(row)
	settings_layout.move_child(row, settings_back_button.get_index())
	var label := Label.new()
	label.text = "VSync"
	label.custom_minimum_size = Vector2(160.0, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	_settings_vsync_check = CheckBox.new()
	_settings_vsync_check.button_pressed = _is_vsync_enabled()
	_settings_vsync_check.text = "On" if _settings_vsync_check.button_pressed else "Off"
	_settings_vsync_check.toggled.connect(_on_vsync_toggled)
	row.add_child(_settings_vsync_check)

func _add_audio_settings_rows() -> void:
	var section_label := Label.new()
	section_label.text = "Audio"
	section_label.add_theme_font_size_override("font_size", 15)
	section_label.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0, 0.92))
	settings_layout.add_child(section_label)
	settings_layout.move_child(section_label, settings_back_button.get_index())
	_add_audio_slider_row("Master", AudioBusConfigData.MASTER_BUS)
	_add_audio_slider_row("Music", AudioBusConfigData.MUSIC_BUS)
	_add_audio_slider_row("SFX", AudioBusConfigData.SFX_BUS)

func _add_audio_slider_row(label_text: String, bus_name: String) -> void:
	var row := HBoxContainer.new()
	row.name = "%sVolumeRow" % bus_name
	row.add_theme_constant_override("separation", 12)
	settings_layout.add_child(row)
	settings_layout.move_child(row, settings_back_button.get_index())
	var label := Label.new()
	label.text = "%s Volume" % label_text
	label.custom_minimum_size = Vector2(160.0, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(220.0, 0.0)
	slider.value = AudioBusConfigData.get_bus_volume(bus_name, _get_default_audio_volume(bus_name))
	slider.value_changed.connect(_on_audio_volume_changed.bind(bus_name))
	row.add_child(slider)
	_settings_audio_sliders[bus_name] = slider

func _add_settings_section(parent: VBoxContainer, title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0, 0.92))
	parent.add_child(label)

func _add_binding_row(parent: VBoxContainer, label_text: String, action: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(160.0, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var keyboard_button := Button.new()
	keyboard_button.custom_minimum_size = Vector2(180.0, 32.0)
	keyboard_button.pressed.connect(_begin_binding.bind(action, "keyboard", keyboard_button))
	row.add_child(keyboard_button)
	var controller_button := Button.new()
	controller_button.custom_minimum_size = Vector2(180.0, 32.0)
	controller_button.pressed.connect(_begin_binding.bind(action, "controller", controller_button))
	row.add_child(controller_button)
	_wire_ui_click_sfx(row)
	_settings_binding_buttons[action] = {
		"keyboard": keyboard_button,
		"controller": controller_button,
	}

func _begin_binding(action: String, kind: String, button: Button) -> void:
	_pending_binding_action = action
	_pending_binding_kind = kind
	_pending_binding_button = button
	button.text = "Press input..."

func _cancel_pending_binding() -> void:
	_pending_binding_action = ""
	_pending_binding_kind = ""
	_pending_binding_button = null
	_refresh_binding_buttons()

func _try_capture_binding_event(event: InputEvent) -> bool:
	if _pending_binding_action.is_empty():
		return false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return false
		if key_event.keycode == KEY_ESCAPE:
			_cancel_pending_binding()
			return true
		if _pending_binding_kind != "keyboard":
			return false
		var stored_key := key_event.duplicate() as InputEventKey
		stored_key.pressed = false
		stored_key.device = -1
		_apply_binding_event(_pending_binding_action, _pending_binding_kind, stored_key)
		return true
	if event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		if not button_event.pressed or _pending_binding_kind != "controller":
			return false
		var stored_button := InputEventJoypadButton.new()
		stored_button.device = -1
		stored_button.button_index = button_event.button_index
		_apply_binding_event(_pending_binding_action, _pending_binding_kind, stored_button)
		return true
	if event is InputEventJoypadMotion:
		var motion_event := event as InputEventJoypadMotion
		if absf(motion_event.axis_value) < 0.6 or _pending_binding_kind != "controller":
			return false
		var stored_motion := InputEventJoypadMotion.new()
		stored_motion.device = -1
		stored_motion.axis = motion_event.axis
		stored_motion.axis_value = 1.0 if motion_event.axis_value > 0.0 else -1.0
		_apply_binding_event(_pending_binding_action, _pending_binding_kind, stored_motion)
		return true
	return false

func _apply_binding_event(action: String, kind: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var preserved_events: Array = []
	for existing_event in InputMap.action_get_events(action):
		if _get_binding_kind(existing_event) != kind:
			preserved_events.append(existing_event)
	InputMap.action_erase_events(action)
	for preserved_event in preserved_events:
		InputMap.action_add_event(action, preserved_event)
	InputMap.action_add_event(action, event)
	_save_input_bindings()
	_cancel_pending_binding()

func _refresh_binding_buttons() -> void:
	for action in _settings_binding_buttons.keys():
		var buttons: Dictionary = _settings_binding_buttons[action]
		var keyboard_button: Button = buttons.get("keyboard", null)
		if keyboard_button != null:
			keyboard_button.text = "Key: %s" % _describe_binding(action, "keyboard")
		var controller_button: Button = buttons.get("controller", null)
		if controller_button != null:
			controller_button.text = "Pad: %s" % _describe_binding(action, "controller")

func _describe_binding(action: String, kind: String) -> String:
	for event in InputMap.action_get_events(action):
		if _get_binding_kind(event) == kind:
			return _describe_input_event(event)
	return "Unbound"

func _describe_input_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return OS.get_keycode_string(key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode)
	if event is InputEventJoypadButton:
		return _joy_button_name((event as InputEventJoypadButton).button_index)
	if event is InputEventJoypadMotion:
		var motion_event := event as InputEventJoypadMotion
		return "%s %s" % [_joy_axis_name(motion_event.axis), "+" if motion_event.axis_value > 0.0 else "-"]
	return event.as_text()

func _get_binding_kind(event: InputEvent) -> String:
	if event is InputEventKey:
		return "keyboard"
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return "controller"
	return "other"

func _is_player_2_action(action: String) -> bool:
	return action.begins_with("p2_")

func _is_debug_menu_enabled() -> bool:
	if OS.is_debug_build():
		return true
	for arg in OS.get_cmdline_user_args():
		if arg == "--debug-menu":
			return true
	return false

func _joy_button_name(button_index: int) -> String:
	var names := {
		JOY_BUTTON_A: "A",
		JOY_BUTTON_B: "B",
		JOY_BUTTON_X: "X",
		JOY_BUTTON_Y: "Y",
		JOY_BUTTON_BACK: "Back",
		JOY_BUTTON_START: "Start",
		JOY_BUTTON_LEFT_SHOULDER: "LB",
		JOY_BUTTON_RIGHT_SHOULDER: "RB",
		JOY_BUTTON_LEFT_STICK: "LS",
		JOY_BUTTON_RIGHT_STICK: "RS",
	}
	return str(names.get(button_index, "Button %d" % button_index))

func _joy_axis_name(axis: int) -> String:
	var names := {
		JOY_AXIS_LEFT_X: "Left X",
		JOY_AXIS_LEFT_Y: "Left Y",
		JOY_AXIS_RIGHT_X: "Right X",
		JOY_AXIS_RIGHT_Y: "Right Y",
		JOY_AXIS_TRIGGER_LEFT: "LT",
		JOY_AXIS_TRIGGER_RIGHT: "RT",
	}
	return str(names.get(axis, "Axis %d" % axis))

func _ensure_default_controller_bindings() -> void:
	for player_id in [1, 2]:
		_add_default_controller_motion("p%d_move_left" % player_id, JOY_AXIS_LEFT_X, -1.0)
		_add_default_controller_motion("p%d_move_right" % player_id, JOY_AXIS_LEFT_X, 1.0)
		_add_default_controller_motion("p%d_move_up" % player_id, JOY_AXIS_LEFT_Y, -1.0)
		_add_default_controller_motion("p%d_move_down" % player_id, JOY_AXIS_LEFT_Y, 1.0)
		_add_default_controller_motion("p%d_aim_left" % player_id, JOY_AXIS_RIGHT_X, -1.0)
		_add_default_controller_motion("p%d_aim_right" % player_id, JOY_AXIS_RIGHT_X, 1.0)
		_add_default_controller_motion("p%d_aim_up" % player_id, JOY_AXIS_RIGHT_Y, -1.0)
		_add_default_controller_motion("p%d_aim_down" % player_id, JOY_AXIS_RIGHT_Y, 1.0)
		_add_default_controller_button("p%d_fire" % player_id, JOY_BUTTON_RIGHT_SHOULDER)
		_add_default_controller_button("p%d_ability_1" % player_id, JOY_BUTTON_A)
		_add_default_controller_button("p%d_ability_2" % player_id, JOY_BUTTON_X)
		_add_default_controller_button("p%d_ability_3" % player_id, JOY_BUTTON_Y)
		_add_default_controller_button("p%d_ability_4" % player_id, JOY_BUTTON_B)

func _ensure_debug_input_binding() -> void:
	if not InputMap.has_action("debug_overlay_toggle"):
		InputMap.add_action("debug_overlay_toggle")
	if InputMap.action_get_events("debug_overlay_toggle").is_empty():
		var key_event := InputEventKey.new()
		key_event.keycode = KEY_F4
		key_event.physical_keycode = KEY_F4
		InputMap.action_add_event("debug_overlay_toggle", key_event)

func _add_default_controller_motion(action: String, axis: JoyAxis, axis_value: float) -> void:
	if _action_has_matching_controller_motion(action, axis, axis_value):
		return
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = axis_value
	InputMap.action_add_event(action, event)

func _add_default_controller_button(action: String, button_index: JoyButton) -> void:
	if _action_has_matching_controller_button(action, button_index):
		return
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button_index
	InputMap.action_add_event(action, event)

func _action_has_matching_controller_motion(action: String, axis: JoyAxis, axis_value: float) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion:
			var motion_event := event as InputEventJoypadMotion
			if motion_event.axis == axis and signf(motion_event.axis_value) == signf(axis_value):
				return true
	return false

func _action_has_matching_controller_button(action: String, button_index: JoyButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			var button_event := event as InputEventJoypadButton
			if button_event.button_index == button_index:
				return true
	return false

func _cache_default_input_events() -> void:
	_default_input_events.clear()
	for action in _get_editable_input_actions():
		_default_input_events[action] = _duplicate_input_events(InputMap.action_get_events(action))

func _get_editable_input_actions() -> Array:
	var actions: Array = []
	for entry in MENU_BINDING_ACTIONS:
		actions.append(str(entry["action"]))
	for player_id in [1, 2]:
		for entry in INPUT_BINDING_ACTIONS:
			actions.append("p%d_%s" % [player_id, str(entry["suffix"])])
	return actions

func _duplicate_input_events(events: Array) -> Array:
	var duplicated: Array = []
	for event in events:
		duplicated.append((event as InputEvent).duplicate())
	return duplicated

func _save_input_bindings() -> void:
	var config := ConfigFile.new()
	for action in _get_editable_input_actions():
		var encoded_events: Array = []
		var seen_events := {}
		for event in InputMap.action_get_events(action):
			var encoded_event := _encode_input_event(event)
			var encoded_key := JSON.stringify(encoded_event)
			if seen_events.has(encoded_key):
				continue
			seen_events[encoded_key] = true
			encoded_events.append(encoded_event)
		config.set_value("bindings", action, encoded_events)
	config.save(INPUT_BINDINGS_PATH)

func _load_input_bindings() -> void:
	var config := ConfigFile.new()
	if config.load(INPUT_BINDINGS_PATH) != OK:
		return
	for action in _get_editable_input_actions():
		if not config.has_section_key("bindings", action):
			continue
		var encoded_events: Array = config.get_value("bindings", action, []) as Array
		InputMap.action_erase_events(action)
		for encoded in encoded_events:
			var event := _decode_input_event(encoded as Dictionary)
			if event != null:
				InputMap.action_add_event(action, event)

func _reset_input_bindings_to_defaults() -> void:
	_cancel_pending_binding()
	for action in _get_editable_input_actions():
		InputMap.action_erase_events(action)
		for event in (_default_input_events.get(action, []) as Array):
			InputMap.action_add_event(action, (event as InputEvent).duplicate())
	_save_input_bindings()
	_refresh_binding_buttons()

func _load_video_settings() -> void:
	var config := ConfigFile.new()
	var enabled := true
	if config.load(VIDEO_SETTINGS_PATH) == OK:
		enabled = bool(config.get_value("display", "vsync_enabled", true))
	_apply_vsync(enabled)

func _load_audio_settings() -> void:
	AudioBusConfigData.ensure_audio_buses()
	var config := ConfigFile.new()
	var values := {
		AudioBusConfigData.MASTER_BUS: AudioBusConfigData.DEFAULT_MASTER_VOLUME,
		AudioBusConfigData.MUSIC_BUS: AudioBusConfigData.DEFAULT_MUSIC_VOLUME,
		AudioBusConfigData.SFX_BUS: AudioBusConfigData.DEFAULT_SFX_VOLUME,
	}
	if config.load(AUDIO_SETTINGS_PATH) == OK:
		for bus_name in values.keys():
			values[bus_name] = float(config.get_value("audio", str(bus_name).to_lower(), values[bus_name]))
	for bus_name in values.keys():
		AudioBusConfigData.set_bus_volume(str(bus_name), float(values[bus_name]))

func _save_video_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "vsync_enabled", _is_vsync_enabled())
	config.save(VIDEO_SETTINGS_PATH)

func _save_audio_settings() -> void:
	var config := ConfigFile.new()
	for bus_name in [AudioBusConfigData.MASTER_BUS, AudioBusConfigData.MUSIC_BUS, AudioBusConfigData.SFX_BUS]:
		config.set_value("audio", str(bus_name).to_lower(), AudioBusConfigData.get_bus_volume(bus_name, _get_default_audio_volume(bus_name)))
	config.save(AUDIO_SETTINGS_PATH)

func _on_vsync_toggled(enabled: bool) -> void:
	_apply_vsync(enabled)
	if _settings_vsync_check != null:
		_settings_vsync_check.text = "On" if enabled else "Off"
	_save_video_settings()

func _on_audio_volume_changed(value: float, bus_name: String) -> void:
	AudioBusConfigData.set_bus_volume(bus_name, value)
	_save_audio_settings()

func _apply_vsync(enabled: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)

func _is_vsync_enabled() -> bool:
	return DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED

func _get_default_audio_volume(bus_name: String) -> float:
	match bus_name:
		AudioBusConfigData.MUSIC_BUS:
			return AudioBusConfigData.DEFAULT_MUSIC_VOLUME
		AudioBusConfigData.SFX_BUS:
			return AudioBusConfigData.DEFAULT_SFX_VOLUME
		_:
			return AudioBusConfigData.DEFAULT_MASTER_VOLUME

func _set_music_context(context: String) -> void:
	if MusicEngine != null and MusicEngine.has_method("set_context"):
		MusicEngine.set_context(context)

func _wire_ui_click_sfx(root: Node) -> void:
	if root == null:
		return
	if root is Button:
		var button := root as Button
		if not button.pressed.is_connected(_play_ui_click_sfx):
			button.pressed.connect(_play_ui_click_sfx)
	for child in root.get_children():
		_wire_ui_click_sfx(child)

func _play_ui_click_sfx() -> void:
	if sfx_engine != null and sfx_engine.has_method("play_ui_click"):
		sfx_engine.play_ui_click()

func _encode_input_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return {
			"type": "key",
			"keycode": key_event.keycode,
			"physical_keycode": key_event.physical_keycode,
			"shift": key_event.shift_pressed,
			"ctrl": key_event.ctrl_pressed,
			"alt": key_event.alt_pressed,
			"meta": key_event.meta_pressed,
		}
	if event is InputEventJoypadButton:
		return {
			"type": "joy_button",
			"button_index": (event as InputEventJoypadButton).button_index,
		}
	if event is InputEventJoypadMotion:
		var motion_event := event as InputEventJoypadMotion
		return {
			"type": "joy_motion",
			"axis": motion_event.axis,
			"axis_value": motion_event.axis_value,
		}
	return {}

func _decode_input_event(encoded: Dictionary) -> InputEvent:
	match str(encoded.get("type", "")):
		"key":
			var key_event := InputEventKey.new()
			key_event.device = -1
			key_event.keycode = int(encoded.get("keycode", 0)) as Key
			key_event.physical_keycode = int(encoded.get("physical_keycode", 0)) as Key
			key_event.shift_pressed = bool(encoded.get("shift", false))
			key_event.ctrl_pressed = bool(encoded.get("ctrl", false))
			key_event.alt_pressed = bool(encoded.get("alt", false))
			key_event.meta_pressed = bool(encoded.get("meta", false))
			return key_event
		"joy_button":
			var button_event := InputEventJoypadButton.new()
			button_event.device = -1
			button_event.button_index = int(encoded.get("button_index", 0)) as JoyButton
			return button_event
		"joy_motion":
			var motion_event := InputEventJoypadMotion.new()
			motion_event.device = -1
			motion_event.axis = int(encoded.get("axis", 0)) as JoyAxis
			motion_event.axis_value = float(encoded.get("axis_value", 1.0))
			return motion_event
	return null

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
	_debug_mutation_toggles.clear()
	_create_perf_launcher_row()

func _create_launch_cheat_row() -> void:
	pass

func _create_perf_launcher_row() -> void:
	if _debug_perf_option != null and is_instance_valid(_debug_perf_option):
		return
	var row := HBoxContainer.new()
	row.name = "PerfScenarioRow"
	row.add_theme_constant_override("separation", 10)
	menu_layout.add_child(row)
	menu_layout.move_child(row, status_label.get_index())
	var label := Label.new()
	label.text = "Perf Scenario"
	label.custom_minimum_size = Vector2(160.0, 0.0)
	row.add_child(label)
	_debug_perf_option = OptionButton.new()
	_debug_perf_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_populate_profile_option(_debug_perf_option, [
		{"label": "Champion Hive Heavy", "value": "champion:hive|heavy"},
		{"label": "Champion Pulsar Heavy", "value": "champion:pulsar|heavy"},
		{"label": "Champion Support Heavy", "value": "champion:elite_support|heavy"},
		{"label": "Combat Base", "value": "room:combat|base"},
	], "champion:hive|heavy")
	row.add_child(_debug_perf_option)
	_debug_perf_button = Button.new()
	_debug_perf_button.text = "Run Perf"
	_debug_perf_button.pressed.connect(_on_debug_perf_pressed)
	row.add_child(_debug_perf_button)
	_wire_ui_click_sfx(row)

func _on_debug_perf_pressed() -> void:
	if _debug_perf_option == null:
		return
	var value := str(_debug_perf_option.get_selected_metadata())
	var parts := value.split("|")
	var scenario := str(parts[0]) if parts.size() > 0 else "champion:hive"
	var build := str(parts[1]) if parts.size() > 1 else "base"
	if PerfRunner != null and PerfRunner.has_method("run_from_menu"):
		PerfRunner.run_from_menu(scenario, get_selected_player_count(), build)

func _ensure_loadout_columns() -> void:
	if _loadout_columns != null and is_instance_valid(_loadout_columns):
		return
	_loadout_columns = HBoxContainer.new()
	_loadout_columns.name = "LoadoutColumns"
	_loadout_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loadout_columns.add_theme_constant_override("separation", 12)
	menu_layout.add_child(_loadout_columns)
	menu_layout.move_child(_loadout_columns, status_label.get_index())
	for player_index in range(2):
		var column := VBoxContainer.new()
		column.name = "LoadoutColumnP%d" % (player_index + 1)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 6)
		_loadout_columns.add_child(column)

func _get_loadout_column(player_index: int) -> VBoxContainer:
	_ensure_loadout_columns()
	return _loadout_columns.get_child(player_index) as VBoxContainer

func _sync_loadout_columns(player_count: int) -> void:
	if _loadout_columns == null or not is_instance_valid(_loadout_columns):
		return
	for index in range(_loadout_columns.get_child_count()):
		(_loadout_columns.get_child(index) as Control).visible = index < player_count

func _build_class_rows() -> void:
	if not _class_rows.is_empty():
		return
	_ensure_loadout_columns()
	var class_defs := RunState.get_class_catalog()
	for player_index in range(2):
		var container := VBoxContainer.new()
		container.name = "ClassRowsP%d" % (player_index + 1)
		container.add_theme_constant_override("separation", 5)
		_get_loadout_column(player_index).add_child(container)
		var header := Label.new()
		header.text = "P%d Class" % (player_index + 1)
		header.add_theme_font_size_override("font_size", 13)
		container.add_child(header)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 5)
		container.add_child(grid)
		var cards: Dictionary = {}
		for class_def in class_defs:
			var class_data: Dictionary = class_def as Dictionary
			var class_id := str(class_data.get("id", ""))
			if class_id.is_empty():
				continue
			var card := _create_loadout_card(str(class_data.get("name", _format_name(class_id))), str(class_data.get("passive", "")))
			card.toggled.connect(_on_class_card_toggled.bind(player_index, class_id))
			grid.add_child(card)
			_wire_ui_click_sfx(card)
			cards[class_id] = card
		var summary := Label.new()
		summary.add_theme_font_size_override("font_size", 10)
		summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		container.add_child(summary)
		var default_class := _first_class_id()
		_class_rows.append({
			"container": container,
			"cards": cards,
			"summary": summary,
			"selection": default_class,
		})
		_sync_class_row_buttons(player_index)

func _build_player_class_selection() -> Array:
	var selections: Array = []
	for player_index in range(get_selected_player_count()):
		selections.append(_get_player_class_selection(player_index))
	return selections

func _get_player_class_selection(player_index: int) -> String:
	if player_index < 0 or player_index >= _class_rows.size():
		return _first_class_id()
	var row_data: Dictionary = _class_rows[player_index]
	var selection := str(row_data.get("selection", _first_class_id()))
	if not (row_data.get("cards", {}) as Dictionary).has(selection):
		return _first_class_id()
	return selection

func _first_class_id() -> String:
	var class_defs := RunState.get_class_catalog()
	if class_defs.is_empty():
		return "mobile"
	return str((class_defs[0] as Dictionary).get("id", "mobile"))

func _on_class_card_toggled(pressed: bool, player_index: int, class_id: String) -> void:
	if not pressed or player_index < 0 or player_index >= _class_rows.size():
		return
	var row_data: Dictionary = _class_rows[player_index]
	row_data["selection"] = class_id
	_class_rows[player_index] = row_data
	_select_defaults_for_class(player_index)
	_sync_class_row_buttons(player_index)
	_sync_weapon_row_buttons(player_index)
	_sync_ability_row_buttons(player_index)
	_refresh_menu_state()

func _sync_class_row_buttons(player_index: int) -> void:
	if player_index < 0 or player_index >= _class_rows.size():
		return
	var row_data: Dictionary = _class_rows[player_index]
	var cards: Dictionary = row_data.get("cards", {}) as Dictionary
	var selection := str(row_data.get("selection", _first_class_id()))
	for class_id_variant in cards.keys():
		var class_id := str(class_id_variant)
		var button: Button = cards[class_id]
		if button == null:
			continue
		button.set_pressed_no_signal(class_id == selection)
		_style_loadout_card(button, class_id == selection, _player_tints[player_index])
	var summary: Label = row_data.get("summary", null)
	if summary != null:
		var class_def := RunState.get_class_definition(selection)
		summary.text = "HP %d  |  Speed %d  |  Ult %s" % [
			int(class_def.get("hp", 100)),
			int(class_def.get("move_speed", 560)),
			_format_name(str(class_def.get("ultimate", ""))),
		]
		summary.modulate = Color(0.84, 0.92, 1.0, 0.92)

func _build_weapon_rows() -> void:
	if not _weapon_rows.is_empty():
		return
	_ensure_loadout_columns()
	var weapon_defs := RunState.get_weapon_catalog()
	for player_index in range(2):
		var container := VBoxContainer.new()
		container.name = "WeaponRowsP%d" % (player_index + 1)
		container.add_theme_constant_override("separation", 5)
		_get_loadout_column(player_index).add_child(container)
		var header := Label.new()
		header.text = "P%d Weapon" % (player_index + 1)
		header.add_theme_font_size_override("font_size", 13)
		container.add_child(header)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 5)
		container.add_child(grid)
		var cards: Dictionary = {}
		for weapon_def in weapon_defs:
			var weapon := weapon_def as Dictionary
			var weapon_id := str(weapon.get("id", ""))
			if weapon_id.is_empty():
				continue
			var card := _create_loadout_card(str(weapon.get("name", _format_name(weapon_id))), str(weapon.get("description", "")))
			card.toggled.connect(_on_weapon_card_toggled.bind(player_index, weapon_id))
			grid.add_child(card)
			_wire_ui_click_sfx(card)
			cards[weapon_id] = card
		var summary := Label.new()
		summary.add_theme_font_size_override("font_size", 10)
		summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		container.add_child(summary)
		_weapon_rows.append({
			"container": container,
			"cards": cards,
			"summary": summary,
			"selection": _first_weapon_id_for_class(_get_player_class_selection(player_index)),
		})
		_sync_weapon_row_buttons(player_index)

func _build_player_weapon_selection() -> Array:
	var selections: Array = []
	for player_index in range(get_selected_player_count()):
		selections.append(_get_player_weapon_selection(player_index))
	return selections

func _get_player_weapon_selection(player_index: int) -> String:
	if player_index < 0 or player_index >= _weapon_rows.size():
		return _first_weapon_id_for_class(_get_player_class_selection(player_index))
	var row_data: Dictionary = _weapon_rows[player_index]
	var selection := str(row_data.get("selection", ""))
	var allowed_ids := _get_class_weapon_ids(_get_player_class_selection(player_index))
	if not allowed_ids.has(selection):
		selection = _first_weapon_id_for_class(_get_player_class_selection(player_index))
		row_data["selection"] = selection
		_weapon_rows[player_index] = row_data
	return selection

func _on_weapon_card_toggled(pressed: bool, player_index: int, weapon_id: String) -> void:
	if not pressed or player_index < 0 or player_index >= _weapon_rows.size():
		return
	if not _get_class_weapon_ids(_get_player_class_selection(player_index)).has(weapon_id):
		_sync_weapon_row_buttons(player_index)
		return
	var row_data: Dictionary = _weapon_rows[player_index]
	row_data["selection"] = weapon_id
	_weapon_rows[player_index] = row_data
	_sync_weapon_row_buttons(player_index)
	_refresh_menu_state()

func _sync_weapon_row_buttons(player_index: int) -> void:
	if player_index < 0 or player_index >= _weapon_rows.size():
		return
	var row_data: Dictionary = _weapon_rows[player_index]
	var cards: Dictionary = row_data.get("cards", {}) as Dictionary
	var selection := _get_player_weapon_selection(player_index)
	var allowed_ids := _get_class_weapon_ids(_get_player_class_selection(player_index))
	for weapon_id_variant in cards.keys():
		var weapon_id := str(weapon_id_variant)
		var button: Button = cards[weapon_id]
		if button == null:
			continue
		var allowed := allowed_ids.has(weapon_id)
		button.visible = allowed
		button.disabled = not allowed
		button.set_pressed_no_signal(weapon_id == selection)
		_style_loadout_card(button, weapon_id == selection, _player_tints[player_index])
	var summary: Label = row_data.get("summary", null)
	if summary != null:
		summary.text = "Weapon: %s" % _format_name(selection)
		summary.modulate = Color(0.84, 0.92, 1.0, 0.92)

func _build_ability_rows() -> void:
	if not _ability_rows.is_empty():
		return
	_ensure_loadout_columns()
	var ability_defs := _ability_registry.get_all()
	for player_index in range(2):
		var container := VBoxContainer.new()
		container.name = "AbilityRowsP%d" % (player_index + 1)
		container.add_theme_constant_override("separation", 5)
		_get_loadout_column(player_index).add_child(container)
		var header := Label.new()
		header.text = "P%d Abilities" % (player_index + 1)
		header.add_theme_font_size_override("font_size", 13)
		container.add_child(header)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 5)
		container.add_child(grid)
		var cards: Dictionary = {}
		for ability_def in ability_defs:
			var ability_definition: Dictionary = ability_def as Dictionary
			var ability_id := str(ability_definition.get("id", ""))
			if ability_id.is_empty() or str(ability_definition.get("slot", "")) == "ultimate":
				continue
			var card := _create_loadout_card(str(ability_definition.get("name", _format_name(ability_id))), str(ability_definition.get("description", "")))
			card.set_meta("card_text", str(ability_definition.get("name", _format_name(ability_id))))
			card.toggled.connect(_on_ability_card_toggled.bind(player_index, ability_id))
			grid.add_child(card)
			_wire_ui_click_sfx(card)
			cards[ability_id] = card
		var summary := Label.new()
		summary.add_theme_font_size_override("font_size", 10)
		summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		container.add_child(summary)
		_ability_rows.append({
			"container": container,
			"cards": cards,
			"summary": summary,
			"selection": _default_abilities_for_class(_get_player_class_selection(player_index)),
		})
		_sync_ability_row_buttons(player_index)

func _build_player_ability_selection() -> Array:
	var selections: Array = []
	for player_index in range(get_selected_player_count()):
		selections.append(_get_player_ability_pair(player_index))
	return selections

func _get_player_ability_pair(player_index: int) -> Array:
	if player_index < 0 or player_index >= _ability_rows.size():
		return _default_abilities_for_class(_get_player_class_selection(player_index))
	var row_data: Dictionary = _ability_rows[player_index]
	var allowed_ids := _get_class_ability_ids(_get_player_class_selection(player_index))
	var selected: Array = []
	for ability_id_variant in (row_data.get("selection", []) as Array):
		var ability_id := str(ability_id_variant)
		if allowed_ids.has(ability_id) and not selected.has(ability_id):
			selected.append(ability_id)
	while selected.size() > 3:
		selected.pop_back()
	if selected.size() < 3:
		for ability_id in allowed_ids:
			if selected.size() >= 3:
				break
			if not selected.has(ability_id):
				selected.append(ability_id)
	row_data["selection"] = selected
	_ability_rows[player_index] = row_data
	return selected

func _on_ability_card_toggled(pressed: bool, player_index: int, ability_id: String) -> void:
	if player_index < 0 or player_index >= _ability_rows.size():
		return
	if not _get_class_ability_ids(_get_player_class_selection(player_index)).has(ability_id):
		_sync_ability_row_buttons(player_index)
		return
	var row_data: Dictionary = _ability_rows[player_index]
	var selected: Array = (row_data.get("selection", []) as Array).duplicate()
	if pressed:
		if selected.has(ability_id):
			pass
		else:
			while selected.size() >= 3:
				selected.pop_front()
			selected.append(ability_id)
	else:
		selected.erase(ability_id)
	row_data["selection"] = selected
	_ability_rows[player_index] = row_data
	_sync_ability_row_buttons(player_index)
	_refresh_menu_state()

func _sync_ability_row_buttons(player_index: int) -> void:
	if player_index < 0 or player_index >= _ability_rows.size():
		return
	var row_data: Dictionary = _ability_rows[player_index]
	var cards: Dictionary = row_data.get("cards", {}) as Dictionary
	var selected := _get_player_ability_pair(player_index)
	var allowed_ids := _get_class_ability_ids(_get_player_class_selection(player_index))
	for ability_id_variant in cards.keys():
		var ability_id := str(ability_id_variant)
		var button: Button = cards[ability_id]
		if button == null:
			continue
		var allowed := allowed_ids.has(ability_id)
		var slot_index := selected.find(ability_id)
		button.visible = allowed
		button.disabled = not allowed
		button.set_pressed_no_signal(slot_index >= 0)
		button.text = _format_ability_card_text(button, slot_index)
		_style_loadout_card(button, slot_index >= 0, _player_tints[player_index])
	var summary: Label = row_data.get("summary", null)
	if summary != null:
		var class_def := RunState.get_class_definition(_get_player_class_selection(player_index))
		var ultimate_id := str(class_def.get("ultimate", ""))
		if selected.size() >= 3:
			summary.text = "A %s  |  X %s  |  Y %s  |  B %s" % [
				_format_name(str(selected[0])),
				_format_name(str(selected[1])),
				_format_name(str(selected[2])),
				_format_name(ultimate_id),
			]
			summary.modulate = Color(0.84, 0.92, 1.0, 0.92)
		else:
			summary.text = "Select three class abilities."
			summary.modulate = Color(1.0, 0.8, 0.42, 0.96)

func _select_defaults_for_class(player_index: int) -> void:
	if player_index >= 0 and player_index < _weapon_rows.size():
		var weapon_row: Dictionary = _weapon_rows[player_index]
		weapon_row["selection"] = _first_weapon_id_for_class(_get_player_class_selection(player_index))
		_weapon_rows[player_index] = weapon_row
	if player_index >= 0 and player_index < _ability_rows.size():
		var ability_row: Dictionary = _ability_rows[player_index]
		ability_row["selection"] = _default_abilities_for_class(_get_player_class_selection(player_index))
		_ability_rows[player_index] = ability_row

func _get_class_weapon_ids(class_id: String) -> Array:
	var ids: Array = []
	for weapon in RunState.get_weapon_catalog_for_class(class_id):
		ids.append(str((weapon as Dictionary).get("id", "")))
	return ids

func _get_class_ability_ids(class_id: String) -> Array:
	var ids: Array = []
	for ability in RunState.get_ability_catalog_for_class(class_id):
		ids.append(str((ability as Dictionary).get("id", "")))
	return ids

func _first_weapon_id_for_class(class_id: String) -> String:
	var ids := _get_class_weapon_ids(class_id)
	return str(ids[0]) if not ids.is_empty() else "rifle"

func _default_abilities_for_class(class_id: String) -> Array:
	return _get_class_ability_ids(class_id).slice(0, 3)

func _create_loadout_card(text: String, tooltip: String) -> Button:
	var card := Button.new()
	card.toggle_mode = true
	card.custom_minimum_size = Vector2(0.0, 30.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.autowrap_mode = TextServer.AUTOWRAP_OFF
	card.text = text
	card.set_meta("card_text", text)
	card.tooltip_text = tooltip
	return card

func _format_ability_card_text(button: Button, slot_index: int) -> String:
	var card_text := str(button.get_meta("card_text", button.text))
	var labels := ["A", "X", "Y"]
	if slot_index >= 0 and slot_index < labels.size():
		return "%s - %s" % [str(labels[slot_index]), card_text]
	return card_text

func _style_loadout_card(button: Button, selected: bool, player_tint: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.09, 0.13, 0.96)
	normal.border_color = Color(0.24, 0.3, 0.4, 0.72)
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.set_content_margin_all(5)
	var hover := normal.duplicate()
	hover.border_color = Color(0.42, 0.5, 0.64, 0.9)
	var pressed := normal.duplicate()
	if selected:
		var slot_1_color := player_tint.lightened(0.12)
		pressed.bg_color = Color(slot_1_color.r * 0.2, slot_1_color.g * 0.2, slot_1_color.b * 0.2, 0.98)
		pressed.border_color = slot_1_color
	else:
		pressed.bg_color = normal.bg_color
		pressed.border_color = normal.border_color
	pressed.set_border_width_all(2 if selected else 1)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("focus", pressed)

func _can_start_run(player_count: int) -> bool:
	for player_index in range(player_count):
		var class_id := _get_player_class_selection(player_index)
		if class_id.is_empty():
			return false
		if not _get_class_weapon_ids(class_id).has(_get_player_weapon_selection(player_index)):
			return false
		var selected_abilities := _get_player_ability_pair(player_index)
		if selected_abilities.size() != 3:
			return false
		var class_ability_ids := _get_class_ability_ids(class_id)
		for ability_id in selected_abilities:
			if not class_ability_ids.has(str(ability_id)):
				return false
		if str(RunState.get_class_definition(class_id).get("ultimate", "")).is_empty():
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
