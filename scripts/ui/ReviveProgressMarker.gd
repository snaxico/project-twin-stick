class_name ReviveProgressMarker
extends Control

var _is_downed := false
var _progress_ratio := 0.0
var _tint := Color.WHITE

func _init() -> void:
	custom_minimum_size = Vector2(86.0, 46.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_state(is_downed: bool, progress_ratio: float, tint: Color) -> void:
	_is_downed = is_downed
	_progress_ratio = clampf(progress_ratio, 0.0, 1.0)
	_tint = tint
	visible = _is_downed
	queue_redraw()

func _draw() -> void:
	if not _is_downed:
		return
	var center := Vector2(size.x * 0.5, 18.0)
	var radius := 15.0
	draw_circle(center, radius + 4.0, Color(0.02, 0.03, 0.05, 0.82))
	draw_arc(center, radius, -PI * 0.5, PI * 1.5, 42, Color(0.22, 0.24, 0.3, 0.92), 4.0, true)
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * _progress_ratio, 42, _tint.lightened(0.22), 5.0, true)
	draw_string(get_theme_default_font(), Vector2(8.0, 42.0), "DOWNED", HORIZONTAL_ALIGNMENT_CENTER, size.x - 16.0, 13, Color(1.0, 0.28, 0.22, 0.96))
