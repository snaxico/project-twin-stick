class_name FireTrailZone
extends Area2D

var damage: int = 1
var lifetime: float = 1.5
var tick_interval: float = 0.5
var team: String = "player"
var knockback_force: float = 0.0
var _expires_at: float = 0.0
var _next_tick_at: float = 0.0
var _tracked_targets: Array = []

func configure(zone_radius: float, zone_damage: int, zone_lifetime: float, zone_tick_interval: float, zone_team: String, zone_knockback_force: float = 0.0) -> void:
	damage = max(zone_damage, 1)
	lifetime = max(zone_lifetime, 0.1)
	tick_interval = max(zone_tick_interval, 0.1)
	team = zone_team
	knockback_force = max(zone_knockback_force, 0.0)
	var collision_shape := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = max(zone_radius, 8.0)
	collision_shape.shape = shape
	add_child(collision_shape)

	var visual := Polygon2D.new()
	visual.color = Color(1.0, 0.46, 0.14, 0.28)
	visual.polygon = _build_circle_points(shape.radius, 18)
	add_child(visual)

func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	_expires_at = _current_time_seconds() + lifetime
	_next_tick_at = _current_time_seconds()

func _physics_process(_delta: float) -> void:
	var now := _current_time_seconds()
	if now >= _expires_at:
		queue_free()
		return
	if now < _next_tick_at:
		return
	_next_tick_at = now + tick_interval
	for target in _tracked_targets.duplicate():
		if target == null or not is_instance_valid(target):
			_tracked_targets.erase(target)
			continue
		if not target.has_method("apply_damage"):
			continue
		if target.has_method("get_team") and str(target.get_team()) == team:
			continue
		if knockback_force > 0.0 and target.has_method("apply_knockback"):
			target.apply_knockback((target.global_position - global_position).normalized(), knockback_force)
		target.apply_damage(damage)

func _on_body_entered(body: Node) -> void:
	_track_target(body)

func _on_body_exited(body: Node) -> void:
	_tracked_targets.erase(body)

func _on_area_entered(area: Area2D) -> void:
	_track_target(area)

func _on_area_exited(area: Area2D) -> void:
	_tracked_targets.erase(area)

func _track_target(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if _tracked_targets.has(target):
		return
	_tracked_targets.append(target)

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _build_circle_points(radius: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := TAU * float(index) / float(point_count)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points
