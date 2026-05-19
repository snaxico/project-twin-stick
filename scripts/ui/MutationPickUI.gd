class_name MutationPickUI
extends Control

const IconFactoryData = preload("res://scripts/ui/IconFactory.gd")

signal selections_confirmed(selections)

var _player_configs: Array = []
var _options_by_player: Array = []
var _selected_indices: Array = []
var _confirmed: Array = []
var _player_panels: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func configure_for_players(configs: Array, options_by_player: Array) -> void:
	_player_configs = configs.duplicate()
	_options_by_player = options_by_player.duplicate(true)
	_selected_indices.clear()
	_confirmed.clear()
	for _index in range(_player_configs.size()):
		_selected_indices.append(0)
		_confirmed.append(false)
	_build()
	_refresh_panels()

func _unhandled_input(event: InputEvent) -> void:
	for player_index in range(_player_configs.size()):
		if _confirmed[player_index]:
			continue
		var move_direction := _get_player_menu_direction(event, player_index)
		if move_direction != 0:
			_selected_indices[player_index] = wrapi(_selected_indices[player_index] + move_direction, 0, max((_options_by_player[player_index] as Array).size(), 1))
			_refresh_panels()
			get_viewport().set_input_as_handled()
			return
		if _is_player_confirm_pressed(event, player_index):
			_confirmed[player_index] = true
			_refresh_panels()
			get_viewport().set_input_as_handled()
			if _all_confirmed():
				var selections: Array = []
				for selection_index in range(_selected_indices.size()):
					var options: Array = _options_by_player[selection_index]
					var choice: Dictionary = options[_selected_indices[selection_index]] if _selected_indices[selection_index] < options.size() else {}
					selections.append(str(choice.get("id", "")))
				selections_confirmed.emit(selections)
			return

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_player_panels.clear()

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03, 0.04, 0.06, 0.84)
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_top", 120)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_bottom", 120)
	add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	margin.add_child(row)

	for player_index in range(_player_configs.size()):
		var player_panel := VBoxContainer.new()
		player_panel.custom_minimum_size = Vector2(420.0, 0.0)
		player_panel.add_theme_constant_override("separation", 14)
		row.add_child(player_panel)

		var title := Label.new()
		title.text = "Player %d Mutation" % (player_index + 1)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		player_panel.add_child(title)

		var cards := HBoxContainer.new()
		cards.alignment = BoxContainer.ALIGNMENT_CENTER
		cards.add_theme_constant_override("separation", 10)
		player_panel.add_child(cards)
		_player_panels.append(cards)

func _refresh_panels() -> void:
	for panel_index in range(_player_panels.size()):
		var cards: HBoxContainer = _player_panels[panel_index]
		for child in cards.get_children():
			cards.remove_child(child)
			child.queue_free()
		var options: Array = _options_by_player[panel_index]
		for option_index in range(options.size()):
			var card := _build_card(options[option_index], option_index == _selected_indices[panel_index], _confirmed[panel_index])
			cards.add_child(card)

func _build_card(option: Dictionary, is_selected: bool, is_confirmed: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(120.0, 180.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.92)
	style.border_color = Color(0.38, 0.44, 0.52, 0.46)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	if is_selected:
		style.border_color = Color(0.95, 0.82, 0.28, 0.96)
		style.set_border_width_all(2)
	if is_confirmed and is_selected:
		style.bg_color = Color(0.12, 0.22, 0.16, 0.96)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(64.0, 64.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = IconFactoryData.get_mutation_icon(str(option.get("id", "")))
	layout.add_child(icon)

	var title := Label.new()
	title.text = str(option.get("name", "Mutation"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(title)

	var description := Label.new()
	description.text = str(option.get("description", ""))
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 11)
	layout.add_child(description)
	return panel

func _get_player_menu_direction(event: InputEvent, player_index: int) -> int:
	var config = _player_configs[player_index]
	if config.control_source == "gamepad" and event is InputEventJoypadMotion:
		var joy_event := event as InputEventJoypadMotion
		if joy_event.device != player_index:
			pass
	if config.control_source == "gamepad" and gamepad_direction(event, config):
		return gamepad_direction(event, config)
	if config.control_source != "gamepad" and event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		match player_index:
			0:
				if key_event.physical_keycode == KEY_A:
					return -1
				if key_event.physical_keycode == KEY_D:
					return 1
			1:
				if key_event.physical_keycode == KEY_J:
					return -1
				if key_event.physical_keycode == KEY_L:
					return 1
	return 0

func gamepad_direction(event: InputEvent, config) -> int:
	if gamepad_direction_button(event, config, JOY_BUTTON_DPAD_LEFT):
		return -1
	if gamepad_direction_button(event, config, JOY_BUTTON_DPAD_RIGHT):
		return 1
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.device != config.player_id - 1 and motion.device != 0 and motion.device != 1:
			return 0
		if motion.axis == JOY_AXIS_LEFT_X:
			if motion.axis_value <= -0.5:
				return -1
			if motion.axis_value >= 0.5:
				return 1
	return 0

func gamepad_direction_button(event: InputEvent, config, button_index: JoyButton) -> bool:
	if not (event is InputEventJoypadButton):
		return false
	var joy_button := event as InputEventJoypadButton
	if not joy_button.pressed or joy_button.button_index != button_index:
		return false
	return joy_button.device == config.player_id - 1 or joy_button.device == 0 or joy_button.device == 1

func _is_player_confirm_pressed(event: InputEvent, player_index: int) -> bool:
	var config = _player_configs[player_index]
	if config.control_source == "gamepad":
		if not (event is InputEventJoypadButton):
			return false
		var joy_button := event as InputEventJoypadButton
		return joy_button.pressed and joy_button.button_index == JOY_BUTTON_A
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.physical_keycode == KEY_SPACE if player_index == 0 else key_event.physical_keycode == KEY_ENTER

func _all_confirmed() -> bool:
	for entry in _confirmed:
		if not bool(entry):
			return false
	return true
