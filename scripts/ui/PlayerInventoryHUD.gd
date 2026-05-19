class_name PlayerInventoryHUD
extends PanelContainer

const HealthBarHUDData = preload("res://scripts/juice/HealthBarHUD.gd")
const WeaponSlotHUDData = preload("res://scripts/ui/WeaponSlotHUD.gd")
const IconFactoryData = preload("res://scripts/ui/IconFactory.gd")

var _header_label: Label = null
var _health_bar = null
var _weapon_slot: WeaponSlotHUD = null
var _primary_skill_slot: WeaponSlotHUD = null
var _secondary_skill_slot: WeaponSlotHUD = null
var _mutation_row: HBoxContainer = null
var _panel_style: StyleBoxFlat = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(220.0, 132.0)
	_build()

func configure_player(player_label: String, tint: Color) -> void:
	if _header_label == null:
		_build()
	_header_label.text = player_label
	_health_bar.configure("", tint)
	_panel_style.border_color = tint.lightened(0.1)
	add_theme_stylebox_override("panel", _panel_style)

func update_hud(data: Dictionary) -> void:
	if _header_label == null:
		_build()
	_header_label.text = str(data.get("header", _header_label.text))
	var health_state: Dictionary = data.get("health_state", {}) as Dictionary
	_health_bar.set_health(int(health_state.get("current", 0)), int(health_state.get("max", 1)), str(data.get("health_status", "")))
	_weapon_slot.configure(data.get("weapon", {}) as Dictionary, false)
	_primary_skill_slot.configure(data.get("primary_skill", {}) as Dictionary, true)
	_secondary_skill_slot.configure(data.get("secondary_skill", {}) as Dictionary, true)
	_update_mutation_icons(data.get("mutations", []))

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
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)

	_header_label = Label.new()
	layout.add_child(_header_label)

	_health_bar = HealthBarHUDData.new()
	_health_bar.custom_minimum_size = Vector2(0.0, 30.0)
	layout.add_child(_health_bar)

	var weapon_row := HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 6)
	layout.add_child(weapon_row)

	_weapon_slot = WeaponSlotHUDData.new()
	weapon_row.add_child(_weapon_slot)
	_primary_skill_slot = WeaponSlotHUDData.new()
	weapon_row.add_child(_primary_skill_slot)
	_secondary_skill_slot = WeaponSlotHUDData.new()
	weapon_row.add_child(_secondary_skill_slot)

	_mutation_row = HBoxContainer.new()
	_mutation_row.add_theme_constant_override("separation", 4)
	layout.add_child(_mutation_row)

func _update_mutation_icons(mutations: Array) -> void:
	for child in _mutation_row.get_children():
		_mutation_row.remove_child(child)
		child.queue_free()
	if mutations.is_empty():
		return
	for mutation in mutations:
		if not (mutation is Dictionary):
			continue
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(22.0, 22.0)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.16, 0.2, 0.28)
		style.border_color = Color(0.8, 0.88, 0.98, 0.3)
		style.set_border_width_all(1)
		style.corner_radius_top_left = 5
		style.corner_radius_top_right = 5
		style.corner_radius_bottom_left = 5
		style.corner_radius_bottom_right = 5
		chip.add_theme_stylebox_override("panel", style)
		chip.tooltip_text = "%s\n%s" % [str((mutation as Dictionary).get("name", "")), str((mutation as Dictionary).get("description", ""))]
		var icon := TextureRect.new()
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = IconFactoryData.get_mutation_icon(str((mutation as Dictionary).get("id", "")))
		chip.add_child(icon)
		_mutation_row.add_child(chip)
