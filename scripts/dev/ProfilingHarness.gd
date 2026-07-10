extends Node2D
## Phase-1 performance profiling harness. NOT part of the game runtime.
## Spawns enemies + projectiles like the game does, ramps the count in steps,
## samples Godot's Performance monitors, prints a CSV, then quits.
## KEEP committed as dev tooling — needed to re-measure after each perf change (through the
## MultiMesh phase) and for future profiling. Inert (not in the main scene, no game coupling).
## Remove only once ALL performance work is finished, if desired. See playtest-round-6-plan.md.

const EnemyScene := preload("res://scenes/enemies/Enemy.tscn")
const ProjectileScene := preload("res://scenes/weapons/Projectile.tscn")
const ProjectileRendererData := preload("res://scripts/weapons/ProjectileRenderer.gd")
const MineFieldModifierScene := preload("res://scripts/modifiers/MineFieldModifier.gd")
const FlowFieldData := preload("res://scripts/game/FlowField.gd")

const ARENA_SIZE := Vector2(4800.0, 2700.0)
const ARENA_CENTER := Vector2(2400.0, 1350.0)
const ARENA_RECT := Rect2(Vector2.ZERO, Vector2(4800.0, 2700.0))
const ENEMY_TYPES := ["chaser", "charger", "spitter", "splitter", "bomber"]

# Each step holds this many enemies AND this many projectiles for SAMPLE_SECONDS.
const STEPS := [50, 100, 150, 200]
const SAMPLE_SECONDS := 5.0
const WARMUP_SECONDS := 2.5
const FLOW_TARGET_UPDATE_INTERVAL := 0.12
# Include the sweep ("Scanline", formerly Mine Field) modifier. Set false for a
# clean entity-only baseline.
const INCLUDE_MINEFIELD := false
const FLOWFIELD_OBSTACLES := [
	Rect2(Vector2(1380.0, 760.0), Vector2(120.0, 430.0)),
	Rect2(Vector2(1500.0, 1070.0), Vector2(440.0, 120.0)),
	Rect2(Vector2(2900.0, 1480.0), Vector2(520.0, 120.0)),
	Rect2(Vector2(3340.0, 760.0), Vector2(120.0, 400.0)),
]

var _enemies_container: Node2D
var _projectiles_container: Node2D
var _obstacles_container: Node2D
var _projectile_renderer = null
var _flow_field = null
var _flowfield_profile := false
var _targets: Array = []
var _enemies: Array = []

var _step_index := -1            # -1 = warmup before first step
var _phase_elapsed := 0.0
var _fps_sum := 0.0
var _proc_sum := 0.0
var _phys_sum := 0.0
var _draw_sum := 0.0
var _node_sum := 0.0
var _frames := 0
var _target_phase := 0.0
var _flow_target_update_elapsed := 0.0

func _ready() -> void:
	randomize()
	_flowfield_profile = _is_flowfield_profile()
	# Uncap framerate so FPS reveals the true ceiling (vsync would pin it to ~60 and hide it).
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var cam := Camera2D.new()
	cam.global_position = ARENA_CENTER
	# Window ~1152 wide / arena 4800 -> ~0.24 to keep the whole arena (all entities) on-screen
	# so nothing is culled and draw-call counts reflect worst case.
	cam.zoom = Vector2(0.24, 0.24)
	add_child(cam)
	cam.make_current()
	_enemies_container = Node2D.new()
	add_child(_enemies_container)
	_projectiles_container = Node2D.new()
	add_child(_projectiles_container)
	_obstacles_container = Node2D.new()
	add_child(_obstacles_container)
	_projectile_renderer = ProjectileRendererData.new()
	_projectile_renderer.set_projectile_container(_projectiles_container)
	_projectiles_container.add_child(_projectile_renderer)
	if _flowfield_profile:
		FlowFieldData.profile_enabled = true
		FlowFieldData.profiling_reset()
		_flow_field = FlowFieldData.new()
		_flow_field.setup(ARENA_RECT)
		_spawn_flowfield_obstacles()
	for i in range(2):
		var t := ProfTarget.new()
		t.player_index = i
		t.global_position = ARENA_CENTER + Vector2(randf_range(-500.0, 500.0), randf_range(-300.0, 300.0))
		t.add_to_group("player_target")
		t.add_to_group("player")
		add_child(t)
		_targets.append(t)
	if INCLUDE_MINEFIELD:
		var mf := MineFieldModifierScene.new()
		add_child(mf)
		mf.setup(ARENA_RECT, _targets)
	_update_flowfield_targets()
	print("=== PROFILING HARNESS START (vsync off, minefield=%s, flowfield=%s) ===" % [str(INCLUDE_MINEFIELD), str(_flowfield_profile)])
	print("step,enemy_budget,live_enemies,live_proj,avg_fps,process_ms,physics_ms,draw_calls,nodes")
	if _flowfield_profile:
		print("flowfield_bucket_step,physics_ms,sample_ms,update_targets_ms,dominant")

func _is_flowfield_profile() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == "--flowfield-obstacles" or arg == "--profile=flowfield_stress":
			return true
	return false

func _spawn_flowfield_obstacles() -> void:
	for obstacle_variant in FLOWFIELD_OBSTACLES:
		var obstacle_rect: Rect2 = obstacle_variant as Rect2
		var body := StaticBody2D.new()
		body.name = "ProfileArenaObstacle"
		body.collision_layer = 1
		body.collision_mask = 1
		body.global_position = obstacle_rect.position + obstacle_rect.size * 0.5
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = obstacle_rect.size
		shape.shape = rectangle
		body.add_child(shape)
		var visual := Polygon2D.new()
		var half_size: Vector2 = obstacle_rect.size * 0.5
		visual.polygon = PackedVector2Array([
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y),
		])
		visual.color = Color(0.18, 0.2, 0.24, 0.9)
		body.add_child(visual)
		_obstacles_container.add_child(body)
	_flow_field.build(FLOWFIELD_OBSTACLES)

func _update_flowfield_targets() -> void:
	if _flow_field == null or not _flow_field.has_obstacles():
		return
	var positions: Array = []
	for target in _targets:
		positions.append((target as Node2D).global_position if target != null and is_instance_valid(target) else null)
	_flow_field.update_targets(positions)

# Combat-owner API some enemy behaviors call (the rest are has_method-guarded -> skipped).
func get_player_target_nodes() -> Array:
	return _targets

func get_player_index_for_node(node) -> int:
	if node != null and is_instance_valid(node) and "player_index" in node:
		return int(node.player_index)
	return _targets.find(node)

func get_flow_direction_to_player(world_position: Vector2, target_player_index: int, fallback_dir: Vector2) -> Vector2:
	if _flow_field == null:
		return fallback_dir.normalized() if fallback_dir.length_squared() > 0.0001 else Vector2.ZERO
	return _flow_field.sample(world_position, target_player_index, fallback_dir)

func has_flow_obstacles() -> bool:
	return _flow_field != null and _flow_field.has_obstacles()

func _process(delta: float) -> void:
	_phase_elapsed += delta
	_target_phase += delta
	# Slowly orbit the dummy targets so enemies keep chasing/moving (real move_and_slide load).
	for i in range(_targets.size()):
		var t: Node2D = _targets[i]
		if is_instance_valid(t):
			t.global_position = ARENA_CENTER + Vector2.RIGHT.rotated(_target_phase * 0.6 + float(i) * PI) * 700.0
	_flow_target_update_elapsed += delta
	if _flow_target_update_elapsed >= FLOW_TARGET_UPDATE_INTERVAL:
		_flow_target_update_elapsed = 0.0
		_update_flowfield_targets()

	if _step_index < 0:
		# Warmup: spawn the first step's entities, let things settle before sampling.
		if _step_index == -1:
			_apply_budget(STEPS[0])
			_step_index = 0
			_phase_elapsed = 0.0
			_reset_accumulators()
		return

	_apply_budget(STEPS[_step_index])   # top-up projectiles (they churn) + hold enemies
	if _phase_elapsed < WARMUP_SECONDS:
		return

	# Sampling window.
	_fps_sum += Performance.get_monitor(Performance.TIME_FPS)
	_proc_sum += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_phys_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_draw_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_node_sum += Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	_frames += 1

	if _phase_elapsed >= WARMUP_SECONDS + SAMPLE_SECONDS:
		_emit_row()
		_step_index += 1
		if _step_index >= STEPS.size():
			print("=== PROFILING HARNESS DONE ===")
			get_tree().quit()
			return
		_apply_budget(STEPS[_step_index])
		_phase_elapsed = 0.0
		_reset_accumulators()

func _emit_row() -> void:
	var f := float(max(_frames, 1))
	var live_proj := _count_live(_projectiles_container)
	print("%d,%d,%d,%d,%.1f,%.3f,%.3f,%.0f,%.0f" % [
		_step_index, STEPS[_step_index], _enemies.size(), live_proj,
		_fps_sum / f, _proc_sum / f, _phys_sum / f, _draw_sum / f, _node_sum / f,
	])
	if _flowfield_profile:
		var flow_profile := FlowFieldData.profiling_snapshot()
		var sample_ms := float(flow_profile.get("sample_usec", 0)) / 1000.0 / f
		var update_ms := float(flow_profile.get("update_usec", 0)) / 1000.0 / f
		var physics_ms := _phys_sum / f
		var dominant := "physics"
		if sample_ms >= physics_ms and sample_ms >= update_ms:
			dominant = "sample"
		elif update_ms >= physics_ms and update_ms >= sample_ms:
			dominant = "update_targets"
		print("%d,%.3f,%.3f,%.3f,%s" % [_step_index, physics_ms, sample_ms, update_ms, dominant])

func _reset_accumulators() -> void:
	_fps_sum = 0.0; _proc_sum = 0.0; _phys_sum = 0.0; _draw_sum = 0.0; _node_sum = 0.0; _frames = 0
	if _flowfield_profile:
		FlowFieldData.profiling_reset()

func _apply_budget(budget: int) -> void:
	_prune_dead()
	while _enemies.size() < budget:
		_spawn_enemy()
	var live_proj := _count_live(_projectiles_container)
	for _i in range(budget - live_proj):
		_spawn_projectile()

func _spawn_enemy() -> void:
	var e := EnemyScene.instantiate()
	_enemies_container.add_child(e)
	var spawn_position := ARENA_CENTER + Vector2(randf_range(-2100.0, 2100.0), randf_range(-1150.0, 1150.0))
	if _flow_field != null and _flow_field.has_obstacles():
		spawn_position = _flow_field.nearest_passable_position(spawn_position)
	e.global_position = spawn_position
	e.setup(ENEMY_TYPES[randi() % ENEMY_TYPES.size()], self)
	e.fire_requested.connect(func(_a, _b, _c, _d, _e, _f, _g): pass)
	e.enemy_died.connect(func(_n): pass)
	e.hit_received.connect(func(_n, _a, _l): pass)
	_enemies.append(e)

func _spawn_projectile() -> void:
	var p := ProjectileScene.instantiate()
	_projectiles_container.add_child(p)
	p.impact_requested.connect(func(_a, _b, _c, _d, _e, _f, _g, _h): pass)
	var dir := Vector2.RIGHT.rotated(randf() * TAU)
	var pos := ARENA_CENTER + Vector2(randf_range(-2100.0, 2100.0), randf_range(-1150.0, 1150.0))
	p.activate_from_config("player", dir, {
		"speed": 650.0,
		"damage": 16,
		"color": Color(1.0, 0.96, 0.7),
		"feedback_profile": "rifle",
		"impact_weight": 1.0,
		"collision_half_width": 6.0,
		"max_distance": 5000.0,
		"use_lifetime": true,
	}, pos)

func _prune_dead() -> void:
	var kept: Array = []
	for e in _enemies:
		if is_instance_valid(e):
			kept.append(e)
	_enemies = kept

func _count_live(container: Node) -> int:
	var n := 0
	for c in container.get_children():
		if is_instance_valid(c) and c.has_method("is_projectile_active") and c.is_projectile_active():
			n += 1
	return n

class ProfTarget extends Node2D:
	var player_index := 0
	func is_alive() -> bool: return true
	func is_targetable() -> bool: return true
	func get_team() -> String: return "player"
	func apply_damage(_amount: int) -> void: pass
