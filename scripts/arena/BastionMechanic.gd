extends "res://scripts/arena/CoverMechanicBase.gd"

const RECT_LAYOUTS := [
	[Rect2(700, 800, 340, 500), Rect2(2560, 800, 340, 500)],
	[Rect2(820, 480, 500, 260), Rect2(2450, 1260, 300, 480)],
	[Rect2(620, 1280, 520, 240), Rect2(2640, 500, 260, 520)],
]

var _rects: Array = []


func setup(arena: Rect2, players: Array, coop: Node) -> void:
	super.setup(arena, players, coop)
	for rect_variant in RECT_LAYOUTS[_variant_index]:
		var local_rect := rect_variant as Rect2
		_rects.append(Rect2(_arena.position + local_rect.position, local_rect.size))
	_apply_rects(_rects, true)


func _draw() -> void:
	for rect in _rects:
		draw_rect(rect, Color(0.16, 0.48, 0.82, 0.78), true)
		draw_rect(rect, Color(0.62, 0.9, 1.0, 0.85), false, 2.0)
