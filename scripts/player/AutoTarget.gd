class_name AutoTarget
extends RefCounted

const TARGET_GROUP := "aim_target"
const SNAP_RADIUS := 950.0

func find_nearest(owner: Node2D, weapon_range: float = SNAP_RADIUS) -> Node2D:
	var tree := owner.get_tree()
	if tree == null:
		return null

	var best_target: Node2D = null
	var best_distance_sq := INF
	var max_range := weapon_range if weapon_range > 0.0 else SNAP_RADIUS
	var max_range_sq := max_range * max_range
	var candidates: Array = []
	var combat_owner := tree.current_scene
	if combat_owner != null and combat_owner.has_method("get_nearby_enemy_target_nodes"):
		candidates = combat_owner.get_nearby_enemy_target_nodes(owner.global_position, max_range)
	else:
		candidates = tree.get_nodes_in_group(TARGET_GROUP)

	for candidate in candidates:
		if not is_instance_valid(candidate) or not (candidate is Node2D):
			continue
		if candidate.has_method("is_alive") and not candidate.is_alive():
			continue

		var offset: Vector2 = (candidate as Node2D).global_position - owner.global_position
		var distance_sq := offset.length_squared()
		if distance_sq <= 0.0 or distance_sq > max_range_sq:
			continue
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best_target = candidate as Node2D

	return best_target
