class_name AbilityMine
extends Node2D

const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")

var lifetime := 8.0
var trigger_radius := 52.0
var explosion_radius := 88.0
var damage := 42
var tint := Color(1.0, 0.82, 0.34, 1.0)
var _detonating := false
var _detonate_at := 0.0

func configure(duration: float, radius: float, mine_damage: int, color: Color) -> void:
	lifetime = duration
	explosion_radius = radius
	damage = mine_damage
	tint = color
	set_physics_process(true)
	queue_redraw()

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _detonating and now >= _detonate_at:
		_explode()
		return
	if _detonating:
		queue_redraw()
		return
	for enemy in _get_candidate_enemies(trigger_radius):
		if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("is_alive") or not enemy.is_alive():
			continue
		if enemy.global_position.distance_squared_to(global_position) <= trigger_radius * trigger_radius:
			_detonating = true
			_detonate_at = now + 0.12
			queue_redraw()
			return
	queue_redraw()

func _explode() -> void:
	var explosion_radius_sq := explosion_radius * explosion_radius
	for enemy in _get_candidate_enemies(explosion_radius):
		if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("is_alive") or not enemy.is_alive():
			continue
		if enemy.global_position.distance_squared_to(global_position) <= explosion_radius_sq:
			enemy.apply_damage(damage)
			_spawn_hit_sparks(enemy.global_position, enemy.global_position - global_position)
			if enemy.has_method("apply_knockback"):
				enemy.apply_knockback((enemy.global_position - global_position).normalized(), 320.0)
	var parent_node := get_parent()
	if parent_node != null:
		var ring := ParticleFactoryData.create_explosion_ring(tint.lightened(0.1), explosion_radius, 3.5)
		ring.global_position = global_position
		parent_node.add_child(ring)
	queue_free()

func _spawn_hit_sparks(hit_position: Vector2, direction: Vector2) -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	var sparks := ParticleFactoryData.create_impact_sparks(tint.lightened(0.18), direction.normalized() if direction.length() > 0.0 else Vector2.UP, 0.9)
	sparks.global_position = hit_position
	parent_node.add_child(sparks)

func _draw() -> void:
	var ring_color := Color(tint.r, tint.g, tint.b, 0.92) if _detonating else Color(tint.r, tint.g, tint.b, 0.62)
	var fill_color := Color(tint.r, tint.g, tint.b, 0.34) if _detonating else Color(tint.r, tint.g, tint.b, 0.18)
	draw_circle(Vector2.ZERO, 12.0, fill_color)
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 18, ring_color, 3.0)
	draw_arc(Vector2.ZERO, trigger_radius, 0.0, TAU, 20, Color(tint.r, tint.g, tint.b, 0.2), 2.0)

func _get_candidate_enemies(radius: float) -> Array:
	var tree := get_tree()
	if tree == null:
		return []
	var combat_owner := tree.current_scene
	if combat_owner != null and combat_owner.has_method("get_nearby_enemy_target_nodes"):
		return combat_owner.get_nearby_enemy_target_nodes(global_position, radius)
	return tree.get_nodes_in_group("aim_target")
