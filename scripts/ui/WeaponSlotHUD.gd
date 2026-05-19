class_name WeaponSlotHUD
extends PanelContainer

const IconFactoryData = preload("res://scripts/ui/IconFactory.gd")

var _icon_rect: TextureRect = null
var _name_label: Label = null
var _cooldown_track: ColorRect = null
var _cooldown_fill: ColorRect = null
var _charges_label: Label = null
var _panel_style: StyleBoxFlat = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(64.0, 64.0)
	_build()

func configure(slot_data: Dictionary, is_secondary: bool) -> void:
	if _icon_rect == null:
		_build()
	var weapon_id := str(slot_data.get("weapon_id", ""))
	var weapon_name := str(slot_data.get("name", "---"))
	_name_label.text = weapon_name
	_name_label.visible = false
	tooltip_text = weapon_name
	_icon_rect.texture = IconFactoryData.get_weapon_icon(weapon_id)
	_icon_rect.visible = _icon_rect.texture != null
	if is_secondary:
		_cooldown_track.visible = true
		var cooldown_duration: float = maxf(float(slot_data.get("cooldown_duration", 0.0)), 0.01)
		var cooldown_remaining: float = clampf(float(slot_data.get("cooldown_remaining", 0.0)), 0.0, cooldown_duration)
		var ready_ratio: float = clampf((cooldown_duration - cooldown_remaining) / cooldown_duration, 0.0, 1.0)
		_cooldown_fill.scale = Vector2(ready_ratio, 1.0)
		var charges_current: int = int(slot_data.get("charges_current", 1))
		var charges_max: int = int(slot_data.get("charges_max", 1))
		_charges_label.visible = charges_max > 1
		_charges_label.text = "%d/%d" % [charges_current, charges_max]
	else:
		_cooldown_track.visible = false
		_cooldown_fill.scale = Vector2.ONE
		_charges_label.visible = false

func _build() -> void:
	if _icon_rect != null:
		return
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(0.04, 0.06, 0.09, 0.2)
	_panel_style.border_color = Color(0.42, 0.48, 0.58, 0.42)
	_panel_style.set_border_width_all(1)
	_panel_style.corner_radius_top_left = 6
	_panel_style.corner_radius_top_right = 6
	_panel_style.corner_radius_bottom_left = 6
	_panel_style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", _panel_style)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 6)
	root.add_theme_constant_override("margin_top", 6)
	root.add_theme_constant_override("margin_right", 6)
	root.add_theme_constant_override("margin_bottom", 6)
	add_child(root)

	var icon_frame := Control.new()
	icon_frame.custom_minimum_size = Vector2(50.0, 50.0)
	root.add_child(icon_frame)

	_icon_rect = TextureRect.new()
	_icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_frame.add_child(_icon_rect)

	_name_label = Label.new()
	_name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 10)
	icon_frame.add_child(_name_label)

	_cooldown_track = ColorRect.new()
	_cooldown_track.anchor_left = 0.0
	_cooldown_track.anchor_top = 1.0
	_cooldown_track.anchor_right = 1.0
	_cooldown_track.anchor_bottom = 1.0
	_cooldown_track.offset_top = -6.0
	_cooldown_track.color = Color(0.08, 0.1, 0.14, 0.54)
	icon_frame.add_child(_cooldown_track)

	_cooldown_fill = ColorRect.new()
	_cooldown_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cooldown_fill.color = Color(0.28, 0.9, 0.82, 0.74)
	_cooldown_track.add_child(_cooldown_fill)

	_charges_label = Label.new()
	_charges_label.anchor_left = 1.0
	_charges_label.anchor_top = 0.0
	_charges_label.anchor_right = 1.0
	_charges_label.anchor_bottom = 0.0
	_charges_label.offset_left = -30.0
	_charges_label.offset_right = 0.0
	_charges_label.offset_bottom = 16.0
	_charges_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_charges_label.add_theme_font_size_override("font_size", 10)
	icon_frame.add_child(_charges_label)
