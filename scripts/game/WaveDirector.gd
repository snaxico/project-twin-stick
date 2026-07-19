extends Node

const EnemySceneData = preload("res://scenes/enemies/Enemy.tscn")
const EnemyTypes = preload("res://scripts/game/EnemyTypes.gd")
const ArenaGeometry = preload("res://scripts/game/ArenaGeometry.gd")

const ARENA_SIZE := Vector2(3600.0, 2100.0)
const ARENA_CENTER := Vector2(ARENA_SIZE.x * 0.5, ARENA_SIZE.y * 0.5)
const ARENA_MARGIN := 72.0
const BASE_RAMP_DURATION := 45.0
const CHAMPION_SPAWN_DELAY := 10.0
const SHOOTER_COST := {"spitter": 1}
const SHOOTER_BUDGET_BASE := 6
const PULSE_PERIOD := 4.0
const PULSE_SPREAD := 0.8
const PULSE_EDGES := 2
# Physics wall: ~200 CharacterBody2D enemies bunching around physical cover push move_and_slide past the
# 60fps budget. Open rooms have no obstacles and stay uncapped (the swarm power-fantasy lives there). When a
# room has physical cover (a Batch-B WHERE mechanic), cap the concurrent live+pending count — this keeps cover
# rooms readable AND performant. Density-scaled spawning still fills up to the cap and refills as enemies die.
const MAX_OBSTACLE_ENEMIES := 160

var _coop: Node = null
var _enemies_parent: Node = null
var _room_config: Dictionary = {}
var _room_type := "combat"
var _room_enemy_pool: Array = []
var _room_composition: Dictionary = {}
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
var _active_shooter_budget := 0
var _spawn_model := "trickle"
var _spawn_rng: RandomNumberGenerator = null
var _pulse_accumulated := 0
var _next_pulse_at := PULSE_PERIOD
var _pending_pulse_spawns: Array = []
var _spawn_event_log: Array = []


func setup(coop: Node, enemies_parent: Node) -> void:
	_coop = coop
	_enemies_parent = enemies_parent


func start_room(room_config: Dictionary, room_enemy_pool: Array, room_depth: int) -> void:
	_room_config = room_config.duplicate(true)
	_room_type = str(_room_config.get("room_type", "combat"))
	_room_enemy_pool = room_enemy_pool.duplicate()
	_room_composition = (_room_config.get("composition", {}) as Dictionary).duplicate(true)
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
	_active_shooter_budget = 0
	_spawn_model = RunState.apply_pending_spawn_model()
	_spawn_rng = null
	var debug_seed := int(RunState.debug_spawn_seed)
	if _spawn_model == "pulsed" or debug_seed > 0:
		_spawn_rng = RandomNumberGenerator.new()
		_spawn_rng.seed = debug_seed if debug_seed > 0 else _derived_spawn_seed()
	_pulse_accumulated = 0
	_next_pulse_at = PULSE_PERIOD
	_pending_pulse_spawns.clear()
	_spawn_event_log.clear()


func check_wave_progress() -> void:
	if _coop == null or bool(_coop.call("is_room_clear_started")):
		return
	var room_elapsed := float(_coop.call("get_room_elapsed"))
	if _room_type == "boss" and not _boss_spawned and room_elapsed >= _get_champion_spawn_delay():
		_spawn_boss()
	if not _spawning_done and not _is_profiling_no_spawn():
		_continuous_spawn(room_elapsed)
	if _spawn_model == "pulsed":
		_process_pending_pulse_spawns(room_elapsed)
	# Defensive: a champion room must spawn its champion before it can clear, even if future
	# tuning ever made the spawn delay exceed the room duration.
	if _room_type == "boss" and not _boss_spawned and _spawning_done:
		_spawn_boss()
	if _spawning_done and _pending_pulse_spawns.is_empty() and bool(_coop.call("is_enemy_list_empty")) and _pending_enemy_spawns <= 0:
		_coop.call("handle_wave_room_clear")


func spawn_opening_burst() -> void:
	if _is_profiling_no_spawn():
		return
	var flags := _get_minor_modifier_flags()
	var burst_size := _get_burst_size(true)
	if bool(flags.get("swarm", false)):
		burst_size *= 2
	burst_size = _scale_spawn_count(burst_size)
	var health_multiplier := 0.5 if bool(flags.get("swarm", false)) else 1.0
	var start_edge := _randi_mod(4)
	for index in range(burst_size):
		if _obstacle_enemy_cap_reached():
			break
		var enemy_type := _pick_spawn_type(_get_spawn_source())
		var reserved_cost := _shooter_cost(enemy_type)
		var spawn_position := _get_enemy_spawn_position_for_index(index, start_edge)
		_queue_logged_enemy_spawn(enemy_type, spawn_position, health_multiplier, reserved_cost)
		_enemies_spawned += 1


func spawn_enemy_instance(enemy_type: String, spawn_position: Vector2, health_multiplier: float = 1.0, rng_seed: int = -1) -> Node2D:
	if _enemies_parent == null:
		return null
	var enemy = EnemySceneData.instantiate()
	_enemies_parent.add_child(enemy)
	enemy.global_position = spawn_position
	if rng_seed >= 0 and enemy.has_method("seed_rng"):
		enemy.seed_rng(rng_seed)
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


func queue_enemy_spawn(enemy_type: String, spawn_position: Vector2, health_multiplier: float = 1.0, reserved_cost: int = 0) -> void:
	_pending_enemy_spawns += 1
	call_deferred("_spawn_queued_enemy_instance", enemy_type, spawn_position, health_multiplier, reserved_cost)


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


func notify_enemy_removed(enemy_type: String) -> void:
	_release_shooter_reservation(_shooter_cost(enemy_type))


func get_active_shooter_budget() -> int:
	return _active_shooter_budget


func get_active_spawn_model() -> String:
	return _spawn_model


func get_spawn_event_log() -> Array:
	return _spawn_event_log.duplicate(true)


func _continuous_spawn(room_elapsed: float) -> void:
	if room_elapsed >= _room_duration:
		if _spawn_model == "pulsed" and _pulse_accumulated > 0:
			_schedule_pulse(room_elapsed)
		_spawning_done = true
		return
	var flags := _get_minor_modifier_flags()
	var health_multiplier := 0.5 if bool(flags.get("swarm", false)) else 1.0
	if room_elapsed >= _next_spawn_at:
		var current_interval := _spawn_interval
		var base_ramp := clampf(room_elapsed / BASE_RAMP_DURATION, 0.0, 1.0)
		current_interval = lerpf(_spawn_interval, _spawn_interval * 0.55, base_ramp)
		current_interval *= _get_density_interval_multiplier()
		if bool(flags.get("accelerating_waves", false)):
			var ramp := clampf(room_elapsed / min(_room_duration, 25.0), 0.0, 1.0)
			current_interval = lerpf(current_interval, current_interval * 0.6, ramp)
		_next_spawn_at = room_elapsed + current_interval
		var batch := _consume_scaled_stream_count(2 if bool(flags.get("swarm", false)) else 1)
		if _spawn_model == "pulsed":
			_pulse_accumulated += batch
		else:
			_spawn_trickle_batch(batch, health_multiplier)
	if _spawn_model == "pulsed" and room_elapsed >= _next_pulse_at:
		while room_elapsed >= _next_pulse_at:
			_next_pulse_at += PULSE_PERIOD
		_schedule_pulse(room_elapsed)
	if room_elapsed >= _next_burst_at:
		_next_burst_at = room_elapsed + _burst_interval
		var burst_size := _get_burst_size(false)
		if bool(flags.get("swarm", false)):
			burst_size *= 2
		burst_size = _scale_spawn_count(burst_size)
		var burst_start_edge := _randi_mod(4)
		for index in range(burst_size):
			if _obstacle_enemy_cap_reached():
				break
			var enemy_type := _pick_spawn_type(_get_spawn_source())
			var reserved_cost := _shooter_cost(enemy_type)
			var spawn_position := _get_enemy_spawn_position_for_index(index, burst_start_edge)
			_queue_logged_enemy_spawn(enemy_type, spawn_position, health_multiplier, reserved_cost)
			_enemies_spawned += 1


func _spawn_trickle_batch(batch: int, health_multiplier: float) -> void:
	var stream_start_edge := _randi_mod(4) if batch > 1 else 0
	for index in range(batch):
		if _obstacle_enemy_cap_reached():
			break
		var enemy_type := _pick_spawn_type(_get_spawn_source())
		var reserved_cost := _shooter_cost(enemy_type)
		var spawn_position := _get_enemy_spawn_position() if batch == 1 else _get_enemy_spawn_position_for_index(index, stream_start_edge)
		_queue_logged_enemy_spawn(enemy_type, spawn_position, health_multiplier, reserved_cost)
		_enemies_spawned += 1


func _schedule_pulse(room_elapsed: float) -> void:
	var count := _pulse_accumulated
	_pulse_accumulated = 0
	if count <= 0:
		return
	var edges: Array[int] = [_randi_mod(4)]
	if count > 1 and PULSE_EDGES > 1:
		var second_edge := _randi_mod(4)
		while second_edge == edges[0]:
			second_edge = _randi_mod(4)
		edges.append(second_edge)
	for index in range(count):
		var ratio := float(index) / float(maxi(count - 1, 1))
		_pending_pulse_spawns.append({
			"spawn_at": room_elapsed + PULSE_SPREAD * ratio,
			"edge": edges[index % edges.size()],
		})


func _process_pending_pulse_spawns(room_elapsed: float) -> void:
	if _pending_pulse_spawns.is_empty():
		return
	var flags := _get_minor_modifier_flags()
	var health_multiplier := 0.5 if bool(flags.get("swarm", false)) else 1.0
	var remaining: Array = []
	for entry_variant in _pending_pulse_spawns:
		var entry := entry_variant as Dictionary
		if room_elapsed + 0.0001 < float(entry.get("spawn_at", room_elapsed)):
			remaining.append(entry)
			continue
		if _obstacle_enemy_cap_reached():
			continue
		var enemy_type := _pick_spawn_type(_get_spawn_source())
		var reserved_cost := _shooter_cost(enemy_type)
		var spawn_position := ArenaGeometry.enemy_spawn_position_for_edge(
			int(entry.get("edge", 0)),
			ARENA_MARGIN + 48.0,
			ARENA_SIZE,
			_position_rng()
		)
		_queue_logged_enemy_spawn(enemy_type, spawn_position, health_multiplier, reserved_cost)
		_enemies_spawned += 1
	_pending_pulse_spawns = remaining


func _queue_logged_enemy_spawn(enemy_type: String, spawn_position: Vector2, health_multiplier: float, reserved_cost: int) -> void:
	_spawn_event_log.append({
		"time": float(_coop.call("get_room_elapsed")) if _coop != null else 0.0,
		"type": enemy_type,
		"position": spawn_position,
	})
	queue_enemy_spawn(enemy_type, spawn_position, health_multiplier, reserved_cost)


func _spawn_queued_enemy_instance(enemy_type: String, spawn_position: Vector2, health_multiplier: float, reserved_cost: int = 0) -> void:
	_pending_enemy_spawns = max(_pending_enemy_spawns - 1, 0)
	if _coop == null or bool(_coop.call("is_room_clear_started")) or not is_inside_tree():
		_release_shooter_reservation(reserved_cost)
		return
	var enemy := spawn_enemy_instance(enemy_type, spawn_position, health_multiplier)
	if enemy == null:
		_release_shooter_reservation(reserved_cost)


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
	return str(pool[_randi_mod(pool.size())])


func _pick_spawn_type(source) -> String:
	var rolled_type := "chaser"
	if source is Dictionary:
		rolled_type = _roll_composition_enemy_type(source as Dictionary)
	elif source is Array:
		rolled_type = _roll_wave_enemy_type(source as Array)
	var cost := _shooter_cost(rolled_type)
	if cost <= 0:
		return rolled_type
	if _active_shooter_budget + cost > _shooter_budget():
		return _roll_melee_type(source)
	_active_shooter_budget += cost
	return rolled_type


func _get_spawn_source():
	if not _room_composition.is_empty():
		return _room_composition
	return _room_enemy_pool


func _roll_composition_enemy_type(composition: Dictionary) -> String:
	var shooters: Array = (composition.get("shooters", []) as Array)
	var melee_bias: Array = (composition.get("melee_bias", []) as Array)
	var shooter_ratio := clampf(float(composition.get("shooter_ratio", 0.0)), 0.0, 1.0)
	if not shooters.is_empty() and _randf() < shooter_ratio:
		return str(shooters[_randi_mod(shooters.size())])
	if not melee_bias.is_empty():
		return str(melee_bias[_randi_mod(melee_bias.size())])
	return "chaser"


func _roll_melee_type(source) -> String:
	var melee_pool: Array = []
	if source is Dictionary:
		melee_pool = ((source as Dictionary).get("melee_bias", []) as Array).duplicate()
	elif source is Array:
		for enemy_variant in (source as Array):
			var enemy_type := str(enemy_variant)
			if _shooter_cost(enemy_type) <= 0 and not EnemyTypes.is_champion(enemy_type):
				melee_pool.append(enemy_type)
	var filtered: Array = []
	for enemy_variant in melee_pool:
		var enemy_type := str(enemy_variant)
		if _shooter_cost(enemy_type) <= 0 and not EnemyTypes.is_champion(enemy_type):
			filtered.append(enemy_type)
	if filtered.is_empty():
		return "chaser"
	return str(filtered[_randi_mod(filtered.size())])


func _shooter_cost(enemy_type: String) -> int:
	return int(SHOOTER_COST.get(enemy_type, 0))


func _shooter_budget() -> int:
	var player_count := int(_coop.call("get_player_count")) if _coop != null else 1
	return SHOOTER_BUDGET_BASE + 2 * maxi(player_count - 1, 0)


func _release_shooter_reservation(cost: int) -> void:
	if cost <= 0:
		return
	_active_shooter_budget = maxi(_active_shooter_budget - cost, 0)


func _is_profiling_no_spawn() -> bool:
	return bool(_room_config.get("profiling", false))


func _obstacle_enemy_cap_reached() -> bool:
	# Only caps rooms with physical cover (Batch-B WHERE). Open/hazard rooms have no obstacles and stay uncapped.
	if _coop == null or not bool(_coop.call("has_flow_obstacles")):
		return false
	var live := int(_coop.call("get_live_enemy_count"))
	return live + _pending_enemy_spawns >= MAX_OBSTACLE_ENEMIES


func profiling_reset_shooter_budget() -> void:
	_active_shooter_budget = 0


func profiling_pick_spawn_type(source) -> String:
	return _pick_spawn_type(source)


func profiling_cancel_reserved_spawn(enemy_type: String) -> void:
	_release_shooter_reservation(_shooter_cost(enemy_type))


func _get_enemy_count_multiplier() -> float:
	var player_mult := 1.5 if int(_coop.call("get_player_count")) >= 2 else 1.0
	var progress := RunState.get_run_progress()
	var density_mult := lerpf(1.0, 1.4, clampf(progress, 0.0, 1.0)) + maxf(progress - 1.0, 0.0) * 0.12
	return player_mult * density_mult * _get_density_count_multiplier()


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
	var base := lerpf(0.90, 0.40, arc_progress) - continuation * 0.12
	return maxf(base, 0.30)

func _get_density_count_multiplier() -> float:
	match str(_room_config.get("density_profile", "normal")):
		"high":
			return 1.25
		"low":
			return 0.75
		_:
			return 1.0

func _get_density_interval_multiplier() -> float:
	match str(_room_config.get("density_profile", "normal")):
		"high":
			return 0.85
		"low":
			return 1.2
		_:
			return 1.0


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
	var base := lerpf(4.0 if is_opening else 3.0, 9.0 if is_opening else 10.0, arc_progress)
	var continuation_bonus := continuation * (3.0 if is_opening else 5.0)
	return maxi(1, int(round(base + continuation_bonus)))


func _get_champion_spawn_position() -> Vector2:
	return ArenaGeometry.champion_spawn_position(ARENA_CENTER)


func _get_enemy_spawn_position() -> Vector2:
	var inner_margin := ARENA_MARGIN + 48.0
	var edge := _randi_mod(4)
	return ArenaGeometry.enemy_spawn_position_for_edge(edge, inner_margin, ARENA_SIZE, _position_rng())


func _get_enemy_spawn_position_for_index(spawn_index: int, start_edge: int) -> Vector2:
	var inner_margin := ARENA_MARGIN + 48.0
	return ArenaGeometry.enemy_spawn_position_for_index(spawn_index, start_edge, inner_margin, ARENA_SIZE, _position_rng())


func _position_rng() -> RandomNumberGenerator:
	return _spawn_rng


func _randf() -> float:
	return _spawn_rng.randf() if _spawn_rng != null else randf()


func _randi_mod(modulus: int) -> int:
	if modulus <= 0:
		return 0
	return int((_spawn_rng.randi() if _spawn_rng != null else randi()) % modulus)


func _derived_spawn_seed() -> int:
	var explicit_seed := int(_room_config.get("where_seed", 0))
	if explicit_seed != 0:
		return explicit_seed
	return 20260719 + _room_depth * 7919 + str(_room_config.get("archetype_id", _room_type)).hash()


func _get_minor_modifier_flags() -> Dictionary:
	return _coop.call("get_minor_modifier_flags") as Dictionary
