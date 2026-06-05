extends Node
## Automated, reusable performance runner. NOT part of normal runtime.
##
## Launch unattended from the command line and read the CSV from stdout:
##   Godot_v4.6.2-stable_win64_console.exe --path D:\GameDev\Project_Twin_stick -- --profile=boss:pulsar
##
## Scenarios (the `--profile=` value):
##   entity_ramp        -> the isolated 50..200 ramp harness (scenes/dev/ProfilingHarness.tscn)
##   boss:<id>          -> a REAL single boss room via the debug single-room path (warden|hydra|hive|pulsar)
##   room:<room_type>   -> a REAL single room (combat|elite|boss) using real CoopManager spawning
##
## Real-room scenarios use the actual game systems, so the numbers reflect real load.
## RunState.debug_profiling makes players immortal so the fight runs the full window.
## Registered as an autoload; inert unless `--profile=` is present.

const RUN_FLOW_SCENE := preload("res://scenes/ui/RunFlow.tscn")
const PlayerConfigData := preload("res://scripts/player/PlayerConfig.gd")

const WARMUP_SECONDS := 4.0
const SAMPLE_SECONDS := 10.0

func _ready() -> void:
	var scenario := _read_arg("--profile=", "")
	if scenario.is_empty():
		return
	var players := clampi(int(_read_arg("--players=", "1")), 1, 2)
	var build := _read_arg("--build=", "base")
	call_deferred("_run", scenario, players, build)

func _read_arg(prefix: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length()).strip_edges()
	return fallback

func _run(scenario: String, players: int, build: String) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if scenario == "entity_ramp":
		get_tree().change_scene_to_file("res://scenes/dev/ProfilingHarness.tscn")
		return

	var room_type := "combat"
	var boss_type := ""
	if scenario.begins_with("boss:"):
		room_type = "boss"
		boss_type = scenario.substr("boss:".length())
	elif scenario.begins_with("room:"):
		room_type = scenario.substr("room:".length())
		if room_type == "boss":
			boss_type = "warden"
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
		"run_mode": "structured",
		"enabled": true,
		"launch_mode": "single_room",
		"room_type": room_type,
		"room_objective": "kill_all",
		"enemy_mix": "mixed",
		"starting_mutations": [],
		"player_abilities": abilities,
	}
	if room_type == "boss":
		options["boss_type"] = boss_type
	RunState.start_new_run(configs, options)

	# Heavy build: worst-case projectile + burning-pool load from auto-fire (no input needed).
	if build == "heavy":
		for i in range(players):
			var inv = RunState.get_player_inventory(i)
			if inv != null:
				inv.weapon_id = "scattergun"
				inv.weapon_level = 5
				inv.mutations.append_array(["rapid_fire", "rapid_fire", "rapid_fire", "velocity", "fire_trail"])

	get_tree().change_scene_to_packed(RUN_FLOW_SCENE)

	var profiler := _Profiler.new()
	profiler.scenario = "%s players=%d build=%s" % [scenario, players, build]
	profiler.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(profiler)

class _Profiler extends Node:
	var scenario := ""
	var _elapsed := 0.0
	var _frames := 0
	var _fps_sum := 0.0
	var _fps_min := INF
	var _proc_sum := 0.0
	var _phys_sum := 0.0
	var _draw_sum := 0.0
	var _node_sum := 0.0
	var _printed_header := false

	func _ready() -> void:
		print("=== PERF RUNNER: %s (warmup %.0fs, sample %.0fs, vsync off) ===" % [scenario, WARMUP_SECONDS, SAMPLE_SECONDS])

	func _process(delta: float) -> void:
		_elapsed += delta
		if _elapsed < WARMUP_SECONDS:
			return
		var fps := Performance.get_monitor(Performance.TIME_FPS)
		_fps_sum += fps
		_fps_min = minf(_fps_min, fps)
		_proc_sum += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		_phys_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		_draw_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_node_sum += Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		_frames += 1
		if _elapsed >= WARMUP_SECONDS + SAMPLE_SECONDS:
			_emit_and_quit()

	func _emit_and_quit() -> void:
		var f := float(max(_frames, 1))
		print("scenario,avg_fps,min_fps,process_ms,physics_ms,draw_calls,nodes")
		print("%s,%.1f,%.1f,%.3f,%.3f,%.0f,%.0f" % [
			scenario, _fps_sum / f, _fps_min, _proc_sum / f, _phys_sum / f, _draw_sum / f, _node_sum / f,
		])
		print("=== PERF RUNNER DONE ===")
		get_tree().quit()
