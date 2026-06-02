class_name MapNodeButton
extends Button

const LABEL_FONT_SIZE := 11
const DOT_RADIUS := 4.0

var _node_data: Dictionary = {}
var _reachable := false
var _visited := false
var _current := false
var _modifier_colors: Array = []
var _pulse_phase := 0.0

func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty_style := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, empty_style)
	queue_redraw()

func configure(node_data: Dictionary, reachable: bool, visited: bool, current: bool, modifier_colors: Array) -> void:
	_node_data = node_data.duplicate(true)
	_reachable = reachable
	_visited = visited
	_current = current
	_modifier_colors = modifier_colors.duplicate()
	disabled = not reachable
	modulate = Color.WHITE
	set_process(_current)
	queue_redraw()

func _process(delta: float) -> void:
	_pulse_phase += delta * 3.4
	queue_redraw()

func _draw() -> void:
	var room_type := str(_node_data.get("room_type", "combat"))
	var center := Vector2(size.x * 0.5, 26.0)
	var base_color := _get_room_color(room_type)
	var icon_color := _get_icon_color(base_color)
	var ring_color := Color(icon_color.r, icon_color.g, icon_color.b, 0.22)

	if _current:
		var glow := 0.62 + 0.38 * (0.5 + 0.5 * sin(_pulse_phase))
		draw_circle(center, 25.0 + glow * 3.0, Color(base_color.r, base_color.g, base_color.b, 0.12 + glow * 0.12))
	if has_focus():
		draw_circle(center, 24.0, Color(0.96, 0.96, 1.0, 0.08))

	match room_type:
		"elite":
			_draw_hex(center, 18.0, ring_color, 4.0)
			_draw_elite_icon(center, icon_color)
		"boss":
			_draw_circle_outline(center, 18.0, ring_color, 4.0)
			_draw_boss_icon(center, icon_color)
		_:
			_draw_circle_outline(center, 18.0, ring_color, 4.0)
			_draw_combat_icon(center, icon_color)

	var label := _build_label()
	draw_string(
		ThemeDB.fallback_font,
		Vector2(center.x - 34.0, 58.0),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		68.0,
		LABEL_FONT_SIZE,
		Color(icon_color.r, icon_color.g, icon_color.b, 0.92)
	)

	if not _modifier_colors.is_empty():
		var total_width := float(_modifier_colors.size() - 1) * 12.0
		var start_x := center.x - total_width * 0.5
		for index in range(_modifier_colors.size()):
			var dot_center := Vector2(start_x + float(index) * 12.0, 76.0)
			draw_circle(dot_center, DOT_RADIUS, _modifier_colors[index])

func _draw_circle_outline(center: Vector2, radius: float, color: Color, width: float) -> void:
	draw_arc(center, radius, 0.0, TAU, 36, color, width)

func _draw_hex(center: Vector2, radius: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in range(6):
		var angle := -PI * 0.5 + TAU * float(index) / 6.0
		points.append(center + Vector2.RIGHT.rotated(angle) * radius)
	draw_polyline(points + PackedVector2Array([points[0]]), color, width, true)

func _draw_combat_icon(center: Vector2, color: Color) -> void:
	draw_line(center + Vector2(-7.0, 6.0), center + Vector2(7.0, -8.0), color, 2.2, true)
	draw_line(center + Vector2(-7.0, -8.0), center + Vector2(7.0, 6.0), color, 2.2, true)

func _draw_elite_icon(center: Vector2, color: Color) -> void:
	draw_circle(center + Vector2(-5.0, -2.0), 2.2, color)
	draw_circle(center + Vector2(5.0, -2.0), 2.2, color)
	draw_line(center + Vector2(-6.0, 8.0), center + Vector2(6.0, 8.0), color, 2.0, true)
	draw_line(center + Vector2(-2.0, 4.0), center + Vector2(-2.0, 10.0), color, 1.6, true)
	draw_line(center + Vector2(2.0, 4.0), center + Vector2(2.0, 10.0), color, 1.6, true)

func _draw_boss_icon(center: Vector2, color: Color) -> void:
	var crown := PackedVector2Array([
		center + Vector2(-10.0, 8.0),
		center + Vector2(-7.0, -4.0),
		center + Vector2(-1.0, 3.0),
		center + Vector2(0.0, -8.0),
		center + Vector2(1.0, 3.0),
		center + Vector2(7.0, -4.0),
		center + Vector2(10.0, 8.0),
	])
	draw_polyline(crown, color, 2.2, true)
	draw_line(center + Vector2(-10.0, 8.0), center + Vector2(10.0, 8.0), color, 2.2, true)

func _build_label() -> String:
	match str(_node_data.get("room_type", "combat")):
		"elite":
			return "Elite"
		"boss":
			return str(_node_data.get("boss_type", "Boss")).capitalize()
		_:
			return "Fight"

func _get_room_color(room_type: String) -> Color:
	if _current:
		return Color(1.0, 0.88, 0.42, 1.0)
	if room_type == "boss":
		return Color(0.92, 0.28, 0.24, 1.0)
	if room_type == "elite":
		return Color(0.96, 0.58, 0.18, 1.0)
	return Color(0.92, 0.94, 1.0, 1.0)

func _get_icon_color(base_color: Color) -> Color:
	if _current or _reachable:
		return base_color
	if _visited:
		return Color(0.5, 0.58, 0.68, 0.96)
	return Color(0.26, 0.29, 0.35, 0.96)
