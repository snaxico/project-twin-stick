extends Node2D

const PlayerConfigData = preload("res://scripts/player/PlayerConfig.gd")
const ModifierEngineData = preload("res://scripts/game/ModifierEngine.gd")
const ScreenShakeData = preload("res://scripts/juice/ScreenShake.gd")
const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")
const FloatingTextData = preload("res://scripts/juice/FloatingText.gd")
const HealthBarHUDData = preload("res://scripts/juice/HealthBarHUD.gd")
@export var player_scene: PackedScene
@export var enemy_scene: PackedScene
@export var projectile_scene: PackedScene
@export var grenade_projectile_scene: PackedScene
@export var survival_duration: float = 30.0
@export var enemy_spawn_interval: float = 4.0
@export var modifier_intro_duration: float = 1.8
@export var revive_radius: float = 92.0
@export var revive_hold_duration: float = 1.4
@export var revive_health: int = 2
@export var boss_support_spawn_interval: float = 8.0

signal room_cleared(health_states)
signal all_players_dead
signal player_downed(player)
signal player_revived(player)

@onready var players: Node2D = $Players
@onready var projectiles: Node2D = $Projectiles
@onready var enemies: Node2D = $Enemies
@onready var effects: Node2D = $Effects
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

var _player_nodes: Array = []
var _player_configs: Array = [
	PlayerConfigData.new(1, "hybrid", Color(0.2, 0.85, 0.2, 1.0), PlayerConfigData.AimMode.HEAVY_AUTO),
	PlayerConfigData.new(2, "hybrid", Color(0.2, 0.45, 1.0, 1.0), PlayerConfigData.AimMode.FULL_AUTO),
	PlayerConfigData.new(3, "gamepad", Color(0.95, 0.82, 0.22, 1.0), PlayerConfigData.AimMode.FULL_AUTO),
	PlayerConfigData.new(4, "gamepad", Color(1.0, 0.56, 0.2, 1.0), PlayerConfigData.AimMode.FULL_AUTO),
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
var _room_config: Dictionary = {}
var _boss_node = null
var _revive_progress_by_player_id: Dictionary = {}
var _status_labels: Array = []
var _secondary_labels: Array = []
var _hitstop_serial: int = 0
var _sfx_engine = null
var _hud_root: Control = null
var _floating_text_layer: Control = null
var _player_health_bars: Array = []
var _boss_health_bar = null
var _survival_spawn_warning_pending := false
var _boss_support_warning_pending := false
var _pending_survival_wave_plan: Array = []
var _pending_boss_support_plan: Array = []
var _pending_warning_effects: Array = []

func _ready() -> void:
	if player_scene == null:
		player_scene = load("res://scenes/player/Player.tscn")
	if enemy_scene == null:
		enemy_scene = load("res://scenes/enemies/Enemy.tscn")
	if projectile_scene == null:
		projectile_scene = load("res://scenes/weapons/Projectile.tscn")
	if grenade_projectile_scene == null:
		grenade_projectile_scene = load("res://scenes/weapons/GrenadeProjectile.tscn")
	_modifier_engine = ModifierEngineData.new()
	_sfx_engine = get_tree().get_first_node_in_group("sfx_engine")
	_status_labels = [p1_status_label, p2_status_label, p3_status_label, p4_status_label]
	_secondary_labels = [p1_secondary_label, p2_secondary_label, p3_secondary_label, p4_secondary_label]
	_build_hud()

	_is_initialized = true
	_spawn_players()
	_start_room()
	p1_mode_button.pressed.connect(_on_p1_mode_button_pressed)
	p2_mode_button.pressed.connect(_on_p2_mode_button_pressed)
	retry_button.pressed.connect(_on_retry_button_pressed)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_refresh_debug_ui()

func _process(delta: float) -> void:
	_refresh_debug_ui()
	_update_room_progress(delta)
	_update_screen_effects()

func _spawn_players() -> void:
	_clear_container(players)
	_player_nodes.clear()

	var spawn_points := [
		player_1_spawn.global_position,
		player_2_spawn.global_position,
		player_3_spawn.global_position,
		player_4_spawn.global_position,
	]
	var assigned_gamepads := _assign_gamepads(_player_configs)

	for index in range(_player_configs.size()):
		var player = player_scene.instantiate()
		player.global_position = spawn_points[index]
		player.setup(_player_configs[index], assigned_gamepads[index])
		player.apply_loadout(RunState.get_player_runtime_loadout())
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
		players.add_child(player)
		_play_player_spawn_in(player)
		_player_nodes.append(player)
	_refresh_player_health_bars()

func _refresh_debug_ui() -> void:
	for index in range(_status_labels.size()):
		var status_label: Label = _status_labels[index]
		var secondary_label: Label = _secondary_labels[index]
		var has_player := index < _player_nodes.size()
		status_label.visible = has_player
		secondary_label.visible = has_player
		if has_player:
			status_label.text = _build_player_status_text(_player_nodes[index])
			secondary_label.text = _build_secondary_status_text(_player_nodes[index])

	p2_mode_button.visible = _player_nodes.size() >= 2

	var connected_devices: Array = Input.get_connected_joypads()
	if connected_devices.is_empty():
		connection_status_label.text = "Gamepads: none connected. Keyboard fallback active for P1 and P2."
	else:
		connection_status_label.text = "Gamepads: %s" % connected_devices
	modifier_status_label.text = _build_modifier_status_text()
	_refresh_player_health_bars()
	_refresh_boss_health_bar()

func _build_player_status_text(player) -> String:
	var dash_state := "Downed" if player.is_downed() else ("Dashing" if player.is_dash_active() else "Ready")
	if not player.is_downed() and not player.is_dash_active():
		var cooldown: float = player.get_dash_cooldown_remaining()
		dash_state = "Cooldown %.1fs" % cooldown if cooldown > 0.0 else "Ready"

	return "P%d  Control: %s  Aim: %s  Dash: %s" % [
		player.player_id,
		player.player_config.get_control_source_name(),
		"%s | %s" % [player.get_primary_profile_name(), player.get_aim_mode_name()],
		dash_state,
	]

func _build_secondary_status_text(player) -> String:
	if player.is_downed():
		return "P%d Secondary: Downed" % player.player_id
	var remaining: float = player.get_secondary_cooldown_remaining()
	if remaining > 0.0:
		return "P%d Secondary: %s | Cooldown %.1fs" % [player.player_id, player.get_secondary_profile_name(), remaining]
	return "P%d Secondary: Ready (%s)" % [player.player_id, player.get_secondary_profile_name()]

func _build_modifier_status_text() -> String:
	if _is_boss_room():
		return "Boss Room: %s" % str(_room_config.get("title", "Boss"))
	if _active_modifier.is_empty():
		return "Modifier: None"
	return "Modifier: %s | %s" % [
		str(_active_modifier.get("name", "Unknown")),
		str(_active_modifier.get("description", "")),
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
	_refresh_debug_ui()

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
	_active_modifier = {} if _is_boss_room() else _room_config.get("modifier", _modifier_engine.get_random_modifier()).duplicate(true)
	_clear_container(projectiles)
	_clear_container(enemies)
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

func _spawn_room_opening_encounter() -> void:
	if _is_boss_room():
		_spawn_boss()
	else:
		_spawn_survival_wave(_build_survival_wave_plan())

func _build_survival_wave_plan() -> Array:
	var spawn_points := _get_enemy_spawn_positions()
	var enemy_types := ["chaser", "spitter", "charger", "chaser", "spitter", "charger"]
	var spawn_count := clampi(4 + max(_player_nodes.size() - 1, 0), 4, enemy_types.size())
	var plan: Array = []

	for index in range(spawn_count):
		var spawn_index := (_survival_wave_index * spawn_count + index) % spawn_points.size()
		plan.append({
			"position": spawn_points[spawn_index],
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
	boss.enemy_died.connect(_on_enemy_died)
	boss.hit_received.connect(_on_enemy_hit_received)
	boss.fire_requested.connect(_on_enemy_fire_requested)
	enemies.add_child(boss)
	_boss_node = boss

func _build_boss_support_wave_plan() -> Array:
	var spawn_points := _get_enemy_spawn_positions()
	var support_count := 2 if _player_nodes.size() <= 2 else 3
	var support_types := ["spitter", "charger", "chaser"]
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
				_modifier_engine.get_death_explosion_radius(_active_modifier),
				_modifier_engine.get_death_explosion_damage(_active_modifier),
				_modifier_engine.get_enemy_contact_damage_bonus(_active_modifier)
			)
		enemy.enemy_died.connect(_on_enemy_died)
		enemy.hit_received.connect(_on_enemy_hit_received)
		enemy.fire_requested.connect(_on_enemy_fire_requested)
		enemies.add_child(enemy)

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func _on_player_fire_requested(origin: Vector2, direction: Vector2, speed: float, damage: int, team: String) -> void:
	if _room_is_cleared or _room_is_failed:
		return
	_spawn_projectile(origin, direction, speed, damage, team)

func _on_player_secondary_requested(origin: Vector2, direction: Vector2, speed: float, damage: int, team: String, projectile_data: Dictionary) -> void:
	if _room_is_cleared or _room_is_failed:
		return

	match str(projectile_data.get("kind", "grenade")):
		"grenade":
			_spawn_grenade(origin, direction, speed, damage, team, projectile_data)
		_:
			_spawn_projectile(origin, direction, speed, damage, team)

func _on_enemy_fire_requested(origin: Vector2, direction: Vector2, speed: float, damage: int, team: String) -> void:
	if _room_is_cleared or _room_is_failed:
		return
	_spawn_projectile(origin, direction, speed, damage, team)

func _spawn_projectile(origin: Vector2, direction: Vector2, speed: float, damage: int, team: String) -> void:
	var projectile = projectile_scene.instantiate()
	projectile.global_position = origin
	projectile.setup(team, direction, speed, damage)
	projectile.impact_requested.connect(_on_projectile_impact_requested)
	projectiles.add_child(projectile)

func _spawn_grenade(origin: Vector2, direction: Vector2, speed: float, damage: int, team: String, projectile_data: Dictionary) -> void:
	var grenade = grenade_projectile_scene.instantiate()
	grenade.global_position = origin
	grenade.setup(team, direction, speed, damage)
	grenade.kind = str(projectile_data.get("kind", grenade.kind))
	grenade.explosion_radius = float(projectile_data.get("explosion_radius", grenade.explosion_radius))
	grenade.fuse_time = float(projectile_data.get("fuse_time", grenade.fuse_time))
	grenade.gravity_force = float(projectile_data.get("gravity_force", grenade.gravity_force))
	grenade.pulse_count = int(projectile_data.get("pulse_count", grenade.pulse_count))
	grenade.pulse_interval = float(projectile_data.get("pulse_interval", grenade.pulse_interval))
	grenade.cluster_blast_count = int(projectile_data.get("cluster_blast_count", grenade.cluster_blast_count))
	grenade.cluster_spread_radius = float(projectile_data.get("cluster_spread_radius", grenade.cluster_spread_radius))
	grenade.exploded.connect(_on_grenade_exploded)
	projectiles.add_child(grenade)

func _on_enemy_died(enemy) -> void:
	_trigger_hitstop(0.04)
	_add_camera_trauma(0.3)
	_play_sfx_enemy_death()
	_spawn_world_effect(
		ParticleFactoryData.create_death_burst(Color(1.0, 0.28, 0.28, 1.0)),
		enemy.global_position
	)
	if _is_boss_room() and enemy != null and enemy.has_method("is_boss") and enemy.is_boss():
		_boss_node = null
		_handle_room_clear("Boss Defeated", "The boss collapsed and the run can continue.")
		return
	call_deferred("_evaluate_room_state")

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

func _on_grenade_exploded(_origin: Vector2) -> void:
	_play_sfx_explosion()
	_spawn_world_effect(
		ParticleFactoryData.create_explosion_burst(Color(1.0, 0.7, 0.28, 1.0)),
		_origin
	)
	_play_zoom_punch(0.06, 0.05, 0.12)

func _on_player_muzzle_flash_requested(origin: Vector2, direction: Vector2, color: Color) -> void:
	_play_sfx_fire()
	_spawn_world_effect(ParticleFactoryData.create_muzzle_flash(color, direction), origin)

func _on_player_dash_trail_requested(origin: Vector2, color: Color) -> void:
	_spawn_world_effect(ParticleFactoryData.create_dash_trail(color.darkened(0.15)), origin)

func _on_player_dash_started(_origin: Vector2) -> void:
	_play_sfx_dash()

func _on_enemy_hit_received(enemy, damage_amount: int, _lethal: bool) -> void:
	_play_sfx_hit()
	if enemy != null and is_instance_valid(enemy):
		_spawn_world_floating_text("-%d" % damage_amount, Color(1.0, 0.85, 0.7, 1.0), enemy.global_position + Vector2(0.0, -36.0))

func _on_projectile_impact_requested(origin: Vector2, direction: Vector2, team: String) -> void:
	var color := Color(1.0, 0.88, 0.48, 1.0) if team == "player" else Color(1.0, 0.48, 0.48, 1.0)
	_spawn_world_effect(ParticleFactoryData.create_impact_sparks(color, direction), origin)

func _evaluate_room_state() -> void:
	if _room_is_failed or _room_is_cleared:
		return

	if get_active_players().is_empty():
		_room_is_failed = true
		_reset_room_status_pulse()
		room_status_label.text = "Room status: All players down"
		_clear_container(projectiles)
		_clear_container(enemies)
		var defeat_text := "All players were downed before the timer expired."
		if _is_boss_room():
			defeat_text = "All players were downed before the boss was defeated."
		_show_result("Defeat", defeat_text)
		all_players_dead.emit()

func _update_room_progress(delta: float) -> void:
	if _room_is_cleared or _room_is_failed:
		return

	var now := _current_time_seconds()
	if _room_is_in_intro:
		var intro_remaining: float = max(_room_intro_ends_at - now, 0.0)
		var intro_label := str(_room_config.get("title", "Room")) if _is_boss_room() else str(_active_modifier.get("name", "Modifier"))
		room_status_label.text = "Room status: %s in %.1fs" % [intro_label, intro_remaining]
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

	_apply_stationary_modifier(now)

	room_status_label.text = "Room status: Survive %.1fs | Enemies: %d%s" % [
		remaining,
		enemies.get_child_count(),
		_build_revive_status_suffix(),
	]
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
	_clear_container(projectiles)
	_clear_container(enemies)
	_clear_spawn_warning_effects()
	if _boss_node != null and is_instance_valid(_boss_node):
		_boss_node = null
	room_status_label.text = "Room status: %s" % title
	_reset_room_status_pulse()
	_play_sfx_room_clear()
	var gold_gain := int(_room_config.get("currency_reward", 0))
	if gold_gain > 0:
		_spawn_screen_floating_text("+%d Gold" % gold_gain, Color(1.0, 0.88, 0.28, 1.0), Vector2(860.0, 120.0))
	_play_clear_juice()
	_show_result(title, detail)
	room_cleared.emit(capture_player_health_states())

func _show_result(title: String, detail: String) -> void:
	result_title_label.text = title
	result_detail_label.text = detail
	result_panel.visible = true

func _show_room_intro() -> void:
	if _is_boss_room():
		modifier_intro_title_label.text = "Incoming Boss: %s" % str(_room_config.get("title", "Boss"))
		modifier_intro_detail_label.text = str(_room_config.get("description", "Defeat the boss to finish the run."))
	else:
		modifier_intro_title_label.text = "Incoming Modifier: %s" % str(_active_modifier.get("name", "Unknown"))
		modifier_intro_detail_label.text = str(_active_modifier.get("description", ""))
	modifier_intro_panel.visible = true

func _apply_modifier_visuals() -> void:
	if modifier_tint == null:
		return

	var target_color := Color(1.0, 1.0, 1.0, 1.0)
	if _is_boss_room():
		target_color = Color(1.0, 1.0, 1.0, 1.0)
	else:
		var tint: Color = _modifier_engine.get_tint_color(_active_modifier)
		target_color = tint.darkened(0.3)

	var tween := create_tween()
	tween.tween_property(modifier_tint, "color", target_color, 0.28)

func _get_spawn_interval() -> float:
	var base_interval := float(_room_config.get("enemy_spawn_interval", enemy_spawn_interval))
	return base_interval * _modifier_engine.get_spawn_interval_multiplier(_active_modifier)

func _apply_stationary_modifier(now: float) -> void:
	var stationary_interval: float = _modifier_engine.get_stationary_damage_interval(_active_modifier)
	if stationary_interval <= 0.0 or now < _stationary_damage_next_tick_at:
		return

	_stationary_damage_next_tick_at = now + stationary_interval
	for player in get_active_players():
		if not is_instance_valid(player):
			continue
		if player.velocity.length() <= 10.0:
			player.apply_damage(1)

func handle_enemy_death_explosion(origin: Vector2, radius: float, damage: int) -> void:
	for player in get_active_players():
		if not is_instance_valid(player):
			continue
		if player.global_position.distance_to(origin) <= radius:
			player.apply_damage(damage)

func _on_retry_button_pressed() -> void:
	Engine.time_scale = 1.0
	_clear_spawn_warning_effects()
	_spawn_players()
	_start_room()
	_refresh_debug_ui()

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _restore_player_health_states() -> void:
	if RunState.player_health_states.size() == 0:
		return

	for index in range(min(_player_nodes.size(), RunState.player_health_states.size())):
		var player = _player_nodes[index]
		if is_instance_valid(player):
			player.set_health_state(RunState.player_health_states[index])

func _is_boss_room() -> bool:
	return str(_room_config.get("room_type", "")) == "boss"

func _get_enemy_spawn_positions() -> Array:
	return [
		enemy_spawn_1.global_position,
		enemy_spawn_2.global_position,
		enemy_spawn_3.global_position,
		enemy_spawn_4.global_position,
		enemy_spawn_5.global_position,
		enemy_spawn_6.global_position,
	]

func _apply_layout_preset(layout_id: String) -> void:
	const MAP_SCALE := 1.15
	var floor_points: PackedVector2Array = PackedVector2Array([
		Vector2(120, 84),
		Vector2(1160, 84),
		Vector2(1260, 668),
		Vector2(20, 668),
	])
	var back_wall_points: PackedVector2Array = PackedVector2Array([
		Vector2(120, 58),
		Vector2(1160, 58),
		Vector2(1160, 106),
		Vector2(120, 106),
	])
	var left_wall_points: PackedVector2Array = PackedVector2Array([
		Vector2(92, 84),
		Vector2(120, 84),
		Vector2(20, 668),
		Vector2(-8, 668),
	])
	var right_wall_points: PackedVector2Array = PackedVector2Array([
		Vector2(1160, 84),
		Vector2(1188, 84),
		Vector2(1288, 668),
		Vector2(1260, 668),
	])
	var camera_zoom := Vector2(0.8, 0.8)
	var player_positions := [
		Vector2(470, 380),
		Vector2(810, 380),
		Vector2(470, 470),
		Vector2(810, 470),
	]
	var enemy_positions := [
		Vector2(280, 200),
		Vector2(1000, 200),
		Vector2(220, 570),
		Vector2(1060, 570),
		Vector2(640, 160),
		Vector2(640, 610),
	]

	match layout_id:
		"crossfire":
			floor_points = PackedVector2Array([
				Vector2(80, 96),
				Vector2(1200, 96),
				Vector2(1240, 660),
				Vector2(40, 660),
			])
			back_wall_points = PackedVector2Array([
				Vector2(80, 70),
				Vector2(1200, 70),
				Vector2(1200, 118),
				Vector2(80, 118),
			])
			left_wall_points = PackedVector2Array([
				Vector2(52, 96),
				Vector2(80, 96),
				Vector2(40, 660),
				Vector2(12, 660),
			])
			right_wall_points = PackedVector2Array([
				Vector2(1200, 96),
				Vector2(1228, 96),
				Vector2(1268, 660),
				Vector2(1240, 660),
			])
			player_positions = [Vector2(400, 360), Vector2(880, 360), Vector2(540, 500), Vector2(740, 500)]
			enemy_positions = [Vector2(180, 200), Vector2(1100, 200), Vector2(180, 570), Vector2(1100, 570), Vector2(640, 170), Vector2(640, 610)]
			camera_zoom = Vector2(0.76, 0.76)
		"pinch":
			floor_points = PackedVector2Array([
				Vector2(160, 84),
				Vector2(1120, 84),
				Vector2(1260, 668),
				Vector2(20, 668),
			])
			back_wall_points = PackedVector2Array([
				Vector2(160, 58),
				Vector2(1120, 58),
				Vector2(1120, 110),
				Vector2(160, 110),
			])
			left_wall_points = PackedVector2Array([
				Vector2(132, 84),
				Vector2(160, 84),
				Vector2(20, 668),
				Vector2(-8, 668),
			])
			right_wall_points = PackedVector2Array([
				Vector2(1120, 84),
				Vector2(1148, 84),
				Vector2(1288, 668),
				Vector2(1260, 668),
			])
			player_positions = [Vector2(640, 500), Vector2(720, 500), Vector2(560, 500), Vector2(800, 500)]
			enemy_positions = [Vector2(260, 220), Vector2(1020, 220), Vector2(180, 600), Vector2(1100, 600), Vector2(640, 150), Vector2(640, 630)]
			camera_zoom = Vector2(0.78, 0.78)
		"offset":
			floor_points = PackedVector2Array([
				Vector2(100, 92),
				Vector2(1160, 68),
				Vector2(1270, 632),
				Vector2(30, 680),
			])
			back_wall_points = PackedVector2Array([
				Vector2(100, 58),
				Vector2(1160, 34),
				Vector2(1160, 82),
				Vector2(100, 106),
			])
			left_wall_points = PackedVector2Array([
				Vector2(72, 92),
				Vector2(100, 92),
				Vector2(30, 680),
				Vector2(2, 680),
			])
			right_wall_points = PackedVector2Array([
				Vector2(1160, 68),
				Vector2(1188, 68),
				Vector2(1298, 632),
				Vector2(1270, 632),
			])
			player_positions = [Vector2(390, 340), Vector2(760, 300), Vector2(520, 500), Vector2(900, 470)]
			enemy_positions = [Vector2(210, 190), Vector2(1090, 170), Vector2(140, 590), Vector2(1130, 550), Vector2(820, 120), Vector2(470, 630)]
			camera_zoom = Vector2(0.78, 0.78)
		"boss_gate":
			floor_points = PackedVector2Array([
				Vector2(100, 84),
				Vector2(1180, 84),
				Vector2(1280, 668),
				Vector2(0, 668),
			])
			back_wall_points = PackedVector2Array([
				Vector2(100, 58),
				Vector2(1180, 58),
				Vector2(1180, 106),
				Vector2(100, 106),
			])
			left_wall_points = PackedVector2Array([
				Vector2(72, 84),
				Vector2(100, 84),
				Vector2(0, 668),
				Vector2(-28, 668),
			])
			right_wall_points = PackedVector2Array([
				Vector2(1180, 84),
				Vector2(1208, 84),
				Vector2(1308, 668),
				Vector2(1280, 668),
			])
			player_positions = [Vector2(460, 520), Vector2(820, 520), Vector2(560, 600), Vector2(720, 600)]
			enemy_positions = [Vector2(200, 200), Vector2(1080, 200), Vector2(150, 580), Vector2(1130, 580), Vector2(640, 140), Vector2(640, 630)]
			camera_zoom = Vector2(0.74, 0.74)

	var bounds := _compute_bounds(floor_points)
	var min_x: float = bounds["min_x"]
	var max_x: float = bounds["max_x"]
	var min_y: float = bounds["min_y"]
	var max_y: float = bounds["max_y"]
	var wall_depth := 56.0
	var side_wall_width := 42.0
	floor_points = PackedVector2Array([
		Vector2(min_x, min_y),
		Vector2(max_x, min_y),
		Vector2(max_x, max_y),
		Vector2(min_x, max_y),
	])
	back_wall_points = PackedVector2Array([
		Vector2(min_x, min_y - wall_depth),
		Vector2(max_x, min_y - wall_depth),
		Vector2(max_x, min_y),
		Vector2(min_x, min_y),
	])
	left_wall_points = PackedVector2Array([
		Vector2(min_x - side_wall_width, min_y),
		Vector2(min_x, min_y),
		Vector2(min_x, max_y),
		Vector2(min_x - side_wall_width, max_y),
	])
	right_wall_points = PackedVector2Array([
		Vector2(max_x, min_y),
		Vector2(max_x + side_wall_width, min_y),
		Vector2(max_x + side_wall_width, max_y),
		Vector2(max_x, max_y),
	])

	var layout_center := _compute_polygon_center(floor_points)
	floor_points = _scale_points(floor_points, layout_center, MAP_SCALE)
	back_wall_points = _scale_points(back_wall_points, layout_center, MAP_SCALE)
	left_wall_points = _scale_points(left_wall_points, layout_center, MAP_SCALE)
	right_wall_points = _scale_points(right_wall_points, layout_center, MAP_SCALE)
	player_positions = _scale_vector_array(player_positions, layout_center, MAP_SCALE)
	enemy_positions = _scale_vector_array(enemy_positions, layout_center, MAP_SCALE)
	camera.position = layout_center
	camera_zoom *= 1.55

	floor_visual.polygon = floor_points
	back_wall_visual.polygon = back_wall_points
	left_wall_visual.polygon = left_wall_points
	right_wall_visual.polygon = right_wall_points
	_rebuild_floor_grid(floor_points)
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
	camera.zoom = camera_zoom

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
	if modifier_tint == null or camera == null:
		return
	var base_color: Color = modifier_tint.color
	_add_camera_trauma(0.5)
	var tween := create_tween()
	tween.tween_property(modifier_tint, "color", Color(1.0, 0.72, 0.72, 1.0), 0.08)
	tween.tween_property(modifier_tint, "color", base_color, 0.14)

func _play_revive_juice() -> void:
	if modifier_tint == null:
		return
	var base_color: Color = modifier_tint.color
	var tween := create_tween()
	tween.tween_property(modifier_tint, "color", Color(0.78, 1.0, 0.82, 1.0), 0.1)
	tween.tween_property(modifier_tint, "color", base_color, 0.16)

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
	player.scale = Vector2(0.88, 0.88)
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

func _play_sfx_fire() -> void:
	if _sfx_engine != null:
		_sfx_engine.play_fire()

func _play_sfx_hit() -> void:
	if _sfx_engine != null:
		_sfx_engine.play_hit()

func _play_sfx_explosion() -> void:
	if _sfx_engine != null:
		_sfx_engine.play_explosion()

func _play_sfx_dash() -> void:
	if _sfx_engine != null:
		_sfx_engine.play_dash()

func _play_sfx_damage() -> void:
	if _sfx_engine != null:
		_sfx_engine.play_damage()

func _play_sfx_enemy_death() -> void:
	if _sfx_engine != null:
		_sfx_engine.play_enemy_death()

func _play_sfx_room_clear() -> void:
	if _sfx_engine != null:
		_sfx_engine.play_room_clear()

func _build_hud() -> void:
	if ui_layer == null or _hud_root != null:
		return

	_hud_root = Control.new()
	_hud_root.name = "HUDRoot"
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(_hud_root)

	_floating_text_layer = Control.new()
	_floating_text_layer.name = "FloatingTextLayer"
	_floating_text_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.add_child(_floating_text_layer)

	for index in range(4):
		var bar = HealthBarHUDData.new()
		bar.position = Vector2(1540.0, 40.0 + float(index) * 84.0)
		bar.size = Vector2(320.0, 40.0)
		var fill_color := Color(0.7, 0.7, 0.7, 1.0)
		if index < _player_configs.size():
			fill_color = _player_configs[index].tint
		bar.configure("P%d" % (index + 1), fill_color)
		bar.visible = false
		_hud_root.add_child(bar)
		_player_health_bars.append(bar)

	_boss_health_bar = HealthBarHUDData.new()
	_boss_health_bar.position = Vector2(660.0, 18.0)
	_boss_health_bar.size = Vector2(600.0, 40.0)
	_boss_health_bar.configure("Crimson Gate", Color(0.86, 0.18, 0.18, 1.0))
	_boss_health_bar.visible = false
	_hud_root.add_child(_boss_health_bar)

func _refresh_player_health_bars() -> void:
	if _player_health_bars.is_empty():
		return
	for index in range(_player_health_bars.size()):
		var bar = _player_health_bars[index]
		var has_player := index < _player_nodes.size()
		bar.visible = has_player
		if not has_player:
			continue
		var player = _player_nodes[index]
		bar.configure("P%d" % player.player_id, player.player_config.tint)
		var health_state: Dictionary = player.get_health_state()
		var status_text := "DOWN" if player.is_downed() else ""
		bar.set_health(int(health_state.get("current", 0)), int(health_state.get("max", 1)), status_text)

func _refresh_boss_health_bar() -> void:
	if _boss_health_bar == null:
		return
	var boss_alive: bool = _boss_node != null and is_instance_valid(_boss_node) and _boss_node.is_alive()
	_boss_health_bar.visible = boss_alive
	if not boss_alive:
		return
	_boss_health_bar.configure(str(_room_config.get("title", "Boss")), Color(0.86, 0.18, 0.18, 1.0))
	_boss_health_bar.set_health(_boss_node.current_health, _boss_node.max_health)

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
	if remaining < 5.0:
		var pulse := 1.0 + 0.08 * sin(now * 10.0)
		room_status_label.scale = Vector2.ONE * pulse
		room_status_label.modulate = Color(1.0, 0.72, 0.72, 1.0)
		return
	_reset_room_status_pulse()

func _reset_room_status_pulse() -> void:
	room_status_label.scale = Vector2.ONE
	room_status_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

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

func _show_spawn_warning(plan: Array, announcement: String) -> void:
	_clear_spawn_warning_effects()
	for entry in plan:
		if not (entry is Dictionary):
			continue
		var position: Vector2 = entry.get("position", Vector2.ZERO)
		var warning := Polygon2D.new()
		warning.color = Color(1.0, 0.28, 0.22, 0.0)
		warning.polygon = PackedVector2Array([
			Vector2(-18, -10),
			Vector2(18, -10),
			Vector2(18, 10),
			Vector2(-18, 10),
		])
		warning.scale = Vector2(0.4, 0.4)
		_spawn_world_effect(warning, position)
		_pending_warning_effects.append(warning)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(warning, "scale", Vector2(1.7, 1.1), 0.46)
		tween.tween_property(warning, "color:a", 0.85, 0.12)
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

func _rebuild_floor_grid(floor_points: PackedVector2Array) -> void:
	if floor_grid == null:
		return
	for child in floor_grid.get_children():
		child.queue_free()

	var bounds := _compute_bounds(floor_points)
	var min_x: float = bounds["min_x"]
	var max_x: float = bounds["max_x"]
	var min_y: float = bounds["min_y"]
	var max_y: float = bounds["max_y"]
	var spacing := 96.0
	var grid_color := Color(0.48, 0.54, 0.46, 0.7)

	var x := min_x
	while x <= max_x:
		var vertical := Line2D.new()
		vertical.width = 2.0
		vertical.default_color = grid_color
		vertical.points = PackedVector2Array([Vector2(x, min_y), Vector2(x, max_y)])
		floor_grid.add_child(vertical)
		x += spacing

	var y := min_y
	while y <= max_y:
		var horizontal := Line2D.new()
		horizontal.width = 2.0
		horizontal.default_color = grid_color
		horizontal.points = PackedVector2Array([Vector2(min_x, y), Vector2(max_x, y)])
		floor_grid.add_child(horizontal)
		y += spacing

func _apply_collision_bounds_from_floor(floor_points: PackedVector2Array) -> void:
	if floor_points.is_empty():
		return
	var min_x := floor_points[0].x
	var max_x := floor_points[0].x
	var min_y := floor_points[0].y
	var max_y := floor_points[0].y
	for point in floor_points:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)

	var wall_thickness := 16.0
	var width := max_x - min_x
	var height := max_y - min_y
	var top_shape := top_wall.shape as RectangleShape2D
	var bottom_shape := bottom_wall.shape as RectangleShape2D
	var left_shape := left_wall.shape as RectangleShape2D
	var right_shape := right_wall.shape as RectangleShape2D
	if top_shape != null:
		top_shape.size = Vector2(width + wall_thickness, wall_thickness)
	if bottom_shape != null:
		bottom_shape.size = Vector2(width + wall_thickness, wall_thickness)
	if left_shape != null:
		left_shape.size = Vector2(wall_thickness, height + wall_thickness)
	if right_shape != null:
		right_shape.size = Vector2(wall_thickness, height + wall_thickness)

	top_wall.position = Vector2((min_x + max_x) * 0.5, min_y - wall_thickness)
	bottom_wall.position = Vector2((min_x + max_x) * 0.5, max_y + wall_thickness)
	left_wall.position = Vector2(min_x - wall_thickness, (min_y + max_y) * 0.5)
	right_wall.position = Vector2(max_x + wall_thickness, (min_y + max_y) * 0.5)
