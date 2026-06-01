class_name AbilityMine
extends Node2D

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
	for enemy in get_tree().get_nodes_in_group("aim_target"):
		if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("is_alive") or not enemy.is_alive():
			continue
		if enemy.global_position.distance_to(global_position) <= trigger_radius:
			_detonating = true
			_detonate_at = now + 0.12
			queue_redraw()
			return
	queue_redraw()

func _explode() -> void:
	for enemy in get_tree().get_nodes_in_group("aim_target"):
		if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("is_alive") or not enemy.is_alive():
			continue
		if enemy.global_position.distance_to(global_position) <= explosion_radius:
			enemy.apply_damage(damage)
			if enemy.has_method("apply_knockback"):
				enemy.apply_knockback((enemy.global_position - global_position).normalized(), 320.0)
	queue_free()

func _draw() -> void:
	var ring_color := Color(tint.r, tint.g, tint.b, 0.92) if _detonating else Color(tint.r, tint.g, tint.b, 0.62)
	var fill_color := Color(tint.r, tint.g, tint.b, 0.34) if _detonating else Color(tint.r, tint.g, tint.b, 0.18)
	draw_circle(Vector2.ZERO, 12.0, fill_color)
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 18, ring_color, 3.0)
	draw_arc(Vector2.ZERO, trigger_radius, 0.0, TAU, 20, Color(tint.r, tint.g, tint.b, 0.2), 2.0)
