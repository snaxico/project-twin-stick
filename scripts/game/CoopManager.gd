extends Node2D

const EnemySceneData = preload("res://scenes/enemies/Enemy.tscn")
const ProjectileSceneData = preload("res://scenes/weapons/Projectile.tscn")
const PlayerInventoryHUDData = preload("res://scripts/ui/PlayerInventoryHUD.gd")
const MutationSystemData = preload("res://scripts/game/MutationSystem.gd")
const MutationPickUIScene = preload("res://scenes/ui/MutationPickUI.tscn")
const CaptureHillZoneData = preload("res://scripts/game/CaptureHillZone.gd")
const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")

const ARENA_SIZE := Vector2(4800.0, 2700.0)
const ARENA_RECT := Rect2(Vector2.ZERO, ARENA_SIZE)
const ARENA_CENTER := Vector2(ARENA_SIZE.x * 0.5, ARENA_SIZE.y * 0.5)
const ARENA_MARGIN := 72.0
const FLOOR_GRID_SPACING := 160.0
const FLOOR_GRID_MAJOR_INTERVAL := 4
const ARENA_WALL_VISUAL_WIDTH := 18.0
const EXIT_ZONE_SIZE := Vector2(360.0, 140.0)
const EXIT_HOLD_DURATION := 0.8
const REVIVE_RADIUS := 96.0
const REVIVE_HOLD_DURATION := 1.2
const SURVIVE_DURATION := 60.0

@export var player_scene: PackedScene

signal room_cleared(health_states, clear_context)
signal all_players_dead
signal player_downed(player)
signal player_revived(player)
signal return_to_menu_requested

@onready var players: Node2D = $Players
@onready var projectiles: Node2D = $Projectiles
@onready var enemies: Node2D = $Enemies
@onready var effects: Node2D = $Effects
@onready var exit_zone: Area2D = $ExitZone
@onready var exit_zone_shape: CollisionShape2D = $ExitZone/CollisionShape2D
@onready var exit_zone_visual: Polygon2D = $ExitZone/Visual
@onready var floor_visual: Polygon2D = $Floor
@onready var floor_grid: Node2D = $FloorGrid
@onready var camera: Camera2D = $Camera2D
@onready var screen_shake = $Camera2D/ScreenShake
@onready var screen_effects = $ScreenEffects
@onready var top_wall: CollisionShape2D = $ArenaBounds/TopWall
@onready var bottom_wall: CollisionShape2D = $ArenaBounds/BottomWall
@onready var left_wall: CollisionShape2D = $ArenaBounds/LeftWall
@onready var right_wall: CollisionShape2D = $ArenaBounds/RightWall
@onready var ui_layer: CanvasLayer = $UI
@onready var result_panel: Panel = $UI/ResultPanel
@onready var result_title_label: Label = $UI/ResultPanel/MarginContainer/ResultLayout/ResultTitle
@onready var result_detail_label: Label = $UI/ResultPanel/MarginContainer/ResultLayout/ResultDetail
@onready var retry_button: Button = $UI/ResultPanel/MarginContainer/ResultLayout/RetryButton
@onready var pause_panel: Panel = $UI/PausePanel
@onready var resume_button: Button = $UI/PausePanel/MarginContainer/PauseLayout/ResumeButton
@onready var pause_settings_button: Button = $UI/PausePanel/MarginContainer/PauseLayout/PauseSettingsButton
@onready var pause_retry_button: Button = $UI/PausePanel/MarginContainer/PauseLayout/PauseRetryButton
@onready var pause_main_menu_button: Button = $UI/PausePanel/MarginContainer/PauseLayout/PauseMainMenuButton
@onready var settings_panel: Panel = $UI/SettingsPanel
@onready var settings_screen_effect_row: HBoxContainer = $UI/SettingsPanel/MarginContainer/SettingsLayout/ScreenEffectsRow
@onready var settings_screen_effect_option: OptionButton = $UI/SettingsPanel/MarginContainer/SettingsLayout/ScreenEffectsRow/ScreenEffectsOption
@onready var settings_player_1_row: HBoxContainer = $UI/SettingsPanel/MarginContainer/SettingsLayout/Player1AimRow
@onready var settings_player_1_option: OptionButton = $UI/SettingsPanel/MarginContainer/SettingsLayout/Player1AimRow/Player1AimOption
@onready var settings_player_2_row: HBoxContainer = $UI/SettingsPanel/MarginContainer/SettingsLayout/Player2AimRow
@onready var settings_player_2_option: OptionButton = $UI/SettingsPanel/MarginContainer/SettingsLayout/Player2AimRow/Player2AimOption
@onready var settings_player_3_row: HBoxContainer = $UI/SettingsPanel/MarginContainer/SettingsLayout/Player3AimRow
@onready var settings_player_4_row: HBoxContainer = $UI/SettingsPanel/MarginContainer/SettingsLayout/Player4AimRow
@onready var settings_back_button: Button = $UI/SettingsPanel/MarginContainer/SettingsLayout/SettingsBackButton

var _player_configs: Array = []
var _player_nodes: Array = []
var _enemy_nodes: Array = []
var _compiled_loadouts: Array = []
var _mutation_system = MutationSystemData.new()
var _room_config: Dictionary = {}
var _room_type := "combat"
var _room_objective := "survive"
var _room_enemy_mix := "mixed"
var _room_depth := 1
var _room_clear_started := false
var _room_failed := false
var _exit_zone_open := false
var _awaiting_mutation_pick := false
var _room_timer_remaining := 0.0
var _spawn_cooldown_remaining := 0.0
var _boss_spawned := false
var _capture_hill_zone = null
var _capture_hill_progress := 0.0
var _revive_progress_by_player_id: Dictionary = {}
var _hud_root: Control = null
var _player_inventory_huds: Array = []
var _timer_label: Label = null
var _timer_fill: ColorRect = null
var _mutation_pick_ui = null
var _arena_minor_grid_color := Color(0.32, 0.72, 0.86, 0.24)
var _arena_major_grid_color := Color(0.42, 0.9, 1.0, 0.42)
var _arena_wall_color := Color(0.12, 0.32, 0.38, 0.92)
var _pending_clear_summary := ""

func configure_players(configs: Array) -> void:
	_player_configs = configs.duplicate()

func configure_room(room_config: Dictionary) -> void:
	_room_config = room_config.duplicate(true)

func _ready() -> void:
	if player_scene == null:
		player_scene = load("res://scenes/player/Player.tscn")
	_hide_legacy_ui()
	_bind_ui()
	_rebuild_arena()
	_build_hud()
	_spawn_players()
	_start_room()

func _bind_ui() -> void:
	retry_button.pressed.connect(_on_retry_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	pause_retry_button.pressed.connect(_on_retry_pressed)
	pause_main_menu_button.pressed.connect(_on_main_menu_pressed)

func _hide_legacy_ui() -> void:
	for node_path in [
		"Title",
		"P1Status",
		"P2Status",
		"P3Status",
		"P4Status",
		"P1SecondaryStatus",
		"P2SecondaryStatus",
		"P3SecondaryStatus",
		"P4SecondaryStatus",
		"P1ModeButton",
		"P2ModeButton",
		"ConnectionStatus",
		"RoomStatus",
		"ModifierStatus",
		"ModifierIntroPanel",
	]:
		var node := ui_layer.get_node_or_null(node_path)
		if node != null:
			node.visible = false
	result_panel.visible = false
	pause_panel.visible = false
	pause_settings_button.visible = false
	settings_panel.visible = false
	settings_player_3_row.visible = false
	settings_player_4_row.visible = false

func _build_hud() -> void:
	if _hud_root != null:
		_hud_root.queue_free()
	_hud_root = Control.new()
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(_hud_root)

	var timer_panel := PanelContainer.new()
	timer_panel.position = Vector2(840.0, 24.0)
	timer_panel.size = Vector2(240.0, 52.0)
	_hud_root.add_child(timer_panel)
	var timer_margin := MarginContainer.new()
	timer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	timer_margin.add_theme_constant_override("margin_left", 10)
	timer_margin.add_theme_constant_override("margin_top", 10)
	timer_margin.add_theme_constant_override("margin_right", 10)
	timer_margin.add_theme_constant_override("margin_bottom", 10)
	timer_panel.add_child(timer_margin)
	var timer_layout := VBoxContainer.new()
	timer_layout.add_theme_constant_override("separation", 4)
	timer_margin.add_child(timer_layout)
	_timer_label = Label.new()
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_layout.add_child(_timer_label)
	var timer_track := ColorRect.new()
	timer_track.custom_minimum_size = Vector2(220.0, 10.0)
	timer_track.color = Color(0.08, 0.1, 0.14, 0.64)
	timer_layout.add_child(timer_track)
	_timer_fill = ColorRect.new()
	_timer_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_timer_fill.color = Color(0.28, 0.9, 0.82, 0.74)
	timer_track.add_child(_timer_fill)

	_player_inventory_huds.clear()
	for index in range(_player_configs.size()):
		var hud := PlayerInventoryHUDData.new()
		hud.position = Vector2(24.0, 860.0 + index * 140.0) if index == 0 else Vector2(1676.0, 860.0)
		hud.configure_player("P%d" % (index + 1), _player_configs[index].tint)
		_hud_root.add_child(hud)
		_player_inventory_huds.append(hud)

func _spawn_players() -> void:
	for child in players.get_children():
		child.queue_free()
	_player_nodes.clear()
	var connected_gamepads: Array = Input.get_connected_joypads()
	var gamepad_cursor := 0
	for index in range(_player_configs.size()):
		var player = player_scene.instantiate()
		var assigned_gamepad := -1
		if str(_player_configs[index].control_source) == "gamepad" and gamepad_cursor < connected_gamepads.size():
			assigned_gamepad = int(connected_gamepads[gamepad_cursor])
			gamepad_cursor += 1
		player.player_index = index
		players.add_child(player)
		player.global_position = _get_player_spawn_position(index)
		player.setup(_player_configs[index], assigned_gamepad)
		_clamp_player_to_arena(player)
		player.fire_requested.connect(_on_player_fire_requested)
		player.shockwave_requested.connect(_on_player_shockwave_requested)
		player.downed.connect(_on_player_downed)
		player.revived.connect(_on_player_revived)
		player.damage_taken.connect(_on_player_damage_taken)
		player.muzzle_flash_requested.connect(_on_muzzle_flash_requested)
		player.dash_trail_requested.connect(_on_dash_trail_requested)
		_player_nodes.append(player)
	_rebuild_player_loadouts()
	if camera.has_method("set_players"):
		camera.set_players(_player_nodes)
		camera.global_position = ARENA_CENTER

func _rebuild_player_loadouts() -> void:
	_compiled_loadouts.clear()
	for index in range(_player_nodes.size()):
		var base_loadout: Dictionary = RunState.get_player_runtime_loadout_for(index)
		var compiled_primary := _mutation_system.get_compiled_weapon_stats(index, (base_loadout.get("primary_stats", {}) as Dictionary))
		var secondary_stats := _build_secondary_runtime_stats(index, (base_loadout.get("secondary_stats", {}) as Dictionary))
		var compiled_loadout := {
			"primary_weapon_id": str(base_loadout.get("primary_weapon_id", "rifle")),
			"primary_name": str(base_loadout.get("primary_name", "Rifle")),
			"primary_stats": compiled_primary,
			"secondary_weapon_id": str(base_loadout.get("secondary_weapon_id", "shockwave")),
			"secondary_name": str(base_loadout.get("secondary_name", "Shockwave")),
			"secondary_stats": secondary_stats,
			"mutations": _mutation_system.get_active_mutations(index),
			"move_speed": float(base_loadout.get("move_speed", 390.0)),
			"dash_damage_multiplier": _mutation_system.get_dash_damage_multiplier(index),
		}
		_compiled_loadouts.append(compiled_loadout)
		_player_nodes[index].apply_loadout(compiled_loadout)

func _build_secondary_runtime_stats(player_index: int, base_stats: Dictionary) -> Dictionary:
	var knockback_force := float(base_stats.get("knockback_force", 950.0))
	if _mutation_system.has_mutation(player_index, "knockback"):
		knockback_force += float(_mutation_system.get_mutation_count(player_index, "knockback")) * 60.0
	var cooldown: float = maxf(0.5, float(base_stats.get("cooldown", 8.0)) - _mutation_system.get_shockwave_cooldown_reduction(player_index))
	return {
		"kind": str(base_stats.get("kind", "shockwave")),
		"damage": float(base_stats.get("damage", 30.0)),
		"cooldown": cooldown,
		"radius": float(base_stats.get("radius", 250.0)) * _mutation_system.get_secondary_radius_multiplier(player_index),
		"knockback_force": knockback_force,
		"expand_duration": float(base_stats.get("expand_duration", 0.15)),
	}

func _rebuild_arena() -> void:
	floor_visual.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(ARENA_SIZE.x, 0.0),
		ARENA_SIZE,
		Vector2(0.0, ARENA_SIZE.y),
	])
	_rebuild_floor_grid()
	_apply_collision_bounds_from_floor()
	exit_zone.position = Vector2(ARENA_CENTER.x, ARENA_RECT.end.y - 220.0)
	exit_zone_shape.shape = RectangleShape2D.new()
	(exit_zone_shape.shape as RectangleShape2D).size = EXIT_ZONE_SIZE
	exit_zone_visual.polygon = PackedVector2Array([
		Vector2(-EXIT_ZONE_SIZE.x * 0.5, -EXIT_ZONE_SIZE.y * 0.5),
		Vector2(EXIT_ZONE_SIZE.x * 0.5, -EXIT_ZONE_SIZE.y * 0.5),
		Vector2(EXIT_ZONE_SIZE.x * 0.5, EXIT_ZONE_SIZE.y * 0.5),
		Vector2(-EXIT_ZONE_SIZE.x * 0.5, EXIT_ZONE_SIZE.y * 0.5),
	])
	exit_zone.monitoring = false
	exit_zone_visual.visible = false
	if camera.has_method("set_arena_rect"):
		camera.set_arena_rect(ARENA_RECT)
		camera.global_position = ARENA_CENTER
	if screen_effects != null and screen_effects.has_method("set_effect_level"):
		screen_effects.set_effect_level("full")

func _rebuild_floor_grid() -> void:
	for child in floor_grid.get_children():
		child.queue_free()
	var x := 0.0
	var column_index := 0
	while x <= ARENA_SIZE.x:
		var line := Line2D.new()
		var is_major_line := column_index % FLOOR_GRID_MAJOR_INTERVAL == 0
		line.width = 3.0 if is_major_line else 1.5
		line.default_color = _arena_major_grid_color if is_major_line else _arena_minor_grid_color
		line.points = PackedVector2Array([Vector2(x, 0.0), Vector2(x, ARENA_SIZE.y)])
		floor_grid.add_child(line)
		x += FLOOR_GRID_SPACING
		column_index += 1
	var y := 0.0
	var row_index := 0
	while y <= ARENA_SIZE.y:
		var line := Line2D.new()
		var is_major_line := row_index % FLOOR_GRID_MAJOR_INTERVAL == 0
		line.width = 3.0 if is_major_line else 1.5
		line.default_color = _arena_major_grid_color if is_major_line else _arena_minor_grid_color
		line.points = PackedVector2Array([Vector2(0.0, y), Vector2(ARENA_SIZE.x, y)])
		floor_grid.add_child(line)
		y += FLOOR_GRID_SPACING
		row_index += 1
	_add_arena_wall_visuals()

func _add_arena_wall_visuals() -> void:
	var wall_segments := [
		PackedVector2Array([Vector2(ARENA_MARGIN, ARENA_MARGIN), Vector2(ARENA_RECT.end.x - ARENA_MARGIN, ARENA_MARGIN)]),
		PackedVector2Array([Vector2(ARENA_MARGIN, ARENA_RECT.end.y - ARENA_MARGIN), Vector2(ARENA_RECT.end.x - ARENA_MARGIN, ARENA_RECT.end.y - ARENA_MARGIN)]),
		PackedVector2Array([Vector2(ARENA_MARGIN, ARENA_MARGIN), Vector2(ARENA_MARGIN, ARENA_RECT.end.y - ARENA_MARGIN)]),
		PackedVector2Array([Vector2(ARENA_RECT.end.x - ARENA_MARGIN, ARENA_MARGIN), Vector2(ARENA_RECT.end.x - ARENA_MARGIN, ARENA_RECT.end.y - ARENA_MARGIN)]),
	]
	for segment in wall_segments:
		var wall_line := Line2D.new()
		wall_line.width = ARENA_WALL_VISUAL_WIDTH
		wall_line.default_color = _arena_wall_color
		wall_line.antialiased = true
		wall_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		wall_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		wall_line.points = segment
		floor_grid.add_child(wall_line)

func _apply_arena_color_for_depth(depth: int) -> void:
	var hue := fmod(0.54 + float(max(depth - 1, 0)) * 0.08, 1.0)
	_arena_minor_grid_color = Color.from_hsv(hue, 0.48, 0.92, 0.20)
	_arena_major_grid_color = Color.from_hsv(hue, 0.62, 1.0, 0.42)
	_arena_wall_color = Color.from_hsv(hue, 0.52, 0.56, 0.92)
	if floor_visual != null:
		floor_visual.color = Color.from_hsv(hue, 0.36, 0.12, 1.0)
	_rebuild_floor_grid()

func _apply_collision_bounds_from_floor() -> void:
	_set_wall_rect(top_wall, Vector2(ARENA_CENTER.x, ARENA_MARGIN * 0.5), Vector2(ARENA_SIZE.x - ARENA_MARGIN * 2.0, ARENA_MARGIN))
	_set_wall_rect(bottom_wall, Vector2(ARENA_CENTER.x, ARENA_RECT.end.y - ARENA_MARGIN * 0.5), Vector2(ARENA_SIZE.x - ARENA_MARGIN * 2.0, ARENA_MARGIN))
	_set_wall_rect(left_wall, Vector2(ARENA_MARGIN * 0.5, ARENA_CENTER.y), Vector2(ARENA_MARGIN, ARENA_SIZE.y - ARENA_MARGIN * 2.0))
	_set_wall_rect(right_wall, Vector2(ARENA_RECT.end.x - ARENA_MARGIN * 0.5, ARENA_CENTER.y), Vector2(ARENA_MARGIN, ARENA_SIZE.y - ARENA_MARGIN * 2.0))

func _set_wall_rect(node: CollisionShape2D, position: Vector2, size: Vector2) -> void:
	node.position = position
	if node.shape == null or not (node.shape is RectangleShape2D):
		node.shape = RectangleShape2D.new()
	(node.shape as RectangleShape2D).size = size

func _start_room() -> void:
	_clear_runtime_nodes()
	_room_type = str(_room_config.get("room_type", "combat"))
	if _room_type == "elite":
		_room_type = "combat"
	_room_objective = str(_room_config.get("objective", _room_config.get("room_objective", "survive")))
	_room_enemy_mix = str(_room_config.get("enemy_mix", "mixed"))
	_room_depth = max(int(_room_config.get("depth", _room_config.get("step_index", 1))), 1)
	_apply_arena_color_for_depth(_room_depth)
	_room_clear_started = false
	_room_failed = false
	_exit_zone_open = false
	_awaiting_mutation_pick = false
	_capture_hill_progress = 0.0
	_spawn_cooldown_remaining = 0.15
	_room_timer_remaining = SURVIVE_DURATION
	_boss_spawned = false
	_pending_clear_summary = ""
	result_panel.visible = false
	pause_panel.visible = false
	settings_panel.visible = false
	get_tree().paused = false
	_restore_player_health_states()
	_lock_player_input(false)
	if _room_objective == "capture_the_hill":
		_spawn_capture_hill_zone()
	if _room_type == "boss":
		_spawn_boss()
	elif _room_type == "rest":
		_open_exit_zone()

func _clear_runtime_nodes() -> void:
	for group in [projectiles, enemies, effects]:
		for child in group.get_children():
			child.queue_free()
	_enemy_nodes.clear()
	if _capture_hill_zone != null and is_instance_valid(_capture_hill_zone):
		_capture_hill_zone.queue_free()
	_capture_hill_zone = null
	if _mutation_pick_ui != null and is_instance_valid(_mutation_pick_ui):
		_mutation_pick_ui.queue_free()
	_mutation_pick_ui = null

func _restore_player_health_states() -> void:
	for index in range(min(_player_nodes.size(), RunState.player_health_states.size())):
		_player_nodes[index].global_position = _get_player_spawn_position(index)
		_clamp_player_to_arena(_player_nodes[index])
		_player_nodes[index].set_health_state(RunState.player_health_states[index])
		if _player_nodes[index].is_downed():
			_player_nodes[index].revive(20)

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	_clamp_players_to_arena()
	_update_revives(delta)
	_update_room(delta)
	_update_exit_zone(delta)
	_refresh_hud()

func _update_room(delta: float) -> void:
	if _room_clear_started or _room_failed or _room_type == "rest":
		return
	if _room_type == "boss":
		var boss_alive := false
		if _boss_spawned:
			for enemy in _enemy_nodes:
				if enemy != null and is_instance_valid(enemy):
					boss_alive = true
					break
		if _boss_spawned and not boss_alive:
			_handle_room_clear("Boss defeated.")
		return
	if _room_objective == "capture_the_hill":
		_spawn_cooldown_remaining -= delta
		if _spawn_cooldown_remaining <= 0.0:
			_spawn_enemy_wave()
			_spawn_cooldown_remaining = maxf((0.55 - float(_room_depth) * 0.03) * 0.5, 0.09)
		_update_capture_hill_room(delta)
	else:
		_room_timer_remaining = max(_room_timer_remaining - delta, 0.0)
		if _room_timer_remaining <= 0.0:
			_handle_room_clear("Survival timer complete.")
			return
		_spawn_cooldown_remaining -= delta
		if _spawn_cooldown_remaining <= 0.0:
			_spawn_enemy_wave()
			_spawn_cooldown_remaining = maxf((0.55 - float(_room_depth) * 0.03) * 0.5, 0.09)
	_check_failure()

func _update_capture_hill_room(delta: float) -> void:
	if _capture_hill_zone == null:
		return
	var players_in_zone := 0
	for player in get_active_players():
		if _capture_hill_zone.contains_point(player.global_position):
			players_in_zone += 1
	if players_in_zone > 0:
		_capture_hill_progress += delta * 0.18 * float(players_in_zone)
	_capture_hill_progress = clampf(_capture_hill_progress, 0.0, 1.0)
	_capture_hill_zone.set_fill_ratio(_capture_hill_progress)
	if _capture_hill_progress >= 1.0:
		_handle_room_clear("Hold zone secured.")

func _spawn_enemy_wave() -> void:
	var alive_count: int = _enemy_nodes.size()
	var target_alive: int = mini(10 + _room_depth * 4, 36)
	if alive_count >= target_alive:
		return
	var spawn_count: int = mini(target_alive - alive_count, maxi(3, 3 + _room_depth))
	for _index in range(spawn_count):
		var enemy_type := _roll_wave_enemy_type()
		var enemy = EnemySceneData.instantiate()
		enemy.global_position = _find_enemy_spawn_position()
		enemy.setup(enemy_type, self)
		enemy.enemy_died.connect(_on_enemy_died)
		enemy.fire_requested.connect(_on_enemy_fire_requested)
		enemy.hit_received.connect(_on_enemy_hit_received)
		enemies.add_child(enemy)
		_enemy_nodes.append(enemy)

func _roll_wave_enemy_type() -> String:
	match _room_enemy_mix:
		"chaser_only":
			return "chaser"
		"charger_only":
			return "charger"
	if _room_depth <= 1:
		return "chaser"
	if _room_depth == 2:
		return "charger" if randf() < 0.22 else "chaser"
	return "charger" if randf() < 0.35 else "chaser"

func _spawn_boss() -> void:
	var boss = EnemySceneData.instantiate()
	boss.global_position = ARENA_CENTER + Vector2(0.0, -420.0)
	boss.setup("boss", self)
	boss.enemy_died.connect(_on_enemy_died)
	boss.fire_requested.connect(_on_enemy_fire_requested)
	boss.hit_received.connect(_on_enemy_hit_received)
	enemies.add_child(boss)
	_enemy_nodes.append(boss)
	_boss_spawned = true

func _find_enemy_spawn_position() -> Vector2:
	var players_active := get_active_players()
	for _attempt in range(60):
		var edge := randi() % 4
		var candidate := ARENA_CENTER
		match edge:
			0:
				candidate = Vector2(randf_range(ARENA_MARGIN * 2.0, ARENA_RECT.end.x - ARENA_MARGIN * 2.0), ARENA_MARGIN * 2.0)
			1:
				candidate = Vector2(randf_range(ARENA_MARGIN * 2.0, ARENA_RECT.end.x - ARENA_MARGIN * 2.0), ARENA_RECT.end.y - ARENA_MARGIN * 2.0)
			2:
				candidate = Vector2(ARENA_MARGIN * 2.0, randf_range(ARENA_MARGIN * 2.0, ARENA_RECT.end.y - ARENA_MARGIN * 2.0))
			_:
				candidate = Vector2(ARENA_RECT.end.x - ARENA_MARGIN * 2.0, randf_range(ARENA_MARGIN * 2.0, ARENA_RECT.end.y - ARENA_MARGIN * 2.0))
		var valid := true
		for player in players_active:
			if candidate.distance_to(player.global_position) < 460.0:
				valid = false
				break
		if valid:
			return candidate
	return ARENA_CENTER + Vector2(0.0, -420.0)

func _on_player_fire_requested(origin: Vector2, direction: Vector2, config: Dictionary) -> void:
	var shooter = config.get("shooter", null)
	if shooter == null:
		return
	var player_index := int(shooter.player_index)
	var loadout: Dictionary = _compiled_loadouts[player_index]
	var primary_stats: Dictionary = loadout.get("primary_stats", {})
	var split_extra_count := int(primary_stats.get("split_extra_count", 0))
	var spread_step := deg_to_rad(float(primary_stats.get("split_spread_degrees", 15.0)))
	var projectile_count := 1 + split_extra_count
	var directions := _build_spread_directions(direction, projectile_count, spread_step)
	for projectile_direction in directions:
		var projectile = ProjectileSceneData.instantiate()
		projectile.global_position = origin
		var projectile_config := {
			"speed": float(primary_stats.get("projectile_speed", 648.0)),
			"damage": int(round(float(primary_stats.get("damage", 14.0)))),
			"color": shooter.player_config.tint,
			"shooter": shooter,
			"feedback_profile": "rifle",
			"impact_weight": 1.0,
			"max_distance": float(primary_stats.get("range", 520.0)),
			"collision_half_width": float(primary_stats.get("area", 4.0)),
			"pierce_count": int(primary_stats.get("pierce_count", 0)),
			"ricochet_count": int(primary_stats.get("ricochet_count", 0)),
			"ricochet_range": float(primary_stats.get("ricochet_range", 200.0)),
			"leaves_fire_trail": bool(primary_stats.get("leaves_fire_trail", false)),
			"trail_lifetime": float(primary_stats.get("trail_lifetime", 1.5)),
			"trail_tick_interval": float(primary_stats.get("trail_tick_interval", 0.5)),
			"trail_damage_percent": float(primary_stats.get("trail_damage_percent", 0.3)),
			"knockback_force": float(primary_stats.get("knockback_force", 0.0)),
			"weapon_id": str(loadout.get("primary_weapon_id", "rifle")),
			"source_type": "primary",
		}
		projectile.setup_from_config("player", projectile_direction, projectile_config)
		projectile.impact_requested.connect(_on_projectile_impact)
		projectiles.add_child(projectile)

func _on_player_shockwave_requested(origin: Vector2, direction: Vector2, stats: Dictionary) -> void:
	var radius := float(stats.get("radius", 250.0))
	var damage := int(round(float(stats.get("damage", 30.0))))
	var knockback_force := float(stats.get("knockback_force", 500.0))
	var tint: Color = stats.get("color", Color(0.28, 0.9, 0.82, 1.0))
	for enemy in _enemy_nodes:
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var offset: Vector2 = enemy.global_position - origin
		var distance := offset.length()
		if distance > radius:
			continue
		enemy.apply_damage(damage)
		if enemy.has_method("apply_knockback"):
			var radial_direction := offset.normalized() if distance > 0.0 else Vector2.RIGHT
			var distance_ratio := 1.0 - clampf(distance / max(radius, 0.01), 0.0, 1.0)
			var applied_force: float = knockback_force * (0.7 + distance_ratio * 0.75)
			enemy.apply_knockback(radial_direction, applied_force)
	_spawn_shockwave_visual(
		origin,
		radius,
		tint,
		float(stats.get("expand_duration", 0.15))
	)
	if screen_shake != null and screen_shake.has_method("add_trauma"):
		screen_shake.add_trauma(clampf(0.16 * float(stats.get("impact_weight", 1.9)), 0.0, 0.36))

func _spawn_shockwave_visual(center: Vector2, radius: float, color: Color, duration: float) -> void:
	var ring := Line2D.new()
	ring.width = 10.0
	ring.closed = true
	ring.default_color = color.lightened(0.18)
	ring.position = center
	ring.scale = Vector2(0.08, 0.08)
	ring.antialiased = true
	ring.points = _build_circle_points(Vector2.ZERO, radius, 40)
	effects.add_child(ring)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(ring.queue_free)

func _on_enemy_fire_requested(origin: Vector2, direction: Vector2, speed: float, damage: int, team: String, color: Color, projectile_scale: float) -> void:
	var projectile = ProjectileSceneData.instantiate()
	projectile.global_position = origin
	projectile.setup_from_config(team, direction, {
		"speed": speed,
		"damage": damage,
		"color": color,
		"feedback_profile": "enemy",
		"impact_weight": projectile_scale,
		"collision_half_width": 6.0 * projectile_scale,
		"use_lifetime": true,
	})
	projectile.impact_requested.connect(_on_projectile_impact)
	projectiles.add_child(projectile)

func _on_projectile_impact(origin: Vector2, direction: Vector2, _team: String, color: Color, _feedback_profile: String, impact_weight: float, target: Node, _combat_context: Dictionary) -> void:
	_spawn_projectile_hit_effect(origin, direction, color, impact_weight, target)
	if screen_shake != null and screen_shake.has_method("add_trauma"):
		screen_shake.add_trauma(clampf(0.03 * impact_weight, 0.0, 0.18))

func _spawn_projectile_hit_effect(origin: Vector2, direction: Vector2, color: Color, impact_weight: float, target: Node) -> void:
	if effects == null:
		return
	var effect_color := color.lightened(0.2)
	if target != null and is_instance_valid(target) and target.has_method("get_feedback_color"):
		effect_color = target.get_feedback_color().lightened(0.12)
	var effect_direction := direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT
	var sparks := ParticleFactoryData.create_impact_sparks(effect_color, effect_direction, impact_weight)
	sparks.global_position = origin
	effects.add_child(sparks)
	if target != null and is_instance_valid(target) and not (target is StaticBody2D):
		var ring := ParticleFactoryData.create_impact_ring(effect_color, 16.0 + impact_weight * 8.0, 2.5 + impact_weight)
		ring.global_position = origin
		effects.add_child(ring)

func _on_enemy_died(enemy) -> void:
	_enemy_nodes.erase(enemy)
	if screen_shake != null and screen_shake.has_method("add_trauma"):
		screen_shake.add_trauma(clampf(0.06 * enemy.get_feedback_weight(), 0.0, 0.2))

func _on_enemy_hit_received(_enemy, _damage_amount: int, lethal: bool) -> void:
	if lethal:
		return
	if screen_shake != null and screen_shake.has_method("add_trauma"):
		screen_shake.add_trauma(0.025)

func _on_player_downed(player) -> void:
	_revive_progress_by_player_id[player.player_id] = 0.0
	player_downed.emit(player)
	_check_failure()

func _on_player_revived(player) -> void:
	_revive_progress_by_player_id.erase(player.player_id)
	player_revived.emit(player)

func _on_player_damage_taken(player, _amount: int, _current_health: int) -> void:
	if player == null or not is_instance_valid(player):
		return
	var burst := ParticleFactoryData.create_impact_sparks(player.player_config.tint.lightened(0.22), Vector2.UP, 1.1)
	burst.global_position = player.global_position
	effects.add_child(burst)
	var ring := ParticleFactoryData.create_impact_ring(player.player_config.tint.lightened(0.12), 22.0, 3.0)
	ring.global_position = player.global_position
	effects.add_child(ring)
	if screen_shake != null and screen_shake.has_method("add_trauma"):
		screen_shake.add_trauma(0.06)

func _on_muzzle_flash_requested(_origin: Vector2, _direction: Vector2, _color: Color, _feedback_profile: String, impact_weight: float) -> void:
	if screen_shake != null and screen_shake.has_method("add_trauma"):
		screen_shake.add_trauma(clampf(0.02 * impact_weight, 0.0, 0.08))

func _on_dash_trail_requested(_origin: Vector2, _color: Color) -> void:
	pass

func _update_revives(delta: float) -> void:
	for player in _player_nodes:
		if player == null or not is_instance_valid(player) or not player.is_downed():
			continue
		var has_reviver := false
		for candidate in get_active_players():
			if candidate == player:
				continue
			if candidate.global_position.distance_to(player.global_position) <= REVIVE_RADIUS:
				has_reviver = true
				break
		var progress := float(_revive_progress_by_player_id.get(player.player_id, 0.0))
		progress = progress + delta if has_reviver else max(progress - delta * 0.75, 0.0)
		if progress >= REVIVE_HOLD_DURATION:
			player.revive(20)
			_revive_progress_by_player_id.erase(player.player_id)
		else:
			_revive_progress_by_player_id[player.player_id] = progress

func _handle_room_clear(summary: String) -> void:
	if _room_clear_started:
		return
	_room_clear_started = true
	_pending_clear_summary = summary
	_lock_player_input(true)
	_end_active_encounter()
	if _room_type == "boss":
		_finish_room_progression(summary)
		return
	_show_mutation_pick()

func _show_mutation_pick() -> void:
	_awaiting_mutation_pick = true
	_mutation_pick_ui = MutationPickUIScene.instantiate()
	_mutation_pick_ui.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	var options_by_player: Array = []
	for player_index in range(_player_nodes.size()):
		options_by_player.append(_mutation_system.roll_mutation_options(player_index, 3))
	_mutation_pick_ui.configure_for_players(_player_configs, options_by_player)
	_mutation_pick_ui.selections_confirmed.connect(_on_mutation_selections_confirmed)
	ui_layer.add_child(_mutation_pick_ui)
	get_tree().paused = true

func _on_mutation_selections_confirmed(selections: Array) -> void:
	get_tree().paused = false
	for player_index in range(min(selections.size(), _player_nodes.size())):
		_mutation_system.apply_mutation(player_index, str(selections[player_index]))
	_rebuild_player_loadouts()
	if _mutation_pick_ui != null and is_instance_valid(_mutation_pick_ui):
		_mutation_pick_ui.queue_free()
	_mutation_pick_ui = null
	_awaiting_mutation_pick = false
	_finish_room_progression(_pending_clear_summary)

func _end_active_encounter() -> void:
	_exit_zone_open = false
	exit_zone.monitoring = false
	exit_zone_visual.visible = false
	for child in projectiles.get_children():
		child.queue_free()
	for child in effects.get_children():
		child.queue_free()
	for enemy in _enemy_nodes:
		if enemy != null and is_instance_valid(enemy):
			enemy.queue_free()
	_enemy_nodes.clear()
	if _capture_hill_zone != null and is_instance_valid(_capture_hill_zone):
		_capture_hill_zone.queue_free()
	_capture_hill_zone = null

func _finish_room_progression(summary: String) -> void:
	room_cleared.emit(capture_player_health_states(), {"summary": summary})

func _open_exit_zone() -> void:
	_exit_zone_open = true
	exit_zone.monitoring = true
	exit_zone_visual.visible = true
	result_panel.visible = false
	_lock_player_input(false)

func _update_exit_zone(delta: float) -> void:
	if not _exit_zone_open or _awaiting_mutation_pick:
		return
	var living_players := get_active_players()
	if living_players.is_empty():
		return
	var everyone_inside := true
	for player in living_players:
		var local_position: Vector2 = player.global_position - exit_zone.global_position
		if abs(local_position.x) > EXIT_ZONE_SIZE.x * 0.5 or abs(local_position.y) > EXIT_ZONE_SIZE.y * 0.5:
			everyone_inside = false
			break
	if not everyone_inside:
		return
	_room_cleared_with_exit(delta)

func _room_cleared_with_exit(delta: float) -> void:
	var progress := float(_revive_progress_by_player_id.get("exit_hold", 0.0)) + delta
	_revive_progress_by_player_id["exit_hold"] = progress
	if progress < EXIT_HOLD_DURATION:
		return
	_revive_progress_by_player_id.erase("exit_hold")
	room_cleared.emit(capture_player_health_states(), {"summary": "Room clear. The team moved on."})

func capture_player_health_states() -> Array:
	var states: Array = []
	for player in _player_nodes:
		var state: Dictionary = player.get_health_state()
		if player.is_downed():
			state["current"] = 1
		states.append(state)
	return states

func _check_failure() -> void:
	if _room_failed:
		return
	if get_active_players().is_empty():
		_room_failed = true
		all_players_dead.emit()

func _spawn_capture_hill_zone() -> void:
	_capture_hill_zone = CaptureHillZoneData.new()
	_capture_hill_zone.configure(180.0)
	_capture_hill_zone.global_position = _roll_capture_hill_position()
	add_child(_capture_hill_zone)

func _roll_capture_hill_position() -> Vector2:
	var quadrants := [
		Vector2(ARENA_RECT.position.x + ARENA_SIZE.x * 0.28, ARENA_RECT.position.y + ARENA_SIZE.y * 0.28),
		Vector2(ARENA_RECT.position.x + ARENA_SIZE.x * 0.72, ARENA_RECT.position.y + ARENA_SIZE.y * 0.28),
		Vector2(ARENA_RECT.position.x + ARENA_SIZE.x * 0.28, ARENA_RECT.position.y + ARENA_SIZE.y * 0.72),
		Vector2(ARENA_RECT.position.x + ARENA_SIZE.x * 0.72, ARENA_RECT.position.y + ARENA_SIZE.y * 0.72),
	]
	return quadrants[randi() % quadrants.size()]

func _get_player_spawn_position(index: int) -> Vector2:
	if _player_configs.size() <= 1:
		return ARENA_CENTER
	var spawn_offsets := [
		Vector2(-80.0, 0.0),
		Vector2(80.0, 0.0),
	]
	return ARENA_CENTER + spawn_offsets[min(index, spawn_offsets.size() - 1)]

func _clamp_players_to_arena() -> void:
	for player in _player_nodes:
		_clamp_player_to_arena(player)

func _clamp_player_to_arena(player) -> void:
	if player == null or not is_instance_valid(player):
		return
	var min_position := Vector2(ARENA_MARGIN + 32.0, ARENA_MARGIN + 32.0)
	var max_position := Vector2(ARENA_RECT.end.x - ARENA_MARGIN - 32.0, ARENA_RECT.end.y - ARENA_MARGIN - 32.0)
	player.global_position = Vector2(
		clampf(player.global_position.x, min_position.x, max_position.x),
		clampf(player.global_position.y, min_position.y, max_position.y)
	)

func _refresh_hud() -> void:
	if _timer_label == null or _timer_fill == null:
		return
	if _room_objective == "capture_the_hill":
		_timer_label.text = "Hold Zone  %d%%" % int(round(_capture_hill_progress * 100.0))
		_timer_fill.scale = Vector2(_capture_hill_progress, 1.0)
	else:
		var max_duration := SURVIVE_DURATION
		var ratio := clampf(_room_timer_remaining / max(max_duration, 0.01), 0.0, 1.0)
		_timer_label.text = "Survive  %.1fs" % _room_timer_remaining if _room_type != "boss" else "Boss Fight"
		_timer_fill.scale = Vector2(1.0 if _room_type == "boss" else ratio, 1.0)
	for index in range(min(_player_inventory_huds.size(), _player_nodes.size())):
		_player_inventory_huds[index].update_hud({
			"header": "P%d" % (index + 1),
			"health_state": _player_nodes[index].get_health_state(),
			"health_status": _player_nodes[index].get_health_ratio_text(),
			"primary": _player_nodes[index].get_primary_hud_data(),
			"secondary": _player_nodes[index].get_secondary_hud_data(),
			"dash": _player_nodes[index].get_dash_hud_data(),
			"mutations": _mutation_system.get_active_mutations(index),
		})

func get_active_players() -> Array:
	var active_players: Array = []
	for player in _player_nodes:
		if player != null and is_instance_valid(player) and player.is_alive():
			active_players.append(player)
	return active_players

func get_player_target_nodes() -> Array:
	return _player_nodes.duplicate()

func get_enemy_target_nodes() -> Array:
	return _enemy_nodes.duplicate()

func _build_circle_points(center: Vector2, radius: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := TAU * float(index) / float(point_count)
		points.append(center + Vector2.RIGHT.rotated(angle) * radius)
	return points

func _build_spread_directions(base_direction: Vector2, projectile_count: int, spread_step: float) -> Array:
	var directions: Array = []
	if projectile_count <= 1 or spread_step <= 0.0:
		return [base_direction.normalized()]
	var center_offset := float(projectile_count - 1) * 0.5
	for index in range(projectile_count):
		var offset := (float(index) - center_offset) * spread_step
		directions.append(base_direction.normalized().rotated(offset))
	return directions

func handle_enemy_charge_windup(_origin: Vector2) -> void:
	if screen_shake != null and screen_shake.has_method("add_trauma"):
		screen_shake.add_trauma(0.06)

func spawn_enemy_attack_trail(_origin: Vector2, _direction: Vector2, _color: Color, _weight: float) -> void:
	pass

func handle_enemy_death_explosion(_origin: Vector2, _radius: float, _damage: int) -> void:
	pass

func _lock_player_input(locked: bool) -> void:
	for player in _player_nodes:
		if player != null and is_instance_valid(player):
			player.set_input_locked(locked)

func _unhandled_input(event: InputEvent) -> void:
	if _awaiting_mutation_pick:
		return
	if not _is_pause_request(event):
		return
	if pause_panel.visible:
		_on_resume_pressed()
		get_viewport().set_input_as_handled()
		return
	_show_pause_menu()
	get_viewport().set_input_as_handled()

func _show_pause_menu() -> void:
	pause_panel.visible = true
	get_tree().paused = true

func _on_resume_pressed() -> void:
	pause_panel.visible = false
	get_tree().paused = false

func _on_retry_pressed() -> void:
	get_tree().paused = false
	_rebuild_player_loadouts()
	_start_room()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	return_to_menu_requested.emit()

func _is_pause_request(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return true
	if not (event is InputEventJoypadButton):
		return false
	var joy_event := event as InputEventJoypadButton
	return joy_event.pressed and joy_event.button_index == JOY_BUTTON_START
