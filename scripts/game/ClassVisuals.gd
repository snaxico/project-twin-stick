class_name ClassVisuals
extends RefCounted

const DEFAULT_ACCENT := Color(0.28, 0.9, 0.82, 1.0)

const VISUALS := {
	"mobile": {
		"accent_color": Color(0.25, 0.95, 1.0, 1.0),
		"silhouette_points": [Vector2(20, 0), Vector2(-10, -10), Vector2(-16, -4), Vector2(-6, 0), Vector2(-16, 4), Vector2(-10, 10)],
		"trail_style": "kinetic",
	},
	"tank": {
		"accent_color": Color(0.9, 0.16, 0.18, 1.0),
		"silhouette_points": [Vector2(12, -14), Vector2(18, 0), Vector2(12, 14), Vector2(-10, 14), Vector2(-18, 0), Vector2(-10, -14)],
		"trail_style": "weight",
	},
	"controller": {
		"accent_color": Color(0.66, 0.32, 1.0, 1.0),
		"silhouette_points": [Vector2(0, -20), Vector2(18, 0), Vector2(0, 20), Vector2(-18, 0)],
		"trail_style": "arcane",
	},
	"risk": {
		"accent_color": Color(1.0, 0.42, 0.08, 1.0),
		"silhouette_points": [Vector2(19, -2), Vector2(5, -16), Vector2(-5, -8), Vector2(-17, -12), Vector2(-9, 0), Vector2(-17, 13), Vector2(-2, 8), Vector2(8, 17)],
		"trail_style": "ember",
	},
}

static func get_visuals(class_id: String) -> Dictionary:
	return (VISUALS.get(class_id, VISUALS.get("mobile", {})) as Dictionary).duplicate(true)

static func get_accent_color(class_id: String) -> Color:
	return get_visuals(class_id).get("accent_color", DEFAULT_ACCENT)

static func get_silhouette_points(class_id: String) -> PackedVector2Array:
	var raw_points: Array = get_visuals(class_id).get("silhouette_points", []) as Array
	var points := PackedVector2Array()
	for point in raw_points:
		if point is Vector2:
			points.append(point)
	return points

static func get_trail_style(class_id: String) -> String:
	return str(get_visuals(class_id).get("trail_style", "kinetic"))
