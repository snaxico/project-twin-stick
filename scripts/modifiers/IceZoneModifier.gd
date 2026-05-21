class_name IceZoneModifier
extends Node2D

const CYCLE_DURATION := 10.0
const FORM_DURATION := 1.0
const FREEZE_DURATION := 8.0
const MELT_DURATION := CYCLE_DURATION - FORM_DURATION - FREEZE_DURATION

var _arena_rect := Rect2()
var _elapsed := 0.0

func setup(arena_rect: Rect2) -> void:
	_arena_rect = arena_rect
	queue_redraw()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()

func get_affected_players(player_nodes: Array) -> Array:
	var affected: Array = []
	if not _is_freezing():
		return affected
	for player in player_nodes:
		if player == null or not is_instance_valid(player) or not player.has_method("is_alive") or not player.is_alive():
			continue
		if _get_active_quadrants().has(_get_quadrant_for_point(player.global_position)):
			affected.append(player)
	return affected

func _is_freezing() -> bool:
	var phase_elapsed := _get_phase_elapsed()
	return phase_elapsed >= FORM_DURATION and phase_elapsed < FORM_DURATION + FREEZE_DURATION

func _get_active_quadrants() -> Array:
	return [1, 2] if int(floor(_elapsed / CYCLE_DURATION)) % 2 == 0 else [0, 3]

func _get_phase_elapsed() -> float:
	return fmod(_elapsed, CYCLE_DURATION)

func _get_quadrant_for_point(point: Vector2) -> int:
	var center := _arena_rect.position + _arena_rect.size * 0.5
	var left := point.x < center.x
	var top := point.y < center.y
	if left and top:
		return 0
	if not left and top:
		return 1
	if left and not top:
		return 2
	return 3

func _draw() -> void:
	var center := _arena_rect.position + _arena_rect.size * 0.5
	var quadrants := [
		Rect2(_arena_rect.position, _arena_rect.size * 0.5),
		Rect2(Vector2(center.x, _arena_rect.position.y), _arena_rect.size * 0.5),
		Rect2(Vector2(_arena_rect.position.x, center.y), _arena_rect.size * 0.5),
		Rect2(center, _arena_rect.size * 0.5),
	]
	var phase_elapsed := _get_phase_elapsed()
	var alpha := 0.10
	if phase_elapsed < FORM_DURATION:
		alpha = lerpf(0.06, 0.2, phase_elapsed / FORM_DURATION)
	elif _is_freezing():
		alpha = 0.2
	else:
		alpha = lerpf(0.2, 0.05, (phase_elapsed - (FORM_DURATION + FREEZE_DURATION)) / MELT_DURATION)
	for quadrant_index in _get_active_quadrants():
		draw_rect(quadrants[quadrant_index], Color(0.2, 0.74, 1.0, alpha), true)
