class_name GoldPickup
extends Area2D

const MAGNET_RADIUS := 160.0
const MAGNET_ACCELERATION := 1200.0
const MAGNET_MAX_SPEED := 600.0
const COLLECT_RADIUS := 48.0

var amount: int = 5
var magnet_speed: float = 0.0

func _ready() -> void:
	var visual := Polygon2D.new()
	visual.polygon = _build_circle_polygon(12.0, 8)
	visual.color = Color(1.0, 0.85, 0.2, 0.95)
	add_child(visual)

func _build_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
