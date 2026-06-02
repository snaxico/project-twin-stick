class_name FireFloorModifier
extends Node2D

const WARNING_DURATION := 1.5
const ACTIVE_DURATION := 4.0
const SPAWN_INTERVAL := 2.8
const DAMAGE_INTERVAL := 0.5
const DAMAGE_AMOUNT := 5
const ZONE_RADIUS := 240.0

var _arena_rect := Rect2()
var _player_nodes: Array = []
var _zones: Array = []
var _spawn_at := 0.0
var _max_zones := 5

func setup(arena_rect: Rect2, player_nodes: Array) -> void:
	_arena_rect = arena_rect
	_player_nodes = player_nodes
	_spawn_at = 0.0
	_spawn_zone()
	_spawn_zone()
	set_physics_process(true)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_spawn_at -= delta
	if _spawn_at <= 0.0 and _zones.size() < _max_zones:
		_spawn_zone()
		_spawn_at = SPAWN_INTERVAL + randf_range(0.0, 0.6)
	var expired: Array = []
	for zone in _zones:
		zone["time"] = float(zone.get("time", 0.0)) + delta
		zone["damage_at"] = float(zone.get("damage_at", DAMAGE_INTERVAL)) - delta
		if float(zone.get("time", 0.0)) >= WARNING_DURATION and float(zone.get("time", 0.0)) <= WARNING_DURATION + ACTIVE_DURATION and float(zone.get("damage_at", 0.0)) <= 0.0:
			zone["damage_at"] = DAMAGE_INTERVAL
			for player in _player_nodes:
				if player == null or not is_instance_valid(player) or not player.has_method("is_alive") or not player.is_alive():
					continue
				if player.global_position.distance_squared_to(zone["position"] as Vector2) <= ZONE_RADIUS * ZONE_RADIUS:
					player.apply_damage(DAMAGE_AMOUNT)
		if float(zone.get("time", 0.0)) >= WARNING_DURATION + ACTIVE_DURATION:
			expired.append(zone)
	queue_redraw()
	for zone in expired:
		_zones.erase(zone)

func _spawn_zone() -> void:
	var margin := 200.0
	_zones.append({
		"position": Vector2(
			randf_range(_arena_rect.position.x + margin, _arena_rect.end.x - margin),
			randf_range(_arena_rect.position.y + margin, _arena_rect.end.y - margin)
		),
		"time": 0.0,
		"damage_at": DAMAGE_INTERVAL,
	})

func _draw() -> void:
	for zone in _zones:
		var elapsed := float(zone.get("time", 0.0))
		var center := zone["position"] as Vector2
		if elapsed < WARNING_DURATION:
			var progress := elapsed / WARNING_DURATION
			draw_circle(center, ZONE_RADIUS * (0.35 + progress * 0.65), Color(1.0, 0.3, 0.16, 0.08 + progress * 0.08))
			draw_arc(center, ZONE_RADIUS, 0.0, TAU, 36, Color(1.0, 0.52, 0.24, 0.36 + progress * 0.26), 4.0)
		else:
			var fade := 1.0 - clampf((elapsed - WARNING_DURATION) / ACTIVE_DURATION, 0.0, 1.0)
			draw_circle(center, ZONE_RADIUS, Color(1.0, 0.24, 0.12, 0.22 * fade))
			draw_arc(center, ZONE_RADIUS, 0.0, TAU, 36, Color(1.0, 0.72, 0.44, 0.58 * fade), 6.0)
