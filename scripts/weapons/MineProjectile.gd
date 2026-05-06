extends Area2D

signal exploded(origin, color)

@export var fuse_time: float = 12.0
@export var explosion_radius: float = 92.0
@export var kind: String = "mine"
@export var pulse_count: int = 1
@export var pulse_interval: float = 0.18
@export var cluster_blast_count: int = 0
@export var cluster_spread_radius: float = 52.0
@export var proximity_radius: float = 52.0

var direction: Vector2 = Vector2.RIGHT
var speed: float = 0.0
var damage: int = 3
var team: String = ""

@onready var visual: Polygon2D = $Visual
@onready var outline: Polygon2D = $Outline
@onready var proximity_ring: Line2D = $ProximityRing

var _tint_color: Color = Color(1.0, 0.72, 0.28, 1.0)
var _arms_at := 0.0
var _expires_at := 0.0
var _has_exploded := false

func setup(projectile_team: String, projectile_direction: Vector2, projectile_speed: float, projectile_damage: int, projectile_color: Color = Color(1.0, 0.72, 0.28, 1.0)) -> void:
	team = projectile_team
	direction = projectile_direction.normalized() if projectile_direction.length() > 0.0 else Vector2.RIGHT
	speed = projectile_speed
	damage = projectile_damage
	_tint_color = projectile_color

func _ready() -> void:
	var now: float = _current_time_seconds()
	_arms_at = now + 0.18
	_expires_at = now + fuse_time
	if visual != null:
		visual.color = _tint_color
		visual.scale = Vector2(1.18, 1.18)
		visual.polygon = PackedVector2Array([
			Vector2(-9, -6),
			Vector2(0, -10),
			Vector2(9, -6),
			Vector2(10, 4),
			Vector2(0, 10),
			Vector2(-10, 4),
		])
	if outline != null:
		var outline_tint: Color = _tint_color
		outline_tint.a = 0.88
		outline.color = outline_tint
		outline.scale = Vector2(1.52, 1.52)
		outline.polygon = visual.polygon if visual != null else outline.polygon
	if proximity_ring != null:
		var ring_tint: Color = _tint_color
		ring_tint.a = 0.56
		proximity_ring.default_color = ring_tint
		proximity_ring.visible = false
		proximity_ring.points = _build_circle_points(proximity_radius, 24)

func _physics_process(_delta: float) -> void:
	var now: float = _current_time_seconds()
	rotation = sin(now * 6.5) * 0.08
	if proximity_ring != null:
		proximity_ring.visible = now >= _arms_at
		proximity_ring.width = 2.0 + 0.5 * sin(now * 8.0)
	if now >= _expires_at:
		queue_free()
		return
	if now >= _arms_at and _check_proximity_trigger():
		_explode()

func _explode() -> void:
	if _has_exploded:
		return
	_has_exploded = true
	set_physics_process(false)
	visible = false
	match kind:
		"shrapnel_mine", "cluster_mine":
			_explode_shrapnel_mine()
		"heavy_mine", "siege_mine":
			_explode_heavy_mine()
		_:
			_apply_explosion_damage(global_position, explosion_radius, damage)
			exploded.emit(global_position, _tint_color)
			queue_free()

func _explode_shrapnel_mine() -> void:
	var blast_points: Array = [global_position]
	var blast_count: int = max(cluster_blast_count, 4)
	for index in range(blast_count):
		var angle := TAU * float(index) / float(blast_count)
		blast_points.append(global_position + Vector2.RIGHT.rotated(angle) * cluster_spread_radius)

	var blast_radius: float = explosion_radius * 0.56
	var blast_damage: int = max(1, int(round(float(damage) * 0.7)))
	for blast_point in blast_points:
		_apply_explosion_damage(blast_point, blast_radius, blast_damage)
		exploded.emit(blast_point, _tint_color)
	queue_free()

func _explode_heavy_mine() -> void:
	_apply_explosion_damage(global_position, explosion_radius, damage)
	exploded.emit(global_position, _tint_color)
	if pulse_count <= 1:
		queue_free()
		return

	for pulse_index in range(1, pulse_count):
		var tree := get_tree()
		if tree == null:
			break
		await tree.create_timer(pulse_interval, false).timeout
		if not is_inside_tree():
			return
		var pulse_scale: float = 1.0 + float(pulse_index) * 0.18
		var pulse_damage: int = max(1, damage - pulse_index)
		_apply_explosion_damage(global_position, explosion_radius * pulse_scale, pulse_damage)
		exploded.emit(global_position, _tint_color)
	queue_free()

func _apply_explosion_damage(origin: Vector2, radius: float, damage_amount: int) -> void:
	var tree := get_tree()
	if tree == null:
		return

	var groups_to_check := ["aim_target"] if team == "player" else ["player_target"]
	for group_name in groups_to_check:
		for candidate in tree.get_nodes_in_group(group_name):
			if not is_instance_valid(candidate):
				continue
			if not (candidate is Node2D):
				continue
			if candidate.has_method("get_team") and candidate.get_team() == team:
				continue

			var target_node: Node2D = candidate
			var distance: float = origin.distance_to(target_node.global_position)
			if distance <= radius and candidate.has_method("apply_damage"):
				candidate.apply_damage(damage_amount)

func _check_proximity_trigger() -> bool:
	var tree := get_tree()
	if tree == null:
		return false

	var groups_to_check := ["aim_target"] if team == "player" else ["player_target"]
	for group_name in groups_to_check:
		for candidate in tree.get_nodes_in_group(group_name):
			if not is_instance_valid(candidate):
				continue
			if not (candidate is Node2D):
				continue
			if candidate.has_method("get_team") and candidate.get_team() == team:
				continue
			if global_position.distance_to(candidate.global_position) <= proximity_radius:
				return true
	return false

func _build_circle_points(radius: float, point_count: int) -> PackedVector2Array:
	var points: Array = []
	for index in range(point_count):
		var angle := TAU * float(index) / float(point_count)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return PackedVector2Array(points)

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
