extends Node2D
class_name ArenaMechanic

var _arena: Rect2
var _players: Array = []
var _coop: Node = null


func setup(arena: Rect2, players: Array, coop: Node) -> void:
	_arena = arena
	_players = players
	_coop = coop
	set_physics_process(true)
	queue_redraw()


func damage_circle(center: Vector2, radius: float, dmg: int, hit_players := true) -> void:
	var radius_sq := radius * radius
	if hit_players:
		for player in _players:
			if player == null or not is_instance_valid(player) or not (player is Node2D):
				continue
			if player.has_method("is_alive") and not player.is_alive():
				continue
			if (player as Node2D).global_position.distance_squared_to(center) <= radius_sq and player.has_method("apply_damage"):
				player.apply_damage(dmg)
	if _coop == null or not _coop.has_method("get_nearby_enemy_target_nodes"):
		return
	for enemy in _coop.get_nearby_enemy_target_nodes(center, radius):
		if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue
		if (enemy as Node2D).global_position.distance_squared_to(center) <= radius_sq and enemy.has_method("apply_damage"):
			enemy.apply_damage(dmg)


func _damage_player(player, amount: int) -> void:
	if player != null and is_instance_valid(player) and player.has_method("apply_damage"):
		if not player.has_method("is_alive") or player.is_alive():
			player.apply_damage(amount)


func _damage_enemy(enemy, amount: int) -> void:
	if enemy != null and is_instance_valid(enemy) and enemy.has_method("apply_damage"):
		if not enemy.has_method("is_alive") or enemy.is_alive():
			enemy.apply_damage(amount)


func _point_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var denom := ab.length_squared()
	if denom <= 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / denom, 0.0, 1.0)
	return point.distance_to(a + ab * t)
