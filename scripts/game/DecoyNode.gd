class_name DecoyNode
extends Node2D

var lifetime := 5.0
var current_health := 120
var tint := Color(0.8, 0.9, 1.0, 0.9)
var _alive := true

func configure(duration: float, color: Color, health_amount: int) -> void:
	lifetime = duration
	tint = color
	current_health = health_amount
	_alive = true
	add_to_group("player_target")
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		_expire()
		return
	queue_redraw()

func is_targetable() -> bool:
	return _alive

func is_alive() -> bool:
	return _alive

func apply_damage(amount: int) -> void:
	if not _alive:
		return
	current_health = max(current_health - amount, 0)
	if current_health <= 0:
		_expire()
	queue_redraw()

func _expire() -> void:
	if not _alive:
		return
	_alive = false
	if is_in_group("player_target"):
		remove_from_group("player_target")
	queue_free()

func _draw() -> void:
	var alpha := clampf(lifetime / 5.0, 0.0, 1.0)
	var color := Color(tint.r, tint.g, tint.b, 0.18 + alpha * 0.46)
	draw_circle(Vector2.ZERO, 28.0, color)
	draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 24, Color(tint.r, tint.g, tint.b, 0.62 + alpha * 0.2), 3.0)
