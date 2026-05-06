class_name WeaponSlotHUD
extends PanelContainer

const ICON_TEXTURE_PATHS := {
	"rifle": "res://assets/sprites/weapons/player_rifle.png",
	"scatter": "res://assets/sprites/weapons/player_scattergun.png",
	"spread": "res://assets/sprites/weapons/player_scattergun.png",
	"slug": "res://assets/sprites/weapons/player_slug.png",
}

static var _icon_cache: Dictionary = {}

var _icon_rect: TextureRect = null
var _placeholder_panel: Panel = null
var _placeholder_label: Label = null
var _level_badge: Label = null
var _cooldown_track: ColorRect = null
var _cooldown_fill: ColorRect = null
var _selected_style: StyleBoxFlat = null
var _unselected_style: StyleBoxFlat = null
var _empty_style: StyleBoxFlat = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(54.0, 54.0)
	_build()

func configure(slot_data: Dictionary, is_secondary: bool, _align_right: bool = false) -> void:
	if _icon_rect == null:
		_build()
	var weapon_id: String = str(slot_data.get("weapon_id", "")).strip_edges()
	var weapon_name: String = str(slot_data.get("name", "---"))
	var has_weapon: bool = not weapon_id.is_empty()
	var is_selected: bool = bool(slot_data.get("selected", false))
	var icon_texture: Texture2D = _get_icon_texture(weapon_id)
	_icon_rect.visible = has_weapon and icon_texture != null
	_placeholder_panel.visible = has_weapon and icon_texture == null
	if _icon_rect.visible:
		_icon_rect.texture = icon_texture
	if _placeholder_panel.visible:
		_placeholder_label.text = _build_placeholder_text(weapon_name, weapon_id)
	var level_value: int = int(slot_data.get("level", 0))
	_level_badge.visible = has_weapon and level_value > 0
	_level_badge.text = str(level_value)
	tooltip_text = "" if not has_weapon else "%s Lv%d" % [weapon_name, max(level_value, 1)]
	if is_secondary and has_weapon:
		_cooldown_track.visible = true
		var cooldown_duration: float = max(float(slot_data.get("cooldown_duration", 0.0)), 0.01)
		var cooldown_remaining: float = clamp(float(slot_data.get("cooldown_remaining", 0.0)), 0.0, cooldown_duration)
		var ready_ratio: float = clamp((cooldown_duration - cooldown_remaining) / cooldown_duration, 0.0, 1.0)
		_cooldown_fill.scale = Vector2(ready_ratio, 1.0)
	else:
		_cooldown_track.visible = false
		_cooldown_fill.scale = Vector2.ZERO
	if not has_weapon:
		add_theme_stylebox_override("panel", _empty_style)
	elif is_selected:
		add_theme_stylebox_override("panel", _selected_style)
	else:
		add_theme_stylebox_override("panel", _unselected_style)

func _build() -> void:
	if _icon_rect != null:
		return
	_selected_style = _make_style(Color(0.96, 0.82, 0.28, 0.92), Color(0.05, 0.07, 0.1, 0.34), 2)
	_unselected_style = _make_style(Color(0.34, 0.42, 0.5, 0.42), Color(0.04, 0.06, 0.09, 0.18), 1)
	_empty_style = _make_style(Color(0.2, 0.24, 0.3, 0.22), Color(0.04, 0.05, 0.08, 0.08), 1)
	add_theme_stylebox_override("panel", _unselected_style)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 4)
	root.add_theme_constant_override("margin_top", 4)
	root.add_theme_constant_override("margin_right", 4)
	root.add_theme_constant_override("margin_bottom", 4)
	add_child(root)

	var icon_frame := Control.new()
	icon_frame.custom_minimum_size = Vector2(46.0, 46.0)
	root.add_child(icon_frame)

	_icon_rect = TextureRect.new()
	_icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon_frame.add_child(_icon_rect)

	_placeholder_panel = Panel.new()
	_placeholder_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var placeholder_style := StyleBoxFlat.new()
	placeholder_style.bg_color = Color(0.12, 0.16, 0.2, 0.45)
	placeholder_style.corner_radius_top_left = 6
	placeholder_style.corner_radius_top_right = 6
	placeholder_style.corner_radius_bottom_left = 6
	placeholder_style.corner_radius_bottom_right = 6
	placeholder_style.border_color = Color(0.58, 0.66, 0.76, 0.34)
	placeholder_style.set_border_width_all(1)
	_placeholder_panel.add_theme_stylebox_override("panel", placeholder_style)
	icon_frame.add_child(_placeholder_panel)

	_placeholder_label = Label.new()
	_placeholder_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_placeholder_label.add_theme_font_size_override("font_size", 11)
	_placeholder_panel.add_child(_placeholder_label)

	_level_badge = Label.new()
	_level_badge.anchor_left = 1.0
	_level_badge.anchor_top = 0.0
	_level_badge.anchor_right = 1.0
	_level_badge.anchor_bottom = 0.0
	_level_badge.offset_left = -18.0
	_level_badge.offset_top = 0.0
	_level_badge.offset_right = 0.0
	_level_badge.offset_bottom = 16.0
	_level_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_badge.add_theme_font_size_override("font_size", 10)
	icon_frame.add_child(_level_badge)

	_cooldown_track = ColorRect.new()
	_cooldown_track.anchor_left = 0.0
	_cooldown_track.anchor_top = 1.0
	_cooldown_track.anchor_right = 1.0
	_cooldown_track.anchor_bottom = 1.0
	_cooldown_track.offset_left = 0.0
	_cooldown_track.offset_top = -6.0
	_cooldown_track.offset_right = 0.0
	_cooldown_track.offset_bottom = 0.0
	_cooldown_track.color = Color(0.08, 0.1, 0.14, 0.54)
	icon_frame.add_child(_cooldown_track)

	_cooldown_fill = ColorRect.new()
	_cooldown_fill.anchor_left = 0.0
	_cooldown_fill.anchor_top = 0.0
	_cooldown_fill.anchor_right = 1.0
	_cooldown_fill.anchor_bottom = 1.0
	_cooldown_fill.offset_left = 0.0
	_cooldown_fill.offset_top = 0.0
	_cooldown_fill.offset_right = 0.0
	_cooldown_fill.offset_bottom = 0.0
	_cooldown_fill.pivot_offset = Vector2.ZERO
	_cooldown_fill.color = Color(0.28, 0.9, 0.82, 0.74)
	_cooldown_track.add_child(_cooldown_fill)

func _make_style(border_color: Color, bg_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

func _build_placeholder_text(weapon_name: String, weapon_id: String) -> String:
	var resolved_id: String = weapon_id.strip_edges().to_upper()
	if resolved_id.begins_with("CLUSTER"):
		return "CL"
	if resolved_id.begins_with("HEAVY"):
		return "HV"
	if resolved_id.begins_with("SHRAPNEL"):
		return "SH"
	if resolved_id.begins_with("SIEGE"):
		return "SG"
	if resolved_id.begins_with("GRENADE"):
		return "GR"
	if resolved_id.begins_with("MINE"):
		return "MN"
	var compact_name: String = weapon_name.strip_edges()
	if compact_name.length() >= 2:
		return compact_name.substr(0, 2).to_upper()
	return resolved_id.substr(0, min(2, resolved_id.length()))

func _get_icon_texture(weapon_id: String) -> Texture2D:
	if weapon_id.is_empty():
		return null
	if _icon_cache.has(weapon_id):
		return _icon_cache[weapon_id] as Texture2D
	if not ICON_TEXTURE_PATHS.has(weapon_id):
		return null
	var texture: Texture2D = load(str(ICON_TEXTURE_PATHS[weapon_id])) as Texture2D
	if texture != null:
		_icon_cache[weapon_id] = texture
	return texture
