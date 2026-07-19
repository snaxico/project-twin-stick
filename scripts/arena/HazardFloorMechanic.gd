extends "res://scripts/arena/ArenaMechanic.gd"

const SAFE_RADIUS := 170.0
const HOLD_TIME := 2.8
const TELEGRAPH_TIME := 0.8
const CYCLE_TIME := HOLD_TIME + TELEGRAPH_TIME
const START_GRACE := 1.5
const DAMAGE_INTERVAL := 0.75

const PATCH_START_RADIUS := 120.0
const PATCH_END_RADIUS := 260.0
const PATCH_GROW_TIME := 6.0
const PATCH_HOLD_TIME := 4.0
const PATCH_FADE_TIME := 1.0
const PATCH_SPAWN_INTERVAL := 2.5
const PATCH_MAX_CONCURRENT := 8
const PATCH_ARENA_INSET := 200.0
const PATCH_MIN_CENTER_STEP := 250.0
const PATCH_GRID_SIZE := 60.0
const PATCH_PLAYER_CLEARANCE := 40.0

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
var _patches: Array = []
var _patch_rng := RandomNumberGenerator.new()
var _next_patch_at := START_GRACE
var _last_patch_center := Vector2.INF
var _accepted_patch_centers: Array = []
var _profiling_invalid_damage_phase := false


func set_variant(variant_id: String) -> void:
	_floor_kind = variant_id


func setup(arena: Rect2, players: Array, coop: Node) -> void:
	super.setup(arena, players, coop)
	if _floor_kind == "mine_grid":
		_build_mine_sets()
		return
	_patch_rng.seed = _patch_seed()
	_next_patch_at = START_GRACE


func _exit_tree() -> void:
	_clear_frost_slow()


func _physics_process(delta: float) -> void:
	_room_elapsed += delta
	if _floor_kind == "mine_grid":
		_update_mine_floor(delta)
	else:
		_update_patch_floor(delta)
	queue_redraw()


func _update_mine_floor(delta: float) -> void:
	_cycle_elapsed += delta
	if _cycle_elapsed >= CYCLE_TIME:
		_cycle_elapsed = fmod(_cycle_elapsed, CYCLE_TIME)
		_set_index = (_set_index + 1) % _safe_zone_sets().size()
		_spent_mines.clear()
	_update_mines()


func _update_patch_floor(delta: float) -> void:
	for patch_variant in _patches:
		var patch := patch_variant as Dictionary
		patch["age"] = float(patch.get("age", 0.0)) + delta
	_patches = _patches.filter(func(patch_variant) -> bool:
		return float((patch_variant as Dictionary).get("age", 0.0)) < _patch_total_time()
	)
	while _room_elapsed >= _next_patch_at:
		if _non_faded_patch_count() < PATCH_MAX_CONCURRENT:
			_spawn_patch()
		_next_patch_at += PATCH_SPAWN_INTERVAL
	_update_patch_effects(delta)


func _spawn_patch() -> void:
	var center := _next_patch_center(_patch_rng, _last_patch_center)
	_last_patch_center = center
	_accepted_patch_centers.append(center)
	_patches.append({"center": center, "age": 0.0})


func _next_patch_center(rng: RandomNumberGenerator, previous: Vector2) -> Vector2:
	var candidate := _random_patch_center(rng)
	while previous != Vector2.INF and candidate.distance_to(previous) < PATCH_MIN_CENTER_STEP:
		candidate = _random_patch_center(rng)
	return candidate


func _random_patch_center(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(
		rng.randf_range(_arena.position.x + PATCH_ARENA_INSET, _arena.end.x - PATCH_ARENA_INSET),
		rng.randf_range(_arena.position.y + PATCH_ARENA_INSET, _arena.end.y - PATCH_ARENA_INSET)
	)


func _update_patch_effects(delta: float) -> void:
	_damage_elapsed += delta
	var should_damage := _damage_elapsed >= DAMAGE_INTERVAL
	if should_damage:
		_damage_elapsed = fmod(_damage_elapsed, DAMAGE_INTERVAL)
	for player in _players:
		if not _valid_player(player):
			continue
		var inside_active_patch := _position_in_active_patch((player as Node2D).global_position)
		if _floor_kind == "frost_grid":
			if inside_active_patch:
				player.apply_zone_modifier("frost_grid", 0.5, 1.0)
			else:
				player.clear_zone_modifier("frost_grid")
		if should_damage and inside_active_patch:
			_damage_player(player, 8 if _floor_kind == "fire_grid" else 6)


func _position_in_active_patch(position: Vector2) -> bool:
	for patch_variant in _patches:
		var patch := patch_variant as Dictionary
		if not _patch_is_active(patch):
			continue
		var radius := _patch_radius(patch)
		if position.distance_squared_to(patch.get("center", Vector2.ZERO) as Vector2) <= radius * radius:
			return true
	return false


func _patch_is_active(patch: Dictionary) -> bool:
	var age := float(patch.get("age", 0.0))
	return age >= TELEGRAPH_TIME and age < TELEGRAPH_TIME + PATCH_GROW_TIME + PATCH_HOLD_TIME


func _patch_is_fading(patch: Dictionary) -> bool:
	var age := float(patch.get("age", 0.0))
	return age >= TELEGRAPH_TIME + PATCH_GROW_TIME + PATCH_HOLD_TIME and age < _patch_total_time()


func _patch_radius(patch: Dictionary) -> float:
	var active_age := clampf(float(patch.get("age", 0.0)) - TELEGRAPH_TIME, 0.0, PATCH_GROW_TIME)
	return lerpf(PATCH_START_RADIUS, PATCH_END_RADIUS, active_age / PATCH_GROW_TIME)


func _patch_total_time() -> float:
	return TELEGRAPH_TIME + PATCH_GROW_TIME + PATCH_HOLD_TIME + PATCH_FADE_TIME


func _non_faded_patch_count() -> int:
	var count := 0
	for patch_variant in _patches:
		if not _patch_is_fading(patch_variant as Dictionary):
			count += 1
	return count


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


func profiling_patch_model_valid() -> bool:
	if _floor_kind == "mine_grid" or _non_faded_patch_count() > PATCH_MAX_CONCURRENT:
		return _floor_kind == "mine_grid"
	if _profiling_invalid_damage_phase or not _profiling_safe_grid_valid():
		return false
	var replay_rng := RandomNumberGenerator.new()
	replay_rng.seed = _patch_seed()
	var replay_previous := Vector2.INF
	for center_variant in _accepted_patch_centers:
		var replay_center := _next_patch_center(replay_rng, replay_previous)
		if replay_center != center_variant as Vector2:
			return false
		replay_previous = replay_center
	return true


func _profiling_safe_grid_valid() -> bool:
	var width := int(_arena.size.x / PATCH_GRID_SIZE)
	var height := int(_arena.size.y / PATCH_GRID_SIZE)
	var safe_cells: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var point := _arena.position + Vector2((float(x) + 0.5) * PATCH_GRID_SIZE, (float(y) + 0.5) * PATCH_GRID_SIZE)
			if _profiling_grid_point_safe(point):
				safe_cells[Vector2i(x, y)] = true
	if safe_cells.size() < int(ceil(float(width * height) * 0.5)):
		return false
	if safe_cells.is_empty():
		return false
	var frontier: Array[Vector2i] = [safe_cells.keys()[0] as Vector2i]
	var visited: Dictionary = {frontier[0]: true}
	var cursor := 0
	while cursor < frontier.size():
		var cell := frontier[cursor]
		cursor += 1
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + offset
			if safe_cells.has(neighbor) and not visited.has(neighbor):
				visited[neighbor] = true
				frontier.append(neighbor)
	return visited.size() >= int(ceil(float(safe_cells.size()) * 0.95))


func _profiling_grid_point_safe(point: Vector2) -> bool:
	for patch_variant in _patches:
		var patch := patch_variant as Dictionary
		if not _patch_is_active(patch):
			continue
		var clearance := _patch_radius(patch) + PATCH_PLAYER_CLEARANCE
		if point.distance_squared_to(patch.get("center", Vector2.ZERO) as Vector2) <= clearance * clearance:
			return false
	return true


func _patch_seed() -> int:
	return _room_seed + _variant_index * 2931


func _draw() -> void:
	if _floor_kind == "mine_grid":
		_draw_mine_floor()
	else:
		_draw_patch_floor()


func _draw_mine_floor() -> void:
	var colors := _skin_colors()
	draw_rect(_arena, colors["hazard"], true)
	_draw_safe_zones(_set_index, colors["safe"], false)
	if _cycle_elapsed >= HOLD_TIME:
		_draw_safe_zones((_set_index + 1) % _safe_zone_sets().size(), Color(1.0, 0.72, 0.2, 0.78), true)
	if not _mine_sets.is_empty():
		_draw_mines(_set_index, false)
		if _cycle_elapsed >= HOLD_TIME:
			_draw_mines((_set_index + 1) % _safe_zone_sets().size(), true)


func _draw_patch_floor() -> void:
	var colors := _skin_colors()
	draw_rect(_arena, Color(colors["safe"], 0.035), true)
	for patch_variant in _patches:
		var patch := patch_variant as Dictionary
		var center := patch.get("center", Vector2.ZERO) as Vector2
		var age := float(patch.get("age", 0.0))
		var radius := _patch_radius(patch)
		if age < TELEGRAPH_TIME:
			var telegraph_ratio := clampf(age / TELEGRAPH_TIME, 0.0, 1.0)
			draw_arc(center, PATCH_START_RADIUS, 0.0, TAU, 48, Color(colors["hazard"], 0.35 + telegraph_ratio * 0.45), 4.0)
		elif _patch_is_fading(patch):
			var fade_ratio := clampf((age - TELEGRAPH_TIME - PATCH_GROW_TIME - PATCH_HOLD_TIME) / PATCH_FADE_TIME, 0.0, 1.0)
			draw_circle(center, PATCH_END_RADIUS, Color(colors["hazard"], 0.18 * (1.0 - fade_ratio)))
			draw_arc(center, PATCH_END_RADIUS, 0.0, TAU, 64, Color(colors["hazard"], 0.5 * (1.0 - fade_ratio)), 3.0)
		else:
			draw_circle(center, radius, Color(colors["hazard"], 0.22))
			draw_arc(center, radius, 0.0, TAU, 64, Color(colors["hazard"], 0.85), 3.0)


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
			return {"hazard": Color(0.35, 0.78, 1.0, 0.88), "safe": Color(0.62, 0.9, 1.0, 0.85)}
		"mine_grid":
			return {"hazard": Color(1.0, 0.72, 0.18, 0.18), "safe": Color(0.62, 0.9, 1.0, 0.85)}
		_:
			return {"hazard": Color(1.0, 0.25, 0.12, 0.88), "safe": Color(0.62, 0.9, 1.0, 0.85)}


func _safe_zone_sets() -> Array:
	return SAFE_ZONE_FAMILIES[_variant_index] as Array
