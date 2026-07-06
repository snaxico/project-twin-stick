extends Node

const EnemySceneData = preload("res://scenes/enemies/Enemy.tscn")
const EnemyTypes = preload("res://scripts/game/EnemyTypes.gd")
const ArenaGeometry = preload("res://scripts/game/ArenaGeometry.gd")

const ARENA_SIZE := Vector2(3600.0, 2100.0)
const ARENA_CENTER := Vector2(ARENA_SIZE.x * 0.5, ARENA_SIZE.y * 0.5)
const ARENA_MARGIN := 72.0
const BASE_RAMP_DURATION := 45.0
const CHAMPION_SPAWN_DELAY := 10.0

var _coop: Node = null
var _enemies_parent: Node = null
var _room_config: Dictionary = {}
var _room_type := "combat"
var _room_enemy_pool: Array = []
var _room_depth := 1
var _room_duration := 45.0
var _spawn_interval := 1.6
var _next_spawn_at := 0.0
var _spawn_count_accumulator := 0.0
var _enemies_spawned := 0
var _pending_enemy_spawns := 0
var _spawning_done := false
var _burst_interval := 10.0
var _next_burst_at := 0.0
var _boss_spawned := false
var _active_boss = null


func setup(coop: Node, enemies_parent: Node) -> void:
	_coop = coop
	_enemies_parent = enemies_parent


func start_room(room_config: Dictionary, room_enemy_pool: Array, room_depth: int) -> void:
	_room_config = room_config.duplicate(true)
	_room_type = str(_room_config.get("room_type", "combat"))
	_room_enemy_pool = room_enemy_pool.duplicate()
	_room_depth = room_depth
	_room_duration = _get_room_duration()
	_spawn_interval = _get_spawn_interval()
	_next_spawn_at = 0.4
	_spawn_count_accumulator = 0.0
	_enemies_spawned = 0
	_pending_enemy_spawns = 0
	_spawning_done = false
	_burst_interval = _get_burst_interval()
	_next_burst_at = _burst_interval
	_boss_spawned = false
	_active_boss = null


func check_wave_progress() -> void:
	if _coop == null or bool(_coop.call("is_room_clear_started")):
		return
	var room_elapsed := float(_coop.call("get_room_elapsed"))
	if _room_type == "boss" and not _boss_spawned and room_elapsed >= _get_champion_spawn_delay():
		_spawn_boss()
	if not _spawning_done:
		_continuous_spawn(room_elapsed)
	# Defensive: a champion room must spawn its champion before it can clear, even if future
	# tuning ever made the spawn delay exceed the room duration.
	if _room_type == "boss" and not _boss_spawned and _spawning_done:
		_spawn_boss()
	if _spawning_done and bool(_coop.call("is_enemy_list_empty")) and _pending_enemy_spawns <= 0:
		_coop.call("handle_wave_room_clear")


func spawn_opening_burst() -> void:
	var flags := _get_minor_modifier_flags()
	var burst_size := _get_burst_size(true)
	if bool(flags.get("swarm", false)):
		burst_size *= 2
	burst_size = _scale_spawn_count(burst_size)
	var health_multiplier := 0.5 if bool(flags.get("swarm", false)) else 1.0
	var start_edge := randi() % 4
	for index in range(burst_size):
		var enemy_type := _roll_wave_enemy_type(_room_enemy_pool)
		var spawn_position := _get_enemy_spawn_position_for_index(index, start_edge)
		queue_enemy_spawn(enemy_type, spawn_position, health_multiplier)
		_enemies_spawned += 1


func spawn_enemy_instance(enemy_type: String, spawn_position: Vector2, health_multiplier: float = 1.0) -> Node2D:
	if _enemies_parent == null:
		return null
	var enemy = EnemySceneData.instantiate()
	_enemies_parent.add_child(enemy)
	enemy.global_position = spawn_position
	enemy.setup(enemy_type, _coop)
	var flags := _get_minor_modifier_flags()
	enemy.apply_room_modifier({
		"health_multiplier": health_multiplier,
		"speed_multiplier": 1.33 if bool(flags.get("enemy_speed", false)) else 1.0,
		"fire_interval_multiplier": 0.75 if bool(flags.get("enemy_speed", false)) else 1.0,
		"shielded": bool(flags.get("shielded", false)),
		"death_explosion_radius": 80.0 if bool(flags.get("explosive_death", false)) else 0.0,
		"death_explosion_damage": 10 if bool(flags.get("explosive_death", false)) else 0,
	})
	enemy.enemy_died.connect(Callable(_coop, "_on_enemy_died"))
	enemy.fire_requested.connect(Callable(_coop, "_on_enemy_fire_requested"))
	enemy.hit_received.connect(Callable(_coop, "_on_enemy_hit_received"))
	_coop.call("register_enemy", enemy)
	return enemy


func queue_enemy_spawn(enemy_type: String, spawn_position: Vector2, health_multiplier: float = 1.0) -> void:
	_pending_enemy_spawns += 1
	call_deferred("_spawn_queued_enemy_instance", enemy_type, spawn_position, health_multiplier)


func clear_active_boss_if(enemy) -> void:
	if enemy == _active_boss:
		_active_boss = null


func get_active_boss():
	return _active_boss


func get_room_duration() -> float:
	return _room_duration


func is_spawning_done() -> bool:
	return _spawning_done


func get_pending_enemy_spawns() -> int:
	return _pending_enemy_spawns


func _continuous_spawn(room_elapsed: float) -> void:
	if room_elapsed >= _room_duration:
		_spawning_done = true
		return
	var flags := _get_minor_modifier_flags()
	var health_multiplier := 0.5 if bool(flags.get("swarm", false)) else 1.0
	if room_elapsed >= _next_spawn_at:
		var current_interval := _spawn_interval
		var base_ramp := clampf(room_elapsed / BASE_RAMP_DURATION, 0.0, 1.0)
		current_interval = lerpf(_spawn_interval, _spawn_interval * 0.55, base_ramp)
		if bool(flags.get("accelerating_waves", false)):
			var ramp := clampf(room_elapsed / min(_room_duration, 25.0), 0.0, 1.0)
			current_interval = lerpf(current_interval, current_interval * 0.6, ramp)
		_next_spawn_at = room_elapsed + current_interval
		var batch := _consume_scaled_stream_count(2 if bool(flags.get("swarm", false)) else 1)
		var stream_start_edge := randi() % 4 if batch > 1 else 0
		for index in range(batch):
			var enemy_type := _roll_wave_enemy_type(_room_enemy_pool)
			var spawn_position := _get_enemy_spawn_position() if batch == 1 else _get_enemy_spawn_position_for_index(index, stream_start_edge)
			queue_enemy_spawn(enemy_type, spawn_position, health_multiplier)
			_enemies_spawned += 1
	if room_elapsed >= _next_burst_at:
		_next_burst_at = room_elapsed + _burst_interval
		var burst_size := _get_burst_size(false)
		if bool(flags.get("swarm", false)):
			burst_size *= 2
		burst_size = _scale_spawn_count(burst_size)
		var burst_start_edge := randi() % 4
		for index in range(burst_size):
			var enemy_type := _roll_wave_enemy_type(_room_enemy_pool)
			var spawn_position := _get_enemy_spawn_position_for_index(index, burst_start_edge)
			queue_enemy_spawn(enemy_type, spawn_position, health_multiplier)
			_enemies_spawned += 1


func _spawn_queued_enemy_instance(enemy_type: String, spawn_position: Vector2, health_multiplier: float) -> void:
	_pending_enemy_spawns = max(_pending_enemy_spawns - 1, 0)
	if _coop == null or bool(_coop.call("is_room_clear_started")) or not is_inside_tree():
		return
	spawn_enemy_instance(enemy_type, spawn_position, health_multiplier)


func _spawn_boss() -> void:
	if _boss_spawned or _coop == null or bool(_coop.call("is_room_clear_started")):
		return
	_boss_spawned = true
	var boss_type := str(_room_config.get("boss_type", "warden"))
	var boss = spawn_enemy_instance(EnemyTypes.champion_enemy_id(boss_type), _get_champion_spawn_position(), 1.0)
	_active_boss = boss
	if boss != null and boss.has_method("apply_champion_scale"):
		boss.apply_champion_scale(_room_depth, int(_coop.call("get_player_count")))
	_coop.call("on_boss_spawned")


func _roll_wave_enemy_type(pool: Array) -> String:
	if pool.is_empty():
		return "chaser"
	return str(pool[randi() % pool.size()])


func _get_enemy_count_multiplier() -> float:
	var player_mult := 1.5 if int(_coop.call("get_player_count")) >= 2 else 1.0
	var progress := RunState.get_run_progress()
	var density_mult := lerpf(1.15, 1.4, clampf(progress, 0.0, 1.0)) + maxf(progress - 1.0, 0.0) * 0.12
	return player_mult * density_mult


func _scale_spawn_count(base_count: int) -> int:
	return maxi(0, int(round(float(base_count) * _get_enemy_count_multiplier())))


func _consume_scaled_stream_count(base_batch: int) -> int:
	_spawn_count_accumulator += float(base_batch) * _get_enemy_count_multiplier()
	var spawn_count := int(floor(_spawn_count_accumulator))
	_spawn_count_accumulator -= float(spawn_count)
	return maxi(spawn_count, 0)


func _get_room_duration() -> float:
	var progress := RunState.get_run_progress()
	var arc_progress := clampf(progress, 0.0, 1.0)
	var continuation := maxf(progress - 1.0, 0.0)
	return lerpf(32.0, 43.0, arc_progress) + continuation * 4.0


func _get_spawn_interval() -> float:
	var progress := RunState.get_run_progress()
	var arc_progress := clampf(progress, 0.0, 1.0)
	var continuation := maxf(progress - 1.0, 0.0)
	var base := lerpf(0.58, 0.40, arc_progress) - continuation * 0.12
	return maxf(base, 0.30)


func _get_champion_spawn_delay() -> float:
	if _room_config.has("boss_spawn_delay"):
		return maxf(0.0, float(_room_config.get("boss_spawn_delay", CHAMPION_SPAWN_DELAY)))
	var continuation_depth := maxi(_room_depth - RunState.RUN_LENGTH, 0)
	return maxf(7.0, CHAMPION_SPAWN_DELAY - float(continuation_depth) * 0.15)


func _get_burst_interval() -> float:
	var progress := RunState.get_run_progress()
	var arc_progress := clampf(progress, 0.0, 1.0)
	var continuation := maxf(progress - 1.0, 0.0)
	return maxf(5.0, lerpf(11.0, 7.0, arc_progress) - continuation * 2.0)


func _get_burst_size(is_opening: bool) -> int:
	var progress := RunState.get_run_progress()
	var arc_progress := clampf(progress, 0.0, 1.0)
	var continuation := maxf(progress - 1.0, 0.0)
	var base := lerpf(6.0 if is_opening else 5.0, 9.0 if is_opening else 10.0, arc_progress)
	var continuation_bonus := continuation * (3.0 if is_opening else 5.0)
	return maxi(1, int(round(base + continuation_bonus)))


func _get_champion_spawn_position() -> Vector2:
	return ArenaGeometry.champion_spawn_position(ARENA_CENTER)


func _get_enemy_spawn_position() -> Vector2:
	var inner_margin := ARENA_MARGIN + 48.0
	var edge := randi() % 4
	return ArenaGeometry.enemy_spawn_position_for_edge(edge, inner_margin, ARENA_SIZE)


func _get_enemy_spawn_position_for_index(spawn_index: int, start_edge: int) -> Vector2:
	var inner_margin := ARENA_MARGIN + 48.0
	return ArenaGeometry.enemy_spawn_position_for_index(spawn_index, start_edge, inner_margin, ARENA_SIZE)


func _get_minor_modifier_flags() -> Dictionary:
	return _coop.call("get_minor_modifier_flags") as Dictionary
