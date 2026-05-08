extends Control

const IconFactoryData = preload("res://scripts/ui/IconFactory.gd")

@onready var panel: Panel = $Panel
@onready var layout: VBoxContainer = $Panel/MarginContainer/Layout
@onready var title_label: Label = $Panel/MarginContainer/Layout/Title
@onready var detail_label: Label = $Panel/MarginContainer/Layout/Detail
@onready var status_label: Label = $Panel/MarginContainer/Layout/Status
@onready var slot_1_label: Label = $Panel/MarginContainer/Layout/SlotRow1
@onready var slot_2_label: Label = $Panel/MarginContainer/Layout/SlotRow2
@onready var hint_label: Label = $Panel/MarginContainer/Layout/Hint

var _incoming_icon_rect: TextureRect = null
var _incoming_meta_label: Label = null
var _slot_panels: Array = []
var _slot_icon_rects: Array = []
var _slot_name_labels: Array = []
var _slot_level_labels: Array = []

func setup_for_replacement(player_index: int, entry: Dictionary, slot_type: String, slot_rows: Array) -> void:
	_ensure_runtime_layout()
	title_label.text = "P%d Replace %s" % [player_index + 1, "Secondary" if slot_type == "secondary" else "Primary"]
	detail_label.text = str(entry.get("name", "Weapon"))
	_incoming_meta_label.text = "Lv%d" % max(int(entry.get("level", 1)), 1)
	_incoming_icon_rect.texture = IconFactoryData.get_weapon_icon(str(entry.get("id", "")))
	status_label.text = "Replace which slot?"
	_set_slot_panel(slot_rows, 0, true)
	_set_slot_panel(slot_rows, 1, false)
	hint_label.text = "Move left/right to choose. Confirm with Take / Interact. Cancel with Scrap."

func set_selected_slot(slot_rows: Array, selected_index: int) -> void:
	_ensure_runtime_layout()
	_set_slot_panel(slot_rows, 0, selected_index == 0)
	_set_slot_panel(slot_rows, 1, selected_index == 1)

func set_status_text(text: String) -> void:
	status_label.text = text

func _ensure_runtime_layout() -> void:
	if _incoming_icon_rect != null:
		return
	var detail_index: int = detail_label.get_index()
	var incoming_panel := PanelContainer.new()
	incoming_panel.custom_minimum_size = Vector2(0.0, 72.0)
	var incoming_margin := MarginContainer.new()
	incoming_margin.add_theme_constant_override("margin_left", 8)
	incoming_margin.add_theme_constant_override("margin_top", 8)
	incoming_margin.add_theme_constant_override("margin_right", 8)
	incoming_margin.add_theme_constant_override("margin_bottom", 8)
	incoming_panel.add_child(incoming_margin)
	var incoming_row := HBoxContainer.new()
	incoming_row.add_theme_constant_override("separation", 10)
	incoming_margin.add_child(incoming_row)

	_incoming_icon_rect = TextureRect.new()
	_incoming_icon_rect.custom_minimum_size = Vector2(48.0, 48.0)
	_incoming_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_incoming_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	incoming_row.add_child(_incoming_icon_rect)

	var incoming_text_column := VBoxContainer.new()
	incoming_text_column.add_theme_constant_override("separation", 2)
	incoming_text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	incoming_row.add_child(incoming_text_column)

	layout.remove_child(detail_label)
	incoming_text_column.add_child(detail_label)
	detail_label.add_theme_font_size_override("font_size", 18)

	_incoming_meta_label = Label.new()
	_incoming_meta_label.add_theme_font_size_override("font_size", 12)
	incoming_text_column.add_child(_incoming_meta_label)

	layout.add_child(incoming_panel)
	layout.move_child(incoming_panel, detail_index)

	slot_1_label.visible = false
	slot_2_label.visible = false
	var slot_insert_index: int = slot_1_label.get_index()
	for _index in range(2):
		var slot_panel := PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(0.0, 56.0)
		var slot_margin := MarginContainer.new()
		slot_margin.add_theme_constant_override("margin_left", 8)
		slot_margin.add_theme_constant_override("margin_top", 8)
		slot_margin.add_theme_constant_override("margin_right", 8)
		slot_margin.add_theme_constant_override("margin_bottom", 8)
		slot_panel.add_child(slot_margin)

		var slot_row := HBoxContainer.new()
		slot_row.add_theme_constant_override("separation", 10)
		slot_margin.add_child(slot_row)

		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(32.0, 32.0)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot_row.add_child(icon_rect)

		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_row.add_child(name_label)

		var level_label := Label.new()
		slot_row.add_child(level_label)

		layout.add_child(slot_panel)
		layout.move_child(slot_panel, slot_insert_index + _index)
		_slot_panels.append(slot_panel)
		_slot_icon_rects.append(icon_rect)
		_slot_name_labels.append(name_label)
		_slot_level_labels.append(level_label)

func _set_slot_panel(slot_rows: Array, slot_index: int, selected: bool) -> void:
	var panel: PanelContainer = _slot_panels[slot_index] as PanelContainer
	var icon_rect: TextureRect = _slot_icon_rects[slot_index] as TextureRect
	var name_label: Label = _slot_name_labels[slot_index] as Label
	var level_label: Label = _slot_level_labels[slot_index] as Label
	var row: Dictionary = slot_rows[slot_index] if slot_index < slot_rows.size() and slot_rows[slot_index] is Dictionary else {}
	var accent: Color = Color(0.96, 0.82, 0.28, 1.0)
	panel.add_theme_stylebox_override("panel", _build_slot_style(selected, accent))
	var name_text: String = str(row.get("name", "---"))
	var level_value: int = int(row.get("level", 0))
	icon_rect.texture = IconFactoryData.get_weapon_icon(str(row.get("weapon_id", "")))
	name_label.text = "Slot %d: %s" % [slot_index + 1, name_text]
	level_label.text = "" if level_value <= 0 else "Lv%d" % level_value

func _build_slot_style(selected: bool, accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.9) if selected else Color(0.06, 0.07, 0.1, 0.68)
	style.border_color = accent if selected else accent.darkened(0.4)
	style.set_border_width_all(2 if selected else 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
