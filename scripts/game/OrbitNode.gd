class_name OrbitNode
extends Node2D

var owner_node: Node2D = null
var lifetime := 5.0
var orb_count := 3
var orbit_radius := 84.0
var damage := 18
var rotation_speed := 2.6
var tint := Color(0.56, 0.92, 1.0, 1.0)
var _angle := 0.0
var _hit_cooldowns: Dictionary = {}

func configure(orbit_owner: Node2D, duration: float, stats: Dictionary, color: Color) -> void:
	owner_node = orbit_owner
	lifetime = duration
	orb_count = int(stats.get("orb_count", orb_count))
	orbit_radius = float(stats.get("orbit_radius", orbit_radius))
	damage = int(stats.get("damage", damage))
	rotation_speed = float(stats.get("rotation_speed", rotation_speed))
	tint = color
	set_physics_process(true)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if owner_node == null or not is_instance_valid(owner_node):
		queue_free()
		return
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	global_position = owner_node.global_position
	_angle = fmod(_angle + rotation_speed * delta, TAU)
	var now := Time.get_ticks_msec() / 1000.0
	for enemy in get_tree().get_nodes_in_group("aim_target"):
		if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("is_alive") or not enemy.is_alive():
			continue
		for orb_position in _get_orb_positions():
			if enemy.global_position.distance_to(orb_position) <= 28.0:
				if float(_hit_cooldowns.get(enemy, 0.0)) > now:
					break
				_hit_cooldowns[enemy] = now + 0.22
				enemy.apply_damage(damage)
				if enemy.has_method("apply_knockback"):
					enemy.apply_knockback((enemy.global_position - global_position).normalized(), 180.0)
				break
	queue_redraw()

func _get_orb_positions() -> Array:
	var points: Array = []
	for index in range(max(orb_count, 1)):
		var angle := _angle + TAU * float(index) / float(max(orb_count, 1))
		points.append(global_position + Vector2.RIGHT.rotated(angle) * orbit_radius)
	return points

func _draw() -> void:
	for orb_position in _get_orb_positions():
		var local_position: Vector2 = orb_position - global_position
		draw_circle(local_position, 10.0, Color(tint.r, tint.g, tint.b, 0.34))
		draw_arc(local_position, 12.0, 0.0, TAU, 16, Color(tint.r, tint.g, tint.b, 0.92), 3.0)
