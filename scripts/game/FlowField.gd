extends RefCounted

const CELL_SIZE := 150.0
const OBSTACLE_INFLATION := 40.0
const INF_DISTANCE := 100000000.0
const TARGET_REBUILD_MIN_INTERVAL_MS := 150
const NEIGHBOR_OFFSETS := [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var _arena_rect := Rect2()
var _cell_size := CELL_SIZE
var _cols := 0
var _rows := 0
var _blocked := PackedByteArray()
var _fields: Dictionary = {}
var _last_target_cells: Dictionary = {}
var _last_field_rebuild_ms: Dictionary = {}
var _obstacle_count := 0

static var profile_enabled := false
static var _profile_sample_usec := 0
static var _profile_sample_calls := 0
static var _profile_update_usec := 0
static var _profile_update_calls := 0


static func profiling_reset() -> void:
	_profile_sample_usec = 0
	_profile_sample_calls = 0
	_profile_update_usec = 0
	_profile_update_calls = 0


static func profiling_snapshot() -> Dictionary:
	return {
		"sample_usec": _profile_sample_usec,
		"sample_calls": _profile_sample_calls,
		"update_usec": _profile_update_usec,
		"update_calls": _profile_update_calls,
	}


func setup(arena_rect: Rect2, cell_size: float = CELL_SIZE) -> void:
	_arena_rect = arena_rect
	_cell_size = maxf(cell_size, 8.0)
	_cols = int(ceil(_arena_rect.size.x / _cell_size))
	_rows = int(ceil(_arena_rect.size.y / _cell_size))
	_reset_grid()


func get_obstacle_inflation() -> float:
	return OBSTACLE_INFLATION


func build(obstacle_rects: Array) -> void:
	if _cols <= 0 or _rows <= 0:
		setup(_arena_rect, _cell_size)
	_reset_grid()
	_fields.clear()
	_last_target_cells.clear()
	_last_field_rebuild_ms.clear()
	_obstacle_count = obstacle_rects.size()
	for obstacle_variant in obstacle_rects:
		if not (obstacle_variant is Rect2):
			continue
		var obstacle_rect := (obstacle_variant as Rect2).grow(OBSTACLE_INFLATION)
		var min_cell := _world_to_cell(obstacle_rect.position)
		var max_cell := _world_to_cell(obstacle_rect.end)
		for cell_y in range(min_cell.y, max_cell.y + 1):
			for cell_x in range(min_cell.x, max_cell.x + 1):
				var cell := Vector2i(cell_x, cell_y)
				if not _is_cell_in_bounds(cell):
					continue
				if _cell_rect(cell).intersects(obstacle_rect):
					_blocked[_cell_index(cell)] = 1


func has_obstacles() -> bool:
	return _obstacle_count > 0


func update_targets(player_positions: Array) -> void:
	var profile_start := Time.get_ticks_usec() if profile_enabled else 0
	if not has_obstacles():
		if profile_enabled:
			_profile_update_usec += Time.get_ticks_usec() - profile_start
			_profile_update_calls += 1
		return
	var valid_indices: Dictionary = {}
	var now_ms := Time.get_ticks_msec()
	for player_index in range(player_positions.size()):
		var position_variant = player_positions[player_index]
		if not (position_variant is Vector2):
			continue
		var player_position := position_variant as Vector2
		if not _arena_rect.has_point(player_position):
			continue
		var target_index := _nearest_passable_index_for_point(player_position)
		if target_index < 0:
			continue
		valid_indices[player_index] = true
		var target_cell := _index_to_cell(target_index)
		if _fields.has(player_index) and _last_target_cells.get(player_index, Vector2i(-999, -999)) == target_cell:
			continue
		if _fields.has(player_index) and now_ms - int(_last_field_rebuild_ms.get(player_index, 0)) < TARGET_REBUILD_MIN_INTERVAL_MS:
			continue
		var distances := _build_distances(target_index)
		_fields[player_index] = {
			"distances": distances,
			"vectors": _build_vectors(distances),
		}
		_last_target_cells[player_index] = target_cell
		_last_field_rebuild_ms[player_index] = now_ms
	for key in _fields.keys():
		if not valid_indices.has(int(key)):
			_fields.erase(key)
			_last_target_cells.erase(key)
			_last_field_rebuild_ms.erase(key)
	if profile_enabled:
		_profile_update_usec += Time.get_ticks_usec() - profile_start
		_profile_update_calls += 1


func sample(world_position: Vector2, target_player_index: int, fallback_dir: Vector2) -> Vector2:
	if profile_enabled:
		var profile_start := Time.get_ticks_usec()
		var result := _sample_impl(world_position, target_player_index, fallback_dir)
		_profile_sample_usec += Time.get_ticks_usec() - profile_start
		_profile_sample_calls += 1
		return result
	return _sample_impl(world_position, target_player_index, fallback_dir)


func _sample_impl(world_position: Vector2, target_player_index: int, fallback_dir: Vector2) -> Vector2:
	var fallback := _normalized_or_zero(fallback_dir)
	if not has_obstacles() or target_player_index < 0 or not _fields.has(target_player_index):
		return fallback
	if not _arena_rect.has_point(world_position):
		return fallback
	var field: Dictionary = _fields[target_player_index] as Dictionary
	var vectors: PackedVector2Array = field.get("vectors", PackedVector2Array()) as PackedVector2Array
	if vectors.is_empty():
		return fallback
	var current_cell := _world_to_cell(world_position)
	if _is_cell_in_bounds(current_cell):
		var current_index := _cell_index(current_cell)
		var current_vector := vectors[current_index]
		if current_vector.length_squared() > 0.0001:
			return current_vector
	return fallback


func validate_connectivity(required_points: Array) -> bool:
	if not has_obstacles():
		return true
	var required_indices: Array = []
	for point_variant in required_points:
		if not (point_variant is Vector2):
			continue
		var index := _nearest_passable_index_for_point(point_variant as Vector2)
		if index < 0:
			return false
		if not required_indices.has(index):
			required_indices.append(index)
	if required_indices.size() <= 1:
		return true
	var visited := _flood_passable(int(required_indices[0]))
	for index_variant in required_indices:
		if not bool(visited[int(index_variant)]):
			return false
	return true


func target_reaches_points(target_player_index: int, points: Array) -> bool:
	if not has_obstacles() or not _fields.has(target_player_index):
		return true
	var field: Dictionary = _fields[target_player_index] as Dictionary
	var distances: PackedFloat32Array = field.get("distances", PackedFloat32Array()) as PackedFloat32Array
	if distances.is_empty():
		return false
	for point_variant in points:
		if not (point_variant is Vector2):
			continue
		var index := _nearest_passable_index_for_point(point_variant as Vector2)
		if index < 0 or float(distances[index]) >= INF_DISTANCE * 0.5:
			return false
	return true


func has_target_field(target_player_index: int) -> bool:
	return _fields.has(target_player_index)


func nearest_passable_position(world_position: Vector2) -> Vector2:
	if not has_obstacles():
		return world_position
	var index := _nearest_passable_index_for_point(world_position)
	return _cell_center(_index_to_cell(index)) if index >= 0 else world_position


func _reset_grid() -> void:
	_blocked.clear()
	_blocked.resize(maxi(_cols * _rows, 0))
	_blocked.fill(0)
	_obstacle_count = 0


func _build_distances(target_index: int) -> PackedFloat32Array:
	var distances := PackedFloat32Array()
	distances.resize(_cols * _rows)
	distances.fill(INF_DISTANCE)
	distances[target_index] = 0.0
	var queue: Array = [target_index]
	var cursor := 0
	while cursor < queue.size():
		var current_index := int(queue[cursor])
		cursor += 1
		var current_cell := _index_to_cell(current_index)
		for offset_variant in NEIGHBOR_OFFSETS:
			var offset: Vector2i = offset_variant as Vector2i
			var neighbor_cell := current_cell + offset
			if not _is_cell_passable(neighbor_cell):
				continue
			var neighbor_index := _cell_index(neighbor_cell)
			if float(distances[neighbor_index]) < INF_DISTANCE * 0.5:
				continue
			distances[neighbor_index] = float(distances[current_index]) + 1.0
			queue.append(neighbor_index)
	return distances


func _build_vectors(distances: PackedFloat32Array) -> PackedVector2Array:
	var vectors := PackedVector2Array()
	vectors.resize(_cols * _rows)
	vectors.fill(Vector2.ZERO)
	var escape_visited := PackedByteArray()
	escape_visited.resize(_cols * _rows)
	escape_visited.fill(0)
	var escape_queue: Array = []
	for index in range(_cols * _rows):
		var current_distance := float(distances[index])
		if bool(_blocked[index]) or current_distance >= INF_DISTANCE * 0.5:
			continue
		escape_visited[index] = 1
		if _has_unreached_neighbor(index, distances):
			escape_queue.append(index)
		if current_distance <= 0.0:
			continue
		var current_cell := _index_to_cell(index)
		var best_distance := current_distance
		var best_index := -1
		for offset_variant in NEIGHBOR_OFFSETS:
			var offset: Vector2i = offset_variant as Vector2i
			var neighbor_cell := current_cell + offset
			if not _is_cell_passable(neighbor_cell):
				continue
			var neighbor_index := _cell_index(neighbor_cell)
			var neighbor_distance := float(distances[neighbor_index])
			if neighbor_distance < best_distance:
				best_distance = neighbor_distance
				best_index = neighbor_index
		if best_index >= 0:
			var vector := _cell_center(_index_to_cell(best_index)) - _cell_center(current_cell)
			vectors[index] = vector.normalized() if vector.length_squared() > 0.0001 else Vector2.ZERO
	_fill_escape_vectors(vectors, escape_visited, escape_queue)
	return vectors


func _has_unreached_neighbor(index: int, distances: PackedFloat32Array) -> bool:
	var cell := _index_to_cell(index)
	for offset_variant in NEIGHBOR_OFFSETS:
		var offset: Vector2i = offset_variant as Vector2i
		var neighbor_cell := cell + offset
		if not _is_cell_in_bounds(neighbor_cell):
			continue
		var neighbor_index := _cell_index(neighbor_cell)
		if bool(_blocked[neighbor_index]) or float(distances[neighbor_index]) >= INF_DISTANCE * 0.5:
			return true
	return false


func _fill_escape_vectors(vectors: PackedVector2Array, visited: PackedByteArray, queue: Array) -> void:
	var cursor := 0
	while cursor < queue.size():
		var current_index := int(queue[cursor])
		cursor += 1
		var current_cell := _index_to_cell(current_index)
		var current_center := _cell_center(current_cell)
		for offset_variant in NEIGHBOR_OFFSETS:
			var offset: Vector2i = offset_variant as Vector2i
			var neighbor_cell := current_cell + offset
			if not _is_cell_in_bounds(neighbor_cell):
				continue
			var neighbor_index := _cell_index(neighbor_cell)
			if bool(visited[neighbor_index]):
				continue
			visited[neighbor_index] = 1
			var neighbor_center := _cell_center(neighbor_cell)
			var escape_vector := current_center - neighbor_center
			vectors[neighbor_index] = escape_vector.normalized() if escape_vector.length_squared() > 0.0001 else Vector2.ZERO
			queue.append(neighbor_index)


func _nearest_passable_index_for_point(world_position: Vector2) -> int:
	var point_cell := _world_to_cell(world_position)
	if _is_cell_passable(point_cell):
		return _cell_index(point_cell)
	var max_radius := maxi(_cols, _rows)
	for search_radius in range(1, max_radius + 1):
		var ring_best_index := -1
		var ring_best_distance_sq := INF
		for cell_y in range(point_cell.y - search_radius, point_cell.y + search_radius + 1):
			for cell_x in range(point_cell.x - search_radius, point_cell.x + search_radius + 1):
				if abs(cell_x - point_cell.x) != search_radius and abs(cell_y - point_cell.y) != search_radius:
					continue
				var candidate_cell := Vector2i(cell_x, cell_y)
				if not _is_cell_passable(candidate_cell):
					continue
				var candidate_index := _cell_index(candidate_cell)
				var distance_sq := world_position.distance_squared_to(_cell_center(candidate_cell))
				if distance_sq < ring_best_distance_sq:
					ring_best_distance_sq = distance_sq
					ring_best_index = candidate_index
		if ring_best_index >= 0:
			return ring_best_index
	var best_index := -1
	var best_distance_sq := INF
	for index in range(_cols * _rows):
		if bool(_blocked[index]):
			continue
		var distance_sq := world_position.distance_squared_to(_cell_center(_index_to_cell(index)))
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best_index = index
	return best_index


func _flood_passable(start_index: int) -> PackedByteArray:
	var visited := PackedByteArray()
	visited.resize(_cols * _rows)
	visited.fill(0)
	if start_index < 0 or start_index >= visited.size() or bool(_blocked[start_index]):
		return visited
	var queue: Array = [start_index]
	visited[start_index] = 1
	var cursor := 0
	while cursor < queue.size():
		var current_index := int(queue[cursor])
		cursor += 1
		var current_cell := _index_to_cell(current_index)
		for offset_variant in NEIGHBOR_OFFSETS:
			var offset: Vector2i = offset_variant as Vector2i
			var neighbor_cell := current_cell + offset
			if not _is_cell_passable(neighbor_cell):
				continue
			var neighbor_index := _cell_index(neighbor_cell)
			if bool(visited[neighbor_index]):
				continue
			visited[neighbor_index] = 1
			queue.append(neighbor_index)
	return visited


func _is_cell_passable(cell: Vector2i) -> bool:
	return _is_cell_in_bounds(cell) and not bool(_blocked[_cell_index(cell)])


func _is_cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < _cols and cell.y >= 0 and cell.y < _rows


func _world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(floor((world_position.x - _arena_rect.position.x) / _cell_size)), 0, maxi(_cols - 1, 0)),
		clampi(int(floor((world_position.y - _arena_rect.position.y) / _cell_size)), 0, maxi(_rows - 1, 0))
	)


func _cell_index(cell: Vector2i) -> int:
	return cell.y * _cols + cell.x


func _index_to_cell(index: int) -> Vector2i:
	return Vector2i(index % _cols, int(floor(float(index) / float(_cols))))


func _cell_center(cell: Vector2i) -> Vector2:
	return _arena_rect.position + Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5) * _cell_size


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(_arena_rect.position + Vector2(cell) * _cell_size, Vector2(_cell_size, _cell_size))


func _normalized_or_zero(vector: Vector2) -> Vector2:
	return vector.normalized() if vector.length_squared() > 0.0001 else Vector2.ZERO
