class_name MineFieldModifier
extends Node2D

const MINE_SPACING := 100.0
const SWEEP_SPEED := 200.0
const TELEGRAPH_DURATION := 1.0
const DAMAGE := 15
const TRIGGER_RADIUS := 34.0

var _arena_rect := Rect2()
var _player_nodes: Array = []
var _sweeps: Array = []
var _spawn_at := 0.0
var _direction_index := 0

func setup(arena_rect: Rect2, player_nodes: Array) -> void:
	_arena_rect = arena_rect
	_player_nodes = player_nodes
	_spawn_at = 1.0
	set_physics_process(true)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_spawn_at -= delta
	if _spawn_at <= 0.0:
		_spawn_sweep()
		_spawn_at = 5.0 + randf_range(0.0, 1.0)
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
	var directions := ["left", "right", "top", "bottom"]
	var dir: String = str(directions[_direction_index % directions.size()])
	_direction_index += 1
	var sweep := {
		"direction": dir,
		"time": 0.0,
		"offset": 0.0,
		"travel_limit": _arena_rect.size.x if dir == "left" or dir == "right" else _arena_rect.size.y,
	}
	_sweeps.append(sweep)

func _apply_sweep_damage(sweep: Dictionary) -> void:
	for player in _player_nodes:
		if player == null or not is_instance_valid(player) or not player.has_method("is_alive") or not player.is_alive():
			continue
		for mine_position in _get_mine_positions(sweep):
			if player.global_position.distance_to(mine_position) <= TRIGGER_RADIUS:
				player.apply_damage(DAMAGE)
				break

func _get_mine_positions(sweep: Dictionary) -> Array:
	var positions: Array = []
	var direction := str(sweep.get("direction", "left"))
	var offset := float(sweep.get("offset", 0.0))
	match direction:
		"left":
			var x_left := _arena_rect.position.x + offset
			var y_left := _arena_rect.position.y + 100.0
			while y_left <= _arena_rect.end.y - 100.0:
				positions.append(Vector2(x_left, y_left))
				y_left += MINE_SPACING
		"right":
			var x_right := _arena_rect.end.x - offset
			var y_right := _arena_rect.position.y + 100.0
			while y_right <= _arena_rect.end.y - 100.0:
				positions.append(Vector2(x_right, y_right))
				y_right += MINE_SPACING
		"top":
			var x_top := _arena_rect.position.x + 100.0
			var y_top := _arena_rect.position.y + offset
			while x_top <= _arena_rect.end.x - 100.0:
				positions.append(Vector2(x_top, y_top))
				x_top += MINE_SPACING
		_:
			var x_bottom := _arena_rect.position.x + 100.0
			var y_bottom := _arena_rect.end.y - offset
			while x_bottom <= _arena_rect.end.x - 100.0:
				positions.append(Vector2(x_bottom, y_bottom))
				x_bottom += MINE_SPACING
	return positions

func _draw() -> void:
	for sweep in _sweeps:
		var telegraph_alpha := 0.0
		if float(sweep.get("time", 0.0)) < TELEGRAPH_DURATION:
			telegraph_alpha = clampf(float(sweep.get("time", 0.0)) / TELEGRAPH_DURATION, 0.0, 1.0)
		if telegraph_alpha > 0.0:
			_draw_sweep_line(sweep, Color(1.0, 0.86, 0.32, 0.28 + telegraph_alpha * 0.34), 8.0, 0.0)
		else:
			_draw_sweep_line(sweep, Color(1.0, 0.48, 0.18, 0.72), 6.0, float(sweep.get("offset", 0.0)))
			for mine_position in _get_mine_positions(sweep):
				draw_circle(mine_position, 14.0, Color(1.0, 0.78, 0.28, 0.92))
				draw_arc(mine_position, 18.0, 0.0, TAU, 24, Color(1.0, 0.96, 0.72, 0.74), 2.0)

func _draw_sweep_line(sweep: Dictionary, color: Color, width: float, override_offset: float) -> void:
	var direction := str(sweep.get("direction", "left"))
	var offset := override_offset
	match direction:
		"left":
			var x_left := _arena_rect.position.x + offset
			draw_line(Vector2(x_left, _arena_rect.position.y), Vector2(x_left, _arena_rect.end.y), color, width)
		"right":
			var x_right := _arena_rect.end.x - offset
			draw_line(Vector2(x_right, _arena_rect.position.y), Vector2(x_right, _arena_rect.end.y), color, width)
		"top":
			var y_top := _arena_rect.position.y + offset
			draw_line(Vector2(_arena_rect.position.x, y_top), Vector2(_arena_rect.end.x, y_top), color, width)
		_:
			var y_bottom := _arena_rect.end.y - offset
			draw_line(Vector2(_arena_rect.position.x, y_bottom), Vector2(_arena_rect.end.x, y_bottom), color, width)
