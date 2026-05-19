class_name AutoTarget
extends RefCounted

const TARGET_GROUP := "aim_target"
const SNAP_RADIUS := 950.0

func find_nearest(owner: Node2D, weapon_range: float = SNAP_RADIUS) -> Node2D:
	var tree := owner.get_tree()
	if tree == null:
		return null

	var best_target: Node2D = null
	var best_distance := INF
	var max_range := weapon_range if weapon_range > 0.0 else SNAP_RADIUS

	for candidate in tree.get_nodes_in_group(TARGET_GROUP):
		if not is_instance_valid(candidate) or not (candidate is Node2D):
			continue
		if candidate.has_method("is_alive") and not candidate.is_alive():
			continue

		var offset: Vector2 = (candidate as Node2D).global_position - owner.global_position
		var distance: float = offset.length()
		if distance <= 0.0 or distance > max_range:
			continue
		if distance < best_distance:
			best_distance = distance
			best_target = candidate as Node2D

	return best_target
