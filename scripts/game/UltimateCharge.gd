class_name UltimateCharge
extends Node

const DAMAGE_CHARGE_RATE := 0.0018
const KILL_CHARGE := 0.05
const CHAMPION_KILL_CHARGE := 0.30

var _player_nodes: Array = []
var _charge_by_player: Array = []

func start_room(player_nodes: Array) -> void:
	_player_nodes = player_nodes
	while _charge_by_player.size() < player_nodes.size():
		_charge_by_player.append(0.0)
	_apply_all()

func update_players(player_nodes: Array) -> void:
	_player_nodes = player_nodes
	while _charge_by_player.size() < player_nodes.size():
		_charge_by_player.append(0.0)
	_apply_all()

func add_damage(player_index: int, amount: int) -> void:
	if amount <= 0:
		return
	_add_charge(player_index, float(amount) * DAMAGE_CHARGE_RATE)

func add_kill(player_index: int, champion: bool = false) -> void:
	_add_charge(player_index, CHAMPION_KILL_CHARGE if champion else KILL_CHARGE)

func reset(player_index: int) -> void:
	if player_index < 0:
		return
	while _charge_by_player.size() <= player_index:
		_charge_by_player.append(0.0)
	_charge_by_player[player_index] = 0.0
	_apply_to_player(player_index)

func _add_charge(player_index: int, amount: float) -> void:
	if player_index < 0:
		return
	while _charge_by_player.size() <= player_index:
		_charge_by_player.append(0.0)
	_charge_by_player[player_index] = clampf(float(_charge_by_player[player_index]) + amount, 0.0, 1.0)
	_apply_to_player(player_index)

func _apply_all() -> void:
	for index in range(_player_nodes.size()):
		_apply_to_player(index)

func _apply_to_player(player_index: int) -> void:
	if player_index < 0 or player_index >= _player_nodes.size():
		return
	var player = _player_nodes[player_index]
	if player == null or not is_instance_valid(player) or not player.has_method("set_ultimate_charge"):
		return
	var charge := float(_charge_by_player[player_index]) if player_index < _charge_by_player.size() else 0.0
	player.set_ultimate_charge(charge)
