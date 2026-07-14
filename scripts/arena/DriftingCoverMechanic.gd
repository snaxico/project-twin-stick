extends "res://scripts/arena/CoverMechanicBase.gd"

const SIZE := Vector2(260, 180)
const OFFSETS := [Vector2(300, 0), Vector2(-300, 0), Vector2(0, 300), Vector2(0, -300)]
const STEP := 2.0
const START_LAYOUTS := [
	[Vector2(800, 600), Vector2(2540, 1320)],
	[Vector2(1050, 1500), Vector2(2850, 650)],
	[Vector2(650, 1150), Vector2(2500, 500)],
]

var _centers: Array = []
var _timer := STEP
var _rng := RandomNumberGenerator.new()
var _current_rects: Array = []
var _pending_centers: Array = []


func setup(arena: Rect2, players: Array, coop: Node) -> void:
	super.setup(arena, players, coop)
	for center_variant in START_LAYOUTS[_variant_index]:
		_centers.append(_arena.position + center_variant as Vector2)
	_rng.seed = _room_seed
	_current_rects = _rects_for_centers(_centers)
	_apply_rects(_current_rects, true)


func _physics_process(delta: float) -> void:
	if _tick_telegraph(delta):
		var proposed_rects := _telegraph_rects.duplicate()
		if _apply_rects(proposed_rects, false):
			_current_rects = proposed_rects
			_centers = _pending_centers.duplicate()
		_pending_centers.clear()
		return
	_timer -= delta
	if _timer <= 0.0 and _telegraph_rects.is_empty():
		_timer = STEP
		_start_telegraph(_next_rects())


func _force_step() -> bool:
	for _attempt in range(8):
		var proposed_rects := _next_rects()
		if _apply_rects(proposed_rects, false):
			_current_rects = proposed_rects
			_centers = _pending_centers.duplicate()
			_pending_centers.clear()
			return true
	_pending_centers.clear()
	return false


func _next_rects() -> Array:
	var next_centers := _centers.duplicate()
	for index in range(next_centers.size()):
		for _attempt in range(6):
			var offset: Vector2 = OFFSETS[_rng.randi_range(0, OFFSETS.size() - 1)] as Vector2
			var candidate: Vector2 = (next_centers[index] as Vector2) + offset
			candidate.x = clampf(candidate.x, _arena.position.x + 360.0, _arena.end.x - 360.0)
			candidate.y = clampf(candidate.y, _arena.position.y + 300.0, _arena.end.y - 300.0)
			var candidate_centers := next_centers.duplicate()
			candidate_centers[index] = candidate
			var candidate_rects := _rects_for_centers(candidate_centers)
			if not _rects_overlap(candidate_rects[0] as Rect2, candidate_rects[1] as Rect2):
				next_centers = candidate_centers
				break
	_pending_centers = next_centers
	return _rects_for_centers(next_centers)


func _rects_for_centers(centers: Array) -> Array:
	var rects: Array = []
	for center in centers:
		rects.append(Rect2((center as Vector2) - SIZE * 0.5, SIZE))
	return rects


func _rects_overlap(a: Rect2, b: Rect2) -> bool:
	var inflation := 40.0
	if _coop != null and _coop.has_method("_get_flow_obstacle_inflation"):
		inflation = float(_coop._get_flow_obstacle_inflation())
	return a.grow(inflation).intersects(b.grow(inflation))


func _draw() -> void:
	for rect in _current_rects:
		draw_rect(rect, Color(0.16, 0.48, 0.82, 0.78), true)
		draw_rect(rect, Color(0.62, 0.9, 1.0, 0.85), false, 2.0)
	_draw_telegraph()
