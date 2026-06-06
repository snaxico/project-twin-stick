class_name MineFieldModifier
extends Node2D

const SWEEP_SPEED := 200.0
const TELEGRAPH_DURATION := 1.0
const DAMAGE := 12
const HIT_HALF_WIDTH := 34.0
const PLAYER_HIT_COOLDOWN := 0.6
const GAP_COUNT_MIN := 2
const GAP_COUNT_MAX := 3
const MAX_ACTIVE_SWEEPS := 2
const GAP_WIDTH_MIN := 200.0
const GAP_WIDTH_MAX := 240.0
const EDGE_PADDING := 100.0

var _arena_rect := Rect2()
var _player_nodes: Array = []
var _sweeps: Array = []
var _spawn_at := 0.0

func setup(arena_rect: Rect2, player_nodes: Array) -> void:
	_arena_rect = arena_rect
	_player_nodes = player_nodes
	_spawn_at = 1.0
	set_physics_process(true)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_spawn_at -= delta
	if _spawn_at <= 0.0:
		if _sweeps.size() < MAX_ACTIVE_SWEEPS:
			_spawn_sweep()
		_spawn_at = 8.0 + randf_range(0.0, 1.5)
	var expired: Array = []
	for sweep in _sweeps:
		sweep["time"] = float(sweep.get("time", 0.0)) + delta
		if float(sweep.get("time", 0.0)) >= TELEGRAPH_DURATION:
			sweep["offset"] = float(sweep.get("offset", 0.0)) + SWEEP_SPEED * delta
			_apply_sweep_damage(sweep)
		if float(sweep.get("offset", 0.0)) >= float(sweep.get("travel_limit", 0.0)):
			expired.append(sweep)
	queue_redraw()
	for sweep in expired:
		_sweeps.erase(sweep)

func _spawn_sweep() -> void:
	var dir := _pick_sweep_direction()
	var sweep := {
		"direction": dir,
		"time": 0.0,
		"offset": 0.0,
		"travel_limit": _arena_rect.size.x if dir == "left" or dir == "right" else _arena_rect.size.y,
		"gaps": _build_gaps(dir),
		"player_hit_times": {},
	}
	_sweeps.append(sweep)

func _pick_sweep_direction() -> String:
	var has_vertical := false
	var has_horizontal := false
	for sweep in _sweeps:
		var direction := str((sweep as Dictionary).get("direction", "left"))
		if direction == "left" or direction == "right":
			has_vertical = true
		else:
			has_horizontal = true
	if has_vertical and not has_horizontal:
		return ["top", "bottom"].pick_random()
	if has_horizontal and not has_vertical:
		return ["left", "right"].pick_random()
	return ["left", "right", "top", "bottom"].pick_random()

func _build_gaps(direction: String) -> Array:
	var lane_length := _arena_rect.size.y if direction == "left" or direction == "right" else _arena_rect.size.x
	var start := EDGE_PADDING
	var end := maxf(start, lane_length - EDGE_PADDING)
	var gap_count := randi_range(GAP_COUNT_MIN, GAP_COUNT_MAX)
	var segment_length := (end - start) / float(gap_count)
	var gaps: Array = []
	for index in range(gap_count):
		var width := randf_range(GAP_WIDTH_MIN, GAP_WIDTH_MAX)
		var segment_start := start + segment_length * float(index)
		var segment_end := start + segment_length * float(index + 1)
		var center := randf_range(segment_start + width * 0.5, segment_end - width * 0.5)
		gaps.append(Vector2(maxf(start, center - width * 0.5), minf(end, center + width * 0.5)))
	return gaps

func _apply_sweep_damage(sweep: Dictionary) -> void:
	var hit_times: Dictionary = sweep.get("player_hit_times", {}) as Dictionary
	var current_time := Time.get_ticks_msec() / 1000.0
	for player in _player_nodes:
		if player == null or not is_instance_valid(player) or not player.has_method("is_alive") or not player.is_alive():
			continue
		var player_id: int = player.get_instance_id()
		var last_hit_time := float(hit_times.get(player_id, -INF))
		if current_time - last_hit_time < PLAYER_HIT_COOLDOWN:
			continue
		if _is_player_in_sweep(player.global_position, sweep):
			player.apply_damage(DAMAGE)
			hit_times[player_id] = current_time
	sweep["player_hit_times"] = hit_times

func _is_player_in_sweep(player_position: Vector2, sweep: Dictionary) -> bool:
	var direction := str(sweep.get("direction", "left"))
	var offset := float(sweep.get("offset", 0.0))
	match direction:
		"left":
			var x_left := _arena_rect.position.x + offset
			if absf(player_position.x - x_left) > HIT_HALF_WIDTH:
				return false
			return not _is_axis_in_gap(player_position.y - _arena_rect.position.y, sweep)
		"right":
			var x_right := _arena_rect.end.x - offset
			if absf(player_position.x - x_right) > HIT_HALF_WIDTH:
				return false
			return not _is_axis_in_gap(player_position.y - _arena_rect.position.y, sweep)
		"top":
			var y_top := _arena_rect.position.y + offset
			if absf(player_position.y - y_top) > HIT_HALF_WIDTH:
				return false
			return not _is_axis_in_gap(player_position.x - _arena_rect.position.x, sweep)
		_:
			var y_bottom := _arena_rect.end.y - offset
			if absf(player_position.y - y_bottom) > HIT_HALF_WIDTH:
				return false
			return not _is_axis_in_gap(player_position.x - _arena_rect.position.x, sweep)

func _is_axis_in_gap(axis_position: float, sweep: Dictionary) -> bool:
	for gap in sweep.get("gaps", []):
		var gap_range := gap as Vector2
		if axis_position >= gap_range.x and axis_position <= gap_range.y:
			return true
	return false

func _draw() -> void:
	for sweep in _sweeps:
		var telegraph_alpha := 0.0
		if float(sweep.get("time", 0.0)) < TELEGRAPH_DURATION:
			telegraph_alpha = clampf(float(sweep.get("time", 0.0)) / TELEGRAPH_DURATION, 0.0, 1.0)
		if telegraph_alpha > 0.0:
			_draw_sweep_line(sweep, Color(1.0, 0.86, 0.32, 0.28 + telegraph_alpha * 0.34), 8.0, 0.0)
		else:
			_draw_sweep_line(sweep, Color(1.0, 0.48, 0.18, 0.72), 6.0, float(sweep.get("offset", 0.0)))

func _draw_sweep_line(sweep: Dictionary, color: Color, width: float, override_offset: float) -> void:
	var direction := str(sweep.get("direction", "left"))
	var offset := override_offset
	var vertical := direction == "left" or direction == "right"
	var lane_start := _arena_rect.position.y if vertical else _arena_rect.position.x
	var lane_end := _arena_rect.end.y if vertical else _arena_rect.end.x
	var fixed_position := 0.0
	match direction:
		"left":
			fixed_position = _arena_rect.position.x + offset
		"right":
			fixed_position = _arena_rect.end.x - offset
		"top":
			fixed_position = _arena_rect.position.y + offset
		_:
			fixed_position = _arena_rect.end.y - offset
	var cursor := lane_start
	var sorted_gaps := (sweep.get("gaps", []) as Array).duplicate()
	sorted_gaps.sort_custom(func(a, b): return (a as Vector2).x < (b as Vector2).x)
	for gap in sorted_gaps:
		var gap_range := gap as Vector2
		var gap_start := lane_start + gap_range.x
		var gap_end := lane_start + gap_range.y
		if gap_start > cursor:
			_draw_scanline_segment(vertical, fixed_position, cursor, minf(gap_start, lane_end), color, width)
		cursor = maxf(cursor, gap_end)
	if cursor < lane_end:
		_draw_scanline_segment(vertical, fixed_position, cursor, lane_end, color, width)

func _draw_scanline_segment(vertical: bool, fixed_position: float, start: float, end: float, color: Color, width: float) -> void:
	if end <= start:
		return
	if vertical:
		draw_line(Vector2(fixed_position, start), Vector2(fixed_position, end), color, width)
	else:
		draw_line(Vector2(start, fixed_position), Vector2(end, fixed_position), color, width)
