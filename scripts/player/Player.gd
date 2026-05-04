extends CharacterBody2D

const PlayerConfigData = preload("res://scripts/player/PlayerConfig.gd")
const AimAssistData = preload("res://scripts/player/AimAssist.gd")
const DashData = preload("res://scripts/player/Dash.gd")

signal fire_requested(origin, direction, speed, damage, team)
signal secondary_requested(origin, direction, speed, damage, team, projectile_data)
signal health_changed(current_health, max_health)
signal downed(player)
signal revived(player)

@export_range(1, 4, 1) var player_id: int = 1
@export var move_speed: float = 260.0
@export var max_health: int = 5
@export var primary_fire_interval: float = 0.18
@export var projectile_speed: float = 540.0
@export var projectile_damage: int = 1
@export var secondary_cooldown: float = 4.0
@export var secondary_projectile_speed: float = 320.0
@export var secondary_damage: int = 3

@onready var visual: Polygon2D = $BodyRoot/Visual
@onready var aim_pivot: Node2D = $BodyRoot/AimPivot
@onready var aim_line: Line2D = $BodyRoot/AimPivot/AimLine

var player_config = PlayerConfigData.new()
var gamepad_device_id: int = -1
var aim_direction: Vector2 = Vector2.RIGHT
var current_health: int = 0

var _aim_assist = null
var _dash = null
var _dash_pressed_last_frame := false
var _next_primary_fire_at := 0.0
var _secondary_pressed_last_frame := false
var _next_secondary_ready_at := 0.0
var _is_downed := false
var _primary_profile_name := "Rifle"
var _primary_projectile_count := 1
var _primary_spread_radians := 0.0
var _secondary_profile_name := "Grenade"
var _secondary_projectile_count := 1
var _secondary_spread_radians := 0.0
var _secondary_projectile_data := {
	"kind": "grenade",
	"explosion_radius": 92.0,
	"fuse_time": 1.0,
	"gravity_force": 520.0,
}
var _base_collision_layer := 0
var _base_collision_mask := 0

func setup(config, assigned_gamepad_device_id: int) -> void:
	player_config = config
	player_id = config.player_id
	gamepad_device_id = assigned_gamepad_device_id
	if is_node_ready():
		_apply_visual_state(_current_time_seconds())

func cycle_aim_mode() -> void:
	player_config.cycle_aim_mode()
	_apply_visual_state(_current_time_seconds())

func get_aim_mode_name() -> String:
	return player_config.get_aim_mode_name()

func is_dash_active() -> bool:
	if _dash == null:
		return false
	return _dash.is_active(_current_time_seconds())

func get_dash_cooldown_remaining() -> float:
	if _dash == null:
		return 0.0
	return _dash.get_cooldown_remaining(_current_time_seconds())

func get_team() -> String:
	return "player"

func is_alive() -> bool:
	return not _is_downed and current_health > 0

func is_downed() -> bool:
	return _is_downed

func get_health_ratio_text() -> String:
	if _is_downed:
		return "DOWN"
	return "%d/%d" % [current_health, max_health]

func get_secondary_cooldown_remaining() -> float:
	return max(_next_secondary_ready_at - _current_time_seconds(), 0.0)

func get_health_state() -> Dictionary:
	return {
		"current": current_health,
		"max": max_health,
	}

func get_primary_profile_name() -> String:
	return _primary_profile_name

func get_secondary_profile_name() -> String:
	return _secondary_profile_name

func apply_loadout(loadout: Dictionary) -> void:
	_primary_profile_name = str(loadout.get("primary_profile_name", "Rifle"))
	_secondary_profile_name = str(loadout.get("secondary_profile_name", "Grenade"))
	_primary_projectile_count = max(1, int(loadout.get("primary_projectile_count", 1)))
	_primary_spread_radians = float(loadout.get("primary_spread_radians", 0.0))
	_secondary_projectile_count = max(1, int(loadout.get("secondary_projectile_count", 1)))
	_secondary_spread_radians = float(loadout.get("secondary_spread_radians", 0.0))
	move_speed = float(loadout.get("move_speed", move_speed))
	primary_fire_interval = float(loadout.get("primary_fire_interval", primary_fire_interval))
	projectile_speed = float(loadout.get("projectile_speed", projectile_speed))
	projectile_damage = max(1, int(loadout.get("projectile_damage", projectile_damage)))
	secondary_cooldown = float(loadout.get("secondary_cooldown", secondary_cooldown))
	secondary_projectile_speed = float(loadout.get("secondary_projectile_speed", secondary_projectile_speed))
	secondary_damage = max(1, int(loadout.get("secondary_damage", secondary_damage)))
	_secondary_projectile_data = {
		"kind": str(loadout.get("secondary_projectile_kind", "grenade")),
		"explosion_radius": float(loadout.get("secondary_explosion_radius", 92.0)),
		"fuse_time": float(loadout.get("secondary_fuse_time", 1.0)),
		"gravity_force": float(loadout.get("secondary_gravity_force", 520.0)),
	}

func set_health_state(state: Dictionary) -> void:
	var target_max := int(state.get("max", max_health))
	var target_current := int(state.get("current", target_max))
	max_health = target_max
	current_health = clampi(target_current, 1, max_health)
	_is_downed = false
	visible = true
	collision_layer = _base_collision_layer
	collision_mask = _base_collision_mask
	set_physics_process(true)
	health_changed.emit(current_health, max_health)
	_apply_visual_state(_current_time_seconds())

func apply_damage(amount: int) -> void:
	if _is_downed:
		return

	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		_enter_downed_state()

func revive(health_amount: int) -> void:
	if not _is_downed:
		return

	current_health = clampi(health_amount, 1, max_health)
	_is_downed = false
	visible = true
	collision_layer = _base_collision_layer
	collision_mask = _base_collision_mask
	set_physics_process(true)
	health_changed.emit(current_health, max_health)
	revived.emit(self)
	_apply_visual_state(_current_time_seconds())

func _ready() -> void:
	_aim_assist = AimAssistData.new()
	_dash = DashData.new()
	add_to_group("player_target")
	_base_collision_layer = collision_layer
	_base_collision_mask = collision_mask
	current_health = max_health
	health_changed.emit(current_health, max_health)
	_apply_visual_state(_current_time_seconds())

func _physics_process(_delta: float) -> void:
	var move_input := _get_move_input()
	var raw_aim_input := _get_aim_input()
	aim_direction = _aim_assist.resolve_aim_direction(
		self,
		raw_aim_input,
		move_input,
		aim_direction,
		player_config.aim_mode
	)

	var now := _current_time_seconds()
	var dash_pressed := _is_dash_pressed()
	if dash_pressed and not _dash_pressed_last_frame:
		var dash_direction := move_input if move_input.length() > 0.0 else aim_direction
		_dash.try_trigger(dash_direction, now)
	_dash_pressed_last_frame = dash_pressed

	if _is_fire_pressed() and now >= _next_primary_fire_at and aim_direction.length() > 0.0:
		_next_primary_fire_at = now + primary_fire_interval
		for projectile_direction in _build_spread_directions(aim_direction, _primary_projectile_count, _primary_spread_radians):
			fire_requested.emit(
				global_position + projectile_direction * 26.0,
				projectile_direction,
				projectile_speed,
				projectile_damage,
				get_team()
			)

	var secondary_pressed := _is_secondary_pressed()
	if secondary_pressed and not _secondary_pressed_last_frame and now >= _next_secondary_ready_at and aim_direction.length() > 0.0:
		_next_secondary_ready_at = now + secondary_cooldown
		for projectile_direction in _build_spread_directions(aim_direction, _secondary_projectile_count, _secondary_spread_radians):
			secondary_requested.emit(
				global_position + projectile_direction * 22.0,
				projectile_direction,
				secondary_projectile_speed,
				secondary_damage,
				get_team(),
				_secondary_projectile_data.duplicate(true)
			)
	_secondary_pressed_last_frame = secondary_pressed

	velocity = _dash.get_velocity(move_input, aim_direction, move_speed, now)
	move_and_slide()
	_apply_visual_state(now)

func _get_move_input() -> Vector2:
	var keyboard_vector := _get_keyboard_move_vector()
	var gamepad_vector := _get_gamepad_move_vector()
	match player_config.control_source:
		"keyboard":
			return keyboard_vector
		"gamepad":
			return gamepad_vector
		"hybrid":
			return _choose_stronger_vector(keyboard_vector, gamepad_vector)
		_:
			return keyboard_vector

func _get_aim_input() -> Vector2:
	var keyboard_vector := _get_keyboard_aim_vector()
	var gamepad_vector := _get_gamepad_aim_vector()
	match player_config.control_source:
		"keyboard":
			return keyboard_vector
		"gamepad":
			return gamepad_vector
		"hybrid":
			return _choose_stronger_vector(keyboard_vector, gamepad_vector)
		_:
			return keyboard_vector

func _get_keyboard_move_vector() -> Vector2:
	var prefix := "p%d_" % player_id
	return Input.get_vector(
		"%smove_left" % prefix,
		"%smove_right" % prefix,
		"%smove_up" % prefix,
		"%smove_down" % prefix
	)

func _get_keyboard_aim_vector() -> Vector2:
	var mouse_direction := get_global_mouse_position() - global_position
	if mouse_direction.length() >= 8.0:
		return mouse_direction.normalized()
	match player_id:
		1:
			return _build_key_vector(KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN)
		2:
			return _build_key_vector(KEY_KP_4, KEY_KP_6, KEY_KP_8, KEY_KP_5)
		_:
			return Vector2.ZERO

func _get_gamepad_move_vector() -> Vector2:
	return _get_gamepad_stick_vector(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)

func _get_gamepad_aim_vector() -> Vector2:
	return _get_gamepad_stick_vector(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)

func _get_gamepad_stick_vector(axis_x: JoyAxis, axis_y: JoyAxis) -> Vector2:
	if gamepad_device_id < 0:
		return Vector2.ZERO
	if not Input.get_connected_joypads().has(gamepad_device_id):
		return Vector2.ZERO

	var vector := Vector2(
		Input.get_joy_axis(gamepad_device_id, axis_x),
		Input.get_joy_axis(gamepad_device_id, axis_y)
	)
	return vector if vector.length() >= 0.2 else Vector2.ZERO

func _build_key_vector(left_key: Key, right_key: Key, up_key: Key, down_key: Key) -> Vector2:
	var horizontal := int(Input.is_physical_key_pressed(right_key)) - int(Input.is_physical_key_pressed(left_key))
	var vertical := int(Input.is_physical_key_pressed(down_key)) - int(Input.is_physical_key_pressed(up_key))
	var vector := Vector2(horizontal, vertical)
	return vector.normalized() if vector.length() > 1.0 else vector

func _is_dash_pressed() -> bool:
	match player_config.control_source:
		"keyboard":
			return _is_keyboard_dash_pressed()
		"gamepad":
			return _is_gamepad_dash_pressed()
		"hybrid":
			return _is_keyboard_dash_pressed() or _is_gamepad_dash_pressed()
		_:
			return _is_keyboard_dash_pressed()

func _is_fire_pressed() -> bool:
	match player_config.control_source:
		"keyboard":
			return _is_keyboard_fire_pressed()
		"gamepad":
			return _is_gamepad_fire_pressed()
		"hybrid":
			return _is_keyboard_fire_pressed() or _is_gamepad_fire_pressed()
		_:
			return _is_keyboard_fire_pressed()

func _is_secondary_pressed() -> bool:
	match player_config.control_source:
		"keyboard":
			return _is_keyboard_secondary_pressed()
		"gamepad":
			return _is_gamepad_secondary_pressed()
		"hybrid":
			return _is_keyboard_secondary_pressed() or _is_gamepad_secondary_pressed()
		_:
			return _is_keyboard_secondary_pressed()

func _is_keyboard_fire_pressed() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _is_gamepad_fire_pressed() -> bool:
	if gamepad_device_id < 0:
		return false
	if not Input.get_connected_joypads().has(gamepad_device_id):
		return false
	return Input.get_joy_axis(gamepad_device_id, JOY_AXIS_TRIGGER_RIGHT) >= 0.5

func _is_keyboard_secondary_pressed() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

func _is_gamepad_secondary_pressed() -> bool:
	if gamepad_device_id < 0:
		return false
	if not Input.get_connected_joypads().has(gamepad_device_id):
		return false
	return Input.get_joy_axis(gamepad_device_id, JOY_AXIS_TRIGGER_LEFT) >= 0.5

func _is_keyboard_dash_pressed() -> bool:
	match player_id:
		1:
			return Input.is_physical_key_pressed(KEY_SPACE)
		2:
			return Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_KP_ENTER)
		_:
			return false

func _is_gamepad_dash_pressed() -> bool:
	if gamepad_device_id < 0:
		return false
	if not Input.get_connected_joypads().has(gamepad_device_id):
		return false
	return Input.is_joy_button_pressed(gamepad_device_id, JOY_BUTTON_A)

func _choose_stronger_vector(primary: Vector2, secondary: Vector2) -> Vector2:
	return secondary if secondary.length() > primary.length() else primary

func _build_spread_directions(base_direction: Vector2, projectile_count: int, spread_radians: float) -> Array:
	var directions: Array = []
	var normalized_direction := base_direction.normalized()
	if projectile_count <= 1 or spread_radians <= 0.0:
		directions.append(normalized_direction)
		return directions

	var center_offset := (projectile_count - 1) * 0.5
	for index in range(projectile_count):
		var offset := (float(index) - center_offset) * spread_radians
		directions.append(normalized_direction.rotated(offset))
	return directions

func _apply_visual_state(now: float) -> void:
	if visual == null or aim_pivot == null or aim_line == null:
		return
	var dash_active: bool = _dash != null and _dash.is_active(now)
	visual.color = player_config.tint.darkened(0.45) if _is_downed else player_config.tint
	visual.scale = Vector2.ONE * (0.9 if _is_downed else (1.15 if dash_active else 1.0))
	aim_pivot.rotation = aim_direction.angle()
	aim_line.default_color = player_config.tint.lightened(0.15)
	aim_line.visible = not _is_downed

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _enter_downed_state() -> void:
	_is_downed = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	downed.emit(self)
	_apply_visual_state(_current_time_seconds())
