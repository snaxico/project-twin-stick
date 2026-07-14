extends "res://scripts/arena/ArenaMechanic.gd"

const SAFE_RADIUS := 170.0
const HOLD_TIME := 2.8
const TELEGRAPH_TIME := 0.8
const CYCLE_TIME := HOLD_TIME + TELEGRAPH_TIME
const START_GRACE := 1.5
const DAMAGE_INTERVAL := 0.75

const MINE_COUNT := 10
const MINE_DAMAGE := 20
const MINE_TRIGGER_RADIUS := 110.0
const MINE_BLAST_RADIUS := 150.0
const MINE_SAFE_DISTANCE := 340.0
const MINE_SEPARATION := 300.0

const SAFE_ZONE_FAMILIES := [
	[
		[Vector2(1800, 1050), Vector2(850, 650), Vector2(2750, 700), Vector2(1150, 1500)],
		[Vector2(1600, 1050), Vector2(1050, 750), Vector2(2550, 850), Vector2(1350, 1450)],
		[Vector2(1800, 850), Vector2(850, 900), Vector2(2700, 1050), Vector2(1500, 1500)],
	],
	[
		[Vector2(1750, 1050), Vector2(700, 800), Vector2(2850, 600), Vector2(2600, 1500)],
		[Vector2(1550, 900), Vector2(900, 950), Vector2(2700, 800), Vector2(2450, 1450)],
		[Vector2(1750, 750), Vector2(750, 1050), Vector2(2850, 950), Vector2(2600, 1350)],
	],
	[
		[Vector2(1800, 1050), Vector2(950, 500), Vector2(2900, 1100), Vector2(900, 1550)],
		[Vector2(2000, 900), Vector2(1100, 700), Vector2(2700, 1050), Vector2(1100, 1450)],
		[Vector2(1800, 800), Vector2(900, 800), Vector2(2850, 900), Vector2(1000, 1350)],
	],
]

var _floor_kind := "fire_grid"
var _set_index := 0
var _cycle_elapsed := 0.0
var _room_elapsed := 0.0
var _damage_elapsed := 0.0
var _mine_sets: Array = []
var _spent_mines: Dictionary = {}


func set_variant(variant_id: String) -> void:
	_floor_kind = variant_id


func setup(arena: Rect2, players: Array, coop: Node) -> void:
	super.setup(arena, players, coop)
	_build_mine_sets()


func _exit_tree() -> void:
	_clear_frost_slow()


func _physics_process(delta: float) -> void:
	_room_elapsed += delta
	_cycle_elapsed += delta
	if _cycle_elapsed >= CYCLE_TIME:
		_cycle_elapsed = fmod(_cycle_elapsed, CYCLE_TIME)
		_set_index = (_set_index + 1) % _safe_zone_sets().size()
		_spent_mines.clear()

	if _floor_kind == "mine_grid":
		_update_mines()
	else:
		_update_floor_effect(delta)
	queue_redraw()


func _update_floor_effect(delta: float) -> void:
	var can_damage := _room_elapsed >= START_GRACE
	_damage_elapsed += delta
	var should_damage := can_damage and _damage_elapsed >= DAMAGE_INTERVAL
	if should_damage:
		_damage_elapsed = fmod(_damage_elapsed, DAMAGE_INTERVAL)
	for player in _players:
		if not _valid_player(player):
			continue
		var off_zone := not _is_in_safe_zone((player as Node2D).global_position, _set_index)
		if _floor_kind == "frost_grid":
			if can_damage and off_zone:
				player.apply_zone_modifier("frost_grid", 0.5, 1.0)
			else:
				player.clear_zone_modifier("frost_grid")
		if should_damage and off_zone:
			_damage_player(player, 8 if _floor_kind == "fire_grid" else 6)


func _update_mines() -> void:
	if _room_elapsed < START_GRACE or _mine_sets.is_empty():
		return
	var mines: Array = _mine_sets[_set_index] as Array
	for mine_index in range(mines.size()):
		if _spent_mines.has(mine_index):
			continue
		var mine_position := mines[mine_index] as Vector2
		var triggered := false
		for player in _players:
			if _valid_player(player) and (player as Node2D).global_position.distance_to(mine_position) <= MINE_TRIGGER_RADIUS:
				triggered = true
				break
		if not triggered:
			continue
		_spent_mines[mine_index] = true
		for player in _players:
			if _valid_player(player) and (player as Node2D).global_position.distance_to(mine_position) <= MINE_BLAST_RADIUS:
				_damage_player(player, MINE_DAMAGE)


func _valid_player(player) -> bool:
	if player == null or not is_instance_valid(player) or not (player is Node2D):
		return false
	return not player.has_method("is_alive") or player.is_alive()


func _is_in_safe_zone(position: Vector2, set_index: int) -> bool:
	var radius_sq := SAFE_RADIUS * SAFE_RADIUS
	for center_variant in _safe_zone_sets()[set_index]:
		var center := _arena.position + center_variant as Vector2
		if position.distance_squared_to(center) <= radius_sq:
			return true
	return false


func _build_mine_sets() -> void:
	_mine_sets.clear()
	for set_index in range(_safe_zone_sets().size()):
		var candidates: Array = []
		var y := _arena.position.y + 250.0
		while y <= _arena.end.y - 250.0:
			var row := int((y - _arena.position.y - 250.0) / 350.0)
			var x := _arena.position.x + 250.0 + (175.0 if row % 2 == 1 else 0.0)
			while x <= _arena.end.x - 250.0:
				var candidate := Vector2(x, y)
				if _mine_is_clear_of_zones(candidate, set_index):
					candidates.append(candidate)
				x += 350.0
			y += 350.0
		var rng := RandomNumberGenerator.new()
		rng.seed = 74021 + _variant_index * 2931 + set_index * 977
		for index in range(candidates.size() - 1, 0, -1):
			var swap_index := rng.randi_range(0, index)
			var swap_value = candidates[index]
			candidates[index] = candidates[swap_index]
			candidates[swap_index] = swap_value
		var mines: Array = []
		for candidate_variant in candidates:
			var candidate := candidate_variant as Vector2
			if _mine_is_separated(candidate, mines):
				mines.append(candidate)
				if mines.size() == MINE_COUNT:
					break
		if mines.size() != MINE_COUNT:
			push_error("HazardFloorMechanic could not place 10 fair mines for set %d" % set_index)
		_mine_sets.append(mines)


func _mine_is_clear_of_zones(candidate: Vector2, set_index: int) -> bool:
	var minimum_sq := MINE_SAFE_DISTANCE * MINE_SAFE_DISTANCE
	for center_variant in _safe_zone_sets()[set_index]:
		var center := _arena.position + center_variant as Vector2
		if candidate.distance_squared_to(center) < minimum_sq:
			return false
	return true


func _mine_is_separated(candidate: Vector2, mines: Array) -> bool:
	var minimum_sq := MINE_SEPARATION * MINE_SEPARATION
	for mine_variant in mines:
		if candidate.distance_squared_to(mine_variant as Vector2) < minimum_sq:
			return false
	return true


func _clear_frost_slow() -> void:
	if _floor_kind != "frost_grid":
		return
	for player in _players:
		if player != null and is_instance_valid(player) and player.has_method("clear_zone_modifier"):
			player.clear_zone_modifier("frost_grid")


func _draw() -> void:
	var colors := _skin_colors()
	draw_rect(_arena, colors["hazard"], true)
	_draw_safe_zones(_set_index, colors["safe"], false)
	if _cycle_elapsed >= HOLD_TIME:
		_draw_safe_zones((_set_index + 1) % _safe_zone_sets().size(), Color(1.0, 0.72, 0.2, 0.78), true)
	if _floor_kind == "mine_grid" and not _mine_sets.is_empty():
		_draw_mines(_set_index, false)
		if _cycle_elapsed >= HOLD_TIME:
			_draw_mines((_set_index + 1) % _safe_zone_sets().size(), true)


func _draw_safe_zones(set_index: int, color: Color, telegraph: bool) -> void:
	for center_variant in _safe_zone_sets()[set_index]:
		var center := _arena.position + center_variant as Vector2
		if not telegraph:
			draw_circle(center, SAFE_RADIUS, Color(color, 0.2))
		draw_arc(center, SAFE_RADIUS, 0.0, TAU, 64, color, 5.0 if telegraph else 3.0)


func _draw_mines(set_index: int, incoming: bool) -> void:
	var mines: Array = _mine_sets[set_index] as Array
	for mine_index in range(mines.size()):
		if not incoming and _spent_mines.has(mine_index):
			continue
		var center := mines[mine_index] as Vector2
		var color := Color(1.0, 0.72, 0.18, 0.25 if incoming else 0.85)
		draw_circle(center, 12.0, color)
		draw_arc(center, MINE_TRIGGER_RADIUS, 0.0, TAU, 32, Color(color, color.a * 0.35), 2.0)


func _skin_colors() -> Dictionary:
	match _floor_kind:
		"frost_grid":
			return {"hazard": Color(0.35, 0.78, 1.0, 0.22), "safe": Color(0.62, 0.9, 1.0, 0.85)}
		"mine_grid":
			return {"hazard": Color(1.0, 0.72, 0.18, 0.18), "safe": Color(0.62, 0.9, 1.0, 0.85)}
		_:
			return {"hazard": Color(1.0, 0.25, 0.12, 0.22), "safe": Color(0.62, 0.9, 1.0, 0.85)}


func _safe_zone_sets() -> Array:
	return SAFE_ZONE_FAMILIES[_variant_index] as Array
