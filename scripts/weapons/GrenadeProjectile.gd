extends Area2D

signal exploded(origin, color)

@export var gravity_force: float = 520.0
@export var fuse_time: float = 1.0
@export var explosion_radius: float = 92.0
@export var kind: String = "grenade"
@export var pulse_count: int = 1
@export var pulse_interval: float = 0.18
@export var cluster_blast_count: int = 0
@export var cluster_spread_radius: float = 52.0

var direction: Vector2 = Vector2.RIGHT
var speed: float = 320.0
var damage: int = 3
var team: String = ""

@onready var visual: Polygon2D = $Visual

var _velocity: Vector2 = Vector2.ZERO
var _explode_at := 0.0
var _tint_color: Color = Color(1.0, 0.72, 0.28, 1.0)

func setup(projectile_team: String, projectile_direction: Vector2, projectile_speed: float, projectile_damage: int, projectile_color: Color = Color(1.0, 0.72, 0.28, 1.0)) -> void:
	team = projectile_team
	direction = projectile_direction.normalized() if projectile_direction.length() > 0.0 else Vector2.RIGHT
	speed = projectile_speed
	damage = projectile_damage
	_tint_color = projectile_color
	_velocity = direction * speed + Vector2(0.0, -180.0)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_explode_at = _current_time_seconds() + fuse_time
	if visual != null:
		visual.color = _tint_color

func _physics_process(delta: float) -> void:
	_velocity.y += gravity_force * delta
	global_position += _velocity * delta
	rotation += delta * 6.0
	if _current_time_seconds() >= _explode_at:
		_explode()

func _on_body_entered(body: Node) -> void:
	if body is StaticBody2D:
		_explode()

func _explode() -> void:
	match kind:
		"cluster":
			_explode_cluster()
		"siege":
			_explode_siege()
		_:
			_apply_explosion_damage(global_position, explosion_radius, damage)
			exploded.emit(global_position, _tint_color)
	queue_free()

func _explode_cluster() -> void:
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

func _explode_siege() -> void:
	_apply_explosion_damage(global_position, explosion_radius, damage)
	exploded.emit(global_position, _tint_color)
	if pulse_count <= 1:
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
			if candidate == self:
				continue
			if candidate.has_method("get_team") and candidate.get_team() == team:
				continue

			var target_node: Node2D = candidate
			var distance: float = origin.distance_to(target_node.global_position)
			if distance <= radius and candidate.has_method("apply_damage"):
				candidate.apply_damage(damage_amount)

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
