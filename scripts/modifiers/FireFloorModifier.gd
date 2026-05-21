class_name FireFloorModifier
extends Node2D

const CYCLE_DURATION := 10.0
const IGNITE_DURATION := 1.0
const BURN_DURATION := 8.0
const EXTINGUISH_DURATION := CYCLE_DURATION - IGNITE_DURATION - BURN_DURATION
const DAMAGE_INTERVAL := 0.5
const DAMAGE_AMOUNT := 5

var _arena_rect := Rect2()
var _player_nodes: Array = []
var _elapsed := 0.0
var _damage_tick_remaining := DAMAGE_INTERVAL

func setup(arena_rect: Rect2, player_nodes: Array) -> void:
	_arena_rect = arena_rect
	_player_nodes = player_nodes
	queue_redraw()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	_damage_tick_remaining -= delta
	if _is_burning() and _damage_tick_remaining <= 0.0:
		_damage_tick_remaining = DAMAGE_INTERVAL
		for player in _player_nodes:
			if player == null or not is_instance_valid(player) or not player.has_method("is_alive") or not player.is_alive():
				continue
			if _get_active_quadrants().has(_get_quadrant_for_point(player.global_position)):
				player.apply_damage(DAMAGE_AMOUNT)
	queue_redraw()

func _is_burning() -> bool:
	var phase_elapsed := _get_phase_elapsed()
	return phase_elapsed >= IGNITE_DURATION and phase_elapsed < IGNITE_DURATION + BURN_DURATION

func _get_active_quadrants() -> Array:
	return [0, 3] if int(floor(_elapsed / CYCLE_DURATION)) % 2 == 0 else [1, 2]

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
	if phase_elapsed < IGNITE_DURATION:
		alpha = lerpf(0.08, 0.24, phase_elapsed / IGNITE_DURATION)
	elif _is_burning():
		alpha = 0.24
	else:
		alpha = lerpf(0.24, 0.06, (phase_elapsed - (IGNITE_DURATION + BURN_DURATION)) / EXTINGUISH_DURATION)
	for quadrant_index in _get_active_quadrants():
		draw_rect(quadrants[quadrant_index], Color(1.0, 0.24, 0.14, alpha), true)
