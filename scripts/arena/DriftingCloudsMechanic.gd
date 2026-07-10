extends "res://scripts/arena/ArenaMechanic.gd"

const CLOUD_R := 200.0
const DRIFT := 60.0
const TICK := 0.6

var _centers := [Vector2(700, 700), Vector2(2900, 1400)]
var _dirs := [Vector2(0.86, 0.51).normalized(), Vector2(-0.89, -0.45).normalized()]
var _tick := TICK


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
			damage_circle(center, CLOUD_R, 4)
	queue_redraw()


func _draw() -> void:
	for center in _centers:
		draw_circle(center, CLOUD_R, Color(0.55, 0.66, 0.72, 0.24))
		draw_arc(center, CLOUD_R, 0.0, TAU, 48, Color(0.86, 0.94, 1.0, 0.42), 3.0)
