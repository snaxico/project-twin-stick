class_name IceZoneModifier
extends Node2D

const PATCH_RADIUS := 90.0
const PATCH_DURATION := 5.0
const ICE_ZONE_SOURCE := "ice_zone"
const MAX_PATCHES := 10
const MIN_SPAWN_INTERVAL := 0.6
const ARC_SEGMENTS := 18

var _patches: Array = []
var _player_nodes: Array = []
var _elapsed := 0.0
var _next_spawn_at := 0.0

func setup(_arena_rect: Rect2, player_nodes: Array) -> void:
	_player_nodes = player_nodes
	set_physics_process(true)
	queue_redraw()

func spawn_patch(patch_position: Vector2) -> void:
	# Throttled + capped: Ice Zone is fed one call per enemy death, so without these the patch
	# list grows unbounded and every patch redraws an arc each frame (high-density lag).
	if _elapsed < _next_spawn_at:
		return
	_next_spawn_at = _elapsed + MIN_SPAWN_INTERVAL
	if _patches.size() >= MAX_PATCHES:
		_patches.remove_at(0)  # recycle the oldest patch
	_patches.append({
		"position": patch_position,
		"time": 0.0,
	})
	queue_redraw()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	var live_patches: Array = []
	for patch in _patches:
		patch["time"] = float(patch.get("time", 0.0)) + delta
		if float(patch.get("time", 0.0)) >= PATCH_DURATION:
			continue
		live_patches.append(patch)
	_patches = live_patches
	for player in _player_nodes:
		if player == null or not is_instance_valid(player):
			continue
		var inside_any_patch := false
		if player.has_method("is_alive") and player.is_alive():
			for patch in _patches:
				if player.global_position.distance_to(patch["position"] as Vector2) <= PATCH_RADIUS:
					inside_any_patch = true
					break
		if inside_any_patch:
			player.apply_zone_modifier(ICE_ZONE_SOURCE, 0.5, 1.0)
		else:
			player.clear_zone_modifier(ICE_ZONE_SOURCE)
	queue_redraw()

func _exit_tree() -> void:
	_clear_all_player_modifiers()

func _clear_all_player_modifiers() -> void:
	for player in _player_nodes:
		if player == null or not is_instance_valid(player):
			continue
		if player.has_method("clear_zone_modifier"):
			player.clear_zone_modifier(ICE_ZONE_SOURCE)

func _draw() -> void:
	for patch in _patches:
		var progress := 1.0 - clampf(float(patch.get("time", 0.0)) / PATCH_DURATION, 0.0, 1.0)
		var center := patch["position"] as Vector2
		draw_circle(center, PATCH_RADIUS, Color(0.24, 0.72, 1.0, 0.14 * progress))
		draw_arc(center, PATCH_RADIUS, 0.0, TAU, ARC_SEGMENTS, Color(0.76, 0.92, 1.0, 0.34 * progress), 4.0)
