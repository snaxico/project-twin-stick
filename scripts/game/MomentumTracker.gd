extends Node

const MOMENTUM_THRESHOLDS := [10, 25, 45, 70]
const MOMENTUM_MOVE_BONUSES := [0.0, 0.10, 0.20, 0.35, 0.50]
const MOMENTUM_FIRE_RATE_BONUSES := [0.0, 0.15, 0.30, 0.50, 0.75]

var _coop: Node = null
var _player_nodes: Array = []
var _momentum_progress_by_player: Array = []
var _momentum_tier_by_player: Array = []
var _room_max_momentum_tier := 0


func setup(coop: Node) -> void:
	_coop = coop


func start_room(player_nodes: Array) -> void:
	_player_nodes = player_nodes
	_room_max_momentum_tier = 0
	_restore_momentum()


func update_players(player_nodes: Array) -> void:
	_player_nodes = player_nodes


func gain_shared_momentum() -> void:
	for index in range(_player_nodes.size()):
		if not _is_momentum_player(index):
			continue
		_momentum_progress_by_player[index] = int(_momentum_progress_by_player[index]) + 1
		_update_momentum_tier(index)
		_store_momentum(index)


func drop_player_momentum(player_index: int) -> void:
	if player_index < 0 or player_index >= _momentum_tier_by_player.size():
		return
	if not _is_momentum_player(player_index):
		return
	var new_tier: int = max(0, int(_momentum_tier_by_player[player_index]) - 2)
	_momentum_tier_by_player[player_index] = new_tier
	_momentum_progress_by_player[player_index] = _get_min_progress_for_momentum_tier(new_tier)
	apply_to_player(player_index)
	_store_momentum(player_index)


func apply_to_player(player_index: int) -> void:
	if player_index < 0 or player_index >= _player_nodes.size():
		return
	var player = _player_nodes[player_index]
	if player == null or not is_instance_valid(player) or not player.has_method("set_momentum_tier"):
		return
	if not _is_momentum_player(player_index):
		player.set_momentum_tier(0, 0.0, 0.0)
		return
	var tier := int(_momentum_tier_by_player[player_index]) if player_index < _momentum_tier_by_player.size() else 0
	player.set_momentum_tier(
		tier,
		float(MOMENTUM_MOVE_BONUSES[tier]),
		float(MOMENTUM_FIRE_RATE_BONUSES[tier])
	)


func get_momentum_tier(player_index: int) -> int:
	return int(_momentum_tier_by_player[player_index]) if player_index >= 0 and player_index < _momentum_tier_by_player.size() else 0


func get_room_max_tier() -> int:
	return _room_max_momentum_tier


func _restore_momentum() -> void:
	_momentum_progress_by_player.clear()
	_momentum_tier_by_player.clear()
	for index in range(_player_nodes.size()):
		var state := RunState.get_momentum_state(index)
		var active := _is_momentum_player(index)
		_momentum_progress_by_player.append(int(state.get("progress", 0)) if active else 0)
		_momentum_tier_by_player.append(int(state.get("tier", 0)) if active else 0)
		_room_max_momentum_tier = maxi(_room_max_momentum_tier, int(state.get("tier", 0)) if active else 0)
		apply_to_player(index)


func _update_momentum_tier(player_index: int) -> void:
	if player_index < 0 or player_index >= _momentum_progress_by_player.size():
		return
	var previous_tier := int(_momentum_tier_by_player[player_index]) if player_index < _momentum_tier_by_player.size() else 0
	var progress := int(_momentum_progress_by_player[player_index])
	var tier := 0
	for threshold_index in range(MOMENTUM_THRESHOLDS.size()):
		if progress >= int(MOMENTUM_THRESHOLDS[threshold_index]):
			tier = threshold_index + 1
	_momentum_tier_by_player[player_index] = tier
	_room_max_momentum_tier = maxi(_room_max_momentum_tier, tier)
	if tier > previous_tier:
		_on_momentum_tier_gained(tier)
	apply_to_player(player_index)


func _on_momentum_tier_gained(tier: int) -> void:
	# Subtle reward pulse on climbing a momentum tier.
	_coop.call("play_sfx", "play_pickup", [0.6 + 0.18 * float(tier)])
	_coop.call("spawn_screen_flash", Color(0.42, 1.0, 0.86, 0.05 + 0.02 * float(tier)), 0.18)


func _store_momentum(player_index: int) -> void:
	if player_index < 0 or player_index >= _momentum_tier_by_player.size() or player_index >= _momentum_progress_by_player.size():
		return
	RunState.set_momentum_state(player_index, int(_momentum_tier_by_player[player_index]), int(_momentum_progress_by_player[player_index]))


func _get_min_progress_for_momentum_tier(tier: int) -> int:
	if tier <= 0:
		return 0
	return int(MOMENTUM_THRESHOLDS[clampi(tier, 1, 4) - 1])

func _is_momentum_player(player_index: int) -> bool:
	if player_index < 0 or player_index >= _player_nodes.size():
		return false
	var player = _player_nodes[player_index]
	return player != null and is_instance_valid(player) and player.has_method("has_passive") and bool(player.has_passive("momentum"))
