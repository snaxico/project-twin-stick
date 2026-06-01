class_name HazardZone
extends Node2D

var radius := 120.0
var lifetime := 3.0
var damage := 5
var damage_interval := 0.5
var tint := Color(0.48, 0.84, 1.0, 0.24)
var _next_damage_at := 0.0

func configure(zone_radius: float, duration: float, zone_damage: int, color: Color) -> void:
	radius = zone_radius
	lifetime = duration
	damage = zone_damage
	tint = color
	queue_redraw()

func update_zone(delta: float, player_nodes: Array) -> void:
	lifetime -= delta
	_next_damage_at -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	if _next_damage_at <= 0.0:
		_next_damage_at = damage_interval
		for player in player_nodes:
			if player == null or not is_instance_valid(player) or not player.has_method("is_alive") or not player.is_alive():
				continue
			if player.global_position.distance_to(global_position) <= radius:
				player.apply_damage(damage)
	queue_redraw()

func _draw() -> void:
	var alpha := clampf(lifetime / 7.0, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(tint.r, tint.g, tint.b, tint.a * alpha))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(tint.r, tint.g, tint.b, 0.5 * alpha + 0.12), 4.0)
