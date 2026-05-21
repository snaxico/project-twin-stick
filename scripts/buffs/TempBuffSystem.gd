class_name TempBuffSystem
extends RefCounted

const BUFF_POOL := ["speed", "damage", "attack_speed"]
const BUFF_VALUE := 0.5

var _random := RandomNumberGenerator.new()

func _init() -> void:
	_random.randomize()

func roll_random_buff() -> Dictionary:
	var buff_type: String = str(BUFF_POOL[_random.randi_range(0, BUFF_POOL.size() - 1)])
	return {"type": buff_type, "value": BUFF_VALUE}

func apply_buff(buff: Dictionary, player_nodes: Array) -> void:
	var buff_type := str(buff.get("type", ""))
	var value := float(buff.get("value", BUFF_VALUE))
	for player in player_nodes:
		if player == null or not is_instance_valid(player) or not player.has_method("apply_temp_buff"):
			continue
		player.apply_temp_buff(buff_type, value)

func clear_all_buffs(player_nodes: Array) -> void:
	for player in player_nodes:
		if player == null or not is_instance_valid(player) or not player.has_method("clear_temp_buffs"):
			continue
		player.clear_temp_buffs()
