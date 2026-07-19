extends "res://scripts/arena/ArenaMechanic.gd"

const BLADE_COUNT := 3
const BLADE_RADIUS := 42.0
const BLADE_SPEED := 130.0
const MIN_CENTER_DISTANCE := BLADE_RADIUS * 2.0 + 120.0
const CONTACT_DAMAGE := 9
const REHIT_COOLDOWN := 0.6
const COSMETIC_SPIN_SPEED := 4.5
const START_LAYOUTS := [
	[Vector2(864, 588), Vector2(2592, 672), Vector2(1872, 1554)],
	[Vector2(620, 520), Vector2(2100, 650), Vector2(2920, 1500)],
	[Vector2(900, 1450), Vector2(1650, 500), Vector2(3000, 900)],
]

var _positions: Array = []
var _directions: Array = []
var _hit_cooldowns: Array = []
var _spin := 0.0


func setup(arena: Rect2, players: Array, coop: Node) -> void:
	super.setup(arena, players, coop)
	var starts: Array = START_LAYOUTS[_variant_index] as Array
	var rng := RandomNumberGenerator.new()
	rng.seed = _room_seed
	for index in range(BLADE_COUNT):
		_positions.append(_arena.position + starts[index] as Vector2)
		_directions.append(Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)))
		_hit_cooldowns.append({})


func _physics_process(delta: float) -> void:
	_spin = fmod(_spin + COSMETIC_SPIN_SPEED * delta, TAU)
	_tick_cooldowns(delta)
	_move_blades(delta)
	_apply_player_hits()
	queue_redraw()


func _move_blades(delta: float) -> void:
	var proposed := _positions.duplicate()
	for index in range(BLADE_COUNT):
		var direction := _directions[index] as Vector2
		var next_position := (_positions[index] as Vector2) + direction * BLADE_SPEED * delta
		var minimum := _arena.position + Vector2.ONE * BLADE_RADIUS
		var maximum := _arena.end - Vector2.ONE * BLADE_RADIUS
		if next_position.x < minimum.x or next_position.x > maximum.x:
			direction.x *= -1.0
			next_position.x = clampf(next_position.x, minimum.x, maximum.x)
		if next_position.y < minimum.y or next_position.y > maximum.y:
			direction.y *= -1.0
			next_position.y = clampf(next_position.y, minimum.y, maximum.y)
		_directions[index] = direction.normalized()
		proposed[index] = next_position

	var blocked: Dictionary = {}
	for first in range(BLADE_COUNT):
		for second in range(first + 1, BLADE_COUNT):
			if (proposed[first] as Vector2).distance_to(proposed[second] as Vector2) < MIN_CENTER_DISTANCE:
				blocked[first] = true
				blocked[second] = true
				_turn_apart(first, second)
	for index in range(BLADE_COUNT):
		if not blocked.has(index):
			_positions[index] = proposed[index]


func _turn_apart(first: int, second: int) -> void:
	var separation := (_positions[first] as Vector2) - (_positions[second] as Vector2)
	if separation.length_squared() <= 0.001:
		separation = Vector2.RIGHT.rotated(TAU * float(first + 1) / float(BLADE_COUNT))
	var normal := separation.normalized()
	_directions[first] = ((_directions[first] as Vector2).reflect(normal) + normal * 0.35).normalized()
	_directions[second] = ((_directions[second] as Vector2).reflect(-normal) - normal * 0.35).normalized()


func _tick_cooldowns(delta: float) -> void:
	for blade_index in range(_hit_cooldowns.size()):
		var cooldowns := _hit_cooldowns[blade_index] as Dictionary
		for player_id in cooldowns.keys():
			var remaining := float(cooldowns[player_id]) - delta
			if remaining <= 0.0:
				cooldowns.erase(player_id)
			else:
				cooldowns[player_id] = remaining


func _apply_player_hits() -> void:
	var radius_sq := BLADE_RADIUS * BLADE_RADIUS
	for blade_index in range(BLADE_COUNT):
		var cooldowns := _hit_cooldowns[blade_index] as Dictionary
		for player in _players:
			if not _valid_player(player):
				continue
			var player_id: int = player.get_instance_id()
			if cooldowns.has(player_id):
				continue
			if (player as Node2D).global_position.distance_squared_to(_positions[blade_index] as Vector2) <= radius_sq:
				_damage_player(player, CONTACT_DAMAGE)
				cooldowns[player_id] = REHIT_COOLDOWN


func _valid_player(player) -> bool:
	if player == null or not is_instance_valid(player) or not (player is Node2D):
		return false
	return not player.has_method("is_alive") or player.is_alive()


func profiling_dodge_lane_valid() -> bool:
	if MIN_CENTER_DISTANCE - BLADE_RADIUS * 2.0 < 120.0:
		return false
	for first in range(_positions.size()):
		for second in range(first + 1, _positions.size()):
			var edge_gap := (_positions[first] as Vector2).distance_to(_positions[second] as Vector2) - BLADE_RADIUS * 2.0
			if edge_gap < 120.0 - 0.01:
				return false
	return true


func _draw() -> void:
	for center_variant in _positions:
		var center := center_variant as Vector2
		draw_circle(center, BLADE_RADIUS, Color(1.0, 0.3, 0.14, 0.9))
		draw_arc(center, BLADE_RADIUS, 0.0, TAU, 24, Color(1.0, 0.72, 0.24, 0.95), 4.0)
		for spoke in range(6):
			var direction := Vector2.RIGHT.rotated(_spin + TAU * float(spoke) / 6.0)
			draw_line(center, center + direction * (BLADE_RADIUS - 4.0), Color(1.0, 0.9, 0.62, 0.9), 3.0)
		draw_circle(center, 7.0, Color(0.18, 0.12, 0.14, 1.0))
