class_name HealthPickup
extends Area2D

const MAGNET_RADIUS := 160.0
const MAGNET_ACCELERATION := 1200.0
const MAGNET_MAX_SPEED := 600.0
const COLLECT_RADIUS := 48.0

var heal_amount: int = 5
var magnet_speed: float = 0.0

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

func _build_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
