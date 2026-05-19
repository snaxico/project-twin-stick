class_name ZoomCamera
extends Camera2D

const MIN_PLAYER_SEPARATION := 320.0

@export var zoom_min: float = 0.35
@export var zoom_max: float = 0.7
@export var padding: Vector2 = Vector2(260.0, 220.0)
@export var follow_speed: float = 8.0
@export var arena_margin: float = 96.0

var _tracked_players: Array = []
var _arena_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(1920.0, 1080.0))

func set_players(players: Array) -> void:
	_tracked_players = players

func set_arena_rect(arena_rect: Rect2) -> void:
	_arena_rect = arena_rect

func get_max_player_separation() -> float:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return MIN_PLAYER_SEPARATION
	var horizontal_span := viewport_size.x * zoom_min - padding.x * 2.0
	var vertical_span := viewport_size.y * zoom_min - padding.y * 2.0
	return maxf(minf(horizontal_span, vertical_span), MIN_PLAYER_SEPARATION)

func _ready() -> void:
	enabled = true
	position_smoothing_enabled = false

func _process(delta: float) -> void:
	var active_players := _get_active_players()
	if active_players.is_empty():
		return

	var bounds := _build_player_bounds(active_players)
	var desired_zoom := _compute_zoom(bounds)
	var desired_position := bounds.get_center()
	desired_position = _clamp_position_to_arena(desired_position, desired_zoom)

	var weight: float = clampf(delta * follow_speed, 0.0, 1.0)
	global_position = global_position.lerp(desired_position, weight)
	zoom = zoom.lerp(Vector2.ONE * desired_zoom, weight)

func _get_active_players() -> Array:
	var active_players: Array = []
	for player in _tracked_players:
		if player == null or not is_instance_valid(player):
			continue
		if player.has_method("is_alive") and not player.is_alive():
			continue
		active_players.append(player)
	return active_players

func _build_player_bounds(active_players: Array) -> Rect2:
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for player in active_players:
		var player_position: Vector2 = player.global_position
		min_point.x = min(min_point.x, player_position.x)
		min_point.y = min(min_point.y, player_position.y)
		max_point.x = max(max_point.x, player_position.x)
		max_point.y = max(max_point.y, player_position.y)
	min_point -= padding
	max_point += padding
	return Rect2(min_point, max_point - min_point)

func _compute_zoom(bounds: Rect2) -> float:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return clampf(zoom.x, zoom_min, zoom_max)
	var width_ratio: float = viewport_size.x / maxf(bounds.size.x, 1.0)
	var height_ratio: float = viewport_size.y / maxf(bounds.size.y, 1.0)
	var desired_zoom: float = minf(width_ratio, height_ratio)
	return clampf(desired_zoom, zoom_min, zoom_max)

func _clamp_position_to_arena(desired_position: Vector2, zoom_value: float) -> Vector2:
	var viewport_size := get_viewport_rect().size
	var half_extents: Vector2 = viewport_size * zoom_value * 0.5
	var min_position: Vector2 = _arena_rect.position + half_extents - Vector2.ONE * arena_margin
	var max_position: Vector2 = _arena_rect.end - half_extents + Vector2.ONE * arena_margin
	return Vector2(
		clampf(desired_position.x, min(min_position.x, max_position.x), max(min_position.x, max_position.x)),
		clampf(desired_position.y, min(min_position.y, max_position.y), max(min_position.y, max_position.y))
	)
