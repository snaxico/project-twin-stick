extends "res://scripts/arena/ArenaMechanic.gd"

const CLOUD_R := 200.0
const DRIFT := 60.0
const TICK := 0.75
const CENTER_LAYOUTS := [
	[Vector2(700, 700), Vector2(2900, 1400)],
	[Vector2(900, 1500), Vector2(2700, 600)],
	[Vector2(600, 1050), Vector2(2450, 1450)],
]
const DIRECTION_LAYOUTS := [
	[Vector2(0.86, 0.51), Vector2(-0.89, -0.45)],
	[Vector2(0.8, -0.6), Vector2(-0.7, 0.7)],
	[Vector2(0.9, 0.2), Vector2(-0.8, -0.5)],
]

var _centers: Array = []
var _dirs: Array = []
var _tick := TICK


func setup(arena: Rect2, players: Array, coop: Node) -> void:
	super.setup(arena, players, coop)
	for center_variant in CENTER_LAYOUTS[_variant_index]:
		_centers.append(_arena.position + center_variant as Vector2)
	for direction_variant in DIRECTION_LAYOUTS[_variant_index]:
		_dirs.append((direction_variant as Vector2).normalized())


func _physics_process(delta: float) -> void:
	for index in range(_centers.size()):
		var center: Vector2 = _centers[index]
		var dir: Vector2 = _dirs[index]
		center += dir * DRIFT * delta
		if center.x < _arena.position.x + CLOUD_R or center.x > _arena.end.x - CLOUD_R:
			dir.x *= -1.0
			center.x = clampf(center.x, _arena.position.x + CLOUD_R, _arena.end.x - CLOUD_R)
		if center.y < _arena.position.y + CLOUD_R or center.y > _arena.end.y - CLOUD_R:
			dir.y *= -1.0
			center.y = clampf(center.y, _arena.position.y + CLOUD_R, _arena.end.y - CLOUD_R)
		_centers[index] = center
		_dirs[index] = dir
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		for center in _centers:
			damage_circle(center, CLOUD_R, 8, true, false)
	queue_redraw()


func _draw() -> void:
	for center in _centers:
		draw_circle(center, CLOUD_R, Color(0.72, 0.82, 0.9, 0.2))
		draw_arc(center, CLOUD_R, 0.0, TAU, 48, Color(0.72, 0.82, 0.9, 0.5), 3.0)
