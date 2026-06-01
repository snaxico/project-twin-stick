class_name CollectorOrb
extends Node2D

const MAGNET_RADIUS := 180.0
const COLLECT_RADIUS := 28.0
const MAGNET_ACCELERATION := 560.0
const MAGNET_MAX_SPEED := 540.0

var magnet_speed := 0.0
var collected := false

func update_orb(delta: float, player_nodes: Array) -> bool:
	if collected:
		return true
	var nearest_player: Node2D = null
	var nearest_distance := INF
	for player in player_nodes:
		if player == null or not is_instance_valid(player) or not player.has_method("is_alive") or not player.is_alive():
			continue
		var distance: float = player.global_position.distance_to(global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_player = player
	if nearest_player == null:
		return false
	if nearest_distance < MAGNET_RADIUS:
		var direction := (nearest_player.global_position - global_position).normalized()
		magnet_speed = minf(magnet_speed + MAGNET_ACCELERATION * delta, MAGNET_MAX_SPEED)
		global_position += direction * magnet_speed * delta
		nearest_distance = nearest_player.global_position.distance_to(global_position)
	if nearest_distance <= COLLECT_RADIUS:
		collected = true
		queue_free()
		return true
	queue_redraw()
	return false

func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.94, 0.68, 0.42))
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 18, Color(1.0, 1.0, 0.9, 0.96), 3.0)
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 20, Color(1.0, 0.92, 0.54, 0.22), 2.0)
