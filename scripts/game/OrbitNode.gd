class_name OrbitNode
extends "res://scripts/game/DeployableNode.gd"

const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")

var owner_node: Node2D = null
var orb_count := 3
var orbit_radius := 84.0
var damage := 18
var rotation_speed := 2.6
var expand_interval := 0.0
var expand_bonus_radius := 0.0
var orb_visual_scale := 1.0
var blocks_projectiles := false
var orbit_lifetime := 20.0
var tint := Color(0.56, 0.92, 1.0, 1.0)
var _angle := 0.0
var _hit_cooldowns: Dictionary = {}
var _expires_at := 0.0

func configure(orbit_owner: Node2D, stats: Dictionary, color: Color) -> void:
	owner_node = orbit_owner
	orb_count = int(stats.get("orb_count", orb_count)) + int(stats.get("extra_orbs", 0))
	orbit_radius = float(stats.get("orbit_radius", orbit_radius))
	damage = int(stats.get("damage", damage))
	rotation_speed = float(stats.get("rotation_speed", rotation_speed))
	expand_interval = maxf(0.0, float(stats.get("expand_interval", 0.0)))
	expand_bonus_radius = maxf(0.0, float(stats.get("expand_bonus_radius", 0.0)))
	orb_visual_scale = maxf(0.1, float(stats.get("orb_visual_scale", orb_visual_scale)))
	blocks_projectiles = bool(stats.get("blocks_projectiles", blocks_projectiles))
	orbit_lifetime = maxf(0.1, float(stats.get("orbit_lifetime", orbit_lifetime)))
	_expires_at = Time.get_ticks_msec() / 1000.0 + orbit_lifetime
	tint = color
	configure_deployable_health(int(stats.get("orbit_health", stats.get("health", 140))), true)
	set_physics_process(true)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	if owner_node == null or not is_instance_valid(owner_node):
		despawn_deployable()
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now >= _expires_at:
		despawn_deployable()
		return
	global_position = owner_node.global_position
	_angle = fmod(_angle + rotation_speed * delta, TAU)
	var effective_radius := _current_orbit_radius(now)
	var orb_positions := _get_orb_positions(effective_radius)
	for enemy in _get_candidate_enemies(effective_radius + 32.0):
		if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("is_alive") or not enemy.is_alive():
			continue
		for orb_position in orb_positions:
			if enemy.global_position.distance_to(orb_position) <= _orb_hit_radius():
				if float(_hit_cooldowns.get(enemy, 0.0)) > now:
					break
				_hit_cooldowns[enemy] = now + 0.22
				enemy.apply_damage(damage, _get_owner_player_index())
				_spawn_hit_sparks(enemy.global_position, enemy.global_position - orb_position)
				if enemy.has_method("apply_knockback"):
					enemy.apply_knockback((enemy.global_position - global_position).normalized(), 180.0)
				break
	if blocks_projectiles:
		_block_enemy_projectiles(orb_positions)
	queue_redraw()

func _get_orb_positions(effective_radius: float = -1.0) -> Array:
	var points: Array = []
	var radius := orbit_radius if effective_radius < 0.0 else effective_radius
	for index in range(max(orb_count, 1)):
		var angle := _angle + TAU * float(index) / float(max(orb_count, 1))
		points.append(global_position + Vector2.RIGHT.rotated(angle) * radius)
	return points

func _draw() -> void:
	var effective_radius := _current_orbit_radius(Time.get_ticks_msec() / 1000.0)
	for orb_position in _get_orb_positions(effective_radius):
		var local_position: Vector2 = orb_position - global_position
		draw_circle(local_position, 10.0 * orb_visual_scale, Color(tint.r, tint.g, tint.b, 0.34))
		draw_arc(local_position, 12.0 * orb_visual_scale, 0.0, TAU, 16, Color(tint.r, tint.g, tint.b, 0.92), 3.0)
	_draw_deployable_health_bar(34.0, 42.0)

func _current_orbit_radius(now: float) -> float:
	if expand_interval <= 0.0 or expand_bonus_radius <= 0.0:
		return orbit_radius
	var phase := fmod(now, expand_interval) / expand_interval
	var pulse := sin(phase * PI)
	return orbit_radius + expand_bonus_radius * pulse

func _get_candidate_enemies(radius: float) -> Array:
	var tree := get_tree()
	if tree == null:
		return []
	var combat_owner := tree.current_scene
	if combat_owner != null and combat_owner.has_method("get_nearby_enemy_target_nodes"):
		return combat_owner.get_nearby_enemy_target_nodes(global_position, radius)
	return tree.get_nodes_in_group("aim_target")

func _block_enemy_projectiles(orb_positions: Array) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var combat_owner := tree.current_scene
	var candidates: Array = []
	if combat_owner != null and combat_owner.has_method("get_projectile_nodes"):
		candidates = combat_owner.get_projectile_nodes()
	else:
		var projectile_root := get_node_or_null("../Projectiles")
		if projectile_root != null:
			candidates = projectile_root.get_children()
	for projectile in candidates:
		if projectile == null or not is_instance_valid(projectile):
			continue
		if projectile.has_method("is_projectile_active") and not projectile.is_projectile_active():
			continue
		if not ("team" in projectile) or str(projectile.team) != "enemy":
			continue
		for orb_position in orb_positions:
			if projectile.global_position.distance_to(orb_position) <= _orb_hit_radius():
				_spawn_hit_sparks(projectile.global_position, projectile.global_position - orb_position)
				if projectile.has_method("_finish_projectile"):
					projectile._finish_projectile()
				else:
					projectile.queue_free()
				break

func _orb_hit_radius() -> float:
	return 28.0 * orb_visual_scale

func _get_owner_player_index() -> int:
	if owner_node == null or not is_instance_valid(owner_node):
		return -1
	return int(owner_node.get("player_index"))

func get_owner_player_index() -> int:
	return _get_owner_player_index()

func _spawn_hit_sparks(hit_position: Vector2, direction: Vector2) -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	var sparks := ParticleFactoryData.create_impact_sparks(tint.lightened(0.18), direction.normalized() if direction.length() > 0.0 else Vector2.UP, 0.72)
	sparks.global_position = hit_position
	parent_node.add_child(sparks)

func _on_deployable_destroyed() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	var ring := ParticleFactoryData.create_explosion_ring(tint, orbit_radius, 2.4)
	ring.global_position = global_position
	parent_node.add_child(ring)
