class_name TurretNode
extends Node2D

signal fire_requested(origin, direction, config)

var lifetime := 6.0
var fire_rate := 3.2
var damage := 12
var attack_range := 780.0
var projectile_speed := 760.0
var tint := Color(0.9, 0.95, 1.0, 1.0)
var _next_fire_at := 0.0

func configure(duration: float, stats: Dictionary, color: Color) -> void:
	lifetime = duration
	fire_rate = float(stats.get("fire_rate", fire_rate))
	damage = int(stats.get("damage", damage))
	attack_range = float(stats.get("range", attack_range))
	projectile_speed = float(stats.get("projectile_speed", projectile_speed))
	tint = color
	set_physics_process(true)
	queue_redraw()

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var target := _find_target()
	var now := Time.get_ticks_msec() / 1000.0
	if target != null:
		look_at(target.global_position)
		if now >= _next_fire_at:
			_next_fire_at = now + 1.0 / max(fire_rate, 0.1)
			var direction := (target.global_position - global_position).normalized()
			fire_requested.emit(global_position + direction * 18.0, direction, {
				"speed": projectile_speed,
				"damage": damage,
				"color": tint,
				"feedback_profile": "rifle",
				"impact_weight": 0.9,
				"max_distance": attack_range,
				"collision_half_width": 4.0,
				"source_type": "ability",
				"weapon_id": "turret",
			})
	queue_redraw()

func _find_target() -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	var best_target: Node2D = null
	var best_distance := INF
	for candidate in tree.get_nodes_in_group("aim_target"):
		if candidate == null or not is_instance_valid(candidate) or not (candidate is Node2D):
			continue
		if candidate.has_method("is_alive") and not candidate.is_alive():
			continue
		var distance := global_position.distance_to((candidate as Node2D).global_position)
		if distance > attack_range or distance >= best_distance:
			continue
		best_distance = distance
		best_target = candidate as Node2D
	return best_target

func _draw() -> void:
	draw_circle(Vector2.ZERO, 18.0, Color(tint.r, tint.g, tint.b, 0.3))
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 20, Color(tint.r, tint.g, tint.b, 0.88), 3.0)
	draw_line(Vector2.ZERO, Vector2.RIGHT * 24.0, Color(1.0, 1.0, 1.0, 0.9), 4.0)
