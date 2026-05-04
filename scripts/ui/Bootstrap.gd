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
@onready var start_button: Button = $MenuPanel/MarginContainer/MenuLayout/StartButton
@onready var player_2_control_row: HBoxContainer = $MenuPanel/MarginContainer/MenuLayout/Player2ControlRow
@onready var player_3_control_row: HBoxContainer = $MenuPanel/MarginContainer/MenuLayout/Player3ControlRow
@onready var player_4_control_row: HBoxContainer = $MenuPanel/MarginContainer/MenuLayout/Player4ControlRow
@onready var status_label: Label = $MenuPanel/MarginContainer/MenuLayout/StatusLabel

var _active_game = null
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
	status_label.text = "Patch 8 menu supports 1-4 players. Player 3 and Player 4 are intended for gamepad play in the current prototype."

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
	game_container.add_child(_active_game)
	menu_panel.visible = false
