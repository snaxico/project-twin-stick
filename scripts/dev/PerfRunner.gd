extends Node
## Automated, reusable performance runner. NOT part of normal runtime.
##
## Launch unattended from the command line and read the CSV from stdout:
##   Godot_v4.6.2-stable_win64_console.exe --path D:\GameDev\Project_Twin_stick -- --profile=champion:pulsar
##
## Scenarios (the `--profile=` value):
##   entity_ramp        -> the isolated 50..200 ramp harness (scenes/dev/ProfilingHarness.tscn)
##   flowfield_stress   -> the isolated ramp harness with obstacle blocks + FlowField sampling
##   champion:<id>      -> a REAL champion-in-wave room via the debug single-room path
##   room:<room_type>   -> a REAL single room (combat|boss) using real CoopManager spawning
##   where:<id>         -> a REAL profiling room with one WHERE mechanic and deterministic injected enemies
##   shooter_budget     -> focused WaveDirector shooter-budget smoke
##
## Real-room scenarios use the actual game systems, so the numbers reflect real load.
## RunState.debug_profiling makes players immortal so the fight runs the full window.
## Registered as an autoload; inert unless `--profile=` is present.

const RUN_FLOW_SCENE := preload("res://scenes/ui/RunFlow.tscn")
const PlayerConfigData := preload("res://scripts/player/PlayerConfig.gd")

const WARMUP_SECONDS := 4.0
const SAMPLE_SECONDS := 10.0
const PROFILING_SEED := 20260707

func _ready() -> void:
	var scenario := _read_arg("--profile=", "")
	if scenario.is_empty():
		return
	var players := clampi(int(_read_arg("--players=", "1")), 1, 2)
	var build := _read_arg("--build=", "base")
	var smoke := OS.get_cmdline_user_args().has("--smoke")
	call_deferred("_run", scenario, players, build, smoke)

func run_from_menu(scenario: String, players: int, build: String) -> void:
	call_deferred("_run", scenario, clampi(players, 1, 2), build, false)

func _read_arg(prefix: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length()).strip_edges()
	return fallback

func _run(scenario: String, players: int, build: String, smoke: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if scenario == "entity_ramp" or scenario == "flowfield_stress":
		get_tree().change_scene_to_file("res://scenes/dev/ProfilingHarness.tscn")
		return

	var room_type := "combat"
	var champion_type := ""
	var where_id := ""
	var profiling_room := false
	if scenario.begins_with("champion:"):
		room_type = "boss"
		champion_type = scenario.substr("champion:".length())
	elif scenario.begins_with("room:"):
		room_type = scenario.substr("room:".length())
		if room_type == "boss":
			champion_type = "warden"
	elif scenario.begins_with("where:"):
		room_type = "combat"
		where_id = scenario.substr("where:".length())
		profiling_room = true
	elif scenario == "shooter_budget":
		room_type = "combat"
		profiling_room = true
	else:
		push_error("PerfRunner: unknown scenario '%s'" % scenario)
		get_tree().quit(1)
		return

	RunState.debug_profiling = true
	var tints := [Color(0.25, 1.0, 0.3, 1.0), Color(0.3, 0.7, 1.0, 1.0)]
	var configs := []
	var abilities := []
	for i in range(players):
		configs.append(PlayerConfigData.new(i + 1, "hybrid", tints[i % tints.size()]))
		abilities.append(["overcharge", "dash"])
	var options := {
		"enabled": true,
		"launch_mode": "single_room",
		"room_type": room_type,
		"room_objective": "kill_all",
		"enemy_mix": "mixed",
		"starting_mutations": [],
		"player_abilities": abilities,
	}
	if profiling_room:
		options["where"] = where_id
		options["where_variant"] = clampi(int(_read_arg("--variant=", "0")), 0, 2)
		options["where_seed"] = PROFILING_SEED
		options["profiling"] = true
		options["side_objective"] = ""
		options["composition"] = {
			"melee_density": "medium",
			"melee_bias": ["chaser", "charger", "splitter", "bomber"],
			"shooters": ["spitter"],
			"shooter_ratio": 0.2,
		}
	if room_type == "boss":
		options["boss_type"] = champion_type
		options["boss_spawn_delay"] = 1.0
	RunState.start_new_run(configs, options)

	# Heavy build: worst-case projectile + burning-pool load from auto-fire (no input needed).
	if build == "heavy":
		for i in range(players):
			var inv = RunState.get_player_inventory(i)
			if inv != null:
				inv.weapon_id = "scattergun"
				inv.weapon_level = 5
				inv.mutations.append_array(["piercing_rounds", "ricochet", "fire_trail"])

	get_tree().change_scene_to_packed(RUN_FLOW_SCENE)

	var profiler := _Profiler.new()
	profiler.scenario = "%s players=%d build=%s" % [scenario, players, build]
	profiler.raw_scenario = scenario
	profiler.smoke = smoke
	profiler.where_id = where_id
	profiler.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(profiler)

class _Profiler extends Node:
	var scenario := ""
	var raw_scenario := ""
	var smoke := false
	var where_id := ""
	var _elapsed := 0.0
	var _frames := 0
	var _fps_sum := 0.0
	var _fps_min := INF
	var _proc_sum := 0.0
	var _phys_sum := 0.0
	var _draw_sum := 0.0
	var _node_sum := 0.0
	var _frame_ms_max := 0.0
	var _worst_frames: Array = []
	var _sampling_started := false
	var _coop: Node = null
	var _load_ready := false
	var _smoke_ran := false
	var _smoke_passed := true
	var _next_forced_step_at := 0.0

	func _ready() -> void:
		print("=== PERF RUNNER: %s (warmup %.0fs, sample %.0fs, vsync off) ===" % [scenario, WARMUP_SECONDS, SAMPLE_SECONDS])

	func _process(delta: float) -> void:
		_elapsed += delta
		_ensure_profile_setup()
		if _elapsed < WARMUP_SECONDS:
			return
		if not _sampling_started:
			_sampling_started = true
			return
		var fps := Performance.get_monitor(Performance.TIME_FPS)
		var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		var frame_ms := delta * 1000.0
		_fps_sum += fps
		_fps_min = minf(_fps_min, fps)
		_proc_sum += process_ms
		_phys_sum += physics_ms
		_draw_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_node_sum += Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		_frame_ms_max = maxf(_frame_ms_max, frame_ms)
		_record_worst_frame(_elapsed, frame_ms)
		_frames += 1
		if _elapsed >= WARMUP_SECONDS + SAMPLE_SECONDS:
			_emit_and_quit()

	func _emit_and_quit() -> void:
		var f := float(max(_frames, 1))
		print("worst_frame_rank,time_s,frame_ms")
		_worst_frames.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("frame_ms", 0.0)) > float(b.get("frame_ms", 0.0))
		)
		for index in range(mini(_worst_frames.size(), 10)):
			var entry: Dictionary = _worst_frames[index] as Dictionary
			print("%d,%.3f,%.3f" % [index + 1, float(entry.get("time", 0.0)), float(entry.get("frame_ms", 0.0))])
		print("scenario,avg_fps,min_fps,max_frame_ms,process_ms,physics_ms,draw_calls,nodes")
		print("%s,%.1f,%.1f,%.3f,%.3f,%.3f,%.0f,%.0f" % [
			scenario, _fps_sum / f, _fps_min, _frame_ms_max, _proc_sum / f, _phys_sum / f, _draw_sum / f, _node_sum / f,
		])
		print("=== PERF RUNNER DONE ===")
		var avg_fps := _fps_sum / f
		get_tree().quit(1 if (not _smoke_passed or avg_fps < 60.0) else 0)

	func _ensure_profile_setup() -> void:
		if _coop == null:
			_coop = _find_coop(get_tree().root)
		if _coop == null:
			return
		if raw_scenario == "shooter_budget" and smoke and not _smoke_ran:
			_smoke_ran = true
			_smoke_passed = bool(_coop.call("profiling_run_shooter_budget_smoke"))
			if not _smoke_passed:
				push_error("PerfRunner: shooter_budget smoke failed")
				get_tree().quit(1)
			return
		if not raw_scenario.begins_with("where:"):
			return
		if not _load_ready:
			_load_ready = bool(_coop.call("profiling_inject", PROFILING_SEED, 200))
			if not _load_ready:
				return
		if smoke and not _smoke_ran:
			_smoke_ran = true
			_smoke_passed = _run_where_smoke()
			if not _smoke_passed:
				push_error("PerfRunner: where smoke failed for %s" % where_id)
				get_tree().quit(1)
			else:
				print("where_smoke=%s variant=%d passed" % [where_id, int(RunState.current_node.get("where_variant", 0))])
				get_tree().quit(0)
			return
		if where_id == "drifting_cover":
			if _elapsed >= _next_forced_step_at:
				_next_forced_step_at = _elapsed + 2.0
				_coop.call("profiling_force_where_step")

	func _run_where_smoke() -> bool:
		if int(_coop.call("profiling_registered_enemy_count")) != 200:
			return false
		if not bool(_coop.call("profiling_cover_blocks_projectile")):
			return false
		if where_id == "drifting_cover" or where_id == "popup_pillars":
			var before := int(_coop.call("profiling_where_revision"))
			if not bool(_coop.call("profiling_force_where_step")):
				return false
			var after := int(_coop.call("profiling_where_revision"))
			if after <= before:
				return false
			if not bool(_coop.call("profiling_all_enemies_reachable")):
				return false
		return true

	func _find_coop(node: Node) -> Node:
		if node != null and node.has_method("profiling_inject"):
			return node
		for child in node.get_children():
			var found := _find_coop(child)
			if found != null:
				return found
		return null

	func _record_worst_frame(time_s: float, frame_ms: float) -> void:
		_worst_frames.append({"time": time_s, "frame_ms": frame_ms})
		_worst_frames.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("frame_ms", 0.0)) > float(b.get("frame_ms", 0.0))
		)
		if _worst_frames.size() > 10:
			_worst_frames.resize(10)
