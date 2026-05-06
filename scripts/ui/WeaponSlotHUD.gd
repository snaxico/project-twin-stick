class_name WeaponSlotHUD
extends PanelContainer

var _name_label: Label = null
var _level_label: Label = null
var _cooldown_bar: ProgressBar = null
var _selected_style: StyleBoxFlat = null
var _unselected_style: StyleBoxFlat = null
var _empty_style: StyleBoxFlat = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(128.0, 54.0)
	_build()

func configure(slot_data: Dictionary, is_secondary: bool, align_right: bool = false) -> void:
	if _name_label == null:
		_build()
	var has_weapon: bool = str(slot_data.get("weapon_id", "")).strip_edges() != ""
	var is_selected: bool = bool(slot_data.get("selected", false))
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if align_right else HORIZONTAL_ALIGNMENT_LEFT
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if align_right else HORIZONTAL_ALIGNMENT_LEFT
	_name_label.text = str(slot_data.get("name", "---"))
	var level_value: int = int(slot_data.get("level", 0))
	_level_label.text = "" if level_value <= 0 else "Lv %d" % level_value
	if is_secondary:
		_cooldown_bar.visible = has_weapon
		var cooldown_duration: float = max(float(slot_data.get("cooldown_duration", 0.0)), 0.0)
		var cooldown_remaining: float = clamp(float(slot_data.get("cooldown_remaining", 0.0)), 0.0, cooldown_duration if cooldown_duration > 0.0 else 0.0)
		_cooldown_bar.max_value = max(cooldown_duration, 0.01)
		_cooldown_bar.value = cooldown_duration - cooldown_remaining
	else:
		_cooldown_bar.visible = false
	if not has_weapon:
		add_theme_stylebox_override("panel", _empty_style)
	elif is_selected:
		add_theme_stylebox_override("panel", _selected_style)
	else:
		add_theme_stylebox_override("panel", _unselected_style)

func _build() -> void:
	if _name_label != null:
		return
	_selected_style = _make_style(Color(0.96, 0.82, 0.28, 0.98), Color(0.08, 0.1, 0.14, 0.74), 3)
	_unselected_style = _make_style(Color(0.34, 0.42, 0.5, 0.72), Color(0.05, 0.07, 0.1, 0.54), 2)
	_empty_style = _make_style(Color(0.2, 0.24, 0.3, 0.52), Color(0.04, 0.05, 0.08, 0.32), 1)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 2)
	margin.add_child(layout)
	_name_label = Label.new()
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_name_label)
	_level_label = Label.new()
	layout.add_child(_level_label)
	_cooldown_bar = ProgressBar.new()
	_cooldown_bar.custom_minimum_size = Vector2(0.0, 10.0)
	_cooldown_bar.show_percentage = false
	layout.add_child(_cooldown_bar)
	add_theme_stylebox_override("panel", _unselected_style)

func _make_style(border_color: Color, bg_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style
