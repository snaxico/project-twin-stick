class_name GravityWellModifier
extends Node2D

const WELL_RADIUS := 150.0
const REPOSITION_INTERVAL := 8.0
const PULL_FORCE := 240.0

var _arena_rect := Rect2()
var _wells: Array = []
var _elapsed := 0.0

func setup(arena_rect: Rect2) -> void:
	_arena_rect = arena_rect
	_reposition_wells()
	set_physics_process(true)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= REPOSITION_INTERVAL:
		_elapsed = 0.0
		_reposition_wells()
	queue_redraw()

func apply_pull(players: Array, enemies: Array, delta: float) -> void:
	for well in _wells:
		var center := well as Vector2
		for player in players:
			if player == null or not is_instance_valid(player) or not player.has_method("is_alive") or not player.is_alive():
				continue
			var offset: Vector2 = center - player.global_position
			var distance: float = offset.length()
			if distance > WELL_RADIUS or distance <= 0.0:
				continue
			player.apply_impulse(offset.normalized(), PULL_FORCE * (1.0 - distance / WELL_RADIUS) * delta * 60.0)
		for enemy in enemies:
			if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("is_alive") or not enemy.is_alive():
				continue
			var enemy_offset: Vector2 = center - enemy.global_position
			var enemy_distance: float = enemy_offset.length()
			if enemy_distance > WELL_RADIUS or enemy_distance <= 0.0:
				continue
			enemy.apply_knockback(enemy_offset.normalized(), PULL_FORCE * (1.0 - enemy_distance / WELL_RADIUS) * delta * 60.0)

func _reposition_wells() -> void:
	_wells.clear()
	for _index in range(2):
		_wells.append(Vector2(
			randf_range(_arena_rect.position.x + 200.0, _arena_rect.end.x - 200.0),
			randf_range(_arena_rect.position.y + 200.0, _arena_rect.end.y - 200.0)
		))

func _draw() -> void:
	for well in _wells:
		var center := well as Vector2
		draw_circle(center, WELL_RADIUS, Color(0.36, 0.24, 0.82, 0.1))
		draw_arc(center, WELL_RADIUS, 0.0, TAU, 36, Color(0.62, 0.44, 1.0, 0.52), 4.0)
		draw_arc(center, WELL_RADIUS * 0.6, 0.0, TAU, 32, Color(0.78, 0.72, 1.0, 0.42), 3.0)
