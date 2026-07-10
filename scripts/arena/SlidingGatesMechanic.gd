extends "res://scripts/arena/CoverMechanicBase.gd"

const X := 2400.0
const WIDTH := 180.0
const TOP_Y := 290.0
const BOTTOM_Y := 1810.0
const GAP := 420.0
const GAP_YS := [610.0, 900.0, 1190.0]
const STEP := 1.5

var _gap_index := 0
var _timer := STEP
var _current_rects: Array = []


func setup(arena: Rect2, players: Array, coop: Node) -> void:
	super.setup(arena, players, coop)
	_current_rects = _rects_for_gap(float(GAP_YS[_gap_index]))
	_apply_rects(_current_rects, true)


func _physics_process(delta: float) -> void:
	if _tick_telegraph(delta):
		_current_rects = _telegraph_rects.duplicate()
		_apply_rects(_current_rects, false)
		return
	_timer -= delta
	if _timer <= 0.0 and _telegraph_rects.is_empty():
		_timer = STEP
		_gap_index = (_gap_index + 1) % GAP_YS.size()
		_start_telegraph(_rects_for_gap(float(GAP_YS[_gap_index])))


func _force_step() -> bool:
	_gap_index = (_gap_index + 1) % GAP_YS.size()
	_current_rects = _rects_for_gap(float(GAP_YS[_gap_index]))
	return _apply_rects(_current_rects, false)


func _rects_for_gap(gap_y: float) -> Array:
	return [
		Rect2(X, TOP_Y, WIDTH, maxf(0.0, gap_y - TOP_Y)),
		Rect2(X, gap_y + GAP, WIDTH, maxf(0.0, BOTTOM_Y - gap_y - GAP)),
	]


func _draw() -> void:
	for rect in _current_rects:
		draw_rect(rect, Color(0.22, 0.28, 0.34, 0.32), true)
		draw_rect(rect, Color(0.66, 0.84, 1.0, 0.48), false, 2.0)
	_draw_telegraph()
