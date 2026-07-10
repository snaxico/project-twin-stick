extends "res://scripts/arena/CoverMechanicBase.gd"

const XS := [560.0, 1040.0, 2560.0, 3040.0]
const YS := [520.0, 1050.0, 1580.0]
const SIZE := Vector2(220, 220)
const STEP := 2.5

var _up_parity := 0
var _timer := STEP
var _current_rects: Array = []


func setup(arena: Rect2, players: Array, coop: Node) -> void:
	super.setup(arena, players, coop)
	_current_rects = _rects_for_parity(_up_parity)
	_apply_rects(_current_rects, true)


func _physics_process(delta: float) -> void:
	if _tick_telegraph(delta):
		_current_rects = _telegraph_rects.duplicate()
		_apply_rects(_current_rects, false)
		return
	_timer -= delta
	if _timer <= 0.0 and _telegraph_rects.is_empty():
		_timer = STEP
		_up_parity = 1 - _up_parity
		_start_telegraph(_rects_for_parity(_up_parity))


func _force_step() -> bool:
	_up_parity = 1 - _up_parity
	_current_rects = _rects_for_parity(_up_parity)
	return _apply_rects(_current_rects, false)


func _rects_for_parity(parity: int) -> Array:
	var rects: Array = []
	for ci in range(XS.size()):
		for ri in range(YS.size()):
			if (ci + ri) % 2 == parity:
				rects.append(Rect2(Vector2(float(XS[ci]), float(YS[ri])) - SIZE * 0.5, SIZE))
	return rects


func _draw() -> void:
	for rect in _current_rects:
		draw_rect(rect, Color(0.22, 0.28, 0.34, 0.34), true)
		draw_rect(rect, Color(0.7, 0.84, 1.0, 0.5), false, 2.0)
	_draw_telegraph()
