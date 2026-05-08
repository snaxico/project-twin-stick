class_name PlayerInventoryHUD
extends PanelContainer

const HealthBarHUDData = preload("res://scripts/juice/HealthBarHUD.gd")
const WeaponSlotHUDData = preload("res://scripts/ui/WeaponSlotHUD.gd")
const IconFactoryData = preload("res://scripts/ui/IconFactory.gd")

var _header_label: Label = null
var _gold_label: Label = null
var _gold_icon_rect: TextureRect = null
var _health_bar = null
var _primary_slot_huds: Array = []
var _secondary_slot_huds: Array = []
var _passive_row: HBoxContainer = null
var _aligned_right: bool = false
var _panel_style: StyleBoxFlat = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(220.0, 146.0)
	_build()

func configure_player(player_label: String, tint: Color, align_right: bool = false) -> void:
	_aligned_right = align_right
	if _header_label == null:
		_build()
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if _aligned_right else HORIZONTAL_ALIGNMENT_LEFT
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if _aligned_right else HORIZONTAL_ALIGNMENT_LEFT
	if _passive_row != null:
		_passive_row.alignment = BoxContainer.ALIGNMENT_END if _aligned_right else BoxContainer.ALIGNMENT_BEGIN
	_header_label.text = player_label
	_health_bar.configure("", tint)
	_panel_style.border_color = tint.lightened(0.1)
	add_theme_stylebox_override("panel", _panel_style)

func update_hud(data: Dictionary) -> void:
	if _header_label == null:
		_build()
	_header_label.text = str(data.get("header", _header_label.text))
	_gold_label.text = str(int(data.get("gold", 0)))
	var health_state: Dictionary = data.get("health_state", {})
	var health_status: String = str(data.get("health_status", ""))
	_health_bar.set_health(int(health_state.get("current", 0)), int(health_state.get("max", 1)), health_status)
	var primary_slots: Array = data.get("primary_slots", [])
	var secondary_slots: Array = data.get("secondary_slots", [])
	for slot_index in range(_primary_slot_huds.size()):
		var slot_data: Dictionary = primary_slots[slot_index] if slot_index < primary_slots.size() and primary_slots[slot_index] is Dictionary else {}
		var primary_slot_hud = _primary_slot_huds[slot_index]
		primary_slot_hud.configure(slot_data, false, _aligned_right)
	for slot_index in range(_secondary_slot_huds.size()):
		var slot_data: Dictionary = secondary_slots[slot_index] if slot_index < secondary_slots.size() and secondary_slots[slot_index] is Dictionary else {}
		var secondary_slot_hud = _secondary_slot_huds[slot_index]
		secondary_slot_hud.configure(slot_data, true, _aligned_right)
	_update_passive_icons(data.get("passives", []))

func _build() -> void:
	if _header_label != null:
		return
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(0.04, 0.06, 0.09, 0.28)
	_panel_style.border_color = Color(0.38, 0.44, 0.52, 0.46)
	_panel_style.set_border_width_all(1)
	_panel_style.corner_radius_top_left = 8
	_panel_style.corner_radius_top_right = 8
	_panel_style.corner_radius_bottom_left = 8
	_panel_style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", _panel_style)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 5)
	margin.add_child(layout)

	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	top_row.add_theme_constant_override("separation", 4)
	layout.add_child(top_row)

	_header_label = Label.new()
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_header_label)

	var gold_row := HBoxContainer.new()
	gold_row.alignment = BoxContainer.ALIGNMENT_END
	gold_row.add_theme_constant_override("separation", 4)
	top_row.add_child(gold_row)

	_gold_icon_rect = TextureRect.new()
	_gold_icon_rect.custom_minimum_size = Vector2(16.0, 16.0)
	_gold_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gold_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gold_icon_rect.texture = IconFactoryData.get_ui_icon("gold")
	gold_row.add_child(_gold_icon_rect)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 12)
	gold_row.add_child(_gold_label)

	_health_bar = HealthBarHUDData.new()
	_health_bar.custom_minimum_size = Vector2(0.0, 30.0)
	layout.add_child(_health_bar)

	var primary_row := HBoxContainer.new()
	primary_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	primary_row.add_theme_constant_override("separation", 4)
	layout.add_child(primary_row)

	var secondary_row := HBoxContainer.new()
	secondary_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	secondary_row.add_theme_constant_override("separation", 4)
	layout.add_child(secondary_row)

	for _index in range(2):
		var primary_slot := WeaponSlotHUDData.new()
		primary_row.add_child(primary_slot)
		_primary_slot_huds.append(primary_slot)
		var secondary_slot := WeaponSlotHUDData.new()
		secondary_row.add_child(secondary_slot)
		_secondary_slot_huds.append(secondary_slot)

	_passive_row = HBoxContainer.new()
	_passive_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_passive_row.add_theme_constant_override("separation", 4)
	layout.add_child(_passive_row)

func _update_passive_icons(passive_entries: Array) -> void:
	if _passive_row == null:
		return
	for child in _passive_row.get_children():
		_passive_row.remove_child(child)
		child.queue_free()
	if passive_entries.is_empty():
		var empty_chip := _build_empty_passive_chip()
		empty_chip.modulate.a = 0.45
		_passive_row.add_child(empty_chip)
		return
	var display_count: int = mini(passive_entries.size(), 4)
	for index in range(display_count):
		var passive_entry: Dictionary = passive_entries[index] if passive_entries[index] is Dictionary else {}
		_passive_row.add_child(_build_passive_chip_icon(passive_entry))
	if passive_entries.size() > display_count:
		_passive_row.add_child(_build_passive_count_chip(passive_entries.size() - display_count))

func _build_passive_chip_icon(passive_entry: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(24.0, 20.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.16, 0.2, 0.28)
	style.border_color = Color(0.8, 0.88, 0.98, 0.3)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style)
	panel.tooltip_text = str(passive_entry.get("name", str(passive_entry.get("id", ""))))
	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = IconFactoryData.get_passive_icon(str(passive_entry.get("id", "")))
	panel.add_child(icon)
	return panel

func _build_empty_passive_chip() -> Control:
	var panel := _build_passive_count_chip(0)
	panel.tooltip_text = "No passives"
	var label: Label = panel.get_child(0) as Label
	if label != null:
		label.text = "--"
	return panel

func _build_passive_count_chip(hidden_count: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(24.0, 20.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.16, 0.2, 0.28)
	style.border_color = Color(0.8, 0.88, 0.98, 0.3)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.text = "+%d" % hidden_count if hidden_count > 0 else "--"
	panel.add_child(label)
	return panel
