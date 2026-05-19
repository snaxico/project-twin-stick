class_name HotFloorZone
extends Node2D

var radius: float = 120.0
var damage: int = 8
var warning_duration: float = 1.5
var active_duration: float = 2.5
var tick_interval: float = 1.0

var _spawned_at: float = 0.0
var _warning_ring: Polygon2D = null
var _active_fill: Polygon2D = null
var _inner_glow: Polygon2D = null
var _next_tick_by_target: Dictionary = {}

func configure(zone_radius: float, zone_damage: int, warning_seconds: float, active_seconds: float, damage_tick_interval: float = 1.0) -> void:
	radius = maxf(zone_radius, 24.0)
	damage = max(zone_damage, 1)
	warning_duration = maxf(warning_seconds, 0.1)
	active_duration = maxf(active_seconds, 0.1)
	tick_interval = maxf(damage_tick_interval, 0.1)

func _ready() -> void:
	_spawned_at = _current_time_seconds()
	_build_visuals()
	set_process(true)

func _process(_delta: float) -> void:
	var elapsed: float = _current_time_seconds() - _spawned_at
	if elapsed >= warning_duration + active_duration:
		queue_free()
		return
	_update_visuals(elapsed)

func is_active() -> bool:
	var elapsed: float = _current_time_seconds() - _spawned_at
	return elapsed >= warning_duration and elapsed < warning_duration + active_duration

func apply_damage_to_targets(targets: Array) -> void:
	if not is_active():
		return
	var now: float = _current_time_seconds()
	for target in targets:
		if not is_instance_valid(target) or not (target is Node2D):
			continue
		if not target.has_method("apply_damage"):
			continue
		var node_target: Node2D = target as Node2D
		if node_target.global_position.distance_to(global_position) > radius:
			continue
		var target_key: String = str(node_target.get_instance_id())
		var next_tick_at: float = float(_next_tick_by_target.get(target_key, 0.0))
		if now < next_tick_at:
			continue
		_next_tick_by_target[target_key] = now + tick_interval
		node_target.apply_damage(damage)

func _build_visuals() -> void:
	var outer_points: PackedVector2Array = _build_circle_polygon(radius, 24)
	var inner_points: PackedVector2Array = _build_circle_polygon(radius * 0.76, 24)

	_warning_ring = Polygon2D.new()
	_warning_ring.color = Color(0.96, 0.82, 0.26, 0.18)
	_warning_ring.polygon = outer_points
	add_child(_warning_ring)

	_active_fill = Polygon2D.new()
	_active_fill.color = Color(0.96, 0.34, 0.12, 0.0)
	_active_fill.polygon = outer_points
	add_child(_active_fill)

	_inner_glow = Polygon2D.new()
	_inner_glow.color = Color(1.0, 0.62, 0.16, 0.0)
	_inner_glow.polygon = inner_points
	add_child(_inner_glow)

func _update_visuals(elapsed: float) -> void:
	if _warning_ring == null or _active_fill == null or _inner_glow == null:
		return
	if elapsed < warning_duration:
		var pulse: float = 0.72 + 0.16 * sin(elapsed * 8.0)
		_warning_ring.color = Color(0.96, 0.82, 0.26, 0.16 + 0.18 * pulse)
		_active_fill.color = Color(0.96, 0.34, 0.12, 0.0)
		_inner_glow.color = Color(1.0, 0.62, 0.16, 0.0)
		scale = Vector2.ONE * lerpf(0.92, 1.02, clampf(elapsed / warning_duration, 0.0, 1.0))
		return
	var active_elapsed: float = elapsed - warning_duration
	var fade_ratio: float = 1.0 - clampf(active_elapsed / active_duration, 0.0, 1.0)
	_warning_ring.color = Color(1.0, 0.88, 0.36, 0.22 * fade_ratio)
	_active_fill.color = Color(0.96, 0.34, 0.12, 0.26 + 0.16 * fade_ratio)
	_inner_glow.color = Color(1.0, 0.62, 0.16, 0.14 + 0.12 * fade_ratio)
	scale = Vector2.ONE

func _build_circle_polygon(circle_radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index in range(segments):
		var angle: float = float(index) / float(segments) * TAU
		points.append(Vector2(cos(angle) * circle_radius, sin(angle) * circle_radius))
	return points

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
