extends Node

const TempBuffSystemData = preload("res://scripts/buffs/TempBuffSystem.gd")
const HoldZoneObjectiveData = preload("res://scripts/objectives/HoldZoneObjective.gd")
const CollectorOrbData = preload("res://scripts/game/CollectorOrb.gd")
const CoopFormat = preload("res://scripts/game/CoopFormat.gd")

const COLLECTOR_TARGET := 8
const COLLECTOR_TOTAL_SPAWN := 12
const COLLECTOR_SPAWN_INTERVAL := 2.5

var _coop: Node = null
var _effects_parent: Node = null
var _pickups_parent: Node = null
var _arena_rect := Rect2()
var _player_nodes: Array = []
var _hold_zone = null
var _temp_buff_system = null
var _hold_buff_offer: Dictionary = {}
var _side_objective_id := ""
var _side_objective_completed := false
var _kill_streak_target := 0
var _kill_streak_progress := 0
var _collector_collected := 0
var _collector_spawned := 0
var _collector_spawn_timer := COLLECTOR_SPAWN_INTERVAL
var _collector_orbs: Array = []


func setup(coop: Node, effects_parent: Node, pickups_parent: Node, arena_rect: Rect2) -> void:
	_coop = coop
	_effects_parent = effects_parent
	_pickups_parent = pickups_parent
	_arena_rect = arena_rect


func start_room(room_config: Dictionary, player_nodes: Array) -> void:
	if _temp_buff_system != null:
		_temp_buff_system.clear_all_buffs(player_nodes)
	_player_nodes = player_nodes
	_hold_zone = null
	_hold_buff_offer.clear()
	_collector_orbs.clear()
	_side_objective_id = str(room_config.get("side_objective", ""))
	_side_objective_completed = false
	_kill_streak_target = 0
	_kill_streak_progress = 0
	_collector_collected = 0
	_collector_spawned = 0
	_collector_spawn_timer = COLLECTOR_SPAWN_INTERVAL
	_temp_buff_system = TempBuffSystemData.new()
	if _side_objective_id.is_empty():
		return
	_hold_buff_offer = _temp_buff_system.roll_random_buff()
	match _side_objective_id:
		"hold_zone":
			_hold_zone = HoldZoneObjectiveData.new()
			_hold_zone.setup(_arena_rect)
			_effects_parent.add_child(_hold_zone)
			_hold_zone.completed.connect(_complete_side_objective)
		"kill_streak":
			_kill_streak_target = 30
		"collector":
			_collector_spawn_timer = 0.8


func clear_runtime() -> void:
	_hold_zone = null
	_collector_orbs.clear()
	_hold_buff_offer.clear()


func update(delta: float, player_nodes: Array) -> void:
	_player_nodes = player_nodes
	if _side_objective_completed or _side_objective_id.is_empty():
		return
	match _side_objective_id:
		"hold_zone":
			if _hold_zone != null and is_instance_valid(_hold_zone):
				_hold_zone.update_zone(delta, player_nodes)
		"collector":
			_collector_spawn_timer -= delta
			if _collector_spawned < COLLECTOR_TOTAL_SPAWN and _collector_spawn_timer <= 0.0:
				_collector_spawn_timer = COLLECTOR_SPAWN_INTERVAL
				_spawn_collector_orb()
			var collected_now := 0
			for orb in _collector_orbs:
				if orb == null or not is_instance_valid(orb):
					continue
				if orb.update_orb(delta, player_nodes):
					collected_now += 1
			_collector_collected += collected_now
			if collected_now > 0:
				_coop.call("play_sfx", "play_pickup", [])
			_cleanup_orbs()
			if _collector_collected >= COLLECTOR_TARGET:
				_complete_side_objective()


func on_enemy_killed() -> void:
	if _side_objective_id == "kill_streak" and not _side_objective_completed:
		_kill_streak_progress += 1
		if _kill_streak_progress >= _kill_streak_target:
			_complete_side_objective()


func on_player_damaged() -> void:
	if _side_objective_id == "kill_streak" and not _side_objective_completed:
		_kill_streak_progress = 0


func build_clear_summary() -> String:
	var lines := ["Room cleared."]
	if not _side_objective_id.is_empty():
		lines.append("Objective: %s" % format_objective_text())
		if _side_objective_completed:
			lines.append("Buff earned: %s" % CoopFormat.format_buff_name(str(_hold_buff_offer.get("type", ""))))
	return "\n".join(lines)


func format_objective_text() -> String:
	if _side_objective_completed:
		return "Complete"
	match _side_objective_id:
		"hold_zone":
			return _hold_zone.get_progress_text() if _hold_zone != null and is_instance_valid(_hold_zone) else "Hold Zone"
		"kill_streak":
			return "Kill Streak %d/%d" % [_kill_streak_progress, _kill_streak_target]
		"collector":
			return "Collector %d/%d" % [_collector_collected, COLLECTOR_TARGET]
		_:
			return ""


func get_view() -> Dictionary:
	return {
		"id": _side_objective_id,
		"completed": _side_objective_completed,
		"hold_zone": _hold_zone,
		"hold_buff_offer": _hold_buff_offer.duplicate(true),
		"kill_streak_progress": _kill_streak_progress,
		"kill_streak_target": _kill_streak_target,
		"collector_collected": _collector_collected,
		"collector_target": COLLECTOR_TARGET,
	}


func _complete_side_objective() -> void:
	if _side_objective_completed or _temp_buff_system == null or _hold_buff_offer.is_empty():
		return
	_side_objective_completed = true
	_temp_buff_system.apply_buff(_hold_buff_offer, _player_nodes)


func _spawn_collector_orb() -> void:
	if _collector_spawned >= COLLECTOR_TOTAL_SPAWN:
		return
	var orb := CollectorOrbData.new()
	var spawn_position := Vector2(
		randf_range(_arena_rect.position.x + 220.0, _arena_rect.end.x - 220.0),
		randf_range(_arena_rect.position.y + 220.0, _arena_rect.end.y - 220.0)
	)
	if _coop != null and _coop.has_method("get_safe_pickup_position"):
		spawn_position = _coop.call("get_safe_pickup_position", spawn_position)
	orb.global_position = spawn_position
	_pickups_parent.add_child(orb)
	_collector_orbs.append(orb)
	_collector_spawned += 1


func _cleanup_orbs() -> void:
	var alive_orbs: Array = []
	for orb in _collector_orbs:
		if orb != null and is_instance_valid(orb):
			alive_orbs.append(orb)
	_collector_orbs = alive_orbs
