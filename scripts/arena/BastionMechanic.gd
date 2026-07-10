extends "res://scripts/arena/CoverMechanicBase.gd"

const RECTS := [
	Rect2(700, 800, 340, 500),
	Rect2(2560, 800, 340, 500),
]


func setup(arena: Rect2, players: Array, coop: Node) -> void:
	super.setup(arena, players, coop)
	_apply_rects(RECTS, true)


func _draw() -> void:
	for rect in RECTS:
		draw_rect(rect, Color(0.22, 0.28, 0.34, 0.34), true)
		draw_rect(rect, Color(0.68, 0.82, 0.92, 0.45), false, 2.0)
