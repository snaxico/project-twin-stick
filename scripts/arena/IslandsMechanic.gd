extends "res://scripts/arena/ArenaMechanic.gd"

const PAD_R := 150.0
const RESHUFFLE := 4.0
const TELEGRAPH := 0.6
const START_GRACE := 1.5
const PLAYER_TICK := 0.5
const ENEMY_TICK := 1.0
const PAD_SETS := [
	[Vector2(1800, 1050), Vector2(760, 620), Vector2(2840, 620), Vector2(1800, 1620)],
	[Vector2(760, 1480), Vector2(2840, 1480), Vector2(1360, 760), Vector2(2240, 760)],
	[Vector2(1360, 1340), Vector2(2240, 1340), Vector2(1800, 700), Vector2(700, 1050)],
]

var _t := 0.0
var _set_index := 0
var _next_set_index := 1
var _phase_t := 0.0
var _player_tick := PLAYER_TICK
var _enemy_tick := ENEMY_TICK


func _physics_process(delta: float) -> void:
	_t += delta
	_phase_t += delta
	if _phase_t >= RESHUFFLE:
		_set_index = _next_set_index
		_next_set_index = (_set_index + 1) % PAD_SETS.size()
		_phase_t = 0.0
	_player_tick -= delta
	_enemy_tick -= delta
	if _t >= START_GRACE and _player_tick <= 0.0:
		_player_tick = PLAYER_TICK
		for player in _players:
			if player != null and is_instance_valid(player) and player is Node2D and not _is_on_pad((player as Node2D).global_position):
				_damage_player(player, 4)
	if _t >= START_GRACE and _enemy_tick <= 0.0 and _coop != null:
		_enemy_tick = ENEMY_TICK
		for enemy in _coop.get_enemy_target_nodes().duplicate():
			if enemy != null and is_instance_valid(enemy) and enemy is Node2D and not _is_on_pad((enemy as Node2D).global_position):
				_damage_enemy(enemy, 2)
	queue_redraw()


func _is_on_pad(pos: Vector2) -> bool:
	var radius_sq := PAD_R * PAD_R
	for center in PAD_SETS[_set_index]:
		if pos.distance_squared_to(center) <= radius_sq:
			return true
	return false


func _draw() -> void:
	draw_rect(_arena, Color(0.14, 0.26, 0.34, 0.18), true)
	for center in PAD_SETS[_set_index]:
		draw_circle(center, PAD_R, Color(0.28, 0.82, 0.58, 0.22))
		draw_arc(center, PAD_R, 0.0, TAU, 48, Color(0.62, 1.0, 0.82, 0.7), 3.0)
	if _phase_t >= RESHUFFLE - TELEGRAPH:
		for center in PAD_SETS[_next_set_index]:
			draw_arc(center, PAD_R, 0.0, TAU, 48, Color(1.0, 0.94, 0.45, 0.85), 4.0)
