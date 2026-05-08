extends Node2D

const PlayerConfigData = preload("res://scripts/player/PlayerConfig.gd")
const ModifierEngineData = preload("res://scripts/game/ModifierEngine.gd")
const PlayerInventoryData = preload("res://scripts/game/PlayerInventory.gd")
const PassiveTriggerSystemData = preload("res://scripts/game/PassiveTriggerSystem.gd")
const RecipeEngineData = preload("res://scripts/game/RecipeEngine.gd")
const ScreenShakeData = preload("res://scripts/juice/ScreenShake.gd")
const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")
const FloatingTextData = preload("res://scripts/juice/FloatingText.gd")
const HealthBarHUDData = preload("res://scripts/juice/HealthBarHUD.gd")
const PlayerInventoryHUDData = preload("res://scripts/ui/PlayerInventoryHUD.gd")
const HotFloorZoneData = preload("res://scripts/game/HotFloorZone.gd")
const DeathPuddleData = preload("res://scripts/game/DeathPuddle.gd")
const DARKNESS_OVERLAY_SHADER := """
shader_type canvas_item;

uniform vec2 player_1_pos = vec2(-9999.0, -9999.0);
uniform vec2 player_2_pos = vec2(-9999.0, -9999.0);
uniform vec2 player_3_pos = vec2(-9999.0, -9999.0);
uniform vec2 player_4_pos = vec2(-9999.0, -9999.0);
uniform float player_1_active = 0.0;
uniform float player_2_active = 0.0;
uniform float player_3_active = 0.0;
uniform float player_4_active = 0.0;
uniform float vision_radius = 280.0;
uniform vec4 darkness_color : source_color = vec4(0.01, 0.02, 0.03, 0.84);

float reveal_amount(vec2 frag, vec2 center, float active, float radius) {
	if (active < 0.5) {
		return 0.0;
	}
	float edge_start = radius * 0.72;
	float dist = distance(frag, center);
	return 1.0 - smoothstep(edge_start, radius, dist);
}

void fragment() {
	vec2 frag = SCREEN_UV / SCREEN_PIXEL_SIZE;
	float reveal = 0.0;
	reveal = max(reveal, reveal_amount(frag, player_1_pos, player_1_active, vision_radius));
	reveal = max(reveal, reveal_amount(frag, player_2_pos, player_2_active, vision_radius));
	reveal = max(reveal, reveal_amount(frag, player_3_pos, player_3_active, vision_radius));
	reveal = max(reveal, reveal_amount(frag, player_4_pos, player_4_active, vision_radius));
	float alpha = darkness_color.a * (1.0 - reveal);
	COLOR = vec4(darkness_color.rgb, alpha);
}
"""
const UNIFORM_ARENA_FLOOR_COLOR := Color(0.28, 0.30, 0.25, 1.0)
const UNIFORM_ARENA_ACCENT_COLOR := Color(0.44, 0.46, 0.48, 0.16)
const ARENA_CENTER := Vector2(960.0, 540.0)
const CENTER_OBSTACLE_EXCLUSION_RADIUS := 140.0
const GENERATOR_CLEARANCE_RADIUS := 74.0
const LAYOUT_PALETTES := {
	"default": {
		"floor_color": UNIFORM_ARENA_FLOOR_COLOR,
		"wall_color": UNIFORM_ARENA_FLOOR_COLOR,
		"side_wall_color": UNIFORM_ARENA_FLOOR_COLOR,
		"grid_color": Color(0.28, 0.3, 0.32, 0.26),
		"accent_color": UNIFORM_ARENA_ACCENT_COLOR,
	},
	"crossfire": {
		"floor_color": UNIFORM_ARENA_FLOOR_COLOR,
		"wall_color": UNIFORM_ARENA_FLOOR_COLOR,
		"side_wall_color": UNIFORM_ARENA_FLOOR_COLOR,
		"grid_color": Color(0.3, 0.29, 0.28, 0.26),
		"accent_color": UNIFORM_ARENA_ACCENT_COLOR,
	},
	"pinch": {
		"floor_color": UNIFORM_ARENA_FLOOR_COLOR,
		"wall_color": UNIFORM_ARENA_FLOOR_COLOR,
		"side_wall_color": UNIFORM_ARENA_FLOOR_COLOR,
		"grid_color": Color(0.27, 0.31, 0.32, 0.26),
		"accent_color": UNIFORM_ARENA_ACCENT_COLOR,
	},
	"offset": {
		"floor_color": UNIFORM_ARENA_FLOOR_COLOR,
		"wall_color": UNIFORM_ARENA_FLOOR_COLOR,
		"side_wall_color": UNIFORM_ARENA_FLOOR_COLOR,
		"grid_color": Color(0.31, 0.3, 0.28, 0.26),
		"accent_color": UNIFORM_ARENA_ACCENT_COLOR,
	},
	"gauntlet_pockets": {
		"floor_color": UNIFORM_ARENA_FLOOR_COLOR,
		"wall_color": UNIFORM_ARENA_FLOOR_COLOR,
		"side_wall_color": UNIFORM_ARENA_FLOOR_COLOR,
		"grid_color": Color(0.3, 0.31, 0.27, 0.26),
		"accent_color": UNIFORM_ARENA_ACCENT_COLOR,
	},
	"boss_gate": {
		"floor_color": UNIFORM_ARENA_FLOOR_COLOR,
		"wall_color": UNIFORM_ARENA_FLOOR_COLOR,
		"side_wall_color": UNIFORM_ARENA_FLOOR_COLOR,
		"grid_color": Color(0.31, 0.28, 0.29, 0.26),
		"accent_color": UNIFORM_ARENA_ACCENT_COLOR,
	},
	"lane": {
		"floor_color": UNIFORM_ARENA_FLOOR_COLOR,
		"wall_color": UNIFORM_ARENA_FLOOR_COLOR,
		"side_wall_color": UNIFORM_ARENA_FLOOR_COLOR,
		"grid_color": Color(0.25, 0.31, 0.34, 0.28),
		"accent_color": Color(0.48, 0.62, 0.66, 0.18),
	},
}
@export var player_scene: PackedScene
@export var enemy_scene: PackedScene
@export var projectile_scene: PackedScene
@export var grenade_projectile_scene: PackedScene
@export var mine_projectile_scene: PackedScene
@export var generator_scene: PackedScene
@export var pickup_scene: PackedScene
@export var loot_drop_scene: PackedScene
@export var loot_vote_ui_scene: PackedScene
@export var weapon_replace_ui_scene: PackedScene
@export var shop_station_scene: PackedScene
@export var shop_ui_scene: PackedScene
@export var survival_duration: float = 30.0
@export var enemy_spawn_interval: float = 4.0
@export var modifier_intro_duration: float = 1.8
@export var revive_radius: float = 92.0
@export var revive_hold_duration: float = 1.4
@export var revive_health: int = 20
@export var boss_support_spawn_interval: float = 8.0
@export var exit_hold_duration: float = 1.0
@export var exit_auto_transition_delay: float = 15.0

signal room_cleared(health_states, clear_context)
signal all_players_dead
signal player_downed(player)
signal player_revived(player)

@onready var players: Node2D = $Players
@onready var projectiles: Node2D = $Projectiles
@onready var enemies: Node2D = $Enemies
@onready var generators: Node2D = $Generators
@onready var pickups: Node2D = $Pickups
@onready var effects: Node2D = $Effects
@onready var exit_zone: Area2D = $ExitZone
@onready var exit_zone_shape: CollisionShape2D = $ExitZone/CollisionShape2D
@onready var exit_zone_visual: Polygon2D = $ExitZone/Visual
@onready var floor_visual: Polygon2D = $Floor
@onready var floor_grid: Node2D = $FloorGrid
@onready var back_wall_visual: Polygon2D = $BackWall
@onready var left_wall_visual: Polygon2D = $LeftWallVisual
@onready var right_wall_visual: Polygon2D = $RightWallVisual
@onready var camera: Camera2D = $Camera2D
@onready var screen_shake: ScreenShakeData = $Camera2D/ScreenShake
@onready var screen_effects = $ScreenEffects
@onready var top_wall: CollisionShape2D = $ArenaBounds/TopWall
@onready var bottom_wall: CollisionShape2D = $ArenaBounds/BottomWall
@onready var left_wall: CollisionShape2D = $ArenaBounds/LeftWall
@onready var right_wall: CollisionShape2D = $ArenaBounds/RightWall
@onready var player_1_spawn: Marker2D = $Player1Spawn
@onready var player_2_spawn: Marker2D = $Player2Spawn
@onready var player_3_spawn: Marker2D = $Player3Spawn
@onready var player_4_spawn: Marker2D = $Player4Spawn
@onready var enemy_spawn_1: Marker2D = $EnemySpawn1
@onready var enemy_spawn_2: Marker2D = $EnemySpawn2
@onready var enemy_spawn_3: Marker2D = $EnemySpawn3
@onready var enemy_spawn_4: Marker2D = $EnemySpawn4
@onready var enemy_spawn_5: Marker2D = $EnemySpawn5
@onready var enemy_spawn_6: Marker2D = $EnemySpawn6
@onready var ui_layer: CanvasLayer = $UI
@onready var title_label: Label = $UI/Title
@onready var p1_status_label: Label = $UI/P1Status
@onready var p2_status_label: Label = $UI/P2Status
@onready var p3_status_label: Label = $UI/P3Status
@onready var p4_status_label: Label = $UI/P4Status
@onready var p1_secondary_label: Label = $UI/P1SecondaryStatus
@onready var p2_secondary_label: Label = $UI/P2SecondaryStatus
@onready var p3_secondary_label: Label = $UI/P3SecondaryStatus
@onready var p4_secondary_label: Label = $UI/P4SecondaryStatus
@onready var p1_mode_button: Button = $UI/P1ModeButton
@onready var p2_mode_button: Button = $UI/P2ModeButton
@onready var room_status_label: Label = $UI/RoomStatus
@onready var modifier_status_label: Label = $UI/ModifierStatus
@onready var connection_status_label: Label = $UI/ConnectionStatus
@onready var result_panel: Panel = $UI/ResultPanel
@onready var result_title_label: Label = $UI/ResultPanel/MarginContainer/ResultLayout/ResultTitle
@onready var result_detail_label: Label = $UI/ResultPanel/MarginContainer/ResultLayout/ResultDetail
@onready var retry_button: Button = $UI/ResultPanel/MarginContainer/ResultLayout/RetryButton
@onready var modifier_tint: CanvasModulate = $ModifierTint
@onready var modifier_intro_panel: Panel = $UI/ModifierIntroPanel
@onready var modifier_intro_title_label: Label = $UI/ModifierIntroPanel/MarginContainer/IntroLayout/ModifierTitle
@onready var modifier_intro_detail_label: Label = $UI/ModifierIntroPanel/MarginContainer/IntroLayout/ModifierDetail
@onready var pause_panel: Panel = $UI/PausePanel
@onready var resume_button: Button = $UI/PausePanel/MarginContainer/PauseLayout/ResumeButton
@onready var pause_settings_button: Button = $UI/PausePanel/MarginContainer/PauseLayout/PauseSettingsButton
@onready var pause_retry_button: Button = $UI/PausePanel/MarginContainer/PauseLayout/PauseRetryButton
@onready var settings_panel: Panel = $UI/SettingsPanel
@onready var settings_screen_effect_row: HBoxContainer = $UI/SettingsPanel/MarginContainer/SettingsLayout/ScreenEffectsRow
@onready var settings_screen_effect_option: OptionButton = $UI/SettingsPanel/MarginContainer/SettingsLayout/ScreenEffectsRow/ScreenEffectsOption
@onready var settings_player_1_row: HBoxContainer = $UI/SettingsPanel/MarginContainer/SettingsLayout/Player1AimRow
@onready var settings_player_1_option: OptionButton = $UI/SettingsPanel/MarginContainer/SettingsLayout/Player1AimRow/Player1AimOption
@onready var settings_player_2_row: HBoxContainer = $UI/SettingsPanel/MarginContainer/SettingsLayout/Player2AimRow
@onready var settings_player_2_option: OptionButton = $UI/SettingsPanel/MarginContainer/SettingsLayout/Player2AimRow/Player2AimOption
@onready var settings_player_3_row: HBoxContainer = $UI/SettingsPanel/MarginContainer/SettingsLayout/Player3AimRow
@onready var settings_player_3_option: OptionButton = $UI/SettingsPanel/MarginContainer/SettingsLayout/Player3AimRow/Player3AimOption
@onready var settings_player_4_row: HBoxContainer = $UI/SettingsPanel/MarginContainer/SettingsLayout/Player4AimRow
@onready var settings_player_4_option: OptionButton = $UI/SettingsPanel/MarginContainer/SettingsLayout/Player4AimRow/Player4AimOption
@onready var settings_back_button: Button = $UI/SettingsPanel/MarginContainer/SettingsLayout/SettingsBackButton

var _player_nodes: Array = []
var _player_configs: Array = [
	PlayerConfigData.new(1, "gamepad", Color(0.15, 0.92, 0.25, 1.0), PlayerConfigData.AimMode.HEAVY_AUTO),
	PlayerConfigData.new(2, "keyboard", Color(0.18, 0.42, 1.0, 1.0), PlayerConfigData.AimMode.FULL_AUTO),
	PlayerConfigData.new(3, "keyboard", Color(1.0, 0.88, 0.12, 1.0), PlayerConfigData.AimMode.FULL_AUTO),
	PlayerConfigData.new(4, "keyboard", Color(1.0, 0.5, 0.12, 1.0), PlayerConfigData.AimMode.FULL_AUTO),
]
var _is_initialized := false
var _room_is_cleared := false
var _room_is_failed := false
var _room_is_in_intro := false
var _room_started_at := 0.0
var _next_enemy_spawn_at := 0.0
var _next_boss_support_spawn_at := 0.0
var _survival_wave_index := 0
var _room_intro_ends_at := 0.0
var _stationary_damage_next_tick_at := 0.0
var _active_modifier: Dictionary = {}
var _modifier_engine = null
var _recipe_engine = null
var _passive_trigger_system = null
var _room_config: Dictionary = {}
var _boss_node = null
var _revive_progress_by_player_id: Dictionary = {}
var _hitstop_serial: int = 0
var _sfx_engine = null
var _hud_root: Control = null
var _floating_text_layer: Control = null
var _player_inventory_huds: Array = []
var _boss_health_bar = null
var _gold_panel: Panel = null
var _gold_label: Label = null
var _modifier_chip_panel: Panel = null
var _modifier_chip_label: Label = null
var _timer_panel: Panel = null
var _timer_fill: ColorRect = null
var _timer_label: Label = null
var _encounter_status_label: Label = null
var _darkness_overlay: ColorRect = null
var _darkness_material: ShaderMaterial = null
var _survival_spawn_warning_pending := false
var _boss_support_warning_pending := false
var _pending_survival_wave_plan: Array = []
var _pending_boss_support_plan: Array = []
var _pending_warning_effects: Array = []
var _friendly_fire_enabled := false
var _vision_radius := 0.0
var _wave_random := RandomNumberGenerator.new()
var _settings_rows: Array = []
var _settings_options: Array = []
var _generator_nodes: Array = []
var _generator_slot_positions: Array = []
var _generator_total_count: int = 0
var _obstacle_nodes: Array = []
var _hot_floor_zones: Array = []
var _death_puddles: Array = []
var _next_hot_floor_batch_at: float = 0.0
var _room_random := RandomNumberGenerator.new()
var _active_loot_drop = null
var _loot_vote_ui: Control = null
var _pending_loot_item: Dictionary = {}
var _loot_vote_active: bool = false
var _loot_vote_deadline: float = 0.0
var _loot_vote_duration: float = 10.0
var _loot_votes: Dictionary = {}
var _loot_vote_take_pressed: Dictionary = {}
var _loot_vote_scrap_pressed: Dictionary = {}
var _loot_interact_pressed: Dictionary = {}
var _pending_health_states_after_loot: Array = []
var _weapon_replace_ui: Control = null
var _weapon_replace_active: bool = false
var _pending_weapon_replace_request: Dictionary = {}
var _pending_weapon_replace_result: Dictionary = {}
var _weapon_replace_selected_slot: int = 0
var _weapon_replace_left_pressed: bool = false
var _weapon_replace_right_pressed: bool = false
var _weapon_replace_confirm_pressed: bool = false
var _weapon_replace_cancel_pressed: bool = false
var _shop_station = null
var _shop_ui: Control = null
var _shop_room_ready_players: Dictionary = {}
var _shop_ready_deadline: float = 0.0
var _shop_active_player_index: int = -1
var _shop_selection_index: int = 0
var _shop_nav_left_pressed: bool = false
var _shop_nav_right_pressed: bool = false
var _shop_confirm_pressed: bool = false
var _shop_cancel_pressed: bool = false
var _shop_interact_pressed: Dictionary = {}
var _shop_status_message: String = ""
var _shop_room_log: Array = []
var _exit_zone_open: bool = false
var _exit_zone_auto_exit_at: float = 0.0
var _exit_zone_hold_started_at: float = -1.0
var _pending_room_clear_health_states: Array = []
var _pending_room_clear_context: Dictionary = {}
var _pending_room_clear_title: String = ""
var _pending_room_clear_detail: String = ""

func _ready() -> void:
	if player_scene == null:
		player_scene = load("res://scenes/player/Player.tscn")
	if enemy_scene == null:
		enemy_scene = load("res://scenes/enemies/Enemy.tscn")
	if projectile_scene == null:
		projectile_scene = load("res://scenes/weapons/Projectile.tscn")
	if grenade_projectile_scene == null:
		grenade_projectile_scene = load("res://scenes/weapons/GrenadeProjectile.tscn")
	if mine_projectile_scene == null:
		mine_projectile_scene = load("res://scenes/weapons/MineProjectile.tscn")
	if generator_scene == null:
		generator_scene = load("res://scenes/game/GeneratorObjective.tscn")
	if pickup_scene == null:
		pickup_scene = load("res://scenes/game/RoomPickup.tscn")
	if loot_drop_scene == null:
		loot_drop_scene = load("res://scenes/game/LootDrop.tscn")
	if loot_vote_ui_scene == null:
		loot_vote_ui_scene = load("res://scenes/ui/LootVoteUI.tscn")
	if weapon_replace_ui_scene == null:
		weapon_replace_ui_scene = load("res://scenes/ui/WeaponReplaceUI.tscn")
	if shop_station_scene == null:
		shop_station_scene = load("res://scenes/game/ShopStation.tscn")
	if shop_ui_scene == null:
		shop_ui_scene = load("res://scenes/ui/ShopUI.tscn")
	_modifier_engine = ModifierEngineData.new()
	_recipe_engine = RecipeEngineData.new()
	_passive_trigger_system = PassiveTriggerSystemData.new()
	_wave_random.randomize()
	_room_random.randomize()
	_sfx_engine = get_tree().get_first_node_in_group("sfx_engine")
	_settings_rows = [
		settings_player_1_row,
		settings_player_2_row,
		settings_player_3_row,
		settings_player_4_row,
	]
	_settings_options = [
		settings_player_1_option,
		settings_player_2_option,
		settings_player_3_option,
		settings_player_4_option,
	]
	_populate_screen_effect_option(settings_screen_effect_option, ProfileState.get_screen_effect_level())
	for index in range(_settings_options.size()):
		var aim_mode_value: int = PlayerConfigData.AimMode.FULL_AUTO
		if index < _player_configs.size():
			aim_mode_value = int(_player_configs[index].aim_mode)
		_populate_aim_mode_option(_settings_options[index], aim_mode_value)
	settings_screen_effect_option.item_selected.connect(_on_pause_screen_effect_selected)
	_build_hud()
	_apply_screen_effect_setting()
	_is_initialized = true
	_spawn_players()
	_start_room()
	p1_mode_button.pressed.connect(_on_p1_mode_button_pressed)
	p2_mode_button.pressed.connect(_on_p2_mode_button_pressed)
	retry_button.pressed.connect(_on_retry_button_pressed)
	resume_button.pressed.connect(_on_resume_button_pressed)
	pause_settings_button.pressed.connect(_on_pause_settings_button_pressed)
	pause_retry_button.pressed.connect(_on_pause_retry_button_pressed)
	for index in range(_settings_options.size()):
		_settings_options[index].item_selected.connect(_on_pause_aim_mode_selected.bind(index))
	settings_back_button.pressed.connect(_on_pause_settings_back_button_pressed)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_configure_menu_focus()
	_refresh_debug_ui()

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_refresh_debug_ui()
	_update_room_progress(delta)
	_update_screen_effects()
	_update_loot_resolution()
	_update_exit_zone(delta)

func _input(event: InputEvent) -> void:
	if get_tree().paused and event.is_action_pressed("ui_cancel") and not event.is_echo():
		if settings_panel.visible:
			_close_pause_settings()
		else:
			_set_paused(false)
		get_viewport().set_input_as_handled()
		return
	if _room_is_cleared or _room_is_failed:
		return
	if event.is_echo():
		return
	if _is_pause_event(event):
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _spawn_players() -> void:
	_clear_container(players)
	_player_nodes.clear()
	if _passive_trigger_system != null:
		_passive_trigger_system.clear_state()

	var spawn_points := [
		player_1_spawn.global_position,
		player_2_spawn.global_position,
		player_3_spawn.global_position,
		player_4_spawn.global_position,
	]
	var assigned_gamepads := _assign_gamepads(_player_configs)
	var player_slot_count := mini(_player_configs.size(), mini(spawn_points.size(), assigned_gamepads.size()))

	for index in range(player_slot_count):
		var player = player_scene.instantiate()
		player.global_position = spawn_points[index]
		player.setup(_player_configs[index], assigned_gamepads[index])
		player.player_index = index
		player.apply_loadout(RunState.get_player_runtime_loadout_for(index))
		player.name = "Player%d" % (index + 1)
		player.fire_requested.connect(_on_player_fire_requested)
		player.secondary_requested.connect(_on_player_secondary_requested)
		player.health_changed.connect(_on_player_health_changed)
		player.damage_taken.connect(_on_player_damage_taken)
		player.downed.connect(_on_player_downed)
		player.revived.connect(_on_player_revived)
		player.muzzle_flash_requested.connect(_on_player_muzzle_flash_requested)
		player.dash_trail_requested.connect(_on_player_dash_trail_requested)
		player.dash_started.connect(_on_player_dash_started)
		player.set_input_locked(false)
		players.add_child(player)
		_play_player_spawn_in(player)
		_player_nodes.append(player)
	_refresh_player_inventory_huds()
	_refresh_pause_settings_panel()

func _reapply_player_loadout(player_index: int) -> void:
	if player_index < 0 or player_index >= _player_nodes.size():
		return
	var player = _player_nodes[player_index]
	if player == null or not is_instance_valid(player):
		return
	player.apply_loadout(RunState.get_player_runtime_loadout_for(player_index))

func _reapply_all_player_loadouts() -> void:
	for index in range(_player_nodes.size()):
		_reapply_player_loadout(index)

func _refresh_debug_ui() -> void:
	p1_mode_button.visible = false
	p2_mode_button.visible = false

	var connected_devices: Array = Input.get_connected_joypads()
	if connected_devices.is_empty():
		connection_status_label.text = "Gamepads: none connected. Keyboard fallback active for P1 and P2."
	else:
		connection_status_label.text = "Gamepads: %s" % connected_devices
	modifier_status_label.text = _build_modifier_status_text()
	_refresh_modifier_chip()
	_refresh_gold_panel()
	_refresh_player_inventory_huds()
	_refresh_boss_health_bar()
	_refresh_pause_settings_panel()

func _build_modifier_status_text() -> String:
	var recipe_suffix: String = _get_recipe_debug_suffix()
	if _is_boss_room():
		return "Boss Room: %s%s" % [str(_room_config.get("title", "Boss")), recipe_suffix]
	if _is_shop_room():
		return "Shop Room: Personal offers and ready-up.%s" % recipe_suffix
	if _active_modifier.is_empty():
		return "Modifier: None%s" % recipe_suffix
	return "Modifier: %s | %s" % [
		str(_active_modifier.get("name", "Unknown")),
		"%s%s" % [str(_active_modifier.get("description", "")), recipe_suffix],
	]

func configure_players(player_configs: Array) -> void:
	_player_configs = []
	for config in player_configs:
		_player_configs.append(config)

	if _is_initialized:
		_spawn_players()
		_start_room()
		_refresh_debug_ui()

func configure_room(room_config: Dictionary) -> void:
	_room_config = room_config.duplicate(true)
	if _is_initialized:
		_start_room()
		_refresh_debug_ui()

func _assign_gamepads(player_configs: Array) -> Array:
	var connected_devices: Array = Input.get_connected_joypads()
	var assigned_devices: Array = []
	var next_device_index := 0

	for config in player_configs:
		var device_id := -1
		if config.uses_gamepad() and next_device_index < connected_devices.size():
			device_id = connected_devices[next_device_index]
			next_device_index += 1
		assigned_devices.append(device_id)

	return assigned_devices

func _on_p1_mode_button_pressed() -> void:
	_cycle_player_mode(0)

func _on_p2_mode_button_pressed() -> void:
	_cycle_player_mode(1)

func _cycle_player_mode(player_index: int) -> void:
	if player_index < 0 or player_index >= _player_nodes.size():
		return
	_player_nodes[player_index].cycle_aim_mode()
	if player_index < _player_configs.size():
		_player_configs[player_index].aim_mode = _player_nodes[player_index].player_config.aim_mode
	if player_index < RunState.player_configs.size():
		RunState.player_configs[player_index].aim_mode = _player_nodes[player_index].player_config.aim_mode
	_refresh_debug_ui()

func _populate_aim_mode_option(option_button: OptionButton, selected_aim_mode: int) -> void:
	option_button.clear()
	var entries := [
		{"label": "Heavy Auto", "value": PlayerConfigData.AimMode.HEAVY_AUTO},
		{"label": "Full Auto", "value": PlayerConfigData.AimMode.FULL_AUTO},
		{"label": "Manual", "value": PlayerConfigData.AimMode.MANUAL},
	]
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		option_button.add_item(str(entry.get("label", "Aim")))
		option_button.set_item_metadata(index, int(entry.get("value", PlayerConfigData.AimMode.HEAVY_AUTO)))
	_select_option_by_metadata(option_button, selected_aim_mode)

func _populate_screen_effect_option(option_button: OptionButton, selected_level: String) -> void:
	option_button.clear()
	var entries := [
		{"label": "Off", "value": "off"},
		{"label": "Minimal", "value": "minimal"},
		{"label": "Full", "value": "full"},
	]
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		option_button.add_item(str(entry.get("label", "Effects")))
		option_button.set_item_metadata(index, str(entry.get("value", "off")))
	_select_string_option_by_metadata(option_button, selected_level)

func _select_option_by_metadata(option_button: OptionButton, target_value: int) -> void:
	for index in range(option_button.item_count):
		if option_button.get_item_metadata(index) == target_value:
			option_button.select(index)
			return
	if option_button.item_count > 0:
		option_button.select(0)

func _select_string_option_by_metadata(option_button: OptionButton, target_value: String) -> void:
	for index in range(option_button.item_count):
		if str(option_button.get_item_metadata(index)) == target_value:
			option_button.select(index)
			return
	if option_button.item_count > 0:
		option_button.select(0)

func _refresh_pause_settings_panel() -> void:
	settings_screen_effect_row.visible = true
	_select_string_option_by_metadata(settings_screen_effect_option, ProfileState.get_screen_effect_level())
	var settings_slot_count := mini(_settings_rows.size(), _settings_options.size())
	for index in range(settings_slot_count):
		var has_player := index < _player_configs.size()
		_settings_rows[index].visible = has_player
		if has_player:
			_select_option_by_metadata(_settings_options[index], int(_player_configs[index].aim_mode))

func _focus_pause_settings_panel() -> void:
	if settings_screen_effect_row.visible:
		settings_screen_effect_option.grab_focus()
		return
	var settings_slot_count := mini(_settings_rows.size(), _settings_options.size())
	for index in range(settings_slot_count):
		if _settings_rows[index].visible:
			_settings_options[index].grab_focus()
			return
	settings_back_button.grab_focus()

func _apply_player_aim_mode(player_index: int, aim_mode_value: int) -> void:
	if player_index < 0 or player_index >= _player_configs.size():
		return
	var resolved_aim_mode: int = clampi(
		aim_mode_value,
		PlayerConfigData.AimMode.HEAVY_AUTO,
		PlayerConfigData.AimMode.MANUAL
	)
	_player_configs[player_index].aim_mode = resolved_aim_mode
	if player_index < RunState.player_configs.size():
		RunState.player_configs[player_index].aim_mode = resolved_aim_mode
	if player_index < _player_nodes.size() and is_instance_valid(_player_nodes[player_index]):
		_player_nodes[player_index].set_aim_mode(resolved_aim_mode)
	_refresh_debug_ui()

func _open_pause_settings() -> void:
	_refresh_pause_settings_panel()
	pause_panel.visible = false
	settings_panel.visible = true
	_apply_panel_style(settings_panel, _get_active_hud_accent())
	call_deferred("_focus_pause_settings_panel")

func _close_pause_settings() -> void:
	settings_panel.visible = false
	if get_tree().paused:
		pause_panel.visible = true
		resume_button.grab_focus()

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_debug_ui()

func get_active_players() -> Array:
	var active_players: Array = []
	for player in _player_nodes:
		if is_instance_valid(player) and player.is_alive():
			active_players.append(player)
	return active_players

func get_downed_players() -> Array:
	var downed_players: Array = []
	for player in _player_nodes:
		if is_instance_valid(player) and player.is_downed():
			downed_players.append(player)
	return downed_players

func capture_player_health_states() -> Array:
	var states: Array = []
	for player in _player_nodes:
		if is_instance_valid(player):
			var state: Dictionary = player.get_health_state()
			if player.is_downed():
				state["current"] = 1
			states.append(state)
	return states

func _start_room() -> void:
	_room_is_cleared = false
	_room_is_failed = false
	_room_is_in_intro = true
	_reset_loot_resolution_state()
	_reset_shop_room_state()
	_set_exit_zone_visible(false)
	_pending_room_clear_health_states = []
	_pending_room_clear_context = {}
	_pending_room_clear_title = ""
	_pending_room_clear_detail = ""
	var now := _current_time_seconds()
	_room_started_at = now + modifier_intro_duration
	_room_intro_ends_at = _room_started_at
	_next_enemy_spawn_at = _room_started_at + _get_spawn_interval()
	_next_boss_support_spawn_at = _room_started_at + boss_support_spawn_interval
	_stationary_damage_next_tick_at = now
	_survival_wave_index = 0
	_revive_progress_by_player_id = {}
	_survival_spawn_warning_pending = false
	_boss_support_warning_pending = false
	_pending_survival_wave_plan = []
	_pending_boss_support_plan = []
	_boss_node = null
	_generator_nodes = []
	_generator_slot_positions = []
	_generator_total_count = 0
	_clear_modifier_hazards()
	_clear_obstacles()
	_active_modifier = {} if _is_boss_room() else _room_config.get("modifier", _modifier_engine.get_random_modifier(int(_room_config.get("step_index", 0)))).duplicate(true)
	_friendly_fire_enabled = _modifier_engine.is_friendly_fire(_active_modifier)
	_vision_radius = _modifier_engine.get_vision_radius(_active_modifier)
	_next_hot_floor_batch_at = _room_started_at + _modifier_engine.get_hot_floor_zone_interval(_active_modifier)
	_clear_container(projectiles)
	_clear_container(enemies)
	_clear_container(generators)
	_clear_container(pickups)
	_clear_container(effects)
	_clear_spawn_warning_effects()
	if screen_shake != null:
		screen_shake.clear()
	_reset_room_status_pulse()
	result_panel.visible = false
	_apply_layout_preset(str(_room_config.get("layout_id", "default")))
	_restore_player_health_states()
	_apply_modifier_visuals()
	_show_room_intro()
	_play_intro_juice()
	room_status_label.text = "Room status: Incoming encounter"
	if _is_generator_room():
		_set_room_progress_ui("Deploying", "Break the generators.", 1.0, _get_active_hud_accent())
	else:
		_set_room_progress_ui("Deploying", "Hold the arena.", 1.0, _get_active_hud_accent())

func _spawn_room_opening_encounter() -> void:
	if _is_boss_room():
		_spawn_boss()
	elif _is_generator_room():
		_spawn_generators()
	elif _is_shop_room():
		_start_shop_room()
	else:
		_spawn_survival_wave(_build_survival_wave_plan())

func _build_survival_wave_plan() -> Array:
	var spawn_points := _get_enemy_spawn_positions()
	var step_index := int(_room_config.get("step_index", 0))
	var is_elite := str(_room_config.get("room_type", "")) == "elite"
	var spawn_count := _compute_wave_size(step_index, is_elite, spawn_points.size())
	var weight_hint_name: String = str(_room_config.get("enemy_weight_hint", "default"))
	var weight_override: Array = _recipe_engine.get_weight_hint(weight_hint_name) if _recipe_engine != null else []
	var enemy_types := _roll_wave_composition(step_index, is_elite, max(spawn_count, 1), weight_override)
	var assigned_positions: Array = _build_wave_spawn_positions(spawn_points, spawn_count, enemy_types)
	var plan: Array = []

	for index in range(spawn_count):
		plan.append({
			"position": assigned_positions[index],
			"type": enemy_types[index],
			"apply_modifier": true,
		})
	return plan

func _spawn_survival_wave(plan: Array) -> void:
	_spawn_enemy_wave(plan)
	_survival_wave_index += 1

func _spawn_boss() -> void:
	var boss = enemy_scene.instantiate()
	boss.global_position = Vector2(640, 210)
	boss.setup("boss", self)
	boss.apply_boss_scale(_player_nodes.size())
	var rooms_bonus: int = max(RunState.rooms_completed - 2, 0)
	boss.max_health += rooms_bonus * 30
	boss.current_health = boss.max_health
	boss.enemy_died.connect(_on_enemy_died)
	boss.hit_received.connect(_on_enemy_hit_received)
	boss.fire_requested.connect(_on_enemy_fire_requested)
	enemies.add_child(boss)
	_boss_node = boss

func _roll_wave_composition(step_index: int, is_elite: bool, composition_size: int, weight_override: Array = []) -> Array:
	var weights: Array = [6, 1, 0, 0]
	if not weight_override.is_empty() and weight_override.size() >= 4:
		weights = weight_override.duplicate()
	elif step_index >= 4:
		weights = [1, 1, 3, 3]
	elif step_index >= 2:
		weights = [3, 1, 2, 2]

	if is_elite:
		weights[0] = max(weights[0] - 1, 0)
		weights[2] += 1
		weights[3] += 1

	var weighted_pool: Array = []
	for _index in range(weights[0]):
		weighted_pool.append("chaser")
	for _index in range(weights[1]):
		weighted_pool.append("spitter")
	for _index in range(weights[2]):
		weighted_pool.append("charger")
	for _index in range(weights[3]):
		weighted_pool.append("bruiser")
	if weighted_pool.is_empty():
		weighted_pool.append("chaser")

	var composition: Array = []
	while composition.size() < composition_size:
		composition.append(weighted_pool[_wave_random.randi_range(0, weighted_pool.size() - 1)])
	composition.shuffle()
	return composition

func _compute_wave_size(step_index: int, is_elite: bool, max_spawn_points: int) -> int:
	var wave_size_bonus: int = int(_room_config.get("wave_size_bonus", 0)) + _modifier_engine.get_wave_size_bonus(_active_modifier)
	var base_size: int = 4 + max(step_index - 1, 0) + (1 if is_elite else 0) + max(_player_nodes.size() - 1, 0) + wave_size_bonus
	var max_wave_size: int = max_spawn_points + max(_modifier_engine.get_wave_size_bonus(_active_modifier), 0)
	return clampi(base_size, 4, max(max_wave_size, 4))

func _build_wave_spawn_positions(spawn_points: Array, spawn_count: int, enemy_types: Array) -> Array:
	var ordered_positions: Array = []
	for index in range(spawn_count):
		var spawn_index: int = (_survival_wave_index * spawn_count + index) % spawn_points.size()
		ordered_positions.append(spawn_points[spawn_index])
	var spawn_position_bias: String = _modifier_engine.get_spawn_position_bias(_active_modifier)
	if spawn_position_bias != "sides":
		return ordered_positions
	var side_priority: Array = ordered_positions.duplicate()
	side_priority.sort_custom(func(a: Vector2, b: Vector2) -> bool: return abs(a.x - ARENA_CENTER.x) > abs(b.x - ARENA_CENTER.x))
	var used_positions: Array = []
	var assigned_positions: Array = []
	assigned_positions.resize(spawn_count)
	for index in range(enemy_types.size()):
		if str(enemy_types[index]) != "spitter":
			continue
		var side_position: Vector2 = _take_next_unused_spawn_position(side_priority, used_positions)
		assigned_positions[index] = side_position
		used_positions.append(side_position)
	for index in range(enemy_types.size()):
		if assigned_positions[index] is Vector2:
			continue
		var default_position: Vector2 = _take_next_unused_spawn_position(ordered_positions, used_positions)
		assigned_positions[index] = default_position
		used_positions.append(default_position)
	return assigned_positions

func _take_next_unused_spawn_position(pool: Array, used_positions: Array) -> Vector2:
	for position_variant in pool:
		var position: Vector2 = position_variant
		if not used_positions.has(position):
			return position
	return pool[0] if not pool.is_empty() else ARENA_CENTER

func _get_recipe_debug_suffix() -> String:
	if not bool(RunState.debug_run_setup.get("enabled", false)):
		return ""
	var recipe_id: String = str(_room_config.get("recipe_id", "")).strip_edges()
	if recipe_id.is_empty():
		return ""
	return " | Recipe: %s" % recipe_id

func _build_boss_support_wave_plan() -> Array:
	var spawn_points := _get_enemy_spawn_positions()
	var support_count := 2 if _player_nodes.size() <= 2 else 3
	var support_types := ["chaser", "charger", "bruiser"]
	var plan: Array = []
	for index in range(support_count):
		var enemy_type: String = str(support_types[(_survival_wave_index + index) % support_types.size()])
		var spawn_index := (_survival_wave_index + index) % spawn_points.size()
		plan.append({
			"position": spawn_points[spawn_index],
			"type": enemy_type,
			"apply_modifier": false,
		})
	return plan

func _spawn_boss_support_wave(plan: Array) -> void:
	var support_count := plan.size()
	_spawn_enemy_wave(plan)
	_survival_wave_index += support_count

func _spawn_enemy_wave(plan: Array) -> void:
	for entry in plan:
		if not (entry is Dictionary):
			continue
		var enemy = enemy_scene.instantiate()
		enemy.global_position = entry.get("position", Vector2.ZERO)
		enemy.setup(str(entry.get("type", "chaser")), self)
		if bool(entry.get("apply_modifier", false)):
			enemy.apply_room_modifier(
				_modifier_engine.get_enemy_bonus_health(_active_modifier),
				_modifier_engine.get_enemy_speed_multiplier(_active_modifier),
				_modifier_engine.get_enemy_fire_interval_multiplier(_active_modifier),
				0.0,
				0,
				_modifier_engine.get_enemy_contact_damage_bonus(_active_modifier)
			)
		enemy.enemy_died.connect(_on_enemy_died)
		enemy.hit_received.connect(_on_enemy_hit_received)
		enemy.fire_requested.connect(_on_enemy_fire_requested)
		enemies.add_child(enemy)

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func _on_player_fire_requested(origin: Vector2, direction: Vector2, config: Dictionary) -> void:
	if _room_is_cleared or _room_is_failed:
		return
	_execute_primary_behavior(origin, direction, config)
	_process_primary_trigger_event("on_fire", _build_primary_combat_context(origin, direction, config))

func _on_player_secondary_requested(origin: Vector2, direction: Vector2, speed: float, damage: int, team: String, projectile_data: Dictionary, color: Color) -> void:
	if _room_is_cleared or _room_is_failed:
		return

	var secondary_kind := str(projectile_data.get("kind", "mine"))
	if _is_mine_secondary_kind(secondary_kind):
		_spawn_mine(origin, direction, speed, damage, team, projectile_data, color)
	else:
		_spawn_grenade(origin, direction, speed, damage, team, projectile_data, color)

func _on_enemy_fire_requested(origin: Vector2, direction: Vector2, speed: float, damage: int, team: String, color: Color) -> void:
	if _room_is_cleared or _room_is_failed:
		return
	_spawn_projectile(origin, direction, speed, damage, team, color)

func _spawn_projectile(origin: Vector2, direction: Vector2, speed: float, damage: int, team: String, color: Color, shooter: Node = null, feedback_profile: String = "rifle", impact_weight: float = 1.0) -> void:
	var projectile = projectile_scene.instantiate()
	projectile.global_position = origin
	projectile.setup(team, direction, speed, damage, color, shooter, feedback_profile, impact_weight)
	projectile.allow_friendly_fire = _friendly_fire_enabled and team == "player"
	projectile.impact_requested.connect(_on_projectile_impact_requested)
	projectiles.add_child(projectile)

func _spawn_projectile_from_config(origin: Vector2, direction: Vector2, config: Dictionary) -> void:
	var projectile = projectile_scene.instantiate()
	var projectile_team := str(config.get("team", "player"))
	projectile.global_position = origin
	projectile.setup_from_config(projectile_team, direction, config)
	projectile.allow_friendly_fire = _friendly_fire_enabled and projectile_team == "player"
	projectile.impact_requested.connect(_on_projectile_impact_requested)
	projectiles.add_child(projectile)

func _execute_primary_behavior(origin: Vector2, direction: Vector2, config: Dictionary) -> void:
	match str(config.get("behavior", "projectile")):
		"cone":
			_execute_primary_cone(origin, direction, config)
		"beam":
			_execute_primary_beam(origin, direction, config)
		"chain":
			_execute_primary_chain(origin, direction, config)
		_:
			_spawn_projectile_from_config(origin, direction, config)

func _execute_primary_cone(origin: Vector2, direction: Vector2, config: Dictionary) -> void:
	var max_range: float = max(float(config.get("max_distance", 0.0)), 1.0)
	var cone_angle: float = max(float(config.get("collision_half_width", 0.0)), 0.08)
	var half_angle: float = cone_angle * 0.5
	var max_targets: int = max(int(config.get("max_targets", 0)), 0)
	var hit_targets: Array = []
	for target in _get_damageable_targets_for_team(str(config.get("team", "player"))):
		if not is_instance_valid(target):
			continue
		var offset: Vector2 = target.global_position - origin
		var distance: float = offset.length()
		if distance <= 0.0 or distance > max_range:
			continue
		if abs(direction.angle_to(offset.normalized())) > half_angle:
			continue
		hit_targets.append({"target": target, "distance": distance})
	hit_targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("distance", 0.0)) < float(b.get("distance", 0.0)))
	var limit: int = hit_targets.size() if max_targets <= 0 else mini(hit_targets.size(), max_targets)
	for hit_index in range(limit):
		var hit_entry: Dictionary = hit_targets[hit_index] as Dictionary
		var target = hit_entry.get("target", null)
		_apply_damage_with_context(target, origin, direction, config)

func _execute_primary_beam(origin: Vector2, direction: Vector2, config: Dictionary) -> void:
	var max_range: float = max(float(config.get("max_distance", 0.0)), 1.0)
	var beam_width: float = max(float(config.get("collision_half_width", 0.0)), 4.0)
	var max_targets: int = max(int(config.get("max_targets", 0)), 0)
	var beam_targets: Array = []
	for target in _get_damageable_targets_for_team(str(config.get("team", "player"))):
		if not is_instance_valid(target):
			continue
		var offset: Vector2 = target.global_position - origin
		var projection: float = offset.dot(direction)
		if projection <= 0.0 or projection > max_range:
			continue
		var perpendicular: float = abs(offset.cross(direction))
		if perpendicular > beam_width:
			continue
		beam_targets.append({"target": target, "projection": projection})
	beam_targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("projection", 0.0)) < float(b.get("projection", 0.0)))
	var limit: int = beam_targets.size() if max_targets <= 0 else mini(beam_targets.size(), max_targets)
	for hit_index in range(limit):
		var hit_entry: Dictionary = beam_targets[hit_index] as Dictionary
		var target = hit_entry.get("target", null)
		_apply_damage_with_context(target, origin, direction, config)

func _execute_primary_chain(origin: Vector2, direction: Vector2, config: Dictionary) -> void:
	var chain_targets: Array = _collect_chain_targets(
		origin,
		direction,
		str(config.get("team", "player")),
		max(float(config.get("max_distance", 0.0)), 1.0),
		max(float(config.get("collision_half_width", 0.0)), 24.0),
		_resolve_chain_target_count(config)
	)
	for target in chain_targets:
		_apply_damage_with_context(target, origin if target == chain_targets[0] else (target as Node2D).global_position, direction, config)

func _collect_chain_targets(origin: Vector2, direction: Vector2, team: String, acquisition_range: float, jump_search_radius: float, max_chain_targets: int) -> Array:
	var available_targets: Array = _get_damageable_targets_for_team(team)
	var first_target = _find_chain_first_target(origin, direction, available_targets, acquisition_range)
	if first_target == null:
		return []
	var chain_targets: Array = [first_target]
	var previous_target: Node2D = first_target
	while chain_targets.size() < max_chain_targets:
		var next_target = _find_next_chain_target(previous_target, available_targets, chain_targets, jump_search_radius)
		if next_target == null:
			break
		chain_targets.append(next_target)
		previous_target = next_target
	return chain_targets

func _resolve_chain_target_count(config: Dictionary) -> int:
	var amount: int = max(int(config.get("amount", 1)), 1)
	var max_targets: int = max(int(config.get("max_targets", 0)), 0)
	return amount if max_targets <= 0 else mini(amount, max_targets)

func _find_chain_first_target(origin: Vector2, direction: Vector2, available_targets: Array, acquisition_range: float) -> Node2D:
	var best_target: Node2D = null
	var best_score := INF
	for target in available_targets:
		if not is_instance_valid(target) or not (target is Node2D):
			continue
		var node_target: Node2D = target
		var offset: Vector2 = node_target.global_position - origin
		var distance: float = offset.length()
		if distance <= 0.0 or distance > acquisition_range:
			continue
		var alignment: float = offset.normalized().dot(direction)
		if alignment < 0.1:
			continue
		var score: float = distance - alignment * 140.0
		if score < best_score:
			best_score = score
			best_target = node_target
	return best_target

func _find_next_chain_target(previous_target: Node2D, available_targets: Array, excluded_targets: Array, jump_search_radius: float) -> Node2D:
	var best_target: Node2D = null
	var best_distance := INF
	for target in available_targets:
		if not is_instance_valid(target) or not (target is Node2D):
			continue
		if excluded_targets.has(target):
			continue
		var node_target: Node2D = target
		var distance: float = previous_target.global_position.distance_to(node_target.global_position)
		if distance > jump_search_radius:
			continue
		if distance < best_distance:
			best_distance = distance
			best_target = node_target
	return best_target

func _get_damageable_targets_for_team(source_team: String) -> Array:
	var targets: Array = []
	if source_team == "player":
		for enemy in enemies.get_children():
			if enemy != null and is_instance_valid(enemy) and enemy.has_method("is_alive") and enemy.is_alive():
				targets.append(enemy)
		for generator in generators.get_children():
			if generator != null and is_instance_valid(generator) and generator.has_method("is_alive") and generator.is_alive():
				targets.append(generator)
	else:
		targets.append_array(get_active_players())
	return targets

func _apply_damage_with_context(target, origin: Vector2, direction: Vector2, config: Dictionary) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("apply_damage"):
		return
	if target.has_method("get_team") and str(target.get_team()) == str(config.get("team", "player")):
		return
	if target.has_method("apply_knockback"):
		target.apply_knockback(direction, 180.0 + float(config.get("impact_weight", 1.0)) * 90.0)
	target.apply_damage(int(config.get("damage", 1)))
	var impact_origin: Vector2 = target.global_position if target is Node2D else origin
	_handle_combat_hit(
		impact_origin,
		-direction,
		str(config.get("team", "player")),
		config.get("color", Color.WHITE),
		str(config.get("feedback_profile", "rifle")),
		float(config.get("impact_weight", 1.0)),
		target,
		_build_primary_combat_context(origin, direction, config, target)
	)

func _spawn_grenade(origin: Vector2, direction: Vector2, speed: float, damage: int, team: String, projectile_data: Dictionary, color: Color) -> void:
	var grenade = grenade_projectile_scene.instantiate()
	grenade.global_position = origin
	grenade.setup(
		team,
		direction,
		speed,
		damage,
		color,
		str(projectile_data.get("feedback_profile", "grenade")),
		float(projectile_data.get("impact_weight", 1.6))
	)
	grenade.kind = str(projectile_data.get("kind", grenade.kind))
	grenade.explosion_radius = float(projectile_data.get("explosion_radius", grenade.explosion_radius))
	grenade.fuse_time = float(projectile_data.get("fuse_time", grenade.fuse_time))
	grenade.gravity_force = float(projectile_data.get("gravity_force", grenade.gravity_force))
	grenade.pulse_count = int(projectile_data.get("pulse_count", grenade.pulse_count))
	grenade.pulse_interval = float(projectile_data.get("pulse_interval", grenade.pulse_interval))
	grenade.cluster_blast_count = int(projectile_data.get("cluster_blast_count", grenade.cluster_blast_count))
	grenade.cluster_spread_radius = float(projectile_data.get("cluster_spread_radius", grenade.cluster_spread_radius))
	grenade.source_context = {
		"owner": projectile_data.get("shooter", null),
		"weapon_id": str(projectile_data.get("weapon_id", "")),
		"weapon_tags": [],
		"source_type": str(projectile_data.get("source_type", "secondary")),
		"trigger_passives": (projectile_data.get("trigger_passives", []) as Array).duplicate(true),
	}
	grenade.exploded.connect(_on_explosive_detonated)
	grenade.damage_applied.connect(_on_secondary_damage_applied)
	projectiles.add_child(grenade)

func _spawn_mine(origin: Vector2, direction: Vector2, speed: float, damage: int, team: String, projectile_data: Dictionary, color: Color) -> void:
	var mine = mine_projectile_scene.instantiate()
	mine.global_position = origin
	mine.setup(
		team,
		direction,
		speed,
		damage,
		color,
		str(projectile_data.get("feedback_profile", "mine")),
		float(projectile_data.get("impact_weight", 1.7))
	)
	mine.kind = str(projectile_data.get("kind", mine.kind))
	mine.explosion_radius = float(projectile_data.get("explosion_radius", mine.explosion_radius))
	mine.fuse_time = float(projectile_data.get("fuse_time", mine.fuse_time))
	mine.pulse_count = int(projectile_data.get("pulse_count", mine.pulse_count))
	mine.pulse_interval = float(projectile_data.get("pulse_interval", mine.pulse_interval))
	mine.cluster_blast_count = int(projectile_data.get("cluster_blast_count", mine.cluster_blast_count))
	mine.cluster_spread_radius = float(projectile_data.get("cluster_spread_radius", mine.cluster_spread_radius))
	mine.proximity_radius = float(projectile_data.get("proximity_radius", mine.proximity_radius))
	mine.source_context = {
		"owner": projectile_data.get("shooter", null),
		"weapon_id": str(projectile_data.get("weapon_id", "")),
		"weapon_tags": [],
		"source_type": str(projectile_data.get("source_type", "secondary")),
		"trigger_passives": (projectile_data.get("trigger_passives", []) as Array).duplicate(true),
	}
	mine.exploded.connect(_on_explosive_detonated)
	mine.damage_applied.connect(_on_secondary_damage_applied)
	projectiles.add_child(mine)

func _is_mine_secondary_kind(kind: String) -> bool:
	return kind == "mine" or kind == "shrapnel_mine" or kind == "heavy_mine" or kind == "cluster_mine" or kind == "siege_mine"

func _spawn_generators() -> void:
	_clear_container(generators)
	_generator_nodes.clear()
	_generator_total_count = 0
	var configured_slots: Array = _generator_slot_positions.duplicate()
	if configured_slots.is_empty():
		configured_slots = [
			Vector2(420.0, 320.0),
			Vector2(860.0, 320.0),
			Vector2(640.0, 520.0),
		]
	var generator_count: int = mini(int(_room_config.get("generator_count", 2)), configured_slots.size())
	var generator_config := {
		"is_elite": str(_room_config.get("room_type", "")) == "elite",
		"max_health": 140 if str(_room_config.get("room_type", "")) == "elite" else 100,
		"spawn_interval": float(_room_config.get("generator_spawn_interval", 3.2)),
		"spitter_chance": float(_room_config.get("generator_spitter_chance", 0.0)),
	}
	for index in range(generator_count):
		var generator = generator_scene.instantiate()
		generator.global_position = configured_slots[index]
		generator.setup(generator_config)
		generator.generator_destroyed.connect(_on_generator_destroyed)
		generator.hit_received.connect(_on_generator_hit_received)
		generator.spawn_requested.connect(_on_generator_spawn_requested)
		generators.add_child(generator)
		_generator_nodes.append(generator)
		_spawn_world_effect(
			ParticleFactoryData.create_explosion_burst(Color(0.8, 0.92, 0.44, 1.0)),
			generator.global_position
		)
	_generator_total_count = _generator_nodes.size()

func _on_generator_destroyed(generator) -> void:
	_trigger_hitstop(0.05)
	_add_camera_trauma(0.45)
	_play_sfx_enemy_death(1.2)
	_spawn_world_effect(
		ParticleFactoryData.create_explosion_burst(Color(0.96, 0.62, 0.28, 1.0), 1.25),
		generator.global_position
	)
	_spawn_world_effect(
		ParticleFactoryData.create_explosion_ring(Color(1.0, 0.72, 0.32, 0.78), 72.0, 4.0),
		generator.global_position
	)
	_drop_pickups_for_generator(generator)
	call_deferred("_evaluate_generator_room_clear")

func _on_generator_hit_received(generator, damage_amount: int, _lethal: bool) -> void:
	if generator != null and is_instance_valid(generator):
		_spawn_world_floating_text("-%d" % damage_amount, Color(1.0, 0.88, 0.72, 1.0), generator.global_position + Vector2(0.0, -42.0))
	_play_sfx_hit()

func _on_generator_spawn_requested(generator, enemy_type: String) -> void:
	if _room_is_cleared or _room_is_failed or _room_is_in_intro:
		return
	if generator == null or not is_instance_valid(generator) or not generator.is_alive():
		return
	var enemy_cap: int = int(_room_config.get("generator_enemy_cap", 6))
	if enemies.get_child_count() >= enemy_cap:
		return
	_spawn_generator_enemy(generator, enemy_type)

func _spawn_generator_enemy(generator, enemy_type: String) -> void:
	var spawn_position: Vector2 = generator.global_position + Vector2(
		_room_random.randf_range(-24.0, 24.0),
		_room_random.randf_range(-18.0, 18.0)
	)
	_spawn_enemy_wave([{
		"position": spawn_position,
		"type": enemy_type,
		"apply_modifier": true,
	}])

func _drop_pickups_for_enemy(enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_method("is_boss") and enemy.is_boss():
		return
	var pickup_offset: Vector2 = Vector2(
		_room_random.randf_range(-18.0, 18.0),
		_room_random.randf_range(-18.0, 18.0)
	)
	var drop_pos: Vector2 = enemy.global_position + pickup_offset
	if _room_random.randf() <= 0.2:
		_spawn_pickup("gold", drop_pos, 1)
	if _room_random.randf() <= 0.15:
		_spawn_pickup("food", drop_pos + Vector2(12.0, 0.0), 1)

func _drop_pickups_for_generator(generator) -> void:
	if generator == null:
		return
	_spawn_pickup("gold", generator.global_position + Vector2(-14.0, 4.0), 1)
	_spawn_pickup("food", generator.global_position + Vector2(14.0, -4.0), 1)

func _spawn_pickup(pickup_type: String, origin: Vector2, value: int = 1) -> void:
	call_deferred("_spawn_pickup_deferred", pickup_type, origin, value)

func _spawn_pickup_deferred(pickup_type: String, origin: Vector2, value: int = 1) -> void:
	var pickup = pickup_scene.instantiate()
	pickup.global_position = origin
	pickup.setup(pickup_type, value)
	pickup.pickup_collected.connect(_on_pickup_collected)
	pickups.call_deferred("add_child", pickup)

func _on_pickup_collected(_pickup, collector, pickup_type: String, value: int) -> void:
	match pickup_type:
		"food":
			if collector != null and is_instance_valid(collector) and collector.has_method("heal"):
				var healed_amount: int = int(collector.heal(value * 10))
				if healed_amount > 0:
					_spawn_world_floating_text("+%d HP" % healed_amount, Color(0.74, 0.96, 0.48, 1.0), collector.global_position + Vector2(0.0, -46.0))
		_:
			for inventory_index in range(RunState.player_inventories.size()):
				if inventory_index < _player_nodes.size() and is_instance_valid(_player_nodes[inventory_index]):
					var player = _player_nodes[inventory_index]
					_spawn_world_floating_text("+%d Gold" % value, player.player_config.tint, player.global_position + Vector2(0.0, -32.0))
			RunState.award_gold_to_all(value)

func _auto_collect_remaining_pickups() -> void:
	var remaining_pickups: Array = pickups.get_children()
	for pickup in remaining_pickups:
		if pickup == null or not is_instance_valid(pickup):
			continue
		var pickup_kind := str(pickup.pickup_type)
		if pickup_kind == "food":
			var injured_player: Node = _find_lowest_health_living_player()
			if injured_player != null:
				pickup.collect(injured_player)
			else:
				pickup.queue_free()
		else:
			var active_players: Array = get_active_players()
			var collector: Node = active_players[0] if not active_players.is_empty() else null
			pickup.collect(collector)

func _find_lowest_health_living_player() -> Node:
	var lowest_player: Node = null
	var lowest_ratio := 2.0
	for player in get_active_players():
		if not is_instance_valid(player):
			continue
		var health_state: Dictionary = player.get_health_state()
		var current_health: int = int(health_state.get("current", 0))
		var max_health: int = max(int(health_state.get("max", 1)), 1)
		if current_health >= max_health:
			continue
		var ratio: float = float(current_health) / float(max_health)
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			lowest_player = player
	return lowest_player

func _on_enemy_died(enemy) -> void:
	var enemy_weight: float = enemy.get_feedback_weight() if enemy != null and is_instance_valid(enemy) and enemy.has_method("get_feedback_weight") else 1.0
	var enemy_color: Color = enemy.get_feedback_color() if enemy != null and is_instance_valid(enemy) and enemy.has_method("get_feedback_color") else Color(1.0, 0.28, 0.28, 1.0)
	_trigger_hitstop(0.05 + enemy_weight * 0.025)
	_add_camera_trauma(0.25 + enemy_weight * 0.20)
	_play_sfx_enemy_death(enemy_weight)
	_spawn_world_effect(
		ParticleFactoryData.create_death_burst(enemy_color, enemy_weight),
		enemy.global_position
	)
	_spawn_world_effect(
		ParticleFactoryData.create_explosion_ring(enemy_color.lightened(0.22), 44.0 + enemy_weight * 28.0, 3.0 + enemy_weight * 1.5),
		enemy.global_position
	)
	if _is_boss_room() and enemy != null and enemy.has_method("is_boss") and enemy.is_boss():
		_boss_node = null
		_handle_room_clear("Boss Defeated", "The boss collapsed and the run can continue.")
		return
	_spawn_death_puddle(enemy.global_position)
	_drop_pickups_for_enemy(enemy)
	call_deferred("_evaluate_room_state")
	if _is_generator_room():
		call_deferred("_evaluate_generator_room_clear")

func _on_player_health_changed(_current_health: int, _max_health: int) -> void:
	_refresh_debug_ui()

func _on_player_damage_taken(_player, _amount: int, _current_health: int) -> void:
	_play_sfx_damage()

func _on_player_downed(player) -> void:
	_revive_progress_by_player_id.erase(player.player_id)
	player_downed.emit(player)
	_play_damage_juice()
	_refresh_debug_ui()
	call_deferred("_evaluate_room_state")

func _on_player_revived(player) -> void:
	_revive_progress_by_player_id.erase(player.player_id)
	player_revived.emit(player)
	_play_revive_juice()
	_spawn_world_effect(
		ParticleFactoryData.create_explosion_burst(player.player_config.tint.lightened(0.18)),
		player.global_position
	)
	_refresh_debug_ui()

func _on_explosive_detonated(origin: Vector2, color: Color, feedback_profile: String, impact_weight: float, explosion_radius: float, combat_context: Dictionary) -> void:
	_play_sfx_explosion(impact_weight, feedback_profile)
	_spawn_world_effect(ParticleFactoryData.create_explosion_burst(color, impact_weight), origin)
	_spawn_world_effect(ParticleFactoryData.create_explosion_ring(color.lightened(0.1), max(explosion_radius, 46.0), 3.0 + impact_weight), origin)
	_add_camera_trauma(0.16 + impact_weight * 0.14)
	_play_zoom_punch(0.04 + impact_weight * 0.018, 0.04, 0.1 + impact_weight * 0.03)
	_process_primary_trigger_event("on_explosion", combat_context)

func _on_player_muzzle_flash_requested(origin: Vector2, direction: Vector2, color: Color, feedback_profile: String, impact_weight: float) -> void:
	_play_sfx_fire(feedback_profile, impact_weight)
	_spawn_world_effect(ParticleFactoryData.create_muzzle_flash(color, direction, feedback_profile, impact_weight), origin)
	if feedback_profile == "slug":
		_add_camera_trauma(0.16)
	elif feedback_profile == "scatter":
		_add_camera_trauma(0.10)
	else:
		_add_camera_trauma(0.05)

func _on_player_dash_trail_requested(origin: Vector2, color: Color) -> void:
	_spawn_world_effect(ParticleFactoryData.create_dash_trail(color.darkened(0.15), 1.1), origin)

func _on_player_dash_started(origin: Vector2, color: Color, shield_duration: float) -> void:
	_play_sfx_dash(1.1)
	_spawn_world_effect(ParticleFactoryData.create_dash_burst(color.lightened(0.08), Vector2.UP, 1.1), origin)
	var shield_ring_color: Color = color.lightened(0.22)
	shield_ring_color.a = min(0.72, 0.46 + shield_duration * 0.4)
	_spawn_world_effect(ParticleFactoryData.create_impact_ring(shield_ring_color, 28.0, 3.5), origin)
	_add_camera_trauma(0.07)

func _on_enemy_hit_received(enemy, damage_amount: int, lethal: bool) -> void:
	var enemy_weight: float = enemy.get_feedback_weight() if enemy != null and is_instance_valid(enemy) and enemy.has_method("get_feedback_weight") else 1.0
	_play_sfx_hit(enemy_weight)
	if not lethal:
		_trigger_hitstop(0.018 + enemy_weight * 0.01)
	if enemy != null and is_instance_valid(enemy):
		var text_color: Color = Color(1.0, 0.85, 0.7, 1.0)
		if lethal:
			text_color = enemy.get_feedback_color().lightened(0.35) if enemy.has_method("get_feedback_color") else Color(1.0, 0.72, 0.72, 1.0)
		var jitter := Vector2(_room_random.randf_range(-10.0, 10.0), _room_random.randf_range(-4.0, 4.0))
		_spawn_world_floating_text("-%d" % damage_amount, text_color, enemy.global_position + Vector2(0.0, -36.0) + jitter)

func _on_secondary_damage_applied(origin: Vector2, direction: Vector2, team: String, color: Color, feedback_profile: String, impact_weight: float, target, combat_context: Dictionary) -> void:
	_handle_combat_hit(origin, direction, team, color, feedback_profile, impact_weight, target, combat_context)

func _on_projectile_impact_requested(origin: Vector2, direction: Vector2, team: String, color: Color, feedback_profile: String, impact_weight: float, target, combat_context: Dictionary) -> void:
	_handle_combat_hit(origin, direction, team, color, feedback_profile, impact_weight, target, combat_context)

func _handle_combat_hit(origin: Vector2, direction: Vector2, _team: String, color: Color, _feedback_profile: String, impact_weight: float, target, combat_context: Dictionary) -> void:
	_spawn_world_effect(ParticleFactoryData.create_impact_sparks(color, direction, impact_weight), origin)
	_spawn_world_effect(ParticleFactoryData.create_impact_ring(color.lightened(0.15), 12.0 + impact_weight * 8.0, 2.0 + impact_weight), origin)
	if target != null and is_instance_valid(target) and target.has_method("get_team") and str(target.get_team()) == "enemy":
		_add_camera_trauma(0.015 + impact_weight * 0.015)
	_process_primary_trigger_event("on_hit", combat_context)
	if target != null and is_instance_valid(target) and target.has_method("is_alive") and not target.is_alive():
		_process_primary_trigger_event("on_kill", combat_context)

func _build_primary_combat_context(origin: Vector2, direction: Vector2, config: Dictionary, target = null) -> Dictionary:
	return {
		"owner": config.get("shooter", null),
		"weapon_id": str(config.get("weapon_id", "")),
		"weapon_tags": config.get("weapon_tags", []),
		"origin": origin,
		"direction": direction,
		"target": target,
		"damage": int(config.get("damage", 1)),
		"color": config.get("color", Color.WHITE),
		"feedback_profile": str(config.get("feedback_profile", "rifle")),
		"impact_weight": float(config.get("impact_weight", 1.0)),
		"is_tick": str(config.get("behavior", "projectile")) in ["beam", "cone"],
		"source_type": str(config.get("source_type", "primary")),
		"trigger_passives": config.get("trigger_passives", []),
	}

func _process_primary_trigger_event(hook: String, context: Dictionary) -> void:
	if _passive_trigger_system == null:
		return
	var actions: Array = _passive_trigger_system.collect_actions(hook, context)
	for action in actions:
		if action is Dictionary:
			_execute_primary_trigger_action(action as Dictionary, context)

func _execute_primary_trigger_action(action: Dictionary, context: Dictionary) -> void:
	match str(action.get("type", "")):
		"explosion":
			_execute_trigger_explosion(action, context)
		"spawn_behavior":
			_execute_trigger_behavior(action, context)
		_:
			push_warning("[CoopManager] Unsupported trigger action type '%s'." % str(action.get("type", "")))

func _execute_trigger_explosion(action: Dictionary, context: Dictionary) -> void:
	var origin: Vector2 = context.get("origin", Vector2.ZERO)
	var target = context.get("target", null)
	if target != null and is_instance_valid(target) and target is Node2D:
		origin = (target as Node2D).global_position
	var damage: int = max(int(action.get("damage", 1)), 1)
	var radius: float = max(float(action.get("radius", 48.0)), 12.0)
	var impact_weight: float = max(float(action.get("impact_weight", context.get("impact_weight", 1.0))), 0.1)
	var color: Color = action.get("color", context.get("color", Color(1.0, 0.76, 0.42, 1.0)))
	_play_sfx_explosion(impact_weight, str(action.get("feedback_profile", "grenade")))
	_spawn_world_effect(ParticleFactoryData.create_explosion_burst(color, impact_weight), origin)
	_spawn_world_effect(ParticleFactoryData.create_explosion_ring(color.lightened(0.1), max(radius, 46.0), 3.0 + impact_weight), origin)
	var hits: Array = []
	for candidate in _get_damageable_targets_for_team("player"):
		if not is_instance_valid(candidate) or not (candidate is Node2D):
			continue
		var node_candidate: Node2D = candidate
		var distance: float = origin.distance_to(node_candidate.global_position)
		if distance > radius:
			continue
		hits.append({"target": node_candidate, "distance": distance})
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("distance", 0.0)) < float(b.get("distance", 0.0)))
	var max_targets: int = max(int(action.get("max_targets", 1)), 1)
	for hit_index in range(mini(hits.size(), max_targets)):
		var target_entry: Dictionary = hits[hit_index] as Dictionary
		var hit_target = target_entry.get("target", null)
		var explosion_direction: Vector2 = ((hit_target as Node2D).global_position - origin).normalized() if hit_target != null and is_instance_valid(hit_target) and hit_target is Node2D else Vector2.RIGHT
		var trigger_config: Dictionary = {
			"weapon_id": str(context.get("weapon_id", "")),
			"weapon_tags": (context.get("weapon_tags", []) as Array).duplicate(true),
			"shooter": context.get("owner", null),
			"damage": damage,
			"team": "player",
			"color": color,
			"feedback_profile": str(action.get("feedback_profile", "grenade")),
			"impact_weight": impact_weight,
			"source_type": "trigger",
			"trigger_passives": [],
			"behavior": "explosion",
		}
		_apply_damage_with_context(hit_target, origin, explosion_direction, trigger_config)
	var explosion_context: Dictionary = context.duplicate(true)
	explosion_context["origin"] = origin
	explosion_context["damage"] = damage
	explosion_context["color"] = color
	explosion_context["source_type"] = "trigger_explosion"
	explosion_context["trigger_passives"] = []
	_process_primary_trigger_event("on_explosion", explosion_context)

func _execute_trigger_behavior(action: Dictionary, context: Dictionary) -> void:
	var origin: Vector2 = context.get("origin", Vector2.ZERO)
	var direction: Vector2 = context.get("direction", Vector2.RIGHT)
	var target = context.get("target", null)
	if target != null and is_instance_valid(target) and target is Node2D:
		direction = ((target as Node2D).global_position - origin).normalized()
	var behavior_config: Dictionary = {
		"behavior": str(action.get("behavior", "projectile")),
		"weapon_id": str(context.get("weapon_id", "")),
		"weapon_tags": (context.get("weapon_tags", []) as Array).duplicate(true),
		"trigger_passives": [],
		"source_type": "trigger",
		"speed": float(action.get("speed", 540.0)),
		"damage": max(int(action.get("damage", 1)), 1),
		"team": "player",
		"color": action.get("color", context.get("color", Color.WHITE)),
		"shooter": context.get("owner", null),
		"feedback_profile": str(action.get("feedback_profile", context.get("feedback_profile", "rifle"))),
		"impact_weight": float(action.get("impact_weight", context.get("impact_weight", 1.0))),
		"max_distance": float(action.get("range", 180.0)),
		"collision_half_width": float(action.get("area", 24.0)),
		"amount": max(int(action.get("amount", 1)), 1),
		"max_targets": max(int(action.get("max_targets", 1)), 1),
		"spread_radians": float(action.get("spread_radians", 0.0)),
		"pierce_count": max(int(action.get("pierce_count", 0)), 0),
	}
	_execute_primary_behavior(origin, direction, behavior_config)

func _evaluate_room_state() -> void:
	if _room_is_failed or _room_is_cleared:
		return

	if get_active_players().is_empty():
		_room_is_failed = true
		_reset_room_status_pulse()
		room_status_label.text = "Room status: All players down"
		_set_room_progress_ui("Defeat", "All players down", 0.0, Color(0.94, 0.32, 0.28, 1.0))
		_clear_container(projectiles)
		_clear_container(enemies)
		_clear_container(generators)
		_clear_container(pickups)
		var defeat_text := "All players were downed before the timer expired."
		if _is_boss_room():
			defeat_text = "All players were downed before the boss was defeated."
		elif _is_generator_room():
			defeat_text = "All players were downed before the generators were destroyed."
		_show_result("Defeat", defeat_text)
		all_players_dead.emit()

func _update_room_progress(delta: float) -> void:
	if _room_is_cleared or _room_is_failed:
		return

	var now := _current_time_seconds()
	if _room_is_in_intro:
		var intro_remaining: float = max(_room_intro_ends_at - now, 0.0)
		var intro_label := str(_room_config.get("title", "Room")) if _is_boss_room() else ("Destroy Generators" if _is_generator_room() else ("Shop" if _is_shop_room() else str(_active_modifier.get("name", "Modifier"))))
		room_status_label.text = "Room status: %s in %.1fs" % [intro_label, intro_remaining]
		_set_room_progress_ui("%.1fs" % intro_remaining, intro_label, clamp(intro_remaining / max(modifier_intro_duration, 0.01), 0.0, 1.0), _get_active_hud_accent())
		if now >= _room_intro_ends_at:
			_room_is_in_intro = false
			modifier_intro_panel.visible = false
			_spawn_room_opening_encounter()
		return

	_update_revive_state(delta)
	if _room_is_failed or _room_is_cleared:
		return

	if _is_boss_room():
		_update_boss_room(now)
		return

	if _is_generator_room():
		_update_generator_room(now, delta)
		return

	if _is_shop_room():
		_update_shop_room(now, delta)
		return

	var elapsed := now - _room_started_at
	var room_duration: float = float(_room_config.get("survival_duration", survival_duration))
	var remaining: float = max(room_duration - elapsed, 0.0)

	if elapsed >= room_duration:
		_handle_room_clear("Victory", "You survived for %.1f seconds." % room_duration)
		return

	if not _survival_spawn_warning_pending and now >= _next_enemy_spawn_at - 0.5:
		_pending_survival_wave_plan = _build_survival_wave_plan()
		_survival_spawn_warning_pending = true
		_show_spawn_warning(_pending_survival_wave_plan, "Wave %d" % (_survival_wave_index + 1))

	if _survival_spawn_warning_pending and now >= _next_enemy_spawn_at:
		_spawn_survival_wave(_pending_survival_wave_plan)
		_pending_survival_wave_plan = []
		_survival_spawn_warning_pending = false
		_next_enemy_spawn_at += _get_spawn_interval()

	_update_modifier_hazards(now)

	room_status_label.text = "Room status: Survive %.1fs | Enemies: %d%s" % [
		remaining,
		enemies.get_child_count(),
		_build_revive_status_suffix(),
	]
	_set_room_progress_ui(
		"Hold %.1fs" % remaining,
		"Enemies %d%s" % [enemies.get_child_count(), _build_revive_status_suffix()],
		clamp(remaining / max(room_duration, 0.01), 0.0, 1.0),
		_get_active_hud_accent()
	)
	_update_room_timer_pulse(remaining, now)

func _update_boss_room(now: float) -> void:
	var boss_alive: bool = _boss_node != null and is_instance_valid(_boss_node) and _boss_node.is_alive()
	if not boss_alive:
		_reset_room_status_pulse()
		return

	if not _boss_support_warning_pending and now >= _next_boss_support_spawn_at - 0.5:
		_pending_boss_support_plan = _build_boss_support_wave_plan()
		_boss_support_warning_pending = true
		_show_spawn_warning(_pending_boss_support_plan, "Adds Incoming")

	if _boss_support_warning_pending and now >= _next_boss_support_spawn_at:
		_spawn_boss_support_wave(_pending_boss_support_plan)
		_pending_boss_support_plan = []
		_boss_support_warning_pending = false
		_next_boss_support_spawn_at = now + boss_support_spawn_interval

	var add_count: int = max(enemies.get_child_count() - 1, 0)
	room_status_label.text = "Room status: Defeat boss | Boss HP: %s | Adds: %d%s" % [
		_boss_node.get_health_ratio_text(),
		add_count,
		_build_revive_status_suffix(),
	]
	_set_room_progress_ui(
		"Boss",
		"Bring it down | HP %s | Adds %d%s" % [_boss_node.get_health_ratio_text(), add_count, _build_revive_status_suffix()],
		_boss_node.get_health_ratio(),
		_get_active_hud_accent()
	)

func _update_generator_room(now: float, _delta: float) -> void:
	_update_modifier_hazards(now)
	_evaluate_generator_room_clear()
	if _room_is_cleared or _room_is_failed:
		return

	var alive_generators: Array = _get_alive_generators()
	var destroyed_count: int = max(_generator_total_count - alive_generators.size(), 0)
	var revive_suffix: String = _build_revive_status_suffix()
	if alive_generators.is_empty():
		room_status_label.text = "Room status: Sweep the room | Enemies: %d%s" % [enemies.get_child_count(), revive_suffix]
		_set_room_progress_ui("Sweep", "Clear the room%s" % revive_suffix, 1.0, _get_active_hud_accent())
		_reset_room_status_pulse()
		return

	room_status_label.text = "Room status: Destroy generators | %d/%d down | Enemies: %d%s" % [
		destroyed_count,
		_generator_total_count,
		enemies.get_child_count(),
		revive_suffix,
	]
	_set_room_progress_ui(
		"Cores %d/%d" % [destroyed_count, _generator_total_count],
		"Break the generators%s" % revive_suffix,
		clamp(float(destroyed_count) / max(float(_generator_total_count), 1.0), 0.0, 1.0),
		_get_active_hud_accent()
	)
	_reset_room_status_pulse()

func _evaluate_generator_room_clear() -> void:
	if not _is_generator_room() or _room_is_cleared or _room_is_failed or _room_is_in_intro:
		return
	if not _get_alive_generators().is_empty():
		return
	if enemies.get_child_count() > 0:
		return
	_handle_room_clear("Generators Down", "All generators destroyed. Area clear.")

func _update_revive_state(delta: float) -> void:
	var downed_players := get_downed_players()
	if downed_players.is_empty():
		_revive_progress_by_player_id = {}
		return

	for downed_player in downed_players:
		var reviver_found := false
		for reviver in get_active_players():
			if not is_instance_valid(reviver):
				continue
			if reviver.global_position.distance_to(downed_player.global_position) <= revive_radius:
				reviver_found = true
				var progress := float(_revive_progress_by_player_id.get(downed_player.player_id, 0.0)) + delta
				if progress >= revive_hold_duration:
					downed_player.revive(revive_health)
					_revive_progress_by_player_id.erase(downed_player.player_id)
				else:
					_revive_progress_by_player_id[downed_player.player_id] = progress
				break
		if not reviver_found:
			_revive_progress_by_player_id.erase(downed_player.player_id)

func _build_revive_status_suffix() -> String:
	if _revive_progress_by_player_id.is_empty():
		return ""

	var parts: Array = []
	for player in get_downed_players():
		var progress := float(_revive_progress_by_player_id.get(player.player_id, 0.0))
		if progress <= 0.0:
			continue
		var percent := int(round((progress / revive_hold_duration) * 100.0))
		parts.append(" Revive P%d %d%%" % [player.player_id, min(percent, 100)])

	if parts.is_empty():
		return ""
	return " |%s" % " |".join(parts)

func _handle_room_clear(title: String, detail: String) -> void:
	if _room_is_cleared or _room_is_failed:
		return
	_room_is_cleared = true
	_pending_room_clear_title = title
	_pending_room_clear_detail = detail
	_clear_container(projectiles)
	_clear_container(enemies)
	_clear_container(generators)
	_clear_spawn_warning_effects()
	if _boss_node != null and is_instance_valid(_boss_node):
		_boss_node = null
	room_status_label.text = "Room status: %s" % title
	_reset_room_status_pulse()
	_set_room_progress_ui(title, detail, 1.0, _get_active_hud_accent())
	_play_sfx_room_clear()
	var gold_gain := int(_room_config.get("currency_reward", 0))
	if gold_gain > 0:
		_spawn_screen_floating_text("+%d Gold" % gold_gain, Color(1.0, 0.88, 0.28, 1.0), Vector2(860.0, 120.0))
	_play_clear_juice()
	var reward: Dictionary = _room_config.get("reward", {}).duplicate(true)
	if str(reward.get("type", "")) == "loot_choice":
		_begin_loot_drop()
		return
	_open_exit_zone(capture_player_health_states(), {})

func _show_result(title: String, detail: String) -> void:
	result_title_label.text = title
	result_detail_label.text = detail
	_apply_panel_style(result_panel, _get_active_hud_accent())
	result_panel.visible = true

func _begin_loot_drop() -> void:
	_pending_loot_item = RunState.roll_loot_drop()
	if _pending_loot_item.is_empty() or loot_drop_scene == null:
		_open_exit_zone(capture_player_health_states(), {
			"loot_summary": "No loot was available.\n%s" % RunState.get_gold_summary_text(),
		})
		return
	if _active_loot_drop != null and is_instance_valid(_active_loot_drop):
		_active_loot_drop.queue_free()
	_active_loot_drop = loot_drop_scene.instantiate()
	_active_loot_drop.global_position = Vector2(960.0, 540.0)
	_active_loot_drop.setup(_pending_loot_item)
	_active_loot_drop.interact_requested.connect(_on_loot_drop_interacted)
	effects.add_child(_active_loot_drop)
	room_status_label.text = "Room status: Loot dropped"
	_set_room_progress_ui("Loot", "Collect pickups, then interact with the drop.", 1.0, _get_active_hud_accent())

func _on_loot_drop_interacted(_player) -> void:
	if _loot_vote_active or _pending_loot_item.is_empty():
		return
	_begin_loot_vote()

func _begin_loot_vote() -> void:
	if loot_vote_ui_scene == null:
		var fallback_result: Dictionary = RunState.resolve_loot_vote({}, _pending_loot_item, capture_player_health_states())
		_complete_loot_resolution(fallback_result)
		return
	_loot_vote_active = true
	_loot_votes = {}
	_loot_vote_take_pressed = {}
	_loot_vote_scrap_pressed = {}
	_loot_vote_deadline = _current_time_seconds() + _loot_vote_duration
	_pending_health_states_after_loot = capture_player_health_states()
	for index in range(_player_nodes.size()):
		var player = _player_nodes[index]
		if player != null and is_instance_valid(player):
			_loot_vote_take_pressed[index] = _is_player_take_button_pressed(player)
			_loot_vote_scrap_pressed[index] = _is_player_scrap_button_pressed(player)
			player.set_input_locked(true)
	if _active_loot_drop != null and is_instance_valid(_active_loot_drop):
		_active_loot_drop.set_interaction_enabled(false)
	if _loot_vote_ui != null and is_instance_valid(_loot_vote_ui):
		_loot_vote_ui.queue_free()
	_loot_vote_ui = loot_vote_ui_scene.instantiate()
	ui_layer.add_child(_loot_vote_ui)
	_loot_vote_ui.setup_for_item(_pending_loot_item, _player_nodes.size())
	_loot_vote_ui.update_vote_state(_loot_votes, _player_nodes.size(), _loot_vote_duration, _loot_vote_duration)

func _update_loot_resolution() -> void:
	if _weapon_replace_active:
		_update_weapon_replacement()
		return
	if _loot_vote_active:
		_update_loot_vote()
		return
	if _room_is_cleared and not _pending_loot_item.is_empty():
		_poll_loot_interaction_inputs()

func _poll_loot_interaction_inputs() -> void:
	if _active_loot_drop == null or not is_instance_valid(_active_loot_drop):
		return
	for player_index in range(_player_nodes.size()):
		var player = _player_nodes[player_index]
		if player == null or not is_instance_valid(player) or not player.is_alive():
			continue
		var pressed: bool = _is_player_take_button_pressed(player)
		var was_pressed: bool = bool(_loot_interact_pressed.get(player_index, false))
		if pressed and not was_pressed and _active_loot_drop.is_player_in_range(player):
			_active_loot_drop.request_interact(player)
		_loot_interact_pressed[player_index] = pressed

func _update_loot_vote() -> void:
	var now: float = _current_time_seconds()
	for player_index in range(_player_nodes.size()):
		if _loot_votes.has(player_index):
			continue
		var player = _player_nodes[player_index]
		if player == null or not is_instance_valid(player):
			_loot_votes[player_index] = "scrap"
			continue
		var take_pressed: bool = _is_player_take_button_pressed(player)
		var was_take_pressed: bool = bool(_loot_vote_take_pressed.get(player_index, false))
		if take_pressed and not was_take_pressed:
			_loot_votes[player_index] = "take"
		_loot_vote_take_pressed[player_index] = take_pressed
		if _loot_votes.has(player_index):
			continue
		var scrap_pressed: bool = _is_player_scrap_button_pressed(player)
		var was_scrap_pressed: bool = bool(_loot_vote_scrap_pressed.get(player_index, false))
		if scrap_pressed and not was_scrap_pressed:
			_loot_votes[player_index] = "scrap"
		_loot_vote_scrap_pressed[player_index] = scrap_pressed
	var time_remaining: float = max(_loot_vote_deadline - now, 0.0)
	if _loot_vote_ui != null and is_instance_valid(_loot_vote_ui):
		_loot_vote_ui.update_vote_state(_loot_votes, _player_nodes.size(), time_remaining, _loot_vote_duration)
	if _loot_votes.size() >= _player_nodes.size() or now >= _loot_vote_deadline:
		var result: Dictionary = RunState.resolve_loot_vote(_loot_votes, _pending_loot_item, _pending_health_states_after_loot)
		if not (result.get("replacement_request", {}) as Dictionary).is_empty():
			_begin_weapon_replacement(result)
			return
		if _loot_vote_ui != null and is_instance_valid(_loot_vote_ui):
			_loot_vote_ui.show_result(str(result.get("summary", "")))
		_complete_loot_resolution(result)

func _begin_weapon_replacement(result: Dictionary) -> void:
	_loot_vote_active = false
	_pending_weapon_replace_result = result.duplicate(true)
	_pending_weapon_replace_request = (result.get("replacement_request", {}) as Dictionary).duplicate(true)
	if not _pending_weapon_replace_request.has("source"):
		_pending_weapon_replace_request["source"] = "loot"
	_show_weapon_replacement_ui()

func _begin_shop_weapon_replacement(player_index: int, offer: Dictionary, preview: Dictionary) -> void:
	_pending_weapon_replace_result = {
		"source": "shop",
		"player_index": player_index,
		"item_id": str(offer.get("id", "")),
	}
	_pending_weapon_replace_request = {
		"source": "shop",
		"player_index": player_index,
		"entry": offer.duplicate(true),
		"item_id": str(offer.get("id", "")),
		"slot_type": str(preview.get("slot_type", "primary")),
		"slot_count": int(preview.get("slot_count", 2)),
	}
	_show_weapon_replacement_ui()

func _show_weapon_replacement_ui() -> void:
	_weapon_replace_selected_slot = 0
	_weapon_replace_active = true
	_close_shop_ui(false)
	if _loot_vote_ui != null and is_instance_valid(_loot_vote_ui):
		_loot_vote_ui.queue_free()
	_loot_vote_ui = null
	if weapon_replace_ui_scene == null:
		_commit_weapon_replacement(false)
		return
	if _weapon_replace_ui != null and is_instance_valid(_weapon_replace_ui):
		_weapon_replace_ui.queue_free()
	var player_index: int = int(_pending_weapon_replace_request.get("player_index", 0))
	var slot_type: String = str(_pending_weapon_replace_request.get("slot_type", "primary"))
	var slot_rows: Array = RunState.get_player_weapon_slot_display(player_index, slot_type)
	var player = _player_nodes[player_index] if player_index >= 0 and player_index < _player_nodes.size() else null
	_weapon_replace_left_pressed = _is_player_nav_left_pressed(player)
	_weapon_replace_right_pressed = _is_player_nav_right_pressed(player)
	_weapon_replace_confirm_pressed = _is_player_take_button_pressed(player)
	_weapon_replace_cancel_pressed = _is_player_scrap_button_pressed(player)
	_weapon_replace_ui = weapon_replace_ui_scene.instantiate()
	ui_layer.add_child(_weapon_replace_ui)
	_weapon_replace_ui.setup_for_replacement(player_index, _pending_weapon_replace_request.get("entry", {}), slot_type, slot_rows)
	_weapon_replace_ui.set_selected_slot(slot_rows, _weapon_replace_selected_slot)

func _update_weapon_replacement() -> void:
	var player_index: int = int(_pending_weapon_replace_request.get("player_index", -1))
	if player_index < 0 or player_index >= _player_nodes.size():
		_commit_weapon_replacement(true)
		return
	var player = _player_nodes[player_index]
	if player == null or not is_instance_valid(player):
		_commit_weapon_replacement(true)
		return
	var slot_count: int = max(1, int(_pending_weapon_replace_request.get("slot_count", 2)))
	var slot_type: String = str(_pending_weapon_replace_request.get("slot_type", "primary"))
	var slot_rows: Array = RunState.get_player_weapon_slot_display(player_index, slot_type)
	var left_pressed: bool = _is_player_nav_left_pressed(player)
	if left_pressed and not _weapon_replace_left_pressed:
		_weapon_replace_selected_slot = (_weapon_replace_selected_slot - 1 + slot_count) % slot_count
		if _weapon_replace_ui != null and is_instance_valid(_weapon_replace_ui):
			_weapon_replace_ui.set_selected_slot(slot_rows, _weapon_replace_selected_slot)
	_weapon_replace_left_pressed = left_pressed
	var right_pressed: bool = _is_player_nav_right_pressed(player)
	if right_pressed and not _weapon_replace_right_pressed:
		_weapon_replace_selected_slot = (_weapon_replace_selected_slot + 1) % slot_count
		if _weapon_replace_ui != null and is_instance_valid(_weapon_replace_ui):
			_weapon_replace_ui.set_selected_slot(slot_rows, _weapon_replace_selected_slot)
	_weapon_replace_right_pressed = right_pressed
	var confirm_pressed: bool = _is_player_take_button_pressed(player)
	if confirm_pressed and not _weapon_replace_confirm_pressed:
		_commit_weapon_replacement(false)
		return
	_weapon_replace_confirm_pressed = confirm_pressed
	var cancel_pressed: bool = _is_player_scrap_button_pressed(player)
	if cancel_pressed and not _weapon_replace_cancel_pressed:
		_commit_weapon_replacement(true)
		return
	_weapon_replace_cancel_pressed = cancel_pressed

func _commit_weapon_replacement(cancel_instead: bool) -> void:
	var replace_source: String = str(_pending_weapon_replace_request.get("source", "loot"))
	var player_index: int = int(_pending_weapon_replace_request.get("player_index", 0))
	var entry: Dictionary = (_pending_weapon_replace_request.get("entry", {}) as Dictionary).duplicate(true)
	var slot_type: String = str(_pending_weapon_replace_request.get("slot_type", "primary"))
	if replace_source == "shop":
		var item_id: String = str(_pending_weapon_replace_request.get("item_id", str(entry.get("id", ""))))
		var purchase_result: Dictionary = RunState.complete_shop_purchase(player_index, item_id, slot_type, _weapon_replace_selected_slot, cancel_instead)
		if bool(purchase_result.get("success", false)):
			_reapply_player_loadout(player_index)
		_weapon_replace_active = false
		_pending_weapon_replace_request = {}
		_pending_weapon_replace_result = {}
		if _weapon_replace_ui != null and is_instance_valid(_weapon_replace_ui):
			_weapon_replace_ui.queue_free()
		_weapon_replace_ui = null
		_shop_status_message = str(purchase_result.get("summary", "Purchase resolved."))
		if bool(purchase_result.get("success", false)):
			_shop_room_log.append(_shop_status_message)
		_open_shop_ui(player_index)
		return
	var choice_result: Dictionary = RunState.resolve_weapon_replacement_choice(player_index, entry, slot_type, _weapon_replace_selected_slot, cancel_instead)
	var summary_text: String = str(_pending_weapon_replace_result.get("summary", "")).strip_edges()
	var choice_summary: String = str(choice_result.get("summary", "")).strip_edges()
	if not choice_summary.is_empty():
		summary_text = "%s\n%s" % [summary_text, choice_summary] if not summary_text.is_empty() else choice_summary
	var result_payload: Dictionary = _pending_weapon_replace_result.duplicate(true)
	result_payload["summary"] = "%s\n%s" % [summary_text, RunState.get_gold_summary_text()] if not summary_text.is_empty() else RunState.get_gold_summary_text()
	result_payload["replacement_request"] = {}
	_weapon_replace_active = false
	_pending_weapon_replace_request = {}
	_pending_weapon_replace_result = {}
	if _weapon_replace_ui != null and is_instance_valid(_weapon_replace_ui):
		_weapon_replace_ui.queue_free()
	_weapon_replace_ui = null
	_complete_loot_resolution(result_payload)

func _complete_loot_resolution(result: Dictionary) -> void:
	_loot_vote_active = false
	_weapon_replace_active = false
	if _active_loot_drop != null and is_instance_valid(_active_loot_drop):
		_active_loot_drop.queue_free()
	_active_loot_drop = null
	if _loot_vote_ui != null and is_instance_valid(_loot_vote_ui):
		_loot_vote_ui.queue_free()
	_loot_vote_ui = null
	if _weapon_replace_ui != null and is_instance_valid(_weapon_replace_ui):
		_weapon_replace_ui.queue_free()
	_weapon_replace_ui = null
	for player in _player_nodes:
		if player != null and is_instance_valid(player):
			player.set_input_locked(false)
	_reapply_all_player_loadouts()
	var summary_text: String = str(result.get("summary", "")).strip_edges()
	if summary_text.is_empty():
		summary_text = "Loot resolved."
	var resolved_health_states: Array = result.get("health_states", _pending_health_states_after_loot)
	_pending_loot_item = {}
	_pending_health_states_after_loot = []
	_loot_votes = {}
	_loot_vote_take_pressed = {}
	_loot_vote_scrap_pressed = {}
	_loot_interact_pressed = {}
	_pending_weapon_replace_request = {}
	_pending_weapon_replace_result = {}
	_weapon_replace_left_pressed = false
	_weapon_replace_right_pressed = false
	_weapon_replace_confirm_pressed = false
	_weapon_replace_cancel_pressed = false
	_open_exit_zone(resolved_health_states, {"loot_summary": summary_text})

func _reset_loot_resolution_state() -> void:
	_pending_loot_item = {}
	_pending_health_states_after_loot = []
	_loot_vote_active = false
	_weapon_replace_active = false
	_loot_vote_deadline = 0.0
	_loot_votes = {}
	_loot_vote_take_pressed = {}
	_loot_vote_scrap_pressed = {}
	_loot_interact_pressed = {}
	_pending_weapon_replace_request = {}
	_pending_weapon_replace_result = {}
	_weapon_replace_left_pressed = false
	_weapon_replace_right_pressed = false
	_weapon_replace_confirm_pressed = false
	_weapon_replace_cancel_pressed = false
	if _active_loot_drop != null and is_instance_valid(_active_loot_drop):
		_active_loot_drop.queue_free()
	_active_loot_drop = null
	if _loot_vote_ui != null and is_instance_valid(_loot_vote_ui):
		_loot_vote_ui.queue_free()
	_loot_vote_ui = null
	if _weapon_replace_ui != null and is_instance_valid(_weapon_replace_ui):
		_weapon_replace_ui.queue_free()
	_weapon_replace_ui = null

func _open_exit_zone(health_states: Array, clear_context: Dictionary) -> void:
	_pending_room_clear_health_states = []
	for state in health_states:
		if state is Dictionary:
			_pending_room_clear_health_states.append((state as Dictionary).duplicate(true))
	_pending_room_clear_context = clear_context.duplicate(true)
	_exit_zone_hold_started_at = -1.0
	_exit_zone_auto_exit_at = _current_time_seconds() + exit_auto_transition_delay
	_set_exit_zone_visible(true)
	room_status_label.text = "Room status: Exit open"
	_set_room_progress_ui("Exit Open", "All living players must enter the exit.", 1.0, Color(0.24, 0.86, 0.56, 1.0))

func _update_exit_zone(delta: float = 0.0) -> void:
	if not _exit_zone_open or _room_is_failed:
		return
	_update_revive_state(delta)
	var now: float = _current_time_seconds()
	var active_players: Array = get_active_players()
	var everyone_inside: bool = not active_players.is_empty()
	for player in active_players:
		if not _is_player_inside_exit_zone(player):
			everyone_inside = false
			break
	var time_remaining: float = max(_exit_zone_auto_exit_at - now, 0.0)
	if everyone_inside:
		if _exit_zone_hold_started_at < 0.0:
			_exit_zone_hold_started_at = now
		var hold_remaining: float = max(exit_hold_duration - (now - _exit_zone_hold_started_at), 0.0)
		room_status_label.text = "Room status: Exit in %.1fs" % hold_remaining
		_set_room_progress_ui(
			"Exit %.1fs" % hold_remaining,
			"Everyone is in the zone. Hold steady.",
			clamp(hold_remaining / max(exit_hold_duration, 0.01), 0.0, 1.0),
			Color(0.24, 0.86, 0.56, 1.0)
		)
		if now - _exit_zone_hold_started_at >= exit_hold_duration:
			_trigger_room_exit()
		return
	_exit_zone_hold_started_at = -1.0
	room_status_label.text = "Room status: Move to exit %.1fs" % time_remaining
	_set_room_progress_ui(
		"Exit %.1fs" % time_remaining,
		"All living players must enter the zone.",
		clamp(time_remaining / max(exit_auto_transition_delay, 0.01), 0.0, 1.0),
		Color(0.24, 0.86, 0.56, 1.0)
	)
	if now >= _exit_zone_auto_exit_at:
		_spawn_screen_floating_text("Auto-exiting...", Color(0.24, 0.86, 0.56, 1.0), Vector2(960.0, 140.0))
		_trigger_room_exit()

func _trigger_room_exit() -> void:
	if not _exit_zone_open:
		return
	var resolved_health_states: Array = _pending_room_clear_health_states.duplicate(true)
	var clear_context: Dictionary = _pending_room_clear_context.duplicate(true)
	_set_exit_zone_visible(false)
	room_cleared.emit(resolved_health_states, clear_context)

func _set_exit_zone_visible(should_show: bool) -> void:
	_exit_zone_open = should_show
	if exit_zone != null:
		exit_zone.set_deferred("monitoring", should_show)
		exit_zone.set_deferred("monitorable", should_show)
	if exit_zone_visual != null:
		exit_zone_visual.visible = should_show
	if not should_show:
		_exit_zone_auto_exit_at = 0.0
		_exit_zone_hold_started_at = -1.0

func _start_shop_room() -> void:
	RunState.prepare_shop_room_offers()
	_shop_status_message = "Visit the station, buy what you need, then ready up."
	_shop_room_log = []
	_shop_room_ready_players = {}
	_shop_ready_deadline = 0.0
	if _shop_station != null and is_instance_valid(_shop_station):
		_shop_station.queue_free()
	_shop_station = null
	if shop_station_scene != null:
		_shop_station = shop_station_scene.instantiate()
		_shop_station.global_position = Vector2(960.0, 540.0)
		effects.add_child(_shop_station)
	room_status_label.text = "Room status: Shop open"
	_set_room_progress_ui("Shop", "Interact with the station to browse personal offers.", 1.0, Color(0.2, 0.72, 0.96, 1.0))

func _update_shop_room(now: float, delta: float) -> void:
	if _room_is_failed:
		return
	_update_revive_state(delta)
	if _weapon_replace_active:
		return
	if _exit_zone_open:
		return
	if _shop_active_player_index >= 0:
		_update_shop_ui(now)
		return
	_poll_shop_station_inputs()
	if _all_shop_players_ready() or (_shop_ready_deadline > 0.0 and now >= _shop_ready_deadline):
		_open_exit_zone(capture_player_health_states(), {"shop_summary": _build_shop_summary()})
		return
	var ready_count: int = _count_ready_shop_players()
	var deadline_text: String = _get_shop_ready_deadline_text(now)
	room_status_label.text = "Room status: Shop %d/%d ready%s" % [ready_count, _player_nodes.size(), "" if deadline_text.is_empty() else " | %s" % deadline_text]
	_set_room_progress_ui(
		"Shop %d/%d" % [ready_count, _player_nodes.size()],
		"Buy what you need, then ready up.%s" % ("" if deadline_text.is_empty() else "  %s" % deadline_text),
		1.0,
		Color(0.2, 0.72, 0.96, 1.0)
	)

func _poll_shop_station_inputs() -> void:
	if _shop_station == null or not is_instance_valid(_shop_station):
		return
	for player_index in range(_player_nodes.size()):
		var player = _player_nodes[player_index]
		if player == null or not is_instance_valid(player) or not player.is_alive():
			continue
		if bool(_shop_room_ready_players.get(player_index, false)):
			continue
		var pressed: bool = _is_player_take_button_pressed(player)
		var was_pressed: bool = bool(_shop_interact_pressed.get(player_index, false))
		if pressed and not was_pressed and _shop_station.is_player_in_range(player):
			_open_shop_ui(player_index)
		_shop_interact_pressed[player_index] = pressed

func _open_shop_ui(player_index: int) -> void:
	if shop_ui_scene == null or player_index < 0 or player_index >= _player_nodes.size():
		return
	var player = _player_nodes[player_index]
	if player == null or not is_instance_valid(player):
		return
	_shop_active_player_index = player_index
	_shop_selection_index = 0
	_shop_nav_left_pressed = false
	_shop_nav_right_pressed = false
	_shop_confirm_pressed = false
	_shop_cancel_pressed = false
	player.set_input_locked(true)
	if _shop_ui != null and is_instance_valid(_shop_ui):
		_shop_ui.queue_free()
	_shop_ui = shop_ui_scene.instantiate()
	ui_layer.add_child(_shop_ui)
	_refresh_shop_ui(_current_time_seconds())

func _close_shop_ui(unlock_player: bool = true) -> void:
	if unlock_player and _shop_active_player_index >= 0 and _shop_active_player_index < _player_nodes.size():
		var player = _player_nodes[_shop_active_player_index]
		if player != null and is_instance_valid(player):
			player.set_input_locked(false)
	_shop_active_player_index = -1
	if _shop_ui != null and is_instance_valid(_shop_ui):
		_shop_ui.queue_free()
	_shop_ui = null
	_shop_nav_left_pressed = false
	_shop_nav_right_pressed = false
	_shop_confirm_pressed = false
	_shop_cancel_pressed = false

func _refresh_shop_ui(now: float) -> void:
	if _shop_ui == null or not is_instance_valid(_shop_ui) or _shop_active_player_index < 0:
		return
	var offers: Array = RunState.get_shop_offers_for(_shop_active_player_index)
	var inventory: PlayerInventoryData = RunState.player_inventories[_shop_active_player_index] if _shop_active_player_index < RunState.player_inventories.size() else null
	var gold_value: int = int(inventory.gold) if inventory != null else 0
	if _shop_selection_index > 3:
		_shop_selection_index = 3
	_shop_ui.update_state(_shop_active_player_index, offers, gold_value, _shop_selection_index, _shop_room_ready_players, _get_shop_ready_deadline_text(now), _shop_status_message)

func _update_shop_ui(now: float) -> void:
	if _shop_active_player_index < 0 or _shop_active_player_index >= _player_nodes.size():
		_close_shop_ui()
		return
	var player = _player_nodes[_shop_active_player_index]
	if player == null or not is_instance_valid(player):
		_close_shop_ui()
		return
	var offers: Array = RunState.get_shop_offers_for(_shop_active_player_index)
	var selection_count: int = 4
	var left_pressed: bool = _is_player_nav_left_pressed(player)
	if left_pressed and not _shop_nav_left_pressed:
		_shop_selection_index = (_shop_selection_index - 1 + selection_count) % selection_count
	_shop_nav_left_pressed = left_pressed
	var right_pressed: bool = _is_player_nav_right_pressed(player)
	if right_pressed and not _shop_nav_right_pressed:
		_shop_selection_index = (_shop_selection_index + 1) % selection_count
	_shop_nav_right_pressed = right_pressed
	var confirm_pressed: bool = _is_player_take_button_pressed(player)
	if confirm_pressed and not _shop_confirm_pressed:
		if _shop_selection_index >= 3:
			_mark_shop_player_ready(_shop_active_player_index, now)
			_close_shop_ui()
			return
		if _shop_selection_index < offers.size() and offers[_shop_selection_index] is Dictionary:
			var offer: Dictionary = offers[_shop_selection_index]
			var preview: Dictionary = RunState.preview_shop_purchase(_shop_active_player_index, str(offer.get("id", "")))
			if not bool(preview.get("success", false)):
				_shop_status_message = str(preview.get("summary", "Purchase failed."))
			elif bool(preview.get("requires_replacement", false)):
				_begin_shop_weapon_replacement(_shop_active_player_index, offer, preview)
				return
			else:
				var purchase_result: Dictionary = RunState.complete_shop_purchase(_shop_active_player_index, str(offer.get("id", "")))
				_shop_status_message = str(purchase_result.get("summary", "Purchase complete."))
				if bool(purchase_result.get("success", false)):
					_reapply_player_loadout(_shop_active_player_index)
					_shop_room_log.append(_shop_status_message)
	_shop_confirm_pressed = confirm_pressed
	var cancel_pressed: bool = _is_player_scrap_button_pressed(player)
	if cancel_pressed and not _shop_cancel_pressed:
		_close_shop_ui()
		return
	_shop_cancel_pressed = cancel_pressed
	_refresh_shop_ui(now)

func _mark_shop_player_ready(player_index: int, now: float) -> void:
	_shop_room_ready_players[player_index] = true
	_shop_room_log.append("P%d finished shopping." % (player_index + 1))
	if _shop_ready_deadline <= 0.0:
		_shop_ready_deadline = now + 30.0

func _count_ready_shop_players() -> int:
	var ready_count: int = 0
	for ready_value in _shop_room_ready_players.values():
		if bool(ready_value):
			ready_count += 1
	return ready_count

func _all_shop_players_ready() -> bool:
	if _player_nodes.is_empty():
		return false
	for player_index in range(_player_nodes.size()):
		if not bool(_shop_room_ready_players.get(player_index, false)):
			return false
	return true

func _get_shop_ready_deadline_text(now: float) -> String:
	if _shop_ready_deadline <= 0.0:
		return ""
	return "Auto-ready in %.1fs" % max(_shop_ready_deadline - now, 0.0)

func _build_shop_summary() -> String:
	var lines: Array = ["Shop closed."]
	for log_entry in _shop_room_log:
		lines.append(str(log_entry))
	lines.append(RunState.get_gold_summary_text())
	return "\n".join(lines)

func _reset_shop_room_state() -> void:
	if _shop_active_player_index >= 0 or (_shop_ui != null and is_instance_valid(_shop_ui)):
		_close_shop_ui()
	_shop_room_ready_players = {}
	_shop_ready_deadline = 0.0
	_shop_active_player_index = -1
	_shop_selection_index = 0
	_shop_nav_left_pressed = false
	_shop_nav_right_pressed = false
	_shop_confirm_pressed = false
	_shop_cancel_pressed = false
	_shop_interact_pressed = {}
	_shop_status_message = ""
	_shop_room_log = []
	if _shop_station != null and is_instance_valid(_shop_station):
		_shop_station.queue_free()
	_shop_station = null

func _is_player_inside_exit_zone(player) -> bool:
	if player == null or not is_instance_valid(player) or exit_zone == null or exit_zone_shape == null:
		return false
	var shape: Shape2D = exit_zone_shape.shape
	if not (shape is RectangleShape2D):
		return false
	var rect_shape: RectangleShape2D = shape as RectangleShape2D
	var zone_size: Vector2 = rect_shape.size
	var zone_rect := Rect2(exit_zone.global_position - zone_size * 0.5, zone_size)
	return zone_rect.has_point(player.global_position)

func _is_player_take_button_pressed(player) -> bool:
	return _is_player_keyboard_take_pressed(player) or _is_player_gamepad_take_pressed(player)

func _is_player_scrap_button_pressed(player) -> bool:
	return _is_player_keyboard_scrap_pressed(player) or _is_player_gamepad_scrap_pressed(player)

func _is_player_keyboard_take_pressed(player) -> bool:
	match int(player.player_id):
		1:
			return Input.is_physical_key_pressed(KEY_R)
		2:
			return Input.is_physical_key_pressed(KEY_U)
		_:
			return false

func _is_player_keyboard_scrap_pressed(player) -> bool:
	match int(player.player_id):
		1:
			return Input.is_physical_key_pressed(KEY_F)
		2:
			return Input.is_physical_key_pressed(KEY_H)
		_:
			return false

func _is_player_gamepad_take_pressed(player) -> bool:
	if int(player.gamepad_device_id) < 0:
		return false
	if not Input.get_connected_joypads().has(int(player.gamepad_device_id)):
		return false
	return Input.is_joy_button_pressed(int(player.gamepad_device_id), JOY_BUTTON_A)

func _is_player_gamepad_scrap_pressed(player) -> bool:
	if int(player.gamepad_device_id) < 0:
		return false
	if not Input.get_connected_joypads().has(int(player.gamepad_device_id)):
		return false
	return Input.is_joy_button_pressed(int(player.gamepad_device_id), JOY_BUTTON_B)

func _is_player_nav_left_pressed(player) -> bool:
	return _is_player_keyboard_move_left_pressed(player) or _is_player_gamepad_nav_left_pressed(player)

func _is_player_nav_right_pressed(player) -> bool:
	return _is_player_keyboard_move_right_pressed(player) or _is_player_gamepad_nav_right_pressed(player)

func _is_player_keyboard_move_left_pressed(player) -> bool:
	match int(player.player_id):
		1:
			return Input.is_physical_key_pressed(KEY_A)
		2:
			return Input.is_physical_key_pressed(KEY_J)
		_:
			return false

func _is_player_keyboard_move_right_pressed(player) -> bool:
	match int(player.player_id):
		1:
			return Input.is_physical_key_pressed(KEY_D)
		2:
			return Input.is_physical_key_pressed(KEY_L)
		_:
			return false

func _is_player_gamepad_nav_left_pressed(player) -> bool:
	if int(player.gamepad_device_id) < 0:
		return false
	if not Input.get_connected_joypads().has(int(player.gamepad_device_id)):
		return false
	return Input.get_joy_axis(int(player.gamepad_device_id), JOY_AXIS_LEFT_X) <= -0.5

func _is_player_gamepad_nav_right_pressed(player) -> bool:
	if int(player.gamepad_device_id) < 0:
		return false
	if not Input.get_connected_joypads().has(int(player.gamepad_device_id)):
		return false
	return Input.get_joy_axis(int(player.gamepad_device_id), JOY_AXIS_LEFT_X) >= 0.5

func _show_room_intro() -> void:
	if _is_boss_room():
		modifier_intro_title_label.text = "Incoming Boss: %s" % str(_room_config.get("title", "Boss"))
		modifier_intro_detail_label.text = str(_room_config.get("description", "Defeat the boss to finish the run."))
	elif _is_generator_room():
		modifier_intro_title_label.text = "Objective: Destroy Generators"
		var detail_lines := [
			str(_room_config.get("description", "Break the generators, then sweep the room.")),
		]
		if not _active_modifier.is_empty():
			detail_lines.append("Modifier: %s" % str(_active_modifier.get("name", "Unknown")))
		modifier_intro_detail_label.text = "\n".join(detail_lines)
	elif _is_shop_room():
		modifier_intro_title_label.text = "Objective: Shop"
		modifier_intro_detail_label.text = str(_room_config.get("description", "Visit the station, buy what you need, then ready up to leave."))
	else:
		modifier_intro_title_label.text = "Incoming Modifier: %s" % str(_active_modifier.get("name", "Unknown"))
		modifier_intro_detail_label.text = str(_active_modifier.get("description", ""))
	_apply_panel_style(modifier_intro_panel, _get_active_hud_accent())
	modifier_intro_panel.visible = true

func _apply_modifier_visuals() -> void:
	if modifier_tint == null:
		return
	modifier_tint.color = Color(1.0, 1.0, 1.0, 1.0)
	_refresh_modifier_chip()

func _get_spawn_interval() -> float:
	var base_interval := float(_room_config.get("enemy_spawn_interval", enemy_spawn_interval))
	return base_interval * _modifier_engine.get_spawn_interval_multiplier(_active_modifier)

func _update_modifier_hazards(now: float) -> void:
	_update_hot_floor_zones(now)
	_update_death_puddles()

func _update_hot_floor_zones(now: float) -> void:
	var batch_interval: float = _modifier_engine.get_hot_floor_zone_interval(_active_modifier)
	if batch_interval <= 0.0:
		return
	if now >= _next_hot_floor_batch_at:
		_spawn_hot_floor_batch()
		_next_hot_floor_batch_at = now + _room_random.randf_range(maxf(batch_interval - 1.0, 0.5), batch_interval + 1.0)
	var active_players: Array = get_active_players()
	for zone_variant in _hot_floor_zones.duplicate():
		var zone: HotFloorZoneData = zone_variant as HotFloorZoneData
		if zone == null or not is_instance_valid(zone):
			_hot_floor_zones.erase(zone_variant)
			continue
		zone.apply_damage_to_targets(active_players)

func _spawn_hot_floor_batch() -> void:
	var zone_interval: float = _modifier_engine.get_hot_floor_zone_interval(_active_modifier)
	if zone_interval <= 0.0:
		return
	var zone_radius: float = _modifier_engine.get_hot_floor_zone_radius(_active_modifier)
	var zone_damage: int = _modifier_engine.get_hot_floor_zone_damage(_active_modifier)
	var warning_duration: float = _modifier_engine.get_hot_floor_warning_duration(_active_modifier)
	var active_duration: float = _modifier_engine.get_hot_floor_active_duration(_active_modifier)
	var zone_count: int = _room_random.randi_range(2, 3)
	for _index in range(zone_count):
		var zone_position: Vector2 = _roll_hot_floor_zone_position(zone_radius)
		var zone: HotFloorZoneData = HotFloorZoneData.new()
		zone.configure(zone_radius, zone_damage, warning_duration, active_duration, 1.0)
		_spawn_world_effect(zone, zone_position)
		_hot_floor_zones.append(zone)

func _roll_hot_floor_zone_position(zone_radius: float) -> Vector2:
	var bounds_rect: Rect2 = Rect2(Vector2(120.0 + zone_radius, 120.0 + zone_radius), Vector2(1680.0 - zone_radius * 2.0, 840.0 - zone_radius * 2.0))
	var fallback_position: Vector2 = ARENA_CENTER + Vector2(_room_random.randf_range(-220.0, 220.0), _room_random.randf_range(-180.0, 180.0))
	for _attempt in range(10):
		var position := Vector2(
			_room_random.randf_range(bounds_rect.position.x, bounds_rect.end.x),
			_room_random.randf_range(bounds_rect.position.y, bounds_rect.end.y)
		)
		if _is_hot_floor_position_clear(position, zone_radius):
			return position
	return fallback_position

func _is_hot_floor_position_clear(position: Vector2, zone_radius: float) -> bool:
	for player in get_active_players():
		if not is_instance_valid(player):
			continue
		if player.global_position.distance_to(position) < zone_radius * 1.25:
			return false
	return true

func _spawn_death_puddle(origin: Vector2) -> void:
	var puddle_radius: float = _modifier_engine.get_death_puddle_radius(_active_modifier)
	if puddle_radius <= 0.0:
		return
	var puddle_damage: int = _modifier_engine.get_death_puddle_tick_damage(_active_modifier)
	var puddle_tick_interval: float = _modifier_engine.get_death_puddle_tick_interval(_active_modifier)
	var warning_duration: float = _modifier_engine.get_death_puddle_warning_duration(_active_modifier)
	var active_duration: float = _modifier_engine.get_death_puddle_active_duration(_active_modifier)
	var puddle: DeathPuddleData = DeathPuddleData.new()
	puddle.configure(puddle_radius, puddle_damage, puddle_tick_interval, warning_duration, active_duration)
	_spawn_world_effect(puddle, origin)
	_death_puddles.append(puddle)

func _update_death_puddles() -> void:
	var active_players: Array = get_active_players()
	for puddle_variant in _death_puddles.duplicate():
		var puddle: DeathPuddleData = puddle_variant as DeathPuddleData
		if puddle == null or not is_instance_valid(puddle):
			_death_puddles.erase(puddle_variant)
			continue
		puddle.apply_damage_to_targets(active_players)

func _clear_modifier_hazards() -> void:
	for zone_variant in _hot_floor_zones:
		if is_instance_valid(zone_variant):
			zone_variant.queue_free()
	_hot_floor_zones.clear()
	for puddle_variant in _death_puddles:
		if is_instance_valid(puddle_variant):
			puddle_variant.queue_free()
	_death_puddles.clear()

func _on_retry_button_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	pause_panel.visible = false
	_clear_spawn_warning_effects()
	_spawn_players()
	_start_room()
	_refresh_debug_ui()

func _on_resume_button_pressed() -> void:
	_set_paused(false)

func _on_pause_settings_button_pressed() -> void:
	_play_ui_click()
	_open_pause_settings()

func _on_pause_settings_back_button_pressed() -> void:
	_play_ui_click()
	_close_pause_settings()

func _on_pause_aim_mode_selected(selected_index: int, player_index: int) -> void:
	if player_index < 0 or player_index >= _settings_options.size() or player_index >= _player_configs.size():
		return
	_play_ui_click()
	_apply_player_aim_mode(player_index, int(_settings_options[player_index].get_item_metadata(selected_index)))

func _on_pause_screen_effect_selected(selected_index: int) -> void:
	if settings_screen_effect_option == null:
		return
	_play_ui_click()
	ProfileState.set_screen_effect_level(str(settings_screen_effect_option.get_item_metadata(selected_index)))
	_apply_screen_effect_setting()
	_refresh_pause_settings_panel()

func _on_pause_retry_button_pressed() -> void:
	_on_retry_button_pressed()

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _restore_player_health_states() -> void:
	if RunState.player_health_states.size() == 0:
		return

	for index in range(min(_player_nodes.size(), RunState.player_health_states.size())):
		var player = _player_nodes[index]
		if is_instance_valid(player):
			player.set_health_state(RunState.player_health_states[index])

func _is_generator_room() -> bool:
	return str(_room_config.get("room_objective", "survive")) == "destroy_generators"

func _is_shop_room() -> bool:
	return str(_room_config.get("room_type", "")) == "shop"

func _is_boss_room() -> bool:
	return str(_room_config.get("room_type", "")) == "boss"

func _get_alive_generators() -> Array:
	var alive_generators: Array = []
	for generator in _generator_nodes:
		if generator != null and is_instance_valid(generator) and generator.is_alive():
			alive_generators.append(generator)
	return alive_generators

func _get_enemy_spawn_positions() -> Array:
	var spawn_positions := [
		enemy_spawn_1.global_position,
		enemy_spawn_2.global_position,
		enemy_spawn_3.global_position,
		enemy_spawn_4.global_position,
		enemy_spawn_5.global_position,
		enemy_spawn_6.global_position,
	]
	var spawn_side: String = _modifier_engine.get_spawn_side(_active_modifier)
	if spawn_side != "left":
		return spawn_positions

	var min_x: float = spawn_positions[0].x
	var max_x: float = spawn_positions[0].x
	for spawn_position in spawn_positions:
		min_x = min(min_x, spawn_position.x)
		max_x = max(max_x, spawn_position.x)
	var center_x: float = lerpf(min_x, max_x, 0.5)
	var filtered_positions: Array = []
	for spawn_position in spawn_positions:
		if spawn_position.x < center_x:
			filtered_positions.append(spawn_position)
	return filtered_positions if not filtered_positions.is_empty() else spawn_positions

func _apply_layout_preset(layout_id: String) -> void:
	var floor_points: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0),
		Vector2(1920, 0),
		Vector2(1920, 1080),
		Vector2(0, 1080),
	])
	var player_positions := [
		Vector2(860, 490),
		Vector2(1060, 490),
		Vector2(860, 590),
		Vector2(1060, 590),
	]
	var enemy_positions := [
		Vector2(60, 60),
		Vector2(1860, 60),
		Vector2(60, 1020),
		Vector2(1860, 1020),
		Vector2(960, 40),
		Vector2(960, 1040),
	]
	var generator_positions := [
		Vector2(540, 380),
		Vector2(1380, 380),
		Vector2(960, 760),
	]
	var obstacle_positions: Array = []
	var obstacle_radii: Array = []
	var obstacle_segments: Array = []

	match layout_id:
		"crossfire":
			enemy_positions = [
				Vector2(60, 300), Vector2(1860, 300),
				Vector2(60, 780), Vector2(1860, 780),
				Vector2(480, 40), Vector2(1440, 40),
			]
			generator_positions = [Vector2(420, 380), Vector2(1500, 380), Vector2(960, 700)]
		"pinch":
			player_positions = [
				Vector2(910, 540), Vector2(1010, 540),
				Vector2(860, 540), Vector2(1060, 540),
			]
			enemy_positions = [
				Vector2(60, 200), Vector2(1860, 200),
				Vector2(60, 880), Vector2(1860, 880),
				Vector2(960, 40), Vector2(960, 1040),
			]
			generator_positions = [Vector2(600, 340), Vector2(1320, 340), Vector2(960, 780)]
		"offset":
			player_positions = [Vector2(820, 500), Vector2(1020, 470), Vector2(900, 620), Vector2(1100, 590)]
			enemy_positions = [
				Vector2(60, 140), Vector2(1860, 220),
				Vector2(60, 960), Vector2(1860, 900),
				Vector2(760, 40), Vector2(1160, 1040),
			]
			generator_positions = [Vector2(500, 320), Vector2(1440, 420), Vector2(1040, 760)]
		"gauntlet_pockets":
			player_positions = [Vector2(860, 520), Vector2(1060, 520), Vector2(860, 620), Vector2(1060, 620)]
			enemy_positions = [
				Vector2(60, 180), Vector2(1860, 180),
				Vector2(60, 900), Vector2(1860, 900),
				Vector2(960, 40), Vector2(960, 1040),
			]
			generator_positions = [Vector2(540, 380), Vector2(1380, 380), Vector2(960, 760)]
		"pillars":
			player_positions = [
				Vector2(860, 490), Vector2(1060, 490),
				Vector2(860, 590), Vector2(1060, 590),
			]
			enemy_positions = [
				Vector2(60, 60), Vector2(1860, 60),
				Vector2(60, 1020), Vector2(1860, 1020),
				Vector2(960, 40), Vector2(960, 1040),
			]
			generator_positions = [Vector2(540, 380), Vector2(1380, 380), Vector2(960, 760)]
			obstacle_positions = [
				Vector2(420, 340), Vector2(1500, 340),
				Vector2(420, 740), Vector2(1500, 740),
			]
			obstacle_radii = [52.0, 52.0, 52.0, 52.0]
		"ring":
			player_positions = [
				Vector2(910, 520), Vector2(1010, 520),
				Vector2(910, 580), Vector2(1010, 580),
			]
			enemy_positions = [
				Vector2(60, 60), Vector2(1860, 60),
				Vector2(60, 1020), Vector2(1860, 1020),
				Vector2(480, 40), Vector2(1440, 1040),
			]
			generator_positions = [Vector2(540, 380), Vector2(1380, 380), Vector2(960, 760)]
			obstacle_positions = [
				Vector2(960, 250),
				Vector2(1165, 335),
				Vector2(1248, 540),
				Vector2(1165, 745),
				Vector2(960, 830),
				Vector2(755, 745),
				Vector2(672, 540),
				Vector2(755, 335),
			]
			obstacle_radii = [48.0, 48.0, 48.0, 48.0, 48.0, 48.0, 48.0, 48.0]
		"pockets":
			player_positions = [
				Vector2(860, 500), Vector2(1060, 500),
				Vector2(860, 600), Vector2(1060, 600),
			]
			enemy_positions = [
				Vector2(60, 180), Vector2(1860, 180),
				Vector2(60, 900), Vector2(1860, 900),
				Vector2(960, 40), Vector2(960, 1040),
			]
			generator_positions = [Vector2(440, 320), Vector2(1480, 320), Vector2(960, 790)]
			obstacle_positions = [
				Vector2(390, 320), Vector2(510, 320),
				Vector2(1410, 320), Vector2(1530, 320),
				Vector2(900, 790), Vector2(1020, 790),
			]
			obstacle_radii = [42.0, 42.0, 42.0, 42.0, 42.0, 42.0]
		"lane":
			player_positions = [
				Vector2(900, 540), Vector2(1020, 540),
				Vector2(860, 540), Vector2(1060, 540),
			]
			enemy_positions = [
				Vector2(60, 220), Vector2(1860, 220),
				Vector2(60, 860), Vector2(1860, 860),
				Vector2(960, 60), Vector2(960, 1020),
			]
			generator_positions = [Vector2(620, 210), Vector2(620, 540), Vector2(620, 870)]
			obstacle_segments = [
				{"position": Vector2(960, 340), "size": Vector2(1120, 24)},
				{"position": Vector2(960, 740), "size": Vector2(1120, 24)},
			]
		"boss_gate":
			player_positions = [
				Vector2(860, 700), Vector2(1060, 700),
				Vector2(910, 800), Vector2(1010, 800),
			]
			enemy_positions = [
				Vector2(200, 60), Vector2(1720, 60),
				Vector2(60, 540), Vector2(1860, 540),
				Vector2(960, 40), Vector2(960, 1040),
			]
			generator_positions = [Vector2(540, 260), Vector2(1380, 260), Vector2(960, 620)]

	camera.position = Vector2(960, 540)
	camera.zoom = Vector2(1.0, 1.0)
	floor_visual.polygon = floor_points
	back_wall_visual.visible = false
	left_wall_visual.visible = false
	right_wall_visual.visible = false
	_apply_layout_palette(layout_id)
	_rebuild_floor_grid(floor_points, _get_layout_palette(layout_id).get("grid_color", Color(0.2, 0.22, 0.24, 0.5)))
	_apply_collision_bounds_from_floor(floor_points)
	player_1_spawn.position = player_positions[0]
	player_2_spawn.position = player_positions[1]
	player_3_spawn.position = player_positions[2]
	player_4_spawn.position = player_positions[3]
	enemy_spawn_1.position = enemy_positions[0]
	enemy_spawn_2.position = enemy_positions[1]
	enemy_spawn_3.position = enemy_positions[2]
	enemy_spawn_4.position = enemy_positions[3]
	enemy_spawn_5.position = enemy_positions[4]
	enemy_spawn_6.position = enemy_positions[5]
	_generator_slot_positions = _sanitize_generator_positions(generator_positions, obstacle_positions, obstacle_radii, obstacle_segments)
	_spawn_obstacles(obstacle_positions, obstacle_radii)
	_spawn_obstacle_segments(obstacle_segments)

func _spawn_obstacles(positions: Array, radii: Array) -> void:
	_clear_obstacles()
	for index in range(positions.size()):
		var position: Vector2 = positions[index]
		var radius: float = float(radii[index]) if index < radii.size() else 48.0
		if position.distance_to(ARENA_CENTER) < CENTER_OBSTACLE_EXCLUSION_RADIUS + radius:
			continue
		var obstacle := StaticBody2D.new()
		obstacle.position = position
		obstacle.collision_layer = 1
		obstacle.collision_mask = 0
		obstacle.z_as_relative = false
		obstacle.z_index = 5

		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = radius
		shape.shape = circle
		obstacle.add_child(shape)

		var pillar_outline := Polygon2D.new()
		pillar_outline.color = Color(0.08, 0.10, 0.12, 0.96)
		pillar_outline.polygon = _build_circle_polygon(radius + 3.0, 12)
		pillar_outline.z_index = 0
		obstacle.add_child(pillar_outline)

		var pillar_visual := Polygon2D.new()
		pillar_visual.color = Color(0.62, 0.66, 0.72, 0.98)
		pillar_visual.polygon = _build_circle_polygon(radius, 12)
		pillar_visual.z_index = 1
		obstacle.add_child(pillar_visual)

		var pillar_cap := Polygon2D.new()
		pillar_cap.color = Color(0.82, 0.86, 0.90, 0.98)
		pillar_cap.polygon = _build_circle_polygon(radius * 0.58, 12)
		pillar_cap.z_index = 2
		obstacle.add_child(pillar_cap)

		add_child(obstacle)
		_obstacle_nodes.append(obstacle)

func _spawn_obstacle_segments(segments: Array) -> void:
	for segment_variant in segments:
		if not (segment_variant is Dictionary):
			continue
		var segment: Dictionary = segment_variant as Dictionary
		var position: Vector2 = segment.get("position", ARENA_CENTER)
		var size: Vector2 = segment.get("size", Vector2(320.0, 24.0))
		_spawn_rect_obstacle(position, size)

func _spawn_rect_obstacle(position: Vector2, size: Vector2) -> void:
	var obstacle := StaticBody2D.new()
	obstacle.position = position
	obstacle.collision_layer = 1
	obstacle.collision_mask = 0
	obstacle.z_as_relative = false
	obstacle.z_index = 5

	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	obstacle.add_child(shape)

	var outline_visual := Polygon2D.new()
	outline_visual.color = Color(0.08, 0.10, 0.12, 0.96)
	outline_visual.polygon = PackedVector2Array([
		Vector2(-size.x * 0.5 - 4.0, -size.y * 0.5 - 4.0),
		Vector2(size.x * 0.5 + 4.0, -size.y * 0.5 - 4.0),
		Vector2(size.x * 0.5 + 4.0, size.y * 0.5 + 4.0),
		Vector2(-size.x * 0.5 - 4.0, size.y * 0.5 + 4.0),
	])
	obstacle.add_child(outline_visual)

	var wall_visual := Polygon2D.new()
	wall_visual.color = Color(0.62, 0.66, 0.72, 0.98)
	wall_visual.polygon = PackedVector2Array([
		Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, size.y * 0.5),
		Vector2(-size.x * 0.5, size.y * 0.5),
	])
	wall_visual.z_index = 1
	obstacle.add_child(wall_visual)

	add_child(obstacle)
	_obstacle_nodes.append(obstacle)

func _sanitize_generator_positions(generator_positions: Array, obstacle_positions: Array, obstacle_radii: Array, obstacle_segments: Array) -> Array:
	var sanitized: Array = []
	for index in range(generator_positions.size()):
		var position: Vector2 = generator_positions[index]
		sanitized.append(_resolve_generator_position(position, obstacle_positions, obstacle_radii, obstacle_segments, sanitized))
	return sanitized

func _resolve_generator_position(candidate: Vector2, obstacle_positions: Array, obstacle_radii: Array, obstacle_segments: Array, taken_positions: Array) -> Vector2:
	if _is_generator_position_clear(candidate, obstacle_positions, obstacle_radii, obstacle_segments, taken_positions):
		return candidate
	var offsets: Array = [
		Vector2(0.0, -120.0),
		Vector2(0.0, 120.0),
		Vector2(-140.0, 0.0),
		Vector2(140.0, 0.0),
		Vector2(-120.0, -120.0),
		Vector2(120.0, -120.0),
		Vector2(-120.0, 120.0),
		Vector2(120.0, 120.0),
	]
	for offset_variant in offsets:
		var adjusted_position: Vector2 = candidate + (offset_variant as Vector2)
		if _is_generator_position_clear(adjusted_position, obstacle_positions, obstacle_radii, obstacle_segments, taken_positions):
			return adjusted_position
	return candidate

func _is_generator_position_clear(position: Vector2, obstacle_positions: Array, obstacle_radii: Array, obstacle_segments: Array, taken_positions: Array) -> bool:
	if position.x < 120.0 or position.x > 1800.0 or position.y < 120.0 or position.y > 960.0:
		return false
	for taken_variant in taken_positions:
		if position.distance_to(taken_variant as Vector2) < GENERATOR_CLEARANCE_RADIUS * 1.5:
			return false
	for index in range(obstacle_positions.size()):
		var obstacle_position: Vector2 = obstacle_positions[index]
		var obstacle_radius: float = float(obstacle_radii[index]) if index < obstacle_radii.size() else 48.0
		if position.distance_to(obstacle_position) < obstacle_radius + GENERATOR_CLEARANCE_RADIUS:
			return false
	for segment_variant in obstacle_segments:
		if not (segment_variant is Dictionary):
			continue
		var segment: Dictionary = segment_variant as Dictionary
		var segment_position: Vector2 = segment.get("position", ARENA_CENTER)
		var segment_size: Vector2 = segment.get("size", Vector2(320.0, 24.0))
		if abs(position.x - segment_position.x) < segment_size.x * 0.5 + GENERATOR_CLEARANCE_RADIUS and abs(position.y - segment_position.y) < segment_size.y * 0.5 + GENERATOR_CLEARANCE_RADIUS:
			return false
	return true

func _clear_obstacles() -> void:
	for obstacle in _obstacle_nodes:
		if is_instance_valid(obstacle):
			obstacle.queue_free()
	_obstacle_nodes.clear()

func _build_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle: float = float(index) / float(segments) * TAU
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	return points

func _play_intro_juice() -> void:
	if modifier_intro_panel == null or camera == null:
		return
	modifier_intro_panel.scale = Vector2(0.96, 0.96)
	modifier_intro_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(modifier_intro_panel, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(modifier_intro_panel, "scale", Vector2.ONE, 0.18)
	tween.parallel().tween_property(camera, "zoom", camera.zoom * 0.98, 0.16)
	tween.tween_property(camera, "zoom", camera.zoom, 0.18)

func _play_damage_juice() -> void:
	if camera == null:
		return
	_add_camera_trauma(0.3)

func _play_revive_juice() -> void:
	return

func _play_clear_juice() -> void:
	if camera == null:
		return
	_add_camera_trauma(0.4)
	var base_zoom := camera.zoom
	var tween := create_tween()
	tween.tween_property(camera, "zoom", base_zoom * 0.94, 0.1)
	tween.tween_property(camera, "zoom", base_zoom, 0.16)

func _play_player_spawn_in(player) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.scale = Vector2(0.08, 0.08)
	player.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(player, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(player, "modulate:a", 1.0, 0.18)

func _trigger_hitstop(duration: float) -> void:
	_hitstop_serial += 1
	var serial: int = _hitstop_serial
	Engine.time_scale = 0.02
	_restore_hitstop_after(duration, serial)

func _restore_hitstop_after(duration: float, serial: int) -> void:
	await get_tree().create_timer(duration, true, false, true).timeout
	if serial != _hitstop_serial:
		return
	Engine.time_scale = 1.0

func _add_camera_trauma(amount: float) -> void:
	if screen_shake == null:
		return
	screen_shake.add_trauma(amount)

func _play_zoom_punch(amount: float, in_duration: float, out_duration: float) -> void:
	if camera == null:
		return
	var base_zoom := camera.zoom
	var punch_zoom: Vector2 = base_zoom * max(0.4, 1.0 - amount)
	var tween := create_tween()
	tween.tween_property(camera, "zoom", punch_zoom, in_duration)
	tween.tween_property(camera, "zoom", base_zoom, out_duration)

func _spawn_world_effect(effect: Node2D, origin: Vector2) -> void:
	if effect == null or effects == null:
		return
	effects.add_child(effect)
	effect.global_position = origin

func _play_sfx_fire(profile: String = "rifle", weight: float = 1.0) -> void:
	if _sfx_engine != null:
		_sfx_engine.play_fire(profile, weight)

func _play_ui_click() -> void:
	if _sfx_engine != null:
		_sfx_engine.play_ui_click()

func _play_sfx_hit(weight: float = 1.0) -> void:
	if _sfx_engine != null:
		_sfx_engine.play_impact(weight)

func _play_sfx_explosion(weight: float = 1.0, profile: String = "grenade") -> void:
	if _sfx_engine != null:
		_sfx_engine.play_explosion(weight, profile)

func _play_sfx_dash(weight: float = 1.0) -> void:
	if _sfx_engine != null:
		_sfx_engine.play_dash(weight)

func _play_sfx_damage() -> void:
	if _sfx_engine != null:
		_sfx_engine.play_damage()

func _play_sfx_enemy_death(weight: float = 1.0) -> void:
	if _sfx_engine != null:
		_sfx_engine.play_enemy_death(weight)

func _play_sfx_room_clear() -> void:
	if _sfx_engine != null:
		_sfx_engine.play_room_clear()

func _build_hud() -> void:
	if ui_layer == null or _hud_root != null:
		return

	_hud_root = Control.new()
	_hud_root.name = "HUDRoot"
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(_hud_root)
	_sync_hud_root_size()
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)

	_floating_text_layer = Control.new()
	_floating_text_layer.name = "FloatingTextLayer"
	_floating_text_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_floating_text_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_floating_text_layer)
	_hide_legacy_debug_ui()

	_player_inventory_huds.clear()
	for index in range(4):
		var player_hud = PlayerInventoryHUDData.new()
		player_hud.name = "PlayerInventoryHUD%d" % (index + 1)
		var fill_color := Color(0.7, 0.7, 0.7, 1.0)
		var align_right: bool = index % 2 == 1
		if index < _player_configs.size():
			fill_color = _player_configs[index].tint
		player_hud.visible = false
		player_hud.configure_player("P%d" % (index + 1), fill_color, align_right)
		_hud_root.add_child(player_hud)
		_player_inventory_huds.append(player_hud)
	_layout_player_inventory_huds()

	_gold_panel = Panel.new()
	_gold_panel.name = "GoldPanel"
	_gold_panel.anchor_left = 1.0
	_gold_panel.anchor_right = 1.0
	_gold_panel.offset_left = -232.0
	_gold_panel.offset_top = 18.0
	_gold_panel.offset_right = -20.0
	_gold_panel.offset_bottom = 58.0
	_hud_root.add_child(_gold_panel)
	_gold_label = Label.new()
	_gold_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gold_panel.add_child(_gold_label)

	_modifier_chip_panel = Panel.new()
	_modifier_chip_panel.name = "ModifierChip"
	_modifier_chip_panel.anchor_left = 0.5
	_modifier_chip_panel.anchor_right = 0.5
	_modifier_chip_panel.offset_left = -180.0
	_modifier_chip_panel.offset_top = 22.0
	_modifier_chip_panel.offset_right = 180.0
	_modifier_chip_panel.offset_bottom = 62.0
	_hud_root.add_child(_modifier_chip_panel)
	_modifier_chip_label = Label.new()
	_modifier_chip_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modifier_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modifier_chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_modifier_chip_panel.add_child(_modifier_chip_label)

	_timer_panel = Panel.new()
	_timer_panel.name = "TimerPanel"
	_timer_panel.anchor_left = 0.5
	_timer_panel.anchor_right = 0.5
	_timer_panel.offset_left = -220.0
	_timer_panel.offset_top = 70.0
	_timer_panel.offset_right = 220.0
	_timer_panel.offset_bottom = 102.0
	_hud_root.add_child(_timer_panel)
	var timer_bg := ColorRect.new()
	timer_bg.color = Color(0.02, 0.03, 0.05, 0.72)
	timer_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_timer_panel.add_child(timer_bg)
	_timer_fill = ColorRect.new()
	_timer_fill.color = Color(0.45, 0.82, 0.54, 0.95)
	_timer_fill.anchor_top = 0.0
	_timer_fill.anchor_bottom = 1.0
	_timer_fill.offset_left = 4.0
	_timer_fill.offset_top = 4.0
	_timer_fill.offset_bottom = -4.0
	_timer_panel.add_child(_timer_fill)
	_timer_label = Label.new()
	_timer_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer_panel.add_child(_timer_label)

	_encounter_status_label = Label.new()
	_encounter_status_label.anchor_left = 0.5
	_encounter_status_label.anchor_right = 0.5
	_encounter_status_label.offset_left = -340.0
	_encounter_status_label.offset_top = 108.0
	_encounter_status_label.offset_right = 340.0
	_encounter_status_label.offset_bottom = 136.0
	_encounter_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_root.add_child(_encounter_status_label)

	_boss_health_bar = HealthBarHUDData.new()
	_boss_health_bar.position = Vector2(660.0, 18.0)
	_boss_health_bar.size = Vector2(600.0, 40.0)
	_boss_health_bar.configure("Crimson Gate", Color(0.86, 0.18, 0.18, 1.0))
	_boss_health_bar.visible = false
	_hud_root.add_child(_boss_health_bar)

	_darkness_overlay = ColorRect.new()
	_darkness_overlay.name = "DarknessOverlay"
	_darkness_overlay.color = Color(1.0, 1.0, 1.0, 1.0)
	_darkness_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_darkness_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_darkness_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = DARKNESS_OVERLAY_SHADER
	_darkness_material.shader = shader
	_darkness_overlay.material = _darkness_material
	_darkness_overlay.visible = false
	_hud_root.add_child(_darkness_overlay)
	_hud_root.move_child(_darkness_overlay, 0)

	_apply_panel_style(result_panel, Color(0.34, 0.72, 0.98, 1.0))
	_apply_panel_style(modifier_intro_panel, Color(0.34, 0.72, 0.98, 1.0))
	_apply_panel_style(pause_panel, Color(0.34, 0.72, 0.98, 1.0))
	_apply_panel_style(settings_panel, Color(0.34, 0.72, 0.98, 1.0))
	_apply_panel_style(_gold_panel, Color(0.98, 0.76, 0.22, 1.0))
	_apply_panel_style(_modifier_chip_panel, Color(0.34, 0.72, 0.98, 1.0))
	_apply_panel_style(_timer_panel, Color(0.34, 0.72, 0.98, 1.0))
	_set_room_progress_ui("Ready", "Enter the next room.", 1.0, Color(0.34, 0.72, 0.98, 1.0))
	_refresh_gold_panel()
	_refresh_player_inventory_huds()

func _sync_hud_root_size() -> void:
	if _hud_root == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	_hud_root.position = Vector2.ZERO
	_hud_root.size = viewport_size

func _layout_player_inventory_huds() -> void:
	if _hud_root == null or _player_inventory_huds.is_empty():
		return
	for index in range(_player_inventory_huds.size()):
		var player_hud: Control = _player_inventory_huds[index]
		var hud_rect: Rect2 = _get_player_inventory_hud_rect(index)
		player_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		player_hud.position = hud_rect.position
		player_hud.size = hud_rect.size

func _on_viewport_size_changed() -> void:
	_sync_hud_root_size()
	_layout_player_inventory_huds()

func _refresh_player_inventory_huds() -> void:
	if _player_inventory_huds.is_empty():
		return
	for index in range(_player_inventory_huds.size()):
		var hud = _player_inventory_huds[index]
		var has_player: bool = index < _player_nodes.size()
		hud.visible = has_player
		if not has_player:
			continue
		var player = _player_nodes[index]
		var gold_value: int = 0
		if index < RunState.player_inventories.size():
			gold_value = int((RunState.player_inventories[index] as PlayerInventoryData).gold)
		hud.update_hud({
			"header": "P%d" % player.player_id,
			"gold": gold_value,
			"health_state": player.get_health_state(),
			"health_status": player.get_health_status_text(),
			"primary_slots": player.get_primary_slot_hud_data(),
			"secondary_slots": player.get_secondary_slot_hud_data(),
			"passives": RunState.get_player_passive_display_data(index),
		})

func _get_player_inventory_hud_rect(index: int) -> Rect2:
	var width: float = 220.0
	var height: float = 146.0
	var side_margin: float = 32.0
	var bottom_margin: float = 142.0
	var row_spacing: float = 12.0
	var row_index: int = 0 if index < 2 else 1
	var column_index: int = index % 2
	var right_aligned: bool = column_index == 1
	var viewport_size: Vector2 = _hud_root.size if _hud_root != null else get_viewport_rect().size
	var x_position: float = viewport_size.x - side_margin - width if right_aligned else side_margin
	var y_position: float = viewport_size.y - bottom_margin - height - float(row_index) * (height + row_spacing)
	return Rect2(Vector2(x_position, y_position), Vector2(width, height))

func _refresh_boss_health_bar() -> void:
	if _boss_health_bar == null:
		return
	var boss_alive: bool = _boss_node != null and is_instance_valid(_boss_node) and _boss_node.is_alive()
	_boss_health_bar.visible = boss_alive
	if not boss_alive:
		return
	_boss_health_bar.configure(str(_room_config.get("title", "Boss")), Color(0.86, 0.18, 0.18, 1.0))
	_boss_health_bar.set_health(_boss_node.current_health, _boss_node.max_health)

func _refresh_gold_panel() -> void:
	if _gold_panel == null or _gold_label == null:
		return
	_gold_label.text = "Wallets  %s" % RunState.get_gold_summary_text(true)

func _spawn_world_floating_text(content: String, color: Color, world_position: Vector2) -> void:
	_spawn_screen_floating_text(content, color, _world_to_ui_position(world_position))

func _spawn_screen_floating_text(content: String, color: Color, screen_position: Vector2) -> void:
	if _floating_text_layer == null:
		return
	var floating_text = FloatingTextData.new()
	_floating_text_layer.add_child(floating_text)
	floating_text.show_text(content, color, screen_position)

func _world_to_ui_position(world_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_position

func _update_room_timer_pulse(remaining: float, now: float) -> void:
	if _timer_panel == null or _timer_label == null:
		return
	if remaining < 5.0:
		var pulse := 1.0 + 0.08 * sin(now * 10.0)
		_timer_panel.scale = Vector2.ONE * pulse
		_timer_label.modulate = Color(1.0, 0.72, 0.72, 1.0)
		return
	_reset_room_status_pulse()

func _reset_room_status_pulse() -> void:
	if _timer_panel != null:
		_timer_panel.scale = Vector2.ONE
	if _timer_label != null:
		_timer_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _is_pause_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE
	if event is InputEventJoypadButton:
		var joypad_event := event as InputEventJoypadButton
		return joypad_event.pressed and joypad_event.button_index == JOY_BUTTON_START
	return false

func _toggle_pause() -> void:
	_set_paused(not get_tree().paused)

func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	pause_panel.visible = paused
	settings_panel.visible = false
	if paused:
		_refresh_pause_settings_panel()
		resume_button.grab_focus()

func _configure_menu_focus() -> void:
	var controls: Array = [
		p1_mode_button,
		p2_mode_button,
		retry_button,
		resume_button,
		pause_settings_button,
		pause_retry_button,
		settings_screen_effect_option,
		settings_player_1_option,
		settings_player_2_option,
		settings_player_3_option,
		settings_player_4_option,
		settings_back_button,
	]
	for control in controls:
		if control == null:
			continue
		control.focus_mode = Control.FOCUS_ALL

func _update_screen_effects() -> void:
	if screen_effects == null:
		return
	var lowest_ratio := 1.0
	var has_player := false
	for player in _player_nodes:
		if not is_instance_valid(player):
			continue
		var health_state: Dictionary = player.get_health_state()
		var current_health: float = float(health_state.get("current", 0))
		var max_health: float = max(float(health_state.get("max", 1)), 1.0)
		lowest_ratio = min(lowest_ratio, current_health / max_health)
		has_player = true
	if not has_player:
		lowest_ratio = 1.0

	var intensity: float = 0.0
	if not _room_is_failed and not _room_is_cleared and not _room_is_in_intro:
		intensity = clamp(float(enemies.get_child_count()) / max(4.0 + float(_player_nodes.size()) * 1.5, 1.0), 0.0, 1.0)
	screen_effects.set_low_health_ratio(lowest_ratio)
	screen_effects.set_combat_intensity(intensity)
	_update_darkness_overlay()

func _apply_screen_effect_setting() -> void:
	if screen_effects != null and screen_effects.has_method("set_effect_level"):
		screen_effects.set_effect_level(ProfileState.get_screen_effect_level())

func _hide_legacy_debug_ui() -> void:
	var legacy_controls: Array = [
		title_label,
		p1_status_label,
		p2_status_label,
		p3_status_label,
		p4_status_label,
		p1_secondary_label,
		p2_secondary_label,
		p3_secondary_label,
		p4_secondary_label,
		connection_status_label,
		room_status_label,
		modifier_status_label,
		p1_mode_button,
		p2_mode_button,
	]
	for control in legacy_controls:
		if control == null:
			continue
		control.visible = false

func _apply_panel_style(panel: Panel, border_color: Color) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, 0.9)
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

func _set_room_progress_ui(timer_text: String, encounter_text: String, ratio: float, accent: Color) -> void:
	if _timer_fill != null and _timer_panel != null:
		var width: float = max(_timer_panel.size.x - 8.0, 0.0)
		_timer_fill.offset_right = 4.0 + width * clamp(ratio, 0.0, 1.0)
		_timer_fill.color = accent
	if _timer_label != null:
		_timer_label.text = timer_text
	if _encounter_status_label != null:
		_encounter_status_label.text = encounter_text
		_encounter_status_label.modulate = accent.lightened(0.45)
	if _timer_panel != null:
		_apply_panel_style(_timer_panel, accent)

func _refresh_modifier_chip() -> void:
	if _modifier_chip_panel == null or _modifier_chip_label == null:
		return
	_modifier_chip_panel.visible = not _is_boss_room()
	if _is_boss_room():
		return
	var accent := _get_active_hud_accent()
	var chip_text := str(_active_modifier.get("name", "No Modifier"))
	_modifier_chip_label.text = chip_text
	_modifier_chip_label.modulate = accent.lightened(0.5)
	_apply_panel_style(_modifier_chip_panel, accent)

func _get_active_hud_accent() -> Color:
	if _is_boss_room():
		return Color(0.92, 0.24, 0.28, 1.0)
	if _active_modifier.is_empty():
		return Color(0.34, 0.72, 0.98, 1.0)
	return _modifier_engine.get_tint_color(_active_modifier)

func _get_layout_palette(layout_id: String) -> Dictionary:
	return LAYOUT_PALETTES.get(layout_id, LAYOUT_PALETTES["default"])

func _apply_layout_palette(layout_id: String) -> void:
	var palette := _get_layout_palette(layout_id)
	floor_visual.color = palette.get("floor_color", floor_visual.color)
	back_wall_visual.color = palette.get("wall_color", back_wall_visual.color)
	left_wall_visual.color = palette.get("side_wall_color", left_wall_visual.color)
	right_wall_visual.color = palette.get("side_wall_color", right_wall_visual.color)

func _update_darkness_overlay() -> void:
	if _darkness_overlay == null or _darkness_material == null:
		return
	var active := _vision_radius > 0.0 and not _room_is_failed and not _room_is_cleared
	_darkness_overlay.visible = active
	if not active:
		return
	_darkness_material.set_shader_parameter("vision_radius", _vision_radius)
	for index in range(4):
		var active_key := "player_%d_active" % (index + 1)
		var position_key := "player_%d_pos" % (index + 1)
		if index < _player_nodes.size() and is_instance_valid(_player_nodes[index]):
			_darkness_material.set_shader_parameter(active_key, 1.0)
			_darkness_material.set_shader_parameter(position_key, _world_to_ui_position(_player_nodes[index].global_position))
		else:
			_darkness_material.set_shader_parameter(active_key, 0.0)
			_darkness_material.set_shader_parameter(position_key, Vector2(-9999.0, -9999.0))

func _show_spawn_warning(plan: Array, announcement: String) -> void:
	_clear_spawn_warning_effects()
	for entry in plan:
		if not (entry is Dictionary):
			continue
		var warning_position: Vector2 = entry.get("position", Vector2.ZERO)
		var warning := Polygon2D.new()
		warning.color = Color(1.0, 0.28, 0.22, 0.0)
		warning.polygon = PackedVector2Array([
			Vector2(-18, -10),
			Vector2(18, -10),
			Vector2(18, 10),
			Vector2(-18, 10),
		])
		warning.scale = Vector2(0.4, 0.4)
		_spawn_world_effect(warning, warning_position)
		_pending_warning_effects.append(warning)
		var tween := create_tween()
		tween.tween_property(warning, "scale", Vector2(1.7, 1.1), 0.46)
		tween.parallel().tween_property(warning, "color:a", 0.85, 0.12)
		tween.tween_property(warning, "color:a", 0.0, 0.34)
	if not announcement.is_empty():
		_spawn_screen_floating_text(announcement, Color(1.0, 0.72, 0.42, 1.0), Vector2(900.0, 180.0))

func _clear_spawn_warning_effects() -> void:
	for effect in _pending_warning_effects:
		if effect != null and is_instance_valid(effect):
			effect.queue_free()
	_pending_warning_effects.clear()

func _compute_polygon_center(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for point in points:
		sum += point
	return sum / float(points.size())

func _compute_bounds(points: PackedVector2Array) -> Dictionary:
	if points.is_empty():
		return {
			"min_x": 0.0,
			"max_x": 0.0,
			"min_y": 0.0,
			"max_y": 0.0,
		}
	var min_x := points[0].x
	var max_x := points[0].x
	var min_y := points[0].y
	var max_y := points[0].y
	for point in points:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)
	return {
		"min_x": min_x,
		"max_x": max_x,
		"min_y": min_y,
		"max_y": max_y,
	}

func _scale_points(points: PackedVector2Array, center: Vector2, scale_factor: float) -> PackedVector2Array:
	var scaled: Array = []
	for point in points:
		scaled.append(center + (point - center) * scale_factor)
	return PackedVector2Array(scaled)

func _scale_vector_array(points: Array, center: Vector2, scale_factor: float) -> Array:
	var scaled: Array = []
	for point in points:
		scaled.append(center + (point - center) * scale_factor)
	return scaled

func _rebuild_floor_grid(floor_points: PackedVector2Array, grid_color: Color) -> void:
	if floor_grid == null:
		return
	for child in floor_grid.get_children():
		child.queue_free()

	var bounds := _compute_bounds(floor_points)
	var min_x: float = bounds["min_x"]
	var max_x: float = bounds["max_x"]
	var min_y: float = bounds["min_y"]
	var max_y: float = bounds["max_y"]
	var spacing := 120.0

	var x := min_x + spacing
	while x < max_x:
		var vertical := Line2D.new()
		vertical.width = 2.0
		vertical.default_color = grid_color
		vertical.points = PackedVector2Array([Vector2(x, min_y), Vector2(x, max_y)])
		floor_grid.add_child(vertical)
		x += spacing

	var y := min_y + spacing
	while y < max_y:
		var horizontal := Line2D.new()
		horizontal.width = 2.0
		horizontal.default_color = grid_color
		horizontal.points = PackedVector2Array([Vector2(min_x, y), Vector2(max_x, y)])
		floor_grid.add_child(horizontal)
		y += spacing

func _apply_collision_bounds_from_floor(_floor_points: PackedVector2Array) -> void:
	var wall_thickness := 16.0
	var width := 1920.0
	var height := 1080.0
	var top_shape := top_wall.shape as RectangleShape2D
	var bottom_shape := bottom_wall.shape as RectangleShape2D
	var left_shape := left_wall.shape as RectangleShape2D
	var right_shape := right_wall.shape as RectangleShape2D
	if top_shape != null:
		top_shape.size = Vector2(width, wall_thickness)
	if bottom_shape != null:
		bottom_shape.size = Vector2(width, wall_thickness)
	if left_shape != null:
		left_shape.size = Vector2(wall_thickness, height)
	if right_shape != null:
		right_shape.size = Vector2(wall_thickness, height)

	top_wall.position = Vector2(960.0, -wall_thickness * 0.5)
	bottom_wall.position = Vector2(960.0, 1080.0 + wall_thickness * 0.5)
	left_wall.position = Vector2(-wall_thickness * 0.5, 540.0)
	right_wall.position = Vector2(1920.0 + wall_thickness * 0.5, 540.0)
