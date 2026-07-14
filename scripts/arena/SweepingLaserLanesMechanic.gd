extends "res://scripts/arena/ArenaMechanic.gd"

const WARNING_TIME := 1.0
const SWEEP_TIME := 3.2
const REST_TIME := 1.2
const LASER_WIDTH := 70.0
const GAP_SIZE := 420.0
const DAMAGE := 9
const REHIT_COOLDOWN := 0.5
const WARNING_COLOR := Color(1.0, 0.72, 0.2, 0.78)
const LASER_COLOR := Color(1.0, 0.15, 0.45, 0.9)
const SWEEP_SEQUENCES := [
	[{"axis": "x", "direction": 1.0, "gap": 620.0}, {"axis": "y", "direction": 1.0, "gap": 2450.0}],
	[{"axis": "x", "direction": -1.0, "gap": 1450.0}, {"axis": "y", "direction": -1.0, "gap": 1050.0}],
	[{"axis": "x", "direction": 1.0, "gap": 1050.0}, {"axis": "y", "direction": -1.0, "gap": 2700.0}],
]

var _phase := "warning"
var _phase_elapsed := 0.0
var _sweep_index := 0
var _hit_cooldowns: Dictionary = {}


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
			_phase = "warning"


func _current_sweep() -> Dictionary:
	return (SWEEP_SEQUENCES[_variant_index] as Array)[_sweep_index] as Dictionary


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
			var next_sweep := (SWEEP_SEQUENCES[_variant_index] as Array)[(_sweep_index + 1) % 2] as Dictionary
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
