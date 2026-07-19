extends Node
## Headless acceptance checks for the v4 feel-polish spawn prototype.
##
## Run with:
##   godot --headless --path <project> res://scenes/dev/FeelPolishAcceptance.tscn

const WaveDirectorScript := preload("res://scripts/game/WaveDirector.gd")
const TEST_SEED := 424242
const STEP_SECONDS := 0.05
const END_SECONDS := 48.0


class FakeCoop extends Node:
	var elapsed := 0.0

	func is_room_clear_started() -> bool:
		return false

	func get_room_elapsed() -> float:
		return elapsed

	func is_enemy_list_empty() -> bool:
		return false

	func handle_wave_room_clear() -> void:
		pass

	func get_minor_modifier_flags() -> Dictionary:
		return {}

	func get_player_count() -> int:
		return 1

	func has_flow_obstacles() -> bool:
		return false

	func get_live_enemy_count() -> int:
		return 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_cmdline_user_args().has("--profile-sandbox-smoke"):
		_run_profile_sandbox_smoke()
		return
	var trickle_first := _simulate("trickle")
	var trickle_second := _simulate("trickle")
	var pulsed_first := _simulate("pulsed")
	var pulsed_second := _simulate("pulsed")

	var failures: Array[String] = []
	if trickle_first.size() != pulsed_first.size():
		failures.append(
			"uncapped totals differ: trickle=%d pulsed=%d"
			% [trickle_first.size(), pulsed_first.size()]
		)
	if trickle_first != trickle_second:
		failures.append("seeded trickle spawn sequence did not reproduce")
	if pulsed_first != pulsed_second:
		failures.append("seeded pulsed spawn sequence did not reproduce")
	_check_builder_config(failures, "horde", "open", 3, 1001, "high")
	_check_builder_config(failures, "gauntlet", "bastion", 6, 1002, "low")
	_check_builder_config(failures, "mixed", "fire_grid", 8, 1003, "medium")
	_check_seeded_spawn_does_not_consume_global_rng(failures)

	if failures.is_empty():
		print(
			"FEEL_POLISH_ACCEPTANCE PASS total=%d trickle_repro=true pulsed_repro=true"
			% trickle_first.size()
		)
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("FEEL_POLISH_ACCEPTANCE: %s" % failure)
	get_tree().quit(1)


func _run_profile_sandbox_smoke() -> void:
	var failures: Array[String] = []
	if not ProfileState.is_sandboxed():
		failures.append("profile sandbox was not active")
	if ProfileState.get_active_save_path() != "user://profile_sandbox.cfg":
		failures.append("profile sandbox path was not selected")
	var expected_score := int(_read_arg("--expect-score=", "0"))
	if ProfileState.banked_score != expected_score:
		failures.append(
			"expected sandbox score %d, got %d"
			% [expected_score, ProfileState.banked_score]
		)
	var add_score := int(_read_arg("--add-score=", "0"))
	if add_score > 0:
		ProfileState.add_score(add_score)
	if failures.is_empty():
		print(
			"PROFILE_SANDBOX_ACCEPTANCE PASS path=%s score=%d"
			% [ProfileState.get_active_save_path(), ProfileState.banked_score]
		)
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("PROFILE_SANDBOX_ACCEPTANCE: %s" % failure)
	get_tree().quit(1)


func _read_arg(prefix: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length()).strip_edges()
	return fallback


func _simulate(model: String) -> Array:
	RunState.start_new_run([], {
		"enabled": true,
		"launch_mode": "single_room",
		"room_type": "combat",
		"step_index": 2,
		"spawn_model": model,
		"debug_spawn_seed": TEST_SEED,
	})
	var coop := FakeCoop.new()
	var director = WaveDirectorScript.new()
	director.setup(coop, null)
	director.start_room({
		"room_type": "combat",
		"archetype_id": "horde",
		"density_profile": "normal",
		"where_seed": TEST_SEED,
		"composition": {
			"melee_density": "medium",
			"melee_bias": ["chaser", "charger", "splitter", "bomber"],
			"shooters": [],
			"shooter_ratio": 0.0,
		},
	}, ["chaser", "charger", "splitter", "bomber"], 3)
	director.spawn_opening_burst()
	var step_count := int(ceil(END_SECONDS / STEP_SECONDS))
	for index in range(step_count + 1):
		coop.elapsed = float(index) * STEP_SECONDS
		director.check_wave_progress()
	var event_log: Array = director.get_spawn_event_log()
	director.free()
	coop.free()
	return event_log


func _check_builder_config(
	failures: Array[String],
	archetype_id: String,
	where_id: String,
	depth: int,
	test_seed: int,
	expected_density: String
) -> void:
	var first := _build_single_room_node(archetype_id, where_id, depth, test_seed)
	var second := _build_single_room_node(archetype_id, where_id, depth, test_seed)
	for key in ["archetype_id", "where", "where_variant", "where_seed", "depth", "density_profile", "composition"]:
		if first.get(key) != second.get(key):
			failures.append("%s builder field '%s' did not reproduce" % [archetype_id, key])
	if str(first.get("archetype_id", "")) != archetype_id:
		failures.append("%s builder archetype was not resolved" % archetype_id)
	if str(first.get("where", "")) != where_id or int(first.get("depth", 0)) != depth:
		failures.append("%s builder WHERE/depth mismatch" % archetype_id)
	if str(first.get("density_profile", "")) != expected_density:
		failures.append("%s builder density profile mismatch" % archetype_id)
	if (first.get("composition", {}) as Dictionary).is_empty():
		failures.append("%s builder composition is empty" % archetype_id)


func _build_single_room_node(
	archetype_id: String,
	where_id: String,
	depth: int,
	test_seed: int
) -> Dictionary:
	RunState.start_new_run([], {
		"enabled": true,
		"launch_mode": "single_room",
		"room_type": "combat",
		"archetype_id": archetype_id,
		"where": where_id,
		"where_variant": 0,
		"where_seed": test_seed,
		"debug_spawn_seed": test_seed,
		"depth": depth,
	})
	var options := RunState.get_current_options()
	return (options[0] as Dictionary).duplicate(true) if not options.is_empty() else {}


func _check_seeded_spawn_does_not_consume_global_rng(failures: Array[String]) -> void:
	RunState.start_new_run([], {
		"enabled": true,
		"launch_mode": "single_room",
		"spawn_model": "trickle",
		"debug_spawn_seed": TEST_SEED,
	})
	var coop := FakeCoop.new()
	var director = WaveDirectorScript.new()
	director.setup(coop, null)
	director.start_room({
		"room_type": "combat",
		"where_seed": TEST_SEED,
		"composition": {
			"melee_bias": ["chaser", "charger"],
			"shooters": [],
			"shooter_ratio": 0.0,
		},
	}, ["chaser", "charger"], 1)
	seed(998877)
	var expected := randi()
	seed(998877)
	director.spawn_opening_burst()
	var actual := randi()
	if actual != expected:
		failures.append("seeded spawning consumed the global RNG")
	director.free()
	coop.free()
