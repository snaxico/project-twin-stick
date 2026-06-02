class_name HealthPickup
extends Area2D

const MAGNET_RADIUS := 160.0
const MAGNET_ACCELERATION := 1200.0
const MAGNET_MAX_SPEED := 600.0
const COLLECT_RADIUS := 48.0

var heal_amount: int = 5
var magnet_speed: float = 0.0
var _collected := false

func _ready() -> void:
	var ring := Polygon2D.new()
	ring.polygon = _build_circle_polygon(12.0, 8)
	ring.color = Color(0.22, 1.0, 0.54, 0.95)
	add_child(ring)

	var cross := Polygon2D.new()
	cross.polygon = PackedVector2Array([
		Vector2(-3.0, -10.0),
		Vector2(3.0, -10.0),
		Vector2(3.0, -3.0),
		Vector2(10.0, -3.0),
		Vector2(10.0, 3.0),
		Vector2(3.0, 3.0),
		Vector2(3.0, 10.0),
		Vector2(-3.0, 10.0),
		Vector2(-3.0, 3.0),
		Vector2(-10.0, 3.0),
		Vector2(-10.0, -3.0),
		Vector2(-3.0, -3.0),
	])
	cross.color = Color(0.88, 1.0, 0.92, 0.98)
	add_child(cross)

func _process(delta: float) -> void:
	if _collected:
		return
	var tree := get_tree()
	if tree == null:
		return
	var nearest_player: Node2D = null
	var nearest_distance := INF
	for candidate in tree.get_nodes_in_group("player_target"):
		if not is_instance_valid(candidate) or not (candidate is Node2D):
			continue
		if candidate.has_method("is_alive") and not candidate.is_alive():
			continue
		if not candidate.has_method("heal"):
			continue
		var distance := global_position.distance_to((candidate as Node2D).global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_player = candidate as Node2D
	if nearest_player == null:
		return
	if nearest_distance < MAGNET_RADIUS:
		var direction := (nearest_player.global_position - global_position).normalized()
		magnet_speed = minf(magnet_speed + MAGNET_ACCELERATION * delta, MAGNET_MAX_SPEED)
		global_position += direction * magnet_speed * delta
		nearest_distance = nearest_player.global_position.distance_to(global_position)
	if nearest_distance <= COLLECT_RADIUS:
		_collected = true
		nearest_player.heal(heal_amount)
		queue_free()

func _build_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
