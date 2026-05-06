class_name PlayerInventoryHUD
extends PanelContainer

const HealthBarHUDData = preload("res://scripts/juice/HealthBarHUD.gd")
const WeaponSlotHUDData = preload("res://scripts/ui/WeaponSlotHUD.gd")

var _header_label: Label = null
var _gold_label: Label = null
var _health_bar = null
var _passive_label: Label = null
var _primary_slot_huds: Array = []
var _secondary_slot_huds: Array = []
var _primary_row: HBoxContainer = null
var _secondary_row: HBoxContainer = null
var _aligned_right: bool = false
var _panel_style: StyleBoxFlat = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(300.0, 196.0)
	_build()

func configure_player(player_label: String, tint: Color, align_right: bool = false) -> void:
	_aligned_right = align_right
	if _header_label == null:
		_build()
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if _aligned_right else HORIZONTAL_ALIGNMENT_LEFT
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if _aligned_right else HORIZONTAL_ALIGNMENT_LEFT
	_passive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if _aligned_right else HORIZONTAL_ALIGNMENT_LEFT
	if _primary_row != null:
		_primary_row.alignment = BoxContainer.ALIGNMENT_END if _aligned_right else BoxContainer.ALIGNMENT_BEGIN
	if _secondary_row != null:
		_secondary_row.alignment = BoxContainer.ALIGNMENT_END if _aligned_right else BoxContainer.ALIGNMENT_BEGIN
	_header_label.text = player_label
	_health_bar.configure("%s HP" % player_label, tint)
	_panel_style.border_color = tint.lightened(0.12)
	add_theme_stylebox_override("panel", _panel_style)

func update_hud(data: Dictionary) -> void:
	if _header_label == null:
		_build()
	_header_label.text = str(data.get("header", _header_label.text))
	_gold_label.text = "Gold: %d" % int(data.get("gold", 0))
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

func _build() -> void:
	if _header_label != null:
		return
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(0.04, 0.06, 0.09, 0.58)
	_panel_style.border_color = Color(0.4, 0.46, 0.54, 0.8)
	_panel_style.set_border_width_all(2)
	_panel_style.corner_radius_top_left = 8
	_panel_style.corner_radius_top_right = 8
	_panel_style.corner_radius_bottom_left = 8
	_panel_style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", _panel_style)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	_header_label = Label.new()
	layout.add_child(_header_label)
	_gold_label = Label.new()
	layout.add_child(_gold_label)
	_health_bar = HealthBarHUDData.new()
	_health_bar.custom_minimum_size = Vector2(0.0, 38.0)
	layout.add_child(_health_bar)
	_primary_row = HBoxContainer.new()
	_primary_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_primary_row.add_theme_constant_override("separation", 6)
	layout.add_child(_primary_row)
	_secondary_row = HBoxContainer.new()
	_secondary_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_secondary_row.add_theme_constant_override("separation", 6)
	layout.add_child(_secondary_row)
	for _index in range(2):
		var primary_slot := WeaponSlotHUDData.new()
		_primary_row.add_child(primary_slot)
		_primary_slot_huds.append(primary_slot)
		var secondary_slot := WeaponSlotHUDData.new()
		_secondary_row.add_child(secondary_slot)
		_secondary_slot_huds.append(secondary_slot)
	_passive_label = Label.new()
	_passive_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_passive_label.modulate = Color(1.0, 1.0, 1.0, 0.82)
	_passive_label.visible = false
	layout.add_child(_passive_label)
	_passive_label.text = _build_passive_text([])

func _build_passive_text(passive_names: Array) -> String:
	if passive_names.is_empty():
		return "Passives: None"
	return "Passives: %s" % ", ".join(passive_names)
