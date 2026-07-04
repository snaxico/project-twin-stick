extends "res://scripts/game/DeployableNode.gd"

const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")

var _owner = null
var _damage := 14
var _move_speed := 260.0
var _detection_range := 640.0
var _attack_radius := 58.0
var _attack_interval := 0.55
var _tint := Color.WHITE
var _next_attack_at := 0.0

func configure(owner_node, stats: Dictionary, color: Color) -> void:
	_owner = owner_node
	_damage = int(stats.get("damage", 14))
	_move_speed = float(stats.get("move_speed", 260.0))
	_detection_range = float(stats.get("range", stats.get("detection_range", 640.0)))
	_attack_radius = float(stats.get("attack_radius", 58.0))
	_attack_interval = maxf(0.1, float(stats.get("attack_interval", 0.55)))
	_tint = color
	configure_deployable_health(int(stats.get("construct_health", stats.get("health", 100))), true)

func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	var target := _find_target()
	if target == null:
		queue_redraw()
		return
	var offset: Vector2 = target.global_position - global_position
	var distance := offset.length()
	if distance > _attack_radius:
		var move_direction := offset.normalized() if distance > 0.0 else Vector2.RIGHT
		global_position += move_direction * _move_speed * delta
	else:
		_try_attack(target, offset)
	queue_redraw()

func _find_target() -> Node2D:
	var combat_owner := _get_combat_owner()
	var candidates: Array = []
	if combat_owner != null and combat_owner.has_method("get_nearby_enemy_target_nodes"):
		candidates = combat_owner.get_nearby_enemy_target_nodes(global_position, _detection_range)
	else:
		var tree := get_tree()
		candidates = tree.get_nodes_in_group("aim_target") if tree != null else []
	var best_target: Node2D = null
	var best_distance_sq := INF
	for candidate in candidates:
		if candidate == null or not is_instance_valid(candidate) or not (candidate is Node2D):
			continue
		if candidate.has_method("is_alive") and not candidate.is_alive():
			continue
		var distance_sq := (candidate as Node2D).global_position.distance_squared_to(global_position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best_target = candidate as Node2D
	return best_target

func _try_attack(target: Node2D, offset: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _next_attack_at:
		return
	_next_attack_at = now + _attack_interval
	if target.has_method("apply_damage"):
		target.apply_damage(_damage, _get_source_player_index())
	if target.has_method("apply_knockback"):
		target.apply_knockback(offset.normalized() if offset.length() > 0.0 else Vector2.RIGHT, 180.0)
	var combat_owner := _get_combat_owner()
	if combat_owner != null and combat_owner.has_method("spawn_target_hit_spark"):
		combat_owner.spawn_target_hit_spark(target.global_position, offset.normalized() if offset.length() > 0.0 else Vector2.RIGHT, _tint, 0.9)

func _get_source_player_index() -> int:
	if _owner != null and is_instance_valid(_owner) and "player_index" in _owner:
		return int(_owner.player_index)
	return -1

func _get_combat_owner() -> Node:
	var current := get_parent()
	while current != null:
		if current.has_method("get_nearby_enemy_target_nodes"):
			return current
		current = current.get_parent()
	var tree := get_tree()
	return tree.current_scene if tree != null else null

func _draw() -> void:
	draw_circle(Vector2.ZERO, 18.0, Color(_tint.r, _tint.g, _tint.b, 0.48))
	draw_arc(Vector2.ZERO, 23.0, 0.0, TAU, 20, Color(_tint.r, _tint.g, _tint.b, 0.84), 3.0)
	draw_arc(Vector2.ZERO, _attack_radius, -0.45, 0.45, 8, Color(_tint.r, _tint.g, _tint.b, 0.28), 2.0)
	_draw_deployable_health_bar(30.0)
