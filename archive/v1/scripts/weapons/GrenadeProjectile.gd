extends Area2D

signal exploded(origin, color, feedback_profile, impact_weight, explosion_radius, combat_context)
signal damage_applied(origin, direction, team, color, feedback_profile, impact_weight, target, combat_context)

@export var gravity_force: float = 520.0
@export var fuse_time: float = 1.0
@export var explosion_radius: float = 106.0

var direction: Vector2 = Vector2.RIGHT
var speed: float = 125.0
var damage: int = 36
var team: String = ""
var impact_weight: float = 1.6
var feedback_profile: String = "grenade"
var source_context: Dictionary = {}
var knockback_force: float = 320.0

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
	_apply_explosion_damage(global_position, explosion_radius, damage)
	exploded.emit(global_position, _tint_color, feedback_profile, impact_weight, explosion_radius, _build_explosion_context(global_position, explosion_radius, damage))
	queue_free()

func _apply_explosion_damage(origin: Vector2, radius: float, damage_amount: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var groups_to_check: Array = ["aim_target"] if team == "player" else ["player_target"]
	for group_name in groups_to_check:
		for candidate in tree.get_nodes_in_group(group_name):
			if not is_instance_valid(candidate) or not (candidate is Node2D) or candidate == self:
				continue
			if candidate.has_method("get_team") and candidate.get_team() == team:
				continue
			var target_node: Node2D = candidate
			var distance := origin.distance_to(target_node.global_position)
			if distance > radius or not candidate.has_method("apply_damage"):
				continue
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
		"weapon_tags": [],
		"origin": origin,
		"direction": (target.global_position - origin).normalized(),
		"target": target,
		"damage": damage_amount,
		"color": _tint_color,
		"feedback_profile": feedback_profile,
		"impact_weight": impact_weight,
		"is_tick": false,
		"source_type": str(source_context.get("source_type", "secondary")),
	}

func _build_explosion_context(origin: Vector2, radius: float, damage_amount: int) -> Dictionary:
	var context: Dictionary = {
		"owner": source_context.get("owner", null),
		"weapon_id": str(source_context.get("weapon_id", "")),
		"origin": origin,
		"target": null,
		"damage": damage_amount,
		"radius": radius,
		"color": _tint_color,
		"feedback_profile": feedback_profile,
		"impact_weight": impact_weight,
		"source_type": str(source_context.get("source_type", "secondary")),
	}
	return context
