class_name FireTrailZone
extends Node2D

var radius: float = 50.0
var damage: int = 1
var lifetime: float = 1.5
var tick_interval: float = 0.5
var team: String = "player"
var knockback_force: float = 0.0
var source_player_index := -1
var healing_owner: Node = null
var wake_heal_per_hit := 0

var _expires_at: float = 0.0
var _next_tick_at: float = 0.0

func configure(zone_radius: float, zone_damage: int, zone_lifetime: float, zone_tick_interval: float, zone_team: String, zone_knockback_force: float = 0.0, zone_source_player_index: int = -1, zone_healing_owner: Node = null, zone_wake_heal_per_hit: int = 0) -> void:
	radius = max(zone_radius, 8.0)
	damage = max(zone_damage, 1)
	lifetime = max(zone_lifetime, 0.1)
	tick_interval = max(zone_tick_interval, 0.1)
	team = zone_team
	knockback_force = max(zone_knockback_force, 0.0)
	source_player_index = zone_source_player_index
	healing_owner = zone_healing_owner
	wake_heal_per_hit = maxi(0, zone_wake_heal_per_hit)
	queue_redraw()

func _ready() -> void:
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
	_apply_tick_damage()
	queue_redraw()

func _apply_tick_damage() -> void:
	for target in _get_targets_for_team():
		if target == null or not is_instance_valid(target) or not (target is Node2D):
			continue
		if not target.has_method("apply_damage"):
			continue
		if target.has_method("get_team") and str(target.get_team()) == team:
			continue
		var target_node := target as Node2D
		if target_node.global_position.distance_squared_to(global_position) > radius * radius:
			continue
		if knockback_force > 0.0 and target.has_method("apply_knockback"):
			var knockback_direction := (target_node.global_position - global_position).normalized()
			target.apply_knockback(knockback_direction, knockback_force)
		var health_before = _numeric_current_health(target)
		if team == "player":
			target.apply_damage(damage, source_player_index)
		else:
			target.apply_damage(damage)
		var health_after = _numeric_current_health(target)
		if health_before != null and health_after != null and float(health_after) < float(health_before):
			_try_apply_wake_heal()

func _numeric_current_health(target):
	if not ("current_health" in target):
		return null
	var value = target.get("current_health")
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return null
	return value

func _try_apply_wake_heal() -> void:
	if wake_heal_per_hit <= 0 or healing_owner == null or not is_instance_valid(healing_owner):
		return
	if healing_owner.has_method("try_apply_wake_heal"):
		healing_owner.try_apply_wake_heal(wake_heal_per_hit)

func _get_targets_for_team() -> Array:
	var combat_owner := _get_combat_owner()
	if team == "player":
		if combat_owner != null and combat_owner.has_method("get_nearby_enemy_target_nodes"):
			return combat_owner.get_nearby_enemy_target_nodes(global_position, radius)
		var aim_target_tree := get_tree()
		return aim_target_tree.get_nodes_in_group("aim_target") if aim_target_tree != null else []
	if combat_owner != null and combat_owner.has_method("get_player_target_nodes"):
		return combat_owner.get_player_target_nodes()
	var player_target_tree := get_tree()
	return player_target_tree.get_nodes_in_group("player_target") if player_target_tree != null else []

func _get_combat_owner() -> Node:
	var current := get_parent()
	while current != null:
		if current.has_method("get_nearby_enemy_target_nodes") or current.has_method("get_player_target_nodes"):
			return current
		current = current.get_parent()
	var owner_tree := get_tree()
	return owner_tree.current_scene if owner_tree != null else null

func _draw() -> void:
	var remaining_ratio := clampf((_expires_at - _current_time_seconds()) / maxf(lifetime, 0.01), 0.0, 1.0)
	draw_colored_polygon(_build_circle_points(radius, 18), Color(1.0, 0.46, 0.14, 0.28 * remaining_ratio))

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _build_circle_points(circle_radius: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := TAU * float(index) / float(point_count)
		points.append(Vector2.RIGHT.rotated(angle) * circle_radius)
	return points
