extends "res://scripts/arena/CoverMechanicBase.gd"

const XS := [700.0, 1000.0, 1300.0, 1600.0, 1900.0, 2200.0, 2500.0, 2800.0]
const SIZE := Vector2(120, 520)
const Y := 790.0
const STEP := 2.0

var _x_index := 0
var _dir := 1
var _timer := STEP
var _current_rects: Array = []


func setup(arena: Rect2, players: Array, coop: Node) -> void:
	super.setup(arena, players, coop)
	_current_rects = [_rect_for_x(float(XS[_x_index]))]
	_apply_rects(_current_rects, true)


func _physics_process(delta: float) -> void:
	if _tick_telegraph(delta):
		_current_rects = _telegraph_rects.duplicate()
		_apply_rects(_current_rects, false)
		return
	_timer -= delta
	if _timer <= 0.0 and _telegraph_rects.is_empty():
		_timer = STEP
		_start_telegraph([_rect_for_x(_next_x())])


func _force_step() -> bool:
	_current_rects = [_rect_for_x(_next_x())]
	return _apply_rects(_current_rects, false)


func _next_x() -> float:
	_x_index += _dir
	if _x_index >= XS.size():
		_x_index = XS.size() - 2
		_dir = -1
	elif _x_index < 0:
		_x_index = 1
		_dir = 1
	return float(XS[_x_index])


func _rect_for_x(x: float) -> Rect2:
	return Rect2(Vector2(x, Y), SIZE)


func _draw() -> void:
	for rect in _current_rects:
		draw_rect(rect, Color(0.24, 0.3, 0.34, 0.34), true)
		draw_rect(rect, Color(0.72, 0.84, 0.96, 0.5), false, 2.0)
	_draw_telegraph()
