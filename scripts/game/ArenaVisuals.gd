extends Node2D

const ArenaGeometry = preload("res://scripts/game/ArenaGeometry.gd")

var _coop: Node = null
var _floor_visual: Polygon2D = null
var _floor_grid: Node2D = null
var _top_wall: CollisionShape2D = null
var _bottom_wall: CollisionShape2D = null
var _left_wall: CollisionShape2D = null
var _right_wall: CollisionShape2D = null
var _exit_zone: Area2D = null
var _exit_zone_shape: CollisionShape2D = null
var _exit_zone_visual: Polygon2D = null
var _camera: Camera2D = null
var _arena_size := Vector2.ZERO
var _arena_rect := Rect2()
var _arena_center := Vector2.ZERO
var _arena_margin := 0.0
var _floor_grid_spacing := 160.0
var _floor_grid_major_interval := 4
var _arena_wall_visual_width := 18.0
var _floor_grid_player_highlight_radius := 520.0
var _grid_pulse_time := 0.0


func setup(
	coop: Node,
	floor_visual: Polygon2D,
	floor_grid: Node2D,
	top_wall: CollisionShape2D,
	bottom_wall: CollisionShape2D,
	left_wall: CollisionShape2D,
	right_wall: CollisionShape2D,
	exit_zone: Area2D,
	exit_zone_shape: CollisionShape2D,
	exit_zone_visual: Polygon2D,
	camera: Camera2D,
	arena_size: Vector2,
	arena_rect: Rect2,
	arena_center: Vector2,
	arena_margin: float,
	floor_grid_spacing: float,
	floor_grid_major_interval: int,
	arena_wall_visual_width: float,
	floor_grid_player_highlight_radius: float
) -> void:
	_coop = coop
	_floor_visual = floor_visual
	_floor_grid = floor_grid
	_top_wall = top_wall
	_bottom_wall = bottom_wall
	_left_wall = left_wall
	_right_wall = right_wall
	_exit_zone = exit_zone
	_exit_zone_shape = exit_zone_shape
	_exit_zone_visual = exit_zone_visual
	_camera = camera
	_arena_size = arena_size
	_arena_rect = arena_rect
	_arena_center = arena_center
	_arena_margin = arena_margin
	_floor_grid_spacing = floor_grid_spacing
	_floor_grid_major_interval = floor_grid_major_interval
	_arena_wall_visual_width = arena_wall_visual_width
	_floor_grid_player_highlight_radius = floor_grid_player_highlight_radius


func rebuild_arena() -> void:
	_floor_visual.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(_arena_size.x, 0.0),
		_arena_size,
		Vector2(0.0, _arena_size.y),
	])
	_rebuild_floor_grid()
	_apply_collision_bounds_from_floor()
	_exit_zone.position = Vector2(_arena_center.x, _arena_rect.end.y - 220.0)
	_exit_zone_shape.shape = RectangleShape2D.new()
	(_exit_zone_shape.shape as RectangleShape2D).size = Vector2(360.0, 140.0)
	_exit_zone_visual.visible = false
	if _camera.has_method("set_arena_rect"):
		_camera.set_arena_rect(_arena_rect)
		_camera.global_position = _arena_center


func apply_arena_color() -> void:
	var hue := 0.55
	var minor := Color.from_hsv(hue, 0.42, 0.92, 0.18)
	var major := Color.from_hsv(hue, 0.58, 1.0, 0.34)
	var wall := Color.from_hsv(hue, 0.62, 1.0, 0.68)
	if _floor_visual != null:
		_floor_visual.color = Color(0.012, 0.017, 0.032, 1.0)
	var max_dist := (_arena_size * 0.5).length()
	for child in _floor_grid.get_children():
		if child is Line2D:
			var line := child as Line2D
			if line.width >= _arena_wall_visual_width:
				var wall_color := Color(wall.r, wall.g, wall.b, line.default_color.a)
				line.default_color = wall_color
				line.set_meta("grid_base_color", wall_color)
				continue
			var base_color := major if line.width >= 3.0 else minor
			var mid := (line.points[0] + line.points[line.points.size() - 1]) * 0.5
			var depth := 1.0 - clampf(mid.distance_to(_arena_center) / max_dist, 0.0, 1.0)
			var line_color := Color(base_color.r, base_color.g, base_color.b, base_color.a * (0.32 + 0.68 * depth))
			line.default_color = line_color
			line.set_meta("grid_base_color", line_color)


func tick(delta: float) -> void:
	if _floor_grid == null:
		return
	_grid_pulse_time += delta
	var pulse := 0.94 + 0.06 * sin(_grid_pulse_time * 1.6)
	for child in _floor_grid.get_children():
		if not (child is Line2D):
			continue
		var line := child as Line2D
		var base_color: Color = line.get_meta("grid_base_color", line.default_color) as Color
		var is_wall := bool(line.get_meta("grid_is_wall", false))
		if is_wall:
			line.default_color = Color(base_color.r * pulse, base_color.g * pulse, base_color.b * pulse, base_color.a)
			continue
		var player_glow := _get_grid_player_glow(line)
		var alpha_mult := pulse * (0.78 + player_glow * 0.65)
		line.default_color = Color(base_color.r, base_color.g, base_color.b, clampf(base_color.a * alpha_mult, 0.02, 0.52))


func _rebuild_floor_grid() -> void:
	for child in _floor_grid.get_children():
		child.queue_free()
	var x := 0.0
	var column_index := 0
	while x <= _arena_size.x:
		var is_major_line := column_index % _floor_grid_major_interval == 0
		var line := _build_grid_line(
			PackedVector2Array([Vector2(x, 0.0), Vector2(x, _arena_size.y)]),
			3.0 if is_major_line else 1.5,
			Color(0.34, 0.8, 1.0, 0.3) if is_major_line else Color(0.24, 0.52, 0.68, 0.18),
			false
		)
		_floor_grid.add_child(line)
		x += _floor_grid_spacing
		column_index += 1
	var y := 0.0
	var row_index := 0
	while y <= _arena_size.y:
		var is_major_line := row_index % _floor_grid_major_interval == 0
		var line := _build_grid_line(
			PackedVector2Array([Vector2(0.0, y), Vector2(_arena_size.x, y)]),
			3.0 if is_major_line else 1.5,
			Color(0.34, 0.8, 1.0, 0.3) if is_major_line else Color(0.24, 0.52, 0.68, 0.18),
			false
		)
		_floor_grid.add_child(line)
		y += _floor_grid_spacing
		row_index += 1
	_add_arena_wall_visuals()


func _add_arena_wall_visuals() -> void:
	var wall_segments := [
		PackedVector2Array([Vector2(_arena_margin, _arena_margin), Vector2(_arena_rect.end.x - _arena_margin, _arena_margin)]),
		PackedVector2Array([Vector2(_arena_margin, _arena_rect.end.y - _arena_margin), Vector2(_arena_rect.end.x - _arena_margin, _arena_rect.end.y - _arena_margin)]),
		PackedVector2Array([Vector2(_arena_margin, _arena_margin), Vector2(_arena_margin, _arena_rect.end.y - _arena_margin)]),
		PackedVector2Array([Vector2(_arena_rect.end.x - _arena_margin, _arena_margin), Vector2(_arena_rect.end.x - _arena_margin, _arena_rect.end.y - _arena_margin)]),
	]
	for segment in wall_segments:
		_floor_grid.add_child(_build_grid_line(segment, _arena_wall_visual_width * 2.8, Color(0.18, 0.7, 1.0, 0.16), true))
		_floor_grid.add_child(_build_grid_line(segment, _arena_wall_visual_width, Color(0.26, 0.84, 1.0, 0.66), true))


func _build_grid_line(points: PackedVector2Array, width: float, color: Color, is_wall: bool) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.antialiased = true
	line.default_color = color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND if is_wall else Line2D.LINE_CAP_NONE
	line.end_cap_mode = Line2D.LINE_CAP_ROUND if is_wall else Line2D.LINE_CAP_NONE
	line.points = points
	line.set_meta("grid_base_color", color)
	line.set_meta("grid_is_wall", is_wall)
	return line


func _apply_collision_bounds_from_floor() -> void:
	_set_wall_rect(_top_wall, Vector2(_arena_center.x, _arena_margin * 0.5), Vector2(_arena_size.x - _arena_margin * 2.0, _arena_margin))
	_set_wall_rect(_bottom_wall, Vector2(_arena_center.x, _arena_rect.end.y - _arena_margin * 0.5), Vector2(_arena_size.x - _arena_margin * 2.0, _arena_margin))
	_set_wall_rect(_left_wall, Vector2(_arena_margin * 0.5, _arena_center.y), Vector2(_arena_margin, _arena_size.y - _arena_margin * 2.0))
	_set_wall_rect(_right_wall, Vector2(_arena_rect.end.x - _arena_margin * 0.5, _arena_center.y), Vector2(_arena_margin, _arena_size.y - _arena_margin * 2.0))


func _set_wall_rect(node: CollisionShape2D, wall_position: Vector2, size: Vector2) -> void:
	node.position = wall_position
	if node.shape == null or not (node.shape is RectangleShape2D):
		node.shape = RectangleShape2D.new()
	(node.shape as RectangleShape2D).size = size


func _get_grid_player_glow(line: Line2D) -> float:
	if line.points.size() < 2:
		return 0.0
	var best := 0.0
	var start := line.points[0]
	var end := line.points[line.points.size() - 1]
	if _coop == null or not _coop.has_method("get_active_players"):
		return 0.0
	for player in _coop.call("get_active_players"):
		if player == null or not is_instance_valid(player) or not (player is Node2D):
			continue
		var distance := ArenaGeometry.distance_to_segment((player as Node2D).global_position, start, end)
		best = maxf(best, 1.0 - clampf(distance / _floor_grid_player_highlight_radius, 0.0, 1.0))
	return best * best
