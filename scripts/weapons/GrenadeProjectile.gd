extends Area2D

@export var gravity_force: float = 520.0
@export var fuse_time: float = 1.0
@export var explosion_radius: float = 92.0

var direction: Vector2 = Vector2.RIGHT
var speed: float = 320.0
var damage: int = 3
var team: String = ""

var _velocity: Vector2 = Vector2.ZERO
var _explode_at := 0.0

func setup(projectile_team: String, projectile_direction: Vector2, projectile_speed: float, projectile_damage: int) -> void:
	team = projectile_team
	direction = projectile_direction.normalized() if projectile_direction.length() > 0.0 else Vector2.RIGHT
	speed = projectile_speed
	damage = projectile_damage
	_velocity = direction * speed + Vector2(0.0, -180.0)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_explode_at = _current_time_seconds() + fuse_time

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
	var tree := get_tree()
	if tree == null:
		queue_free()
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
			var distance: float = global_position.distance_to(target_node.global_position)
			if distance <= explosion_radius and candidate.has_method("apply_damage"):
				candidate.apply_damage(damage)

	queue_free()

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
