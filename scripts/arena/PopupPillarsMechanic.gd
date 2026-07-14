extends "res://scripts/arena/CoverMechanicBase.gd"

const DOWN_TIME := 1.2
const RISING_TIME := 0.4
const UP_TIME := 1.8
const PERIOD := DOWN_TIME + RISING_TIME + UP_TIME
const RISE_DAMAGE := 10
const PHASE_OFFSETS := [0.0, 0.38, 0.76, 1.14, 1.52, 1.90, 2.28, 2.66, 3.04]

const LAYOUTS := [
	[
		{"center": Vector2(650, 500), "size": Vector2(220, 240)},
		{"center": Vector2(1180, 520), "size": Vector2(250, 210)},
		{"center": Vector2(2400, 500), "size": Vector2(200, 250)},
		{"center": Vector2(3000, 620), "size": Vector2(260, 220)},
		{"center": Vector2(720, 1050), "size": Vector2(210, 260)},
		{"center": Vector2(2850, 1120), "size": Vector2(240, 200)},
		{"center": Vector2(1050, 1600), "size": Vector2(230, 250)},
		{"center": Vector2(2250, 1600), "size": Vector2(260, 210)},
		{"center": Vector2(3000, 1580), "size": Vector2(200, 240)},
	],
	[
		{"center": Vector2(520, 720), "size": Vector2(240, 210)},
		{"center": Vector2(1050, 430), "size": Vector2(210, 250)},
		{"center": Vector2(2500, 470), "size": Vector2(260, 200)},
		{"center": Vector2(3100, 850), "size": Vector2(220, 260)},
		{"center": Vector2(620, 1450), "size": Vector2(250, 220)},
		{"center": Vector2(1250, 1580), "size": Vector2(200, 240)},
		{"center": Vector2(2350, 1550), "size": Vector2(230, 260)},
		{"center": Vector2(3050, 1450), "size": Vector2(260, 210)},
		{"center": Vector2(2600, 1050), "size": Vector2(210, 230)},
	],
	[
		{"center": Vector2(600, 450), "size": Vector2(250, 200)},
		{"center": Vector2(1450, 480), "size": Vector2(210, 260)},
		{"center": Vector2(2450, 600), "size": Vector2(240, 220)},
		{"center": Vector2(3100, 500), "size": Vector2(200, 250)},
		{"center": Vector2(480, 1150), "size": Vector2(260, 210)},
		{"center": Vector2(3000, 1200), "size": Vector2(220, 240)},
		{"center": Vector2(900, 1650), "size": Vector2(230, 200)},
		{"center": Vector2(1850, 1580), "size": Vector2(250, 230)},
		{"center": Vector2(2700, 1600), "size": Vector2(200, 260)},
	],
]

var _layout: Array = []
var _states: Array = []
var _current_rects: Array = []
var _t := 0.0


func setup(arena: Rect2, players: Array, coop: Node) -> void:
	super.setup(arena, players, coop)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_layout = (LAYOUTS[rng.randi_range(0, LAYOUTS.size() - 1)] as Array).duplicate(true)
	_states = _compute_states()
	_current_rects = _rects_for_states(_states)
	_apply_rects(_current_rects, true)


func _physics_process(delta: float) -> void:
	_t += delta
	_sync_states()
	queue_redraw()


func _force_step() -> bool:
	for attempt in range(8):
		_t += 0.45
		if _sync_states():
			return true
	return false


func _sync_states() -> bool:
	var next_states := _compute_states()
	for index in range(next_states.size()):
		if str(_states[index]) == "rising" and str(next_states[index]) == "up":
			_apply_rise_damage(_pillar_rect(index))
	var next_rects := _rects_for_states(next_states)
	var changed := not _same_rects(next_rects, _current_rects)
	_states = next_states
	if changed and _apply_rects(next_rects, false):
		_current_rects = next_rects
		return true
	return false


func _compute_states() -> Array:
	var result: Array = []
	for index in range(_layout.size()):
		var phase := fmod(_t + float(PHASE_OFFSETS[index]), PERIOD)
		if phase < DOWN_TIME:
			result.append("down")
		elif phase < DOWN_TIME + RISING_TIME:
			result.append("rising")
		else:
			result.append("up")
	return result


func _rects_for_states(states: Array) -> Array:
	var rects: Array = []
	for index in range(states.size()):
		if str(states[index]) == "up":
			rects.append(_pillar_rect(index))
	return rects


func _pillar_rect(index: int) -> Rect2:
	var pillar := _layout[index] as Dictionary
	var size := pillar["size"] as Vector2
	return Rect2(_arena.position + pillar["center"] as Vector2 - size * 0.5, size)


func _apply_rise_damage(rect: Rect2) -> void:
	for player in _players:
		if player == null or not is_instance_valid(player) or not (player is Node2D):
			continue
		if player.has_method("is_alive") and not player.is_alive():
			continue
		if rect.has_point((player as Node2D).global_position):
			_damage_player(player, RISE_DAMAGE)


func _same_rects(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for rect_variant in a:
		if not b.has(rect_variant):
			return false
	return true


func _draw() -> void:
	var pulse := 0.65 + sin(_t * 12.0) * 0.2
	for index in range(_layout.size()):
		var rect := _pillar_rect(index)
		match str(_states[index]):
			"up":
				draw_rect(rect, Color(0.16, 0.48, 0.82, 0.78), true)
				draw_rect(rect, Color(0.58, 0.86, 1.0, 0.92), false, 3.0)
				draw_line(rect.position + Vector2(5, 6), Vector2(rect.end.x - 5, rect.position.y + 6), Color(0.8, 0.95, 1.0, 0.95), 5.0)
			"rising":
				draw_rect(rect, Color(1.0, 0.58, 0.1, 0.12 + pulse * 0.12), true)
				_draw_dashed_rect(rect, Color(1.0, 0.72, 0.22, pulse))
			_:
				draw_rect(rect, Color(0.2, 0.36, 0.5, 0.08), true)
				draw_rect(rect, Color(0.42, 0.62, 0.78, 0.18), false, 2.0)


func _draw_dashed_rect(rect: Rect2, color: Color) -> void:
	var top_left := rect.position
	var top_right := Vector2(rect.end.x, rect.position.y)
	var bottom_right := rect.end
	var bottom_left := Vector2(rect.position.x, rect.end.y)
	draw_dashed_line(top_left, top_right, color, 4.0, 14.0)
	draw_dashed_line(top_right, bottom_right, color, 4.0, 14.0)
	draw_dashed_line(bottom_right, bottom_left, color, 4.0, 14.0)
	draw_dashed_line(bottom_left, top_left, color, 4.0, 14.0)
