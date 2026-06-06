class_name DecoyNode
extends Node2D

const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")

var lifetime := 5.0
var current_health := 120
var tint := Color(0.8, 0.9, 1.0, 0.9)
var death_blast_damage := 0
var death_blast_radius := 0.0
var taunt_radius := 700.0
var invincible := true
var _alive := true

func configure(duration: float, color: Color, health_amount: int, stats: Dictionary = {}) -> void:
	lifetime = duration
	tint = color
	current_health = health_amount
	death_blast_damage = int(stats.get("death_blast_damage", 0))
	death_blast_radius = float(stats.get("death_blast_radius", 0.0))
	taunt_radius = float(stats.get("taunt_radius", taunt_radius))
	invincible = not stats.has("decoy_health") or bool(stats.get("invincible", false))
	_alive = true
	add_to_group("player_target")
	add_to_group("decoy_taunt")
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		_expire()
		return
	queue_redraw()

func is_targetable() -> bool:
	return _alive

func is_alive() -> bool:
	return _alive

func is_taunting() -> bool:
	return _alive

func get_taunt_radius() -> float:
	return taunt_radius

func apply_damage(amount: int) -> void:
	if not _alive:
		return
	if invincible:
		return
	current_health = max(current_health - amount, 0)
	if current_health <= 0:
		_expire()
	queue_redraw()

func _expire() -> void:
	if not _alive:
		return
	_alive = false
	_trigger_death_blast()
	if is_in_group("player_target"):
		remove_from_group("player_target")
	if is_in_group("decoy_taunt"):
		remove_from_group("decoy_taunt")
	queue_free()

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
	var alpha := clampf(lifetime / 5.0, 0.0, 1.0)
	var color := Color(tint.r, tint.g, tint.b, 0.18 + alpha * 0.46)
	draw_circle(Vector2.ZERO, 28.0, color)
	draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 24, Color(tint.r, tint.g, tint.b, 0.62 + alpha * 0.2), 3.0)
