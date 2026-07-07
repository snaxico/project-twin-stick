extends Node2D

const EnemySceneData = preload("res://scenes/enemies/Enemy.tscn")
const ProjectileSceneData = preload("res://scenes/weapons/Projectile.tscn")
const MutationSystemData = preload("res://scripts/game/MutationSystem.gd")
const AbilityRegistryData = preload("res://scripts/game/AbilityRegistry.gd")
const EnemyTypes = preload("res://scripts/game/EnemyTypes.gd")
const ArenaGeometry = preload("res://scripts/game/ArenaGeometry.gd")
const ProjectileSystemData = preload("res://scripts/game/ProjectileSystem.gd")
const ArenaVisualsData = preload("res://scripts/game/ArenaVisuals.gd")
const GameHudData = preload("res://scripts/game/GameHud.gd")
const WaveDirectorData = preload("res://scripts/game/WaveDirector.gd")
const SideObjectiveControllerData = preload("res://scripts/game/SideObjectiveController.gd")
const MomentumTrackerData = preload("res://scripts/game/MomentumTracker.gd")
const UltimateChargeData = preload("res://scripts/game/UltimateCharge.gd")
const MutationPickFlowData = preload("res://scripts/game/MutationPickFlow.gd")
const CombatEffectsData = preload("res://scripts/game/CombatEffects.gd")
const FireFloorModifierData = preload("res://scripts/modifiers/FireFloorModifier.gd")
const IceZoneModifierData = preload("res://scripts/modifiers/IceZoneModifier.gd")
const MineFieldModifierData = preload("res://scripts/modifiers/MineFieldModifier.gd")
const ShrinkingArenaModifierData = preload("res://scripts/modifiers/ShrinkingArenaModifier.gd")
const TurretNodeData = preload("res://scripts/game/TurretNode.gd")
const OrbitNodeData = preload("res://scripts/game/OrbitNode.gd")
const SummonNodeData = preload("res://scripts/game/SummonNode.gd")
const HealthPickupData = preload("res://scripts/pickups/HealthPickup.gd")
const HazardZoneData = preload("res://scripts/game/HazardZone.gd")
const FireTrailZoneData = preload("res://scripts/weapons/FireTrailZone.gd")
const AbilityMineData = preload("res://scripts/game/AbilityMine.gd")
const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")
const HitStopManagerData = preload("res://scripts/juice/HitStopManager.gd")
const PauseDebugUiData = preload("res://scripts/game/PauseDebugUi.gd")
const FlowFieldData = preload("res://scripts/game/FlowField.gd")

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
const HEALTH_DROP_CHANCE := 0.03
const MAX_ACTIVE_SUMMONS := 5
const ENEMY_SEPARATION_CELL_SIZE := 96.0
const FLOW_FIELD_CELL_SIZE := 100.0
const FLOW_TARGET_UPDATE_INTERVAL := 0.12
const OBSTACLE_EDGE_EXCLUSION := ARENA_MARGIN + 168.0
const OBSTACLE_PLAYER_EXCLUSION_RADIUS := 150.0
const OBSTACLE_CENTER_EXCLUSION_HALF_SIZE := Vector2(420.0, 320.0)
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
	"ability_1",
	"ability_2",
	"ability_3",
	"ability_4",
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
var _room_score_recorded := false
var _pending_pick_consumes_levelup := false
var _pending_champion_bonus_pick := false
var _pending_clear_summary := ""
var _next_boss_hit_feedback_at := 0.0
var _revive_progress_by_player_id: Dictionary = {}
var _active_modifiers: Array = []
var _arena_visuals = null
var _hud = null
var _wave_director = null
var _side_objectives = null
var _momentum_tracker = null
var _ultimate_charge = null
var _mutation_pick_flow = null
var _combat_effects = null
var _pause_debug_ui = null
var _modifier_definitions: Dictionary = {}
var _minor_modifier_flags := {
	"accelerating_waves": false,
	"enemy_speed": false,
	"swarm": false,
	"shielded": false,
	"explosive_death": false,
}
var _fire_floor_modifier = null
var _ice_zone_modifier = null
var _mine_field_modifier = null
var _shrinking_arena_modifier = null
var _active_turrets: Array = []
var _active_orbits: Array = []
var _active_summons: Array = []
var _active_hazards: Array = []
var _active_mines: Array = []
var _next_hud_refresh_at := 0.0
var _enemy_separation_grid: Dictionary = {}
var _enemy_separation_grid_frame := -1
var _projectile_system = null
var _screen_effect_level := "full"
var _hit_stop_manager = null
var arena_obstacles: Node2D = null
var _flow_field = null
var _active_obstacle_rects: Array = []
var _flow_spawn_lane_points: Array = []
var _flow_reachability_warned := false
var _flow_target_update_elapsed := 0.0

func configure_players(configs: Array) -> void:
	_player_configs = configs.duplicate()

func configure_room(room_config: Dictionary) -> void:
	_room_config = room_config.duplicate(true)

func _ready() -> void:
	_pause_debug_ui = PauseDebugUiData.new()
	_pause_debug_ui.name = "PauseDebugUi"
	_pause_debug_ui.setup(
		self,
		ui_layer,
		pause_panel,
		resume_button,
		pause_retry_button,
		pause_main_menu_button,
		_mutation_system,
		_ability_registry
	)
	add_child(_pause_debug_ui)
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
	_side_objectives = SideObjectiveControllerData.new()
	_side_objectives.name = "SideObjectiveController"
	_side_objectives.setup(self, effects, pickups, ARENA_RECT)
	add_child(_side_objectives)
	_momentum_tracker = MomentumTrackerData.new()
	_momentum_tracker.name = "MomentumTracker"
	_momentum_tracker.setup(self)
	add_child(_momentum_tracker)
	_ultimate_charge = UltimateChargeData.new()
	_ultimate_charge.name = "UltimateCharge"
	add_child(_ultimate_charge)
	_mutation_pick_flow = MutationPickFlowData.new()
	_mutation_pick_flow.name = "MutationPickFlow"
	_mutation_pick_flow.setup(self, ui_layer, _mutation_system)
	add_child(_mutation_pick_flow)
	_combat_effects = CombatEffectsData.new()
	_combat_effects.name = "CombatEffects"
	_combat_effects.setup(self, effects, projectiles)
	add_child(_combat_effects)
	_ensure_arena_obstacle_container()
	_flow_field = FlowFieldData.new()
	_flow_field.setup(ARENA_RECT, FLOW_FIELD_CELL_SIZE)
	_hud = GameHudData.new()
	_hud.name = "GameHud"
	_hud.setup(self, ui_layer)
	ui_layer.add_child(_hud)
	_build_hud()
	_build_debug_overlay()
	_spawn_players()
	_start_room()

func _bind_ui() -> void:
	if _pause_debug_ui != null:
		_pause_debug_ui.bind_ui()

func _configure_pause_focus() -> void:
	if _pause_debug_ui != null:
		_pause_debug_ui.configure_pause_focus()

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
	if _pause_debug_ui != null:
		_pause_debug_ui.build_debug_overlay()

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
			"class_id": str(base_loadout.get("class_id", "")),
			"passive_id": str(base_loadout.get("passive_id", "")),
			"weapon_id": str(base_loadout.get("weapon_id", "rifle")),
			"weapon_name": str(base_loadout.get("weapon_name", "Rifle")),
			"weapon_level": int(base_loadout.get("weapon_level", 1)),
			"weapon_stats": compiled_weapon,
			"mutations": _mutation_system.get_active_mutations(index),
			"move_speed": float(base_loadout.get("move_speed", 560.0)),
			"move_speed_bonus": _mutation_system.get_move_speed_bonus(index),
			"max_health": int(round(float(base_loadout.get("max_health", 100)) * _mutation_system.get_max_health_multiplier(index))),
			"heal_disabled": _mutation_system.is_healing_disabled(index),
		}
		for slot_index in range(4):
			var slot_number := slot_index + 1
			var slot_key := "ability_slot_%d" % slot_number
			compiled_loadout[slot_key] = _build_runtime_ability(index, (base_loadout.get(slot_key, {}) as Dictionary).duplicate(true))
			compiled_loadout["ability_slot_%d_id" % slot_number] = str(base_loadout.get("ability_slot_%d_id" % slot_number, ""))
		_compiled_loadouts.append(compiled_loadout)
		_player_nodes[index].apply_loadout(compiled_loadout)
		if _momentum_tracker != null:
			_momentum_tracker.update_players(_player_nodes)
			_momentum_tracker.apply_to_player(index)
	if _ultimate_charge != null:
		_ultimate_charge.update_players(_player_nodes)

func rebuild_player_loadouts() -> void:
	_rebuild_player_loadouts()

func _restore_momentum() -> void:
	if _momentum_tracker != null:
		_momentum_tracker.start_room(_player_nodes)
	if _ultimate_charge != null:
		_ultimate_charge.start_room(_player_nodes)

func _gain_shared_momentum() -> void:
	if _momentum_tracker != null:
		_momentum_tracker.gain_shared_momentum()

func _drop_player_momentum(player_index: int) -> void:
	if _momentum_tracker != null:
		_momentum_tracker.drop_player_momentum(player_index)

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
	_apply_radiance_ability_stats(player_index, ability_definition, stats)
	var ability_type := str(ability_definition.get("type", "instant"))
	var scales_duration := ability_type != "instant" and ability_type != "movement"
	var base_cooldown := float(ability_definition.get("cooldown", 1.0))
	var cooldown := maxf(0.2, base_cooldown * maxf(cooldown_mult, 0.1))
	if _player_has_passive(player_index, "overheat"):
		base_cooldown = 0.5
		cooldown = 0.5
	var duration := maxf(0.0, float(ability_definition.get("duration", 0.0)) * (duration_mult if scales_duration else 1.0))
	for stat_key in ["radius", "orbit_radius", "distance"]:
		if stats.has(stat_key):
			stats[stat_key] = float(stats[stat_key]) * area_mult
	for stat_key in ["duration", "trail_duration"]:
		if scales_duration and stats.has(stat_key):
			stats[stat_key] = float(stats[stat_key]) * duration_mult
	return {
		"id": ability_id,
		"name": str(ability_definition.get("name", "Ability")),
		"type": ability_type,
		"slot": str(ability_definition.get("slot", "")),
		"cooldown": cooldown,
		"base_cooldown": base_cooldown,
		"duration": duration,
		"stats": stats,
	}

func _player_has_passive(player_index: int, passive_id: String) -> bool:
	if player_index >= 0 and player_index < _player_nodes.size():
		var player = _player_nodes[player_index]
		if player != null and is_instance_valid(player) and player.has_method("has_passive"):
			return bool(player.has_passive(passive_id))
	var inventory = RunState.get_player_inventory(player_index)
	return inventory != null and str(inventory.passive_id) == passive_id

func _apply_radiance_ability_stats(player_index: int, ability_definition: Dictionary, stats: Dictionary) -> void:
	if not _player_has_passive(player_index, "radiance"):
		return
	if not (ability_definition.get("tags", []) as Array).has("summon"):
		return
	for key in ["damage"]:
		if stats.has(key):
			stats[key] = int(round(float(stats[key]) * 1.2))
	for key in ["turret_health", "orbit_health", "mine_health", "health"]:
		if stats.has(key):
			stats[key] = int(round(float(stats[key]) * 1.45))
	if stats.has("fire_rate"):
		stats["fire_rate"] = float(stats["fire_rate"]) * 1.15

func _update_radiance_auras() -> void:
	for player in _player_nodes:
		if player != null and is_instance_valid(player) and player.has_method("clear_zone_modifier"):
			player.clear_zone_modifier("radiance")
	for source in _player_nodes:
		if source == null or not is_instance_valid(source) or not source.has_method("has_passive") or not source.has_passive("radiance"):
			continue
		if source.has_method("is_alive") and not source.is_alive():
			continue
		for target in _player_nodes:
			if target == null or not is_instance_valid(target) or not target.has_method("apply_zone_modifier"):
				continue
			if target.global_position.distance_squared_to(source.global_position) > 360.0 * 360.0:
				continue
			target.apply_zone_modifier("radiance", 1.0, 1.0, 1.15)

func _apply_bloodthirst_on_kill(enemy) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("get_last_damage_player_index"):
		return
	var player_index := int(enemy.get_last_damage_player_index())
	if player_index < 0 or player_index >= _player_nodes.size():
		return
	var player = _player_nodes[player_index]
	if player == null or not is_instance_valid(player) or not player.has_method("apply_bloodthirst_heal"):
		return
	if not player.has_method("has_passive") or not player.has_passive("bloodthirst"):
		return
	var heal_amount := 2
	if _mutation_system.has_mutation(player_index, "gorge"):
		heal_amount += 3
	var overshield_mult := 1.35 if _mutation_system.has_mutation(player_index, "overflow") else 1.0
	player.apply_bloodthirst_heal(heal_amount, overshield_mult)

func _start_room() -> void:
	_clear_runtime_nodes()
	_projectile_system.ensure_renderer()
	_prewarm_combat_vfx()
	_set_game_paused(false)
	_set_music_context("combat")
	_spawn_screen_flash(Color(0.0, 0.0, 0.0, 0.5), 0.4)  # room-intro fade-in from black
	_rebuild_player_loadouts()
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
	_setup_room_obstacles()
	_wave_director.start_room(_room_config, _room_enemy_pool, _room_depth)
	_arena_visuals.apply_arena_color()
	_side_objectives.start_room(_room_config, _player_nodes)
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
	_update_flow_field_targets()
	_apply_active_modifiers()
	_wave_director.spawn_opening_burst()
	_refresh_hud()

func _clear_runtime_nodes() -> void:
	_ensure_arena_obstacle_container()
	for node in [projectiles, enemies, pickups, effects, arena_obstacles]:
		for child in node.get_children():
			child.queue_free()
	_enemy_nodes.clear()
	_active_turrets.clear()
	_active_orbits.clear()
	_active_summons.clear()
	_active_hazards.clear()
	_active_mines.clear()
	if _projectile_system != null:
		_projectile_system.clear_runtime()
	if _side_objectives != null:
		_side_objectives.clear_runtime()
	_fire_floor_modifier = null
	_ice_zone_modifier = null
	_mine_field_modifier = null
	_shrinking_arena_modifier = null
	if _combat_effects != null:
		_combat_effects.clear_runtime()
	_enemy_separation_grid.clear()
	_enemy_separation_grid_frame = -1
	_active_obstacle_rects.clear()
	_flow_spawn_lane_points.clear()
	_flow_reachability_warned = false
	_flow_target_update_elapsed = 0.0
	if _flow_field != null:
		_flow_field.build([])
	_invalidate_runtime_caches()

func _ensure_arena_obstacle_container() -> void:
	if arena_obstacles != null and is_instance_valid(arena_obstacles):
		return
	arena_obstacles = Node2D.new()
	arena_obstacles.name = "ArenaObstacles"
	add_child(arena_obstacles)

func _setup_room_obstacles() -> void:
	_ensure_arena_obstacle_container()
	for child in arena_obstacles.get_children():
		child.queue_free()
	_active_obstacle_rects.clear()
	_flow_spawn_lane_points = _build_flow_spawn_lane_points()
	_flow_reachability_warned = false
	_flow_target_update_elapsed = 0.0
	if _flow_field == null:
		_flow_field = FlowFieldData.new()
		_flow_field.setup(ARENA_RECT, FLOW_FIELD_CELL_SIZE)
	var raw_obstacles: Array = (_room_config.get("obstacles", []) as Array).duplicate(true)
	if raw_obstacles.is_empty():
		_flow_field.build([])
		return
	var accepted_rects: Array = []
	for obstacle_variant in raw_obstacles:
		var obstacle_rect := _parse_obstacle_rect(obstacle_variant)
		if obstacle_rect.size.x <= 0.0 or obstacle_rect.size.y <= 0.0:
			push_warning("CoopManager: rejected invalid arena obstacle %s" % str(obstacle_variant))
			continue
		if not _is_obstacle_rect_spawn_safe(obstacle_rect):
			push_warning("CoopManager: rejected unsafe arena obstacle %s" % str(obstacle_variant))
			continue
		accepted_rects.append(obstacle_rect)
	_flow_field.build(accepted_rects)
	if not accepted_rects.is_empty() and not _flow_field.validate_connectivity(_build_flow_connectivity_points()):
		push_warning("CoopManager: rejected arena obstacle layout because it partitions spawn lanes from play space")
		accepted_rects.clear()
		_flow_field.build([])
	_active_obstacle_rects = accepted_rects
	for obstacle_rect in _active_obstacle_rects:
		_spawn_arena_obstacle(obstacle_rect)

func _parse_obstacle_rect(obstacle_variant) -> Rect2:
	if obstacle_variant is Rect2:
		return _clamp_obstacle_rect(obstacle_variant as Rect2)
	if not (obstacle_variant is Dictionary):
		return Rect2()
	var obstacle := obstacle_variant as Dictionary
	var rect := Rect2(
		Vector2(float(obstacle.get("x", 0.0)), float(obstacle.get("y", 0.0))),
		Vector2(float(obstacle.get("w", 0.0)), float(obstacle.get("h", 0.0)))
	)
	return _clamp_obstacle_rect(rect)

func _clamp_obstacle_rect(rect: Rect2) -> Rect2:
	var clipped := rect.abs().intersection(ARENA_RECT)
	return clipped if clipped.size.x > 0.0 and clipped.size.y > 0.0 else Rect2()

func _is_obstacle_rect_spawn_safe(obstacle_rect: Rect2) -> bool:
	var inflated := obstacle_rect.grow(_get_flow_obstacle_inflation())
	for exclusion_rect in _build_obstacle_exclusion_rects():
		if inflated.intersects(exclusion_rect):
			return false
	return true

func _build_obstacle_exclusion_rects() -> Array:
	var exclusions: Array = [
		Rect2(Vector2.ZERO, Vector2(ARENA_SIZE.x, OBSTACLE_EDGE_EXCLUSION)),
		Rect2(Vector2(0.0, ARENA_SIZE.y - OBSTACLE_EDGE_EXCLUSION), Vector2(ARENA_SIZE.x, OBSTACLE_EDGE_EXCLUSION)),
		Rect2(Vector2.ZERO, Vector2(OBSTACLE_EDGE_EXCLUSION, ARENA_SIZE.y)),
		Rect2(Vector2(ARENA_SIZE.x - OBSTACLE_EDGE_EXCLUSION, 0.0), Vector2(OBSTACLE_EDGE_EXCLUSION, ARENA_SIZE.y)),
		Rect2(ARENA_CENTER - OBSTACLE_CENTER_EXCLUSION_HALF_SIZE, OBSTACLE_CENTER_EXCLUSION_HALF_SIZE * 2.0),
	]
	for player_index in range(maxi(_player_configs.size(), 1)):
		var spawn_position := _get_player_spawn_position(player_index)
		exclusions.append(Rect2(
			spawn_position - Vector2(OBSTACLE_PLAYER_EXCLUSION_RADIUS, OBSTACLE_PLAYER_EXCLUSION_RADIUS),
			Vector2(OBSTACLE_PLAYER_EXCLUSION_RADIUS * 2.0, OBSTACLE_PLAYER_EXCLUSION_RADIUS * 2.0)
		))
	return exclusions

func _spawn_arena_obstacle(obstacle_rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.name = "ArenaObstacle"
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_to_group("arena_obstacle")
	body.global_position = obstacle_rect.position + obstacle_rect.size * 0.5
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = obstacle_rect.size
	shape.shape = rectangle
	body.add_child(shape)
	var visual := Polygon2D.new()
	var half_size := obstacle_rect.size * 0.5
	visual.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	visual.color = Color(0.18, 0.2, 0.24, 0.92)
	body.add_child(visual)
	arena_obstacles.add_child(body)

func _get_flow_obstacle_inflation() -> float:
	return float(_flow_field.get_obstacle_inflation()) if _flow_field != null else 84.0

func _build_flow_spawn_lane_points() -> Array:
	var inner_margin := ARENA_MARGIN + 48.0
	var points: Array = []
	for ratio in [0.2, 0.5, 0.8]:
		points.append(Vector2(lerpf(inner_margin, ARENA_SIZE.x - inner_margin, float(ratio)), inner_margin + 30.0))
		points.append(Vector2(lerpf(inner_margin, ARENA_SIZE.x - inner_margin, float(ratio)), ARENA_SIZE.y - inner_margin - 30.0))
		points.append(Vector2(inner_margin + 30.0, lerpf(inner_margin, ARENA_SIZE.y - inner_margin, float(ratio))))
		points.append(Vector2(ARENA_SIZE.x - inner_margin - 30.0, lerpf(inner_margin, ARENA_SIZE.y - inner_margin, float(ratio))))
	return points

func _build_flow_connectivity_points() -> Array:
	var points := _flow_spawn_lane_points.duplicate()
	points.append(ARENA_CENTER)
	for player_index in range(maxi(_player_configs.size(), 1)):
		points.append(_get_player_spawn_position(player_index))
	return points

func _update_flow_field_targets() -> void:
	if _flow_field == null or not _flow_field.has_obstacles():
		return
	var player_positions: Array = []
	for player in _player_nodes:
		if player == null or not is_instance_valid(player) or not (player is Node2D):
			player_positions.append(null)
			continue
		if player.has_method("is_alive") and not player.is_alive():
			player_positions.append(null)
			continue
		player_positions.append((player as Node2D).global_position)
	_flow_field.update_targets(player_positions)
	if _flow_reachability_warned:
		return
	for player_index in range(player_positions.size()):
		if player_positions[player_index] == null:
			continue
		if not _flow_field.target_reaches_points(player_index, _flow_spawn_lane_points):
			_flow_reachability_warned = true
			push_warning("CoopManager: arena flow field for player %d cannot reach all enemy spawn lanes" % player_index)
			return

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
	if (_pause_debug_ui != null and _pause_debug_ui.is_game_paused()) or pause_panel.visible or get_tree().paused:
		return
	_room_elapsed += delta
	_update_screen_atmosphere()
	_combat_effects.update_scheduled_enemy_shockwaves()
	_combat_effects.update_scheduled_player_shockwaves()
	_combat_effects.update_scheduled_enemy_hazards()
	_combat_effects.update_scheduled_pulsar_emps()
	_projectile_system.tick(delta)
	_side_objectives.update(delta, _player_nodes)
	_flow_target_update_elapsed += delta
	if _flow_target_update_elapsed >= FLOW_TARGET_UPDATE_INTERVAL:
		_flow_target_update_elapsed = 0.0
		_update_flow_field_targets()
	_update_radiance_auras()
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

func register_hazard_zone(hazard: Node) -> void:
	if hazard != null and is_instance_valid(hazard) and not _active_hazards.has(hazard):
		_active_hazards.append(hazard)

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
		_mutation_pick_flow.show_pick(false, "Level Up", "Choose one upgrade.")
		return
	if _room_type == "boss" and not _pending_champion_bonus_pick:
		_pending_champion_bonus_pick = true
		_pending_pick_consumes_levelup = false
		_mutation_pick_flow.show_pick(true, "Champion Reward", "Guaranteed rare pressure. Choose one upgrade.")
		return
	_finish_room_progression()

func _show_mutation_pick(force_rare: bool, title: String, subtitle: String) -> void:
	_mutation_pick_flow.show_pick(force_rare, title, subtitle)

func _on_mutation_selections_confirmed(selections_per_player: Array) -> void:
	for player_index in range(min(selections_per_player.size(), _player_nodes.size())):
		for mutation_id in (selections_per_player[player_index] as Array):
			_mutation_system.apply_mutation(player_index, str(mutation_id))
	if _pending_pick_consumes_levelup:
		RunState.spend_levelup()
	_mutation_pick_flow.close_pick()
	_rebuild_player_loadouts()
	if _pending_pick_consumes_levelup and RunState.get_pending_levelups() > 0:
		_show_progression_pick_if_needed()
		return
	if _pending_pick_consumes_levelup and _room_type == "boss" and not _pending_champion_bonus_pick:
		_pending_pick_consumes_levelup = false
		_pending_champion_bonus_pick = true
		_mutation_pick_flow.show_pick(true, "Champion Reward", "Guaranteed rare pressure. Choose one upgrade.")
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
	return _side_objectives.build_clear_summary() if _side_objectives != null else "Room cleared."

func _on_player_fire_requested(origin: Vector2, direction: Vector2, projectile_config: Dictionary) -> void:
	_projectile_system.handle_player_fire(origin, direction, projectile_config)

func _on_player_ability_activated(player, slot_index: int, ability_id: String, origin: Vector2, direction: Vector2, stats: Dictionary) -> void:
	var tint: Color = stats.get("color", Color.WHITE)
	_spawn_ability_activation_flash(origin, tint, ability_id)
	_play_sfx("play_explosion", [0.85, ability_id])
	match ability_id:
		"shockwave":
			_combat_effects.spawn_player_shockwave(origin, stats)
			_combat_effects.schedule_player_shockwave_resonance(origin, stats)
		"dash":
			_spawn_dash_effect(origin, direction, tint)
		"shield":
			_spawn_shield_effect(origin, float(stats.get("radius", 78.0)), tint)
		"turret":
			var turret := TurretNodeData.new()
			turret.global_position = origin
			turret.configure(stats, tint, player)
			turret.fire_requested.connect(_on_player_fire_requested)
			effects.add_child(turret)
			_active_turrets.append(turret)
		"minefield":
			_spawn_ability_mines(origin, stats)
		"orbit":
			var orbit := OrbitNodeData.new()
			orbit.configure(player, stats, tint)
			effects.add_child(orbit)
			_active_orbits.append(orbit)
		"afterburn":
			_spawn_player_fire_zone(origin, stats)
			_spawn_zone_cast_pulse(origin, float(stats.get("trail_radius", stats.get("radius", 120.0))), tint, 0.75)
		"momentum_burst":
			var burst_stats := stats.duplicate(true)
			var momentum_tier := 0
			if player != null and is_instance_valid(player) and "player_index" in player and _momentum_tracker != null:
				momentum_tier = int(_momentum_tracker.get_momentum_tier(int(player.player_index)))
			burst_stats["damage"] = int(round(float(burst_stats.get("damage", 24.0)) + float(momentum_tier) * float(burst_stats.get("momentum_damage_per_tier", 8.0))))
			_combat_effects.spawn_player_shockwave(origin, burst_stats)
		"deflect":
			_deflect_enemy_projectiles(origin, stats)
		"sonic_boom":
			_fire_ability_projectile(player, origin, direction, stats)
		"ground_slam":
			_combat_effects.spawn_player_shockwave(origin, stats)
		"quake":
			_spawn_player_fire_zone(origin, stats)
			_spawn_zone_cast_pulse(origin, float(stats.get("radius", 150.0)), tint, 1.1)
		"blood_lance":
			_fire_ability_projectile(player, origin, direction, stats)
		"summon":
			_spawn_summons(player, origin, stats, tint)
		"reinforce":
			_reinforce_deployables(origin, stats, tint)
		"fireball":
			_fire_ability_projectile(player, origin, direction, stats)
		"ignite":
			_ignite_nearby_enemies(origin, stats, tint)
		"slipstream":
			_apply_timed_player_modifier(player, "slipstream", stats)
			_apply_slipstream_world_slow(stats)
			if player != null and is_instance_valid(player) and player.has_method("recharge_dash_slots"):
				player.recharge_dash_slots()
			_spawn_slipstream_aura(origin, tint, float(stats.get("duration", 5.0)))
			_deflect_enemy_projectiles(origin, stats)
		"blood_frenzy":
			_apply_timed_player_modifier(player, "blood_frenzy", stats)
			_spawn_zone_cast_pulse(origin, 180.0, Color(1.0, 0.12, 0.16, 0.92), 1.25)
			if player != null and is_instance_valid(player) and player.has_method("apply_bloodthirst_heal"):
				player.apply_bloodthirst_heal(int(stats.get("heal", 35)), 1.0)
		"overload_grid":
			_spawn_zone_cast_pulse(origin, 260.0, tint.lightened(0.16), 1.25)
			_activate_overload_grid(player, origin, stats, tint)
		"firestorm":
			_spawn_zone_cast_pulse(origin, float(stats.get("spread_radius", 260.0)), tint, 1.25)
			_activate_firestorm(origin, stats)
		"overcharge":
			var burst := ParticleFactoryData.create_explosion_burst(tint, 1.15)
			burst.global_position = origin
			effects.add_child(burst)
	if slot_index == 3 and _ultimate_charge != null and player != null and is_instance_valid(player):
		_ultimate_charge.reset(int(player.player_index))

func _spawn_player_shockwave(origin: Vector2, stats: Dictionary) -> void:
	_combat_effects.spawn_player_shockwave(origin, stats)

func _schedule_player_shockwave_resonance(origin: Vector2, stats: Dictionary) -> void:
	_combat_effects.schedule_player_shockwave_resonance(origin, stats)

func _spawn_dash_effect(origin: Vector2, direction: Vector2, color: Color) -> void:
	var burst := ParticleFactoryData.create_dash_burst(color, direction, 1.0)
	burst.global_position = origin
	effects.add_child(burst)
	_play_sfx("play_dash", [1.0])

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
	var mine_health := int(stats.get("mine_health", 45))
	var tint: Color = stats.get("color", Color.WHITE)
	for mine_index in range(mine_count):
		var angle := TAU * float(mine_index) / float(max(mine_count, 1))
		var mine := AbilityMineData.new()
		mine.global_position = origin + Vector2.RIGHT.rotated(angle) * spread_radius
		mine.configure(radius, damage, tint, trigger_radius, mine_health, int(stats.get("source_player_index", -1)))
		effects.add_child(mine)
		_active_mines.append(mine)

func _spawn_player_fire_zone(origin: Vector2, stats: Dictionary) -> void:
	var zone := FireTrailZoneData.new()
	zone.global_position = origin
	zone.configure(
		float(stats.get("radius", stats.get("trail_radius", 120.0))),
		int(round(float(stats.get("damage", stats.get("burn_dps", 8.0))))),
		float(stats.get("duration", stats.get("trail_lifetime", 2.0))),
		float(stats.get("tick_interval", 0.4)),
		"player",
		float(stats.get("knockback_force", 0.0)),
		int(stats.get("source_player_index", -1))
	)
	effects.add_child(zone)

func _deflect_enemy_projectiles(origin: Vector2, stats: Dictionary) -> void:
	var radius := float(stats.get("radius", 190.0))
	var destroyed := 0
	for projectile in projectiles.get_children():
		if projectile == null or not is_instance_valid(projectile):
			continue
		if projectile.has_method("is_projectile_active") and not projectile.is_projectile_active():
			continue
		if not ("team" in projectile) or str(projectile.team) != "enemy":
			continue
		if projectile.global_position.distance_squared_to(origin) > radius * radius:
			continue
		destroyed += 1
		if projectile.has_method("_finish_projectile"):
			projectile._finish_projectile()
		else:
			projectile.queue_free()
	var damage := int(stats.get("reflect_damage", 0)) + destroyed * int(stats.get("damage_per_projectile", 2))
	if damage > 0:
		for enemy in get_nearby_enemy_target_nodes(origin, radius):
			if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("is_alive") or not enemy.is_alive():
				continue
			enemy.apply_damage(damage, int(stats.get("source_player_index", -1)))
	_spawn_shockwave_visual(origin, radius, stats.get("color", Color.WHITE), float(stats.get("expand_duration", 0.12)))

func _fire_ability_projectile(player, origin: Vector2, direction: Vector2, stats: Dictionary) -> void:
	var projectile_config := stats.duplicate(true)
	projectile_config["team"] = "player"
	projectile_config["color"] = stats.get("color", Color.WHITE)
	projectile_config["shooter"] = player
	projectile_config["source_type"] = "ability"
	projectile_config["source_player_index"] = int(stats.get("source_player_index", -1))
	projectile_config["speed"] = float(projectile_config.get("speed", projectile_config.get("projectile_speed", 780.0)))
	projectile_config["max_distance"] = float(projectile_config.get("range", projectile_config.get("max_distance", 780.0)))
	projectile_config["collision_half_width"] = float(projectile_config.get("collision_half_width", projectile_config.get("width", 8.0)))
	projectile_config["projectile_kind"] = str(projectile_config.get("projectile_kind", "bullet"))
	projectile_config["feedback_profile"] = str(projectile_config.get("feedback_profile", "ability"))
	projectile_config["impact_weight"] = float(projectile_config.get("impact_weight", 1.25))
	projectile_config["projectile_shape"] = str(projectile_config.get("projectile_shape", "orb"))
	projectile_config["use_lifetime"] = true
	_on_player_fire_requested(origin + direction.normalized() * 28.0, direction, projectile_config)

func _spawn_summons(player, origin: Vector2, stats: Dictionary, tint: Color) -> void:
	var construct_count := maxi(1, int(stats.get("construct_count", 2)))
	var spread_radius := float(stats.get("spread_radius", 70.0))
	for summon_index in range(construct_count):
		_enforce_summon_cap(MAX_ACTIVE_SUMMONS - 1)
		var summon := SummonNodeData.new()
		var angle := TAU * float(summon_index) / float(construct_count)
		summon.global_position = origin + Vector2.RIGHT.rotated(angle) * spread_radius
		summon.configure(player, stats, tint)
		effects.add_child(summon)
		_active_summons.append(summon)
		if not _should_suppress_combat_vfx():
			var flash := ParticleFactoryData.create_explosion_burst(tint.lightened(0.18), 0.72)
			flash.global_position = summon.global_position
			effects.add_child(flash)
	_enforce_summon_cap()

func _reinforce_deployables(origin: Vector2, stats: Dictionary, tint: Color) -> void:
	var repair_amount := int(stats.get("repair_amount", 55))
	var radius := float(stats.get("radius", 520.0))
	var source_player_index := int(stats.get("source_player_index", -1))
	var shield_amount := 0
	if source_player_index >= 0 and _mutation_system.has_mutation(source_player_index, "aegis"):
		shield_amount = int(_mutation_system.get_mutation_param("aegis", "shield_amount", 35))
	for deployable in get_tree().get_nodes_in_group("player_deployable"):
		if deployable == null or not is_instance_valid(deployable) or not (deployable is Node2D):
			continue
		if (deployable as Node2D).global_position.distance_squared_to(origin) > radius * radius:
			continue
		if deployable.has_method("heal_deployable"):
			deployable.heal_deployable(repair_amount)
		if shield_amount > 0 and deployable.has_method("apply_deployable_shield"):
			deployable.apply_deployable_shield(shield_amount)
		if deployable.has_method("heal_deployable") or shield_amount > 0:
			if not _should_suppress_combat_vfx():
				var glint := ParticleFactoryData.create_impact_ring(tint.lightened(0.2), 26.0, 2.2)
				glint.global_position = (deployable as Node2D).global_position
				effects.add_child(glint)
	_spawn_shockwave_visual(origin, radius, tint, 0.18)

func _ignite_nearby_enemies(origin: Vector2, stats: Dictionary, tint: Color) -> void:
	var radius := float(stats.get("radius", 230.0))
	var damage := int(stats.get("damage", 8))
	var source_player_index := int(stats.get("source_player_index", -1))
	for enemy in get_nearby_enemy_target_nodes(origin, radius):
		if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("is_alive") or not enemy.is_alive():
			continue
		if enemy.global_position.distance_squared_to(origin) > radius * radius:
			continue
		if damage > 0:
			enemy.apply_damage(damage, source_player_index)
		if enemy.has_method("apply_poison"):
			enemy.apply_poison(float(stats.get("burn_dps", 8.0)), float(stats.get("burn_duration", 4.0)))
		if enemy.has_method("apply_ignite_on_death"):
			enemy.apply_ignite_on_death(float(stats.get("ignite_radius", 130.0)), int(stats.get("ignite_damage", 20)))
		if not _should_suppress_combat_vfx():
			var embers := ParticleFactoryData.create_projectile_trail(tint.lightened(0.16), "embers")
			embers.global_position = enemy.global_position
			effects.add_child(embers)
			var ember_id: int = int(embers.get_instance_id())
			var timer := get_tree().create_timer(0.22)
			timer.timeout.connect(func():
				var ember_node := instance_from_id(ember_id) as Node
				if ember_node != null:
					ember_node.queue_free()
			)
	_spawn_shockwave_visual(origin, radius, tint, 0.12)

func _apply_timed_player_modifier(player, source: String, stats: Dictionary) -> void:
	if player == null or not is_instance_valid(player) or not player.has_method("apply_zone_modifier"):
		return
	player.apply_zone_modifier(
		source,
		float(stats.get("move_speed_multiplier", 1.0)),
		float(stats.get("attack_speed_multiplier", 1.0)),
		float(stats.get("damage_multiplier", 1.0))
	)
	var duration := maxf(0.1, float(stats.get("duration", 4.0)))
	var player_id: int = int(player.get_instance_id())
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func():
		var player_node := instance_from_id(player_id)
		if player_node != null and player_node.has_method("clear_zone_modifier"):
			player_node.clear_zone_modifier(source)
	)

func _apply_slipstream_world_slow(stats: Dictionary) -> void:
	var multiplier := clampf(float(stats.get("world_slow_multiplier", 0.55)), 0.1, 1.0)
	var duration := maxf(float(stats.get("world_slow_duration", stats.get("duration", 5.0))), 0.1)
	for enemy in _enemy_nodes:
		if enemy != null and is_instance_valid(enemy) and enemy.has_method("apply_slow"):
			enemy.apply_slow(multiplier, duration)
	for projectile in projectiles.get_children():
		if projectile == null or not is_instance_valid(projectile):
			continue
		if "team" in projectile and str(projectile.team) == "enemy" and "speed" in projectile:
			projectile.speed = float(projectile.speed) * multiplier

func _activate_overload_grid(player, origin: Vector2, stats: Dictionary, tint: Color) -> void:
	_reinforce_deployables(origin, stats, tint)
	var summon_stats := stats.duplicate(true)
	summon_stats["construct_count"] = int(stats.get("construct_count", 3))
	summon_stats["construct_health"] = int(stats.get("construct_health", 160))
	summon_stats["damage"] = int(stats.get("damage", 22))
	summon_stats["overcharged"] = true
	_spawn_summons(player, origin, summon_stats, tint.lightened(0.18))

func _activate_firestorm(origin: Vector2, stats: Dictionary) -> void:
	var zone_count := maxi(1, int(stats.get("zone_count", 8)))
	var spread_radius := float(stats.get("spread_radius", 260.0))
	for zone_index in range(zone_count):
		var angle := TAU * float(zone_index) / float(zone_count)
		var zone_stats := stats.duplicate(true)
		zone_stats["radius"] = float(stats.get("radius", 150.0))
		zone_stats["duration"] = float(stats.get("duration", 5.0))
		zone_stats["damage"] = int(stats.get("damage", 18))
		if not _should_suppress_combat_vfx():
			var telegraph := ParticleFactoryData.create_impact_ring(stats.get("color", Color(1.0, 0.35, 0.1, 1.0)), float(zone_stats.get("radius", 150.0)), 2.5)
			telegraph.global_position = origin + Vector2.RIGHT.rotated(angle) * spread_radius
			effects.add_child(telegraph)
		_spawn_player_fire_zone(origin + Vector2.RIGHT.rotated(angle) * spread_radius, zone_stats)
	_spawn_screen_flash(Color(1.0, 0.32, 0.08, 0.18), 0.22)

func _spawn_zone_cast_pulse(origin: Vector2, radius: float, color: Color, weight: float = 1.0) -> void:
	if _should_suppress_combat_vfx():
		return
	var pulse := ParticleFactoryData.create_zone_pulse(color, radius, weight)
	pulse.global_position = origin
	effects.add_child(pulse)

func _spawn_slipstream_aura(origin: Vector2, color: Color, duration: float) -> void:
	if _should_suppress_combat_vfx():
		return
	var aura := Node2D.new()
	aura.global_position = origin
	for index in range(5):
		var streak := Line2D.new()
		streak.width = 3.0
		streak.antialiased = true
		streak.default_color = Color(color.r, color.g, minf(color.b + 0.35, 1.0), 0.55)
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / 5.0)
		streak.points = PackedVector2Array([direction * 24.0, direction * 112.0])
		aura.add_child(streak)
	effects.add_child(aura)
	var tween := aura.create_tween()
	tween.set_parallel(true)
	tween.tween_property(aura, "rotation", TAU, minf(duration, 0.7))
	tween.tween_property(aura, "modulate:a", 0.0, minf(duration, 0.7))
	tween.set_parallel(false)
	tween.tween_callback(aura.queue_free)

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

func spawn_shockwave_visual(center: Vector2, radius: float, color: Color, duration: float) -> void:
	_spawn_shockwave_visual(center, radius, color, duration)

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

func spawn_target_hit_spark(hit_position: Vector2, direction: Vector2, color: Color, weight: float) -> void:
	_spawn_target_hit_spark(hit_position, direction, color, weight)

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

func spawn_screen_flash(color: Color, duration: float) -> void:
	_spawn_screen_flash(color, duration)

func request_pick_dilation() -> void:
	if _hit_stop_manager != null and _hit_stop_manager.has_method("request_dilation"):
		_hit_stop_manager.request_dilation(70, 0.18)

func set_awaiting_pick(awaiting: bool) -> void:
	_awaiting_mutation_pick = awaiting

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

func add_screen_trauma(amount: float) -> void:
	if _screen_effects_enabled() and screen_shake != null and screen_shake.has_method("add_trauma"):
		screen_shake.add_trauma(amount)

func _on_enemy_died(enemy) -> void:
	_enemy_nodes.erase(enemy)
	if _wave_director != null:
		_wave_director.clear_active_boss_if(enemy)
	_enemies_killed += 1
	_gain_shared_momentum()
	_apply_bloodthirst_on_kill(enemy)
	var enemy_type_name := str(enemy.get_type_name())
	if _ultimate_charge != null and enemy.has_method("get_last_damage_player_index"):
		_ultimate_charge.add_kill(int(enemy.get_last_damage_player_index()), EnemyTypes.is_champion(enemy_type_name))
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
	if _side_objectives != null:
		_side_objectives.on_enemy_killed()

func _on_enemy_hit_received(_enemy, _damage_amount: int, _lethal: bool) -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	if _ultimate_charge != null and _enemy.has_method("get_last_damage_player_index"):
		_ultimate_charge.add_damage(int(_enemy.get_last_damage_player_index()), _damage_amount)
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
	hp_pickup.global_position = get_safe_pickup_position(spawn_position)
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
	if _side_objectives != null:
		_side_objectives.on_player_damaged()
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
	var room_max_momentum_tier: int = _momentum_tracker.get_room_max_tier() if _momentum_tracker != null else 0
	return clear_credit + _enemies_killed + _champions_killed * 250 + room_max_momentum_tier * 50

func _refresh_hud() -> void:
	if _hud != null:
		_hud.refresh()

func refresh_hud() -> void:
	_refresh_hud()

func notify_run_score_changed() -> void:
	_refresh_hud()

func _refresh_boss_hud() -> void:
	if _hud != null:
		_hud.refresh_boss()

func play_sfx(method_name: String, args: Array) -> void:
	_play_sfx(method_name, args)

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

func get_current_rare_chance() -> float:
	return _get_current_rare_chance()

func get_signature_share(depth: int) -> float:
	return _signature_share(depth)

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

func _cleanup_helpers() -> void:
	_active_hazards = _cleanup_instance_array(_active_hazards)
	_active_turrets = _cleanup_instance_array(_active_turrets)
	_active_orbits = _cleanup_instance_array(_active_orbits)
	_active_summons = _cleanup_instance_array(_active_summons)
	_active_mines = _cleanup_instance_array(_active_mines)


func _enforce_summon_cap(target_count: int = MAX_ACTIVE_SUMMONS) -> void:
	_active_summons = _cleanup_instance_array(_active_summons)
	while _active_summons.size() > target_count:
		var summon = _active_summons.pop_front()
		if summon == null or not is_instance_valid(summon):
			continue
		if summon.has_method("despawn_deployable"):
			summon.despawn_deployable()
		else:
			summon.queue_free()

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
	_combat_effects.spawn_enemy_shockwave(origin, radius, damage, knockback_force, color, destroy_projectiles)

func schedule_enemy_shockwave(origin: Vector2, radius: float, damage: int, knockback_force: float, color: Color, delay: float, destroy_projectiles: bool = false) -> void:
	_combat_effects.schedule_enemy_shockwave(origin, radius, damage, knockback_force, color, delay, destroy_projectiles)

func _update_scheduled_enemy_shockwaves() -> void:
	_combat_effects.update_scheduled_enemy_shockwaves()

func _update_scheduled_player_shockwaves() -> void:
	_combat_effects.update_scheduled_player_shockwaves()

func schedule_enemy_hazard_zone(origin: Vector2, radius: float, duration: float, damage: int, color: Color, delay: float) -> void:
	_combat_effects.schedule_enemy_hazard_zone(origin, radius, duration, damage, color, delay)

func _update_scheduled_enemy_hazards() -> void:
	_combat_effects.update_scheduled_enemy_hazards()

func spawn_enemy_hazard_zone(origin: Vector2, radius: float, duration: float, damage: int, color: Color) -> void:
	_combat_effects.spawn_enemy_hazard_zone(origin, radius, duration, damage, color)

func spawn_enemy_minions(origin: Vector2, count: int, phase: float, forced_type: String = "") -> void:
	_combat_effects.spawn_enemy_minions(origin, count, phase, forced_type)

func spawn_enemy_minion_mix(origin: Vector2, count: int, types: Array) -> void:
	_combat_effects.spawn_enemy_minion_mix(origin, count, types)

func apply_enemy_support_aura(origin: Vector2, radius: float, speed_mult: float, attack_mult: float, duration: float) -> void:
	_combat_effects.apply_enemy_support_aura(origin, radius, speed_mult, attack_mult, duration)

func spawn_champion_deflector_minions(origin: Vector2, count: int) -> Array:
	return _combat_effects.spawn_champion_deflector_minions(origin, count)

func spawn_hive_shield_minions(origin: Vector2, count: int) -> Array:
	return _combat_effects.spawn_hive_shield_minions(origin, count)

func spawn_pulsar_emp(origin: Vector2, lockout_seconds: float, color: Color) -> void:
	_combat_effects.spawn_pulsar_emp(origin, lockout_seconds, color)

func schedule_pulsar_emp(origin: Vector2, lockout_seconds: float, color: Color, delay: float) -> void:
	_combat_effects.schedule_pulsar_emp(origin, lockout_seconds, color, delay)

func _update_scheduled_pulsar_emps() -> void:
	_combat_effects.update_scheduled_pulsar_emps()

func spawn_enemy_burst(origin: Vector2, count: int, phase: float) -> void:
	_combat_effects.spawn_enemy_burst(origin, count, phase)

func handle_enemy_charge_windup(origin: Vector2) -> void:
	_combat_effects.handle_enemy_charge_windup(origin)

func spawn_enemy_attack_trail(origin: Vector2, direction: Vector2, color: Color, weight: float) -> void:
	_combat_effects.spawn_enemy_attack_trail(origin, direction, color, weight)

func handle_enemy_death_explosion(origin: Vector2, radius: float, damage: int) -> void:
	_combat_effects.handle_enemy_death_explosion(origin, radius, damage)

func get_active_players() -> Array:
	var active_players: Array = []
	for player in _player_nodes:
		if player != null and is_instance_valid(player) and player.is_alive():
			active_players.append(player)
	return active_players

func get_player_configs() -> Array:
	return _player_configs

func get_compiled_loadouts() -> Array:
	return _compiled_loadouts

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
	return _side_objectives.get_view() if _side_objectives != null else {}

func get_revive_progress_for_player_id(player_id: int) -> float:
	return float(_revive_progress_by_player_id.get(player_id, 0.0))

func get_revive_hold_duration() -> float:
	return REVIVE_HOLD_DURATION

func get_active_modifiers() -> Array:
	return _active_modifiers.duplicate()

func get_modifier_definitions() -> Dictionary:
	return _modifier_definitions

func get_momentum_tier(player_index: int) -> int:
	return _momentum_tracker.get_momentum_tier(player_index) if _momentum_tracker != null else 0

func get_radiance_deployable_count(player_index: int = -1) -> int:
	var total := 0
	for deployable_list in [_active_turrets, _active_orbits, _active_summons, _active_mines]:
		for deployable in deployable_list:
			if deployable == null or not is_instance_valid(deployable):
				continue
			if player_index >= 0 and deployable.has_method("get_owner_player_index") and int(deployable.get_owner_player_index()) != player_index:
				continue
			if player_index >= 0 and not deployable.has_method("get_owner_player_index"):
				continue
			total += 1
	return total

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

func get_arena_center() -> Vector2:
	return ARENA_CENTER

func get_player_target_nodes() -> Array:
	return _player_nodes

func get_player_index_for_node(node) -> int:
	if node != null and is_instance_valid(node) and "player_index" in node:
		return int(node.player_index)
	return _player_nodes.find(node)

func get_flow_direction_to_player(world_position: Vector2, target_player_index: int, fallback_dir: Vector2) -> Vector2:
	if _flow_field == null:
		return fallback_dir.normalized() if fallback_dir.length_squared() > 0.0001 else Vector2.ZERO
	return _flow_field.sample(world_position, target_player_index, fallback_dir)

func has_flow_obstacles() -> bool:
	return _flow_field != null and _flow_field.has_obstacles()

func get_safe_pickup_position(preferred_position: Vector2) -> Vector2:
	if _flow_field == null or not _flow_field.has_obstacles():
		return preferred_position
	return _flow_field.nearest_passable_position(preferred_position)

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

func lock_player_input(locked: bool) -> void:
	_lock_player_input(locked)

func _set_game_paused(paused: bool) -> void:
	if _pause_debug_ui != null:
		_pause_debug_ui.set_game_paused(paused)

func _set_runtime_pause_state(paused: bool) -> void:
	if _pause_debug_ui != null:
		_pause_debug_ui.set_runtime_pause_state(paused)

func get_runtime_pause_node_groups() -> Array:
	return [
		projectiles.get_children(),
		pickups.get_children(),
		effects.get_children(),
		arena_obstacles.get_children() if arena_obstacles != null else [],
		_enemy_nodes,
		_active_hazards,
		_active_mines,
		_active_turrets,
		_active_orbits,
		_active_summons,
	]

func get_runtime_pause_singletons() -> Array:
	return [_fire_floor_modifier, _ice_zone_modifier, _mine_field_modifier, _shrinking_arena_modifier]

func _sync_player_health_state(player) -> void:
	if player == null or not is_instance_valid(player):
		return
	var player_index := int(player.player_index)
	if player_index < 0 or player_index >= RunState.player_health_states.size():
		return
	RunState.player_health_states[player_index] = player.get_health_state()

func restart_current_room() -> void:
	_set_game_paused(false)
	_start_room()

func request_return_to_menu() -> void:
	_set_game_paused(false)
	return_to_menu_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if _awaiting_mutation_pick:
		return
	if _pause_debug_ui != null and _pause_debug_ui.handle_unhandled_input(event):
		get_viewport().set_input_as_handled()

func _ensure_debug_overlay_action() -> void:
	if _pause_debug_ui != null:
		_pause_debug_ui.ensure_debug_overlay_action()

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _invalidate_runtime_caches() -> void:
	pass
