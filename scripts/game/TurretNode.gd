class_name TurretNode
extends "res://scripts/game/DeployableNode.gd"

signal fire_requested(origin, direction, config)

const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")

var fire_rate := 3.2
var damage := 12
var attack_range := 780.0
var projectile_speed := 760.0
var gun_count := 1
var tint := Color(0.9, 0.95, 1.0, 1.0)
var owner_player_index := -1
var _next_fire_at := 0.0

func configure(stats: Dictionary, color: Color, owner_node = null) -> void:
	fire_rate = float(stats.get("fire_rate", fire_rate))
	damage = int(stats.get("damage", damage))
	attack_range = float(stats.get("range", attack_range))
	projectile_speed = float(stats.get("projectile_speed", projectile_speed))
	gun_count = maxi(1, int(stats.get("gun_count", 1)))
	tint = color
	owner_player_index = int(owner_node.player_index) if owner_node != null and is_instance_valid(owner_node) and "player_index" in owner_node else int(stats.get("source_player_index", -1))
	configure_deployable_health(int(stats.get("turret_health", stats.get("health", 110))), true)
	set_physics_process(true)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if not is_alive():
		return
	var target := _find_target()
	var now := Time.get_ticks_msec() / 1000.0
	if target != null:
		look_at(target.global_position)
		if now >= _next_fire_at:
			_next_fire_at = now + 1.0 / max(fire_rate, 0.1)
			var direction := (target.global_position - global_position).normalized()
			var perpendicular := direction.orthogonal().normalized()
			for gun_index in range(gun_count):
				var offset := 0.0
				if gun_count > 1:
					offset = (float(gun_index) - (float(gun_count - 1) * 0.5)) * 16.0
				fire_requested.emit(global_position + direction * 18.0 + perpendicular * offset, direction, {
					"speed": projectile_speed,
					"damage": damage,
					"color": tint,
					"feedback_profile": "rifle",
					"impact_weight": 0.9,
					"max_distance": attack_range,
					"collision_half_width": 4.0,
					"source_type": "ability",
					"weapon_id": "turret",
					"source_player_index": owner_player_index,
				})
	queue_redraw()

func _find_target() -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	var best_target: Node2D = null
	var best_distance_sq := INF
	var range_sq := attack_range * attack_range
	var candidates: Array = []
	var combat_owner := tree.current_scene
	if combat_owner != null and combat_owner.has_method("get_nearby_enemy_target_nodes"):
		candidates = combat_owner.get_nearby_enemy_target_nodes(global_position, attack_range)
	else:
		candidates = tree.get_nodes_in_group("aim_target")
	for candidate in candidates:
		if candidate == null or not is_instance_valid(candidate) or not (candidate is Node2D):
			continue
		if candidate.has_method("is_alive") and not candidate.is_alive():
			continue
		var distance_sq := global_position.distance_squared_to((candidate as Node2D).global_position)
		if distance_sq > range_sq or distance_sq >= best_distance_sq:
			continue
		best_distance_sq = distance_sq
		best_target = candidate as Node2D
	return best_target

func _draw() -> void:
	draw_circle(Vector2.ZERO, 18.0, Color(tint.r, tint.g, tint.b, 0.3))
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 20, Color(tint.r, tint.g, tint.b, 0.88), 3.0)
	for gun_index in range(gun_count):
		var offset := 0.0
		if gun_count > 1:
			offset = (float(gun_index) - (float(gun_count - 1) * 0.5)) * 8.0
		draw_line(Vector2(0.0, offset), Vector2.RIGHT * 24.0 + Vector2(0.0, offset), Color(1.0, 1.0, 1.0, 0.9), 4.0)
	_draw_deployable_health_bar(25.0)

func get_owner_player_index() -> int:
	return owner_player_index

func _on_deployable_destroyed() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	var ring := ParticleFactoryData.create_explosion_ring(tint, 34.0, 2.1)
	ring.global_position = global_position
	parent_node.add_child(ring)
