extends RefCounted

static func distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_sq := segment.length_squared()
	if length_sq <= 0.001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(segment) / length_sq, 0.0, 1.0)
	return point.distance_to(start + segment * t)


static func default_player_spawn_position(index: int, arena_center: Vector2) -> Vector2:
	return arena_center + Vector2((index % 2) * 160.0 - 80.0, floor(index / 2.0) * 120.0 - 60.0)


static func boss_room_player_spawn_position(index: int, player_count: int, arena_center: Vector2, arena_rect: Rect2, boss_player_spawn_distance: float) -> Vector2:
	var horizontal_spacing := 180.0
	var center_offset := (float(index) - (float(maxi(player_count, 1)) - 1.0) * 0.5) * horizontal_spacing
	return Vector2(
		clampf(arena_center.x + center_offset, arena_rect.position.x + 220.0, arena_rect.end.x - 220.0),
		clampf(arena_center.y + boss_player_spawn_distance, arena_rect.position.y + 220.0, arena_rect.end.y - 220.0)
	)


static func enemy_spawn_position_for_index(spawn_index: int, start_edge: int, inner_margin: float, arena_size: Vector2) -> Vector2:
	var edge := (start_edge + spawn_index) % 4
	return enemy_spawn_position_for_edge(edge, inner_margin, arena_size)


static func enemy_spawn_position_for_edge(edge: int, inner_margin: float, arena_size: Vector2) -> Vector2:
	match edge:
		0:
			return Vector2(randf_range(inner_margin, arena_size.x - inner_margin), inner_margin + randf_range(0.0, 60.0))
		1:
			return Vector2(randf_range(inner_margin, arena_size.x - inner_margin), arena_size.y - inner_margin - randf_range(0.0, 60.0))
		2:
			return Vector2(inner_margin + randf_range(0.0, 60.0), randf_range(inner_margin, arena_size.y - inner_margin))
		_:
			return Vector2(arena_size.x - inner_margin - randf_range(0.0, 60.0), randf_range(inner_margin, arena_size.y - inner_margin))


static func champion_spawn_position(arena_center: Vector2) -> Vector2:
	return arena_center + Vector2(randf_range(-180.0, 180.0), randf_range(-120.0, 120.0))


static func build_spread_directions(base_direction: Vector2, projectile_count: int, spread_step: float) -> Array:
	var normalized := base_direction.normalized() if base_direction.length() > 0.0 else Vector2.RIGHT
	if projectile_count <= 1 or spread_step <= 0.0:
		return [normalized]
	var directions: Array = [normalized]
	var extras := projectile_count - 1
	for index in range(1, extras + 1):
		var side := 1 if index % 2 == 1 else -1
		var rank := int(ceil(float(index) / 2.0))
		directions.append(normalized.rotated(spread_step * float(rank) * float(side)))
	return directions
