extends Area2D

signal exploded(origin, color, feedback_profile, impact_weight, explosion_radius, combat_context)
signal damage_applied(origin, direction, team, color, feedback_profile, impact_weight, target, combat_context)

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
var impact_weight: float = 1.6
var feedback_profile: String = "grenade"
var source_context: Dictionary = {}

@onready var visual: Polygon2D = $Visual
@onready var outline: Polygon2D = $Outline

var _velocity: Vector2 = Vector2.ZERO
var _explode_at := 0.0
var _tint_color: Color = Color(1.0, 0.72, 0.28, 1.0)
var _has_exploded := false

func setup(projectile_team: String, projectile_direction: Vector2, projectile_speed: float, projectile_damage: int, projectile_color: Color = Color(1.0, 0.72, 0.28, 1.0), projectile_feedback_profile: String = "grenade", projectile_impact_weight: float = 1.6) -> void:
	team = projectile_team
	direction = projectile_direction.normalized() if projectile_direction.length() > 0.0 else Vector2.RIGHT
	speed = projectile_speed
	damage = projectile_damage
	_tint_color = projectile_color
	feedback_profile = projectile_feedback_profile
	impact_weight = projectile_impact_weight
	source_context = {}
	_velocity = direction * speed + Vector2(0.0, -180.0)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_explode_at = _current_time_seconds() + fuse_time
	if visual != null:
		visual.color = _tint_color
		visual.scale = Vector2(1.2, 1.2)
	if outline != null:
		var outline_tint: Color = _tint_color
		outline_tint.a = 0.88
		outline.color = outline_tint
		outline.scale = Vector2(1.52, 1.52)
		outline.polygon = visual.polygon if visual != null else outline.polygon

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
	if _has_exploded:
		return
	_has_exploded = true
	set_physics_process(false)
	visible = false
	match kind:
		"cluster_grenade", "cluster":
			_explode_cluster_grenade()
		"siege_grenade", "siege":
			_explode_siege_grenade()
		_:
			_apply_explosion_damage(global_position, explosion_radius, damage)
			exploded.emit(global_position, _tint_color, feedback_profile, impact_weight, explosion_radius, _build_explosion_context(global_position, explosion_radius, damage))
			queue_free()

func _explode_cluster_grenade() -> void:
	var blast_points: Array = [global_position]
	var blast_count: int = max(cluster_blast_count, 4)
	for index in range(blast_count):
		var angle := TAU * float(index) / float(blast_count)
		blast_points.append(global_position + Vector2.RIGHT.rotated(angle) * cluster_spread_radius)

	var blast_radius: float = explosion_radius * 0.56
	var blast_damage: int = max(1, int(round(float(damage) * 0.7)))
	for blast_point in blast_points:
		_apply_explosion_damage(blast_point, blast_radius, blast_damage)
		exploded.emit(blast_point, _tint_color, feedback_profile, impact_weight, blast_radius, _build_explosion_context(blast_point, blast_radius, blast_damage))
	queue_free()

func _explode_siege_grenade() -> void:
	_apply_explosion_damage(global_position, explosion_radius, damage)
	exploded.emit(global_position, _tint_color, feedback_profile, impact_weight, explosion_radius, _build_explosion_context(global_position, explosion_radius, damage))
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
		var pulse_radius: float = explosion_radius * pulse_scale
		_apply_explosion_damage(global_position, pulse_radius, pulse_damage)
		exploded.emit(global_position, _tint_color, feedback_profile, impact_weight, pulse_radius, _build_explosion_context(global_position, pulse_radius, pulse_damage))
	queue_free()

func _apply_explosion_damage(origin: Vector2, radius: float, damage_amount: int) -> void:
	var tree := get_tree()
	if tree == null:
		return

	var groups_to_check: Array = ["aim_target"] if team == "player" else ["player_target"]
	var knockback_force: float = 240.0
	if kind == "grenade":
		knockback_force *= 1.4

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
				if candidate.has_method("apply_knockback"):
					candidate.apply_knockback((target_node.global_position - origin).normalized(), knockback_force)
				candidate.apply_damage(damage_amount)
				damage_applied.emit(origin, (target_node.global_position - origin).normalized(), team, _tint_color, feedback_profile, impact_weight, candidate, _build_combat_context(origin, target_node, damage_amount))

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _build_combat_context(origin: Vector2, target: Node2D, damage_amount: int) -> Dictionary:
	return {
		"owner": source_context.get("owner", null),
		"weapon_id": str(source_context.get("weapon_id", "")),
		"weapon_tags": (source_context.get("weapon_tags", []) as Array).duplicate(true),
		"origin": origin,
		"direction": (target.global_position - origin).normalized(),
		"target": target,
		"damage": damage_amount,
		"color": _tint_color,
		"feedback_profile": feedback_profile,
		"impact_weight": impact_weight,
		"is_tick": false,
		"source_type": str(source_context.get("source_type", "secondary")),
		"trigger_passives": (source_context.get("trigger_passives", []) as Array).duplicate(true),
	}

func _build_explosion_context(origin: Vector2, radius: float, damage_amount: int) -> Dictionary:
	var context: Dictionary = _build_combat_context(origin, self, damage_amount)
	context["origin"] = origin
	context["target"] = null
	context["radius"] = radius
	return context
