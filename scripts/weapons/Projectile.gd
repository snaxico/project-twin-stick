extends Area2D

const FireTrailZoneData = preload("res://scripts/weapons/FireTrailZone.gd")
const BASE_COLLISION_HALF_WIDTH := 4.0
const BLOOM_COLOR_MULTIPLIER := 1.45

@export var lifetime: float = 1.8

signal impact_requested(origin, direction, team, color, feedback_profile, impact_weight, target, combat_context)
signal projectile_deactivated(projectile)

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
var trail_tick_interval: float = 0.5
var impact_pool_radius: float = 0.0
var impact_pool_lifetime: float = 0.0
var impact_pool_damage_percent: float = 0.0
var knockback_force: float = 0.0
var explosion_radius: float = 0.0
var explosion_damage_percent: float = 0.0
var slow_multiplier: float = 1.0
var slow_step: float = 0.0
var slow_floor: float = 0.15
var slow_duration: float = 0.0
var poison_dps: float = 0.0
var poison_duration: float = 0.0
var rapid_fire_level: int = 0
var velocity_level: int = 0
var knockback_level: int = 0
var projectile_shape: String = "orb"
var trail_style: String = "default"
var accent_color: Color = Color.WHITE
var impact_sfx: String = "hit"
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
var _spawn_position := Vector2.ZERO
var _base_collision_radius := 0.0
var _base_visual_scale := Vector2.ONE
var _hit_targets: Array = []
var _pooled := false
var _active := true
var _impact_pool_spawned := false

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
	trail_tick_interval = 0.5
	impact_pool_radius = 0.0
	impact_pool_lifetime = 0.0
	impact_pool_damage_percent = 0.0
	knockback_force = 0.0
	explosion_radius = 0.0
	explosion_damage_percent = 0.0
	slow_multiplier = 1.0
	slow_step = 0.0
	slow_floor = 0.15
	slow_duration = 0.0
	poison_dps = 0.0
	poison_duration = 0.0
	rapid_fire_level = 0
	velocity_level = 0
	knockback_level = 0
	projectile_shape = "orb"
	trail_style = "default"
	accent_color = projectile_color.lightened(0.2)
	impact_sfx = "hit"
	source_type = "projectile"
	weapon_id = ""
	weapon_tags = []
	trigger_passives = []
	use_lifetime = projectile_team != "enemy"
	_hit_targets.clear()
	_impact_pool_spawned = false

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
	trail_tick_interval = max(0.1, float(config.get("trail_tick_interval", trail_tick_interval)))
	impact_pool_radius = max(0.0, float(config.get("impact_pool_radius", impact_pool_radius)))
	impact_pool_lifetime = max(0.0, float(config.get("impact_pool_lifetime", impact_pool_lifetime)))
	impact_pool_damage_percent = max(0.0, float(config.get("impact_pool_damage_percent", impact_pool_damage_percent)))
	knockback_force = max(0.0, float(config.get("knockback_force", knockback_force)))
	explosion_radius = max(0.0, float(config.get("explosion_radius", explosion_radius)))
	explosion_damage_percent = max(0.0, float(config.get("explosion_damage_percent", explosion_damage_percent)))
	slow_multiplier = clampf(float(config.get("slow_multiplier", slow_multiplier)), 0.1, 1.0)
	slow_step = max(0.0, float(config.get("slow_step", slow_step)))
	slow_floor = clampf(float(config.get("slow_floor", slow_floor)), 0.01, 1.0)
	slow_duration = max(0.0, float(config.get("slow_duration", slow_duration)))
	poison_dps = max(0.0, float(config.get("poison_dps", poison_dps)))
	poison_duration = max(0.0, float(config.get("poison_duration", poison_duration)))
	rapid_fire_level = max(0, int(config.get("rapid_fire_level", rapid_fire_level)))
	velocity_level = max(0, int(config.get("velocity_level", velocity_level)))
	knockback_level = max(0, int(config.get("knockback_level", knockback_level)))
	projectile_shape = str(config.get("projectile_shape", projectile_shape))
	trail_style = str(config.get("trail_style", trail_style))
	accent_color = _parse_color(config.get("accent_color", accent_color), accent_color)
	# Player projectiles read as the player color: outline/accent follows the player tint,
	# overriding any per-mutation accent. Mutation distinction stays via shape/trail/impact.
	if team == "player":
		accent_color = tint_color.lightened(0.22)
	impact_sfx = str(config.get("impact_sfx", impact_sfx))
	source_type = str(config.get("source_type", source_type))
	weapon_id = str(config.get("weapon_id", weapon_id))
	weapon_tags = (config.get("weapon_tags", []) as Array).duplicate(true)
	trigger_passives = (config.get("trigger_passives", []) as Array).duplicate(true)
	use_lifetime = bool(config.get("use_lifetime", use_lifetime))

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if visual != null and _base_visual_scale == Vector2.ONE:
		_base_visual_scale = visual.scale
	if collision_shape != null and collision_shape.shape is CircleShape2D and _base_collision_radius <= 0.0:
		collision_shape.shape = (collision_shape.shape as CircleShape2D).duplicate()
		_base_collision_radius = (collision_shape.shape as CircleShape2D).radius
	_activate_projectile_runtime()

func set_pooled(pooled: bool) -> void:
	_pooled = pooled

func is_projectile_active() -> bool:
	return _active

func activate_from_config(projectile_team: String, projectile_direction: Vector2, config: Dictionary, spawn_position: Vector2) -> void:
	global_position = spawn_position
	setup_from_config(projectile_team, projectile_direction, config)
	_activate_projectile_runtime()

func _activate_projectile_runtime() -> void:
	_active = true
	visible = true
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	set_process(true)
	set_physics_process(true)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)
	_expires_at = _current_time_seconds() + lifetime
	rotation = direction.angle()
	_spawn_position = global_position
	_apply_visual_state()

func _physics_process(delta: float) -> void:
	if not _active:
		return
	rotation = direction.angle()
	global_position += direction * speed * delta
	if max_distance > 0.0 and global_position.distance_squared_to(_spawn_position) >= max_distance * max_distance:
		_spawn_impact_fire_pool()
		_finish_projectile()
		return
	if use_lifetime and _current_time_seconds() >= _expires_at:
		_spawn_impact_fire_pool()
		_finish_projectile()

func _on_body_entered(body: Node) -> void:
	if body is StaticBody2D:
		impact_requested.emit(global_position, -direction, team, _get_impact_color(), impact_sfx, impact_weight, body, _build_combat_context(body))
		_spawn_impact_fire_pool()
		_finish_projectile()
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
	if slow_duration > 0.0:
		if slow_step > 0.0 and target.has_method("apply_stacking_slow"):
			target.apply_stacking_slow(slow_step, slow_floor, slow_duration)
		elif target.has_method("apply_slow"):
			target.apply_slow(slow_multiplier, slow_duration)
	if poison_duration > 0.0 and poison_dps > 0.0 and target.has_method("apply_poison"):
		target.apply_poison(poison_dps, poison_duration)
	_hit_targets.append(target)
	impact_requested.emit(global_position, -direction, team, _get_impact_color(), impact_sfx, impact_weight, target, _build_combat_context(target))
	if pierce_remaining > 0:
		pierce_remaining -= 1
		return
	if ricochet_remaining > 0 and _redirect_to_ricochet_target(target):
		ricochet_remaining -= 1
		return
	_spawn_impact_fire_pool()
	_finish_projectile()

func _spawn_impact_fire_pool() -> void:
	if _impact_pool_spawned or not leaves_fire_trail or impact_pool_radius <= 0.0 or impact_pool_lifetime <= 0.0 or impact_pool_damage_percent <= 0.0:
		return
	if get_parent() == null:
		return
	_impact_pool_spawned = true
	var pool := FireTrailZoneData.new()
	pool.global_position = global_position
	pool.configure(
		impact_pool_radius,
		max(1, int(round(float(damage) * impact_pool_damage_percent))),
		impact_pool_lifetime,
		trail_tick_interval,
		team,
		knockback_force
	)
	get_parent().add_child(pool)

func _finish_projectile() -> void:
	if not _pooled:
		queue_free()
		return
	_active = false
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_process(false)
	set_physics_process(false)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	projectile_deactivated.emit(self)

func _redirect_to_ricochet_target(previous_target: Node) -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var best_target: Node2D = null
	var best_distance_sq := INF
	var range_sq := ricochet_range * ricochet_range
	var candidates: Array = []
	var combat_owner := tree.current_scene
	if combat_owner != null and combat_owner.has_method("get_nearby_enemy_target_nodes"):
		candidates = combat_owner.get_nearby_enemy_target_nodes(global_position, ricochet_range)
	else:
		candidates = tree.get_nodes_in_group("aim_target")
	for candidate in candidates:
		if candidate == null or not is_instance_valid(candidate) or candidate == previous_target:
			continue
		if _hit_targets.has(candidate):
			continue
		if not (candidate is Node2D):
			continue
		var distance_sq := global_position.distance_squared_to((candidate as Node2D).global_position)
		if distance_sq > range_sq or distance_sq >= best_distance_sq:
			continue
		best_distance_sq = distance_sq
		best_target = candidate as Node2D
	if best_target == null:
		return false
	direction = (best_target.global_position - global_position).normalized()
	rotation = direction.angle()
	return true

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _apply_visual_state() -> void:
	var size_scale: float = maxf(collision_half_width / BASE_COLLISION_HALF_WIDTH, 0.25)
	if visual != null:
		visual.visible = false
	if outline != null:
		outline.visible = false
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = _base_collision_radius * size_scale

func get_render_scale() -> Vector2:
	var size_scale: float = maxf(collision_half_width / BASE_COLLISION_HALF_WIDTH, 0.25)
	var streak_scale: float = 1.0 + 0.18 * float(max(rapid_fire_level - 1, 0)) + 0.22 * float(max(velocity_level - 1, 0))
	if team == "enemy":
		var enemy_orb_scale := 1.36 * (8.0 / 6.0)
		return Vector2(_base_visual_scale.x * enemy_orb_scale * size_scale * streak_scale, _base_visual_scale.y * enemy_orb_scale * size_scale)
	return _get_shape_scale(size_scale, streak_scale)

func get_render_color() -> Color:
	var projectile_color: Color = _get_projectile_color()
	if team == "enemy":
		return _bloom_color(projectile_color)
	return _bloom_color(projectile_color.lightened(0.05))

func _get_projectile_color() -> Color:
	return tint_color

func _get_impact_color() -> Color:
	return accent_color if team == "player" else tint_color

func _bloom_color(color: Color) -> Color:
	return Color(color.r * BLOOM_COLOR_MULTIPLIER, color.g * BLOOM_COLOR_MULTIPLIER, color.b * BLOOM_COLOR_MULTIPLIER, color.a)

func _get_shape_scale(size_scale: float, streak_scale: float) -> Vector2:
	match projectile_shape:
		"small_orb":
			return Vector2(_base_visual_scale.x * 0.92 * size_scale * streak_scale, _base_visual_scale.y * 0.92 * size_scale)
		"lance":
			return Vector2(_base_visual_scale.x * 1.75 * size_scale * streak_scale, _base_visual_scale.y * 0.76 * size_scale)
		"large_orb":
			return Vector2(_base_visual_scale.x * 1.36 * size_scale * streak_scale, _base_visual_scale.y * 1.36 * size_scale)
		"diamond":
			return Vector2(_base_visual_scale.x * 1.18 * size_scale * streak_scale, _base_visual_scale.y * 1.18 * size_scale)
		"shard":
			return Vector2(_base_visual_scale.x * 1.45 * size_scale * streak_scale, _base_visual_scale.y * 0.9 * size_scale)
		"blob":
			return Vector2(_base_visual_scale.x * 1.18 * size_scale * streak_scale, _base_visual_scale.y * 1.0 * size_scale)
		"bomb", "ember_orb":
			return Vector2(_base_visual_scale.x * 1.28 * size_scale * streak_scale, _base_visual_scale.y * 1.28 * size_scale)
		_:
			return Vector2(_base_visual_scale.x * 1.18 * size_scale * streak_scale, _base_visual_scale.y * 1.18 * size_scale)

static func build_shape_polygon(shape: String) -> PackedVector2Array:
	match shape:
		"lance":
			return PackedVector2Array([Vector2(10.0, 0.0), Vector2(1.5, 5.0), Vector2(-8.0, 3.0), Vector2(-8.0, -3.0), Vector2(1.5, -5.0)])
		"diamond":
			return PackedVector2Array([Vector2(8.0, 0.0), Vector2(0.0, 7.0), Vector2(-8.0, 0.0), Vector2(0.0, -7.0)])
		"shard":
			return PackedVector2Array([Vector2(9.0, 0.0), Vector2(2.0, 5.5), Vector2(-7.0, 2.0), Vector2(-4.0, -4.5)])
		"blob":
			return PackedVector2Array([Vector2(7.0, -1.0), Vector2(3.0, 6.0), Vector2(-5.5, 5.0), Vector2(-8.0, -1.0), Vector2(-2.0, -6.5), Vector2(5.0, -5.0)])
		"bomb":
			return build_orb_polygon(7.0, 10)
		"large_orb", "ember_orb":
			return build_orb_polygon(7.0, 10)
		"small_orb":
			return build_orb_polygon(5.2, 8)
		_:
			return build_orb_polygon(6.0)

static func build_orb_polygon(radius: float, point_count: int = 8) -> PackedVector2Array:
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
		"impact_sfx": impact_sfx,
		"impact_weight": impact_weight,
		"is_tick": false,
		"source_type": source_type,
		"trigger_passives": trigger_passives,
		"rapid_fire_level": rapid_fire_level,
		"velocity_level": velocity_level,
		"knockback_level": knockback_level,
		"explosion_radius": explosion_radius,
		"explosion_damage": int(round(float(damage) * explosion_damage_percent)),
		"slow_multiplier": slow_multiplier,
		"slow_step": slow_step,
		"slow_floor": slow_floor,
		"slow_duration": slow_duration,
		"poison_dps": poison_dps,
		"poison_duration": poison_duration,
	}

func _parse_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array:
		var parts: Array = value as Array
		if parts.size() >= 3:
			return Color(float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3]) if parts.size() > 3 else 1.0)
	return fallback
