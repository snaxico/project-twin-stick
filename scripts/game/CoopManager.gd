extends Node2D

const EnemySceneData = preload("res://scenes/enemies/Enemy.tscn")
const ProjectileSceneData = preload("res://scenes/weapons/Projectile.tscn")
const GoldPickupSceneData = preload("res://scenes/pickups/GoldPickup.tscn")
const GoldPickupData = preload("res://scripts/pickups/GoldPickup.gd")
const HealthPickupData = preload("res://scripts/pickups/HealthPickup.gd")
const PlayerInventoryHUDData = preload("res://scripts/ui/PlayerInventoryHUD.gd")
const MutationSystemData = preload("res://scripts/game/MutationSystem.gd")
const MutationPickUIScene = preload("res://scenes/ui/MutationPickUI.tscn")
const TempBuffSystemData = preload("res://scripts/buffs/TempBuffSystem.gd")
const HoldZoneObjectiveData = preload("res://scripts/objectives/HoldZoneObjective.gd")
const FireFloorModifierData = preload("res://scripts/modifiers/FireFloorModifier.gd")
const IceZoneModifierData = preload("res://scripts/modifiers/IceZoneModifier.gd")
const MineFieldModifierData = preload("res://scripts/modifiers/MineFieldModifier.gd")

const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")
const MODIFIERS_DATA_PATH := "res://data/modifiers.json"

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
const SURVIVAL_BONUS_GOLD := 0
const MUTATION_PICK_COSTS := [15, 50, 100]
const ELITE_RARE_PICK_COST := 50
const GOLD_DROP_PER_ENEMY := 1
const HEALTH_DROP_CHANCE := 0.08
const HEALTH_PICKUP_HEAL := 5
const SHOP_MUTATION_COST := 80
const SHOP_HEAL_COST := 40
const SHOP_REROLL_COST := 20
const SHOP_HEAL_AMOUNT := 25
const SHOP_MUTATION_COUNT := 3
const MAX_ACTIVE_PROJECTILES := 180
const IMPACT_EFFECT_SOFT_CAP := 120
const HUD_REFRESH_INTERVAL := 0.08

@export var player_scene: PackedScene

signal room_cleared(health_states, clear_context)
signal all_players_dead
signal player_downed(player)
signal player_revived(player)
signal return_to_menu_requested

@onready var players: Node2D = $Players
@onready var projectiles: Node2D = $Projectiles
@onready var enemies: Node2D = $Enemies
@onready var pickups: Node2D = $Pickups
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
var _revive_progress_by_player_id: Dictionary = {}
var _hud_root: Control = null
var _player_inventory_huds: Array = []
var _gold_labels: Array = []
var _timer_label: Label = null
var _timer_fill: ColorRect = null
var _modifier_hud: VBoxContainer = null
var _hold_zone_status_label: Label = null
var _mutation_pick_ui = null
var _shop_ui = null
var _arena_minor_grid_color := Color(0.32, 0.72, 0.86, 0.24)
var _arena_major_grid_color := Color(0.42, 0.9, 1.0, 0.42)
var _arena_wall_color := Color(0.12, 0.32, 0.38, 0.92)
var _pending_clear_summary := ""
var _room_gold_multiplier: float = 1.0
var _room_gold_earned: int = 0
var _next_hud_refresh_at := 0.0
var _active_players_cache: Array = []
var _active_players_cache_frame := -1
var _pause_selection_index := 0
var _active_modifiers: Array = []
var _modifier_definitions: Dictionary = {}
var _accelerating_waves_active := false
var _enemy_faster_active := false
var _spitter_swarm_active := false
var _hold_zone = null
var _temp_buff_system = null
var _hold_buff_offer: Dictionary = {}
var _fire_floor_modifier = null
var _ice_zone_modifier = null
var _mine_field_modifier = null
var _aura_buffed_enemies: Array = []
var _aura_debuffed_players: Array = []

func configure_players(configs: Array) -> void:
	_player_configs = configs.duplicate()

func configure_room(room_config: Dictionary) -> void:
	_room_config = room_config.duplicate(true)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if player_scene == null:
		player_scene = load("res://scenes/player/Player.tscn")
	_hide_legacy_ui()
	_bind_ui()
	_load_modifier_definitions()
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

	_hold_zone_status_label = Label.new()
	_hold_zone_status_label.position = Vector2(820.0, 84.0)
	_hold_zone_status_label.size = Vector2(280.0, 20.0)
	_hold_zone_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hold_zone_status_label.add_theme_font_size_override("font_size", 13)
	_hold_zone_status_label.add_theme_color_override("font_color", Color(0.84, 0.94, 1.0, 0.9))
	_hud_root.add_child(_hold_zone_status_label)

	_modifier_hud = VBoxContainer.new()
	_modifier_hud.position = Vector2(1600.0, 24.0)
	_modifier_hud.add_theme_constant_override("separation", 6)
	_modifier_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_modifier_hud)

	_player_inventory_huds.clear()
	_gold_labels.clear()
	for index in range(_player_configs.size()):
		var hud := PlayerInventoryHUDData.new()
		var hud_position := Vector2(24.0, 860.0 + index * 140.0) if index == 0 else Vector2(1676.0, 860.0)
		hud.position = hud_position
		hud.configure_player("P%d" % (index + 1), _player_configs[index].tint)
		_hud_root.add_child(hud)
		_player_inventory_huds.append(hud)

		var gold_label := Label.new()
		gold_label.text = "0g"
		gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		gold_label.add_theme_font_size_override("font_size", 16)
		gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 0.95))
		gold_label.position = hud_position + Vector2(0.0, -24.0)
		_hud_root.add_child(gold_label)
		_gold_labels.append(gold_label)

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
		player.primary_skill_requested.connect(_on_player_primary_skill_requested)
		player.downed.connect(_on_player_downed)
		player.revived.connect(_on_player_revived)
		player.damage_taken.connect(_on_player_damage_taken)
		player.muzzle_flash_requested.connect(_on_muzzle_flash_requested)
		player.secondary_skill_trail_requested.connect(_on_secondary_skill_trail_requested)
		_player_nodes.append(player)
	_rebuild_player_loadouts()
	if camera.has_method("set_players"):
		camera.set_players(_player_nodes)
		camera.global_position = ARENA_CENTER

func _rebuild_player_loadouts() -> void:
	_compiled_loadouts.clear()
	for index in range(_player_nodes.size()):
		var base_loadout: Dictionary = RunState.get_player_runtime_loadout_for(index)
		var compiled_weapon := _mutation_system.get_compiled_weapon_stats(index, (base_loadout.get("weapon_stats", {}) as Dictionary))
		var compiled_skill_stats := _build_primary_skill_runtime_stats(index, (base_loadout.get("primary_skill_stats", {}) as Dictionary))
		var compiled_loadout := {
			"weapon_id": str(base_loadout.get("weapon_id", "rifle")),
			"weapon_name": str(base_loadout.get("weapon_name", "Rifle")),
			"weapon_stats": compiled_weapon,
			"primary_skill_id": str(base_loadout.get("primary_skill_id", "shockwave")),
			"primary_skill_name": str(base_loadout.get("primary_skill_name", "Shockwave")),
			"primary_skill_stats": compiled_skill_stats,
			"mutations": _mutation_system.get_active_mutations(index),
			"move_speed": float(base_loadout.get("move_speed", 390.0)),
			"dash_damage_multiplier": _mutation_system.get_dash_damage_multiplier(index),
		}
		_compiled_loadouts.append(compiled_loadout)
		_player_nodes[index].apply_loadout(compiled_loadout)

func _build_primary_skill_runtime_stats(player_index: int, base_stats: Dictionary) -> Dictionary:
	var knockback_force := float(base_stats.get("knockback_force", 950.0))
	if _mutation_system.has_mutation(player_index, "knockback"):
		knockback_force += float(_mutation_system.get_mutation_level(player_index, "knockback")) * 60.0
	var cooldown_reduction_pct: float = _mutation_system.get_primary_skill_cooldown_reduction(player_index)
	var cooldown: float = maxf(0.5, float(base_stats.get("cooldown", 8.0)) * (1.0 - cooldown_reduction_pct))
	return {
		"kind": str(base_stats.get("kind", "shockwave")),
		"damage": float(base_stats.get("damage", 30.0)),
		"cooldown": cooldown,
		"radius": float(base_stats.get("radius", 250.0)) * _mutation_system.get_primary_skill_radius_multiplier(player_index),
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

func _set_wall_rect(node: CollisionShape2D, wall_position: Vector2, size: Vector2) -> void:
	node.position = wall_position
	if node.shape == null or not (node.shape is RectangleShape2D):
		node.shape = RectangleShape2D.new()
	(node.shape as RectangleShape2D).size = size

func _start_room() -> void:
	_clear_runtime_nodes()
	_room_type = str(_room_config.get("room_type", "combat"))
	_room_objective = str(_room_config.get("objective", _room_config.get("room_objective", "survive")))
	_room_enemy_mix = str(_room_config.get("enemy_mix", "mixed"))
	_room_depth = max(int(_room_config.get("depth", _room_config.get("step_index", 1))), 1)
	_active_modifiers = (_room_config.get("modifiers", []) as Array).duplicate()
	_accelerating_waves_active = _active_modifiers.has("accelerating_waves")
	_enemy_faster_active = _active_modifiers.has("enemy_faster")
	_spitter_swarm_active = _active_modifiers.has("spitter_swarm")
	_apply_arena_color_for_depth(_room_depth)
	_room_clear_started = false
	_room_failed = false
	_exit_zone_open = false
	_awaiting_mutation_pick = false
	_spawn_cooldown_remaining = 0.15
	_room_timer_remaining = SURVIVE_DURATION
	_boss_spawned = false
	_pending_clear_summary = ""
	_room_gold_multiplier = 1.0
	for mod_id in _active_modifiers:
		_room_gold_multiplier += _get_modifier_gold_bonus(str(mod_id))
	_room_gold_earned = 0
	_next_hud_refresh_at = 0.0
	result_panel.visible = false
	pause_panel.visible = false
	settings_panel.visible = false
	get_tree().paused = false
	_restore_player_health_states()
	_lock_player_input(false)
	_populate_modifier_hud()
	if (_room_type == "combat" or _room_type == "elite") and str(_room_config.get("side_objective", "")) == "hold_zone":
		_temp_buff_system = TempBuffSystemData.new()
		_hold_buff_offer = _temp_buff_system.roll_random_buff()
		_hold_zone = HoldZoneObjectiveData.new()
		_hold_zone.setup(ARENA_RECT)
		_hold_zone.completed.connect(_on_hold_zone_completed)
		add_child(_hold_zone)
	if _active_modifiers.has("fire_floor"):
		_fire_floor_modifier = FireFloorModifierData.new()
		_fire_floor_modifier.setup(ARENA_RECT, _player_nodes)
		add_child(_fire_floor_modifier)
	if _active_modifiers.has("ice_zone"):
		_ice_zone_modifier = IceZoneModifierData.new()
		_ice_zone_modifier.setup(ARENA_RECT)
		add_child(_ice_zone_modifier)
	if _active_modifiers.has("mine_field"):
		_mine_field_modifier = MineFieldModifierData.new()
		_mine_field_modifier.setup(ARENA_RECT, _player_nodes)
		add_child(_mine_field_modifier)
	if _room_type == "boss":
		_spawn_boss()
	elif _room_type == "rest" or _room_type == "shop":
		_start_non_combat_room()
	elif _room_type == "elite":
		_spawn_elite_miniboss()

func _clear_runtime_nodes() -> void:
	for group in [projectiles, enemies, effects, pickups]:
		for child in group.get_children():
			child.queue_free()
	_enemy_nodes.clear()
	if _temp_buff_system != null:
		_temp_buff_system.clear_all_buffs(_player_nodes)
	_temp_buff_system = null
	_hold_buff_offer.clear()
	for player in _player_nodes:
		if player != null and is_instance_valid(player):
			player.clear_zone_modifier("ice_zone")
			player.clear_zone_modifier("elite_support")
	if _hold_zone != null and is_instance_valid(_hold_zone):
		_hold_zone.queue_free()
	_hold_zone = null
	for node_ref in [_fire_floor_modifier, _ice_zone_modifier, _mine_field_modifier]:
		if node_ref != null and is_instance_valid(node_ref):
			node_ref.queue_free()
	_fire_floor_modifier = null
	_ice_zone_modifier = null
	_mine_field_modifier = null
	for enemy in _aura_buffed_enemies:
		if enemy != null and is_instance_valid(enemy) and enemy.has_method("clear_aura"):
			enemy.clear_aura()
	_aura_buffed_enemies.clear()
	_aura_debuffed_players.clear()
	if _mutation_pick_ui != null and is_instance_valid(_mutation_pick_ui):
		_mutation_pick_ui.queue_free()
	_mutation_pick_ui = null
	if _shop_ui != null and is_instance_valid(_shop_ui):
		_shop_ui.queue_free()
	_shop_ui = null

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
	_invalidate_runtime_caches()
	_clamp_players_to_arena()
	_update_revives(delta)
	_update_elite_support_auras()
	_update_room(delta)
	_update_gold_pickups(delta)
	_update_exit_zone(delta)
	var now := _current_time_seconds()
	if now >= _next_hud_refresh_at:
		_refresh_hud()
		_next_hud_refresh_at = now + HUD_REFRESH_INTERVAL

func _update_room(delta: float) -> void:
	if _room_clear_started or _room_failed or _room_type == "rest" or _room_type == "shop":
		return
	if _hold_zone != null and is_instance_valid(_hold_zone) and not _hold_zone.is_complete():
		_hold_zone.update_zone(delta, _player_nodes)
	if _ice_zone_modifier != null and is_instance_valid(_ice_zone_modifier):
		_apply_ice_zone_modifier()
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
	_room_timer_remaining = max(_room_timer_remaining - delta, 0.0)
	if _room_timer_remaining <= 0.0:
		_handle_room_clear("Survival timer complete.")
		return
	_spawn_cooldown_remaining -= delta
	if _spawn_cooldown_remaining <= 0.0:
		_spawn_enemy_wave()
		var base_interval := maxf((0.55 - float(_room_depth) * 0.03) * 0.5, 0.09)
		if _accelerating_waves_active:
			var elapsed := SURVIVE_DURATION - _room_timer_remaining
			var accel_mult := maxf(1.0 - (minf(elapsed, 40.0) / 40.0) * 0.67, 0.33)
			base_interval *= accel_mult
		_spawn_cooldown_remaining = base_interval
	_check_failure()

func _spawn_enemy_wave() -> void:
	var alive_count: int = _enemy_nodes.size()
	var elite_bonus := 6 if _room_type == "elite" else 0
	var target_alive: int = mini(10 + _room_depth * 4 + elite_bonus, 44)
	if alive_count >= target_alive:
		return
	var spawn_count: int = mini(target_alive - alive_count, maxi(3, 3 + _room_depth))
	for _index in range(spawn_count):
		var enemy_type := _roll_wave_enemy_type()
		var enemy = EnemySceneData.instantiate()
		enemy.global_position = _find_enemy_spawn_position()
		enemy.setup(enemy_type, self)
		if _enemy_faster_active:
			enemy.apply_room_modifier(0, 1.33, 1.0 / 1.33, 0.0, 0, 0)
		enemy.enemy_died.connect(_on_enemy_died)
		enemy.fire_requested.connect(_on_enemy_fire_requested)
		enemy.hit_received.connect(_on_enemy_hit_received)
		enemies.add_child(enemy)
		_enemy_nodes.append(enemy)

func _roll_wave_enemy_type() -> String:
	if _spitter_swarm_active:
		var spitter_roll := randf()
		if spitter_roll < 0.25:
			return "chaser"
		if spitter_roll < 0.5:
			return "charger"
		return "spitter"
	match _room_enemy_mix:
		"chaser_only":
			return "chaser"
		"charger_only":
			return "charger"
		"charger_heavy":
			return "charger" if randf() < 0.55 else "chaser"
	if _room_depth <= 1:
		return "spitter" if randf() < 0.1 else "chaser"
	if _room_depth == 2:
		var depth_two_roll := randf()
		if depth_two_roll < 0.1:
			return "spitter"
		return "charger" if depth_two_roll < 0.32 else "chaser"
	var mixed_roll := randf()
	if mixed_roll < 0.1:
		return "spitter"
	return "charger" if mixed_roll < 0.45 else "chaser"

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

func _spawn_elite_miniboss() -> void:
	var miniboss_types := ["elite_charger", "elite_spitter", "elite_support"]
	var miniboss_type: String = miniboss_types[randi() % miniboss_types.size()]
	var miniboss = EnemySceneData.instantiate()
	miniboss.global_position = ARENA_CENTER + Vector2(randf_range(-120.0, 120.0), -320.0)
	miniboss.setup(miniboss_type, self)
	if _enemy_faster_active:
		miniboss.apply_room_modifier(0, 1.33, 1.0 / 1.33, 0.0, 0, 0)
	miniboss.enemy_died.connect(_on_enemy_died)
	miniboss.fire_requested.connect(_on_enemy_fire_requested)
	miniboss.hit_received.connect(_on_enemy_hit_received)
	enemies.add_child(miniboss)
	_enemy_nodes.append(miniboss)

func _start_non_combat_room() -> void:
	if _room_type == "shop":
		_show_shop()
	else:
		_open_exit_zone()

func _show_shop() -> void:
	_awaiting_mutation_pick = true
	_shop_ui = _build_shop_panel()
	_shop_ui.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	ui_layer.add_child(_shop_ui)
	get_tree().paused = true

func _build_shop_panel() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.82)
	root.add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_bottom", 60)
	root.add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	margin.add_child(row)

	for player_index in range(_player_configs.size()):
		var player_panel := _build_shop_player_panel(player_index)
		row.add_child(player_panel)
	return root

func _build_shop_player_panel(player_index: int) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(560.0, 0.0)
	panel.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "Player %d Shop" % (player_index + 1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	panel.add_child(title)

	var gold_label := Label.new()
	gold_label.name = "GoldLabel"
	gold_label.text = "Gold: %dg" % RunState.get_player_gold(player_index)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 0.95))
	panel.add_child(gold_label)

	var hint := Label.new()
	hint.text = "Navigate with D-Pad/Arrows, confirm with A/Space, done with B/Escape."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(0.75, 0.78, 0.84, 0.7)
	panel.add_child(hint)

	var options_container := VBoxContainer.new()
	options_container.name = "Options"
	options_container.add_theme_constant_override("separation", 6)
	panel.add_child(options_container)

	var mutation_options: Array = _mutation_system.roll_mutation_options(player_index, SHOP_MUTATION_COUNT, "all")
	for option_index in range(mutation_options.size()):
		var mutation: Dictionary = mutation_options[option_index]
		var option_row := _build_shop_option_row(
			str(mutation.get("name", "Unknown")),
			str(mutation.get("description", "")),
			SHOP_MUTATION_COST,
			"mutation_%d" % option_index,
		)
		option_row.set_meta("mutation_id", str(mutation.get("id", "")))
		option_row.set_meta("option_type", "mutation")
		options_container.add_child(option_row)

	var heal_row := _build_shop_option_row("Heal (+%d HP)" % SHOP_HEAL_AMOUNT, "Restore health.", SHOP_HEAL_COST, "heal")
	heal_row.set_meta("option_type", "heal")
	options_container.add_child(heal_row)

	var reroll_row := _build_shop_option_row("Reroll Mutations", "Refresh mutation options.", SHOP_REROLL_COST, "reroll")
	reroll_row.set_meta("option_type", "reroll")
	options_container.add_child(reroll_row)

	var done_row := _build_shop_option_row("Done", "Leave the shop.", 0, "done")
	done_row.set_meta("option_type", "done")
	options_container.add_child(done_row)

	panel.set_meta("player_index", player_index)
	panel.set_meta("selected_index", 0)
	panel.set_meta("confirmed", false)
	panel.set_meta("mutation_options", mutation_options)
	_refresh_shop_panel_highlight(panel)
	return panel

func _build_shop_option_row(title_text: String, desc_text: String, cost: int, _option_id: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 48.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.92)
	style.border_color = Color(0.3, 0.34, 0.4, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)

	var title := Label.new()
	title.name = "Title"
	title.text = title_text
	title.add_theme_font_size_override("font_size", 14)
	text_box.add_child(title)

	if not desc_text.is_empty():
		var desc := Label.new()
		desc.text = desc_text
		desc.add_theme_font_size_override("font_size", 11)
		desc.modulate = Color(0.72, 0.76, 0.84, 0.8)
		text_box.add_child(desc)

	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	if cost > 0:
		cost_label.text = "%dg" % cost
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 0.95))
	else:
		cost_label.text = ""
	cost_label.add_theme_font_size_override("font_size", 14)
	row.add_child(cost_label)
	return panel

func _refresh_shop_panel_highlight(panel: VBoxContainer) -> void:
	var options_container: VBoxContainer = panel.get_node("Options")
	var selected_index: int = int(panel.get_meta("selected_index", 0))
	var is_confirmed: bool = bool(panel.get_meta("confirmed", false))
	var player_index: int = int(panel.get_meta("player_index", 0))
	var gold_label: Label = panel.get_node("GoldLabel")
	gold_label.text = "Gold: %dg" % RunState.get_player_gold(player_index)

	for child_index in range(options_container.get_child_count()):
		var option: PanelContainer = options_container.get_child(child_index) as PanelContainer
		if option == null:
			continue
		var style: StyleBoxFlat = option.get_theme_stylebox("panel") as StyleBoxFlat
		if style == null:
			continue
		var new_style := style.duplicate() as StyleBoxFlat
		if child_index == selected_index and not is_confirmed:
			new_style.border_color = Color(0.95, 0.82, 0.28, 0.96)
			new_style.set_border_width_all(2)
		else:
			new_style.border_color = Color(0.3, 0.34, 0.4, 0.5)
			new_style.set_border_width_all(1)
		if is_confirmed:
			new_style.bg_color = Color(0.06, 0.08, 0.1, 0.8)
		else:
			new_style.bg_color = Color(0.08, 0.1, 0.14, 0.92)
		option.add_theme_stylebox_override("panel", new_style)

func _handle_shop_input(event: InputEvent) -> void:
	if _shop_ui == null:
		return
	var row: HBoxContainer = _shop_ui.get_child(1).get_child(0) as HBoxContainer
	if row == null:
		return
	for child_index in range(row.get_child_count()):
		var panel: VBoxContainer = row.get_child(child_index) as VBoxContainer
		if panel == null:
			continue
		if bool(panel.get_meta("confirmed", false)):
			continue
		var player_index: int = int(panel.get_meta("player_index", 0))
		var options_container: VBoxContainer = panel.get_node("Options")
		var option_count: int = options_container.get_child_count()
		var selected_index: int = int(panel.get_meta("selected_index", 0))

		var direction := _get_shop_direction(event, player_index)
		if direction != 0:
			selected_index = wrapi(selected_index + direction, 0, option_count)
			panel.set_meta("selected_index", selected_index)
			_refresh_shop_panel_highlight(panel)
			get_viewport().set_input_as_handled()
			return

		if _is_shop_skip_pressed(event, player_index):
			_finalize_shop_player(panel)
			get_viewport().set_input_as_handled()
			return

		if _is_shop_confirm_pressed(event, player_index):
			_execute_shop_option(panel, selected_index)
			get_viewport().set_input_as_handled()
			return

func _execute_shop_option(panel: VBoxContainer, option_index: int) -> void:
	var player_index: int = int(panel.get_meta("player_index", 0))
	var options_container: VBoxContainer = panel.get_node("Options")
	var option: PanelContainer = options_container.get_child(option_index) as PanelContainer
	if option == null:
		return
	var option_type: String = str(option.get_meta("option_type", ""))
	match option_type:
		"mutation":
			var mutation_id: String = str(option.get_meta("mutation_id", ""))
			if mutation_id.is_empty():
				return
			if not RunState.spend_player_gold(player_index, SHOP_MUTATION_COST):
				return
			_mutation_system.apply_mutation(player_index, mutation_id)
			_rebuild_player_loadouts()
			var title_label: Label = option.get_node("Title") as Label
			if title_label != null:
				title_label.text += "  [BOUGHT]"
			option.set_meta("option_type", "sold")
		"heal":
			if not RunState.spend_player_gold(player_index, SHOP_HEAL_COST):
				return
			var health_state: Dictionary = RunState.player_health_states[player_index]
			health_state["current"] = mini(int(health_state.get("current", 0)) + SHOP_HEAL_AMOUNT, int(health_state.get("max", 50)))
			RunState.player_health_states[player_index] = health_state
			if player_index < _player_nodes.size():
				_player_nodes[player_index].set_health_state(health_state)
		"reroll":
			if not RunState.spend_player_gold(player_index, SHOP_REROLL_COST):
				return
			_reroll_shop_mutations(panel, player_index)
		"done":
			_finalize_shop_player(panel)
			return
	_refresh_shop_panel_highlight(panel)

func _reroll_shop_mutations(panel: VBoxContainer, player_index: int) -> void:
	var options_container: VBoxContainer = panel.get_node("Options")
	var new_mutations: Array = _mutation_system.roll_mutation_options(player_index, SHOP_MUTATION_COUNT, "all")
	panel.set_meta("mutation_options", new_mutations)
	for child_index in range(mini(new_mutations.size(), options_container.get_child_count())):
		var option: PanelContainer = options_container.get_child(child_index) as PanelContainer
		if option == null:
			continue
		var mutation: Dictionary = new_mutations[child_index]
		option.set_meta("mutation_id", str(mutation.get("id", "")))
		option.set_meta("option_type", "mutation")
		var title_label: Label = option.get_node("Title") as Label
		if title_label != null:
			title_label.text = str(mutation.get("name", "Unknown"))

func _finalize_shop_player(panel: VBoxContainer) -> void:
	panel.set_meta("confirmed", true)
	_refresh_shop_panel_highlight(panel)
	if _all_shop_players_done():
		_close_shop()

func _all_shop_players_done() -> bool:
	if _shop_ui == null:
		return true
	var row: HBoxContainer = _shop_ui.get_child(1).get_child(0) as HBoxContainer
	if row == null:
		return true
	for child_index in range(row.get_child_count()):
		var panel: VBoxContainer = row.get_child(child_index) as VBoxContainer
		if panel == null:
			continue
		if not bool(panel.get_meta("confirmed", false)):
			return false
	return true

func _close_shop() -> void:
	get_tree().paused = false
	_awaiting_mutation_pick = false
	if _temp_buff_system != null:
		_temp_buff_system.clear_all_buffs(_player_nodes)
	if _shop_ui != null and is_instance_valid(_shop_ui):
		_shop_ui.queue_free()
	_shop_ui = null
	_open_exit_zone()

func _get_shop_direction(event: InputEvent, player_index: int) -> int:
	var config = _player_configs[player_index]
	if config.control_source == "gamepad" and event is InputEventJoypadButton:
		var joy_button := event as InputEventJoypadButton
		if joy_button.pressed and joy_button.device == _get_shop_gamepad_device(player_index):
			if joy_button.button_index == JOY_BUTTON_DPAD_UP:
				return -1
			if joy_button.button_index == JOY_BUTTON_DPAD_DOWN:
				return 1
	if config.control_source == "gamepad" and event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.device == _get_shop_gamepad_device(player_index) and motion.axis == JOY_AXIS_LEFT_Y:
			if motion.axis_value < -0.5:
				return -1
			if motion.axis_value > 0.5:
				return 1
	if config.control_source != "gamepad":
		if _event_matches_action(event, "p%d_move_up" % int(config.player_id)):
			return -1
		if _event_matches_action(event, "p%d_move_down" % int(config.player_id)):
			return 1
	return 0

func _is_shop_confirm_pressed(event: InputEvent, player_index: int) -> bool:
	var config = _player_configs[player_index]
	if config.control_source == "gamepad":
		if not (event is InputEventJoypadButton):
			return false
		var joy_button := event as InputEventJoypadButton
		return joy_button.pressed and joy_button.device == _get_shop_gamepad_device(player_index) and joy_button.button_index == JOY_BUTTON_A
	return _event_matches_action(event, "p%d_secondary" % int(config.player_id))

func _is_shop_skip_pressed(event: InputEvent, player_index: int) -> bool:
	var config = _player_configs[player_index]
	if config.control_source == "gamepad":
		if not (event is InputEventJoypadButton):
			return false
		var joy_button := event as InputEventJoypadButton
		return joy_button.pressed and joy_button.device == _get_shop_gamepad_device(player_index) and joy_button.button_index == JOY_BUTTON_B
	return _event_matches_action(event, "p%d_dash" % int(config.player_id)) or _event_matches_action(event, "ui_cancel")

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
	if projectiles.get_child_count() >= MAX_ACTIVE_PROJECTILES:
		return
	var player_index := int(shooter.player_index)
	var loadout: Dictionary = _compiled_loadouts[player_index]
	var weapon_stats: Dictionary = loadout.get("weapon_stats", {})
	var split_extra_count := int(weapon_stats.get("split_extra_count", 0))
	var spread_step := deg_to_rad(float(weapon_stats.get("split_spread_degrees", 15.0)))
	var projectile_count := 1 + split_extra_count
	if projectiles.get_child_count() >= int(MAX_ACTIVE_PROJECTILES / 2.0):
		projectile_count = 1
	var directions := _build_spread_directions(direction, projectile_count, spread_step)
	for projectile_direction in directions:
		var projectile = ProjectileSceneData.instantiate()
		projectile.global_position = origin
		var projectile_config := {
			"speed": float(weapon_stats.get("projectile_speed", 648.0)),
			"damage": int(round(float(weapon_stats.get("damage", 14.0)))),
			"color": shooter.player_config.tint,
			"shooter": shooter,
			"feedback_profile": "rifle",
			"impact_weight": 1.0,
			"max_distance": float(weapon_stats.get("range", 520.0)),
			"collision_half_width": float(weapon_stats.get("area", 4.0)),
			"pierce_count": int(weapon_stats.get("pierce_count", 0)),
			"ricochet_count": int(weapon_stats.get("ricochet_count", 0)),
			"ricochet_range": float(weapon_stats.get("ricochet_range", 200.0)),
			"leaves_fire_trail": bool(weapon_stats.get("leaves_fire_trail", false)),
			"trail_lifetime": float(weapon_stats.get("trail_lifetime", 1.5)),
			"trail_tick_interval": float(weapon_stats.get("trail_tick_interval", 0.5)),
			"trail_damage_percent": float(weapon_stats.get("trail_damage_percent", 0.3)),
			"knockback_force": float(weapon_stats.get("knockback_force", 0.0)),
			"weapon_id": str(loadout.get("weapon_id", "rifle")),
			"source_type": "weapon",
		}
		projectile.setup_from_config("player", projectile_direction, projectile_config)
		projectile.impact_requested.connect(_on_projectile_impact)
		projectiles.add_child(projectile)

func _on_player_primary_skill_requested(origin: Vector2, _direction: Vector2, stats: Dictionary) -> void:
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
	if projectiles.get_child_count() >= MAX_ACTIVE_PROJECTILES:
		return
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
	if projectiles.get_child_count() >= IMPACT_EFFECT_SOFT_CAP and impact_weight <= 1.0:
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
	var gold_amount := _get_gold_drop_amount(enemy.get_type_name())
	if gold_amount > 0:
		_spawn_gold_pickup(enemy.global_position, gold_amount)
	if enemy.get_type_name() != "boss" and randf() < HEALTH_DROP_CHANCE:
		_spawn_health_pickup(enemy.global_position, HEALTH_PICKUP_HEAL)

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

func _on_secondary_skill_trail_requested(_origin: Vector2, _color: Color) -> void:
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
	_auto_collect_all_gold()
	_award_survival_bonus()
	_award_modifier_gold_bonus()
	var gold_summary := "\nGold earned: %dg" % _room_gold_earned
	_pending_clear_summary = summary + gold_summary
	_lock_player_input(true)
	_end_active_encounter()
	if _room_type == "boss":
		_finish_room_progression(_pending_clear_summary)
		return
	_show_mutation_pick()

func _show_mutation_pick() -> void:
	_awaiting_mutation_pick = true
	_mutation_pick_ui = MutationPickUIScene.instantiate()
	_mutation_pick_ui.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	var options_by_player: Array = []
	var gold_per_player: Array = []
	var pick_costs: Array = MUTATION_PICK_COSTS
	var option_count := 3
	var rarity_filter := "common"
	if _room_type == "elite":
		pick_costs = [ELITE_RARE_PICK_COST]
		option_count = 1
		rarity_filter = "rare"
	for player_index in range(_player_nodes.size()):
		options_by_player.append(_mutation_system.roll_mutation_options(player_index, option_count, rarity_filter))
		gold_per_player.append(RunState.get_player_gold(player_index))
	_mutation_pick_ui.selections_confirmed.connect(_on_mutation_selections_confirmed)
	_mutation_pick_ui.configure_for_players(_player_configs, options_by_player, gold_per_player, pick_costs)
	ui_layer.add_child(_mutation_pick_ui)
	get_tree().paused = true

func _on_mutation_selections_confirmed(selections_per_player: Array) -> void:
	get_tree().paused = false
	for player_index in range(min(selections_per_player.size(), _player_nodes.size())):
		var selected_ids: Array = selections_per_player[player_index]
		for pick_index in range(selected_ids.size()):
			var mutation_id := str(selected_ids[pick_index])
			if mutation_id.is_empty():
				continue
			var cost: int = ELITE_RARE_PICK_COST if _room_type == "elite" else MUTATION_PICK_COSTS[mini(pick_index, MUTATION_PICK_COSTS.size() - 1)]
			if RunState.spend_player_gold(player_index, cost):
				_mutation_system.apply_mutation(player_index, mutation_id)
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
	if _temp_buff_system != null:
		_temp_buff_system.clear_all_buffs(_player_nodes)
	if _hold_zone != null and is_instance_valid(_hold_zone):
		_hold_zone.queue_free()
	_hold_zone = null
	if _fire_floor_modifier != null and is_instance_valid(_fire_floor_modifier):
		_fire_floor_modifier.queue_free()
	_fire_floor_modifier = null
	if _ice_zone_modifier != null and is_instance_valid(_ice_zone_modifier):
		_ice_zone_modifier.queue_free()
	_ice_zone_modifier = null
	if _mine_field_modifier != null and is_instance_valid(_mine_field_modifier):
		_mine_field_modifier.queue_free()
	_mine_field_modifier = null
	for child in projectiles.get_children():
		child.queue_free()
	for child in effects.get_children():
		child.queue_free()
	for enemy in _enemy_nodes:
		if enemy != null and is_instance_valid(enemy):
			enemy.queue_free()
	_enemy_nodes.clear()

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
	var max_duration := SURVIVE_DURATION
	var ratio := clampf(_room_timer_remaining / max(max_duration, 0.01), 0.0, 1.0)
	_timer_label.text = "Survive  %.1fs" % _room_timer_remaining if _room_type != "boss" else "Boss Fight"
	_timer_fill.scale = Vector2(1.0 if _room_type == "boss" else ratio, 1.0)
	if _hold_zone_status_label != null:
		if _hold_zone != null and is_instance_valid(_hold_zone):
			if _hold_zone.is_complete():
				_hold_zone_status_label.text = "Buff Active: %s +50%%!" % _format_buff_name(str(_hold_buff_offer.get("type", "")))
			else:
				_hold_zone_status_label.text = _hold_zone.get_progress_text()
		else:
			_hold_zone_status_label.text = ""
	for index in range(min(_player_inventory_huds.size(), _player_nodes.size())):
		_player_inventory_huds[index].update_hud({
			"header": "P%d" % (index + 1),
			"health_state": _player_nodes[index].get_health_state(),
			"health_status": _player_nodes[index].get_health_ratio_text(),
			"weapon": _player_nodes[index].get_weapon_hud_data(),
			"primary_skill": _player_nodes[index].get_primary_skill_hud_data(),
			"secondary_skill": _player_nodes[index].get_secondary_skill_hud_data(),
			"mutations": _mutation_system.get_active_mutations(index),
		})
	for index in range(min(_gold_labels.size(), _player_configs.size())):
		(_gold_labels[index] as Label).text = "%dg" % RunState.get_player_gold(index)

func _load_modifier_definitions() -> void:
	_modifier_definitions.clear()
	if not FileAccess.file_exists(MODIFIERS_DATA_PATH):
		return
	var file := FileAccess.open(MODIFIERS_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	for entry in ((parsed as Dictionary).get("modifiers", []) as Array):
		if not (entry is Dictionary):
			continue
		var definition: Dictionary = (entry as Dictionary).duplicate(true)
		var modifier_id := str(definition.get("id", ""))
		if modifier_id.is_empty():
			continue
		_modifier_definitions[modifier_id] = definition

func _populate_modifier_hud() -> void:
	if _modifier_hud == null:
		return
	for child in _modifier_hud.get_children():
		child.queue_free()
	for mod_id_variant in _active_modifiers:
		var mod_id := str(mod_id_variant)
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(0.0, 28.0)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = _get_modifier_chip_color(mod_id)
		style.set_border_width_all(1)
		style.border_color = _get_modifier_chip_color(mod_id).lightened(0.3)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.set_content_margin_all(6)
		chip.add_theme_stylebox_override("panel", style)
		var lbl := Label.new()
		lbl.text = _format_modifier_display_name(mod_id)
		lbl.add_theme_font_size_override("font_size", 14)
		chip.add_child(lbl)
		_modifier_hud.add_child(chip)

func _get_modifier_gold_bonus(mod_id: String) -> float:
	return float((_modifier_definitions.get(mod_id, {}) as Dictionary).get("gold_bonus", 0.0))

func _get_modifier_chip_color(mod_id: String) -> Color:
	var category := str((_modifier_definitions.get(mod_id, {}) as Dictionary).get("category", "minor"))
	return Color(0.85, 0.25, 0.2, 0.6) if category == "major" else Color(0.85, 0.65, 0.2, 0.6)

func _format_modifier_display_name(mod_id: String) -> String:
	var definition := _modifier_definitions.get(mod_id, {}) as Dictionary
	if not definition.is_empty():
		return str(definition.get("name", mod_id))
	var parts: Array = []
	for word in mod_id.split("_"):
		if not word.is_empty():
			parts.append(word.capitalize())
	return " ".join(parts)

func _format_buff_name(buff_type: String) -> String:
	match buff_type:
		"attack_speed":
			return "Attack Speed"
		"damage":
			return "Damage"
		_:
			return "Speed"

func _apply_ice_zone_modifier() -> void:
	var affected: Array = []
	if _ice_zone_modifier != null and is_instance_valid(_ice_zone_modifier):
		affected = _ice_zone_modifier.get_affected_players(_player_nodes)
	for player in _player_nodes:
		if player == null or not is_instance_valid(player):
			continue
		if affected.has(player):
			player.apply_zone_modifier("ice_zone", 0.67, 0.67)
		else:
			player.clear_zone_modifier("ice_zone")

func _on_hold_zone_completed() -> void:
	if _temp_buff_system == null or _hold_buff_offer.is_empty():
		return
	_temp_buff_system.apply_buff(_hold_buff_offer, _player_nodes)

func _update_elite_support_auras() -> void:
	var support_nodes: Array = []
	for enemy in _enemy_nodes:
		if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("is_alive") or not enemy.is_alive():
			continue
		if enemy.get_type_name() == "elite_support":
			support_nodes.append(enemy)
	var buffed_now: Array = []
	var debuffed_now: Array = []
	for support in support_nodes:
		for enemy in _enemy_nodes:
			if enemy == null or not is_instance_valid(enemy) or enemy == support or not enemy.has_method("is_alive") or not enemy.is_alive():
				continue
			if enemy.global_position.distance_to(support.global_position) <= 300.0:
				enemy.apply_aura(1.33, 1.33)
				if not buffed_now.has(enemy):
					buffed_now.append(enemy)
		for player in _player_nodes:
			if player == null or not is_instance_valid(player) or not player.has_method("is_alive") or not player.is_alive():
				continue
			if player.global_position.distance_to(support.global_position) <= 300.0:
				player.apply_zone_modifier("elite_support", 0.67, 0.67)
				if not debuffed_now.has(player):
					debuffed_now.append(player)
	for enemy in _aura_buffed_enemies:
		if buffed_now.has(enemy):
			continue
		if enemy != null and is_instance_valid(enemy) and enemy.has_method("clear_aura"):
			enemy.clear_aura()
	_aura_buffed_enemies = buffed_now
	for player in _aura_debuffed_players:
		if debuffed_now.has(player):
			continue
		if player != null and is_instance_valid(player):
			player.clear_zone_modifier("elite_support")
	_aura_debuffed_players = debuffed_now

func get_active_players() -> Array:
	var frame := Engine.get_physics_frames()
	if _active_players_cache_frame == frame:
		return _active_players_cache
	var active_players: Array = []
	for player in _player_nodes:
		if player != null and is_instance_valid(player) and player.is_alive():
			active_players.append(player)
	_active_players_cache = active_players
	_active_players_cache_frame = frame
	return _active_players_cache

func get_player_target_nodes() -> Array:
	return _player_nodes

func get_enemy_target_nodes() -> Array:
	return _enemy_nodes

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

func _get_gold_drop_amount(enemy_type_name: String) -> int:
	if enemy_type_name == "boss":
		return 0
	return GOLD_DROP_PER_ENEMY

func _spawn_gold_pickup(spawn_position: Vector2, amount: int) -> void:
	var pickup = GoldPickupSceneData.instantiate()
	pickup.amount = amount
	pickup.global_position = spawn_position
	pickups.add_child(pickup)

func _spawn_health_pickup(spawn_position: Vector2, heal_amount: int) -> void:
	var pickup = HealthPickupData.new()
	pickup.heal_amount = heal_amount
	pickup.global_position = spawn_position
	pickups.add_child(pickup)

func _update_gold_pickups(delta: float) -> void:
	var eligible_players := _get_pickup_eligible_players()
	if eligible_players.is_empty():
		return
	var to_remove: Array = []
	for pickup in pickups.get_children():
		if not is_instance_valid(pickup):
			continue
		var nearest_player = null
		var nearest_distance := INF
		for player in eligible_players:
			var dist: float = player.global_position.distance_to(pickup.global_position)
			if dist < nearest_distance:
				nearest_distance = dist
				nearest_player = player
		if nearest_player == null:
			continue
		var magnet_radius := GoldPickupData.MAGNET_RADIUS if pickup is GoldPickupData else HealthPickupData.MAGNET_RADIUS
		var magnet_acceleration := GoldPickupData.MAGNET_ACCELERATION if pickup is GoldPickupData else HealthPickupData.MAGNET_ACCELERATION
		var magnet_max_speed := GoldPickupData.MAGNET_MAX_SPEED if pickup is GoldPickupData else HealthPickupData.MAGNET_MAX_SPEED
		var collect_radius := GoldPickupData.COLLECT_RADIUS if pickup is GoldPickupData else HealthPickupData.COLLECT_RADIUS
		if nearest_distance < magnet_radius:
			var direction: Vector2 = (nearest_player.global_position - pickup.global_position).normalized()
			pickup.magnet_speed = minf(pickup.magnet_speed + magnet_acceleration * delta, magnet_max_speed)
			pickup.global_position += direction * pickup.magnet_speed * delta
			nearest_distance = nearest_player.global_position.distance_to(pickup.global_position)
		if nearest_distance < collect_radius:
			if pickup is GoldPickupData:
				RunState.add_gold_to_all_players(pickup.amount)
				_room_gold_earned += pickup.amount
				to_remove.append(pickup)
			elif pickup is HealthPickupData:
				if nearest_player.heal(int(pickup.heal_amount)):
					_sync_player_health_state(nearest_player)
					to_remove.append(pickup)
	for pickup in to_remove:
		pickup.queue_free()

func _auto_collect_all_gold() -> void:
	for pickup in pickups.get_children():
		if not is_instance_valid(pickup):
			continue
		if pickup is GoldPickupData:
			RunState.add_gold_to_all_players(pickup.amount)
			_room_gold_earned += pickup.amount
		pickup.queue_free()

func _award_survival_bonus() -> void:
	RunState.add_gold_to_all_players(SURVIVAL_BONUS_GOLD)
	_room_gold_earned += SURVIVAL_BONUS_GOLD

func _award_modifier_gold_bonus() -> void:
	if _room_gold_multiplier <= 1.0:
		return
	var base_gold_earned := _room_gold_earned
	if base_gold_earned <= 0:
		return
	var bonus_gold := int(round(float(base_gold_earned) * (_room_gold_multiplier - 1.0)))
	if bonus_gold <= 0:
		return
	RunState.add_gold_to_all_players(bonus_gold)
	_room_gold_earned += bonus_gold

func _get_pickup_eligible_players() -> Array:
	var eligible_players: Array = []
	for player in _player_nodes:
		if player == null or not is_instance_valid(player) or not player.has_method("is_alive") or not player.is_alive():
			continue
		eligible_players.append(player)
	return eligible_players

func _sync_player_health_state(player) -> void:
	if player == null or not is_instance_valid(player):
		return
	var player_index := int(player.player_index)
	if player_index < 0 or player_index >= RunState.player_health_states.size():
		return
	RunState.player_health_states[player_index] = player.get_health_state()

func _get_shop_gamepad_device(player_index: int) -> int:
	if player_index >= 0 and player_index < _player_nodes.size():
		var player = _player_nodes[player_index]
		if player != null and is_instance_valid(player):
			return int(player.gamepad_device_id)
	var config = _player_configs[player_index]
	return int(config.player_id) - 1

func _event_matches_action(event: InputEvent, action_name: String) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	return event.is_action_pressed(action_name)

func _unhandled_input(event: InputEvent) -> void:
	if pause_panel.visible:
		_handle_pause_input(event)
		get_viewport().set_input_as_handled()
		return
	if _shop_ui != null:
		_handle_shop_input(event)
		return
	if _awaiting_mutation_pick:
		return
	if not _is_pause_request(event):
		return
	_show_pause_menu()
	get_viewport().set_input_as_handled()

func _show_pause_menu() -> void:
	pause_panel.visible = true
	_pause_selection_index = 0
	_focus_pause_selection()
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

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _invalidate_runtime_caches() -> void:
	_active_players_cache_frame = -1

func _handle_pause_input(event: InputEvent) -> void:
	var direction := _get_pause_direction(event)
	if direction != 0:
		var buttons := _get_pause_buttons()
		if not buttons.is_empty():
			_pause_selection_index = wrapi(_pause_selection_index + direction, 0, buttons.size())
			_focus_pause_selection()
		return
	if _is_pause_confirm_pressed(event):
		_activate_pause_selection()
		return
	if _is_pause_cancel_pressed(event):
		_on_resume_pressed()

func _get_pause_buttons() -> Array:
	var buttons: Array = []
	for button in [resume_button, pause_settings_button, pause_retry_button, pause_main_menu_button]:
		if button != null and is_instance_valid(button) and button.visible:
			buttons.append(button)
	return buttons

func _focus_pause_selection() -> void:
	var buttons := _get_pause_buttons()
	if buttons.is_empty():
		return
	_pause_selection_index = clampi(_pause_selection_index, 0, buttons.size() - 1)
	(buttons[_pause_selection_index] as Button).grab_focus()

func _activate_pause_selection() -> void:
	var buttons := _get_pause_buttons()
	if buttons.is_empty():
		return
	_pause_selection_index = clampi(_pause_selection_index, 0, buttons.size() - 1)
	var selected: Button = buttons[_pause_selection_index] as Button
	if selected == resume_button:
		_on_resume_pressed()
	elif selected == pause_retry_button:
		_on_retry_pressed()
	elif selected == pause_main_menu_button:
		_on_main_menu_pressed()
	elif selected == pause_settings_button and pause_settings_button.visible:
		pause_settings_button.pressed.emit()

func _get_pause_direction(event: InputEvent) -> int:
	if event is InputEventJoypadButton:
		var joy_button := event as InputEventJoypadButton
		if joy_button.pressed and _is_player_gamepad_device(joy_button.device):
			if joy_button.button_index == JOY_BUTTON_DPAD_UP:
				return -1
			if joy_button.button_index == JOY_BUTTON_DPAD_DOWN:
				return 1
	for player_index in range(_player_configs.size()):
		if _event_matches_action(event, "p%d_move_up" % (player_index + 1)):
			return -1
		if _event_matches_action(event, "p%d_move_down" % (player_index + 1)):
			return 1
	return 0

func _is_pause_confirm_pressed(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		var joy_button := event as InputEventJoypadButton
		return joy_button.pressed and _is_player_gamepad_device(joy_button.device) and joy_button.button_index == JOY_BUTTON_A
	for player_index in range(_player_configs.size()):
		if _event_matches_action(event, "p%d_secondary" % (player_index + 1)):
			return true
	return false

func _is_pause_cancel_pressed(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		var joy_button := event as InputEventJoypadButton
		if joy_button.pressed and _is_player_gamepad_device(joy_button.device):
			return joy_button.button_index == JOY_BUTTON_B or joy_button.button_index == JOY_BUTTON_START
	for player_index in range(_player_configs.size()):
		if _event_matches_action(event, "p%d_dash" % (player_index + 1)):
			return true
	return event.is_action_pressed("ui_cancel")

func _is_player_gamepad_device(device_id: int) -> bool:
	for player in _player_nodes:
		if player != null and is_instance_valid(player) and int(player.gamepad_device_id) == device_id:
			return true
	return false
