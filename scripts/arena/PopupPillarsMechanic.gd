extends "res://scripts/arena/CoverMechanicBase.gd"

const SIZE := Vector2(260, 260)
const CENTERS := [Vector2(620, 560), Vector2(2720, 560), Vector2(620, 1280), Vector2(2720, 1280), Vector2(1670, 1480)]
const DELAYS := [0.0, -0.6, -1.2, -1.8, -2.4]
const PERIOD := 3.0
const UP_TIME := 1.8
const TELEGRAPH := 0.4

var _t := 0.0
var _current_rects: Array = []
var _warning_rects: Array = []


func setup(arena: Rect2, players: Array, coop: Node) -> void:
	super.setup(arena, players, coop)
	_current_rects = _compute_active_rects()
	_apply_rects(_current_rects, true)


func _physics_process(delta: float) -> void:
	_t += delta
	var next_rects := _compute_active_rects()
	_warning_rects = _compute_warning_rects()
	if not _same_rects(next_rects, _current_rects):
		_current_rects = next_rects
		_apply_rects(_current_rects, false)
	queue_redraw()


func _force_step() -> bool:
	_t += 1.0
	_current_rects = _compute_active_rects()
	_warning_rects = _compute_warning_rects()
	return _apply_rects(_current_rects, false)


func _compute_active_rects() -> Array:
	var rects: Array = []
	for index in range(CENTERS.size()):
		var phase := fmod(_t + float(DELAYS[index]), PERIOD)
		if phase < 0.0:
			phase += PERIOD
		if phase < UP_TIME:
			rects.append(Rect2(CENTERS[index] - SIZE * 0.5, SIZE))
	return rects


func _compute_warning_rects() -> Array:
	var rects: Array = []
	for index in range(CENTERS.size()):
		var phase := fmod(_t + float(DELAYS[index]), PERIOD)
		if phase < 0.0:
			phase += PERIOD
		if phase >= PERIOD - TELEGRAPH or (phase >= UP_TIME - TELEGRAPH and phase < UP_TIME):
			rects.append(Rect2(CENTERS[index] - SIZE * 0.5, SIZE))
	return rects


func _same_rects(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for index in range(a.size()):
		if (a[index] as Rect2) != (b[index] as Rect2):
			return false
	return true


func _draw() -> void:
	for rect in _current_rects:
		draw_rect(rect, Color(0.24, 0.3, 0.36, 0.32), true)
		draw_rect(rect, Color(0.72, 0.86, 1.0, 0.45), false, 2.0)
	for rect in _warning_rects:
		draw_rect(rect, Color(0.82, 0.9, 1.0, 0.12), true)
		draw_rect(rect, Color(0.82, 0.95, 1.0, 0.65), false, 3.0)
