extends Node2D

const PlayerConfigData = preload("res://scripts/player/PlayerConfig.gd")
const ModifierEngineData = preload("res://scripts/game/ModifierEngine.gd")

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
@onready var floor_visual: Polygon2D = $Floor
@onready var back_wall_visual: Polygon2D = $BackWall
@onready var left_wall_visual: Polygon2D = $LeftWallVisual
@onready var right_wall_visual: Polygon2D = $RightWallVisual
@onready var camera: Camera2D = $Camera2D
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
	_status_labels = [p1_status_label, p2_status_label, p3_status_label, p4_status_label]
	_secondary_labels = [p1_secondary_label, p2_secondary_label, p3_secondary_label, p4_secondary_label]

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
		player.downed.connect(_on_player_downed)
		player.revived.connect(_on_player_revived)
		players.add_child(player)
		_player_nodes.append(player)

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

func _build_player_status_text(player) -> String:
	var dash_state := "Downed" if player.is_downed() else ("Dashing" if player.is_dash_active() else "Ready")
	if not player.is_downed() and not player.is_dash_active():
		var cooldown: float = player.get_dash_cooldown_remaining()
		dash_state = "Cooldown %.1fs" % cooldown if cooldown > 0.0 else "Ready"

	return "P%d  HP: %s  Control: %s  Aim: %s  Dash: %s" % [
		player.player_id,
		player.get_health_ratio_text(),
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
	_boss_node = null
	_active_modifier = {} if _is_boss_room() else _room_config.get("modifier", _modifier_engine.get_random_modifier()).duplicate(true)
	_clear_container(projectiles)
	_clear_container(enemies)
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
		_spawn_survival_wave()

func _spawn_survival_wave() -> void:
	var spawn_points := _get_enemy_spawn_positions()
	var enemy_types := ["chaser", "spitter", "chaser", "spitter"]
	var spawn_count := clampi(2 + max(_player_nodes.size() - 2, 0), 2, enemy_types.size())

	for index in range(spawn_count):
		var spawn_index := (_survival_wave_index * spawn_count + index) % spawn_points.size()
		var enemy = enemy_scene.instantiate()
		enemy.global_position = spawn_points[spawn_index]
		enemy.setup(enemy_types[index], self)
		enemy.apply_room_modifier(
			_modifier_engine.get_enemy_bonus_health(_active_modifier),
			_modifier_engine.get_enemy_speed_multiplier(_active_modifier),
			_modifier_engine.get_enemy_fire_interval_multiplier(_active_modifier),
			_modifier_engine.get_death_explosion_radius(_active_modifier),
			_modifier_engine.get_death_explosion_damage(_active_modifier),
			_modifier_engine.get_enemy_contact_damage_bonus(_active_modifier)
		)
		enemy.enemy_died.connect(_on_enemy_died)
		enemy.fire_requested.connect(_on_enemy_fire_requested)
		enemies.add_child(enemy)

	_survival_wave_index += 1

func _spawn_boss() -> void:
	var boss = enemy_scene.instantiate()
	boss.global_position = Vector2(640, 210)
	boss.setup("boss", self)
	boss.apply_boss_scale(_player_nodes.size())
	boss.enemy_died.connect(_on_enemy_died)
	boss.fire_requested.connect(_on_enemy_fire_requested)
	enemies.add_child(boss)
	_boss_node = boss

func _spawn_boss_support_wave() -> void:
	var spawn_points := _get_enemy_spawn_positions()
	var support_count := 1 if _player_nodes.size() <= 2 else 2
	for index in range(support_count):
		var enemy_type := "spitter" if (_survival_wave_index + index) % 2 == 0 else "chaser"
		var spawn_index := (_survival_wave_index + index) % spawn_points.size()
		var enemy = enemy_scene.instantiate()
		enemy.global_position = spawn_points[spawn_index]
		enemy.setup(enemy_type, self)
		enemy.enemy_died.connect(_on_enemy_died)
		enemy.fire_requested.connect(_on_enemy_fire_requested)
		enemies.add_child(enemy)
	_survival_wave_index += support_count

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
	projectiles.add_child(projectile)

func _spawn_grenade(origin: Vector2, direction: Vector2, speed: float, damage: int, team: String, projectile_data: Dictionary) -> void:
	var grenade = grenade_projectile_scene.instantiate()
	grenade.global_position = origin
	grenade.setup(team, direction, speed, damage)
	grenade.explosion_radius = float(projectile_data.get("explosion_radius", grenade.explosion_radius))
	grenade.fuse_time = float(projectile_data.get("fuse_time", grenade.fuse_time))
	grenade.gravity_force = float(projectile_data.get("gravity_force", grenade.gravity_force))
	projectiles.add_child(grenade)

func _on_enemy_died(enemy) -> void:
	if _is_boss_room() and enemy != null and enemy.has_method("is_boss") and enemy.is_boss():
		_boss_node = null
		_handle_room_clear("Boss Defeated", "The boss collapsed and the run can continue.")
		return
	call_deferred("_evaluate_room_state")

func _on_player_health_changed(_current_health: int, _max_health: int) -> void:
	_refresh_debug_ui()

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
	_refresh_debug_ui()

func _evaluate_room_state() -> void:
	if _room_is_failed or _room_is_cleared:
		return

	if get_active_players().is_empty():
		_room_is_failed = true
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

	if now >= _next_enemy_spawn_at:
		_spawn_survival_wave()
		_next_enemy_spawn_at += _get_spawn_interval()

	_apply_stationary_modifier(now)

	room_status_label.text = "Room status: Survive %.1fs | Enemies: %d%s" % [
		remaining,
		enemies.get_child_count(),
		_build_revive_status_suffix(),
	]

func _update_boss_room(now: float) -> void:
	var boss_alive: bool = _boss_node != null and is_instance_valid(_boss_node) and _boss_node.is_alive()
	if not boss_alive:
		return

	if now >= _next_boss_support_spawn_at:
		_spawn_boss_support_wave()
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
	if _boss_node != null and is_instance_valid(_boss_node):
		_boss_node = null
	room_status_label.text = "Room status: %s" % title
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

	if _is_boss_room():
		modifier_tint.color = Color(1.0, 1.0, 1.0, 1.0)
		return

	var tint: Color = _modifier_engine.get_tint_color(_active_modifier)
	modifier_tint.color = tint.darkened(0.55)

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
	var floor_points: PackedVector2Array = PackedVector2Array([
		Vector2(200, 120),
		Vector2(1080, 120),
		Vector2(1180, 620),
		Vector2(100, 620),
	])
	var back_wall_points: PackedVector2Array = PackedVector2Array([
		Vector2(200, 96),
		Vector2(1080, 96),
		Vector2(1080, 136),
		Vector2(200, 136),
	])
	var left_wall_points: PackedVector2Array = PackedVector2Array([
		Vector2(172, 120),
		Vector2(200, 120),
		Vector2(100, 620),
		Vector2(72, 620),
	])
	var right_wall_points: PackedVector2Array = PackedVector2Array([
		Vector2(1080, 120),
		Vector2(1108, 120),
		Vector2(1208, 620),
		Vector2(1180, 620),
	])
	var camera_zoom := Vector2(0.92, 0.92)
	var player_positions := [
		Vector2(500, 360),
		Vector2(780, 360),
		Vector2(500, 438),
		Vector2(780, 438),
	]
	var enemy_positions := [
		Vector2(360, 220),
		Vector2(920, 220),
		Vector2(360, 520),
		Vector2(920, 520),
		Vector2(640, 180),
		Vector2(640, 560),
	]

	match layout_id:
		"crossfire":
			floor_points = PackedVector2Array([
				Vector2(150, 132),
				Vector2(1130, 132),
				Vector2(1160, 610),
				Vector2(120, 610),
			])
			player_positions = [Vector2(420, 350), Vector2(860, 350), Vector2(560, 470), Vector2(720, 470)]
			enemy_positions = [Vector2(240, 220), Vector2(1040, 220), Vector2(240, 520), Vector2(1040, 520), Vector2(640, 200), Vector2(640, 540)]
			camera_zoom = Vector2(0.88, 0.88)
		"pinch":
			floor_points = PackedVector2Array([
				Vector2(240, 118),
				Vector2(1040, 118),
				Vector2(1160, 620),
				Vector2(120, 620),
			])
			back_wall_points = PackedVector2Array([
				Vector2(240, 94),
				Vector2(1040, 94),
				Vector2(1040, 138),
				Vector2(240, 138),
			])
			player_positions = [Vector2(640, 470), Vector2(700, 470), Vector2(580, 470), Vector2(760, 470)]
			enemy_positions = [Vector2(320, 250), Vector2(960, 250), Vector2(260, 520), Vector2(1020, 520), Vector2(640, 180), Vector2(640, 580)]
			camera_zoom = Vector2(0.9, 0.9)
		"offset":
			floor_points = PackedVector2Array([
				Vector2(180, 128),
				Vector2(1080, 112),
				Vector2(1188, 600),
				Vector2(112, 628),
			])
			player_positions = [Vector2(430, 330), Vector2(720, 300), Vector2(540, 470), Vector2(830, 450)]
			enemy_positions = [Vector2(300, 220), Vector2(980, 200), Vector2(220, 520), Vector2(1020, 500), Vector2(760, 180), Vector2(520, 560)]
			camera_zoom = Vector2(0.9, 0.9)
		"boss_gate":
			floor_points = PackedVector2Array([
				Vector2(180, 120),
				Vector2(1100, 120),
				Vector2(1200, 620),
				Vector2(80, 620),
			])
			player_positions = [Vector2(500, 490), Vector2(780, 490), Vector2(570, 560), Vector2(710, 560)]
			enemy_positions = [Vector2(260, 220), Vector2(1020, 220), Vector2(220, 520), Vector2(1060, 520), Vector2(640, 180), Vector2(640, 540)]
			camera_zoom = Vector2(0.86, 0.86)

	floor_visual.polygon = floor_points
	back_wall_visual.polygon = back_wall_points
	left_wall_visual.polygon = left_wall_points
	right_wall_visual.polygon = right_wall_points
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
	var tween := create_tween()
	tween.tween_property(modifier_tint, "color", Color(1.0, 0.72, 0.72, 1.0), 0.08)
	tween.parallel().tween_property(camera, "offset", Vector2(8, 0), 0.05)
	tween.tween_property(modifier_tint, "color", base_color, 0.14)
	tween.parallel().tween_property(camera, "offset", Vector2.ZERO, 0.1)

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
	var base_zoom := camera.zoom
	var tween := create_tween()
	tween.tween_property(camera, "zoom", base_zoom * 0.94, 0.1)
	tween.tween_property(camera, "zoom", base_zoom, 0.16)
