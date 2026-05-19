class_name DeathPuddle
extends Node2D

var radius: float = 84.0
var tick_damage: int = 6
var tick_interval: float = 0.5
var warning_duration: float = 0.4
var active_duration: float = 2.0

var _spawned_at: float = 0.0
var _warning_ring: Polygon2D = null
var _puddle_fill: Polygon2D = null
var _puddle_core: Polygon2D = null
var _next_tick_by_target: Dictionary = {}

func configure(puddle_radius: float, damage_per_tick: int, damage_tick_interval: float, warning_seconds: float, active_seconds: float) -> void:
	radius = maxf(puddle_radius, 20.0)
	tick_damage = max(damage_per_tick, 1)
	tick_interval = maxf(damage_tick_interval, 0.1)
	warning_duration = maxf(warning_seconds, 0.05)
	active_duration = maxf(active_seconds, 0.1)

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
		node_target.apply_damage(tick_damage)

func _build_visuals() -> void:
	var outer_points: PackedVector2Array = _build_circle_polygon(radius, 22)
	var inner_points: PackedVector2Array = _build_circle_polygon(radius * 0.72, 22)

	_warning_ring = Polygon2D.new()
	_warning_ring.color = Color(0.98, 0.76, 0.28, 0.28)
	_warning_ring.polygon = outer_points
	add_child(_warning_ring)

	_puddle_fill = Polygon2D.new()
	_puddle_fill.color = Color(0.76, 0.16, 0.44, 0.0)
	_puddle_fill.polygon = outer_points
	add_child(_puddle_fill)

	_puddle_core = Polygon2D.new()
	_puddle_core.color = Color(0.44, 0.04, 0.14, 0.0)
	_puddle_core.polygon = inner_points
	add_child(_puddle_core)

func _update_visuals(elapsed: float) -> void:
	if _warning_ring == null or _puddle_fill == null or _puddle_core == null:
		return
	if elapsed < warning_duration:
		var flash: float = 0.6 + 0.4 * sin(elapsed * 18.0)
		_warning_ring.color = Color(0.98, 0.76, 0.28, 0.18 + 0.18 * flash)
		_puddle_fill.color = Color(0.76, 0.16, 0.44, 0.0)
		_puddle_core.color = Color(0.44, 0.04, 0.14, 0.0)
		return
	var active_elapsed: float = elapsed - warning_duration
	var fade_ratio: float = 1.0 - clampf(active_elapsed / active_duration, 0.0, 1.0)
	_warning_ring.color = Color(0.92, 0.42, 0.72, 0.16 * fade_ratio)
	_puddle_fill.color = Color(0.76, 0.16, 0.44, 0.22 + 0.16 * fade_ratio)
	_puddle_core.color = Color(0.44, 0.04, 0.14, 0.28 + 0.18 * fade_ratio)

func _build_circle_polygon(circle_radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index in range(segments):
		var angle: float = float(index) / float(segments) * TAU
		points.append(Vector2(cos(angle) * circle_radius, sin(angle) * circle_radius))
	return points

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
