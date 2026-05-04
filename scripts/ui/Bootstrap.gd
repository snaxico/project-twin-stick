extends Control

const PlayerConfigData = preload("res://scripts/player/PlayerConfig.gd")
const RUN_FLOW_SCENE = preload("res://scenes/ui/RunFlow.tscn")

@onready var game_container: Control = $GameContainer
@onready var menu_panel: Panel = $MenuPanel
@onready var player_count_option: OptionButton = $MenuPanel/MarginContainer/MenuLayout/PlayerCountRow/PlayerCountOption
@onready var player_1_control_option: OptionButton = $MenuPanel/MarginContainer/MenuLayout/Player1ControlRow/Player1ControlOption
@onready var player_2_control_option: OptionButton = $MenuPanel/MarginContainer/MenuLayout/Player2ControlRow/Player2ControlOption
@onready var player_3_control_option: OptionButton = $MenuPanel/MarginContainer/MenuLayout/Player3ControlRow/Player3ControlOption
@onready var player_4_control_option: OptionButton = $MenuPanel/MarginContainer/MenuLayout/Player4ControlRow/Player4ControlOption
@onready var meta_button: Button = $MenuPanel/MarginContainer/MenuLayout/MetaButton
@onready var reset_profile_button: Button = $MenuPanel/MarginContainer/MenuLayout/ResetProfileButton
@onready var start_button: Button = $MenuPanel/MarginContainer/MenuLayout/StartButton
@onready var player_2_control_row: HBoxContainer = $MenuPanel/MarginContainer/MenuLayout/Player2ControlRow
@onready var player_3_control_row: HBoxContainer = $MenuPanel/MarginContainer/MenuLayout/Player3ControlRow
@onready var player_4_control_row: HBoxContainer = $MenuPanel/MarginContainer/MenuLayout/Player4ControlRow
@onready var status_label: Label = $MenuPanel/MarginContainer/MenuLayout/StatusLabel
@onready var meta_panel: Panel = $MetaPanel
@onready var meta_status_label: Label = $MetaPanel/MarginContainer/MetaLayout/MetaStatusLabel
@onready var unlock_button_1: Button = $MetaPanel/MarginContainer/MetaLayout/UnlockButton1
@onready var unlock_button_2: Button = $MetaPanel/MarginContainer/MetaLayout/UnlockButton2
@onready var unlock_button_3: Button = $MetaPanel/MarginContainer/MetaLayout/UnlockButton3
@onready var unlock_button_4: Button = $MetaPanel/MarginContainer/MetaLayout/UnlockButton4
@onready var meta_back_button: Button = $MetaPanel/MarginContainer/MetaLayout/MetaBackButton

var _active_game = null
var _meta_unlocks: Array = []
var _player_tints := [
	Color(0.2, 0.85, 0.2, 1.0),
	Color(0.2, 0.45, 1.0, 1.0),
	Color(0.95, 0.82, 0.22, 1.0),
	Color(1.0, 0.56, 0.2, 1.0),
]
var _player_aim_modes := [
	PlayerConfigData.AimMode.HEAVY_AUTO,
	PlayerConfigData.AimMode.FULL_AUTO,
	PlayerConfigData.AimMode.FULL_AUTO,
	PlayerConfigData.AimMode.FULL_AUTO,
]

func _ready() -> void:
	_populate_menu()
	player_count_option.item_selected.connect(_on_player_count_changed)
	start_button.pressed.connect(_on_start_pressed)
	meta_button.pressed.connect(_on_meta_button_pressed)
	reset_profile_button.pressed.connect(_on_reset_profile_button_pressed)
	unlock_button_1.pressed.connect(_on_unlock_button_1_pressed)
	unlock_button_2.pressed.connect(_on_unlock_button_2_pressed)
	unlock_button_3.pressed.connect(_on_unlock_button_3_pressed)
	unlock_button_4.pressed.connect(_on_unlock_button_4_pressed)
	meta_back_button.pressed.connect(_on_meta_back_button_pressed)
	menu_panel.visible = true
	meta_panel.visible = false
	_refresh_menu_state()

func _populate_menu() -> void:
	player_count_option.clear()
	player_count_option.add_item("1 Player")
	player_count_option.add_item("2 Players")
	player_count_option.add_item("3 Players")
	player_count_option.add_item("4 Players")
	player_count_option.select(0)

	_populate_control_option(player_1_control_option, "gamepad")
	_populate_control_option(player_2_control_option, "gamepad")
	_populate_control_option(player_3_control_option, "gamepad")
	_populate_control_option(player_4_control_option, "gamepad")

func _populate_control_option(option_button: OptionButton, default_value: String) -> void:
	option_button.clear()
	option_button.add_item("Keyboard")
	option_button.set_item_metadata(0, "keyboard")
	option_button.add_item("Gamepad")
	option_button.set_item_metadata(1, "gamepad")
	option_button.add_item("Hybrid")
	option_button.set_item_metadata(2, "hybrid")

	for index in range(option_button.item_count):
		if option_button.get_item_metadata(index) == default_value:
			option_button.select(index)
			break

func _refresh_menu_state() -> void:
	var player_count := get_selected_player_count()
	player_2_control_row.visible = player_count > 1
	player_3_control_row.visible = player_count > 2
	player_4_control_row.visible = player_count > 3
	status_label.text = "%s\nPatch 9 adds persistent unlocks. Player 3 and Player 4 are still intended for gamepad play in the current prototype." % ProfileState.get_profile_summary_text()

func get_selected_player_count() -> int:
	return player_count_option.selected + 1

func _on_player_count_changed(_index: int) -> void:
	_refresh_menu_state()

func _on_start_pressed() -> void:
	var player_configs := _build_player_configs()
	_launch_game(player_configs)

func _build_player_configs() -> Array:
	var configs: Array = []
	var player_count := get_selected_player_count()
	var control_options := [
		player_1_control_option,
		player_2_control_option,
		player_3_control_option,
		player_4_control_option,
	]

	for index in range(player_count):
		var option_button: OptionButton = control_options[index]
		var control_source := str(option_button.get_selected_metadata())
		var aim_mode = _player_aim_modes[index]
		var tint: Color = _player_tints[index]
		configs.append(PlayerConfigData.new(index + 1, control_source, tint, aim_mode))

	return configs

func _launch_game(player_configs: Array) -> void:
	if _active_game != null and is_instance_valid(_active_game):
		_active_game.queue_free()

	RunState.start_new_run(player_configs)
	_active_game = RUN_FLOW_SCENE.instantiate()
	_active_game.return_to_menu_requested.connect(_on_return_to_menu_requested)
	game_container.add_child(_active_game)
	menu_panel.visible = false
	meta_panel.visible = false

func _on_return_to_menu_requested(open_meta_menu: bool = false) -> void:
	if _active_game != null and is_instance_valid(_active_game):
		_active_game.queue_free()
	_active_game = null
	_refresh_menu_state()
	if open_meta_menu:
		menu_panel.visible = false
		meta_panel.visible = true
		_refresh_meta_panel("")
		return
	menu_panel.visible = true
	meta_panel.visible = false

func _on_meta_button_pressed() -> void:
	menu_panel.visible = false
	meta_panel.visible = true
	_refresh_meta_panel("")

func _on_reset_profile_button_pressed() -> void:
	ProfileState.reset_profile()
	_refresh_menu_state()

func _on_unlock_button_pressed(index: int) -> void:
	if index < 0 or index >= _meta_unlocks.size():
		return
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
	meta_panel.visible = false
	menu_panel.visible = true
	_refresh_menu_state()

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
