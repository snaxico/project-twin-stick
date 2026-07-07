extends Node

const PlayerCombatIndicatorData = preload("res://scripts/ui/PlayerCombatIndicator.gd")
const ReviveProgressMarkerData = preload("res://scripts/ui/ReviveProgressMarker.gd")
const HealthBarHUDData = preload("res://scripts/juice/HealthBarHUD.gd")
const HudPaletteData = preload("res://scripts/game/HudPalette.gd")
const CoopFormat = preload("res://scripts/game/CoopFormat.gd")
const ClassVisualsData = preload("res://scripts/game/ClassVisuals.gd")

const HUD_HEALTH_COLOR := Color(0.24, 0.92, 0.34, 1.0)
const HUD_SLOT_2_COLOR := HudPaletteData.SLOT_2_COLOR
const HUD_ABILITY_TRIGGERS := ["A", "X", "B", "Y"]

var _coop: Node = null
var _ui_layer: CanvasLayer = null
var _hud_root: Control = null
var _player_combat_indicators: Array = []
var _revive_markers: Array = []
var _bottom_hud: HBoxContainer = null
var _bottom_player_hud_cards: Array = []
var _objective_label: Label = null
var _room_label: Label = null
var _xp_label: Label = null
var _score_label: Label = null
var _xp_fill: ColorRect = null
var _modifier_hud: VBoxContainer = null
var _objective_panel: PanelContainer = null
var _objective_icon_label: Label = null
var _objective_title_label: Label = null
var _objective_progress_label: Label = null
var _objective_progress_bar: ProgressBar = null
var _boss_health_bar = null


func setup(coop: Node, ui_layer: CanvasLayer) -> void:
	_coop = coop
	_ui_layer = ui_layer


func build() -> void:
	if _hud_root != null:
		_hud_root.queue_free()
	_hud_root = Control.new()
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_hud_root)

	var xp_panel := PanelContainer.new()
	xp_panel.position = Vector2(700.0, 20.0)
	xp_panel.size = Vector2(520.0, 88.0)
	_hud_root.add_child(xp_panel)
	var xp_margin := MarginContainer.new()
	xp_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	xp_margin.add_theme_constant_override("margin_left", 12)
	xp_margin.add_theme_constant_override("margin_top", 10)
	xp_margin.add_theme_constant_override("margin_right", 12)
	xp_margin.add_theme_constant_override("margin_bottom", 10)
	xp_panel.add_child(xp_margin)
	var xp_layout := VBoxContainer.new()
	xp_layout.add_theme_constant_override("separation", 6)
	xp_margin.add_child(xp_layout)
	_room_label = Label.new()
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_label.add_theme_font_size_override("font_size", 16)
	xp_layout.add_child(_room_label)
	var xp_track := ColorRect.new()
	xp_track.custom_minimum_size = Vector2(488.0, 14.0)
	xp_track.color = Color(0.07, 0.09, 0.12, 0.88)
	xp_layout.add_child(xp_track)
	_xp_fill = ColorRect.new()
	_xp_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_xp_fill.color = Color(0.28, 0.9, 0.82, 0.82)
	xp_track.add_child(_xp_fill)
	_xp_label = Label.new()
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_layout.add_child(_xp_label)
	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 12)
	_score_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.46, 0.96))
	xp_layout.add_child(_score_label)

	_boss_health_bar = HealthBarHUDData.new()
	_boss_health_bar.position = Vector2(700.0, 114.0)
	_boss_health_bar.size = Vector2(520.0, 36.0)
	_boss_health_bar.configure("Boss", Color(1.0, 0.22, 0.14, 0.95))
	_boss_health_bar.visible = false
	_hud_root.add_child(_boss_health_bar)
	_objective_label = Label.new()
	_objective_label.position = Vector2(24.0, 24.0)
	_objective_label.size = Vector2(520.0, 54.0)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.add_theme_font_size_override("font_size", 15)
	_objective_label.visible = false
	_hud_root.add_child(_objective_label)
	_build_objective_panel()

	_modifier_hud = VBoxContainer.new()
	_modifier_hud.position = Vector2(1520.0, 60.0)
	_modifier_hud.add_theme_constant_override("separation", 6)
	_hud_root.add_child(_modifier_hud)

	_bottom_hud = HBoxContainer.new()
	_bottom_hud.anchor_left = 0.0
	_bottom_hud.anchor_right = 1.0
	_bottom_hud.anchor_top = 1.0
	_bottom_hud.anchor_bottom = 1.0
	_bottom_hud.offset_left = 36.0
	_bottom_hud.offset_top = -118.0
	_bottom_hud.offset_right = -36.0
	_bottom_hud.offset_bottom = -20.0
	_bottom_hud.alignment = BoxContainer.ALIGNMENT_CENTER
	var player_configs := _get_player_configs()
	var player_count := player_configs.size()
	var card_width := 380.0 if player_count <= 2 else 280.0
	var card_separation := 14 if player_count <= 2 else 8
	var ability_font_size := 9 if player_count <= 2 else 8
	_bottom_hud.add_theme_constant_override("separation", card_separation)
	_hud_root.add_child(_bottom_hud)

	_player_combat_indicators.clear()
	_revive_markers.clear()
	_bottom_player_hud_cards.clear()
	for index in range(player_configs.size()):
		var indicator := PlayerCombatIndicatorData.new()
		var tint: Color = player_configs[index].tint
		var slot_1_color := CoopFormat.get_slot_color(tint, 0, HUD_SLOT_2_COLOR)
		var slot_2_color := CoopFormat.get_slot_color(tint, 1, HUD_SLOT_2_COLOR)
		indicator.configure_player(tint, slot_1_color, slot_2_color)
		_hud_root.add_child(indicator)
		_player_combat_indicators.append(indicator)
		var revive_marker := ReviveProgressMarkerData.new()
		revive_marker.set_state(false, 0.0, tint)
		_hud_root.add_child(revive_marker)
		_revive_markers.append(revive_marker)

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(card_width, 86.0)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(tint.r * 0.14, tint.g * 0.14, tint.b * 0.14, 0.84)
		card_style.border_color = tint.lightened(0.18)
		card_style.set_border_width_all(1)
		card_style.corner_radius_top_left = 8
		card_style.corner_radius_top_right = 8
		card_style.corner_radius_bottom_left = 8
		card_style.corner_radius_bottom_right = 8
		card.add_theme_stylebox_override("panel", card_style)
		_bottom_hud.add_child(card)

		var card_margin := MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 10)
		card_margin.add_theme_constant_override("margin_top", 8)
		card_margin.add_theme_constant_override("margin_right", 10)
		card_margin.add_theme_constant_override("margin_bottom", 8)
		card.add_child(card_margin)

		var card_layout := VBoxContainer.new()
		card_layout.add_theme_constant_override("separation", 4)
		card_margin.add_child(card_layout)

		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 8)
		card_layout.add_child(top_row)

		var header := Label.new()
		header.text = "P%d" % (index + 1)
		header.add_theme_font_size_override("font_size", 12)
		header.add_theme_color_override("font_color", tint.lightened(0.18))
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top_row.add_child(header)

		var passive_label := Label.new()
		passive_label.add_theme_font_size_override("font_size", 10)
		passive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		passive_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		card_layout.add_child(passive_label)

		var health_bar := ProgressBar.new()
		health_bar.show_percentage = false
		health_bar.min_value = 0.0
		health_bar.max_value = 100.0
		health_bar.value = 100.0
		health_bar.custom_minimum_size = Vector2(120.0, 10.0)
		_apply_progress_bar_tint(health_bar, HUD_HEALTH_COLOR, 0.92)
		card_layout.add_child(health_bar)

		var momentum_row := HBoxContainer.new()
		momentum_row.alignment = BoxContainer.ALIGNMENT_CENTER
		momentum_row.add_theme_constant_override("separation", 4)
		card_layout.add_child(momentum_row)
		var momentum_pips: Array = []
		for pip_index in range(4):
			var pip := ColorRect.new()
			pip.custom_minimum_size = Vector2(18.0, 5.0)
			pip.color = Color(tint.r, tint.g, tint.b, 0.18)
			momentum_row.add_child(pip)
			momentum_pips.append(pip)

		var passive_bar := ProgressBar.new()
		passive_bar.show_percentage = false
		passive_bar.min_value = 0.0
		passive_bar.max_value = 100.0
		passive_bar.value = 0.0
		passive_bar.custom_minimum_size = Vector2(120.0, 6.0)
		_apply_progress_bar_tint(passive_bar, tint.lightened(0.16), 0.82)
		card_layout.add_child(passive_bar)

		var ability_row := HBoxContainer.new()
		ability_row.add_theme_constant_override("separation", 8)
		card_layout.add_child(ability_row)

		var ability_slots: Array = []
		for slot_index in range(4):
			var slot_color := CoopFormat.get_slot_color(tint, slot_index, HUD_SLOT_2_COLOR)
			var slot_box := VBoxContainer.new()
			slot_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot_box.add_theme_constant_override("separation", 2)
			ability_row.add_child(slot_box)
			slot_box.add_child(_create_hud_trigger_label(str(HUD_ABILITY_TRIGGERS[slot_index]), slot_color))
			var slot_label := Label.new()
			slot_label.add_theme_font_size_override("font_size", ability_font_size)
			slot_label.add_theme_color_override("font_color", slot_color)
			slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			slot_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			slot_box.add_child(slot_label)
			var slot_charge_label := Label.new()
			slot_charge_label.add_theme_font_size_override("font_size", 9)
			slot_charge_label.add_theme_color_override("font_color", slot_color.lightened(0.28))
			slot_charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			slot_charge_label.visible = false
			slot_box.add_child(slot_charge_label)
			var slot_bar := ProgressBar.new()
			slot_bar.show_percentage = false
			slot_bar.min_value = 0.0
			slot_bar.max_value = 100.0
			slot_bar.value = 100.0
			slot_bar.custom_minimum_size = Vector2(74.0, 8.0)
			_apply_progress_bar_tint(slot_bar, slot_color, 0.82)
			slot_box.add_child(slot_bar)
			ability_slots.append({
				"label": slot_label,
				"charge_label": slot_charge_label,
				"bar": slot_bar,
			})

		_bottom_player_hud_cards.append({
			"header": header,
			"passive_label": passive_label,
			"health_bar": health_bar,
			"ability_slots": ability_slots,
			"momentum_row": momentum_row,
			"momentum_pips": momentum_pips,
			"passive_bar": passive_bar,
		})


func refresh() -> void:
	var xp_progress := RunState.get_xp_progress()
	var xp_ratio := clampf(float(xp_progress.get("current", 0)) / max(float(xp_progress.get("needed", 1)), 1.0), 0.0, 1.0)
	_xp_fill.scale = Vector2(max(xp_ratio, 0.01), 1.0)
	_xp_fill.anchor_right = xp_ratio
	_xp_label.text = "Lv %d  |  XP %d/%d  |  Pending Picks %d" % [
		int(xp_progress.get("level", 0)),
		int(xp_progress.get("current", 0)),
		int(xp_progress.get("needed", 80)),
		int(xp_progress.get("pending", 0)),
	]
	if _score_label != null:
		_score_label.text = "Score %d" % RunState.get_current_score()
	_room_label.text = _build_room_status_text()
	_objective_label.text = _build_side_objective_text()
	_refresh_objective_panel()
	refresh_boss()
	_update_player_combat_indicators()
	_refresh_bottom_hud()


func refresh_boss() -> void:
	var boss = _coop.call("get_active_boss")
	var boss_alive: bool = boss != null and is_instance_valid(boss) and boss.has_method("is_alive") and bool(boss.is_alive())
	if _boss_health_bar != null:
		_boss_health_bar.visible = boss_alive
	if not boss_alive:
		return
	var current_health := int(round(float(boss.current_health)))
	var max_health := int(round(float(boss.max_health)))
	var room_config := _coop.call("get_room_config") as Dictionary
	var title := CoopFormat.format_boss_type(str(room_config.get("boss_type", "")))
	_boss_health_bar.configure(title if not title.is_empty() else "Champion", Color(1.0, 0.22, 0.14, 0.95))
	_boss_health_bar.set_health(current_health, max_health)


func update_player_combat_indicator_positions() -> void:
	if _player_combat_indicators.is_empty():
		return
	var player_nodes := _get_player_nodes()
	var viewport_size: Vector2 = _coop.get_viewport_rect().size
	var canvas_transform: Transform2D = _coop.get_viewport().get_canvas_transform()
	for index in range(min(_player_combat_indicators.size(), player_nodes.size())):
		var indicator = _player_combat_indicators[index]
		var player = player_nodes[index]
		if indicator == null or not is_instance_valid(indicator) or player == null or not is_instance_valid(player):
			continue
		var screen_position: Vector2 = (canvas_transform * player.global_position).round()
		var indicator_size: Vector2 = indicator.custom_minimum_size
		var top_left := screen_position + Vector2(-indicator_size.x * 0.5, -20.0)
		top_left.x = clampf(top_left.x, 8.0, viewport_size.x - indicator_size.x - 8.0)
		top_left.y = clampf(top_left.y, 8.0, viewport_size.y - indicator_size.y - 8.0)
		indicator.position = top_left.round()
		if index < _revive_markers.size():
			var marker = _revive_markers[index]
			if marker != null and is_instance_valid(marker):
				var marker_size: Vector2 = marker.custom_minimum_size
				var marker_position := screen_position + Vector2(-marker_size.x * 0.5, indicator_size.y - 6.0)
				marker_position.x = clampf(marker_position.x, 8.0, viewport_size.x - marker_size.x - 8.0)
				marker_position.y = clampf(marker_position.y, 8.0, viewport_size.y - marker_size.y - 8.0)
				marker.position = marker_position.round()


func populate_modifier_hud() -> void:
	if _modifier_hud == null:
		return
	for child in _modifier_hud.get_children():
		child.queue_free()
	var modifier_definitions := _coop.call("get_modifier_definitions") as Dictionary
	for mod_id_variant in (_coop.call("get_active_modifiers") as Array):
		var mod_id := str(mod_id_variant)
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(0.0, 28.0)
		var style := StyleBoxFlat.new()
		style.bg_color = CoopFormat.get_modifier_chip_color(mod_id, modifier_definitions)
		style.set_border_width_all(1)
		style.border_color = CoopFormat.get_modifier_chip_color(mod_id, modifier_definitions).lightened(0.3)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.set_content_margin_all(6)
		chip.add_theme_stylebox_override("panel", style)
		var lbl := Label.new()
		lbl.text = CoopFormat.format_modifier_display_name(mod_id, modifier_definitions)
		chip.add_child(lbl)
		_modifier_hud.add_child(chip)


func format_objective_text() -> String:
	return _format_objective_text()


func build_side_objective_text() -> String:
	return _build_side_objective_text()


func _build_objective_panel() -> void:
	_objective_panel = PanelContainer.new()
	_objective_panel.position = Vector2(24.0, 20.0)
	_objective_panel.size = Vector2(460.0, 92.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.05, 0.08, 0.86)
	panel_style.border_color = Color(0.38, 0.88, 0.78, 0.72)
	panel_style.set_border_width_all(1)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	_objective_panel.add_theme_stylebox_override("panel", panel_style)
	_hud_root.add_child(_objective_panel)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_objective_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	_objective_icon_label = Label.new()
	_objective_icon_label.custom_minimum_size = Vector2(42.0, 0.0)
	_objective_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_objective_icon_label.add_theme_font_size_override("font_size", 26)
	row.add_child(_objective_icon_label)
	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 4)
	row.add_child(layout)
	_objective_title_label = Label.new()
	_objective_title_label.add_theme_font_size_override("font_size", 15)
	_objective_title_label.add_theme_color_override("font_color", Color(0.88, 0.98, 1.0, 0.96))
	layout.add_child(_objective_title_label)
	_objective_progress_label = Label.new()
	_objective_progress_label.add_theme_font_size_override("font_size", 12)
	_objective_progress_label.add_theme_color_override("font_color", Color(0.76, 0.86, 0.92, 0.9))
	layout.add_child(_objective_progress_label)
	_objective_progress_bar = ProgressBar.new()
	_objective_progress_bar.show_percentage = false
	_objective_progress_bar.min_value = 0.0
	_objective_progress_bar.max_value = 100.0
	_objective_progress_bar.custom_minimum_size = Vector2(340.0, 10.0)
	_apply_progress_bar_tint(_objective_progress_bar, Color(0.38, 0.88, 0.78, 1.0), 0.86)
	layout.add_child(_objective_progress_bar)


func _create_hud_trigger_label(text: String, tint: Color) -> Label:
	var trigger := Label.new()
	trigger.text = text
	trigger.add_theme_font_size_override("font_size", 9)
	trigger.add_theme_color_override("font_color", tint.lightened(0.25))
	trigger.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return trigger


func _apply_progress_bar_tint(bar: ProgressBar, tint: Color, alpha: float) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.04, 0.06, 0.09, 0.72)
	background.corner_radius_top_left = 3
	background.corner_radius_top_right = 3
	background.corner_radius_bottom_left = 3
	background.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(tint.r, tint.g, tint.b, alpha)
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill)


func _build_room_status_text() -> String:
	var room_type := str(_coop.call("get_room_type"))
	var room_depth := int(_coop.call("get_room_depth"))
	if room_type == "boss":
		var room_config := _coop.call("get_room_config") as Dictionary
		return "Room %d  |  %s  |  %s" % [room_depth, CoopFormat.format_room_type(room_type), CoopFormat.format_boss_type(str(room_config.get("boss_type", "")))]
	var time_left := maxf(float(_coop.call("get_room_duration")) - float(_coop.call("get_room_elapsed")), 0.0)
	if bool(_coop.call("is_spawning_done")):
		return "Room %d  |  %s  |  %d remaining" % [room_depth, CoopFormat.format_room_type(room_type), int(_coop.call("get_enemy_count"))]
	return "Room %d  |  %s  |  %ds  |  %d alive" % [room_depth, CoopFormat.format_room_type(room_type), int(ceil(time_left)), int(_coop.call("get_enemy_count"))]


func _format_objective_text() -> String:
	var view := _coop.call("get_side_objective_view") as Dictionary
	if bool(view.get("completed", false)):
		return "Complete"
	match str(view.get("id", "")):
		"hold_zone":
			var hold_zone = view.get("hold_zone", null)
			return hold_zone.get_progress_text() if hold_zone != null and is_instance_valid(hold_zone) else "Hold Zone"
		"kill_streak":
			return "Kill Streak %d/%d" % [int(view.get("kill_streak_progress", 0)), int(view.get("kill_streak_target", 0))]
		"collector":
			return "Collector %d/%d" % [int(view.get("collector_collected", 0)), int(view.get("collector_target", 1))]
		_:
			return ""


func _build_side_objective_text() -> String:
	var view := _coop.call("get_side_objective_view") as Dictionary
	var objective_id := str(view.get("id", ""))
	if objective_id.is_empty():
		return ""
	if bool(view.get("completed", false)):
		var offer := view.get("hold_buff_offer", {}) as Dictionary
		return "Objective complete: %s Buff" % CoopFormat.format_buff_name(str(offer.get("type", "")))
	match objective_id:
		"hold_zone":
			var hold_zone = view.get("hold_zone", null)
			return hold_zone.get_progress_text() if hold_zone != null and is_instance_valid(hold_zone) else ""
		"kill_streak":
			return "Kill Streak: %d/%d" % [int(view.get("kill_streak_progress", 0)), int(view.get("kill_streak_target", 0))]
		"collector":
			return "Collector: %d/%d orbs" % [int(view.get("collector_collected", 0)), int(view.get("collector_target", 1))]
		_:
			return ""


func _refresh_objective_panel() -> void:
	if _objective_panel == null:
		return
	var view := _coop.call("get_side_objective_view") as Dictionary
	var has_objective := not str(view.get("id", "")).is_empty()
	_objective_panel.visible = has_objective
	if not has_objective:
		return
	_objective_icon_label.text = _get_objective_icon_text()
	_objective_title_label.text = _get_objective_title_text()
	_objective_progress_label.text = _build_side_objective_text()
	_objective_progress_bar.value = _get_objective_progress_ratio() * 100.0


func _get_objective_icon_text() -> String:
	match str((_coop.call("get_side_objective_view") as Dictionary).get("id", "")):
		"hold_zone":
			return "H"
		"kill_streak":
			return "K"
		"collector":
			return "C"
		_:
			return "!"


func _get_objective_title_text() -> String:
	var view := _coop.call("get_side_objective_view") as Dictionary
	if bool(view.get("completed", false)):
		return "Objective Complete"
	match str(view.get("id", "")):
		"hold_zone":
			return "Hold Zone"
		"kill_streak":
			return "Kill Streak"
		"collector":
			return "Collect"
		_:
			return "Objective"


func _get_objective_progress_ratio() -> float:
	var view := _coop.call("get_side_objective_view") as Dictionary
	if bool(view.get("completed", false)):
		return 1.0
	match str(view.get("id", "")):
		"hold_zone":
			var hold_zone = view.get("hold_zone", null)
			return hold_zone.get_progress_ratio() if hold_zone != null and is_instance_valid(hold_zone) and hold_zone.has_method("get_progress_ratio") else 0.0
		"kill_streak":
			return clampf(float(view.get("kill_streak_progress", 0)) / maxf(float(view.get("kill_streak_target", 1)), 1.0), 0.0, 1.0)
		"collector":
			return clampf(float(view.get("collector_collected", 0)) / maxf(float(view.get("collector_target", 1)), 1.0), 0.0, 1.0)
		_:
			return 0.0


func _update_player_combat_indicators() -> void:
	var player_nodes := _get_player_nodes()
	var player_configs := _get_player_configs()
	for index in range(min(_player_combat_indicators.size(), player_nodes.size())):
		var player = player_nodes[index]
		var health_state: Dictionary = player.get_health_state()
		var slot_1_hud_data: Dictionary = player.get_ability_hud_data(0)
		var slot_2_hud_data: Dictionary = player.get_ability_hud_data(1)
		_player_combat_indicators[index].update_state(
			int(health_state.get("current", 0)),
			int(health_state.get("max", 1)),
			player.is_downed(),
			float(slot_1_hud_data.get("cooldown_remaining", 0.0)),
			float(slot_1_hud_data.get("cooldown_duration", 1.0)),
			float(slot_2_hud_data.get("cooldown_remaining", 0.0)),
			float(slot_2_hud_data.get("cooldown_duration", 1.0)),
			str(slot_1_hud_data.get("name", "")),
			str(slot_2_hud_data.get("name", ""))
		)
		if index < _revive_markers.size():
			var marker = _revive_markers[index]
			if marker != null and is_instance_valid(marker):
				var progress := float(_coop.call("get_revive_progress_for_player_id", player.player_id)) / float(_coop.call("get_revive_hold_duration"))
				marker.set_state(player.is_downed(), progress, player_configs[index].tint)


func _refresh_bottom_hud() -> void:
	var player_nodes := _get_player_nodes()
	for index in range(min(_bottom_player_hud_cards.size(), player_nodes.size())):
		var card: Dictionary = _bottom_player_hud_cards[index]
		var player = player_nodes[index]
		var health_state: Dictionary = player.get_health_state()
		_refresh_class_state_text(card, health_state, index)
		var health_ratio := clampf(float(health_state.get("current", 0)) / maxf(float(health_state.get("max", 1)), 1.0), 0.0, 1.0)
		(card.get("health_bar") as ProgressBar).value = health_ratio * 100.0
		var ability_slots: Array = card.get("ability_slots", []) as Array
		for slot_index in range(ability_slots.size()):
			var slot_hud_data: Dictionary = player.get_ability_hud_data(slot_index)
			var slot_duration := maxf(float(slot_hud_data.get("cooldown_duration", 1.0)), 0.01)
			var slot_ratio := 1.0 - clampf(float(slot_hud_data.get("cooldown_remaining", 0.0)) / slot_duration, 0.0, 1.0)
			if bool(slot_hud_data.get("is_ultimate", false)):
				slot_ratio = clampf(float(slot_hud_data.get("ready_ratio", 0.0)), 0.0, 1.0)
			var slot_nodes: Dictionary = ability_slots[slot_index] as Dictionary
			(slot_nodes.get("label") as Label).text = str(slot_hud_data.get("name", "Ability %d" % (slot_index + 1)))
			_update_slot_charge_label(slot_nodes.get("charge_label") as Label, slot_hud_data)
			(slot_nodes.get("bar") as ProgressBar).value = slot_ratio * 100.0
		_refresh_momentum_pips(card, index)


func _refresh_momentum_pips(card: Dictionary, player_index: int) -> void:
	var pips: Array = card.get("momentum_pips", []) as Array
	var tier := int(_coop.call("get_momentum_tier", player_index))
	var player_configs := _get_player_configs()
	var tint: Color = player_configs[player_index].tint if player_index < player_configs.size() else Color.WHITE
	for index in range(pips.size()):
		var pip: ColorRect = pips[index] as ColorRect
		if pip == null:
			continue
		pip.color = Color(tint.r, tint.g, tint.b, 0.92) if index < tier else Color(tint.r, tint.g, tint.b, 0.18)


func _refresh_class_state_text(card: Dictionary, health_state: Dictionary, player_index: int) -> void:
	var class_id := str(health_state.get("class_id", ""))
	var passive_id := str(health_state.get("passive_id", ""))
	var class_def := RunState.get_class_definition(class_id)
	var display_class_name := str(class_def.get("name", _format_inline_name(class_id)))
	var passive_name := _format_inline_name(passive_id)
	var accent := ClassVisualsData.get_accent_color(class_id)
	var header: Label = card.get("header", null)
	if header != null:
		header.text = "P%d  %s" % [player_index + 1, display_class_name]
		header.add_theme_color_override("font_color", accent.lightened(0.15))
	var passive_label: Label = card.get("passive_label", null)
	if passive_label == null:
		return
	var details := ""
	var passive_ratio := 0.0
	var show_momentum := passive_id == "momentum"
	var momentum_row: HBoxContainer = card.get("momentum_row", null)
	if momentum_row != null:
		momentum_row.visible = show_momentum
	var passive_bar: ProgressBar = card.get("passive_bar", null)
	if passive_bar != null:
		passive_bar.visible = not show_momentum and not passive_id.is_empty()
	if passive_id == "overheat":
		var heat := float(health_state.get("heat", 0.0))
		details = "Heat %d" % int(round(heat))
		passive_ratio = clampf(heat / 100.0, 0.0, 1.0)
	elif passive_id == "bloodthirst":
		var overshield := float(health_state.get("overshield", 0.0))
		var max_health := maxf(float(health_state.get("max", 1)), 1.0)
		details = "Overshield %d" % int(round(overshield))
		passive_ratio = clampf(overshield / maxf(max_health * 0.25, 1.0), 0.0, 1.0)
	elif passive_id == "momentum":
		details = "Momentum"
	elif passive_id == "radiance":
		var deployable_count := int(_coop.call("get_radiance_deployable_count", player_index)) if _coop != null and _coop.has_method("get_radiance_deployable_count") else 0
		details = "Radiance  %d active" % deployable_count
		passive_ratio = clampf(float(deployable_count) / 5.0, 0.0, 1.0)
	if passive_bar != null:
		passive_bar.value = passive_ratio * 100.0
		if passive_id == "overheat":
			_apply_progress_bar_tint(passive_bar, Color(1.0, 0.4, 0.16, 1.0), 0.86)
		elif passive_id == "bloodthirst":
			_apply_progress_bar_tint(passive_bar, Color(0.42, 0.78, 1.0, 1.0), 0.86)
		elif passive_id == "radiance":
			_apply_progress_bar_tint(passive_bar, Color(1.0, 0.88, 0.38, 1.0), 0.86)
	var detail_text := "  |  %s" % details if not details.is_empty() else ""
	passive_label.text = "%s%s" % [passive_name, detail_text]
	passive_label.add_theme_color_override("font_color", accent.lightened(0.28))


func _update_slot_charge_label(label: Label, slot_hud_data: Dictionary) -> void:
	if label == null:
		return
	if bool(slot_hud_data.get("is_ultimate", false)):
		label.visible = true
		label.text = "READY" if bool(slot_hud_data.get("is_ready", false)) else "%d%%" % int(round(float(slot_hud_data.get("ready_ratio", 0.0)) * 100.0))
		return
	var max_charges := int(slot_hud_data.get("charges_max", 1))
	if max_charges <= 1:
		label.visible = false
		label.text = ""
		return
	label.visible = true
	label.text = "%d/%d" % [int(slot_hud_data.get("charges_current", max_charges)), max_charges]


func _get_player_configs() -> Array:
	return _coop.call("get_player_configs") as Array


func _get_player_nodes() -> Array:
	return _coop.call("get_player_target_nodes") as Array


func _format_inline_name(raw_id: String) -> String:
	var parts: Array = []
	for part in raw_id.split("_"):
		if not part.is_empty():
			parts.append(part.capitalize())
	return " ".join(parts)
