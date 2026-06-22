class_name MutationPickUI
extends Control

const IconFactoryData = preload("res://scripts/ui/IconFactory.gd")

signal selections_confirmed(selections_per_player: Array)
signal reroll_requested(player_index: int)
signal skip_requested(player_index: int)

var _player_configs: Array = []
var _options_by_player: Array = []
var _reroll_costs_by_player: Array = []
var _selected_indices: Array = []
var _confirmed: Array = []
var _locked_selection_ids: Array = []
var _player_views: Array = []
var _definition_cache: Dictionary = {}
var _round_title := "Level Up"
var _round_subtitle := "Choose one upgrade."
var _shared_run_score := 0

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
	_reroll_costs_by_player.clear()
	_definition_cache.clear()
	for player_index in range(_player_configs.size()):
		_selected_indices.append(0)
		_confirmed.append(false)
		_locked_selection_ids.append("")
		_reroll_costs_by_player.append(0)
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
			if _is_player_cancel_pressed(event, player_index):
				_unconfirm_player_selection(player_index)
				get_viewport().set_input_as_handled()
				return
			continue
		var move_direction := _get_player_menu_direction(event, player_index)
		if move_direction != 0:
			var slot_count := _get_navigable_slot_count(player_index)
			if slot_count > 0:
				_selected_indices[player_index] = wrapi(_selected_indices[player_index] + move_direction, 0, slot_count)
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
	var selected_index := clampi(int(_selected_indices[player_index]), 0, _get_navigable_slot_count(player_index) - 1)
	if selected_index == options.size():
		if _is_reroll_affordable(player_index):
			reroll_requested.emit(player_index)
		return
	if selected_index == options.size() + 1:
		_locked_selection_ids[player_index] = ""
		_confirmed[player_index] = true
		_refresh_panels()
		skip_requested.emit(player_index)
		if _all_confirmed():
			selections_confirmed.emit(_build_final_selections())
		return
	var option: Dictionary = options[selected_index] as Dictionary
	_locked_selection_ids[player_index] = str(option.get("id", ""))
	_confirmed[player_index] = true
	_refresh_panels()
	if _all_confirmed():
		selections_confirmed.emit(_build_final_selections())

func set_reroll_state(shared_run_score: int, reroll_costs_by_player: Array) -> void:
	_shared_run_score = max(shared_run_score, 0)
	_reroll_costs_by_player = reroll_costs_by_player.duplicate()
	while _reroll_costs_by_player.size() < _player_configs.size():
		_reroll_costs_by_player.append(0)
	_refresh_panels()

func replace_options_for_player(player_index: int, options: Array) -> void:
	if player_index < 0 or player_index >= _options_by_player.size():
		return
	_options_by_player[player_index] = options.duplicate(true)
	_selected_indices[player_index] = 0
	_confirmed[player_index] = false
	_locked_selection_ids[player_index] = ""
	_refresh_panels()

func _unconfirm_player_selection(player_index: int) -> void:
	var options: Array = _options_by_player[player_index]
	if options.is_empty():
		return
	_confirmed[player_index] = false
	_locked_selection_ids[player_index] = ""
	_refresh_panels()

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

		var detail_panel := PanelContainer.new()
		detail_panel.custom_minimum_size = Vector2(0.0, 118.0)
		var detail_style := StyleBoxFlat.new()
		detail_style.bg_color = Color(0.055, 0.07, 0.1, 0.94)
		detail_style.border_color = Color(0.26, 0.34, 0.44, 0.76)
		detail_style.set_border_width_all(1)
		detail_style.corner_radius_top_left = 8
		detail_style.corner_radius_top_right = 8
		detail_style.corner_radius_bottom_left = 8
		detail_style.corner_radius_bottom_right = 8
		detail_panel.add_theme_stylebox_override("panel", detail_style)
		player_panel.add_child(detail_panel)
		var detail_margin := MarginContainer.new()
		detail_margin.add_theme_constant_override("margin_left", 12)
		detail_margin.add_theme_constant_override("margin_top", 10)
		detail_margin.add_theme_constant_override("margin_right", 12)
		detail_margin.add_theme_constant_override("margin_bottom", 10)
		detail_panel.add_child(detail_margin)
		var detail_layout := VBoxContainer.new()
		detail_layout.add_theme_constant_override("separation", 5)
		detail_margin.add_child(detail_layout)
		var detail_title := Label.new()
		detail_title.add_theme_font_size_override("font_size", 15)
		detail_layout.add_child(detail_title)
		var detail_meta := Label.new()
		detail_meta.add_theme_font_size_override("font_size", 11)
		detail_meta.modulate = Color(0.82, 0.9, 1.0, 0.72)
		detail_layout.add_child(detail_meta)
		var detail_description := Label.new()
		detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_description.add_theme_font_size_override("font_size", 12)
		detail_description.modulate = Color(0.9, 0.93, 1.0, 0.9)
		detail_layout.add_child(detail_description)

		_player_views.append({
			"title": player_title,
			"state": state_label,
			"inventory_flow": inventory_flow,
			"cards": cards,
			"detail_title": detail_title,
			"detail_meta": detail_meta,
			"detail_description": detail_description,
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
		if not options.is_empty():
			cards.add_child(_build_action_slot(player_index, options.size(), "Reroll", "Score %d | Cost %d" % [_shared_run_score, _get_reroll_cost(player_index)], _is_reroll_affordable(player_index)))
			cards.add_child(_build_action_slot(player_index, options.size() + 1, "Skip", "Decline this pick", true))
		_refresh_detail_panel(view, player_index)

func _build_card(player_index: int, option_index: int) -> Control:
	var option: Dictionary = (_options_by_player[player_index] as Array)[option_index] as Dictionary
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(132.0, 144.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.94)
	style.border_color = Color(0.38, 0.44, 0.52, 0.46)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	var is_cursor := option_index == int(_selected_indices[player_index]) and not bool(_confirmed[player_index])
	var is_locked := str(_locked_selection_ids[player_index]) == str(option.get("id", ""))
	var rarity := str(option.get("rarity", "common"))
	var rarity_rank := _rarity_rank(rarity)
	if rarity_rank >= 1:
		style.border_color = _rarity_color(rarity)
	if is_cursor:
		style.set_border_width_all(2)
		style.border_color = Color(0.42, 0.98, 0.8, 0.96) if rarity_rank <= 0 else _rarity_color(rarity).lightened(0.12)
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
	meta_label.text = "%s | %s" % [_rarity_label(rarity).to_upper(), group.to_upper()]
	meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta_label.add_theme_font_size_override("font_size", 10)
	meta_label.modulate = _rarity_color(rarity) if rarity_rank >= 1 else IconFactoryData.get_group_color(group).lightened(0.18)
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

	if rarity_rank <= 0 and group != "weapon":
		var current_level := _get_current_mutation_level(player_index, str(option.get("id", "")))
		var level_label := Label.new()
		level_label.text = "Lv %d -> Lv %d" % [current_level, current_level + 1]
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.add_theme_font_size_override("font_size", 11)
		level_label.modulate = Color(0.86, 0.94, 1.0, 0.84)
		layout.add_child(level_label)

	return panel

func _build_action_slot(player_index: int, slot_index: int, title_text: String, subtitle_text: String, enabled: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(112.0, 144.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.085, 0.11, 0.9) if enabled else Color(0.045, 0.05, 0.06, 0.82)
	style.border_color = Color(0.34, 0.44, 0.56, 0.54) if enabled else Color(0.18, 0.2, 0.24, 0.5)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	var is_cursor := slot_index == int(_selected_indices[player_index]) and not bool(_confirmed[player_index])
	if is_cursor:
		style.set_border_width_all(2)
		style.border_color = Color(0.42, 0.98, 0.8, 0.96) if enabled else Color(0.38, 0.44, 0.5, 0.7)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var title_label := Label.new()
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.modulate = Color(0.9, 0.96, 1.0, 0.96) if enabled else Color(0.62, 0.68, 0.74, 0.7)
	layout.add_child(title_label)

	var icon_label := Label.new()
	icon_label.text = "R" if title_text == "Reroll" else "X"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 30)
	icon_label.modulate = Color(0.42, 0.98, 0.8, 0.9) if enabled else Color(0.42, 0.46, 0.5, 0.64)
	layout.add_child(icon_label)

	var subtitle_label := Label.new()
	subtitle_label.text = subtitle_text if enabled else "Not enough score"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 10)
	subtitle_label.modulate = Color(0.78, 0.86, 0.96, 0.78) if enabled else Color(0.56, 0.6, 0.66, 0.66)
	layout.add_child(subtitle_label)
	return panel

func _refresh_detail_panel(view: Dictionary, player_index: int) -> void:
	var detail_title: Label = view["detail_title"]
	var detail_meta: Label = view["detail_meta"]
	var detail_description: Label = view["detail_description"]
	var options: Array = _options_by_player[player_index]
	if options.is_empty():
		detail_title.text = "No Upgrade"
		detail_meta.text = ""
		detail_description.text = ""
		return
	var selected_index := clampi(int(_selected_indices[player_index]), 0, _get_navigable_slot_count(player_index) - 1)
	if selected_index == options.size():
		detail_title.text = "Reroll"
		detail_title.modulate = Color(0.42, 0.98, 0.8, 0.96) if _is_reroll_affordable(player_index) else Color(0.62, 0.68, 0.74, 0.82)
		detail_meta.text = "Shared score: %d | Cost: %d" % [_shared_run_score, _get_reroll_cost(player_index)]
		detail_description.text = "Replace your offered cards without changing rare pity for this pick round."
		return
	if selected_index == options.size() + 1:
		detail_title.text = "Skip"
		detail_title.modulate = Color(0.92, 0.98, 1.0, 0.96)
		detail_meta.text = "Free decline"
		detail_description.text = "Take no upgrade and resolve this pick."
		return
	if bool(_confirmed[player_index]) and not str(_locked_selection_ids[player_index]).is_empty():
		for index in range(options.size()):
			if str((options[index] as Dictionary).get("id", "")) == str(_locked_selection_ids[player_index]):
				selected_index = index
				break
	var option: Dictionary = options[selected_index] as Dictionary
	var group := str(option.get("group", "attribute"))
	var rarity := str(option.get("rarity", "common"))
	var rarity_rank := _rarity_rank(rarity)
	detail_title.text = str(option.get("name", "Upgrade"))
	detail_title.modulate = _rarity_color(rarity) if rarity_rank >= 1 else Color(0.92, 0.98, 1.0, 0.96)
	var meta_parts: Array = [_rarity_label(rarity), group.capitalize()]
	if bool(option.get("is_parasite", false)):
		meta_parts.append("Parasite")
	var tags: Array = option.get("tags", []) as Array
	if not tags.is_empty():
		var tag_labels: Array = []
		for tag_variant in tags:
			tag_labels.append(str(tag_variant).capitalize())
		meta_parts.append("Tags: %s" % ", ".join(PackedStringArray(tag_labels)))
	if rarity_rank <= 0 and group != "weapon":
		var current_level := _get_current_mutation_level(player_index, str(option.get("id", "")))
		meta_parts.append("Lv %d -> Lv %d" % [current_level, current_level + 1])
	detail_meta.text = " | ".join(meta_parts)
	detail_description.text = str(option.get("description", ""))

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
	var rarity := str(entry.get("rarity", "common"))
	var rarity_rank := _rarity_rank(rarity)
	var group_color := IconFactoryData.get_group_color(str(entry.get("group", "attribute")))
	style.bg_color = Color(group_color.r * 0.16, group_color.g * 0.16, group_color.b * 0.16, 0.96)
	style.border_color = _rarity_color(rarity) if rarity_rank >= 1 else Color(group_color.r, group_color.g, group_color.b, 0.78)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.set_content_margin_all(6)
	chip.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = str(entry.get("name", "Mutation"))
	if int(entry.get("level", 1)) > 1 and rarity_rank <= 0:
		label.text += " Lv%d" % int(entry.get("level", 1))
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = _rarity_color(rarity) if rarity_rank >= 1 else Color(0.92, 0.96, 1.0, 0.94)
	chip.add_child(label)
	return chip

func _rarity_rank(rarity: String) -> int:
	match rarity:
		"signature":
			return 2
		"rare":
			return 1
		_:
			return 0

func _rarity_label(rarity: String) -> String:
	if rarity == "signature":
		return "Signature"
	if rarity == "rare":
		return "Rare"
	return "Common"

func _rarity_color(rarity: String) -> Color:
	if rarity == "signature":
		return Color(1.0, 0.44, 0.96, 0.96)
	if rarity == "rare":
		return Color(1.0, 0.82, 0.28, 0.9)
	return Color(0.92, 0.96, 1.0, 0.94)

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
	if config.has_method("uses_gamepad") and config.uses_gamepad():
		var gamepad_direction := _gamepad_direction(event, config)
		if gamepad_direction != 0:
			return gamepad_direction
	if config.has_method("uses_keyboard") and config.uses_keyboard():
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
	if config.has_method("uses_gamepad") and config.uses_gamepad() and event is InputEventJoypadButton:
		var joy_button := event as InputEventJoypadButton
		if joy_button.pressed and joy_button.button_index == JOY_BUTTON_A:
			return true
	return _event_matches_action(event, "p%d_secondary" % int(config.player_id)) if config.has_method("uses_keyboard") and config.uses_keyboard() else false

func _is_player_cancel_pressed(event: InputEvent, player_index: int) -> bool:
	var config = _player_configs[player_index]
	if config.has_method("uses_gamepad") and config.uses_gamepad() and _gamepad_direction_button(event, config, JOY_BUTTON_B):
		return true
	return _event_matches_action(event, "ui_cancel") if config.has_method("uses_keyboard") and config.uses_keyboard() else false

func _get_navigable_slot_count(player_index: int) -> int:
	var options: Array = _options_by_player[player_index]
	return options.size() + (2 if not options.is_empty() else 0)

func _get_reroll_cost(player_index: int) -> int:
	if player_index < 0 or player_index >= _reroll_costs_by_player.size():
		return 0
	return int(_reroll_costs_by_player[player_index])

func _is_reroll_affordable(player_index: int) -> bool:
	return _shared_run_score >= _get_reroll_cost(player_index)

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
