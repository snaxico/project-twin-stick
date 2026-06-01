class_name IceZoneModifier
extends Node2D

const PATCH_RADIUS := 90.0
const PATCH_DURATION := 5.0

var _patches: Array = []
var _player_nodes: Array = []
var _patch_sources_by_player: Dictionary = {}

func setup(_arena_rect: Rect2, player_nodes: Array) -> void:
	_player_nodes = player_nodes
	set_physics_process(true)
	queue_redraw()

func spawn_patch(position: Vector2) -> void:
	_patches.append({
		"position": position,
		"time": 0.0,
		"id": "ice_%d" % Time.get_ticks_usec(),
	})
	queue_redraw()

func _physics_process(delta: float) -> void:
	var affected_sources: Dictionary = {}
	var expired: Array = []
	for patch in _patches:
		patch["time"] = float(patch.get("time", 0.0)) + delta
		if float(patch.get("time", 0.0)) >= PATCH_DURATION:
			expired.append(patch)
			continue
		var patch_id := str(patch.get("id", ""))
		for player in _player_nodes:
			if player == null or not is_instance_valid(player) or not player.has_method("is_alive") or not player.is_alive():
				continue
			if player.global_position.distance_to(patch["position"] as Vector2) <= PATCH_RADIUS:
				player.apply_zone_modifier(patch_id, 0.5, 1.0)
				if not affected_sources.has(player):
					affected_sources[player] = []
				(affected_sources[player] as Array).append(patch_id)
	queue_redraw()
	for patch in expired:
		_patches.erase(patch)
	for player in _player_nodes:
		if player == null or not is_instance_valid(player):
			continue
		var active_ids: Array = affected_sources.get(player, []) as Array
		var previous_ids: Array = _patch_sources_by_player.get(player, []) as Array
		for patch_id in previous_ids:
			if not active_ids.has(patch_id):
				player.clear_zone_modifier(str(patch_id))
		_patch_sources_by_player[player] = active_ids.duplicate()

func _draw() -> void:
	for patch in _patches:
		var progress := 1.0 - clampf(float(patch.get("time", 0.0)) / PATCH_DURATION, 0.0, 1.0)
		var center := patch["position"] as Vector2
		draw_circle(center, PATCH_RADIUS, Color(0.24, 0.72, 1.0, 0.14 * progress))
		draw_arc(center, PATCH_RADIUS, 0.0, TAU, 40, Color(0.76, 0.92, 1.0, 0.34 * progress), 4.0)
