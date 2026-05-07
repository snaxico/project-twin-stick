class_name AimAssist
extends RefCounted

const PlayerConfigData = preload("res://scripts/player/PlayerConfig.gd")

const TARGET_GROUP := "aim_target"
const SNAP_RADIUS := 480.0
const ALIGNMENT_WEIGHT := 140.0

func resolve_aim_direction(
	owner: Node2D,
	raw_input: Vector2,
	move_input: Vector2,
	previous_direction: Vector2,
	aim_mode: int,
	weapon_range: float = SNAP_RADIUS
) -> Vector2:
	match aim_mode:
		PlayerConfigData.AimMode.MANUAL:
			return _fallback_direction(raw_input, move_input, previous_direction)
		PlayerConfigData.AimMode.HEAVY_AUTO:
			var desired := raw_input if raw_input.length() > 0.0 else move_input
			var target := _find_target(owner, desired if desired.length() > 0.0 else previous_direction, true, weapon_range)
			if target != null:
				return (target.global_position - owner.global_position).normalized()
			return _fallback_direction(raw_input, move_input, previous_direction)
		PlayerConfigData.AimMode.FULL_AUTO:
			var target := _find_target(owner, previous_direction, false, weapon_range)
			if target != null:
				return (target.global_position - owner.global_position).normalized()
			return _fallback_direction(Vector2.ZERO, move_input, previous_direction)
		_:
			return _fallback_direction(raw_input, move_input, previous_direction)

func _find_target(owner: Node2D, desired_direction: Vector2, require_alignment: bool, weapon_range: float = SNAP_RADIUS) -> Node2D:
	var tree := owner.get_tree()
	if tree == null:
		return null

	var best_target: Node2D = null
	var best_score := INF
	var desired := desired_direction.normalized() if desired_direction.length() > 0.0 else Vector2.RIGHT
	var max_range := weapon_range if weapon_range > 0.0 else SNAP_RADIUS

	for candidate in tree.get_nodes_in_group(TARGET_GROUP):
		if not is_instance_valid(candidate):
			continue
		if not candidate is Node2D:
			continue

		var offset: Vector2 = candidate.global_position - owner.global_position
		var distance: float = offset.length()
		if distance <= 0.0 or distance > max_range:
			continue

		var direction: Vector2 = offset / distance
		var alignment: float = direction.dot(desired)
		if require_alignment and alignment < 0.2:
			continue

		var score: float = distance - max(alignment, 0.0) * ALIGNMENT_WEIGHT
		if score < best_score:
			best_score = score
			best_target = candidate

	return best_target

func _fallback_direction(raw_input: Vector2, move_input: Vector2, previous_direction: Vector2) -> Vector2:
	if raw_input.length() > 0.0:
		return raw_input.normalized()
	if move_input.length() > 0.0:
		return move_input.normalized()
	if previous_direction.length() > 0.0:
		return previous_direction.normalized()
	return Vector2.RIGHT
