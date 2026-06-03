extends Node2D

const EnemySceneData = preload("res://scenes/enemies/Enemy.tscn")
const ProjectileSceneData = preload("res://scenes/weapons/Projectile.tscn")
const PlayerCombatIndicatorData = preload("res://scripts/ui/PlayerCombatIndicator.gd")
const MutationSystemData = preload("res://scripts/game/MutationSystem.gd")
const AbilityRegistryData = preload("res://scripts/game/AbilityRegistry.gd")
const HudPaletteData = preload("res://scripts/game/HudPalette.gd")
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
const PauseInputProxyData = preload("res://scripts/ui/PauseInputProxy.gd")

const MODIFIERS_DATA_PATH := "res://data/modifiers.json"

const ARENA_SIZE := Vector2(4800.0, 2700.0)
const ARENA_RECT := Rect2(Vector2.ZERO, ARENA_SIZE)
const ARENA_CENTER := Vector2(ARENA_SIZE.x * 0.5, ARENA_SIZE.y * 0.5)
const ARENA_MARGIN := 72.0
const BOSS_PLAYER_SPAWN_DISTANCE := 720.0
const FLOOR_GRID_SPACING := 160.0
const FLOOR_GRID_MAJOR_INTERVAL := 4
const ARENA_WALL_VISUAL_WIDTH := 18.0
const REVIVE_RADIUS := 96.0
const REVIVE_HOLD_DURATION := 1.2
const MAX_ACTIVE_PROJECTILES := 180
const HUD_REFRESH_INTERVAL := 0.08
const COLLECTOR_TARGET := 8
const COLLECTOR_TOTAL_SPAWN := 12
const COLLECTOR_SPAWN_INTERVAL := 2.5
const HEALTH_DROP_CHANCE := 0.10
const BASE_RAMP_DURATION := 45.0
const ENEMY_SEPARATION_CELL_SIZE := 96.0
const BOSS_ADD_CAP := 25
const BOSS_ADD_WAVE_MIN := 4
const BOSS_ADD_WAVE_MAX := 5
const HUD_HEALTH_COLOR := Color(0.24, 0.92, 0.34, 1.0)
const HUD_SLOT_2_COLOR := HudPaletteData.SLOT_2_COLOR
const ENEMY_PROJECTILE_COLOR := Color(1.0, 0.0, 0.0, 1.0)
const COMBAT_VFX_LOAD_THRESHOLD := 150

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
var _room_clear_started := false
var _awaiting_mutation_pick := false
var _boss_spawned := false
var _room_duration := 45.0
var _room_elapsed := 0.0
var _spawn_interval := 1.6
var _next_spawn_at := 0.0
var _enemies_spawned := 0
var _enemies_killed := 0
var _pending_enemy_spawns := 0
var _spawning_done := false
var _burst_interval := 10.0
var _next_burst_at := 0.0
var _pending_pick_consumes_levelup := false
var _pending_elite_bonus_pick := false
var _pending_clear_summary := ""
var _active_boss = null
var _active_elite = null
var _next_elite_add_spawn_at := 0.0
var _next_boss_add_spawn_at := 0.0
var _boss_add_dry_run_enabled := false
var _revive_progress_by_player_id: Dictionary = {}
var _hud_root: Control = null
var _player_combat_indicators: Array = []
var _bottom_hud: HBoxContainer = null
var _bottom_player_hud_cards: Array = []
var _objective_label: Label = null
var _room_label: Label = null
var _xp_label: Label = null
var _xp_fill: ColorRect = null
var _modifier_hud: VBoxContainer = null
var _score_label: Label = null
var _objective_panel: PanelContainer = null
var _objective_icon_label: Label = null
var _objective_title_label: Label = null
var _objective_progress_label: Label = null
var _objective_progress_bar: ProgressBar = null
var _mutation_pick_ui = null
var _active_modifiers: Array = []
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
var _enemy_separation_grid: Dictionary = {}
var _enemy_separation_grid_frame := -1
var _game_paused := false
var _pause_input_proxy = null
var _projectile_pool: Array = []
var _active_projectiles: Array = []
var _active_homing_projectiles: Array = []
var _active_beams: Array = []
var _screen_effect_level := "full"

func configure_players(configs: Array) -> void:
	_player_configs = configs.duplicate()

func configure_room(room_config: Dictionary) -> void:
	_room_config = room_config.duplicate(true)

func _ready() -> void:
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
	if _hud_root != null:
		_hud_root.queue_free()
	_hud_root = Control.new()
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(_hud_root)

	var xp_panel := PanelContainer.new()
	xp_panel.position = Vector2(700.0, 20.0)
	xp_panel.size = Vector2(520.0, 72.0)
	_hud_root.add_child(xp_panel)
	var xp_margin := MarginContainer.new()
	xp_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	xp_margin.add_theme_constant_override("margin_left", 12)
	xp_margin.add_theme_constant_override("margin_top", 10)
	xp_margin.add_theme_constant_override("margin_right", 12)
	xp_margin.add_theme_constant_override("margin_bottom", 10)
	xp_panel.add_child(xp_margin)
	var xp_layout := VBoxContainer.new()
	xp_layout.add_theme_constant_override("separation", 6)
	xp_margin.add_child(xp_layout)
	_room_label = Label.new()
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_label.add_theme_font_size_override("font_size", 16)
	xp_layout.add_child(_room_label)
	var xp_track := ColorRect.new()
	xp_track.custom_minimum_size = Vector2(488.0, 14.0)
	xp_track.color = Color(0.07, 0.09, 0.12, 0.88)
	xp_layout.add_child(xp_track)
	_xp_fill = ColorRect.new()
	_xp_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_xp_fill.color = Color(0.28, 0.9, 0.82, 0.82)
	xp_track.add_child(_xp_fill)
	_xp_label = Label.new()
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_layout.add_child(_xp_label)

	_objective_label = Label.new()
	_objective_label.position = Vector2(24.0, 24.0)
	_objective_label.size = Vector2(520.0, 54.0)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.add_theme_font_size_override("font_size", 15)
	_objective_label.visible = false
	_hud_root.add_child(_objective_label)
	_build_objective_panel()

	_score_label = Label.new()
	_score_label.position = Vector2(1520.0, 24.0)
	_score_label.size = Vector2(360.0, 28.0)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_label.add_theme_font_size_override("font_size", 16)
	_hud_root.add_child(_score_label)

	_modifier_hud = VBoxContainer.new()
	_modifier_hud.position = Vector2(1520.0, 60.0)
	_modifier_hud.add_theme_constant_override("separation", 6)
	_hud_root.add_child(_modifier_hud)

	_bottom_hud = HBoxContainer.new()
	_bottom_hud.anchor_left = 0.0
	_bottom_hud.anchor_right = 1.0
	_bottom_hud.anchor_top = 1.0
	_bottom_hud.anchor_bottom = 1.0
	_bottom_hud.offset_left = 36.0
	_bottom_hud.offset_top = -104.0
	_bottom_hud.offset_right = -36.0
	_bottom_hud.offset_bottom = -20.0
	_bottom_hud.alignment = BoxContainer.ALIGNMENT_CENTER
	var player_count := _player_configs.size()
	var card_width := 260.0 if player_count <= 2 else 200.0
	var card_separation := 14 if player_count <= 2 else 8
	var ability_font_size := 10 if player_count <= 2 else 9
	_bottom_hud.add_theme_constant_override("separation", card_separation)
	_hud_root.add_child(_bottom_hud)

	_player_combat_indicators.clear()
	_bottom_player_hud_cards.clear()
	for index in range(_player_configs.size()):
		var indicator := PlayerCombatIndicatorData.new()
		var tint: Color = _player_configs[index].tint
		var slot_1_color := _get_slot_color(tint, 0)
		var slot_2_color := _get_slot_color(tint, 1)
		indicator.configure_player(tint, slot_1_color, slot_2_color)
		_hud_root.add_child(indicator)
		_player_combat_indicators.append(indicator)

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(card_width, 72.0)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(tint.r * 0.14, tint.g * 0.14, tint.b * 0.14, 0.84)
		card_style.border_color = tint.lightened(0.18)
		card_style.set_border_width_all(1)
		card_style.corner_radius_top_left = 8
		card_style.corner_radius_top_right = 8
		card_style.corner_radius_bottom_left = 8
		card_style.corner_radius_bottom_right = 8
		card.add_theme_stylebox_override("panel", card_style)
		_bottom_hud.add_child(card)

		var card_margin := MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 10)
		card_margin.add_theme_constant_override("margin_top", 8)
		card_margin.add_theme_constant_override("margin_right", 10)
		card_margin.add_theme_constant_override("margin_bottom", 8)
		card.add_child(card_margin)

		var card_layout := VBoxContainer.new()
		card_layout.add_theme_constant_override("separation", 4)
		card_margin.add_child(card_layout)

		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 8)
		card_layout.add_child(top_row)

		var header := Label.new()
		header.text = "P%d" % (index + 1)
		header.add_theme_font_size_override("font_size", 12)
		header.add_theme_color_override("font_color", tint.lightened(0.18))
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top_row.add_child(header)

		var health_bar := ProgressBar.new()
		health_bar.show_percentage = false
		health_bar.min_value = 0.0
		health_bar.max_value = 100.0
		health_bar.value = 100.0
		health_bar.custom_minimum_size = Vector2(120.0, 10.0)
		_apply_progress_bar_tint(health_bar, HUD_HEALTH_COLOR, 0.92)
		card_layout.add_child(health_bar)

		var ability_row := HBoxContainer.new()
		ability_row.add_theme_constant_override("separation", 8)
		card_layout.add_child(ability_row)

		var slot_1_box := VBoxContainer.new()
		slot_1_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_1_box.add_theme_constant_override("separation", 2)
		ability_row.add_child(slot_1_box)
		slot_1_box.add_child(_create_hud_trigger_label("LT", slot_1_color))
		var slot_1_label := Label.new()
		slot_1_label.add_theme_font_size_override("font_size", ability_font_size)
		slot_1_label.add_theme_color_override("font_color", slot_1_color)
		slot_1_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_1_box.add_child(slot_1_label)
		var slot_1_bar := ProgressBar.new()
		slot_1_bar.show_percentage = false
		slot_1_bar.min_value = 0.0
		slot_1_bar.max_value = 100.0
		slot_1_bar.value = 100.0
		slot_1_bar.custom_minimum_size = Vector2(96.0, 8.0)
		_apply_progress_bar_tint(slot_1_bar, slot_1_color, 0.82)
		slot_1_box.add_child(slot_1_bar)

		var slot_2_box := VBoxContainer.new()
		slot_2_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_2_box.add_theme_constant_override("separation", 2)
		ability_row.add_child(slot_2_box)
		slot_2_box.add_child(_create_hud_trigger_label("RT", slot_2_color))
		var slot_2_label := Label.new()
		slot_2_label.add_theme_font_size_override("font_size", ability_font_size)
		slot_2_label.add_theme_color_override("font_color", slot_2_color)
		slot_2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_2_box.add_child(slot_2_label)
		var slot_2_bar := ProgressBar.new()
		slot_2_bar.show_percentage = false
		slot_2_bar.min_value = 0.0
		slot_2_bar.max_value = 100.0
		slot_2_bar.value = 100.0
		slot_2_bar.custom_minimum_size = Vector2(96.0, 8.0)
		_apply_progress_bar_tint(slot_2_bar, slot_2_color, 0.78)
		slot_2_box.add_child(slot_2_bar)

		_bottom_player_hud_cards.append({
			"health_bar": health_bar,
			"slot_1_label": slot_1_label,
			"slot_1_bar": slot_1_bar,
			"slot_2_label": slot_2_label,
			"slot_2_bar": slot_2_bar,
		})

func _build_objective_panel() -> void:
	_objective_panel = PanelContainer.new()
	_objective_panel.position = Vector2(24.0, 20.0)
	_objective_panel.size = Vector2(460.0, 92.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.05, 0.08, 0.86)
	panel_style.border_color = Color(0.38, 0.88, 0.78, 0.72)
	panel_style.set_border_width_all(1)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	_objective_panel.add_theme_stylebox_override("panel", panel_style)
	_hud_root.add_child(_objective_panel)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_objective_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	_objective_icon_label = Label.new()
	_objective_icon_label.custom_minimum_size = Vector2(42.0, 0.0)
	_objective_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_objective_icon_label.add_theme_font_size_override("font_size", 26)
	row.add_child(_objective_icon_label)
	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 4)
	row.add_child(layout)
	_objective_title_label = Label.new()
	_objective_title_label.add_theme_font_size_override("font_size", 15)
	_objective_title_label.add_theme_color_override("font_color", Color(0.88, 0.98, 1.0, 0.96))
	layout.add_child(_objective_title_label)
	_objective_progress_label = Label.new()
	_objective_progress_label.add_theme_font_size_override("font_size", 12)
	_objective_progress_label.add_theme_color_override("font_color", Color(0.76, 0.86, 0.92, 0.9))
	layout.add_child(_objective_progress_label)
	_objective_progress_bar = ProgressBar.new()
	_objective_progress_bar.show_percentage = false
	_objective_progress_bar.min_value = 0.0
	_objective_progress_bar.max_value = 100.0
	_objective_progress_bar.custom_minimum_size = Vector2(340.0, 10.0)
	_apply_progress_bar_tint(_objective_progress_bar, Color(0.38, 0.88, 0.78, 1.0), 0.86)
	layout.add_child(_objective_progress_bar)

func _get_slot_color(player_tint: Color, slot_index: int) -> Color:
	if slot_index == 0:
		return player_tint.lightened(0.12)
	return HUD_SLOT_2_COLOR

func _create_hud_trigger_label(text: String, tint: Color) -> Label:
	var trigger := Label.new()
	trigger.text = text
	trigger.add_theme_font_size_override("font_size", 9)
	trigger.add_theme_color_override("font_color", tint.lightened(0.25))
	trigger.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return trigger

func _apply_progress_bar_tint(bar: ProgressBar, tint: Color, alpha: float) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.04, 0.06, 0.09, 0.72)
	background.corner_radius_top_left = 3
	background.corner_radius_top_right = 3
	background.corner_radius_bottom_left = 3
	background.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(tint.r, tint.g, tint.b, alpha)
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill)

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
		player.fire_requested.connect(_on_player_fire_requested)
		player.ability_activated.connect(_on_player_ability_activated)
		player.downed.connect(_on_player_downed)
		player.revived.connect(_on_player_revived)
		player.damage_taken.connect(_on_player_damage_taken)
		player.muzzle_flash_requested.connect(_on_muzzle_flash_requested)
		_player_nodes.append(player)
	if camera.has_method("set_players"):
		camera.set_players(_player_nodes)
		camera.global_position = ARENA_CENTER

func _rebuild_player_loadouts() -> void:
	_compiled_loadouts.clear()
	for index in range(_player_nodes.size()):
		var base_loadout: Dictionary = RunState.get_player_runtime_loadout_for(index)
		var compiled_weapon := _mutation_system.get_compiled_weapon_stats(index, (base_loadout.get("weapon_stats", {}) as Dictionary))
		var compiled_loadout := {
			"weapon_id": str(base_loadout.get("weapon_id", "rifle")),
			"weapon_name": str(base_loadout.get("weapon_name", "Rifle")),
			"weapon_stats": compiled_weapon,
			"ability_slot_1": _build_runtime_ability(index, (base_loadout.get("ability_slot_1", {}) as Dictionary).duplicate(true)),
			"ability_slot_2": _build_runtime_ability(index, (base_loadout.get("ability_slot_2", {}) as Dictionary).duplicate(true)),
			"ability_slot_1_id": str(base_loadout.get("ability_slot_1_id", "shockwave")),
			"ability_slot_2_id": str(base_loadout.get("ability_slot_2_id", "dash")),
			"mutations": _mutation_system.get_active_mutations(index),
			"move_speed": float(base_loadout.get("move_speed", 488.0)) * _mutation_system.get_move_speed_multiplier(index),
			"max_health": int(round(float(base_loadout.get("max_health", 50)) * _mutation_system.get_max_health_multiplier(index))),
		}
		_compiled_loadouts.append(compiled_loadout)
		_player_nodes[index].apply_loadout(compiled_loadout)

func _build_runtime_ability(player_index: int, ability_definition: Dictionary) -> Dictionary:
	if ability_definition.is_empty():
		return {}
	var stats: Dictionary = (ability_definition.get("stats", {}) as Dictionary).duplicate(true)
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
	return {
		"id": str(ability_definition.get("id", "")),
		"name": str(ability_definition.get("name", "Ability")),
		"type": ability_type,
		"cooldown": cooldown,
		"base_cooldown": base_cooldown,
		"duration": duration,
		"stats": stats,
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
	(exit_zone_shape.shape as RectangleShape2D).size = Vector2(360.0, 140.0)
	exit_zone_visual.visible = false
	if camera.has_method("set_arena_rect"):
		camera.set_arena_rect(ARENA_RECT)
		camera.global_position = ARENA_CENTER

func _rebuild_floor_grid() -> void:
	for child in floor_grid.get_children():
		child.queue_free()
	var x := 0.0
	var column_index := 0
	while x <= ARENA_SIZE.x:
		var line := Line2D.new()
		var is_major_line := column_index % FLOOR_GRID_MAJOR_INTERVAL == 0
		line.width = 3.0 if is_major_line else 1.5
		line.default_color = Color(0.34, 0.8, 1.0, 0.3) if is_major_line else Color(0.24, 0.52, 0.68, 0.18)
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
		line.default_color = Color(0.34, 0.8, 1.0, 0.3) if is_major_line else Color(0.24, 0.52, 0.68, 0.18)
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
		wall_line.default_color = Color(0.26, 0.84, 1.0, 0.66)
		wall_line.antialiased = true
		wall_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		wall_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		wall_line.points = segment
		floor_grid.add_child(wall_line)

func _apply_arena_color_for_act(act: int) -> void:
	var hue := 0.55 if act <= 1 else 0.03
	var minor := Color.from_hsv(hue, 0.42, 0.92, 0.18)
	var major := Color.from_hsv(hue, 0.58, 1.0, 0.34)
	var wall := Color.from_hsv(hue, 0.62, 1.0, 0.68)
	if floor_visual != null:
		floor_visual.color = Color(0.0, 0.0, 0.0, 1.0)
	for child in floor_grid.get_children():
		if child is Line2D:
			var line := child as Line2D
			line.default_color = wall if line.width >= ARENA_WALL_VISUAL_WIDTH else (major if line.width >= 3.0 else minor)

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
	_set_game_paused(false)
	_rebuild_player_loadouts()
	_room_clear_started = false
	_awaiting_mutation_pick = false
	_pending_pick_consumes_levelup = false
	_pending_elite_bonus_pick = false
	_active_boss = null
	_active_elite = null
	_next_elite_add_spawn_at = 0.0
	_next_boss_add_spawn_at = 0.0
	_boss_add_dry_run_enabled = bool(_room_config.get("debug_boss_add_waves", false))
	_room_elapsed = 0.0
	_room_type = str(_room_config.get("room_type", "combat"))
	_room_enemy_pool = ( _room_config.get("enemy_pool", []) as Array).duplicate()
	_room_depth = int(_room_config.get("depth", 1))
	_room_duration = _get_room_duration()
	_spawn_interval = _get_spawn_interval()
	_next_spawn_at = 0.4
	_enemies_spawned = 0
	_enemies_killed = 0
	_pending_enemy_spawns = 0
	_spawning_done = false
	_burst_interval = 10.0 if RunState.get_current_act() <= 1 else 8.0
	_next_burst_at = _burst_interval
	_side_objective_id = str(_room_config.get("side_objective", ""))
	_side_objective_completed = false
	_kill_streak_progress = 0
	_collector_collected = 0
	_collector_spawned = 0
	_collector_spawn_timer = COLLECTOR_SPAWN_INTERVAL
	RunState.set_current_act(int(_room_config.get("act", 1)))
	_apply_arena_color_for_act(RunState.get_current_act())
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
	if _room_type == "boss":
		_spawn_boss()
	elif _room_type == "elite":
		_spawn_elite_miniboss()
	if _room_type != "boss":
		_spawn_opening_burst()
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
	_projectile_pool.clear()
	_active_projectiles.clear()
	_active_homing_projectiles.clear()
	_active_beams.clear()
	_collector_orbs.clear()
	_hold_zone = null
	_fire_floor_modifier = null
	_ice_zone_modifier = null
	_mine_field_modifier = null
	_shrinking_arena_modifier = null
	_scheduled_enemy_shockwaves.clear()
	_enemy_separation_grid.clear()
	_enemy_separation_grid_frame = -1
	_hold_buff_offer.clear()
	_invalidate_runtime_caches()

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
			_kill_streak_target = 18
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
	_populate_modifier_hud()

func _physics_process(delta: float) -> void:
	if _awaiting_mutation_pick:
		return
	if _game_paused or pause_panel.visible or get_tree().paused:
		return
	_room_elapsed += delta
	_update_scheduled_enemy_shockwaves()
	_update_homing_projectiles(delta)
	_update_active_beams(delta)
	_update_elite_add_waves()
	_update_boss_add_waves()
	_update_side_objectives(delta)
	_update_hazards(delta)
	_update_revives(delta)
	_clamp_runtime_nodes()
	_check_wave_progress()
	var now := _current_time_seconds()
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
			_cleanup_orbs()
			if _collector_collected >= COLLECTOR_TARGET:
				_complete_side_objective()

func _update_hazards(delta: float) -> void:
	for hazard in _active_hazards:
		if hazard != null and is_instance_valid(hazard):
			hazard.update_zone(delta, _player_nodes)
	_cleanup_helpers()

func _update_elite_add_waves() -> void:
	if _room_type != "elite" or _room_clear_started:
		return
	if _active_elite == null or not is_instance_valid(_active_elite) or not _active_elite.has_method("is_alive") or not _active_elite.is_alive():
		return
	if _room_elapsed < _next_elite_add_spawn_at:
		return
	_next_elite_add_spawn_at = _room_elapsed + randf_range(6.0, 8.0)
	var count := randi_range(2, 3)
	var start_edge := randi() % 4
	var health_multiplier := 0.5 if bool(_minor_modifier_flags["swarm"]) else 1.0
	for index in range(count):
		var enemy_type := _roll_wave_enemy_type(_room_enemy_pool)
		var spawn_position := _get_enemy_spawn_position_for_index(index, start_edge)
		_queue_enemy_spawn(enemy_type, spawn_position, health_multiplier)
		_enemies_spawned += 1

func _update_boss_add_waves() -> void:
	if not _boss_add_dry_run_enabled or _room_type != "boss" or _room_clear_started:
		return
	if _active_boss == null or not is_instance_valid(_active_boss) or not _active_boss.has_method("is_alive") or not _active_boss.is_alive():
		return
	if _room_elapsed < _next_boss_add_spawn_at:
		return
	var remaining_budget := _get_boss_add_budget_remaining()
	if remaining_budget <= 0:
		_next_boss_add_spawn_at = _room_elapsed + 1.0
		return
	var boss_type := str(_room_config.get("boss_type", "warden"))
	if boss_type == "hive":
		_next_boss_add_spawn_at = _room_elapsed + randf_range(5.0, 6.0)
		return
	var count := mini(randi_range(BOSS_ADD_WAVE_MIN, BOSS_ADD_WAVE_MAX), remaining_budget)
	var enemy_type := _get_boss_add_enemy_type(boss_type)
	var start_edge := randi() % 4
	var health_multiplier := 0.5 if bool(_minor_modifier_flags["swarm"]) else 1.0
	for index in range(count):
		var spawn_position := _get_enemy_spawn_position_for_index(index, start_edge)
		if _queue_boss_budgeted_enemy_spawn(enemy_type, spawn_position, health_multiplier):
			_enemies_spawned += 1
	_next_boss_add_spawn_at = _room_elapsed + randf_range(5.0, 6.0)

func _get_boss_add_enemy_type(boss_type: String) -> String:
	match boss_type:
		"warden":
			return "charger"
		"hydra":
			return "splitter"
		"pulsar":
			return "spitter"
		_:
			return "chaser"

func _get_boss_add_budget_remaining() -> int:
	if _room_type != "boss" or not _boss_add_dry_run_enabled:
		return 999999
	var live_non_boss := 0
	for enemy in _enemy_nodes:
		if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("is_alive") or not enemy.is_alive():
			continue
		if enemy.has_method("get_type_name") and str(enemy.get_type_name()).begins_with("boss_"):
			continue
		live_non_boss += 1
	return maxi(BOSS_ADD_CAP - live_non_boss - _pending_enemy_spawns, 0)

func _check_wave_progress() -> void:
	if _room_clear_started:
		return
	if _room_type == "boss":
		if _enemy_nodes.is_empty() and _pending_enemy_spawns <= 0:
			_handle_room_clear()
		return
	if not _spawning_done:
		_continuous_spawn()
	if _spawning_done and _enemy_nodes.is_empty() and _pending_enemy_spawns <= 0:
		_handle_room_clear()

func _continuous_spawn() -> void:
	if _room_elapsed >= _room_duration:
		_spawning_done = true
		return
	var health_multiplier := 0.5 if bool(_minor_modifier_flags["swarm"]) else 1.0
	if _room_elapsed >= _next_spawn_at:
		var current_interval := _spawn_interval
		var base_ramp := clampf(_room_elapsed / BASE_RAMP_DURATION, 0.0, 1.0)
		current_interval = lerpf(_spawn_interval, _spawn_interval * 0.55, base_ramp)
		if bool(_minor_modifier_flags["accelerating_waves"]):
			var ramp := clampf(_room_elapsed / min(_room_duration, 25.0), 0.0, 1.0)
			current_interval = lerpf(current_interval, current_interval * 0.6, ramp)
		_next_spawn_at = _room_elapsed + current_interval
		var batch := 2 if bool(_minor_modifier_flags["swarm"]) else 1
		var stream_start_edge := randi() % 4 if batch > 1 else 0
		for index in range(batch):
			var enemy_type := _roll_wave_enemy_type(_room_enemy_pool)
			var spawn_position := _get_enemy_spawn_position() if batch == 1 else _get_enemy_spawn_position_for_index(index, stream_start_edge)
			_queue_enemy_spawn(enemy_type, spawn_position, health_multiplier)
			_enemies_spawned += 1
	if _room_elapsed >= _next_burst_at:
		_next_burst_at = _room_elapsed + _burst_interval
		var burst_size := randi_range(4, 6) if RunState.get_current_act() <= 1 else randi_range(6, 8)
		if bool(_minor_modifier_flags["swarm"]):
			burst_size *= 2
		var burst_start_edge := randi() % 4
		for index in range(burst_size):
			var enemy_type := _roll_wave_enemy_type(_room_enemy_pool)
			var spawn_position := _get_enemy_spawn_position_for_index(index, burst_start_edge)
			_queue_enemy_spawn(enemy_type, spawn_position, health_multiplier)
			_enemies_spawned += 1

func _spawn_opening_burst() -> void:
	var burst_size := 6 if RunState.get_current_act() <= 1 else 8
	if bool(_minor_modifier_flags["swarm"]):
		burst_size *= 2
	var health_multiplier := 0.5 if bool(_minor_modifier_flags["swarm"]) else 1.0
	var start_edge := randi() % 4
	for index in range(burst_size):
		var enemy_type := _roll_wave_enemy_type(_room_enemy_pool)
		var spawn_position := _get_enemy_spawn_position_for_index(index, start_edge)
		_queue_enemy_spawn(enemy_type, spawn_position, health_multiplier)
		_enemies_spawned += 1

func _spawn_enemy_instance(enemy_type: String, spawn_position: Vector2, health_multiplier: float = 1.0) -> Node2D:
	var enemy = EnemySceneData.instantiate()
	enemies.add_child(enemy)
	enemy.global_position = spawn_position
	enemy.setup(enemy_type, self)
	enemy.apply_room_modifier({
		"health_multiplier": health_multiplier,
		"speed_multiplier": 1.33 if bool(_minor_modifier_flags["enemy_speed"]) else 1.0,
		"fire_interval_multiplier": 0.75 if bool(_minor_modifier_flags["enemy_speed"]) else 1.0,
		"shielded": bool(_minor_modifier_flags["shielded"]),
		"death_explosion_radius": 80.0 if bool(_minor_modifier_flags["explosive_death"]) else 0.0,
		"death_explosion_damage": 10 if bool(_minor_modifier_flags["explosive_death"]) else 0,
	})
	enemy.enemy_died.connect(_on_enemy_died)
	enemy.fire_requested.connect(_on_enemy_fire_requested)
	enemy.hit_received.connect(_on_enemy_hit_received)
	_enemy_nodes.append(enemy)
	return enemy

func _queue_enemy_spawn(enemy_type: String, spawn_position: Vector2, health_multiplier: float = 1.0) -> void:
	_pending_enemy_spawns += 1
	call_deferred("_spawn_queued_enemy_instance", enemy_type, spawn_position, health_multiplier)

func _queue_boss_budgeted_enemy_spawn(enemy_type: String, spawn_position: Vector2, health_multiplier: float = 1.0) -> bool:
	if _room_type == "boss" and _boss_add_dry_run_enabled and _get_boss_add_budget_remaining() <= 0:
		return false
	_queue_enemy_spawn(enemy_type, spawn_position, health_multiplier)
	return true

func _spawn_queued_enemy_instance(enemy_type: String, spawn_position: Vector2, health_multiplier: float) -> void:
	_pending_enemy_spawns = max(_pending_enemy_spawns - 1, 0)
	if _room_clear_started or not is_inside_tree():
		return
	_spawn_enemy_instance(enemy_type, spawn_position, health_multiplier)

func _spawn_elite_miniboss() -> void:
	var elite_pool := ["elite_charger", "elite_spitter", "elite_support"]
	var elite_type := str(elite_pool[randi() % elite_pool.size()])
	var spawn_position := _get_elite_spawn_position()
	_active_elite = _spawn_enemy_instance(elite_type, spawn_position)
	if _active_elite != null and _active_elite.has_method("apply_elite_act_scale"):
		_active_elite.apply_elite_act_scale(int(_room_config.get("act", 1)))
	_next_elite_add_spawn_at = _room_elapsed + randf_range(6.0, 8.0)
	_spawn_elite_entrance_vfx(spawn_position)

func _spawn_boss() -> void:
	_boss_spawned = true
	var boss_type := str(_room_config.get("boss_type", "warden"))
	var full_boss_id := "boss_%s" % boss_type
	var boss = _spawn_enemy_instance(full_boss_id, ARENA_CENTER, 1.0)
	_active_boss = boss
	if boss != null and boss.has_method("apply_boss_scale"):
		boss.apply_boss_scale(_player_nodes.size())
		if int(_room_config.get("act", 1)) >= 2:
			boss.apply_room_modifier({"health_multiplier": 2.0})
		if RunState.is_endless_mode():
			var room_scale := 1.0 + float(max(_room_depth - 1, 0)) * 0.1
			boss.apply_room_modifier({"health_multiplier": room_scale})
	_spawn_boss_entrance_vfx()

func _roll_wave_enemy_type(pool: Array) -> String:
	if pool.is_empty():
		return "chaser"
	return str(pool[randi() % pool.size()])

func _get_room_duration() -> float:
	var base := 35.0
	if RunState.get_current_act() >= 2:
		base = 45.0
	if _room_type == "elite":
		base += 10.0
	if RunState.is_endless_mode() and _room_depth >= 20:
		base += 10.0
	return base

func _get_spawn_interval() -> float:
	var base := 0.7
	if RunState.get_current_act() >= 2:
		base = 0.5
	if _room_type == "elite":
		base -= 0.1
	if _room_depth >= 10:
		base -= 0.05
	if _room_depth >= 20:
		base -= 0.05
	return maxf(base, 0.25)

func _handle_room_clear() -> void:
	if _room_clear_started:
		return
	_room_clear_started = true
	_lock_player_input(true)
	_pending_clear_summary = _build_clear_summary()
	_show_progression_pick_if_needed()

func _show_progression_pick_if_needed() -> void:
	if RunState.get_pending_levelups() > 0:
		_pending_pick_consumes_levelup = true
		_show_mutation_pick(false, "Level Up", "Choose one mutation.")
		return
	if _room_type == "elite" and not _pending_elite_bonus_pick:
		_pending_elite_bonus_pick = true
		_pending_pick_consumes_levelup = false
		_show_mutation_pick(true, "Elite Reward", "Guaranteed rare pressure. Choose one mutation.")
		return
	_finish_room_progression()

func _show_mutation_pick(force_rare: bool, title: String, subtitle: String) -> void:
	if _mutation_pick_ui != null and is_instance_valid(_mutation_pick_ui):
		_mutation_pick_ui.queue_free()
	var options_by_player: Array = []
	for player_index in range(_player_nodes.size()):
		options_by_player.append(_mutation_system.roll_mutation_options(player_index, 3, _get_current_rare_chance(), force_rare))
	_mutation_pick_ui = MutationPickUIScene.instantiate()
	_mutation_pick_ui.configure_for_players(_player_configs, options_by_player, title, subtitle)
	_mutation_pick_ui.selections_confirmed.connect(_on_mutation_selections_confirmed)
	ui_layer.add_child(_mutation_pick_ui)
	_awaiting_mutation_pick = true

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
	if _pending_pick_consumes_levelup and _room_type == "elite" and not _pending_elite_bonus_pick:
		_pending_pick_consumes_levelup = false
		_pending_elite_bonus_pick = true
		_show_mutation_pick(true, "Elite Reward", "Guaranteed rare pressure. Choose one mutation.")
		return
	if not _pending_pick_consumes_levelup and _pending_elite_bonus_pick:
		_pending_elite_bonus_pick = false
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
			lines.append("Buff earned: %s" % _format_buff_name(str(_hold_buff_offer.get("type", ""))))
	return "\n".join(lines)

func _on_player_fire_requested(origin: Vector2, direction: Vector2, projectile_config: Dictionary) -> void:
	_cleanup_active_projectiles()
	if _active_projectiles.size() >= MAX_ACTIVE_PROJECTILES:
		return
	var split_extra_count := int(projectile_config.get("split_extra_count", 0))
	var spread_step := deg_to_rad(float(projectile_config.get("split_spread_degrees", 15.0)))
	var projectile_count: int = (1 + split_extra_count) * maxi(1, int(projectile_config.get("projectile_multiplier", 1)))
	var directions := _build_spread_directions(direction, projectile_count, spread_step)
	for projectile_direction in directions:
		if _active_projectiles.size() >= MAX_ACTIVE_PROJECTILES:
			return
		_activate_projectile("player", origin, projectile_direction, projectile_config)

func _on_player_ability_activated(player, _slot_index: int, ability_id: String, origin: Vector2, direction: Vector2, stats: Dictionary) -> void:
	var tint: Color = stats.get("color", Color.WHITE)
	_spawn_ability_activation_flash(origin, tint, ability_id)
	match ability_id:
		"shockwave":
			_spawn_player_shockwave(origin, stats)
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
			decoy.configure(float(stats.get("duration", 5.0)), tint, int(stats.get("decoy_health", 120)))
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

func _spawn_dash_effect(origin: Vector2, direction: Vector2, color: Color) -> void:
	var burst := ParticleFactoryData.create_dash_burst(color, direction, 1.0)
	burst.global_position = origin
	effects.add_child(burst)

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
	var mine_count := int(stats.get("mine_count", 5))
	var radius := float(stats.get("radius", 100.0))
	var trigger_radius := float(stats.get("trigger_radius", 52.0))
	var damage := int(stats.get("damage", 42))
	var duration := float(stats.get("duration", 8.0))
	var tint: Color = stats.get("color", Color.WHITE)
	for mine_index in range(mine_count):
		var angle := TAU * float(mine_index) / float(max(mine_count, 1))
		var mine := AbilityMineData.new()
		mine.global_position = origin + Vector2.RIGHT.rotated(angle) * (60.0 + float(mine_index % 2) * 24.0)
		mine.configure(duration, radius, damage, tint, trigger_radius)
		effects.add_child(mine)
		_active_mines.append(mine)

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

func _spawn_boss_entrance_vfx() -> void:
	if _screen_effects_enabled() and screen_shake != null and screen_shake.has_method("add_trauma"):
		screen_shake.add_trauma(0.55)
	_spawn_screen_flash(Color(0.82, 0.06, 0.04, 0.24), 0.5)
	var ring := ParticleFactoryData.create_explosion_ring(Color(1.0, 0.14, 0.08, 0.78), 260.0, 6.0)
	ring.global_position = ARENA_CENTER
	effects.add_child(ring)

func _spawn_elite_entrance_vfx(spawn_position: Vector2) -> void:
	if _screen_effects_enabled() and screen_shake != null and screen_shake.has_method("add_trauma"):
		screen_shake.add_trauma(0.22)
	var ring := ParticleFactoryData.create_explosion_ring(Color(1.0, 0.55, 0.18, 0.76), 190.0, 4.0)
	ring.global_position = spawn_position
	effects.add_child(ring)

func _spawn_enemy_death_global_vfx(enemy_type_name: String) -> void:
	if enemy_type_name.begins_with("boss_"):
		if _screen_effects_enabled() and screen_shake != null and screen_shake.has_method("add_trauma"):
			screen_shake.add_trauma(0.6)
		_spawn_screen_flash(Color(1.0, 1.0, 1.0, 0.18), 0.2)
	elif enemy_type_name.begins_with("elite_"):
		if _screen_effects_enabled() and screen_shake != null and screen_shake.has_method("add_trauma"):
			screen_shake.add_trauma(0.25)

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
	_cleanup_active_projectiles()
	if _active_projectiles.size() >= MAX_ACTIVE_PROJECTILES:
		return
	var projectile_color := ENEMY_PROJECTILE_COLOR
	_activate_projectile(team, origin, direction, {
		"speed": speed,
		"damage": damage,
		"color": projectile_color,
		"feedback_profile": "enemy",
		"impact_weight": projectile_scale,
		"collision_half_width": 6.0 * projectile_scale,
		"use_lifetime": true,
	})

func spawn_enemy_homing_orbs(origin: Vector2, count: int, speed: float, duration: float, damage: int, _color: Color) -> void:
	for index in range(count):
		var target: Node2D = _get_nearest_player_to(origin)
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / float(max(count, 1)))
		if target != null:
			direction = (target.global_position - origin).normalized()
		var projectile = ProjectileSceneData.instantiate()
		projectiles.add_child(projectile)
		projectile.impact_requested.connect(_on_projectile_impact)
		projectile.activate_from_config("enemy", direction, {
			"speed": speed,
			"damage": damage,
			"color": ENEMY_PROJECTILE_COLOR,
			"feedback_profile": "enemy",
			"impact_weight": 1.4,
			"collision_half_width": 12.0,
			"use_lifetime": true,
		}, origin + direction * 32.0)
		_active_homing_projectiles.append({
			"projectile": projectile,
			"target": target,
			"expires_at": _current_time_seconds() + duration,
		})

func _update_homing_projectiles(_delta: float) -> void:
	var now := _current_time_seconds()
	var kept: Array = []
	for entry_variant in _active_homing_projectiles:
		var entry := entry_variant as Dictionary
		var projectile = entry.get("projectile", null)
		if projectile == null or not is_instance_valid(projectile):
			continue
		if projectile.has_method("is_projectile_active") and not projectile.is_projectile_active():
			continue
		if now >= float(entry.get("expires_at", 0.0)):
			if projectile.has_method("_finish_projectile"):
				projectile._finish_projectile()
			else:
				projectile.queue_free()
			continue
		var target = entry.get("target", null)
		if target == null or not is_instance_valid(target) or not target.has_method("is_alive") or not target.is_alive():
			target = _get_nearest_player_to(projectile.global_position)
			entry["target"] = target
		if target != null and is_instance_valid(target):
			var desired: Vector2 = (target.global_position - projectile.global_position).normalized()
			if desired.length() > 0.0:
				projectile.direction = projectile.direction.lerp(desired, 0.08).normalized()
		kept.append(entry)
	_active_homing_projectiles = kept

func _activate_projectile(team: String, origin: Vector2, direction: Vector2, projectile_config: Dictionary) -> void:
	var projectile = _acquire_projectile()
	if projectile == null:
		return
	projectile.activate_from_config(team, direction, projectile_config, origin)
	if not _active_projectiles.has(projectile):
		_active_projectiles.append(projectile)

func _acquire_projectile():
	for projectile in _projectile_pool:
		if projectile != null and is_instance_valid(projectile) and projectile.has_method("is_projectile_active") and not projectile.is_projectile_active():
			return projectile
	if _projectile_pool.size() >= MAX_ACTIVE_PROJECTILES:
		return null
	var projectile = ProjectileSceneData.instantiate()
	projectile.set_pooled(true)
	projectile.impact_requested.connect(_on_projectile_impact)
	projectile.projectile_deactivated.connect(_on_projectile_deactivated)
	projectiles.add_child(projectile)
	_projectile_pool.append(projectile)
	return projectile

func _on_projectile_deactivated(projectile) -> void:
	_active_projectiles.erase(projectile)

func _cleanup_active_projectiles() -> void:
	var kept: Array = []
	for projectile in _active_projectiles:
		if projectile != null and is_instance_valid(projectile) and projectile.has_method("is_projectile_active") and projectile.is_projectile_active():
			kept.append(projectile)
	_active_projectiles = kept

func _on_projectile_impact(origin: Vector2, direction: Vector2, team: String, color: Color, _feedback_profile: String, impact_weight: float, target: Node, combat_context: Dictionary) -> void:
	var suppress_vfx := _should_suppress_combat_vfx()
	if not suppress_vfx:
		_spawn_projectile_hit_effect(origin, direction, color, impact_weight, target)
	if not suppress_vfx and int(combat_context.get("knockback_level", 0)) >= 2:
		var knockback_burst := ParticleFactoryData.create_impact_sparks(color.lightened(0.24), -direction.normalized() if direction.length() > 0.0 else Vector2.UP, impact_weight + 0.35)
		knockback_burst.global_position = origin
		effects.add_child(knockback_burst)
	var explosion_radius := float(combat_context.get("explosion_radius", 0.0))
	var explosion_damage := int(combat_context.get("explosion_damage", 0))
	if explosion_radius > 0.0 and explosion_damage > 0:
		if team == "player":
			for enemy in get_nearby_enemy_target_nodes(origin, explosion_radius):
				if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
					continue
				if enemy == target:
					continue
				if enemy.global_position.distance_squared_to(origin) <= explosion_radius * explosion_radius:
					enemy.apply_damage(explosion_damage)
		else:
			for player in _player_nodes:
				if player == null or not is_instance_valid(player) or not player.is_alive():
					continue
				if player.global_position.distance_to(origin) <= explosion_radius:
					player.apply_damage(explosion_damage)
		if not suppress_vfx:
			var ring := ParticleFactoryData.create_explosion_ring(color, explosion_radius, 3.0)
			ring.global_position = origin
			effects.add_child(ring)

func _spawn_projectile_hit_effect(origin: Vector2, direction: Vector2, color: Color, impact_weight: float, target: Node) -> void:
	var effect_color := color.lightened(0.2)
	if target != null and is_instance_valid(target) and target.has_method("get_feedback_color"):
		effect_color = target.get_feedback_color().lightened(0.12)
	var effect_direction := direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT
	var sparks := ParticleFactoryData.create_impact_sparks(effect_color, effect_direction, impact_weight)
	sparks.global_position = origin
	effects.add_child(sparks)
	if target != null and is_instance_valid(target) and not (target is StaticBody2D):
		var ring := ParticleFactoryData.create_impact_ring(effect_color, 18.0 + impact_weight * 8.0, 2.5 + impact_weight)
		ring.global_position = origin
		effects.add_child(ring)

func _should_suppress_combat_vfx() -> bool:
	_cleanup_active_projectiles()
	return _enemy_nodes.size() + _active_projectiles.size() >= COMBAT_VFX_LOAD_THRESHOLD

func _on_enemy_died(enemy) -> void:
	_enemy_nodes.erase(enemy)
	if enemy == _active_boss:
		_active_boss = null
	_enemies_killed += 1
	var enemy_type_name := str(enemy.get_type_name())
	_spawn_enemy_death_global_vfx(enemy_type_name)
	if enemy_type_name.begins_with("boss_"):
		RunState.add_xp(0)
	else:
		RunState.add_xp(int(XP_PER_ENEMY_TYPE.get(enemy_type_name, 10)))
	if not enemy_type_name.begins_with("boss_") and randf() < HEALTH_DROP_CHANCE:
		call_deferred("_spawn_health_pickup", enemy.global_position)
	if enemy_type_name == "splitter":
		for mini_index in range(3):
			var angle := TAU * float(mini_index) / 3.0
			_queue_boss_budgeted_enemy_spawn("splitter_mini", enemy.global_position + Vector2.RIGHT.rotated(angle) * 36.0)
	if _ice_zone_modifier != null and is_instance_valid(_ice_zone_modifier):
		_ice_zone_modifier.spawn_patch(enemy.global_position)
	if _side_objective_id == "kill_streak" and not _side_objective_completed:
		_kill_streak_progress += 1
		if _kill_streak_progress >= _kill_streak_target:
			_complete_side_objective()

func _on_enemy_hit_received(_enemy, _damage_amount: int, _lethal: bool) -> void:
	pass

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

func _on_player_damage_taken(player, _amount: int, _current_health: int) -> void:
	if player == null or not is_instance_valid(player):
		return
	if _side_objective_id == "kill_streak" and not _side_objective_completed:
		_kill_streak_progress = 0
	var burst := ParticleFactoryData.create_impact_sparks(player.player_config.tint.lightened(0.22), Vector2.UP, 1.1)
	burst.global_position = player.global_position
	effects.add_child(burst)

func _on_muzzle_flash_requested(origin: Vector2, direction: Vector2, color: Color, feedback_profile: String, impact_weight: float) -> void:
	var flash := ParticleFactoryData.create_muzzle_flash(color, direction, feedback_profile, impact_weight)
	flash.global_position = origin
	effects.add_child(flash)

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
	all_players_dead.emit()

func _refresh_hud() -> void:
	var xp_progress := RunState.get_xp_progress()
	var xp_ratio := clampf(float(xp_progress.get("current", 0)) / max(float(xp_progress.get("needed", 1)), 1.0), 0.0, 1.0)
	_xp_fill.scale = Vector2(max(xp_ratio, 0.01), 1.0)
	_xp_fill.anchor_right = xp_ratio
	_xp_label.text = "Lv %d  |  XP %d/%d  |  Pending Picks %d" % [
		int(xp_progress.get("level", 0)),
		int(xp_progress.get("current", 0)),
		int(xp_progress.get("needed", 80)),
		int(xp_progress.get("pending", 0)),
	]
	_room_label.text = _build_room_status_text()
	_objective_label.text = _build_side_objective_text()
	_refresh_objective_panel()
	_score_label.text = "Room %d" % max(_room_depth, RunState.get_current_score() + 1) if RunState.is_endless_mode() else ""
	_update_player_combat_indicators()
	_refresh_bottom_hud()

func _build_room_status_text() -> String:
	if RunState.is_endless_mode():
		return "Endless  |  Room %d  |  %s" % [_room_depth, _format_room_type()]
	if _room_type == "boss":
		return "%s  |  %s" % [_format_room_type(), _format_boss_type()]
	var time_left := maxf(_room_duration - _room_elapsed, 0.0)
	if _spawning_done:
		return "%s  |  %d remaining" % [_format_room_type(), _enemy_nodes.size()]
	return "%s  |  %ds  |  %d alive" % [_format_room_type(), int(ceil(time_left)), _enemy_nodes.size()]

func _format_room_type() -> String:
	match _room_type:
		"elite":
			return "Elite"
		"boss":
			return "Boss"
		_:
			return "Combat"

func _format_boss_type() -> String:
	var boss_type := str(_room_config.get("boss_type", ""))
	if boss_type.is_empty():
		return ""
	return boss_type.capitalize()

func _get_current_rare_chance() -> float:
	if RunState.is_endless_mode():
		return 0.30
	return 0.10 if RunState.get_current_act() <= 1 else 0.20

func _format_objective_text() -> String:
	if _side_objective_completed:
		return "Complete"
	match _side_objective_id:
		"hold_zone":
			return _hold_zone.get_progress_text() if _hold_zone != null and is_instance_valid(_hold_zone) else "Hold Zone"
		"kill_streak":
			return "Kill Streak %d/%d" % [_kill_streak_progress, _kill_streak_target]
		"collector":
			return "Collector %d/%d" % [_collector_collected, COLLECTOR_TARGET]
		_:
			return ""

func _build_side_objective_text() -> String:
	if _side_objective_id.is_empty():
		return ""
	if _side_objective_completed:
		return "Objective complete: %s Buff" % _format_buff_name(str(_hold_buff_offer.get("type", "")))
	match _side_objective_id:
		"hold_zone":
			return _hold_zone.get_progress_text() if _hold_zone != null and is_instance_valid(_hold_zone) else ""
		"kill_streak":
			return "Kill Streak: %d/%d" % [_kill_streak_progress, _kill_streak_target]
		"collector":
			return "Collector: %d/%d orbs" % [_collector_collected, COLLECTOR_TARGET]
		_:
			return ""

func _refresh_objective_panel() -> void:
	if _objective_panel == null:
		return
	var has_objective := not _side_objective_id.is_empty()
	_objective_panel.visible = has_objective
	if not has_objective:
		return
	_objective_icon_label.text = _get_objective_icon_text()
	_objective_title_label.text = _get_objective_title_text()
	_objective_progress_label.text = _build_side_objective_text()
	_objective_progress_bar.value = _get_objective_progress_ratio() * 100.0

func _get_objective_icon_text() -> String:
	match _side_objective_id:
		"hold_zone":
			return "H"
		"kill_streak":
			return "K"
		"collector":
			return "C"
		_:
			return "!"

func _get_objective_title_text() -> String:
	if _side_objective_completed:
		return "Objective Complete"
	match _side_objective_id:
		"hold_zone":
			return "Hold Zone"
		"kill_streak":
			return "Kill Streak"
		"collector":
			return "Collect"
		_:
			return "Objective"

func _get_objective_progress_ratio() -> float:
	if _side_objective_completed:
		return 1.0
	match _side_objective_id:
		"hold_zone":
			return _hold_zone.get_progress_ratio() if _hold_zone != null and is_instance_valid(_hold_zone) and _hold_zone.has_method("get_progress_ratio") else 0.0
		"kill_streak":
			return clampf(float(_kill_streak_progress) / maxf(float(_kill_streak_target), 1.0), 0.0, 1.0)
		"collector":
			return clampf(float(_collector_collected) / float(COLLECTOR_TARGET), 0.0, 1.0)
		_:
			return 0.0

func _update_player_combat_indicators() -> void:
	for index in range(min(_player_combat_indicators.size(), _player_nodes.size())):
		var player = _player_nodes[index]
		var health_state: Dictionary = player.get_health_state()
		var slot_1_hud_data: Dictionary = player.get_ability_hud_data(0)
		var slot_2_hud_data: Dictionary = player.get_ability_hud_data(1)
		_player_combat_indicators[index].update_state(
			int(health_state.get("current", 0)),
			int(health_state.get("max", 1)),
			player.is_downed(),
			float(slot_1_hud_data.get("cooldown_remaining", 0.0)),
			float(slot_1_hud_data.get("cooldown_duration", 1.0)),
			float(slot_2_hud_data.get("cooldown_remaining", 0.0)),
			float(slot_2_hud_data.get("cooldown_duration", 1.0)),
			str(slot_1_hud_data.get("name", "")),
			str(slot_2_hud_data.get("name", ""))
		)

func _refresh_bottom_hud() -> void:
	for index in range(min(_bottom_player_hud_cards.size(), _player_nodes.size())):
		var card: Dictionary = _bottom_player_hud_cards[index]
		var player = _player_nodes[index]
		var health_state: Dictionary = player.get_health_state()
		var slot_1_hud_data: Dictionary = player.get_ability_hud_data(0)
		var slot_2_hud_data: Dictionary = player.get_ability_hud_data(1)
		var health_ratio := clampf(float(health_state.get("current", 0)) / maxf(float(health_state.get("max", 1)), 1.0), 0.0, 1.0)
		var slot_1_ratio := 1.0
		var slot_2_ratio := 1.0
		var slot_1_duration := maxf(float(slot_1_hud_data.get("cooldown_duration", 1.0)), 0.01)
		var slot_2_duration := maxf(float(slot_2_hud_data.get("cooldown_duration", 1.0)), 0.01)
		slot_1_ratio = 1.0 - clampf(float(slot_1_hud_data.get("cooldown_remaining", 0.0)) / slot_1_duration, 0.0, 1.0)
		slot_2_ratio = 1.0 - clampf(float(slot_2_hud_data.get("cooldown_remaining", 0.0)) / slot_2_duration, 0.0, 1.0)
		(card.get("health_bar") as ProgressBar).value = health_ratio * 100.0
		(card.get("slot_1_label") as Label).text = str(slot_1_hud_data.get("name", "Ability 1"))
		(card.get("slot_1_bar") as ProgressBar).value = slot_1_ratio * 100.0
		(card.get("slot_2_label") as Label).text = str(slot_2_hud_data.get("name", "Ability 2"))
		(card.get("slot_2_bar") as ProgressBar).value = slot_2_ratio * 100.0

func _update_player_combat_indicator_positions() -> void:
	if _player_combat_indicators.is_empty():
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
	for index in range(min(_player_combat_indicators.size(), _player_nodes.size())):
		var indicator = _player_combat_indicators[index]
		var player = _player_nodes[index]
		if indicator == null or not is_instance_valid(indicator) or player == null or not is_instance_valid(player):
			continue
		var screen_position: Vector2 = (canvas_transform * player.global_position).round()
		var indicator_size: Vector2 = indicator.custom_minimum_size
		var top_left := screen_position + Vector2(-indicator_size.x * 0.5, -20.0)
		top_left.x = clampf(top_left.x, 8.0, viewport_size.x - indicator_size.x - 8.0)
		top_left.y = clampf(top_left.y, 8.0, viewport_size.y - indicator_size.y - 8.0)
		indicator.position = top_left.round()

func _populate_modifier_hud() -> void:
	if _modifier_hud == null:
		return
	for child in _modifier_hud.get_children():
		child.queue_free()
	for mod_id_variant in _active_modifiers:
		var mod_id := str(mod_id_variant)
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(0.0, 28.0)
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
		chip.add_child(lbl)
		_modifier_hud.add_child(chip)

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

func _get_modifier_chip_color(mod_id: String) -> Color:
	var category := str((_modifier_definitions.get(mod_id, {}) as Dictionary).get("category", "minor"))
	return Color(0.86, 0.32, 0.22, 0.62) if category == "major" else Color(0.9, 0.68, 0.22, 0.62)

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
		_queue_boss_budgeted_enemy_spawn(enemy_type, origin + Vector2.RIGHT.rotated(angle) * 96.0)

func spawn_enemy_minion_mix(origin: Vector2, count: int, types: Array) -> void:
	if types.is_empty():
		return
	for index in range(count):
		var enemy_type := str(types[index % types.size()])
		var angle := TAU * float(index) / float(max(count, 1))
		_queue_boss_budgeted_enemy_spawn(enemy_type, origin + Vector2.RIGHT.rotated(angle) * 112.0)

func spawn_boss_deflector_minions(origin: Vector2, count: int) -> Array:
	var shield_nodes: Array = []
	for index in range(count):
		if _room_type == "boss" and _boss_add_dry_run_enabled and _get_boss_add_budget_remaining() <= 0:
			break
		var angle := TAU * float(index) / float(max(count, 1))
		var node := _spawn_enemy_instance("splitter_mini", origin + Vector2.RIGHT.rotated(angle) * 150.0, 3.75)
		if node != null:
			shield_nodes.append(node)
	return shield_nodes

func spawn_hive_shield_minions(origin: Vector2, count: int) -> Array:
	return spawn_boss_deflector_minions(origin, count)

func spawn_pulsar_emp(origin: Vector2, lockout_seconds: float, color: Color) -> void:
	for player in _player_nodes:
		if player != null and is_instance_valid(player) and player.has_method("apply_ability_lockout"):
			player.apply_ability_lockout(lockout_seconds)
	spawn_enemy_shockwave(origin, 520.0, 0, 420.0, color, false)
	_spawn_screen_flash(Color(color.r, color.g, color.b, 0.18), 0.22)

func spawn_pulsar_beam(origin: Vector2, direction: Vector2, color: Color, damage: int) -> void:
	var normalized := direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT
	_active_beams.append({
		"origin": origin,
		"start_angle": normalized.angle() - deg_to_rad(45.0),
		"elapsed": 0.0,
		"duration": 1.5,
		"arc": deg_to_rad(90.0),
		"damage": damage,
		"color": color,
		"hit_players": [],
		"next_visual_at": 0.0,
	})
	_draw_beam_line(origin, normalized, color)

func _update_active_beams(delta: float) -> void:
	if _active_beams.is_empty():
		return
	var kept: Array = []
	for beam_variant in _active_beams:
		var beam := beam_variant as Dictionary
		var elapsed := float(beam.get("elapsed", 0.0)) + delta
		beam["elapsed"] = elapsed
		var duration := maxf(float(beam.get("duration", 1.5)), 0.01)
		if elapsed > duration:
			continue
		var origin: Vector2 = beam.get("origin", Vector2.ZERO)
		var angle := float(beam.get("start_angle", 0.0)) + float(beam.get("arc", 0.0)) * clampf(elapsed / duration, 0.0, 1.0)
		var direction := Vector2.RIGHT.rotated(angle)
		var color: Color = beam.get("color", Color.WHITE)
		if _room_elapsed >= float(beam.get("next_visual_at", 0.0)):
			beam["next_visual_at"] = _room_elapsed + 0.08
			_draw_beam_line(origin, direction, color)
		var hit_players: Array = beam.get("hit_players", []) as Array
		for player in _player_nodes:
			if player == null or not is_instance_valid(player) or not player.has_method("is_alive") or not player.is_alive():
				continue
			if hit_players.has(player):
				continue
			var offset: Vector2 = player.global_position - origin
			if offset.length() > 1500.0:
				continue
			var angle_delta: float = abs(angle_difference(direction.angle(), offset.angle()))
			if angle_delta <= deg_to_rad(5.0):
				player.apply_damage(int(beam.get("damage", 25)))
				hit_players.append(player)
		beam["hit_players"] = hit_players
		kept.append(beam)
	_active_beams = kept

func _draw_beam_line(origin: Vector2, direction: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.width = 18.0
	line.default_color = Color(color.r, color.g, color.b, 0.64)
	line.points = PackedVector2Array([origin, origin + direction.normalized() * 1500.0])
	effects.add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.14)
	tween.tween_callback(line.queue_free)

func spawn_enemy_burst(origin: Vector2, count: int, phase: float) -> void:
	for index in range(count):
		var enemy_type := "chaser"
		if phase >= 0.33 and index % 3 == 0:
			enemy_type = "charger"
		if phase >= 0.66 and index % 4 == 0:
			enemy_type = "spitter"
		var angle := TAU * float(index) / float(max(count, 1))
		_queue_boss_budgeted_enemy_spawn(enemy_type, origin + Vector2.RIGHT.rotated(angle) * 160.0)

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

func _get_nearest_player_to(origin: Vector2):
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

func get_enemy_target_nodes() -> Array:
	return _enemy_nodes

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
	return ARENA_CENTER + Vector2((index % 2) * 160.0 - 80.0, floor(index / 2.0) * 120.0 - 60.0)

func _get_boss_room_player_spawn_position(index: int) -> Vector2:
	var player_count := maxi(_player_nodes.size(), _player_configs.size())
	var horizontal_spacing := 180.0
	var center_offset := (float(index) - (float(maxi(player_count, 1)) - 1.0) * 0.5) * horizontal_spacing
	return Vector2(
		clampf(ARENA_CENTER.x + center_offset, ARENA_RECT.position.x + 220.0, ARENA_RECT.end.x - 220.0),
		clampf(ARENA_CENTER.y + BOSS_PLAYER_SPAWN_DISTANCE, ARENA_RECT.position.y + 220.0, ARENA_RECT.end.y - 220.0)
	)

func _get_enemy_spawn_position() -> Vector2:
	var inner_margin := ARENA_MARGIN + 48.0
	var edge := randi() % 4
	return _get_enemy_spawn_position_for_edge(edge, inner_margin)

func _get_elite_spawn_position() -> Vector2:
	var best_position := _get_enemy_spawn_position()
	var best_distance_sq := -1.0
	for attempt in range(12):
		var candidate := _get_enemy_spawn_position_for_index(attempt, randi() % 4)
		var min_distance_sq := INF
		for player_index in range(maxi(_player_configs.size(), 1)):
			var spawn_position := ARENA_CENTER + Vector2((player_index % 2) * 160.0 - 80.0, floor(player_index / 2.0) * 120.0 - 60.0)
			min_distance_sq = minf(min_distance_sq, candidate.distance_squared_to(spawn_position))
		if min_distance_sq >= 600.0 * 600.0:
			return candidate
		if min_distance_sq > best_distance_sq:
			best_distance_sq = min_distance_sq
			best_position = candidate
	return best_position

func _get_enemy_spawn_position_for_index(spawn_index: int, start_edge: int) -> Vector2:
	var inner_margin := ARENA_MARGIN + 48.0
	var edge := (start_edge + spawn_index) % 4
	return _get_enemy_spawn_position_for_edge(edge, inner_margin)

func _get_enemy_spawn_position_for_edge(edge: int, inner_margin: float) -> Vector2:
	match edge:
		0:
			return Vector2(randf_range(inner_margin, ARENA_SIZE.x - inner_margin), inner_margin + randf_range(0.0, 60.0))
		1:
			return Vector2(randf_range(inner_margin, ARENA_SIZE.x - inner_margin), ARENA_SIZE.y - inner_margin - randf_range(0.0, 60.0))
		2:
			return Vector2(inner_margin + randf_range(0.0, 60.0), randf_range(inner_margin, ARENA_SIZE.y - inner_margin))
		_:
			return Vector2(ARENA_SIZE.x - inner_margin - randf_range(0.0, 60.0), randf_range(inner_margin, ARENA_SIZE.y - inner_margin))

func _build_spread_directions(base_direction: Vector2, projectile_count: int, spread_step: float) -> Array:
	var normalized := base_direction.normalized() if base_direction.length() > 0.0 else Vector2.RIGHT
	if projectile_count <= 1 or spread_step <= 0.0:
		return [normalized]
	var directions: Array = [normalized]
	var extras := projectile_count - 1
	for index in range(1, extras + 1):
		var side := 1 if index % 2 == 1 else -1
		var rank := int(ceil(float(index) / 2.0))
		directions.append(normalized.rotated(spread_step * float(rank) * float(side)))
	return directions

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

func _unhandled_input(event: InputEvent) -> void:
	if _awaiting_mutation_pick:
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
		var weapon: Dictionary = RunState.get_weapon(player_index)
		var weapon_stats: Dictionary = weapon.get("stats", {}) as Dictionary
		var weapon_label := Label.new()
		var projectile_count := int(weapon_stats.get("projectile_count", 1))
		var projectile_text := " x %d" % projectile_count if projectile_count > 1 else ""
		weapon_label.text = "%s - %d dmg @ %.1f/s%s" % [
			str(weapon.get("name", "Rifle")),
			int(round(float(weapon_stats.get("damage", 16.0)))),
			float(weapon_stats.get("fire_rate", 4.0)),
			projectile_text,
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
				"description": str(mutation_dict.get("description", "")),
			}
		if counts.is_empty():
			var empty_label := Label.new()
			empty_label.text = "  No mutations yet"
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
	var slot_color := _get_slot_color(player_tint, slot_index)
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
	var rarity_color := Color(1.0, 0.78, 0.32, 1.0) if rarity == "rare" else Color(0.48, 0.74, 1.0, 1.0)
	var chip := PanelContainer.new()
	chip.tooltip_text = str(entry.get("description", ""))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.18 if rarity == "rare" else 0.14)
	style.border_color = rarity_color
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
	var level_text := " Lv%d" % int(entry.get("count", 1)) if int(entry.get("count", 1)) > 1 and rarity != "rare" else ""
	label.text = "%s%s" % [str(entry.get("name", "")), level_text]
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", rarity_color.lightened(0.18))
	margin.add_child(label)
	return chip

func _compare_mutation_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_rarity_score := 0 if str(left.get("rarity", "common")) == "rare" else 1
	var right_rarity_score := 0 if str(right.get("rarity", "common")) == "rare" else 1
	if left_rarity_score != right_rarity_score:
		return left_rarity_score < right_rarity_score
	return str(left.get("name", "")).naturalnocasecmp_to(str(right.get("name", ""))) < 0

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _invalidate_runtime_caches() -> void:
	pass
