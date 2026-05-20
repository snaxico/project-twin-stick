extends Area2D

const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")
const FireTrailZoneData = preload("res://scripts/weapons/FireTrailZone.gd")
const BASE_COLLISION_HALF_WIDTH := 4.0
const TRAIL_SPAWN_INTERVAL := 0.15
const TRAIL_PARTICLE_SOFT_CAP := 90
const ENEMY_TRAIL_PARTICLE_SOFT_CAP := 36

@export var lifetime: float = 1.8

signal impact_requested(origin, direction, team, color, feedback_profile, impact_weight, target, combat_context)

var direction: Vector2 = Vector2.RIGHT
var speed: float = 500.0
var damage: int = 1
var team: String = ""
var tint_color: Color = Color(1.0, 0.96, 0.7, 1.0)
var allow_friendly_fire := false
var feedback_profile: String = "rifle"
var impact_weight: float = 1.0
var max_distance: float = 0.0
var collision_half_width: float = BASE_COLLISION_HALF_WIDTH
var pierce_count: int = 0
var pierce_remaining: int = 0
var ricochet_remaining: int = 0
var ricochet_range: float = 200.0
var leaves_fire_trail := false
var trail_lifetime: float = 1.5
var trail_tick_interval: float = 0.5
var trail_damage_percent: float = 0.3
var knockback_force: float = 0.0
var source_type: String = "projectile"
var weapon_id: String = ""
var weapon_tags: Array = []
var trigger_passives: Array = []
var use_lifetime := true
var _shooter_node: Node = null

@onready var visual: Polygon2D = $Visual
@onready var outline: Polygon2D = $Outline
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _expires_at := 0.0
var _trail_particles: GPUParticles2D = null
var _spawn_position := Vector2.ZERO
var _base_collision_radius := 0.0
var _base_visual_scale := Vector2.ONE
var _hit_targets: Array = []
var _next_trail_spawn_at := 0.0

func setup(projectile_team: String, projectile_direction: Vector2, projectile_speed: float, projectile_damage: int, projectile_color: Color = Color(1.0, 0.96, 0.7, 1.0), projectile_shooter: Node = null, projectile_feedback_profile: String = "rifle", projectile_impact_weight: float = 1.0) -> void:
	team = projectile_team
	direction = projectile_direction.normalized() if projectile_direction.length() > 0.0 else Vector2.RIGHT
	speed = projectile_speed
	damage = projectile_damage
	tint_color = projectile_color
	_shooter_node = projectile_shooter
	feedback_profile = projectile_feedback_profile
	impact_weight = projectile_impact_weight
	max_distance = 0.0
	collision_half_width = BASE_COLLISION_HALF_WIDTH
	pierce_count = 0
	pierce_remaining = 0
	ricochet_remaining = 0
	ricochet_range = 200.0
	leaves_fire_trail = false
	trail_lifetime = 1.5
	trail_tick_interval = 0.5
	trail_damage_percent = 0.3
	knockback_force = 0.0
	source_type = "projectile"
	weapon_id = ""
	weapon_tags = []
	trigger_passives = []
	use_lifetime = projectile_team != "enemy"
	_hit_targets.clear()

func setup_from_config(projectile_team: String, projectile_direction: Vector2, config: Dictionary) -> void:
	setup(
		projectile_team,
		projectile_direction,
		float(config.get("speed", speed)),
		int(config.get("damage", damage)),
		config.get("color", tint_color),
		config.get("shooter", null),
		str(config.get("feedback_profile", feedback_profile)),
		float(config.get("impact_weight", impact_weight))
	)
	max_distance = max(0.0, float(config.get("max_distance", max_distance)))
	collision_half_width = max(0.1, float(config.get("collision_half_width", collision_half_width)))
	pierce_count = max(0, int(config.get("pierce_count", pierce_count)))
	pierce_remaining = pierce_count
	ricochet_remaining = max(0, int(config.get("ricochet_count", 0)))
	ricochet_range = max(1.0, float(config.get("ricochet_range", ricochet_range)))
	leaves_fire_trail = bool(config.get("leaves_fire_trail", false))
	trail_lifetime = max(0.1, float(config.get("trail_lifetime", trail_lifetime)))
	trail_tick_interval = max(0.1, float(config.get("trail_tick_interval", trail_tick_interval)))
	trail_damage_percent = max(0.0, float(config.get("trail_damage_percent", trail_damage_percent)))
	knockback_force = max(0.0, float(config.get("knockback_force", knockback_force)))
	source_type = str(config.get("source_type", source_type))
	weapon_id = str(config.get("weapon_id", weapon_id))
	weapon_tags = (config.get("weapon_tags", []) as Array).duplicate(true)
	trigger_passives = (config.get("trigger_passives", []) as Array).duplicate(true)
	use_lifetime = bool(config.get("use_lifetime", use_lifetime))

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_expires_at = _current_time_seconds() + lifetime
	rotation = direction.angle()
	_spawn_position = global_position
	if visual != null:
		_base_visual_scale = visual.scale
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		collision_shape.shape = (collision_shape.shape as CircleShape2D).duplicate()
		_base_collision_radius = (collision_shape.shape as CircleShape2D).radius
	_apply_visual_state()
	if _should_spawn_trail_particles():
		_trail_particles = ParticleFactoryData.create_projectile_trail(_get_projectile_color())
		add_child(_trail_particles)
	_next_trail_spawn_at = _current_time_seconds()

func _physics_process(delta: float) -> void:
	rotation = direction.angle()
	global_position += direction * speed * delta
	if max_distance > 0.0 and global_position.distance_squared_to(_spawn_position) >= max_distance * max_distance:
		queue_free()
		return
	if leaves_fire_trail and _current_time_seconds() >= _next_trail_spawn_at:
		_spawn_fire_trail_zone()
		_next_trail_spawn_at = _current_time_seconds() + TRAIL_SPAWN_INTERVAL
	if use_lifetime and _current_time_seconds() >= _expires_at:
		queue_free()

func _spawn_fire_trail_zone() -> void:
	if get_parent() == null:
		return
	var trail := FireTrailZoneData.new()
	trail.global_position = global_position
	trail.configure(
		max(collision_half_width * 1.6, 10.0),
		max(1, int(round(float(damage) * trail_damage_percent))),
		trail_lifetime,
		trail_tick_interval,
		team,
		knockback_force
	)
	get_parent().add_child(trail)

func _on_body_entered(body: Node) -> void:
	if body is StaticBody2D:
		impact_requested.emit(global_position, -direction, team, _get_projectile_color(), feedback_profile, impact_weight, body, _build_combat_context(body))
		queue_free()
		return
	_attempt_hit_target(body)

func _on_area_entered(area: Area2D) -> void:
	_attempt_hit_target(area)

func _attempt_hit_target(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("apply_damage"):
		return
	if _hit_targets.has(target):
		return
	if target.has_method("get_team") and str(target.get_team()) == team:
		return
	if knockback_force > 0.0 and target.has_method("apply_knockback"):
		target.apply_knockback(direction, knockback_force)
	elif target.has_method("apply_knockback"):
		target.apply_knockback(direction, 180.0 + impact_weight * 90.0)
	target.apply_damage(damage)
	_hit_targets.append(target)
	impact_requested.emit(global_position, -direction, team, _get_projectile_color(), feedback_profile, impact_weight, target, _build_combat_context(target))
	if pierce_remaining > 0:
		pierce_remaining -= 1
		return
	if ricochet_remaining > 0 and _redirect_to_ricochet_target(target):
		ricochet_remaining -= 1
		return
	queue_free()

func _redirect_to_ricochet_target(previous_target: Node) -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var best_target: Node2D = null
	var best_distance := INF
	for candidate in tree.get_nodes_in_group("aim_target"):
		if candidate == null or not is_instance_valid(candidate) or candidate == previous_target:
			continue
		if _hit_targets.has(candidate):
			continue
		if not (candidate is Node2D):
			continue
		var distance := global_position.distance_to((candidate as Node2D).global_position)
		if distance > ricochet_range or distance >= best_distance:
			continue
		best_distance = distance
		best_target = candidate as Node2D
	if best_target == null:
		return false
	direction = (best_target.global_position - global_position).normalized()
	rotation = direction.angle()
	return true

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _apply_visual_state() -> void:
	if visual == null:
		return
	var projectile_color: Color = _get_projectile_color()
	var enemy_shot: bool = team == "enemy"
	var size_scale: float = maxf(collision_half_width / BASE_COLLISION_HALF_WIDTH, 0.25)
	if enemy_shot:
		visual.color = projectile_color.lightened(0.18)
		visual.scale = _base_visual_scale * 1.36 * size_scale
		visual.polygon = _build_orb_polygon(8.0)
	else:
		visual.color = projectile_color.lightened(0.05)
		visual.scale = _base_visual_scale * 1.18 * size_scale
		visual.polygon = _build_orb_polygon(6.0)
	if outline != null:
		outline.visible = true
		outline.color = Color(1.0, 0.94, 0.88, 0.92) if enemy_shot else projectile_color.lightened(0.26)
		outline.scale = visual.scale * 1.24
		outline.polygon = visual.polygon
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = _base_collision_radius * size_scale

func _get_projectile_color() -> Color:
	return tint_color

func _should_spawn_trail_particles() -> bool:
	var parent_node := get_parent()
	if parent_node == null:
		return false
	var sibling_count := parent_node.get_child_count()
	if sibling_count >= TRAIL_PARTICLE_SOFT_CAP:
		return false
	if team == "enemy" and sibling_count >= ENEMY_TRAIL_PARTICLE_SOFT_CAP:
		return false
	return true

func _build_orb_polygon(radius: float, point_count: int = 8) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := TAU * float(index) / float(point_count)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

func _build_combat_context(target: Node) -> Dictionary:
	return {
		"owner": _shooter_node,
		"weapon_id": weapon_id,
		"weapon_tags": weapon_tags,
		"origin": global_position,
		"direction": direction,
		"target": target,
		"damage": damage,
		"color": _get_projectile_color(),
		"feedback_profile": feedback_profile,
		"impact_weight": impact_weight,
		"is_tick": false,
		"source_type": source_type,
		"trigger_passives": trigger_passives,
	}
