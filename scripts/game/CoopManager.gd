extends Node2D

const EnemySceneData = preload("res://scenes/enemies/Enemy.tscn")
const ProjectileSceneData = preload("res://scenes/weapons/Projectile.tscn")
const MutationSystemData = preload("res://scripts/game/MutationSystem.gd")
const AbilityRegistryData = preload("res://scripts/game/AbilityRegistry.gd")
const HudPaletteData = preload("res://scripts/game/HudPalette.gd")
const CoopFormat = preload("res://scripts/game/CoopFormat.gd")
const EnemyTypes = preload("res://scripts/game/EnemyTypes.gd")
const ArenaGeometry = preload("res://scripts/game/ArenaGeometry.gd")
const ProjectileSystemData = preload("res://scripts/game/ProjectileSystem.gd")
const ArenaVisualsData = preload("res://scripts/game/ArenaVisuals.gd")
const GameHudData = preload("res://scripts/game/GameHud.gd")
const WaveDirectorData = preload("res://scripts/game/WaveDirector.gd")
const MutationPickUIScene = preload("res://scenes/ui/MutationPickUI.tscn")
const TempBuffSystemData = preload("res://scripts/buffs/TempBuffSystem.gd")
const HoldZoneObjectiveData = preload("res://scripts/objectives/HoldZoneObjective.gd")
const FireFloorModifierData = preload("res://scripts/modifiers/FireFloorModifier.gd")
const IceZoneModifierData = preload("res://scripts/modifiers/IceZoneModifier.gd")
const MineFieldModifierData = preload("res://scripts/modifiers/MineFieldModifier.gd")
const ShrinkingArenaModifierData = preload("res://scripts/modifiers/ShrinkingArenaModifier.gd")
const DecoyNodeData = preload("res://scripts/game/DecoyNode.gd")
const TurretNodeData = preload("res://scripts/game/TurretNode.gd")
const OrbitNodeData = preload("res://scripts/game/OrbitNode.gd")
const CollectorOrbData = preload("res://scripts/game/CollectorOrb.gd")
const HealthPickupData = preload("res://scripts/pickups/HealthPickup.gd")
const HazardZoneData = preload("res://scripts/game/HazardZone.gd")
const AbilityMineData = preload("res://scripts/game/AbilityMine.gd")
const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")
const IconFactoryData = preload("res://scripts/ui/IconFactory.gd")
const HitStopManagerData = preload("res://scripts/juice/HitStopManager.gd")
const PauseInputProxyData = preload("res://scripts/ui/PauseInputProxy.gd")
const EncyclopediaUIData = preload("res://scripts/ui/EncyclopediaUI.gd")

const MODIFIERS_DATA_PATH := "res://data/modifiers.json"

const ARENA_SIZE := Vector2(3600.0, 2100.0)
const ARENA_RECT := Rect2(Vector2.ZERO, ARENA_SIZE)
const ARENA_CENTER := Vector2(ARENA_SIZE.x * 0.5, ARENA_SIZE.y * 0.5)
const ARENA_MARGIN := 72.0
const BOSS_PLAYER_SPAWN_DISTANCE := 720.0
const FLOOR_GRID_SPACING := 160.0
const FLOOR_GRID_MAJOR_INTERVAL := 4
const ARENA_WALL_VISUAL_WIDTH := 18.0
const FLOOR_GRID_PLAYER_HIGHLIGHT_RADIUS := 520.0
const REVIVE_RADIUS := 150.0
const REVIVE_HOLD_DURATION := 1.2
const HUD_REFRESH_INTERVAL := 0.08
const BOSS_HIT_FEEDBACK_INTERVAL := 0.22
const COLLECTOR_TARGET := 8
const COLLECTOR_TOTAL_SPAWN := 12
const COLLECTOR_SPAWN_INTERVAL := 2.5
const HEALTH_DROP_CHANCE := 0.06
const MUTATION_REROLL_BASE_COST := 100
const ENEMY_SEPARATION_CELL_SIZE := 96.0
const MOMENTUM_THRESHOLDS := [10, 25, 45, 70]
const MOMENTUM_MOVE_BONUSES := [0.0, 0.10, 0.20, 0.35, 0.50]
const MOMENTUM_FIRE_RATE_BONUSES := [0.0, 0.15, 0.30, 0.50, 0.75]
const HUD_SLOT_2_COLOR := HudPaletteData.SLOT_2_COLOR
const GAMEPLAY_INPUT_SUFFIXES := [
	"move_left",
	"move_right",
	"move_up",
	"move_down",
	"aim_left",
	"aim_right",
	"aim_up",
	"aim_down",
	"fire",
	"secondary",
	"dash",
	"switch_primary",
	"switch_secondary",
]
const DEBUG_ENEMY_SPAWN_CATALOG := [
	{"label": "Chaser", "value": "chaser"},
	{"label": "Charger", "value": "charger"},
	{"label": "Spitter", "value": "spitter"},
	{"label": "Splitter", "value": "splitter"},
	{"label": "Splitter Mini", "value": "splitter_mini"},
	{"label": "Bomber", "value": "bomber"},
	{"label": "Champion Charger", "value": "elite_charger"},
	{"label": "Champion Spitter", "value": "elite_spitter"},
	{"label": "Champion Support", "value": "elite_support"},
	{"label": "Champion Warden", "value": "boss_warden"},
	{"label": "Champion Hydra", "value": "boss_hydra"},
	{"label": "Champion Hive", "value": "boss_hive"},
	{"label": "Champion Pulsar", "value": "boss_pulsar"},
]

const XP_PER_ENEMY_TYPE := {
	"chaser": 10,
	"charger": 20,
	"spitter": 15,
	"splitter": 12,
	"splitter_mini": 5,
	"bomber": 18,
	"elite_charger": 50,
	"elite_spitter": 50,
	"elite_support": 50,
	"boss": 0,
}

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
@onready var modifier_tint: CanvasModulate = $ModifierTint
@onready var camera: Camera2D = $Camera2D
@onready var screen_shake = $Camera2D/ScreenShake
@onready var screen_effects = $ScreenEffects
@onready var top_wall: CollisionShape2D = $ArenaBounds/TopWall
@onready var bottom_wall: CollisionShape2D = $ArenaBounds/BottomWall
@onready var left_wall: CollisionShape2D = $ArenaBounds/LeftWall
@onready var right_wall: CollisionShape2D = $ArenaBounds/RightWall
@onready var ui_layer: CanvasLayer = $UI
@onready var pause_panel: Panel = $UI/PausePanel
@onready var resume_button: Button = $UI/PausePanel/CenterContainer/PauseLayout/ResumeButton
@onready var pause_retry_button: Button = $UI/PausePanel/CenterContainer/PauseLayout/PauseRetryButton
@onready var pause_main_menu_button: Button = $UI/PausePanel/CenterContainer/PauseLayout/PauseMainMenuButton

var _player_configs: Array = []
var _player_nodes: Array = []
var _enemy_nodes: Array = []
var _compiled_loadouts: Array = []
var _mutation_system = MutationSystemData.new()
var _ability_registry = AbilityRegistryData.new()
var _room_config: Dictionary = {}
var _room_type := "combat"
var _room_enemy_pool: Array = []
var _room_depth := 1
var _room_rare_bonus := 0.0
var _room_clear_started := false
var _awaiting_mutation_pick := false
var _room_elapsed := 0.0
var _enemies_killed := 0
var _champions_killed := 0
var _room_max_momentum_tier := 0
var _room_score_recorded := false
var _pending_pick_consumes_levelup := false
var _pending_champion_bonus_pick := false
var _mutation_pick_round_force_rare := false
var _mutation_pick_reroll_counts: Array = []
var _pending_clear_summary := ""
var _next_boss_hit_feedback_at := 0.0
var _revive_progress_by_player_id: Dictionary = {}
var _mutation_pick_ui = null
var _active_modifiers: Array = []
var _arena_visuals = null
var _hud = null
var _wave_director = null
var _modifier_definitions: Dictionary = {}
var _minor_modifier_flags := {
	"accelerating_waves": false,
	"enemy_speed": false,
	"swarm": false,
	"shielded": false,
	"explosive_death": false,
}
var _hold_zone = null
var _temp_buff_system = null
var _hold_buff_offer: Dictionary = {}
var _side_objective_id := ""
var _side_objective_completed := false
var _kill_streak_target := 0
var _kill_streak_progress := 0
var _momentum_progress_by_player: Array = []
var _momentum_tier_by_player: Array = []
var _collector_collected := 0
var _collector_spawned := 0
var _collector_spawn_timer := COLLECTOR_SPAWN_INTERVAL
var _collector_orbs: Array = []
var _fire_floor_modifier = null
var _ice_zone_modifier = null
var _mine_field_modifier = null
var _shrinking_arena_modifier = null
var _active_decoys: Array = []
var _active_turrets: Array = []
var _active_orbits: Array = []
var _active_hazards: Array = []
var _active_mines: Array = []
var _next_hud_refresh_at := 0.0
var _scheduled_enemy_shockwaves: Array = []
var _scheduled_player_shockwaves: Array = []
var _scheduled_enemy_hazards: Array = []
var _scheduled_pulsar_emps: Array = []
var _enemy_separation_grid: Dictionary = {}
var _enemy_separation_grid_frame := -1
var _game_paused := false
var _pause_input_proxy = null
var _projectile_system = null
var _screen_effect_level := "full"
var _hit_stop_manager = null
var _debug_overlay_panel: PanelContainer = null
var _debug_spawn_option: OptionButton = null
var _debug_weapon_option: OptionButton = null
var _debug_god_check: CheckBox = null

func configure_players(configs: Array) -> void:
	_player_configs = configs.duplicate()

func configure_room(room_config: Dictionary) -> void:
	_room_config = room_config.duplicate(true)

func _ready() -> void:
	_ensure_debug_overlay_action()
	if player_scene == null:
		player_scene = load("res://scenes/player/Player.tscn")
	_hit_stop_manager = HitStopManagerData.new()
	add_child(_hit_stop_manager)
	if not RunState.level_up.is_connected(_on_run_level_up):
		RunState.level_up.connect(_on_run_level_up)
	_hide_legacy_ui()
	_bind_ui()
	_load_modifier_definitions()
	_projectile_system = ProjectileSystemData.new()
	_projectile_system.name = "ProjectileSystem"
	_projectile_system.setup(self, projectiles, effects)
	add_child(_projectile_system)
	_arena_visuals = ArenaVisualsData.new()
	_arena_visuals.name = "ArenaVisuals"
	_arena_visuals.setup(
		self,
		floor_visual,
		floor_grid,
		top_wall,
		bottom_wall,
		left_wall,
		right_wall,
		exit_zone,
		exit_zone_shape,
		exit_zone_visual,
		camera,
		ARENA_SIZE,
		ARENA_RECT,
		ARENA_CENTER,
		ARENA_MARGIN,
		FLOOR_GRID_SPACING,
		FLOOR_GRID_MAJOR_INTERVAL,
		ARENA_WALL_VISUAL_WIDTH,
		FLOOR_GRID_PLAYER_HIGHLIGHT_RADIUS
	)
	add_child(_arena_visuals)
	_arena_visuals.rebuild_arena()
	_wave_director = WaveDirectorData.new()
	_wave_director.name = "WaveDirector"
	_wave_director.setup(self, enemies)
	add_child(_wave_director)
	_hud = GameHudData.new()
	_hud.name = "GameHud"
	_hud.setup(self, ui_layer)
	ui_layer.add_child(_hud)
	_build_hud()
	_build_debug_overlay()
	_spawn_players()
	_start_room()

func _bind_ui() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	pause_retry_button.pressed.connect(_on_retry_pressed)
	pause_main_menu_button.pressed.connect(_on_main_menu_pressed)
	_configure_pause_focus()
	_pause_input_proxy = PauseInputProxyData.new()
	pause_panel.add_child(_pause_input_proxy)
	_pause_input_proxy.pause_pressed.connect(_on_pause_proxy_pressed)

func _configure_pause_focus() -> void:
	var buttons := [resume_button, pause_retry_button, pause_main_menu_button]
	for index in range(buttons.size()):
		var button := buttons[index] as Button
		button.focus_mode = Control.FOCUS_ALL
		var previous_button := buttons[(index - 1 + buttons.size()) % buttons.size()] as Button
		var next_button := buttons[(index + 1) % buttons.size()] as Button
		button.focus_neighbor_top = button.get_path_to(previous_button)
		button.focus_neighbor_bottom = button.get_path_to(next_button)

func _apply_screen_effect_level() -> void:
	if screen_effects != null and screen_effects.has_method("set_effect_level"):
		screen_effects.set_effect_level(_screen_effect_level)

func _screen_effects_enabled() -> bool:
	return _screen_effect_level != "off"

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
		"ResultPanel",
	]:
		var node := ui_layer.get_node_or_null(node_path)
		if node != null:
			node.visible = false
	pause_panel.visible = false

func _build_hud() -> void:
	_hud.build()

func _build_debug_overlay() -> void:
	if not _is_debug_menu_enabled():
		return
	_debug_overlay_panel = PanelContainer.new()
	_debug_overlay_panel.visible = false
	_debug_overlay_panel.position = Vector2(28.0, 136.0)
	_debug_overlay_panel.custom_minimum_size = Vector2(360.0, 0.0)
	ui_layer.add_child(_debug_overlay_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_debug_overlay_panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	var title := Label.new()
	title.text = "Debug Overlay"
	title.add_theme_font_size_override("font_size", 17)
	layout.add_child(title)
	var spawn_row := HBoxContainer.new()
	spawn_row.add_theme_constant_override("separation", 8)
	layout.add_child(spawn_row)
	_debug_spawn_option = OptionButton.new()
	_debug_spawn_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in DEBUG_ENEMY_SPAWN_CATALOG:
		_debug_spawn_option.add_item(str(entry["label"]))
		_debug_spawn_option.set_item_metadata(_debug_spawn_option.item_count - 1, str(entry["value"]))
	spawn_row.add_child(_debug_spawn_option)
	var spawn_button := Button.new()
	spawn_button.text = "Spawn Selected"
	spawn_button.pressed.connect(_on_debug_spawn_pressed)
	spawn_row.add_child(spawn_button)
	var weapon_row := HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 8)
	layout.add_child(weapon_row)
	_debug_weapon_option = OptionButton.new()
	_debug_weapon_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for weapon in RunState.get_weapon_catalog():
		var weapon_dict: Dictionary = weapon as Dictionary
		var weapon_id := str(weapon_dict.get("id", ""))
		if weapon_id.is_empty():
			continue
		_debug_weapon_option.add_item(str(weapon_dict.get("name", weapon_id.capitalize())))
		_debug_weapon_option.set_item_metadata(_debug_weapon_option.item_count - 1, weapon_id)
	weapon_row.add_child(_debug_weapon_option)
	var set_weapon_button := Button.new()
	set_weapon_button.text = "Set Weapon"
	set_weapon_button.pressed.connect(_on_debug_set_weapon_pressed)
	weapon_row.add_child(set_weapon_button)
	var level_button := Button.new()
	level_button.text = "Give P1 Weapon Level"
	level_button.pressed.connect(_on_debug_give_weapon_level_pressed)
	layout.add_child(level_button)
	var clear_button := Button.new()
	clear_button.text = "Clear Enemies"
	clear_button.pressed.connect(_on_debug_clear_enemies_pressed)
	layout.add_child(clear_button)
	_debug_god_check = CheckBox.new()
	_debug_god_check.text = "God Mode"
	_debug_god_check.button_pressed = RunState.debug_profiling
	_debug_god_check.toggled.connect(_on_debug_god_toggled)
	layout.add_child(_debug_god_check)

func _spawn_players() -> void:
	for child in players.get_children():
		child.queue_free()
	_player_nodes.clear()
	var connected_gamepads: Array = Input.get_connected_joypads()
	var gamepad_cursor := 0
	var assigned_gamepads: Array = []
	for index in range(_player_configs.size()):
		var assigned_gamepad := -1
		var config = _player_configs[index]
		var uses_gamepad: bool = config.has_method("uses_gamepad") and config.uses_gamepad()
		if uses_gamepad and gamepad_cursor < connected_gamepads.size():
			assigned_gamepad = int(connected_gamepads[gamepad_cursor])
			gamepad_cursor += 1
		assigned_gamepads.append(assigned_gamepad)
	_stamp_player_gamepad_input_actions(assigned_gamepads)
	for index in range(_player_configs.size()):
		var player = player_scene.instantiate()
		var assigned_gamepad := int(assigned_gamepads[index])
		player.player_index = index
		players.add_child(player)
		player.global_position = _get_player_spawn_position(index)
		player.setup(_player_configs[index], assigned_gamepad)
		player.fire_requested.connect(_on_player_fire_requested)
		player.ability_activated.connect(_on_player_ability_activated)
		player.downed.connect(_on_player_downed)
		player.revived.connect(_on_player_revived)
		player.damage_taken.connect(_on_player_damage_taken)
		player.muzzle_flash_requested.connect(_on_muzzle_flash_requested)
		player.shield_burst_requested.connect(_on_player_shield_burst_requested)
		_player_nodes.append(player)
	if camera.has_method("set_players"):
		camera.set_players(_player_nodes)
		camera.global_position = ARENA_CENTER

func _stamp_player_gamepad_input_actions(assigned_gamepads: Array) -> void:
	var controller_layouts: Dictionary = {}
	for player_index in range(assigned_gamepads.size()):
		var player_id := player_index + 1
		for suffix in GAMEPLAY_INPUT_SUFFIXES:
			var action := "p%d_%s" % [player_id, str(suffix)]
			if not InputMap.has_action(action):
				InputMap.add_action(action)
			var layout_events: Array = []
			for event in InputMap.action_get_events(action):
				if event is InputEventJoypadButton or event is InputEventJoypadMotion:
					layout_events.append((event as InputEvent).duplicate())
			controller_layouts[action] = layout_events
	for player_index in range(assigned_gamepads.size()):
		var player_id := player_index + 1
		var assigned_gamepad := int(assigned_gamepads[player_index])
		for suffix in GAMEPLAY_INPUT_SUFFIXES:
			var action := "p%d_%s" % [player_id, str(suffix)]
			var preserved_events: Array = []
			for event in InputMap.action_get_events(action):
				if event is InputEventJoypadButton or event is InputEventJoypadMotion:
					if int((event as InputEvent).device) != -1:
						continue
				preserved_events.append((event as InputEvent).duplicate())
			InputMap.action_erase_events(action)
			for event in preserved_events:
				InputMap.action_add_event(action, event)
			if assigned_gamepad < 0:
				continue
			for layout_event in (controller_layouts.get(action, []) as Array):
				var stamped_event := (layout_event as InputEvent).duplicate()
				stamped_event.device = assigned_gamepad
				InputMap.action_add_event(action, stamped_event)

func _rebuild_player_loadouts() -> void:
	_compiled_loadouts.clear()
	for index in range(_player_nodes.size()):
		var base_loadout: Dictionary = RunState.get_player_runtime_loadout_for(index)
		var compiled_weapon := _mutation_system.get_compiled_weapon_stats(index, (base_loadout.get("weapon_stats", {}) as Dictionary))
		var compiled_loadout := {
			"weapon_id": str(base_loadout.get("weapon_id", "rifle")),
			"weapon_name": str(base_loadout.get("weapon_name", "Rifle")),
			"weapon_level": int(base_loadout.get("weapon_level", 1)),
			"weapon_stats": compiled_weapon,
			"ability_slot_1": _build_runtime_ability(index, (base_loadout.get("ability_slot_1", {}) as Dictionary).duplicate(true)),
			"ability_slot_2": _build_runtime_ability(index, (base_loadout.get("ability_slot_2", {}) as Dictionary).duplicate(true)),
			"ability_slot_1_id": str(base_loadout.get("ability_slot_1_id", "overcharge")),
			"ability_slot_2_id": str(base_loadout.get("ability_slot_2_id", "dash")),
			"mutations": _mutation_system.get_active_mutations(index),
			"move_speed": float(base_loadout.get("move_speed", 560.0)),
			"move_speed_bonus": _mutation_system.get_move_speed_bonus(index),
			"max_health": int(round(float(base_loadout.get("max_health", 100)) * _mutation_system.get_max_health_multiplier(index))),
			"heal_disabled": _mutation_system.is_healing_disabled(index),
		}
		_compiled_loadouts.append(compiled_loadout)
		_player_nodes[index].apply_loadout(compiled_loadout)
		if index < _momentum_tier_by_player.size():
			_apply_momentum_to_player(index)

func _restore_momentum() -> void:
	_momentum_progress_by_player.clear()
	_momentum_tier_by_player.clear()
	for index in range(_player_nodes.size()):
		var state := RunState.get_momentum_state(index)
		_momentum_progress_by_player.append(int(state.get("progress", 0)))
		_momentum_tier_by_player.append(int(state.get("tier", 0)))
		_room_max_momentum_tier = maxi(_room_max_momentum_tier, int(state.get("tier", 0)))
		_apply_momentum_to_player(index)

func _gain_shared_momentum() -> void:
	for index in range(_player_nodes.size()):
		_momentum_progress_by_player[index] = int(_momentum_progress_by_player[index]) + 1
		_update_momentum_tier(index)
		_store_momentum(index)

func _drop_player_momentum(player_index: int) -> void:
	if player_index < 0 or player_index >= _momentum_tier_by_player.size():
		return
	var new_tier: int = max(0, int(_momentum_tier_by_player[player_index]) - 2)
	_momentum_tier_by_player[player_index] = new_tier
	_momentum_progress_by_player[player_index] = _get_min_progress_for_momentum_tier(new_tier)
	_apply_momentum_to_player(player_index)
	_store_momentum(player_index)

func _update_momentum_tier(player_index: int) -> void:
	if player_index < 0 or player_index >= _momentum_progress_by_player.size():
		return
	var previous_tier := int(_momentum_tier_by_player[player_index]) if player_index < _momentum_tier_by_player.size() else 0
	var progress := int(_momentum_progress_by_player[player_index])
	var tier := 0
	for threshold_index in range(MOMENTUM_THRESHOLDS.size()):
		if progress >= int(MOMENTUM_THRESHOLDS[threshold_index]):
			tier = threshold_index + 1
	_momentum_tier_by_player[player_index] = tier
	_room_max_momentum_tier = maxi(_room_max_momentum_tier, tier)
	if tier > previous_tier:
		_on_momentum_tier_gained(tier)
	_apply_momentum_to_player(player_index)

func _on_momentum_tier_gained(tier: int) -> void:
	# Subtle reward pulse on climbing a momentum tier (kept light — these come often in good play).
	_play_sfx("play_pickup", [0.6 + 0.18 * float(tier)])
	_spawn_screen_flash(Color(0.42, 1.0, 0.86, 0.05 + 0.02 * float(tier)), 0.18)

func _store_momentum(player_index: int) -> void:
	if player_index < 0 or player_index >= _momentum_tier_by_player.size() or player_index >= _momentum_progress_by_player.size():
		return
	RunState.set_momentum_state(player_index, int(_momentum_tier_by_player[player_index]), int(_momentum_progress_by_player[player_index]))

func _apply_momentum_to_player(player_index: int) -> void:
	if player_index < 0 or player_index >= _player_nodes.size():
		return
	var player = _player_nodes[player_index]
	if player == null or not is_instance_valid(player) or not player.has_method("set_momentum_tier"):
		return
	var tier := int(_momentum_tier_by_player[player_index]) if player_index < _momentum_tier_by_player.size() else 0
	player.set_momentum_tier(
		tier,
		float(MOMENTUM_MOVE_BONUSES[tier]),
		float(MOMENTUM_FIRE_RATE_BONUSES[tier])
	)

func _get_min_progress_for_momentum_tier(tier: int) -> int:
	if tier <= 0:
		return 0
	return int(MOMENTUM_THRESHOLDS[clampi(tier, 1, 4) - 1])

func _build_runtime_ability(player_index: int, ability_definition: Dictionary) -> Dictionary:
	if ability_definition.is_empty():
		return {}
	var stats: Dictionary = (ability_definition.get("stats", {}) as Dictionary).duplicate(true)
	var ability_id := str(ability_definition.get("id", ""))
	var rare_effects := _mutation_system.get_ability_rare_effects(player_index, ability_id)
	for key in rare_effects.keys():
		stats[str(key)] = rare_effects[key]
	var cooldown_mult := 1.0 - _mutation_system.get_ability_cooldown_reduction(player_index)
	var area_mult := _mutation_system.get_ability_area_multiplier(player_index)
	var duration_mult := _mutation_system.get_ability_duration_multiplier(player_index)
	var ability_type := str(ability_definition.get("type", "instant"))
	var scales_duration := ability_type != "instant" and ability_type != "movement"
	var base_cooldown := float(ability_definition.get("cooldown", 1.0))
	var cooldown := maxf(0.2, base_cooldown * maxf(cooldown_mult, 0.1))
	var duration := maxf(0.0, float(ability_definition.get("duration", 0.0)) * (duration_mult if scales_duration else 1.0))
	for stat_key in ["radius", "orbit_radius", "distance"]:
		if stats.has(stat_key):
			stats[stat_key] = float(stats[stat_key]) * area_mult
	for stat_key in ["duration", "trail_duration"]:
		if scales_duration and stats.has(stat_key):
			stats[stat_key] = float(stats[stat_key]) * duration_mult
	if ability_id == "minefield" and stats.has("mine_lifetime"):
		stats["mine_lifetime"] = float(stats["mine_lifetime"]) * duration_mult
	return {
		"id": ability_id,
		"name": str(ability_definition.get("name", "Ability")),
		"type": ability_type,
		"cooldown": cooldown,
		"base_cooldown": base_cooldown,
		"duration": duration,
		"stats": stats,
	}

func _start_room() -> void:
	_clear_runtime_nodes()
	_projectile_system.ensure_renderer()
	_prewarm_combat_vfx()
	_set_game_paused(false)
	_set_music_context("combat")
	_spawn_screen_flash(Color(0.0, 0.0, 0.0, 0.5), 0.4)  # room-intro fade-in from black
	_rebuild_player_loadouts()
	_room_max_momentum_tier = 0
	_restore_momentum()
	_room_clear_started = false
	_awaiting_mutation_pick = false
	_pending_pick_consumes_levelup = false
	_pending_champion_bonus_pick = false
	_next_boss_hit_feedback_at = 0.0
	_room_elapsed = 0.0
	_room_type = str(_room_config.get("room_type", "combat"))
	_room_enemy_pool = ( _room_config.get("enemy_pool", []) as Array).duplicate()
	_room_depth = int(_room_config.get("depth", 1))
	_room_rare_bonus = maxf(float(_room_config.get("rare_bonus", 0.0)), 0.0)
	_enemies_killed = 0
	_champions_killed = 0
	_room_score_recorded = false
	_wave_director.start_room(_room_config, _room_enemy_pool, _room_depth)
	_side_objective_id = str(_room_config.get("side_objective", ""))
	_side_objective_completed = false
	_kill_streak_progress = 0
	_collector_collected = 0
	_collector_spawned = 0
	_collector_spawn_timer = COLLECTOR_SPAWN_INTERVAL
	_arena_visuals.apply_arena_color()
	if _temp_buff_system != null:
		_temp_buff_system.clear_all_buffs(_player_nodes)
	_temp_buff_system = TempBuffSystemData.new()
	for player in _player_nodes:
		if player == null or not is_instance_valid(player):
			continue
		if player.is_downed():
			player.revive(player.max_health)
		else:
			player.current_health = player.max_health
		player.set_input_locked(false)
		player.health_changed.emit(player.current_health, player.max_health)
		player.global_position = _get_player_spawn_position(int(player.player_index))
	_setup_side_objective()
	_apply_active_modifiers()
	_wave_director.spawn_opening_burst()
	_refresh_hud()

func _clear_runtime_nodes() -> void:
	for node in [projectiles, enemies, pickups, effects]:
		for child in node.get_children():
			child.queue_free()
	_enemy_nodes.clear()
	_active_decoys.clear()
	_active_turrets.clear()
	_active_orbits.clear()
	_active_hazards.clear()
	_active_mines.clear()
	if _projectile_system != null:
		_projectile_system.clear_runtime()
	_collector_orbs.clear()
	_hold_zone = null
	_fire_floor_modifier = null
	_ice_zone_modifier = null
	_mine_field_modifier = null
	_shrinking_arena_modifier = null
	_scheduled_enemy_shockwaves.clear()
	_scheduled_player_shockwaves.clear()
	_scheduled_enemy_hazards.clear()
	_scheduled_pulsar_emps.clear()
	_enemy_separation_grid.clear()
	_enemy_separation_grid_frame = -1
	_hold_buff_offer.clear()
	_invalidate_runtime_caches()

func _prewarm_combat_vfx() -> void:
	var prewarm_position := ARENA_CENTER
	var samples: Array = [
		ParticleFactoryData.create_muzzle_flash(Color(1.0, 0.76, 0.48, 0.82), Vector2.RIGHT, "enemy", 1.0),
		ParticleFactoryData.create_projectile_trail(Color(1.0, 0.76, 0.48, 0.82), "default"),
		ParticleFactoryData.create_impact_ring(Color(1.0, 0.76, 0.48, 0.82), 64.0, 3.0),
		ParticleFactoryData.create_impact_ring(Color(1.0, 0.76, 0.48, 0.82), 220.0, 3.4),
		ParticleFactoryData.create_impact_ring(Color(0.46, 0.9, 1.0, 0.82), 240.0, 3.4),
		ParticleFactoryData.create_explosion_ring(Color(1.0, 0.78, 0.48, 0.88), 180.0, 4.0),
		ParticleFactoryData.create_explosion_ring(Color(1.0, 0.78, 0.48, 0.88), 260.0, 4.0),
		ParticleFactoryData.create_explosion_ring(Color(0.72, 0.55, 1.0, 0.82), 520.0, 4.0),
		ParticleFactoryData.create_explosion_burst(Color(1.0, 0.54, 0.22, 1.0), 1.1),
		ParticleFactoryData.create_death_burst(Color(1.0, 0.54, 0.22, 1.0), 1.0),
		ParticleFactoryData.create_impact_sparks(Color(1.0, 0.76, 0.48, 0.82), Vector2.RIGHT, 1.0),
		ParticleFactoryData.create_attack_trail(Color(1.0, 0.76, 0.48, 0.82), Vector2.RIGHT, 1.0),
		ParticleFactoryData.create_dash_burst(Color(1.0, 0.76, 0.48, 0.82), Vector2.RIGHT, 1.0),
		ParticleFactoryData.create_debris_ring(Color(1.0, 0.76, 0.48, 0.82), 96.0, 12, 0.24),
	]
	var rendered_samples: Array = []
	for sample in samples:
		_add_combat_prewarm_sample(rendered_samples, sample, effects, prewarm_position)
	var hazard := HazardZoneData.new()
	hazard.configure(80.0, 0.1, 0, Color(1.0, 0.4, 0.2, 0.1))
	_add_combat_prewarm_sample(rendered_samples, hazard, effects, prewarm_position + Vector2(28.0, 0.0))
	var poison_hazard := HazardZoneData.new()
	poison_hazard.configure(160.0, 0.1, 0, Color(0.38, 0.9, 0.24, 0.12))
	_add_combat_prewarm_sample(rendered_samples, poison_hazard, effects, prewarm_position + Vector2(-28.0, 0.0))
	var projectile = ProjectileSceneData.instantiate()
	_add_combat_prewarm_sample(rendered_samples, projectile, projectiles, prewarm_position + Vector2(0.0, 28.0))
	var flash := ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(0.72, 0.55, 1.0, 0.08)
	_add_combat_prewarm_sample(rendered_samples, flash, ui_layer, Vector2.ZERO)
	var deflector = EnemySceneData.instantiate()
	deflector.setup("splitter_mini", self)
	deflector.process_mode = Node.PROCESS_MODE_DISABLED
	var collision := deflector.get_node_or_null("CollisionShape2D")
	if collision != null:
		collision.set_deferred("disabled", true)
	_add_combat_prewarm_sample(rendered_samples, deflector, enemies, prewarm_position + Vector2(0.0, -28.0))
	for index in range(["chaser", "charger", "spitter"].size()):
		var enemy_type := str(["chaser", "charger", "spitter"][index])
		var enemy_sample = EnemySceneData.instantiate()
		enemy_sample.setup(enemy_type, self)
		enemy_sample.process_mode = Node.PROCESS_MODE_DISABLED
		var enemy_collision := enemy_sample.get_node_or_null("CollisionShape2D")
		if enemy_collision != null:
			enemy_collision.set_deferred("disabled", true)
		_add_combat_prewarm_sample(rendered_samples, enemy_sample, enemies, prewarm_position + Vector2(32.0 * float(index - 1), -64.0))
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
	for sample in rendered_samples:
		if sample != null and is_instance_valid(sample):
			sample.queue_free()

func _add_combat_prewarm_sample(rendered_samples: Array, sample: Node, parent: Node, sample_position: Vector2) -> void:
	if sample == null:
		return
	if sample is Node2D:
		(sample as Node2D).global_position = sample_position
	if sample is CanvasItem:
		var canvas_item := sample as CanvasItem
		canvas_item.visible = true
		canvas_item.modulate = Color(1.0, 1.0, 1.0, 0.025)
	parent.add_child(sample)
	rendered_samples.append(sample)

func _setup_side_objective() -> void:
	_side_objective_id = str(_room_config.get("side_objective", ""))
	if _side_objective_id.is_empty():
		return
	_hold_buff_offer = _temp_buff_system.roll_random_buff()
	match _side_objective_id:
		"hold_zone":
			_hold_zone = HoldZoneObjectiveData.new()
			_hold_zone.setup(ARENA_RECT)
			effects.add_child(_hold_zone)
			_hold_zone.completed.connect(_complete_side_objective)
		"kill_streak":
			_kill_streak_target = 30
		"collector":
			_collector_spawn_timer = 0.8

func _apply_active_modifiers() -> void:
	_active_modifiers = (_room_config.get("modifiers", []) as Array).duplicate()
	_minor_modifier_flags["accelerating_waves"] = _active_modifiers.has("accelerating_waves")
	_minor_modifier_flags["enemy_speed"] = _active_modifiers.has("enemy_speed")
	_minor_modifier_flags["swarm"] = _active_modifiers.has("swarm")
	_minor_modifier_flags["shielded"] = _active_modifiers.has("shielded")
	_minor_modifier_flags["explosive_death"] = _active_modifiers.has("explosive_death")
	if _active_modifiers.has("fire_floor"):
		_fire_floor_modifier = FireFloorModifierData.new()
		_fire_floor_modifier.setup(ARENA_RECT, _player_nodes)
		effects.add_child(_fire_floor_modifier)
		_spawn_modifier_activation_vfx("fire_floor", Color(1.0, 0.44, 0.18, 0.72))
	if _active_modifiers.has("ice_zone"):
		_ice_zone_modifier = IceZoneModifierData.new()
		_ice_zone_modifier.setup(ARENA_RECT, _player_nodes)
		effects.add_child(_ice_zone_modifier)
		_spawn_modifier_activation_vfx("ice_zone", Color(0.42, 0.82, 1.0, 0.72))
	if _active_modifiers.has("mine_field"):
		_mine_field_modifier = MineFieldModifierData.new()
		_mine_field_modifier.setup(ARENA_RECT, _player_nodes)
		effects.add_child(_mine_field_modifier)
		_spawn_modifier_activation_vfx("mine_field", Color(1.0, 0.78, 0.24, 0.72))
	if _active_modifiers.has("shrinking_arena"):
		_shrinking_arena_modifier = ShrinkingArenaModifierData.new()
		_shrinking_arena_modifier.setup(ARENA_RECT)
		effects.add_child(_shrinking_arena_modifier)
		_spawn_modifier_activation_vfx("shrinking_arena", Color(0.96, 0.32, 0.28, 0.72))
	_apply_modifier_tint()
	_populate_modifier_hud()

func _apply_modifier_tint() -> void:
	# Reset to neutral each room; a MAJOR hazard washes the world (not the UI layer) with its
	# signature color, by fixed priority. Passive-only / unmodified rooms stay neutral white.
	if modifier_tint == null:
		return
	var tint := Color(1.0, 1.0, 1.0, 1.0)
	if _active_modifiers.has("fire_floor"):
		tint = Color(1.0, 0.88, 0.82)
	elif _active_modifiers.has("ice_zone"):
		tint = Color(0.84, 0.92, 1.0)
	elif _active_modifiers.has("mine_field"):
		tint = Color(1.0, 0.95, 0.82)
	elif _active_modifiers.has("shrinking_arena"):
		tint = Color(1.0, 0.85, 0.84)
	modifier_tint.color = tint

func _physics_process(delta: float) -> void:
	_arena_visuals.tick(delta)
	if _awaiting_mutation_pick:
		return
	if _game_paused or pause_panel.visible or get_tree().paused:
		return
	_room_elapsed += delta
	_update_screen_atmosphere()
	_update_scheduled_enemy_shockwaves()
	_update_scheduled_player_shockwaves()
	_update_scheduled_enemy_hazards()
	_update_scheduled_pulsar_emps()
	_projectile_system.tick(delta)
	_update_side_objectives(delta)
	_update_hazards(delta)
	_update_revives(delta)
	_clamp_runtime_nodes()
	_wave_director.check_wave_progress()
	var now := _current_time_seconds()
	_projectile_system.update_beam_visual_timeouts(now)
	if now >= _next_hud_refresh_at:
		_next_hud_refresh_at = now + HUD_REFRESH_INTERVAL
		_refresh_hud()
	_update_player_combat_indicator_positions()

func _update_side_objectives(delta: float) -> void:
	if _side_objective_completed or _side_objective_id.is_empty():
		return
	match _side_objective_id:
		"hold_zone":
			if _hold_zone != null and is_instance_valid(_hold_zone):
				_hold_zone.update_zone(delta, _player_nodes)
		"collector":
			_collector_spawn_timer -= delta
			if _collector_spawned < COLLECTOR_TOTAL_SPAWN and _collector_spawn_timer <= 0.0:
				_collector_spawn_timer = COLLECTOR_SPAWN_INTERVAL
				_spawn_collector_orb()
			var collected_now := 0
			for orb in _collector_orbs:
				if orb == null or not is_instance_valid(orb):
					continue
				if orb.update_orb(delta, _player_nodes):
					collected_now += 1
			_collector_collected += collected_now
			if collected_now > 0:
				_play_sfx("play_pickup", [])
			_cleanup_orbs()
			if _collector_collected >= COLLECTOR_TARGET:
				_complete_side_objective()

func _update_hazards(delta: float) -> void:
	for hazard in _active_hazards:
		if hazard != null and is_instance_valid(hazard):
			hazard.update_zone(delta, _player_nodes)
	_cleanup_helpers()

func _spawn_enemy_instance(enemy_type: String, spawn_position: Vector2, health_multiplier: float = 1.0) -> Node2D:
	return _wave_director.spawn_enemy_instance(enemy_type, spawn_position, health_multiplier) if _wave_director != null else null

func spawn_enemy_instance(enemy_type: String, spawn_position: Vector2, health_multiplier: float = 1.0) -> Node2D:
	return _spawn_enemy_instance(enemy_type, spawn_position, health_multiplier)

func _queue_enemy_spawn(enemy_type: String, spawn_position: Vector2, health_multiplier: float = 1.0) -> void:
	if _wave_director != null:
		_wave_director.queue_enemy_spawn(enemy_type, spawn_position, health_multiplier)

func queue_enemy_spawn(enemy_type: String, spawn_position: Vector2, health_multiplier: float = 1.0) -> void:
	_queue_enemy_spawn(enemy_type, spawn_position, health_multiplier)

func register_enemy(enemy: Node2D) -> void:
	if enemy != null and is_instance_valid(enemy) and not _enemy_nodes.has(enemy):
		_enemy_nodes.append(enemy)

func is_enemy_list_empty() -> bool:
	return _enemy_nodes.is_empty()

func is_room_clear_started() -> bool:
	return _room_clear_started

func handle_wave_room_clear() -> void:
	_handle_room_clear()

func on_boss_spawned() -> void:
	_spawn_boss_entrance_vfx()

func _handle_room_clear() -> void:
	if _room_clear_started:
		return
	_room_clear_started = true
	_record_room_score(true)
	_set_runtime_pause_state(true)
	_lock_player_input(true)
	_spawn_room_clear_flourish()
	_pending_clear_summary = _build_clear_summary()
	_show_progression_pick_if_needed()

func _show_progression_pick_if_needed() -> void:
	if RunState.get_pending_levelups() > 0:
		_pending_pick_consumes_levelup = true
		_show_mutation_pick(false, "Level Up", "Choose one upgrade.")
		return
	if _room_type == "boss" and not _pending_champion_bonus_pick:
		_pending_champion_bonus_pick = true
		_pending_pick_consumes_levelup = false
		_show_mutation_pick(true, "Champion Reward", "Guaranteed rare pressure. Choose one upgrade.")
		return
	_finish_room_progression()

func _show_mutation_pick(force_rare: bool, title: String, subtitle: String) -> void:
	if _mutation_pick_ui != null and is_instance_valid(_mutation_pick_ui):
		_mutation_pick_ui.queue_free()
	_mutation_pick_round_force_rare = force_rare
	_reset_mutation_pick_reroll_counts()
	var options_by_player: Array = []
	for player_index in range(_player_nodes.size()):
		options_by_player.append(_roll_initial_mutation_options_for_player(player_index, force_rare))
	_mutation_pick_ui = MutationPickUIScene.instantiate()
	_mutation_pick_ui.configure_for_players(_player_configs, options_by_player, title, subtitle)
	_mutation_pick_ui.set_reroll_state(RunState.get_current_score(), _build_mutation_pick_reroll_costs())
	_mutation_pick_ui.selections_confirmed.connect(_on_mutation_selections_confirmed)
	_mutation_pick_ui.reroll_requested.connect(_on_mutation_reroll_requested)
	_mutation_pick_ui.skip_requested.connect(_on_mutation_skip_requested)
	ui_layer.add_child(_mutation_pick_ui)
	_awaiting_mutation_pick = true
	if _hit_stop_manager != null and _hit_stop_manager.has_method("request_dilation"):
		_hit_stop_manager.request_dilation(70, 0.18)

func _roll_initial_mutation_options_for_player(player_index: int, round_force_rare: bool) -> Array:
	var inventory: PlayerInventory = RunState.get_player_inventory(player_index)
	var force_player_rare: bool = round_force_rare or (inventory != null and inventory.rare_dry_streak >= 3)
	var options: Array = _mutation_system.roll_mutation_options(player_index, 3, _get_current_rare_chance(), force_player_rare, _signature_share(_room_depth))
	if inventory != null:
		if _options_contain_rare(options):
			inventory.rare_dry_streak = 0
		else:
			inventory.rare_dry_streak += 1
	return options

func _roll_reroll_mutation_options_for_player(player_index: int) -> Array:
	return _mutation_system.roll_mutation_options(player_index, 3, _get_current_rare_chance(), _mutation_pick_round_force_rare, _signature_share(_room_depth))

func _reset_mutation_pick_reroll_counts() -> void:
	_mutation_pick_reroll_counts.clear()
	for _player_index in range(_player_nodes.size()):
		_mutation_pick_reroll_counts.append(0)

func _build_mutation_pick_reroll_costs() -> Array:
	var costs: Array = []
	for player_index in range(_player_nodes.size()):
		costs.append(_get_mutation_pick_reroll_cost(player_index))
	return costs

func _get_mutation_pick_reroll_cost(player_index: int) -> int:
	if player_index < 0 or player_index >= _mutation_pick_reroll_counts.size():
		return MUTATION_REROLL_BASE_COST
	return MUTATION_REROLL_BASE_COST * int(pow(2.0, float(maxi(int(_mutation_pick_reroll_counts[player_index]), 0))))

func _on_mutation_reroll_requested(player_index: int) -> void:
	if _mutation_pick_ui == null or not is_instance_valid(_mutation_pick_ui):
		return
	if player_index < 0 or player_index >= _player_nodes.size():
		return
	var cost := _get_mutation_pick_reroll_cost(player_index)
	if not RunState.spend_run_score(cost):
		_mutation_pick_ui.set_reroll_state(RunState.get_current_score(), _build_mutation_pick_reroll_costs())
		return
	_mutation_pick_reroll_counts[player_index] = int(_mutation_pick_reroll_counts[player_index]) + 1
	_mutation_pick_ui.replace_options_for_player(player_index, _roll_reroll_mutation_options_for_player(player_index))
	_mutation_pick_ui.set_reroll_state(RunState.get_current_score(), _build_mutation_pick_reroll_costs())
	_play_sfx("play_ui_click", [])
	_refresh_hud()

func _on_mutation_skip_requested(_player_index: int) -> void:
	_play_sfx("play_ui_click", [])
	if _mutation_pick_ui != null and is_instance_valid(_mutation_pick_ui):
		_mutation_pick_ui.set_reroll_state(RunState.get_current_score(), _build_mutation_pick_reroll_costs())

func _options_contain_rare(options: Array) -> bool:
	for option_variant in options:
		var option := option_variant as Dictionary
		if CoopFormat.rarity_rank(str(option.get("rarity", "common"))) >= 1:
			return true
	return false

func _on_mutation_selections_confirmed(selections_per_player: Array) -> void:
	for player_index in range(min(selections_per_player.size(), _player_nodes.size())):
		for mutation_id in (selections_per_player[player_index] as Array):
			_mutation_system.apply_mutation(player_index, str(mutation_id))
	if _pending_pick_consumes_levelup:
		RunState.spend_levelup()
	if _mutation_pick_ui != null and is_instance_valid(_mutation_pick_ui):
		_mutation_pick_ui.queue_free()
	_mutation_pick_ui = null
	_awaiting_mutation_pick = false
	_rebuild_player_loadouts()
	if _pending_pick_consumes_levelup and RunState.get_pending_levelups() > 0:
		_show_progression_pick_if_needed()
		return
	if _pending_pick_consumes_levelup and _room_type == "boss" and not _pending_champion_bonus_pick:
		_pending_pick_consumes_levelup = false
		_pending_champion_bonus_pick = true
		_show_mutation_pick(true, "Champion Reward", "Guaranteed rare pressure. Choose one upgrade.")
		return
	if not _pending_pick_consumes_levelup and _pending_champion_bonus_pick:
		_pending_champion_bonus_pick = false
		_finish_room_progression()
		return
	if RunState.get_pending_levelups() > 0:
		_show_progression_pick_if_needed()
		return
	_finish_room_progression()

func _finish_room_progression() -> void:
	_lock_player_input(false)
	room_cleared.emit(_collect_player_health_states(), {"summary": _pending_clear_summary})

func _collect_player_health_states() -> Array:
	var states: Array = []
	for player in _player_nodes:
		states.append(player.get_health_state())
	return states

func _build_clear_summary() -> String:
	var lines := ["Room cleared."]
	if not _side_objective_id.is_empty():
		lines.append("Objective: %s" % _format_objective_text())
		if _side_objective_completed:
			lines.append("Buff earned: %s" % CoopFormat.format_buff_name(str(_hold_buff_offer.get("type", ""))))
	return "\n".join(lines)

func _on_player_fire_requested(origin: Vector2, direction: Vector2, projectile_config: Dictionary) -> void:
	_projectile_system.handle_player_fire(origin, direction, projectile_config)

func _on_player_ability_activated(player, _slot_index: int, ability_id: String, origin: Vector2, direction: Vector2, stats: Dictionary) -> void:
	var tint: Color = stats.get("color", Color.WHITE)
	_spawn_ability_activation_flash(origin, tint, ability_id)
	_play_sfx("play_explosion", [0.85, ability_id])
	match ability_id:
		"shockwave":
			_spawn_player_shockwave(origin, stats)
			_schedule_player_shockwave_resonance(origin, stats)
		"dash":
			_spawn_dash_effect(origin, direction, tint)
		"blink":
			_spawn_blink_effect(origin, tint)
			_spawn_blink_detonation(origin, stats)
		"shield":
			_spawn_shield_effect(origin, float(stats.get("radius", 78.0)), tint)
		"decoy":
			var decoy := DecoyNodeData.new()
			decoy.global_position = origin
			decoy.configure(float(stats.get("duration", 5.0)), tint, int(stats.get("decoy_health", 120)), stats)
			players.add_child(decoy)
			_active_decoys.append(decoy)
		"turret":
			var turret := TurretNodeData.new()
			turret.global_position = origin
			turret.configure(float(stats.get("duration", 6.0)), stats, tint)
			turret.fire_requested.connect(_on_player_fire_requested)
			effects.add_child(turret)
			_active_turrets.append(turret)
		"minefield":
			_spawn_ability_mines(origin, stats)
		"orbit":
			var orbit := OrbitNodeData.new()
			orbit.configure(player, float(stats.get("duration", 5.0)), stats, tint)
			effects.add_child(orbit)
			_active_orbits.append(orbit)
		"overcharge":
			var burst := ParticleFactoryData.create_explosion_burst(tint, 1.15)
			burst.global_position = origin
			effects.add_child(burst)

func _spawn_player_shockwave(origin: Vector2, stats: Dictionary) -> void:
	var radius := float(stats.get("radius", 250.0))
	var damage := int(round(float(stats.get("damage", 30.0))))
	var knockback_force := float(stats.get("knockback_force", 950.0))
	for enemy in get_nearby_enemy_target_nodes(origin, radius):
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var offset: Vector2 = enemy.global_position - origin
		var distance: float = offset.length()
		if distance > radius:
			continue
		enemy.apply_damage(damage)
		_spawn_target_hit_spark(enemy.global_position, offset.normalized() if distance > 0.0 else Vector2.UP, stats.get("color", Color.WHITE), 1.0)
		if enemy.has_method("apply_knockback"):
			var radial_direction: Vector2 = offset.normalized() if distance > 0.0 else Vector2.RIGHT
			var distance_ratio := 1.0 - clampf(distance / max(radius, 0.01), 0.0, 1.0)
			enemy.apply_knockback(radial_direction, knockback_force * (0.7 + distance_ratio * 0.75))
	for projectile in projectiles.get_children():
		if projectile == null or not is_instance_valid(projectile):
			continue
		if projectile.has_method("is_projectile_active") and not projectile.is_projectile_active():
			continue
		if not ("team" in projectile) or str(projectile.team) != "enemy":
			continue
		if projectile.global_position.distance_to(origin) <= radius:
			var projectile_direction: Vector2 = projectile.global_position - origin
			var sparks := ParticleFactoryData.create_impact_sparks(
				(stats.get("color", Color.WHITE) as Color).lightened(0.1),
				projectile_direction.normalized() if projectile_direction.length() > 0.0 else Vector2.UP,
				0.75
			)
			sparks.global_position = projectile.global_position
			effects.add_child(sparks)
			if projectile.has_method("_finish_projectile"):
				projectile._finish_projectile()
			else:
				projectile.queue_free()
	_spawn_shockwave_visual(origin, radius, stats.get("color", Color.WHITE), float(stats.get("expand_duration", 0.15)))
	if _screen_effects_enabled() and screen_shake != null and screen_shake.has_method("add_trauma"):
		screen_shake.add_trauma(0.18)

func _schedule_player_shockwave_resonance(origin: Vector2, stats: Dictionary) -> void:
	var extra_pulses: int = maxi(0, int(stats.get("extra_pulses", 0)))
	if extra_pulses <= 0:
		return
	var pulse_interval: float = maxf(0.01, float(stats.get("pulse_interval", 0.15)))
	for pulse_index in range(extra_pulses):
		_scheduled_player_shockwaves.append({
			"trigger_at": _room_elapsed + pulse_interval * float(pulse_index + 1),
			"origin": origin,
			"stats": stats.duplicate(true),
		})

func _spawn_dash_effect(origin: Vector2, direction: Vector2, color: Color) -> void:
	var burst := ParticleFactoryData.create_dash_burst(color, direction, 1.0)
	burst.global_position = origin
	effects.add_child(burst)
	_play_sfx("play_dash", [1.0])

func _spawn_blink_effect(origin: Vector2, color: Color) -> void:
	var burst := ParticleFactoryData.create_explosion_burst(color, 0.75)
	burst.global_position = origin
	effects.add_child(burst)

func _spawn_blink_detonation(origin: Vector2, stats: Dictionary) -> void:
	var radius := float(stats.get("detonation_radius", 0.0))
	var damage := int(stats.get("detonation_damage", 0))
	if radius <= 0.0 or damage <= 0:
		return
	var color: Color = stats.get("color", Color.WHITE)
	for enemy in get_nearby_enemy_target_nodes(origin, radius):
		if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("is_alive") or not enemy.is_alive():
			continue
		if enemy.global_position.distance_squared_to(origin) > radius * radius:
			continue
		enemy.apply_damage(damage)
		if enemy.has_method("apply_knockback"):
			var offset: Vector2 = enemy.global_position - origin
			enemy.apply_knockback(offset.normalized() if offset.length() > 0.0 else Vector2.RIGHT, 420.0)
	_spawn_shockwave_visual(origin, radius, color, 0.12)

func _spawn_shield_effect(origin: Vector2, radius: float, color: Color) -> void:
	var ring := ParticleFactoryData.create_explosion_ring(color, radius, 3.0)
	ring.global_position = origin
	effects.add_child(ring)

func _spawn_ability_mines(origin: Vector2, stats: Dictionary) -> void:
	var mine_count := int(stats.get("mine_count", 4)) + int(stats.get("mine_count_bonus", 0))
	var spread_radius := float(stats.get("spread_radius", 150.0))
	var radius := float(stats.get("radius", 100.0))
	var trigger_radius := float(stats.get("trigger_radius", 52.0))
	var damage := int(stats.get("damage", 42))
	var duration := float(stats.get("mine_lifetime", 8.0))
	var tint: Color = stats.get("color", Color.WHITE)
	for mine_index in range(mine_count):
		var angle := TAU * float(mine_index) / float(max(mine_count, 1))
		var mine := AbilityMineData.new()
		mine.global_position = origin + Vector2.RIGHT.rotated(angle) * spread_radius
		mine.configure(duration, radius, damage, tint, trigger_radius)
		effects.add_child(mine)
		_active_mines.append(mine)

func _on_player_shield_burst_requested(origin: Vector2, radius: float, damage: int, color: Color) -> void:
	if radius <= 0.0 or damage <= 0:
		return
	for enemy in get_nearby_enemy_target_nodes(origin, radius):
		if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("is_alive") or not enemy.is_alive():
			continue
		if enemy.global_position.distance_squared_to(origin) > radius * radius:
			continue
		enemy.apply_damage(damage)
		if enemy.has_method("apply_knockback"):
			var offset: Vector2 = enemy.global_position - origin
			enemy.apply_knockback(offset.normalized() if offset.length() > 0.0 else Vector2.RIGHT, 360.0)
	var ring := ParticleFactoryData.create_explosion_ring(color, radius, 4.0)
	ring.global_position = origin
	effects.add_child(ring)

func _spawn_shockwave_visual(center: Vector2, radius: float, color: Color, _duration: float) -> void:
	var ring := ParticleFactoryData.create_explosion_ring(color, radius, 4.0)
	ring.global_position = center
	effects.add_child(ring)
	var pulse := ParticleFactoryData.create_impact_ring(color, radius * 0.15, 3.0)
	pulse.global_position = center
	effects.add_child(pulse)

func _spawn_ability_activation_flash(origin: Vector2, color: Color, ability_id: String) -> void:
	var weight := 1.0
	if ability_id == "shockwave" or ability_id == "overcharge":
		weight = 1.25
	var burst := ParticleFactoryData.create_explosion_burst(color.lightened(0.12), weight)
	burst.global_position = origin
	effects.add_child(burst)
	var ring := ParticleFactoryData.create_impact_ring(color, 46.0 if ability_id != "shield" else 78.0, 3.0)
	ring.global_position = origin
	effects.add_child(ring)

func _spawn_target_hit_spark(hit_position: Vector2, direction: Vector2, color: Color, weight: float) -> void:
	if _should_suppress_combat_vfx():
		return
	var sparks := ParticleFactoryData.create_impact_sparks(color.lightened(0.18), direction, weight)
	sparks.global_position = hit_position
	effects.add_child(sparks)

func _spawn_modifier_activation_vfx(_modifier_id: String, color: Color) -> void:
	var ring := ParticleFactoryData.create_explosion_ring(color, max(ARENA_SIZE.x, ARENA_SIZE.y) * 0.32, 6.0)
	ring.global_position = ARENA_CENTER
	effects.add_child(ring)
	_spawn_screen_flash(Color(color.r, color.g, color.b, 0.16), 0.28)

func _spawn_room_clear_flourish() -> void:
	var color := Color(0.42, 1.0, 0.76, 0.82)
	_play_sfx("play_room_clear", [])
	if _screen_effects_enabled() and screen_shake != null and screen_shake.has_method("add_trauma"):
		screen_shake.add_trauma(0.18)
	_spawn_screen_flash(Color(color.r, color.g, color.b, 0.14), 0.24)
	var ring := ParticleFactoryData.create_explosion_ring(color, 220.0, 5.0)
	ring.global_position = ARENA_CENTER
	effects.add_child(ring)
	var debris := ParticleFactoryData.create_debris_ring(color.lightened(0.12), 180.0, 16, 0.28)
	debris.global_position = ARENA_CENTER
	effects.add_child(debris)

func _spawn_boss_entrance_vfx() -> void:
	_set_music_context("boss")
	if _screen_effects_enabled() and screen_shake != null and screen_shake.has_method("add_trauma"):
		screen_shake.add_trauma(0.32)
	_request_hit_stop(0.65, 42)
	_play_sfx("play_explosion", [1.35, "boss"])
	_spawn_screen_flash(Color(0.82, 0.06, 0.04, 0.18), 0.32)
	var ring := ParticleFactoryData.create_explosion_ring(Color(1.0, 0.14, 0.08, 0.78), 260.0, 6.0)
	var active_boss = get_active_boss()
	ring.global_position = active_boss.global_position if active_boss != null and is_instance_valid(active_boss) and active_boss is Node2D else ARENA_CENTER
	effects.add_child(ring)

func _spawn_enemy_death_global_vfx(enemy_type_name: String) -> void:
	if EnemyTypes.is_champion(enemy_type_name):
		_set_music_context("combat")
		if _screen_effects_enabled() and screen_shake != null and screen_shake.has_method("add_trauma"):
			screen_shake.add_trauma(0.42)
		_request_hit_stop(0.85, 52)
		_play_sfx("play_explosion", [1.45, "boss"])
		_spawn_screen_flash(Color(1.0, 1.0, 1.0, 0.18), 0.2)
	else:
		_play_sfx("play_enemy_death", [0.8])

func _on_run_level_up(_new_level: int) -> void:
	_spawn_screen_flash(Color(0.42, 1.0, 0.72, 0.18), 0.22)
	if _screen_effects_enabled() and screen_shake != null and screen_shake.has_method("add_trauma"):
		screen_shake.add_trauma(0.12)
	_play_sfx("play_level_up", [])

func _request_hit_stop(weight: float, duration_ms: int) -> void:
	if _hit_stop_manager != null and _hit_stop_manager.has_method("request_hit_stop"):
		_hit_stop_manager.request_hit_stop(weight, duration_ms)

func _update_screen_atmosphere() -> void:
	# Drive the (previously unused) ScreenEffects shader: danger vignette from the lowest player's
	# health, and a warm combat-intensity tint from how many enemies are on screen.
	if screen_effects == null:
		return
	var lowest_ratio := 1.0
	var any_alive := false
	for player in _player_nodes:
		if player == null or not is_instance_valid(player) or not player.has_method("is_alive") or not player.is_alive():
			continue
		any_alive = true
		lowest_ratio = minf(lowest_ratio, float(player.current_health) / maxf(float(player.max_health), 1.0))
	if screen_effects.has_method("set_low_health_ratio"):
		screen_effects.set_low_health_ratio(lowest_ratio if any_alive else 1.0)
	if screen_effects.has_method("set_combat_intensity"):
		screen_effects.set_combat_intensity(clampf(float(enemies.get_child_count()) / 22.0, 0.0, 1.0))

func _spawn_screen_flash(color: Color, duration: float) -> void:
	if not _screen_effects_enabled():
		return
	var flash := ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = color
	ui_layer.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, maxf(duration, 0.01))
	tween.tween_callback(flash.queue_free)

func _on_enemy_fire_requested(origin: Vector2, direction: Vector2, speed: float, damage: int, team: String, _color: Color, projectile_scale: float) -> void:
	_projectile_system.handle_enemy_fire(origin, direction, speed, damage, team, projectile_scale)

func spawn_enemy_homing_orbs(origin: Vector2, count: int, speed: float, duration: float, damage: int, _color: Color) -> void:
	_projectile_system.spawn_enemy_homing_orbs(origin, count, speed, duration, damage, _color)

func _apply_enemy_death_effects(enemy) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("get_death_effects"):
		return
	var death_position: Vector2 = enemy.global_position
	for effect_variant in enemy.get_death_effects():
		var effect := effect_variant as Dictionary
		var radius := float(effect.get("radius", 0.0))
		var damage := int(effect.get("damage", 0))
		if radius <= 0.0 or damage <= 0:
			continue
		for nearby in get_nearby_enemy_target_nodes(death_position, radius):
			if nearby == null or not is_instance_valid(nearby) or nearby == enemy:
				continue
			if nearby.has_method("is_alive") and not nearby.is_alive():
				continue
			if nearby.global_position.distance_squared_to(death_position) > radius * radius:
				continue
			if nearby.has_method("apply_damage"):
				nearby.apply_damage(damage)
		if not _should_suppress_combat_vfx():
			var effect_color := Color(1.0, 0.52, 0.18, 0.78) if str(effect.get("type", "")) == "ignite" else Color(0.42, 0.92, 1.0, 0.78)
			var ring := ParticleFactoryData.create_explosion_ring(effect_color, radius, 2.4)
			ring.global_position = death_position
			effects.add_child(ring)

func _should_suppress_combat_vfx() -> bool:
	return _projectile_system.should_suppress_combat_vfx()

func _on_enemy_died(enemy) -> void:
	_enemy_nodes.erase(enemy)
	var was_active_boss: bool = enemy == get_active_boss()
	if _wave_director != null:
		_wave_director.clear_active_boss_if(enemy)
	_enemies_killed += 1
	_gain_shared_momentum()
	var enemy_type_name := str(enemy.get_type_name())
	if EnemyTypes.is_champion(enemy_type_name):
		_champions_killed += 1
	_spawn_enemy_death_global_vfx(enemy_type_name)
	_apply_enemy_death_effects(enemy)
	if EnemyTypes.is_champion(enemy_type_name):
		RunState.add_xp(0)
	else:
		RunState.add_xp(int(XP_PER_ENEMY_TYPE.get(enemy_type_name, 10)))
	if not EnemyTypes.is_champion(enemy_type_name) and randf() < HEALTH_DROP_CHANCE:
		call_deferred("_spawn_health_pickup", enemy.global_position)
	if enemy_type_name == "splitter":
		for mini_index in range(3):
			var angle := TAU * float(mini_index) / 3.0
			_queue_enemy_spawn("splitter_mini", enemy.global_position + Vector2.RIGHT.rotated(angle) * 36.0)
	if _ice_zone_modifier != null and is_instance_valid(_ice_zone_modifier):
		_ice_zone_modifier.spawn_patch(enemy.global_position)
	if _side_objective_id == "kill_streak" and not _side_objective_completed:
		_kill_streak_progress += 1
		if _kill_streak_progress >= _kill_streak_target:
			_complete_side_objective()

func _on_enemy_hit_received(_enemy, _damage_amount: int, _lethal: bool) -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	var is_big_hit: bool = _damage_amount >= 90
	var is_champion_hit: bool = _enemy.has_method("is_champion") and bool(_enemy.is_champion())
	var should_play_feedback := is_big_hit
	if is_champion_hit:
		var now := _current_time_seconds()
		if now >= _next_boss_hit_feedback_at:
			_next_boss_hit_feedback_at = now + BOSS_HIT_FEEDBACK_INTERVAL
			should_play_feedback = true
	if should_play_feedback:
		if _screen_effects_enabled() and screen_shake != null and screen_shake.has_method("add_trauma"):
			screen_shake.add_trauma(0.08 if not is_champion_hit else 0.10)
		if not _lethal:
			_request_hit_stop(0.45 if not is_champion_hit else 0.55, 35)
	_play_sfx("play_impact_profile", [0.85, "hit"])

func _spawn_health_pickup(spawn_position: Vector2) -> void:
	if _room_clear_started or not is_inside_tree():
		return
	var hp_pickup := HealthPickupData.new()
	hp_pickup.global_position = spawn_position
	pickups.add_child(hp_pickup)

func _on_player_downed(player) -> void:
	_revive_progress_by_player_id[player.player_id] = 0.0
	player_downed.emit(player)
	_check_failure()

func _on_player_revived(player) -> void:
	_revive_progress_by_player_id.erase(player.player_id)
	player_revived.emit(player)

func _on_player_damage_taken(player, amount: int, _current_health: int) -> void:
	if player == null or not is_instance_valid(player):
		return
	if _side_objective_id == "kill_streak" and not _side_objective_completed:
		_kill_streak_progress = 0
	_drop_player_momentum(int(player.player_index))
	var burst := ParticleFactoryData.create_impact_sparks(player.player_config.tint.lightened(0.22), Vector2.UP, 1.1)
	burst.global_position = player.global_position
	effects.add_child(burst)
	_play_sfx("play_damage", [])
	# Taking damage should HURT: shake + hit-stop + red flash, scaled by hit size.
	var hit_weight := clampf(float(amount) / 20.0, 0.5, 1.0)
	if _screen_effects_enabled() and screen_shake != null and screen_shake.has_method("add_trauma"):
		screen_shake.add_trauma(0.12 + 0.30 * hit_weight)
	_request_hit_stop(0.7, 48)
	_spawn_screen_flash(Color(0.95, 0.12, 0.12, 0.18 + 0.16 * hit_weight), 0.22)

func _on_muzzle_flash_requested(origin: Vector2, direction: Vector2, color: Color, feedback_profile: String, impact_weight: float) -> void:
	var flash := ParticleFactoryData.create_muzzle_flash(color, direction, feedback_profile, impact_weight + 0.18)
	flash.global_position = origin
	effects.add_child(flash)
	_play_sfx("play_fire", [feedback_profile, impact_weight])

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
		if has_reviver:
			progress += delta
			if progress >= REVIVE_HOLD_DURATION:
				player.revive(max(1, int(round(player.max_health * 0.5))))
				_sync_player_health_state(player)
				progress = 0.0
		else:
			progress = max(progress - delta * 2.0, 0.0)
		_revive_progress_by_player_id[player.player_id] = progress

func _check_failure() -> void:
	for player in _player_nodes:
		if player != null and is_instance_valid(player) and player.is_alive():
			return
	_record_room_score(false)
	all_players_dead.emit()

func _record_room_score(cleared: bool) -> void:
	if _room_score_recorded:
		return
	_room_score_recorded = true
	RunState.add_run_score(_build_room_score_delta(cleared))

func _build_room_score_delta(cleared: bool) -> int:
	var clear_credit := 100 if cleared else 0
	return clear_credit + _enemies_killed + _champions_killed * 250 + _room_max_momentum_tier * 50

func _refresh_hud() -> void:
	if _hud != null:
		_hud.refresh()

func _refresh_boss_hud() -> void:
	if _hud != null:
		_hud.refresh_boss()

func _play_sfx(method_name: String, args: Array) -> void:
	for node in get_tree().get_nodes_in_group("sfx_engine"):
		if node != null and is_instance_valid(node) and node.has_method(method_name):
			node.callv(method_name, args)
			return

func _set_music_context(context: String) -> void:
	if MusicEngine != null and MusicEngine.has_method("set_context"):
		MusicEngine.set_context(context)

func _get_current_rare_chance() -> float:
	var base_chance := lerpf(0.20, 0.45, clampf(float(_room_depth - 1) / 19.0, 0.0, 1.0))
	return clampf(base_chance + _room_rare_bonus, 0.0, 0.60)

func _signature_share(depth: int) -> float:
	return clampf(float(depth - 4) / 16.0, 0.0, 0.5)

func _format_objective_text() -> String:
	return _hud.format_objective_text() if _hud != null else ""

func _build_side_objective_text() -> String:
	return _hud.build_side_objective_text() if _hud != null else ""

func _update_player_combat_indicator_positions() -> void:
	if _hud != null:
		_hud.update_player_combat_indicator_positions()

func _populate_modifier_hud() -> void:
	if _hud != null:
		_hud.populate_modifier_hud()

func _complete_side_objective() -> void:
	if _side_objective_completed or _temp_buff_system == null or _hold_buff_offer.is_empty():
		return
	_side_objective_completed = true
	_temp_buff_system.apply_buff(_hold_buff_offer, _player_nodes)

func _spawn_collector_orb() -> void:
	if _collector_spawned >= COLLECTOR_TOTAL_SPAWN:
		return
	var orb := CollectorOrbData.new()
	orb.global_position = Vector2(
		randf_range(ARENA_RECT.position.x + 220.0, ARENA_RECT.end.x - 220.0),
		randf_range(ARENA_RECT.position.y + 220.0, ARENA_RECT.end.y - 220.0)
	)
	pickups.add_child(orb)
	_collector_orbs.append(orb)
	_collector_spawned += 1

func _cleanup_orbs() -> void:
	var alive_orbs: Array = []
	for orb in _collector_orbs:
		if orb != null and is_instance_valid(orb):
			alive_orbs.append(orb)
	_collector_orbs = alive_orbs

func _cleanup_helpers() -> void:
	_active_hazards = _cleanup_instance_array(_active_hazards)
	_active_decoys = _cleanup_instance_array(_active_decoys)
	_active_turrets = _cleanup_instance_array(_active_turrets)
	_active_orbits = _cleanup_instance_array(_active_orbits)
	_active_mines = _cleanup_instance_array(_active_mines)

func _cleanup_instance_array(nodes: Array) -> Array:
	var kept: Array = []
	for node in nodes:
		if node != null and is_instance_valid(node):
			kept.append(node)
	return kept

func _clamp_runtime_nodes() -> void:
	var clamp_rect := ARENA_RECT
	if _shrinking_arena_modifier != null and is_instance_valid(_shrinking_arena_modifier):
		clamp_rect = _shrinking_arena_modifier.get_current_rect()
	for player in _player_nodes:
		if player == null or not is_instance_valid(player):
			continue
		player.global_position.x = clampf(player.global_position.x, clamp_rect.position.x + 42.0, clamp_rect.end.x - 42.0)
		player.global_position.y = clampf(player.global_position.y, clamp_rect.position.y + 42.0, clamp_rect.end.y - 42.0)
	for enemy in _enemy_nodes:
		if enemy == null or not is_instance_valid(enemy):
			continue
		enemy.global_position.x = clampf(enemy.global_position.x, clamp_rect.position.x + 36.0, clamp_rect.end.x - 36.0)
		enemy.global_position.y = clampf(enemy.global_position.y, clamp_rect.position.y + 36.0, clamp_rect.end.y - 36.0)

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

func spawn_enemy_shockwave(origin: Vector2, radius: float, damage: int, knockback_force: float, color: Color, destroy_projectiles: bool = false) -> void:
	for player in _player_nodes:
		if player == null or not is_instance_valid(player) or not player.is_alive():
			continue
		var offset: Vector2 = player.global_position - origin
		var distance: float = offset.length()
		if distance > radius:
			continue
		if damage > 0:
			player.apply_damage(damage)
		player.apply_knockback(offset.normalized() if distance > 0.0 else Vector2.RIGHT, knockback_force)
	if destroy_projectiles:
		for projectile in projectiles.get_children():
			if projectile == null or not is_instance_valid(projectile):
				continue
			if projectile.has_method("is_projectile_active") and not projectile.is_projectile_active():
				continue
			if not ("team" in projectile):
				continue
			if projectile.global_position.distance_to(origin) > radius:
				continue
			if projectile.has_method("_finish_projectile"):
				projectile._finish_projectile()
			else:
				projectile.queue_free()
	_spawn_shockwave_visual(origin, radius, color, 0.18)

func schedule_enemy_shockwave(origin: Vector2, radius: float, damage: int, knockback_force: float, color: Color, delay: float, destroy_projectiles: bool = false) -> void:
	if delay <= 0.0:
		spawn_enemy_shockwave(origin, radius, damage, knockback_force, color, destroy_projectiles)
		return
	_scheduled_enemy_shockwaves.append({
		"trigger_at": _room_elapsed + delay,
		"origin": origin,
		"radius": radius,
		"damage": damage,
		"knockback_force": knockback_force,
		"color": color,
		"destroy_projectiles": destroy_projectiles,
	})

func _update_scheduled_enemy_shockwaves() -> void:
	if _scheduled_enemy_shockwaves.is_empty():
		return
	var remaining: Array = []
	for scheduled in _scheduled_enemy_shockwaves:
		var trigger_at := float((scheduled as Dictionary).get("trigger_at", INF))
		if _room_elapsed >= trigger_at:
			spawn_enemy_shockwave(
				scheduled.get("origin", Vector2.ZERO),
				float(scheduled.get("radius", 0.0)),
				int(scheduled.get("damage", 0)),
				float(scheduled.get("knockback_force", 0.0)),
				scheduled.get("color", Color.WHITE),
				bool(scheduled.get("destroy_projectiles", false))
			)
		else:
			remaining.append(scheduled)
	_scheduled_enemy_shockwaves = remaining

func _update_scheduled_player_shockwaves() -> void:
	if _scheduled_player_shockwaves.is_empty():
		return
	var remaining: Array = []
	for scheduled in _scheduled_player_shockwaves:
		var trigger_at := float((scheduled as Dictionary).get("trigger_at", INF))
		if _room_elapsed >= trigger_at:
			_spawn_player_shockwave(
				scheduled.get("origin", Vector2.ZERO),
				(scheduled.get("stats", {}) as Dictionary).duplicate(true)
			)
		else:
			remaining.append(scheduled)
	_scheduled_player_shockwaves = remaining

func schedule_enemy_hazard_zone(origin: Vector2, radius: float, duration: float, damage: int, color: Color, delay: float) -> void:
	if delay <= 0.0:
		spawn_enemy_hazard_zone(origin, radius, duration, damage, color)
		return
	_scheduled_enemy_hazards.append({
		"trigger_at": _room_elapsed + delay,
		"origin": origin,
		"radius": radius,
		"duration": duration,
		"damage": damage,
		"color": color,
	})

func _update_scheduled_enemy_hazards() -> void:
	if _scheduled_enemy_hazards.is_empty():
		return
	var remaining: Array = []
	for scheduled in _scheduled_enemy_hazards:
		var entry := scheduled as Dictionary
		if _room_elapsed >= float(entry.get("trigger_at", INF)):
			spawn_enemy_hazard_zone(
				entry.get("origin", Vector2.ZERO),
				float(entry.get("radius", 0.0)),
				float(entry.get("duration", 0.0)),
				int(entry.get("damage", 0)),
				entry.get("color", Color.WHITE)
			)
		else:
			remaining.append(scheduled)
	_scheduled_enemy_hazards = remaining

func spawn_enemy_hazard_zone(origin: Vector2, radius: float, duration: float, damage: int, color: Color) -> void:
	var zone := HazardZoneData.new()
	zone.global_position = origin
	zone.configure(radius, duration, damage, color)
	effects.add_child(zone)
	_active_hazards.append(zone)

func spawn_enemy_minions(origin: Vector2, count: int, phase: float, forced_type: String = "") -> void:
	for index in range(count):
		var enemy_type := forced_type
		if enemy_type.is_empty():
			enemy_type = "chaser"
			if phase >= 0.25 and randf() < phase:
				enemy_type = "charger"
		if phase >= 0.55 and randf() < phase * 0.7:
			enemy_type = "spitter"
		var angle := TAU * float(index) / float(max(count, 1))
		_queue_enemy_spawn(enemy_type, origin + Vector2.RIGHT.rotated(angle) * 96.0)

func spawn_enemy_minion_mix(origin: Vector2, count: int, types: Array) -> void:
	if types.is_empty():
		return
	for index in range(count):
		var enemy_type := str(types[index % types.size()])
		var angle := TAU * float(index) / float(max(count, 1))
		_queue_enemy_spawn(enemy_type, origin + Vector2.RIGHT.rotated(angle) * 112.0)

func apply_enemy_support_aura(origin: Vector2, radius: float, speed_mult: float, attack_mult: float, duration: float) -> void:
	for enemy in get_nearby_enemy_target_nodes(origin, radius):
		if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("apply_aura"):
			continue
		if enemy.has_method("is_champion") and bool(enemy.is_champion()):
			continue
		enemy.apply_aura(speed_mult, attack_mult)
		var aura_target = enemy
		var timer := get_tree().create_timer(maxf(duration, 0.1))
		timer.timeout.connect(func() -> void:
			if aura_target != null and is_instance_valid(aura_target) and aura_target.has_method("clear_aura"):
				aura_target.clear_aura()
		)

func spawn_champion_deflector_minions(origin: Vector2, count: int) -> Array:
	var shield_nodes: Array = []
	for index in range(count):
		var angle := TAU * float(index) / float(max(count, 1))
		var node := _spawn_enemy_instance("splitter_mini", origin + Vector2.RIGHT.rotated(angle) * 150.0, 3.75)
		if node != null:
			shield_nodes.append(node)
	return shield_nodes

func spawn_hive_shield_minions(origin: Vector2, count: int) -> Array:
	return spawn_champion_deflector_minions(origin, count)

func spawn_pulsar_emp(origin: Vector2, lockout_seconds: float, color: Color) -> void:
	for player in _player_nodes:
		if player != null and is_instance_valid(player) and player.has_method("apply_ability_lockout"):
			player.apply_ability_lockout(lockout_seconds)
	spawn_enemy_shockwave(origin, 520.0, 0, 420.0, color, false)
	_spawn_screen_flash(Color(color.r, color.g, color.b, 0.18), 0.22)

func schedule_pulsar_emp(origin: Vector2, lockout_seconds: float, color: Color, delay: float) -> void:
	if delay <= 0.0:
		spawn_pulsar_emp(origin, lockout_seconds, color)
		return
	_scheduled_pulsar_emps.append({
		"trigger_at": _room_elapsed + delay,
		"origin": origin,
		"lockout_seconds": lockout_seconds,
		"color": color,
	})

func _update_scheduled_pulsar_emps() -> void:
	if _scheduled_pulsar_emps.is_empty():
		return
	var remaining: Array = []
	for scheduled in _scheduled_pulsar_emps:
		var entry := scheduled as Dictionary
		if _room_elapsed >= float(entry.get("trigger_at", INF)):
			spawn_pulsar_emp(
				entry.get("origin", Vector2.ZERO),
				float(entry.get("lockout_seconds", 0.0)),
				entry.get("color", Color.WHITE)
			)
		else:
			remaining.append(scheduled)
	_scheduled_pulsar_emps = remaining

func spawn_enemy_burst(origin: Vector2, count: int, phase: float) -> void:
	for index in range(count):
		var enemy_type := "chaser"
		if phase >= 0.33 and index % 3 == 0:
			enemy_type = "charger"
		if phase >= 0.66 and index % 4 == 0:
			enemy_type = "spitter"
		var angle := TAU * float(index) / float(max(count, 1))
		_queue_enemy_spawn(enemy_type, origin + Vector2.RIGHT.rotated(angle) * 160.0)

func handle_enemy_charge_windup(origin: Vector2) -> void:
	var ring := ParticleFactoryData.create_impact_ring(Color(1.0, 0.76, 0.48, 0.82), 64.0, 3.0)
	ring.global_position = origin
	effects.add_child(ring)

func spawn_enemy_attack_trail(origin: Vector2, direction: Vector2, color: Color, weight: float) -> void:
	var trail := ParticleFactoryData.create_attack_trail(color, direction, weight)
	trail.global_position = origin
	effects.add_child(trail)

func handle_enemy_death_explosion(origin: Vector2, radius: float, damage: int) -> void:
	for player in _player_nodes:
		if player == null or not is_instance_valid(player) or not player.is_alive():
			continue
		if player.global_position.distance_to(origin) <= radius:
			player.apply_damage(damage)
	var burst := ParticleFactoryData.create_explosion_burst(Color(1.0, 0.54, 0.22, 1.0), 1.1)
	burst.global_position = origin
	effects.add_child(burst)
	var ring := ParticleFactoryData.create_explosion_ring(Color(1.0, 0.78, 0.48, 0.88), radius, 3.0)
	ring.global_position = origin
	effects.add_child(ring)

func get_active_players() -> Array:
	var active_players: Array = []
	for player in _player_nodes:
		if player != null and is_instance_valid(player) and player.is_alive():
			active_players.append(player)
	return active_players

func get_player_configs() -> Array:
	return _player_configs

func get_active_boss():
	return _wave_director.get_active_boss() if _wave_director != null else null

func get_room_config() -> Dictionary:
	return _room_config.duplicate(true)

func get_room_type() -> String:
	return _room_type

func get_room_depth() -> int:
	return _room_depth

func get_room_duration() -> float:
	return _wave_director.get_room_duration() if _wave_director != null else 0.0

func get_room_elapsed() -> float:
	return _room_elapsed

func is_spawning_done() -> bool:
	return _wave_director.is_spawning_done() if _wave_director != null else false

func get_side_objective_view() -> Dictionary:
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

func get_revive_progress_for_player_id(player_id: int) -> float:
	return float(_revive_progress_by_player_id.get(player_id, 0.0))

func get_revive_hold_duration() -> float:
	return REVIVE_HOLD_DURATION

func get_active_modifiers() -> Array:
	return _active_modifiers.duplicate()

func get_modifier_definitions() -> Dictionary:
	return _modifier_definitions

func get_momentum_tier(player_index: int) -> int:
	return int(_momentum_tier_by_player[player_index]) if player_index >= 0 and player_index < _momentum_tier_by_player.size() else 0

func get_minor_modifier_flags() -> Dictionary:
	return _minor_modifier_flags.duplicate()

func get_player_count() -> int:
	return _player_nodes.size()

func _get_nearest_player_to(origin: Vector2):
	return get_nearest_player_to(origin)

func get_nearest_player_to(origin: Vector2):
	var best_player = null
	var best_distance_sq := INF
	for player in _player_nodes:
		if player == null or not is_instance_valid(player) or not player.has_method("is_alive") or not player.is_alive():
			continue
		var distance_sq := origin.distance_squared_to(player.global_position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best_player = player
	return best_player

func get_arena_rect() -> Rect2:
	return ARENA_RECT

func get_player_target_nodes() -> Array:
	return _player_nodes

func get_projectile_nodes() -> Array:
	return projectiles.get_children()

func get_enemy_target_nodes() -> Array:
	return _enemy_nodes

func get_enemy_count() -> int:
	return _enemy_nodes.size()

func get_nearby_enemy_target_nodes(world_position: Vector2, radius: float) -> Array:
	_rebuild_enemy_separation_grid_if_needed()
	var results: Array = []
	var center_cell := _get_enemy_separation_cell(world_position)
	var cell_radius := int(ceil(radius / ENEMY_SEPARATION_CELL_SIZE))
	for cell_x in range(center_cell.x - cell_radius, center_cell.x + cell_radius + 1):
		for cell_y in range(center_cell.y - cell_radius, center_cell.y + cell_radius + 1):
			var key := Vector2i(cell_x, cell_y)
			if _enemy_separation_grid.has(key):
				results.append_array(_enemy_separation_grid[key] as Array)
	return results

func _rebuild_enemy_separation_grid_if_needed() -> void:
	var current_frame := Engine.get_physics_frames()
	if _enemy_separation_grid_frame == current_frame:
		return
	_enemy_separation_grid_frame = current_frame
	_enemy_separation_grid.clear()
	for enemy in _enemy_nodes:
		if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue
		var key := _get_enemy_separation_cell((enemy as Node2D).global_position)
		if not _enemy_separation_grid.has(key):
			_enemy_separation_grid[key] = []
		(_enemy_separation_grid[key] as Array).append(enemy)

func _get_enemy_separation_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_position.x / ENEMY_SEPARATION_CELL_SIZE)),
		int(floor(world_position.y / ENEMY_SEPARATION_CELL_SIZE))
	)

func _get_player_spawn_position(index: int) -> Vector2:
	if _room_type == "boss":
		return _get_boss_room_player_spawn_position(index)
	return ArenaGeometry.default_player_spawn_position(index, ARENA_CENTER)

func _get_boss_room_player_spawn_position(index: int) -> Vector2:
	var player_count := maxi(_player_nodes.size(), _player_configs.size())
	return ArenaGeometry.boss_room_player_spawn_position(index, player_count, ARENA_CENTER, ARENA_RECT, BOSS_PLAYER_SPAWN_DISTANCE)

func _get_enemy_spawn_position() -> Vector2:
	var inner_margin := ARENA_MARGIN + 48.0
	var edge := randi() % 4
	return ArenaGeometry.enemy_spawn_position_for_edge(edge, inner_margin, ARENA_SIZE)

func _get_elite_spawn_position() -> Vector2:
	var best_position := _get_enemy_spawn_position()
	var best_distance_sq := -1.0
	for attempt in range(12):
		var candidate := _get_enemy_spawn_position_for_index(attempt, randi() % 4)
		var min_distance_sq := INF
		for player_index in range(maxi(_player_configs.size(), 1)):
			var spawn_position := ArenaGeometry.default_player_spawn_position(player_index, ARENA_CENTER)
			min_distance_sq = minf(min_distance_sq, candidate.distance_squared_to(spawn_position))
		if min_distance_sq >= 600.0 * 600.0:
			return candidate
		if min_distance_sq > best_distance_sq:
			best_distance_sq = min_distance_sq
			best_position = candidate
	return best_position

func _get_enemy_spawn_position_for_index(spawn_index: int, start_edge: int) -> Vector2:
	var inner_margin := ARENA_MARGIN + 48.0
	return ArenaGeometry.enemy_spawn_position_for_index(spawn_index, start_edge, inner_margin, ARENA_SIZE)

func _lock_player_input(locked: bool) -> void:
	for player in _player_nodes:
		if player != null and is_instance_valid(player):
			player.set_input_locked(locked)

func _set_game_paused(paused: bool) -> void:
	_game_paused = paused
	pause_panel.visible = paused
	_lock_player_input(paused)
	_set_runtime_pause_state(paused)
	get_tree().paused = paused
	if paused:
		_ensure_pause_encyclopedia_button()
		resume_button.grab_focus()
		_populate_pause_build_overlay()

func _set_runtime_pause_state(paused: bool) -> void:
	_set_nodes_physics_paused(projectiles.get_children(), paused)
	_set_nodes_physics_paused(pickups.get_children(), paused)
	_set_nodes_physics_paused(effects.get_children(), paused)
	_set_nodes_physics_paused(_enemy_nodes, paused)
	_set_nodes_physics_paused(_active_hazards, paused)
	_set_nodes_physics_paused(_active_mines, paused)
	_set_nodes_physics_paused(_active_decoys, paused)
	_set_nodes_physics_paused(_active_turrets, paused)
	_set_nodes_physics_paused(_active_orbits, paused)
	for modifier in [_fire_floor_modifier, _ice_zone_modifier, _mine_field_modifier, _shrinking_arena_modifier, _hold_zone]:
		_set_single_node_physics_paused(modifier, paused)

func _set_nodes_physics_paused(nodes: Array, paused: bool) -> void:
	for node in nodes:
		_set_single_node_physics_paused(node, paused)

func _set_single_node_physics_paused(node, paused: bool) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.set_process(not paused)
	node.set_physics_process(not paused)

func _sync_player_health_state(player) -> void:
	if player == null or not is_instance_valid(player):
		return
	var player_index := int(player.player_index)
	if player_index < 0 or player_index >= RunState.player_health_states.size():
		return
	RunState.player_health_states[player_index] = player.get_health_state()

func _on_retry_pressed() -> void:
	_set_game_paused(false)
	_start_room()

func _on_resume_pressed() -> void:
	_set_game_paused(false)

func _on_main_menu_pressed() -> void:
	_set_game_paused(false)
	return_to_menu_requested.emit()

func _ensure_pause_encyclopedia_button() -> void:
	var pause_layout := pause_panel.get_node_or_null("CenterContainer/PauseLayout")
	if pause_layout == null or pause_layout.get_node_or_null("EncyclopediaButton") != null:
		return
	var button := Button.new()
	button.name = "EncyclopediaButton"
	button.text = "Encyclopedia"
	button.pressed.connect(_open_encyclopedia_overlay)
	pause_layout.add_child(button)
	var retry_index := pause_retry_button.get_index() if pause_retry_button != null else pause_layout.get_child_count() - 1
	pause_layout.move_child(button, retry_index)

func _open_encyclopedia_overlay() -> void:
	var existing := ui_layer.get_node_or_null("EncyclopediaUI")
	if existing != null:
		existing.queue_free()
	var encyclopedia := EncyclopediaUIData.new()
	encyclopedia.name = "EncyclopediaUI"
	ui_layer.add_child(encyclopedia)

func _unhandled_input(event: InputEvent) -> void:
	if _awaiting_mutation_pick:
		return
	if _is_debug_menu_enabled() and event.is_action_pressed("debug_overlay_toggle"):
		_toggle_debug_overlay()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if pause_panel.visible:
			_on_resume_pressed()
		else:
			_set_game_paused(true)
		get_viewport().set_input_as_handled()

func _on_pause_proxy_pressed() -> void:
	if _game_paused:
		_on_resume_pressed()

func _toggle_debug_overlay() -> void:
	if _debug_overlay_panel == null or not is_instance_valid(_debug_overlay_panel):
		return
	_debug_overlay_panel.visible = not _debug_overlay_panel.visible

func _on_debug_spawn_pressed() -> void:
	if _debug_spawn_option == null:
		return
	var enemy_type := str(_debug_spawn_option.get_selected_metadata())
	var spawn_position := ARENA_CENTER
	var target: Node2D = _get_nearest_player_to(ARENA_CENTER)
	if target != null and is_instance_valid(target):
		spawn_position = target.global_position + Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * 360.0
	var spawned := _spawn_enemy_instance(enemy_type, spawn_position)
	if spawned != null and spawned.has_method("apply_champion_scale") and EnemyTypes.is_champion(enemy_type):
		spawned.apply_champion_scale(_room_depth, _player_nodes.size())

func _on_debug_give_weapon_level_pressed() -> void:
	RunState.level_up_weapon(0)
	_rebuild_player_loadouts()
	_refresh_hud()

func _on_debug_set_weapon_pressed() -> void:
	if _debug_weapon_option == null:
		return
	var weapon_id := str(_debug_weapon_option.get_selected_metadata())
	if weapon_id.is_empty():
		return
	RunState.set_active_weapon(0, weapon_id)
	_rebuild_player_loadouts()
	_refresh_hud()

func _on_debug_clear_enemies_pressed() -> void:
	for enemy in _enemy_nodes.duplicate():
		if enemy != null and is_instance_valid(enemy) and enemy.has_method("apply_damage"):
			enemy.apply_damage(999999)

func _on_debug_god_toggled(pressed: bool) -> void:
	RunState.debug_profiling = pressed

func _is_debug_menu_enabled() -> bool:
	if OS.is_debug_build():
		return true
	for arg in OS.get_cmdline_user_args():
		if arg == "--debug-menu":
			return true
	return false

func _ensure_debug_overlay_action() -> void:
	if not InputMap.has_action("debug_overlay_toggle"):
		InputMap.add_action("debug_overlay_toggle")
	if InputMap.action_get_events("debug_overlay_toggle").is_empty():
		var key_event := InputEventKey.new()
		key_event.keycode = KEY_F4
		key_event.physical_keycode = KEY_F4
		InputMap.action_add_event("debug_overlay_toggle", key_event)

func _populate_pause_build_overlay() -> void:
	var pause_layout := pause_panel.get_node_or_null("CenterContainer/PauseLayout")
	if pause_layout == null:
		return
	var existing := pause_layout.get_node_or_null("BuildOverlay")
	if existing != null:
		pause_layout.remove_child(existing)
		existing.queue_free()
	var overlay := VBoxContainer.new()
	overlay.name = "BuildOverlay"
	overlay.add_theme_constant_override("separation", 10)
	pause_layout.add_child(overlay)
	var resume := pause_layout.get_node_or_null("ResumeButton")
	if resume != null:
		pause_layout.move_child(overlay, resume.get_index())
	for player_index in range(_player_nodes.size()):
		var player = _player_nodes[player_index]
		var header := Label.new()
		header.text = "P%d Build" % (player_index + 1)
		header.add_theme_font_size_override("font_size", 15)
		var player_tint: Color = _player_configs[player_index].tint
		header.add_theme_color_override("font_color", player_tint.lightened(0.2))
		overlay.add_child(header)
		var loadout: Dictionary = _compiled_loadouts[player_index] if player_index < _compiled_loadouts.size() else RunState.get_player_runtime_loadout_for(player_index)
		var weapon_stats: Dictionary = loadout.get("weapon_stats", {}) as Dictionary
		var weapon_label := Label.new()
		weapon_label.text = "%s Lv%d - %d dmg @ %.1f/s" % [
			str(loadout.get("weapon_name", "Rifle")),
			int(loadout.get("weapon_level", 1)),
			int(round(float(weapon_stats.get("damage", 16.0)))),
			float(weapon_stats.get("fire_rate", 4.0)),
		]
		weapon_label.add_theme_font_size_override("font_size", 12)
		weapon_label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0, 0.9))
		overlay.add_child(weapon_label)
		var ability_cards := HBoxContainer.new()
		ability_cards.add_theme_constant_override("separation", 8)
		overlay.add_child(ability_cards)
		ability_cards.add_child(_create_build_ability_card(player, player_tint, 0))
		ability_cards.add_child(_create_build_ability_card(player, player_tint, 1))
		var mutations: Array = _mutation_system.get_active_mutations(player_index)
		var counts: Dictionary = {}
		for mutation in mutations:
			var mutation_dict: Dictionary = mutation as Dictionary
			var mutation_id := str(mutation_dict.get("id", ""))
			if mutation_id.is_empty():
				continue
			counts[mutation_id] = {
				"name": str(mutation_dict.get("name", mutation_id)),
				"count": int(counts.get(mutation_id, {}).get("count", 0)) + 1,
				"rarity": str(mutation_dict.get("rarity", "common")),
				"group": str(mutation_dict.get("group", "attribute")),
				"description": str(mutation_dict.get("description", "")),
			}
		if counts.is_empty():
			var empty_label := Label.new()
			empty_label.text = "  No upgrades yet"
			empty_label.add_theme_font_size_override("font_size", 11)
			empty_label.modulate = Color(0.7, 0.78, 0.88, 0.7)
			overlay.add_child(empty_label)
		else:
			var chip_flow := FlowContainer.new()
			chip_flow.add_theme_constant_override("h_separation", 6)
			chip_flow.add_theme_constant_override("v_separation", 4)
			overlay.add_child(chip_flow)
			var sorted_mutations := counts.values()
			sorted_mutations.sort_custom(Callable(self, "_compare_mutation_entries"))
			for entry_variant in sorted_mutations:
				chip_flow.add_child(_create_mutation_chip(entry_variant as Dictionary))
		var stats_line := Label.new()
		var fire_rate := float(player.get_current_fire_rate()) if player.has_method("get_current_fire_rate") else 0.0
		stats_line.text = "Move %d  -  HP %d  -  Fire %.1f/s" % [
			int(round(float(player.move_speed))),
			int(player.max_health),
			fire_rate,
		]
		stats_line.add_theme_font_size_override("font_size", 11)
		stats_line.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0, 0.78))
		overlay.add_child(stats_line)

func _create_build_ability_card(player, player_tint: Color, slot_index: int) -> PanelContainer:
	var slot_data: Dictionary = player.get_ability_hud_data(slot_index)
	var ability_id := str(slot_data.get("skill_id", ""))
	var cooldown := float(slot_data.get("base_cooldown", 0.0))
	if cooldown <= 0.0:
		cooldown = float(_ability_registry.get_definition(ability_id).get("cooldown", 0.0))
	var slot_color := CoopFormat.get_slot_color(player_tint, slot_index, HUD_SLOT_2_COLOR)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(slot_color.r * 0.12, slot_color.g * 0.12, slot_color.b * 0.12, 0.84)
	style.border_color = Color(slot_color.r, slot_color.g, slot_color.b, 0.9)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	card.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 2)
	margin.add_child(layout)
	var trigger := Label.new()
	trigger.text = "LT" if slot_index == 0 else "RT"
	trigger.add_theme_font_size_override("font_size", 10)
	trigger.add_theme_color_override("font_color", slot_color.lightened(0.25))
	layout.add_child(trigger)
	var name_label := Label.new()
	name_label.text = str(slot_data.get("name", "Ability"))
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 0.96))
	layout.add_child(name_label)
	var cooldown_label := Label.new()
	cooldown_label.text = "CD %.1fs" % cooldown
	cooldown_label.add_theme_font_size_override("font_size", 10)
	cooldown_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96, 0.78))
	layout.add_child(cooldown_label)
	return card

func _create_mutation_chip(entry: Dictionary) -> PanelContainer:
	var rarity := str(entry.get("rarity", "common"))
	var rarity_rank := CoopFormat.rarity_rank(rarity)
	var rarity_color := Color(1.0, 0.42, 0.92, 1.0) if rarity_rank >= 2 else (Color(1.0, 0.78, 0.32, 1.0) if rarity_rank == 1 else Color(0.48, 0.74, 1.0, 1.0))
	var group_color := IconFactoryData.get_group_color(str(entry.get("group", "attribute")))
	var chip := PanelContainer.new()
	chip.tooltip_text = str(entry.get("description", ""))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(group_color.r, group_color.g, group_color.b, 0.18 if rarity_rank >= 1 else 0.14)
	style.border_color = rarity_color if rarity_rank >= 1 else group_color
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	chip.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 3)
	chip.add_child(margin)
	var label := Label.new()
	var level_text := " Lv%d" % int(entry.get("count", 1)) if int(entry.get("count", 1)) > 1 and rarity_rank <= 0 else ""
	label.text = "%s%s" % [str(entry.get("name", "")), level_text]
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", rarity_color.lightened(0.18))
	margin.add_child(label)
	return chip

func _compare_mutation_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_rarity_rank := CoopFormat.rarity_rank(str(left.get("rarity", "common")))
	var right_rarity_rank := CoopFormat.rarity_rank(str(right.get("rarity", "common")))
	if left_rarity_rank != right_rarity_rank:
		return left_rarity_rank > right_rarity_rank
	return str(left.get("name", "")).naturalnocasecmp_to(str(right.get("name", ""))) < 0

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _invalidate_runtime_caches() -> void:
	pass
