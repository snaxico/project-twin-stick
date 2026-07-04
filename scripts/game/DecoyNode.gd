class_name DecoyNode
extends "res://scripts/game/DeployableNode.gd"

const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")

var tint := Color(0.8, 0.9, 1.0, 0.9)
var death_blast_damage := 0
var death_blast_radius := 0.0
var taunt_radius := 700.0

func configure(_duration: float, color: Color, health_amount: int, stats: Dictionary = {}) -> void:
	tint = color
	death_blast_damage = int(stats.get("death_blast_damage", 0))
	death_blast_radius = float(stats.get("death_blast_radius", 0.0))
	taunt_radius = float(stats.get("taunt_radius", taunt_radius))
	configure_deployable_health(health_amount, true)
	add_to_group("decoy_taunt")
	queue_redraw()

func is_taunting() -> bool:
	return is_alive()

func get_taunt_radius() -> float:
	return taunt_radius

func _on_deployable_destroyed() -> void:
	_trigger_death_blast()
	if is_in_group("decoy_taunt"):
		remove_from_group("decoy_taunt")

func _trigger_death_blast() -> void:
	if death_blast_damage <= 0 or death_blast_radius <= 0.0:
		return
	var tree := get_tree()
	if tree == null:
		return
	var candidates: Array = []
	var combat_owner := tree.current_scene
	if combat_owner != null and combat_owner.has_method("get_nearby_enemy_target_nodes"):
		candidates = combat_owner.get_nearby_enemy_target_nodes(global_position, death_blast_radius)
	else:
		candidates = tree.get_nodes_in_group("aim_target")
	for enemy in candidates:
		if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue
		if (enemy as Node2D).global_position.distance_squared_to(global_position) > death_blast_radius * death_blast_radius:
			continue
		if enemy.has_method("apply_damage"):
			enemy.apply_damage(death_blast_damage)
	var parent_node := get_parent()
	if parent_node != null:
		var ring := ParticleFactoryData.create_explosion_ring(tint, death_blast_radius, 3.0)
		ring.global_position = global_position
		parent_node.add_child(ring)

func _draw() -> void:
	var alpha := clampf(float(current_health) / float(max_health), 0.0, 1.0)
	var color := Color(tint.r, tint.g, tint.b, 0.18 + alpha * 0.46)
	draw_circle(Vector2.ZERO, 28.0, color)
	draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 24, Color(tint.r, tint.g, tint.b, 0.62 + alpha * 0.2), 3.0)
	_draw_deployable_health_bar(38.0, 44.0)
