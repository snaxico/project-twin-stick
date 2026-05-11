class_name CaptureHillZone
extends Node2D

var radius: float = 132.0
var fill_ratio: float = 0.0

var _outer_ring: Polygon2D = null
var _inner_fill: Polygon2D = null
var _center_glow: Polygon2D = null

func configure(zone_radius: float) -> void:
	radius = maxf(zone_radius, 48.0)

func _ready() -> void:
	_build_visuals()
	set_process(true)

func _process(delta: float) -> void:
	_update_visuals(delta)

func set_fill_ratio(value: float) -> void:
	fill_ratio = clampf(value, 0.0, 1.0)

func contains_point(world_position: Vector2) -> bool:
	return global_position.distance_to(world_position) <= radius

func _build_visuals() -> void:
	var outer_points := _build_circle_polygon(radius, 28)
	var fill_points := _build_circle_polygon(radius * 0.82, 28)
	var center_points := _build_circle_polygon(radius * 0.38, 24)

	_outer_ring = Polygon2D.new()
	_outer_ring.color = Color(0.22, 0.86, 0.96, 0.16)
	_outer_ring.polygon = outer_points
	add_child(_outer_ring)

	_inner_fill = Polygon2D.new()
	_inner_fill.color = Color(0.18, 0.78, 0.92, 0.18)
	_inner_fill.polygon = fill_points
	add_child(_inner_fill)

	_center_glow = Polygon2D.new()
	_center_glow.color = Color(0.96, 0.94, 0.54, 0.18)
	_center_glow.polygon = center_points
	add_child(_center_glow)

func _update_visuals(delta: float) -> void:
	if _outer_ring == null or _inner_fill == null or _center_glow == null:
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 4.5)
	_outer_ring.color = Color(0.22, 0.86, 0.96, 0.14 + pulse * 0.12)
	_inner_fill.color = Color(0.18, 0.78, 0.92, 0.10 + fill_ratio * 0.28)
	_inner_fill.scale = Vector2.ONE * lerpf(0.84, 1.0, fill_ratio)
	_center_glow.color = Color(0.98, 0.96, 0.58, 0.14 + fill_ratio * 0.22)
	_center_glow.scale = _center_glow.scale.lerp(Vector2.ONE * (0.92 + pulse * 0.08 + fill_ratio * 0.12), clamp(delta * 8.0, 0.0, 1.0))

func _build_circle_polygon(circle_radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index in range(segments):
		var angle: float = float(index) / float(segments) * TAU
		points.append(Vector2(cos(angle) * circle_radius, sin(angle) * circle_radius))
	return points
