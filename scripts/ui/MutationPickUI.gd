class_name MutationPickUI
extends Control

const IconFactoryData = preload("res://scripts/ui/IconFactory.gd")

signal selections_confirmed(selections_per_player: Array)

var _player_configs: Array = []
var _options_by_player: Array = []
var _selected_indices: Array = []
var _confirmed: Array = []
var _locked_selection_ids: Array = []
var _player_views: Array = []
var _definition_cache: Dictionary = {}
var _round_title := "Level Up"
var _round_subtitle := "Choose one upgrade."

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func configure_for_players(configs: Array, options_by_player: Array, round_title: String, round_subtitle: String = "Choose one upgrade.") -> void:
	_player_configs = configs.duplicate()
	_options_by_player = options_by_player.duplicate(true)
	_round_title = round_title
	_round_subtitle = round_subtitle
	_selected_indices.clear()
	_confirmed.clear()
	_locked_selection_ids.clear()
	_definition_cache.clear()
	for player_index in range(_player_configs.size()):
		_selected_indices.append(0)
		_confirmed.append(false)
		_locked_selection_ids.append("")
	_build()
	for player_index in range(_player_configs.size()):
		if (_options_by_player[player_index] as Array).is_empty():
			_confirmed[player_index] = true
	_refresh_panels()
	if _all_confirmed():
		call_deferred("emit_signal", "selections_confirmed", _build_final_selections())

func _unhandled_input(event: InputEvent) -> void:
	for player_index in range(_player_configs.size()):
		if _confirmed[player_index]:
			continue
		var move_direction := _get_player_menu_direction(event, player_index)
		if move_direction != 0:
			var option_count := (_options_by_player[player_index] as Array).size()
			if option_count > 0:
				_selected_indices[player_index] = wrapi(_selected_indices[player_index] + move_direction, 0, option_count)
				_refresh_panels()
				get_viewport().set_input_as_handled()
				return
		if _is_player_confirm_pressed(event, player_index):
			_confirm_player_selection(player_index)
			get_viewport().set_input_as_handled()
			return

func _confirm_player_selection(player_index: int) -> void:
	var options: Array = _options_by_player[player_index]
	if options.is_empty():
		_confirmed[player_index] = true
		_refresh_panels()
		if _all_confirmed():
			selections_confirmed.emit(_build_final_selections())
		return
	var selected_index := clampi(int(_selected_indices[player_index]), 0, max(options.size() - 1, 0))
	var option: Dictionary = options[selected_index] as Dictionary
	_locked_selection_ids[player_index] = str(option.get("id", ""))
	_confirmed[player_index] = true
	_refresh_panels()
	if _all_confirmed():
		selections_confirmed.emit(_build_final_selections())

func _build_final_selections() -> Array:
	var selections_per_player: Array = []
	for player_index in range(_player_configs.size()):
		var selection_id := str(_locked_selection_ids[player_index])
		selections_per_player.append([] if selection_id.is_empty() else [selection_id])
	return selections_per_player

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_player_views.clear()

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03, 0.04, 0.06, 0.86)
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_top", 84)
	margin.add_theme_constant_override("margin_right", 72)
	margin.add_theme_constant_override("margin_bottom", 84)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	var title := Label.new()
	title.text = _round_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = _round_subtitle
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.modulate = Color(0.82, 0.88, 0.96, 0.84)
	root.add_child(subtitle)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	root.add_child(row)

	for player_index in range(_player_configs.size()):
		var player_panel := VBoxContainer.new()
		player_panel.custom_minimum_size = Vector2(520.0, 0.0)
		player_panel.add_theme_constant_override("separation", 10)
		row.add_child(player_panel)

		var player_title := Label.new()
		player_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		player_title.add_theme_font_size_override("font_size", 20)
		player_panel.add_child(player_title)

		var state_label := Label.new()
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state_label.add_theme_font_size_override("font_size", 12)
		player_panel.add_child(state_label)

		var hint_label := Label.new()
		hint_label.text = "Move to choose. Confirm locks the highlighted card."
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.add_theme_font_size_override("font_size", 11)
		hint_label.modulate = Color(0.78, 0.86, 0.96, 0.7)
		player_panel.add_child(hint_label)

		var inventory_label := Label.new()
		inventory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inventory_label.add_theme_font_size_override("font_size", 11)
		inventory_label.modulate = Color(0.8, 0.88, 0.98, 0.7)
		inventory_label.text = "Current Build"
		player_panel.add_child(inventory_label)

		var inventory_flow := FlowContainer.new()
		inventory_flow.alignment = FlowContainer.ALIGNMENT_CENTER
		inventory_flow.add_theme_constant_override("h_separation", 6)
		inventory_flow.add_theme_constant_override("v_separation", 6)
		player_panel.add_child(inventory_flow)

		var cards := HBoxContainer.new()
		cards.alignment = BoxContainer.ALIGNMENT_CENTER
		cards.add_theme_constant_override("separation", 10)
		player_panel.add_child(cards)

		_player_views.append({
			"title": player_title,
			"state": state_label,
			"inventory_flow": inventory_flow,
			"cards": cards,
		})

func _refresh_panels() -> void:
	for player_index in range(_player_views.size()):
		var view: Dictionary = _player_views[player_index]
		var title: Label = view["title"]
		var state_label: Label = view["state"]
		var inventory_flow: FlowContainer = view["inventory_flow"]
		var cards: HBoxContainer = view["cards"]
		for child in inventory_flow.get_children():
			inventory_flow.remove_child(child)
			child.queue_free()
		for child in cards.get_children():
			cards.remove_child(child)
			child.queue_free()
		title.text = "Player %d" % (player_index + 1)
		if bool(_confirmed[player_index]):
			var selection_id := str(_locked_selection_ids[player_index])
			state_label.text = "Locked In" if not selection_id.is_empty() else "No valid picks"
			state_label.modulate = Color(0.46, 0.98, 0.72, 0.95)
		else:
			state_label.text = "Choose one upgrade"
			state_label.modulate = Color(0.84, 0.9, 0.98, 0.82)
		_populate_inventory_flow(inventory_flow, player_index)
		var options: Array = _options_by_player[player_index]
		for option_index in range(options.size()):
			cards.add_child(_build_card(player_index, option_index))

func _build_card(player_index: int, option_index: int) -> Control:
	var option: Dictionary = (_options_by_player[player_index] as Array)[option_index] as Dictionary
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(132.0, 184.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.94)
	style.border_color = Color(0.38, 0.44, 0.52, 0.46)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	var is_cursor := option_index == int(_selected_indices[player_index]) and not bool(_confirmed[player_index])
	var is_locked := str(_locked_selection_ids[player_index]) == str(option.get("id", ""))
	var is_rare := str(option.get("rarity", "common")) == "rare"
	if is_rare:
		style.border_color = Color(0.95, 0.78, 0.18, 0.9)
	if is_cursor:
		style.set_border_width_all(2)
		style.border_color = Color(0.42, 0.98, 0.8, 0.96) if not is_rare else Color(1.0, 0.86, 0.32, 0.98)
	if is_locked:
		style.bg_color = Color(0.12, 0.22, 0.16, 0.98)
	if bool(_confirmed[player_index]) and not is_locked:
		style.bg_color = style.bg_color.darkened(0.12)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)

	var group := str(option.get("group", "attribute"))
	var meta_label := Label.new()
	meta_label.text = "%s | %s" % ["RARE" if is_rare else "COMMON", group.to_upper()]
	meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta_label.add_theme_font_size_override("font_size", 10)
	meta_label.modulate = Color(1.0, 0.82, 0.28, 0.9) if is_rare else IconFactoryData.get_group_color(group).lightened(0.18)
	layout.add_child(meta_label)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(64.0, 64.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if group == "weapon":
		icon.texture = IconFactoryData.get_weapon_icon(str(option.get("icon", "")))
	else:
		icon.texture = IconFactoryData.get_mutation_icon(str(option.get("id", "")), group)
	layout.add_child(icon)

	var mutation_title := Label.new()
	mutation_title.text = str(option.get("name", "Mutation"))
	mutation_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mutation_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(mutation_title)

	if not is_rare and group != "weapon":
		var current_level := _get_current_mutation_level(player_index, str(option.get("id", "")))
		var level_label := Label.new()
		level_label.text = "Lv %d -> Lv %d" % [current_level, current_level + 1]
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.add_theme_font_size_override("font_size", 11)
		level_label.modulate = Color(0.86, 0.94, 1.0, 0.84)
		layout.add_child(level_label)

	var description := Label.new()
	description.text = str(option.get("description", ""))
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_OFF
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description.max_lines_visible = 1
	description.add_theme_font_size_override("font_size", 11)
	description.modulate = Color(0.82, 0.86, 0.94, 0.92)
	layout.add_child(description)

	return panel

func _populate_inventory_flow(flow: FlowContainer, player_index: int) -> void:
	var entries := _build_inventory_entries(player_index)
	if entries.is_empty():
		var empty_chip := Label.new()
		empty_chip.text = "No upgrades yet"
		empty_chip.modulate = Color(0.76, 0.82, 0.92, 0.62)
		flow.add_child(empty_chip)
		return
	for entry in entries:
		flow.add_child(_build_inventory_chip(entry as Dictionary))

func _build_inventory_entries(player_index: int) -> Array:
	var counts: Dictionary = {}
	for mutation_id_variant in RunState.get_mutations(player_index):
		var mutation_id := str(mutation_id_variant)
		counts[mutation_id] = int(counts.get(mutation_id, 0)) + 1
	var entries: Array = []
	var active_weapon_id := RunState.get_active_weapon_id(player_index)
	entries.append({
		"id": active_weapon_id,
		"name": "%s Lv%d" % [_get_weapon_name(active_weapon_id), RunState.get_weapon_level(player_index)],
		"level": 1,
		"rarity": "common",
		"group": "weapon",
	})
	for mutation_id_variant in counts.keys():
		var mutation_id := str(mutation_id_variant)
		var definition := _get_mutation_definition(mutation_id)
		entries.append({
			"id": mutation_id,
			"name": str(definition.get("name", _format_name(mutation_id))),
			"level": int(counts[mutation_id]),
			"rarity": str(definition.get("rarity", "common")),
			"group": str(definition.get("group", "attribute")),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if str(a.get("group", "")) == "weapon" and str(b.get("group", "")) != "weapon":
			return true
		if str(a.get("group", "")) != "weapon" and str(b.get("group", "")) == "weapon":
			return false
		return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0
	)
	return entries

func _build_inventory_chip(entry: Dictionary) -> Control:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var is_rare := str(entry.get("rarity", "common")) == "rare"
	var group_color := IconFactoryData.get_group_color(str(entry.get("group", "attribute")))
	style.bg_color = Color(group_color.r * 0.16, group_color.g * 0.16, group_color.b * 0.16, 0.96)
	style.border_color = Color(0.98, 0.82, 0.28, 0.92) if is_rare else Color(group_color.r, group_color.g, group_color.b, 0.78)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.set_content_margin_all(6)
	chip.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = str(entry.get("name", "Mutation"))
	if int(entry.get("level", 1)) > 1 and not is_rare:
		label.text += " Lv%d" % int(entry.get("level", 1))
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = Color(1.0, 0.86, 0.34, 0.98) if is_rare else Color(0.92, 0.96, 1.0, 0.94)
	chip.add_child(label)
	return chip

func _get_mutation_definition(mutation_id: String) -> Dictionary:
	if _definition_cache.has(mutation_id):
		return (_definition_cache[mutation_id] as Dictionary).duplicate(true)
	var system := MutationSystem.new()
	var definition := system.get_definition(mutation_id)
	_definition_cache[mutation_id] = definition.duplicate(true)
	return definition

func _get_weapon_name(weapon_id: String) -> String:
	for weapon in RunState.get_weapon_catalog():
		var weapon_dict: Dictionary = weapon as Dictionary
		if str(weapon_dict.get("id", "")) == weapon_id:
			return str(weapon_dict.get("name", weapon_id))
	return _format_name(weapon_id)

func _format_name(raw_id: String) -> String:
	var parts: Array = []
	for part in raw_id.split("_"):
		if not part.is_empty():
			parts.append(part.capitalize())
	return " ".join(parts)

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

func _get_current_mutation_level(player_index: int, mutation_id: String) -> int:
	var count := 0
	for entry in RunState.get_mutations(player_index):
		if str(entry) == mutation_id:
			count += 1
	return count
