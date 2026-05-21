class_name HoldZoneObjective
extends Node2D

signal completed

const HOLD_DURATION := 10.0
const ZONE_RADIUS := 180.0

var _hold_progress := 0.0
var _is_complete := false
var _zone_position := Vector2.ZERO
var _arena_rect := Rect2()

func setup(arena_rect: Rect2) -> void:
	_arena_rect = arena_rect
	var margin := Vector2(420.0, 280.0)
	var min_x := arena_rect.position.x + margin.x
	var max_x := arena_rect.end.x - margin.x
	var min_y := arena_rect.position.y + margin.y
	var max_y := arena_rect.end.y - margin.y
	_zone_position = Vector2(
		randf_range(min_x, max_x),
		randf_range(min_y, max_y)
	)
	position = _zone_position
	queue_redraw()

func update_zone(delta: float, player_nodes: Array) -> void:
	if _is_complete:
		return
	for player in player_nodes:
		if player == null or not is_instance_valid(player) or not player.has_method("is_alive") or not player.is_alive():
			continue
		if player.global_position.distance_to(_zone_position) <= ZONE_RADIUS:
			_hold_progress = min(_hold_progress + delta, HOLD_DURATION)
			if _hold_progress >= HOLD_DURATION:
				_is_complete = true
				completed.emit()
			queue_redraw()
			return
	queue_redraw()

func get_progress_ratio() -> float:
	return clampf(_hold_progress / HOLD_DURATION, 0.0, 1.0)

func get_progress_text() -> String:
	if _is_complete:
		return "Hold Zone Complete"
	return "Hold Zone: %.1f/%.1fs" % [_hold_progress, HOLD_DURATION]

func is_complete() -> bool:
	return _is_complete

func _draw() -> void:
	var outline_color := Color(0.18, 0.96, 0.84, 0.92) if not _is_complete else Color(0.44, 1.0, 0.68, 0.96)
	var fill_alpha := 0.10 + get_progress_ratio() * 0.22
	draw_circle(Vector2.ZERO, ZONE_RADIUS, Color(outline_color.r, outline_color.g, outline_color.b, fill_alpha))
	draw_arc(Vector2.ZERO, ZONE_RADIUS, 0.0, TAU, 64, outline_color, 6.0)
	draw_arc(Vector2.ZERO, ZONE_RADIUS - 18.0, -PI * 0.5, -PI * 0.5 + TAU * get_progress_ratio(), 64, outline_color.lightened(0.2), 10.0)
