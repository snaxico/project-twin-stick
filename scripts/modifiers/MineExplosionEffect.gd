class_name MineExplosionEffect
extends Node2D

const LIFETIME := 0.22

var _elapsed := 0.0
var _radius := 86.0

func play(radius: float) -> void:
	_radius = maxf(radius, 1.0)
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LIFETIME:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress := clampf(_elapsed / LIFETIME, 0.0, 1.0)
	var ring_radius := lerpf(18.0, _radius, progress)
	var fill_radius := lerpf(12.0, _radius * 0.62, progress)
	var ring_alpha := lerpf(0.95, 0.0, progress)
	var fill_alpha := lerpf(0.32, 0.0, progress)
	draw_circle(Vector2.ZERO, fill_radius, Color(1.0, 0.68, 0.18, fill_alpha))
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48, Color(1.0, 0.94, 0.72, ring_alpha), 5.0)
	draw_arc(Vector2.ZERO, ring_radius * 0.72, 0.0, TAU, 40, Color(1.0, 0.35, 0.18, ring_alpha * 0.85), 3.0)
