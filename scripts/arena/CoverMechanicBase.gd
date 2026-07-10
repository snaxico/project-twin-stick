extends "res://scripts/arena/ArenaMechanic.gd"
class_name CoverMechanicBase

const MOVE_TELEGRAPH := 0.5

var revision := 0
var _telegraph_rects: Array = []
var _telegraph_time := 0.0


func setup(arena: Rect2, players: Array, coop: Node) -> void:
	super.setup(arena, players, coop)


func _apply_rects(rects: Array, initial := false) -> bool:
	if _coop == null or not _coop.has_method("rebuild_obstacles"):
		return false
	var applied := bool(_coop.rebuild_obstacles(rects, initial))
	if applied and not initial:
		revision += 1
	_telegraph_rects.clear()
	_telegraph_time = 0.0
	queue_redraw()
	return applied


func profiling_force_step() -> bool:
	return _force_step()


func _force_step() -> bool:
	return false


func _start_telegraph(rects: Array) -> void:
	_telegraph_rects = rects.duplicate()
	_telegraph_time = MOVE_TELEGRAPH
	queue_redraw()


func _tick_telegraph(delta: float) -> bool:
	if _telegraph_time <= 0.0:
		return false
	_telegraph_time -= delta
	queue_redraw()
	return _telegraph_time <= 0.0


func _draw_telegraph() -> void:
	for rect_variant in _telegraph_rects:
		var rect: Rect2 = rect_variant as Rect2
		draw_rect(rect, Color(0.82, 0.9, 1.0, 0.12), true)
		draw_rect(rect, Color(0.82, 0.95, 1.0, 0.55), false, 2.0)
