extends "res://scripts/arena/ArenaMechanic.gd"

const WARNING_TIME := 1.0
const SWEEP_TIME := 3.2
const REST_TIME := 1.2
const LASER_WIDTH := 70.0
const GAP_SIZE := 420.0
const GAP_EDGE_INSET := 260.0
const GAP_MIN_STEP := 250.0
const DAMAGE := 9
const REHIT_COOLDOWN := 0.5
const WARNING_COLOR := Color(1.0, 0.72, 0.2, 0.78)
const LASER_COLOR := Color(1.0, 0.15, 0.45, 0.9)

var _phase := "warning"
var _phase_elapsed := 0.0
var _sweep_index := 0
var _hit_cooldowns: Dictionary = {}
var _current_sweeps: Array = []
var _gap_rng := RandomNumberGenerator.new()
var _accepted_sweeps: Array = []


func setup(arena: Rect2, players: Array, coop: Node) -> void:
	super.setup(arena, players, coop)
	_gap_rng.seed = _derived_gap_seed()
	_current_sweeps = [_generate_sweep(0), _generate_sweep(1)]
	_accepted_sweeps.clear()
	_accepted_sweeps.append_array(_current_sweeps.duplicate(true))


func _physics_process(delta: float) -> void:
	_phase_elapsed += delta
	_tick_cooldowns(delta)
	if _phase == "sweep":
		_apply_hits()
	var duration := _phase_duration()
	if _phase_elapsed >= duration:
		_phase_elapsed = fmod(_phase_elapsed, duration)
		_advance_phase()
	queue_redraw()


func _phase_duration() -> float:
	match _phase:
		"warning":
			return WARNING_TIME
		"sweep":
			return SWEEP_TIME
		_:
			return REST_TIME


func _advance_phase() -> void:
	match _phase:
		"warning":
			_phase = "sweep"
		"sweep":
			_phase = "rest"
		_:
			_sweep_index = (_sweep_index + 1) % 2
			_current_sweeps[_sweep_index] = _generate_sweep(_sweep_index)
			_accepted_sweeps.append((_current_sweeps[_sweep_index] as Dictionary).duplicate(true))
			_phase = "warning"


func _current_sweep() -> Dictionary:
	if _current_sweeps.is_empty():
		return _generate_sweep(_sweep_index)
	return _current_sweeps[_sweep_index] as Dictionary


func _generate_sweep(index: int) -> Dictionary:
	var axis := _axis_for_index(index)
	return {
		"axis": axis,
		"direction": _direction_for_index(index),
		"gap": _draw_gap(axis),
	}


func _axis_for_index(index: int) -> String:
	var starts_x := (_variant_index % 2) == 0
	var even := (index % 2) == 0
	return "x" if starts_x == even else "y"


func _direction_for_index(index: int) -> float:
	return 1.0 if ((_variant_index + index) % 2) == 0 else -1.0


func _draw_gap(axis: String) -> float:
	var min_gap := (_arena.position.y if axis == "x" else _arena.position.x) + GAP_EDGE_INSET
	var max_gap := (_arena.end.y if axis == "x" else _arena.end.x) - GAP_EDGE_INSET
	var fallback := (min_gap + max_gap) * 0.5
	if max_gap <= min_gap:
		return fallback
	var previous := INF
	for entry_variant in _accepted_sweeps:
		var entry := entry_variant as Dictionary
		if str(entry.get("axis", "")) == axis:
			previous = float(entry.get("gap", INF))
	for attempt in range(12):
		var gap := _gap_rng.randf_range(min_gap, max_gap)
		if previous == INF or absf(gap - previous) >= GAP_MIN_STEP:
			return gap
	return clampf(fallback if previous == INF else previous + GAP_MIN_STEP * (1.0 if previous < fallback else -1.0), min_gap, max_gap)


func _derived_gap_seed() -> int:
	var seed_value := _room_seed
	if seed_value == 0:
		seed_value = 20260720
	return int(seed_value) ^ ((_variant_index + 1) * 1103515245)


func _wall_coordinate(sweep: Dictionary, progress: float) -> float:
	var axis := str(sweep["axis"])
	var direction := float(sweep["direction"])
	var start := _arena.position.x if axis == "x" else _arena.position.y
	var finish := _arena.end.x if axis == "x" else _arena.end.y
	if direction < 0.0:
		var swap := start
		start = finish
		finish = swap
	return lerpf(start, finish, clampf(progress, 0.0, 1.0))


func _apply_hits() -> void:
	var sweep := _current_sweep()
	var axis := str(sweep["axis"])
	var gap_center := float(sweep["gap"])
	var wall := _wall_coordinate(sweep, _phase_elapsed / SWEEP_TIME)
	for player in _players:
		if player == null or not is_instance_valid(player) or not (player is Node2D):
			continue
		if player.has_method("is_alive") and not player.is_alive():
			continue
		var player_id: int = player.get_instance_id()
		if _hit_cooldowns.has(player_id):
			continue
		var pos := (player as Node2D).global_position
		var wall_distance := absf((pos.x if axis == "x" else pos.y) - wall)
		var gap_distance := absf((pos.y if axis == "x" else pos.x) - gap_center)
		if wall_distance <= LASER_WIDTH * 0.5 and gap_distance > GAP_SIZE * 0.5:
			_damage_player(player, DAMAGE)
			_hit_cooldowns[player_id] = REHIT_COOLDOWN


func _tick_cooldowns(delta: float) -> void:
	for player_id in _hit_cooldowns.keys():
		var remaining := float(_hit_cooldowns[player_id]) - delta
		if remaining <= 0.0:
			_hit_cooldowns.erase(player_id)
		else:
			_hit_cooldowns[player_id] = remaining


func _draw() -> void:
	var sweep := _current_sweep()
	match _phase:
		"warning":
			_draw_sweep_path(sweep)
			_draw_wall(sweep, _wall_coordinate(sweep, 0.0), WARNING_COLOR)
			_draw_direction_arrows(sweep)
		"sweep":
			_draw_wall(sweep, _wall_coordinate(sweep, _phase_elapsed / SWEEP_TIME), LASER_COLOR)
		_:
			var next_sweep := _current_sweeps[(_sweep_index + 1) % 2] as Dictionary
			_draw_entry_markers(next_sweep)


func _draw_wall(sweep: Dictionary, coordinate: float, color: Color) -> void:
	var axis := str(sweep["axis"])
	var gap_center := float(sweep["gap"])
	var half_gap := GAP_SIZE * 0.5
	if axis == "x":
		draw_line(Vector2(coordinate, _arena.position.y), Vector2(coordinate, gap_center - half_gap), color, LASER_WIDTH)
		draw_line(Vector2(coordinate, gap_center + half_gap), Vector2(coordinate, _arena.end.y), color, LASER_WIDTH)
	else:
		draw_line(Vector2(_arena.position.x, coordinate), Vector2(gap_center - half_gap, coordinate), color, LASER_WIDTH)
		draw_line(Vector2(gap_center + half_gap, coordinate), Vector2(_arena.end.x, coordinate), color, LASER_WIDTH)


func _draw_sweep_path(sweep: Dictionary) -> void:
	var axis := str(sweep["axis"])
	var gap_center := float(sweep["gap"])
	var half_gap := GAP_SIZE * 0.5
	var path_color := Color(LASER_COLOR, 0.10)
	if axis == "x":
		draw_rect(Rect2(_arena.position, Vector2(_arena.size.x, gap_center - half_gap - _arena.position.y)), path_color, true)
		draw_rect(Rect2(Vector2(_arena.position.x, gap_center + half_gap), Vector2(_arena.size.x, _arena.end.y - gap_center - half_gap)), path_color, true)
	else:
		draw_rect(Rect2(_arena.position, Vector2(gap_center - half_gap - _arena.position.x, _arena.size.y)), path_color, true)
		draw_rect(Rect2(Vector2(gap_center + half_gap, _arena.position.y), Vector2(_arena.end.x - gap_center - half_gap, _arena.size.y)), path_color, true)


func _draw_direction_arrows(sweep: Dictionary) -> void:
	var axis := str(sweep["axis"])
	var direction := float(sweep["direction"])
	var gap_center := float(sweep["gap"])
	var perpendicular := gap_center + (GAP_SIZE * 0.5 + 100.0 if gap_center < (_arena.position.y + _arena.size.y * 0.5 if axis == "x" else _arena.position.x + _arena.size.x * 0.5) else -GAP_SIZE * 0.5 - 100.0)
	for fraction_variant in [0.25, 0.5, 0.75]:
		var fraction := float(fraction_variant)
		var travel: float = (_arena.position.x + _arena.size.x * fraction) if axis == "x" else (_arena.position.y + _arena.size.y * fraction)
		var center := Vector2(travel, perpendicular) if axis == "x" else Vector2(perpendicular, travel)
		var forward := (Vector2.RIGHT if axis == "x" else Vector2.DOWN) * direction
		var side := forward.rotated(PI * 0.5)
		var points := PackedVector2Array([center - forward * 24.0 + side * 16.0, center + forward * 18.0, center - forward * 24.0 - side * 16.0])
		draw_polyline(points, WARNING_COLOR, 6.0)


func _draw_entry_markers(sweep: Dictionary) -> void:
	var coordinate := _wall_coordinate(sweep, 0.0)
	_draw_wall(sweep, coordinate, Color(WARNING_COLOR, 0.45))


func profiling_dodge_lane_valid() -> bool:
	if _current_sweeps.size() < 2:
		return false
	var previous_axis := ""
	var last_gap_by_axis := {}
	for entry_variant in _accepted_sweeps:
		var entry := entry_variant as Dictionary
		var axis := str(entry.get("axis", ""))
		var gap := float(entry.get("gap", 0.0))
		if axis != "x" and axis != "y":
			return false
		if previous_axis == axis:
			return false
		previous_axis = axis
		var min_gap := (_arena.position.y if axis == "x" else _arena.position.x) + GAP_EDGE_INSET
		var max_gap := (_arena.end.y if axis == "x" else _arena.end.x) - GAP_EDGE_INSET
		if gap < min_gap or gap > max_gap:
			return false
		if last_gap_by_axis.has(axis) and absf(gap - float(last_gap_by_axis[axis])) < GAP_MIN_STEP:
			return false
		last_gap_by_axis[axis] = gap
	return _replay_seeded_openings()


func _replay_seeded_openings() -> bool:
	var replay_rng := RandomNumberGenerator.new()
	replay_rng.seed = _derived_gap_seed()
	var replayed: Array = []
	for index in range(_accepted_sweeps.size()):
		var axis := _axis_for_index(index)
		var min_gap := (_arena.position.y if axis == "x" else _arena.position.x) + GAP_EDGE_INSET
		var max_gap := (_arena.end.y if axis == "x" else _arena.end.x) - GAP_EDGE_INSET
		var fallback := (min_gap + max_gap) * 0.5
		var previous := INF
		for prior_variant in replayed:
			var prior := prior_variant as Dictionary
			if str(prior.get("axis", "")) == axis:
				previous = float(prior.get("gap", INF))
		var replay_gap := fallback
		for attempt in range(12):
			var candidate := replay_rng.randf_range(min_gap, max_gap)
			if previous == INF or absf(candidate - previous) >= GAP_MIN_STEP:
				replay_gap = candidate
				break
			if attempt == 11:
				replay_gap = clampf(fallback if previous == INF else previous + GAP_MIN_STEP * (1.0 if previous < fallback else -1.0), min_gap, max_gap)
		replayed.append({"axis": axis, "direction": _direction_for_index(index), "gap": replay_gap})
		var accepted := _accepted_sweeps[index] as Dictionary
		if str(accepted.get("axis", "")) != axis:
			return false
		if not is_equal_approx(float(accepted.get("gap", 0.0)), replay_gap):
			return false
	return true
