class_name MutationPickUI
extends Control

const IconFactoryData = preload("res://scripts/ui/IconFactory.gd")

signal selections_confirmed(selections_per_player: Array)

var _player_configs: Array = []
var _options_by_player: Array = []
var _gold_per_player: Array = []
var _pick_costs: Array = []
var _selected_indices: Array = []
var _selected_option_orders: Array = []
var _confirmed: Array = []
var _player_views: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func configure_for_players(configs: Array, options_by_player: Array, gold_per_player: Array, pick_costs: Array) -> void:
	_player_configs = configs.duplicate()
	_options_by_player = options_by_player.duplicate(true)
	_gold_per_player = gold_per_player.duplicate()
	_pick_costs = pick_costs.duplicate()
	_selected_indices.clear()
	_selected_option_orders.clear()
	_confirmed.clear()
	for _index in range(_player_configs.size()):
		_selected_indices.append(0)
		_selected_option_orders.append([])
		_confirmed.append(false)
	_build()
	_refresh_panels()
	for idx in range(_player_configs.size()):
		if (_options_by_player[idx] as Array).is_empty():
			_confirmed[idx] = true
	_refresh_panels()
	if _all_confirmed():
		call_deferred("emit_signal", "selections_confirmed", _build_final_selections())

func _unhandled_input(event: InputEvent) -> void:
	for player_index in range(_player_configs.size()):
		if _confirmed[player_index]:
			continue
		var move_direction := _get_player_menu_direction(event, player_index)
		if move_direction != 0:
			var max_index := (_options_by_player[player_index] as Array).size()
			_selected_indices[player_index] = wrapi(_selected_indices[player_index] + move_direction, 0, max_index + 1)
			_refresh_panels()
			get_viewport().set_input_as_handled()
			return
		if _is_player_skip_pressed(event, player_index):
			_finalize_player(player_index)
			get_viewport().set_input_as_handled()
			return
		if _is_player_confirm_pressed(event, player_index):
			_handle_player_confirm(player_index)
			get_viewport().set_input_as_handled()
			return

func _handle_player_confirm(player_index: int) -> void:
	var options: Array = _options_by_player[player_index]
	var selected_index: int = int(_selected_indices[player_index])
	if selected_index >= options.size():
		_finalize_player(player_index)
		return
	var selected_order: Array = _selected_option_orders[player_index]
	var existing_order_index := selected_order.find(selected_index)
	if existing_order_index >= 0:
		selected_order.remove_at(existing_order_index)
		_selected_option_orders[player_index] = selected_order
		_refresh_panels()
		return
	if not _can_select_option(player_index, selected_index):
		return
	selected_order.append(selected_index)
	_selected_option_orders[player_index] = selected_order
	_refresh_panels()

func _finalize_player(player_index: int) -> void:
	_confirmed[player_index] = true
	_refresh_panels()
	if _all_confirmed():
		selections_confirmed.emit(_build_final_selections())

func _build_final_selections() -> Array:
	var selections_per_player: Array = []
	for player_index in range(_player_configs.size()):
		var options: Array = _options_by_player[player_index]
		var selected_ids: Array = []
		for option_index in _selected_option_orders[player_index]:
			var normalized_index := int(option_index)
			var choice: Dictionary = options[normalized_index] if normalized_index >= 0 and normalized_index < options.size() else {}
			selected_ids.append(str(choice.get("id", "")))
		selections_per_player.append(selected_ids)
	return selections_per_player

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_player_views.clear()

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03, 0.04, 0.06, 0.84)
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_top", 100)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_bottom", 100)
	add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	margin.add_child(row)

	for player_index in range(_player_configs.size()):
		var player_panel := VBoxContainer.new()
		player_panel.custom_minimum_size = Vector2(520.0, 0.0)
		player_panel.add_theme_constant_override("separation", 12)
		row.add_child(player_panel)

		var title := Label.new()
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 20)
		player_panel.add_child(title)

		var gold_label := Label.new()
		gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 0.95))
		player_panel.add_child(gold_label)

		var hint := Label.new()
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 12)
		hint.modulate = Color(0.8, 0.84, 0.9, 0.8)
		hint.text = "Select cards to buy, then confirm Done."
		player_panel.add_child(hint)

		var cards := HBoxContainer.new()
		cards.alignment = BoxContainer.ALIGNMENT_CENTER
		cards.add_theme_constant_override("separation", 10)
		player_panel.add_child(cards)

		_player_views.append({
			"title": title,
			"gold": gold_label,
			"hint": hint,
			"cards": cards,
		})

func _refresh_panels() -> void:
	for player_index in range(_player_views.size()):
		var view: Dictionary = _player_views[player_index]
		var title: Label = view["title"]
		var gold_label: Label = view["gold"]
		var hint: Label = view["hint"]
		var cards: HBoxContainer = view["cards"]
		for child in cards.get_children():
			cards.remove_child(child)
			child.queue_free()
		title.text = "Player %d Elite Reward" % (player_index + 1) if _pick_costs.size() == 1 else "Player %d Mutations" % (player_index + 1)
		hint.text = "Buy this rare or confirm Done." if _pick_costs.size() == 1 else "Select cards to buy, then confirm Done."
		var selected_count := (_selected_option_orders[player_index] as Array).size()
		gold_label.text = "Gold: %dg   Remaining: %dg   Picks: %d/%d" % [
			int(_gold_per_player[player_index]),
			_get_remaining_gold(player_index),
			selected_count,
			_pick_costs.size(),
		]
		var options: Array = _options_by_player[player_index]
		for option_index in range(options.size()):
			cards.add_child(_build_card(player_index, option_index, false))
		cards.add_child(_build_card(player_index, options.size(), true))

func _build_card(player_index: int, option_index: int, is_done: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(126.0, 196.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.92)
	style.border_color = Color(0.38, 0.44, 0.52, 0.46)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10

	var is_selected_cursor := option_index == int(_selected_indices[player_index])
	var is_confirmed := bool(_confirmed[player_index])
	var selected_order_index := (_selected_option_orders[player_index] as Array).find(option_index)
	var is_selected := selected_order_index >= 0
	var can_select := _can_select_option(player_index, option_index)

	if is_selected_cursor:
		style.border_color = Color(0.95, 0.82, 0.28, 0.96)
		style.set_border_width_all(2)
	if is_selected:
		style.bg_color = Color(0.12, 0.22, 0.16, 0.96)
	if not is_done and not is_selected and not can_select:
		style.bg_color = Color(0.07, 0.08, 0.10, 0.92)
		style.border_color = Color(0.24, 0.26, 0.3, 0.42)
	if is_confirmed:
		style.bg_color = style.bg_color.darkened(0.15)
	if is_done:
		style.bg_color = Color(0.09, 0.12, 0.18, 0.96) if not is_confirmed else Color(0.12, 0.20, 0.14, 0.96)
		if is_selected_cursor:
			style.border_color = Color(0.4, 1.0, 0.74, 0.96)
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

	if is_done:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(64.0, 26.0)
		layout.add_child(spacer)
		var done_title := Label.new()
		done_title.text = "Done"
		done_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done_title.add_theme_font_size_override("font_size", 18)
		layout.add_child(done_title)
		var done_detail := Label.new()
		done_detail.text = "Confirm %d pick(s)\nSave %dg" % [
			(_selected_option_orders[player_index] as Array).size(),
			_get_remaining_gold(player_index),
		]
		done_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		done_detail.add_theme_font_size_override("font_size", 12)
		layout.add_child(done_detail)
		return panel

	var option: Dictionary = (_options_by_player[player_index] as Array)[option_index]
	if str(option.get("rarity", "common")) == "rare":
		style.border_color = Color(0.95, 0.76, 0.18, 0.96)
		if is_selected_cursor:
			style.set_border_width_all(2)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(64.0, 64.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = IconFactoryData.get_mutation_icon(str(option.get("id", "")))
	icon.modulate = Color.WHITE if can_select or is_selected else Color(0.45, 0.45, 0.45, 0.8)
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
	description.modulate = Color.WHITE if can_select or is_selected else Color(0.62, 0.66, 0.74, 0.7)
	layout.add_child(description)

	var cost_label := Label.new()
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 12)
	if is_selected:
		var selected_cost: int = int(_pick_costs[selected_order_index])
		cost_label.text = "Selected  %dg" % selected_cost
		cost_label.modulate = Color(0.52, 1.0, 0.76, 0.95)
	else:
		var next_cost := _get_next_pick_cost(player_index)
		if next_cost < 0:
			cost_label.text = "Max picks"
			cost_label.modulate = Color(0.68, 0.72, 0.8, 0.75)
		elif can_select:
			cost_label.text = "Buy  %dg" % next_cost
			cost_label.modulate = Color(1.0, 0.85, 0.2, 0.95)
		else:
			cost_label.text = "Need  %dg" % next_cost
			cost_label.modulate = Color(0.86, 0.44, 0.44, 0.95)
	layout.add_child(cost_label)
	return panel

func _get_next_pick_cost(player_index: int) -> int:
	var selected_count := (_selected_option_orders[player_index] as Array).size()
	if selected_count >= _pick_costs.size():
		return -1
	return int(_pick_costs[selected_count])

func _get_selected_total_cost(player_index: int) -> int:
	var total := 0
	var selected_order: Array = _selected_option_orders[player_index]
	for cost_index in range(selected_order.size()):
		total += int(_pick_costs[mini(cost_index, _pick_costs.size() - 1)])
	return total

func _get_remaining_gold(player_index: int) -> int:
	return int(_gold_per_player[player_index]) - _get_selected_total_cost(player_index)

func _can_select_option(player_index: int, option_index: int) -> bool:
	var options: Array = _options_by_player[player_index]
	if option_index < 0 or option_index >= options.size():
		return false
	var selected_order: Array = _selected_option_orders[player_index]
	if selected_order.find(option_index) >= 0:
		return true
	var next_cost := _get_next_pick_cost(player_index)
	if next_cost < 0:
		return false
	return _get_remaining_gold(player_index) >= next_cost

func _get_player_menu_direction(event: InputEvent, player_index: int) -> int:
	var config = _player_configs[player_index]
	if config.control_source == "gamepad":
		var gamepad_direction := _gamepad_direction(event, config)
		if gamepad_direction != 0:
			return gamepad_direction
	if config.control_source != "gamepad":
		if _event_matches_action(event, "p%d_move_left" % int(config.player_id)):
			return -1
		if _event_matches_action(event, "p%d_move_right" % int(config.player_id)):
			return 1
	return 0

func _gamepad_direction(event: InputEvent, config) -> int:
	if _gamepad_direction_button(event, config, JOY_BUTTON_DPAD_LEFT):
		return -1
	if _gamepad_direction_button(event, config, JOY_BUTTON_DPAD_RIGHT):
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

func _gamepad_direction_button(event: InputEvent, config, button_index: JoyButton) -> bool:
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
	return _event_matches_action(event, "p%d_secondary" % int(config.player_id))

func _is_player_skip_pressed(event: InputEvent, player_index: int) -> bool:
	var config = _player_configs[player_index]
	if config.control_source == "gamepad":
		if not (event is InputEventJoypadButton):
			return false
		var joy_button := event as InputEventJoypadButton
		return joy_button.pressed and joy_button.button_index == JOY_BUTTON_B
	return _event_matches_action(event, "p%d_dash" % int(config.player_id)) or _event_matches_action(event, "ui_cancel")

func _event_matches_action(event: InputEvent, action_name: String) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	return event.is_action_pressed(action_name)

func _all_confirmed() -> bool:
	for entry in _confirmed:
		if not bool(entry):
			return false
	return true
