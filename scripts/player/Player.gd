extends CharacterBody2D

const PlayerConfigData = preload("res://scripts/player/PlayerConfig.gd")
const AimAssistData = preload("res://scripts/player/AimAssist.gd")
const DashData = preload("res://scripts/player/Dash.gd")
const PLAYER_P1_STANDING_TEXTURE_PATH := "res://assets/sprites/player/player_p1_standing.png"
const PLAYER_P1_RUNNING_TEXTURE_PATH := "res://assets/sprites/player/player_p1_running.png"
const PLAYER_P1_RUNNING_ALT_TEXTURE_PATH := "res://assets/sprites/player/player_p1_running_alt.png"
const PLAYER_RIFLE_TEXTURE_PATH := "res://assets/sprites/weapons/player_rifle.png"
const PLAYER_SCATTERGUN_TEXTURE_PATH := "res://assets/sprites/weapons/player_scattergun.png"
const PLAYER_SLUG_TEXTURE_PATH := "res://assets/sprites/weapons/player_slug.png"
const DASH_SHIELD_DURATION := 0.5
const PRIMARY_FIRE_BUFFER_DURATION := 0.08
const SLOW_PRIMARY_BUFFER_THRESHOLD := 0.34
const FLASH_SHADER_CODE := """
shader_type canvas_item;

uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.2, 0.2, 1.0);

void fragment() {
	vec4 base = COLOR;
	COLOR = mix(base, flash_color, flash_intensity * flash_color.a);
}
"""

signal fire_requested(origin, direction, speed, damage, team, color, shooter, feedback_profile, impact_weight)
signal secondary_requested(origin, direction, speed, damage, team, projectile_data, color)
signal health_changed(current_health, max_health)
signal downed(player)
signal revived(player)
signal muzzle_flash_requested(origin, direction, color, feedback_profile, impact_weight)
signal dash_trail_requested(origin, color)
signal dash_started(origin, color, shield_duration)
signal damage_taken(player, amount, current_health)

@export_range(1, 4, 1) var player_id: int = 1
@export var move_speed: float = 260.0
@export var max_health: int = 5
@export var primary_fire_interval: float = 0.24
@export var projectile_speed: float = 540.0
@export var projectile_damage: int = 1
@export var secondary_cooldown: float = 4.0
@export var secondary_projectile_speed: float = 125.0
@export var secondary_damage: int = 3

@onready var shadow: Polygon2D = $Shadow
@onready var dash_shield_ring: Line2D = $DashShieldRing
@onready var body_root: Node2D = $BodyRoot
@onready var outline: Polygon2D = $BodyRoot/Outline
@onready var visual: Polygon2D = $BodyRoot/Visual
@onready var sprite_visual: Sprite2D = $BodyRoot/SpriteVisual
@onready var aim_pivot: Node2D = $BodyRoot/AimPivot
@onready var weapon_sprite: Sprite2D = $BodyRoot/AimPivot/WeaponSprite
@onready var aim_line_backdrop: Line2D = $BodyRoot/AimPivot/AimLineBackdrop
@onready var aim_line: Line2D = $BodyRoot/AimPivot/AimLine
@onready var secondary_preview: Node2D = $SecondaryPreview
@onready var secondary_trajectory: Line2D = $SecondaryPreview/SecondaryTrajectory
@onready var secondary_target_ring: Line2D = $SecondaryPreview/SecondaryTargetRing
@onready var secondary_target_cross: Line2D = $SecondaryPreview/SecondaryTargetCross

var player_index: int = 0
var player_config = PlayerConfigData.new()
var gamepad_device_id: int = -1
var aim_direction: Vector2 = Vector2.RIGHT
var current_health: int = 0

var _aim_assist = null
var _dash = null
var _dash_pressed_last_frame := false
var _fire_pressed_last_frame := false
var _next_primary_fire_at := 0.0
var _secondary_pressed_last_frame := false
var _switch_primary_pressed_last_frame := false
var _switch_secondary_pressed_last_frame := false
var _secondary_hold_active := false
var _is_downed := false
var _primary_profile_name := "Rifle"
var _primary_projectile_count := 1
var _primary_spread_radians := 0.0
var _secondary_profile_name := "Mine"
var _secondary_projectile_count := 1
var _secondary_spread_radians := 0.0
var _secondary_projectile_data := {
	"kind": "mine",
	"explosion_radius": 92.0,
	"fuse_time": 12.0,
	"gravity_force": 0.0,
	"pulse_count": 1,
	"pulse_interval": 0.18,
	"cluster_blast_count": 0,
	"cluster_spread_radius": 52.0,
	"proximity_radius": 52.0,
}
var _primary_slots: Array = []
var _secondary_slots: Array = []
var _selected_primary_index: int = 0
var _selected_secondary_index: int = 0
var _secondary_cooldowns: Array = [0.0, 0.0]
var _primary_fire_buffered_until: float = 0.0
var _primary_fire_buffered_direction: Vector2 = Vector2.RIGHT
var _input_locked: bool = false
var _base_collision_layer := 0
var _base_collision_mask := 0
var _flash_material: ShaderMaterial = null
var _flash_tween: Tween = null
var _next_dash_trail_at := 0.0
var _base_visual_scale := Vector2.ONE
var _base_sprite_scale := Vector2.ONE
var _base_shadow_scale := Vector2.ONE
var _display_move_input := Vector2.ZERO
var _previous_move_input := Vector2.ZERO
var _sprite_facing_left := false
var _sprite_is_running := false
var _standing_sprite_texture: Texture2D = null
var _running_sprite_texture: Texture2D = null
var _running_sprite_alt_texture: Texture2D = null
var _weapon_texture: Texture2D = null
var _weapon_textures_by_id: Dictionary = {}
var _primary_weapon_id: String = "rifle"
var _primary_feedback_profile: String = "rifle"
var _secondary_feedback_profile: String = "mine"
var _primary_impact_weight: float = 1.0
var _secondary_impact_weight: float = 1.6
var _base_weapon_scale := Vector2.ONE
var _turn_squash := 0.0
var _aim_line_recoil := 0.0
var _outline_pulse := 1.0
var _shield_until: float = 0.0

func _get_projectile_tint() -> Color:
	return player_config.tint

func setup(config, assigned_gamepad_device_id: int) -> void:
	player_config = config
	player_id = config.player_id
	gamepad_device_id = assigned_gamepad_device_id
	if is_node_ready():
		_apply_visual_state(_current_time_seconds())

func cycle_aim_mode() -> void:
	player_config.cycle_aim_mode()
	_apply_visual_state(_current_time_seconds())

func set_aim_mode(aim_mode: int) -> void:
	player_config.aim_mode = clampi(
		aim_mode,
		PlayerConfigData.AimMode.HEAVY_AUTO,
		PlayerConfigData.AimMode.MANUAL
	)
	_apply_visual_state(_current_time_seconds())

func get_aim_mode_name() -> String:
	return player_config.get_aim_mode_name()

func is_dash_active() -> bool:
	if _dash == null:
		return false
	return _dash.is_active(_current_time_seconds())

func is_dash_shield_active() -> bool:
	return _current_time_seconds() < _shield_until

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
	if _selected_secondary_index < 0 or _selected_secondary_index >= _secondary_cooldowns.size():
		return 0.0
	return max(float(_secondary_cooldowns[_selected_secondary_index]) - _current_time_seconds(), 0.0)

func get_health_state() -> Dictionary:
	return {
		"current": current_health,
		"max": max_health,
	}

func get_primary_profile_name() -> String:
	return _primary_profile_name

func get_secondary_profile_name() -> String:
	return _secondary_profile_name

func get_primary_slot_hud_data() -> Array:
	var slot_rows: Array = []
	for slot_index in range(_primary_slots.size()):
		slot_rows.append(_build_slot_hud_data(_primary_slots, slot_index, false))
	return slot_rows

func get_secondary_slot_hud_data() -> Array:
	var slot_rows: Array = []
	for slot_index in range(_secondary_slots.size()):
		slot_rows.append(_build_slot_hud_data(_secondary_slots, slot_index, true))
	return slot_rows

func get_health_status_text() -> String:
	return "DOWN" if _is_downed else "%d/%d" % [current_health, max_health]

func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	if locked:
		if _dash != null:
			_dash.clear_buffer()
		_fire_pressed_last_frame = false
		_primary_fire_buffered_until = 0.0
		_secondary_hold_active = false
		_dash_pressed_last_frame = false
		_secondary_pressed_last_frame = false
		_switch_primary_pressed_last_frame = false
		_switch_secondary_pressed_last_frame = false
		velocity = Vector2.ZERO

func apply_loadout(loadout: Dictionary) -> void:
	move_speed = float(loadout.get("move_speed", move_speed))
	_primary_slots = _normalize_slot_loadout_array(loadout.get("primary_slots", []))
	_secondary_slots = _normalize_slot_loadout_array(loadout.get("secondary_slots", []))
	if _primary_slots.is_empty():
		_primary_slots = [null, null]
	if _secondary_slots.is_empty():
		_secondary_slots = [null, null]
	_selected_primary_index = clampi(int(loadout.get("selected_primary", 0)), 0, max(_primary_slots.size() - 1, 0))
	_selected_secondary_index = clampi(int(loadout.get("selected_secondary", 0)), 0, max(_secondary_slots.size() - 1, 0))
	_selected_primary_index = _resolve_selected_slot_index(_primary_slots, _selected_primary_index)
	_selected_secondary_index = _resolve_selected_slot_index(_secondary_slots, _selected_secondary_index)
	_secondary_cooldowns = []
	for _index in range(max(_secondary_slots.size(), 2)):
		_secondary_cooldowns.append(0.0)
	_sync_inventory_selection()
	_apply_selected_slot_state()

func set_health_state(state: Dictionary) -> void:
	var target_max := int(state.get("max", max_health))
	var target_current := int(state.get("current", target_max))
	max_health = target_max
	current_health = clampi(target_current, 1, max_health)
	_is_downed = false
	_shield_until = 0.0
	if _dash != null:
		_dash.clear_buffer()
	_primary_fire_buffered_until = 0.0
	visible = true
	collision_layer = _base_collision_layer
	collision_mask = _base_collision_mask
	set_physics_process(true)
	health_changed.emit(current_health, max_health)
	_apply_visual_state(_current_time_seconds())

func apply_damage(amount: int) -> void:
	if _is_downed:
		return
	if is_dash_shield_active():
		return

	current_health = max(current_health - amount, 0)
	_play_damage_flash()
	damage_taken.emit(self, amount, current_health)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		_enter_downed_state()

func heal(amount: int) -> int:
	if _is_downed:
		return 0
	var applied_heal: int = max(amount, 0)
	if applied_heal <= 0:
		return 0
	var previous_health: int = current_health
	current_health = min(current_health + applied_heal, max_health)
	var healed_amount: int = current_health - previous_health
	if healed_amount > 0:
		health_changed.emit(current_health, max_health)
		_apply_visual_state(_current_time_seconds())
	return healed_amount

func revive(health_amount: int) -> void:
	if not _is_downed:
		return

	current_health = clampi(health_amount, 1, max_health)
	_is_downed = false
	_shield_until = 0.0
	if _dash != null:
		_dash.clear_buffer()
	_primary_fire_buffered_until = 0.0
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
	_standing_sprite_texture = _load_sprite_texture(PLAYER_P1_STANDING_TEXTURE_PATH)
	_running_sprite_texture = _load_sprite_texture(PLAYER_P1_RUNNING_TEXTURE_PATH)
	_running_sprite_alt_texture = _load_sprite_texture(PLAYER_P1_RUNNING_ALT_TEXTURE_PATH)
	_weapon_textures_by_id = {
		"rifle": _load_sprite_texture(PLAYER_RIFLE_TEXTURE_PATH),
		"scatter": _load_sprite_texture(PLAYER_SCATTERGUN_TEXTURE_PATH),
		"spread": _load_sprite_texture(PLAYER_SCATTERGUN_TEXTURE_PATH),
		"slug": _load_sprite_texture(PLAYER_SLUG_TEXTURE_PATH),
	}
	if visual != null:
		_base_visual_scale = visual.scale
	if sprite_visual != null:
		_base_sprite_scale = sprite_visual.scale
	if weapon_sprite != null:
		_base_weapon_scale = weapon_sprite.scale
	if shadow != null:
		_base_shadow_scale = shadow.scale
	current_health = max_health
	_apply_selected_slot_state()
	health_changed.emit(current_health, max_health)
	_apply_visual_state(_current_time_seconds())

func _physics_process(delta: float) -> void:
	var now := _current_time_seconds()
	if _input_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation_state(Vector2.ZERO, delta)
		_apply_visual_state(now, delta)
		return

	var move_input := _get_move_input()
	var raw_aim_input := _get_aim_input()
	aim_direction = _aim_assist.resolve_aim_direction(
		self,
		raw_aim_input,
		move_input,
		aim_direction,
		player_config.aim_mode
	)

	var dash_pressed := _is_dash_pressed()
	if dash_pressed and not _dash_pressed_last_frame:
		var dash_direction := move_input if move_input.length() > 0.0 else aim_direction
		if _dash.try_trigger(dash_direction, now):
			_activate_dash_shield(now)
	_dash_pressed_last_frame = dash_pressed
	if _dash.consume_buffer_if_ready(now):
		_activate_dash_shield(now)

	var switch_primary_pressed := _is_switch_primary_pressed()
	if switch_primary_pressed and not _switch_primary_pressed_last_frame:
		_cycle_primary_slot()
	_switch_primary_pressed_last_frame = switch_primary_pressed

	var switch_secondary_pressed := _is_switch_secondary_pressed()
	if switch_secondary_pressed and not _switch_secondary_pressed_last_frame:
		_cycle_secondary_slot()
	_switch_secondary_pressed_last_frame = switch_secondary_pressed

	var fire_pressed := _is_fire_pressed()
	var fire_just_pressed: bool = fire_pressed and not _fire_pressed_last_frame
	if fire_just_pressed and _should_buffer_primary_fire(now):
		_primary_fire_buffered_until = now + PRIMARY_FIRE_BUFFER_DURATION
		_primary_fire_buffered_direction = aim_direction
	if fire_pressed and now >= _next_primary_fire_at and aim_direction.length() > 0.0:
		_fire_primary(now, aim_direction)
	elif _primary_fire_buffered_until > 0.0 and now >= _next_primary_fire_at and now <= _primary_fire_buffered_until:
		var buffered_direction: Vector2 = _primary_fire_buffered_direction if _primary_fire_buffered_direction.length() > 0.0 else aim_direction
		if buffered_direction.length() > 0.0:
			_fire_primary(now, buffered_direction.normalized())
	elif _primary_fire_buffered_until > 0.0 and now > _primary_fire_buffered_until:
		_primary_fire_buffered_until = 0.0
	_fire_pressed_last_frame = fire_pressed

	var secondary_pressed := _is_secondary_pressed()
	if _uses_hold_to_aim_secondary():
		if secondary_pressed and not _secondary_pressed_last_frame and _can_activate_secondary():
			_secondary_hold_active = true
		elif not secondary_pressed and _secondary_pressed_last_frame and _secondary_hold_active:
			_fire_secondary()
			_secondary_hold_active = false
	elif secondary_pressed and not _secondary_pressed_last_frame and _can_activate_secondary():
		_fire_secondary()
	_secondary_pressed_last_frame = secondary_pressed

	if is_dash_active() and now >= _next_dash_trail_at:
		_next_dash_trail_at = now + 0.045
		dash_trail_requested.emit(global_position + Vector2(0.0, -10.0), player_config.tint)

	velocity = _dash.get_velocity(move_input, aim_direction, move_speed, now)
	move_and_slide()
	_update_animation_state(move_input, delta)
	_apply_visual_state(now, delta)

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

func _is_switch_primary_pressed() -> bool:
	match player_config.control_source:
		"keyboard":
			return _is_keyboard_switch_primary_pressed()
		"gamepad":
			return _is_gamepad_switch_primary_pressed()
		"hybrid":
			return _is_keyboard_switch_primary_pressed() or _is_gamepad_switch_primary_pressed()
		_:
			return _is_keyboard_switch_primary_pressed()

func _is_switch_secondary_pressed() -> bool:
	match player_config.control_source:
		"keyboard":
			return _is_keyboard_switch_secondary_pressed()
		"gamepad":
			return _is_gamepad_switch_secondary_pressed()
		"hybrid":
			return _is_keyboard_switch_secondary_pressed() or _is_gamepad_switch_secondary_pressed()
		_:
			return _is_keyboard_switch_secondary_pressed()

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

func _is_keyboard_switch_primary_pressed() -> bool:
	match player_id:
		1:
			return Input.is_physical_key_pressed(KEY_Q)
		2:
			return Input.is_physical_key_pressed(KEY_T)
		_:
			return false

func _is_keyboard_switch_secondary_pressed() -> bool:
	match player_id:
		1:
			return Input.is_physical_key_pressed(KEY_E)
		2:
			return Input.is_physical_key_pressed(KEY_Y)
		_:
			return false

func _is_gamepad_dash_pressed() -> bool:
	if gamepad_device_id < 0:
		return false
	if not Input.get_connected_joypads().has(gamepad_device_id):
		return false
	return Input.is_joy_button_pressed(gamepad_device_id, JOY_BUTTON_B)

func _is_gamepad_switch_primary_pressed() -> bool:
	if gamepad_device_id < 0:
		return false
	if not Input.get_connected_joypads().has(gamepad_device_id):
		return false
	return Input.is_joy_button_pressed(gamepad_device_id, JOY_BUTTON_RIGHT_SHOULDER)

func _is_gamepad_switch_secondary_pressed() -> bool:
	if gamepad_device_id < 0:
		return false
	if not Input.get_connected_joypads().has(gamepad_device_id):
		return false
	return Input.is_joy_button_pressed(gamepad_device_id, JOY_BUTTON_LEFT_SHOULDER)

func _choose_stronger_vector(primary: Vector2, secondary: Vector2) -> Vector2:
	return secondary if secondary.length() > primary.length() else primary

func _normalize_slot_loadout_array(slot_entries: Variant) -> Array:
	var normalized: Array = []
	if not (slot_entries is Array):
		return normalized
	for slot_entry in slot_entries:
		if slot_entry is Dictionary:
			normalized.append((slot_entry as Dictionary).duplicate(true))
		else:
			normalized.append(null)
	return normalized

func _get_selected_primary_slot() -> Dictionary:
	return _get_slot_loadout(_primary_slots, _selected_primary_index)

func _get_selected_secondary_slot() -> Dictionary:
	return _get_slot_loadout(_secondary_slots, _selected_secondary_index)

func _get_slot_loadout(slot_group: Array, slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= slot_group.size():
		return {}
	var slot_entry: Variant = slot_group[slot_index]
	if not (slot_entry is Dictionary):
		return {}
	return (slot_entry as Dictionary).duplicate(true)

func _build_slot_hud_data(slot_group: Array, slot_index: int, is_secondary: bool) -> Dictionary:
	var slot_loadout: Dictionary = _get_slot_loadout(slot_group, slot_index)
	if slot_loadout.is_empty():
		return {
			"weapon_id": "",
			"name": "---",
			"level": 0,
			"selected": false,
			"cooldown_remaining": 0.0,
			"cooldown_duration": 0.0,
		}
	var selected_index: int = _selected_secondary_index if is_secondary else _selected_primary_index
	var cooldown_duration: float = float(slot_loadout.get("secondary_cooldown", 0.0)) if is_secondary else 0.0
	var cooldown_remaining: float = _get_secondary_cooldown_remaining_for_slot(slot_index) if is_secondary else 0.0
	return {
		"weapon_id": str(slot_loadout.get("weapon_id", "")),
		"name": str(slot_loadout.get("primary_profile_name", slot_loadout.get("secondary_profile_name", "Weapon"))),
		"level": int(slot_loadout.get("weapon_level", 1)),
		"selected": slot_index == selected_index,
		"cooldown_remaining": cooldown_remaining,
		"cooldown_duration": cooldown_duration,
	}

func _get_secondary_cooldown_remaining_for_slot(slot_index: int) -> float:
	if slot_index < 0 or slot_index >= _secondary_cooldowns.size():
		return 0.0
	return max(float(_secondary_cooldowns[slot_index]) - _current_time_seconds(), 0.0)

func _resolve_selected_slot_index(slot_group: Array, selected_index: int) -> int:
	if slot_group.is_empty():
		return selected_index
	if selected_index >= 0 and selected_index < slot_group.size() and slot_group[selected_index] is Dictionary:
		return selected_index
	for slot_index in range(slot_group.size()):
		if slot_group[slot_index] is Dictionary:
			return slot_index
	return clampi(selected_index, 0, max(slot_group.size() - 1, 0))

func _apply_selected_slot_state() -> void:
	var primary_slot: Dictionary = _get_selected_primary_slot()
	_primary_weapon_id = str(primary_slot.get("weapon_id", "rifle"))
	_primary_profile_name = str(primary_slot.get("primary_profile_name", "Rifle"))
	_primary_projectile_count = max(1, int(primary_slot.get("primary_projectile_count", 1)))
	_primary_spread_radians = float(primary_slot.get("primary_spread_radians", 0.0))
	_primary_feedback_profile = str(primary_slot.get("feedback_profile", "rifle"))
	_primary_impact_weight = float(primary_slot.get("impact_weight", 1.0))
	primary_fire_interval = float(primary_slot.get("primary_fire_interval", 0.27))
	projectile_speed = float(primary_slot.get("projectile_speed", 540.0))
	projectile_damage = max(1, int(primary_slot.get("projectile_damage", 1)))
	_weapon_texture = _get_weapon_texture_for_primary_id(_primary_weapon_id)

	var secondary_slot: Dictionary = _get_selected_secondary_slot()
	_secondary_profile_name = str(secondary_slot.get("secondary_profile_name", "Mine"))
	_secondary_projectile_count = max(1, int(secondary_slot.get("secondary_projectile_count", 1)))
	_secondary_spread_radians = float(secondary_slot.get("secondary_spread_radians", 0.0))
	_secondary_feedback_profile = str(secondary_slot.get("feedback_profile", "mine"))
	_secondary_impact_weight = float(secondary_slot.get("impact_weight", 1.6))
	secondary_cooldown = float(secondary_slot.get("secondary_cooldown", 4.0))
	secondary_projectile_speed = float(secondary_slot.get("secondary_projectile_speed", 0.0))
	secondary_damage = max(1, int(secondary_slot.get("secondary_damage", 3)))
	_secondary_projectile_data = {
		"kind": str(secondary_slot.get("secondary_projectile_kind", "mine")),
		"explosion_radius": float(secondary_slot.get("secondary_explosion_radius", 92.0)),
		"fuse_time": float(secondary_slot.get("secondary_fuse_time", 12.0)),
		"gravity_force": float(secondary_slot.get("secondary_gravity_force", 0.0)),
		"pulse_count": int(secondary_slot.get("secondary_pulse_count", 1)),
		"pulse_interval": float(secondary_slot.get("secondary_pulse_interval", 0.18)),
		"cluster_blast_count": int(secondary_slot.get("secondary_cluster_blast_count", 0)),
		"cluster_spread_radius": float(secondary_slot.get("secondary_cluster_spread_radius", 52.0)),
		"proximity_radius": float(secondary_slot.get("secondary_proximity_radius", 52.0)),
		"feedback_profile": _secondary_feedback_profile,
		"impact_weight": _secondary_impact_weight,
	}

func _cycle_primary_slot() -> void:
	var next_index := _find_next_filled_slot_index(_primary_slots, _selected_primary_index)
	if next_index == _selected_primary_index:
		return
	_selected_primary_index = next_index
	_sync_inventory_selection()
	_apply_selected_slot_state()

func _cycle_secondary_slot() -> void:
	var next_index := _find_next_filled_slot_index(_secondary_slots, _selected_secondary_index)
	if next_index == _selected_secondary_index:
		return
	_selected_secondary_index = next_index
	_secondary_hold_active = false
	_sync_inventory_selection()
	_apply_selected_slot_state()

func _find_next_filled_slot_index(slot_group: Array, current_index: int) -> int:
	if slot_group.is_empty():
		return current_index
	for offset in range(1, slot_group.size() + 1):
		var candidate_index: int = (current_index + offset) % slot_group.size()
		if slot_group[candidate_index] is Dictionary:
			return candidate_index
	return current_index

func _sync_inventory_selection() -> void:
	if player_index < 0 or player_index >= RunState.player_inventories.size():
		return
	var inventory = RunState.player_inventories[player_index]
	if inventory == null:
		return
	inventory.selected_primary = _selected_primary_index
	inventory.selected_secondary = _selected_secondary_index

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

func _apply_visual_state(now: float, delta: float = 0.0) -> void:
	if visual == null or aim_pivot == null or aim_line == null or aim_line_backdrop == null or body_root == null:
		return
	var dash_active: bool = _dash != null and _dash.is_active(now)
	var dash_shield_active: bool = now < _shield_until
	var shield_remaining_ratio: float = clamp((_shield_until - now) / DASH_SHIELD_DURATION, 0.0, 1.0)
	var downed_pulse: float = 0.5 + 0.5 * sin(now * 6.0)
	var use_sprite: bool = _uses_sprite_visual()
	var fill_tint: Color = player_config.tint.darkened(0.45) if _is_downed else player_config.tint
	fill_tint.a = 0.56 + 0.24 * downed_pulse if _is_downed else 1.0
	if delta > 0.0:
		_outline_pulse = move_toward(_outline_pulse, 1.0, delta * 5.0)
	var dash_scale: float = 1.15 if dash_active else 1.0
	var move_stretch: float = clamp(velocity.length() / max(move_speed, 1.0), 0.0, 1.0) * 0.06
	var squash_x: float = 1.0 + _turn_squash * 0.18 - move_stretch * 0.03
	var squash_y: float = 1.0 - _turn_squash * 0.12 + move_stretch
	var scaled_visual: Vector2 = Vector2(_base_visual_scale.x * dash_scale * squash_x, _base_visual_scale.y * dash_scale * squash_y)
	visual.visible = not use_sprite
	if visual.visible:
		visual.color = fill_tint
		visual.scale = scaled_visual
	if outline != null:
		outline.visible = not use_sprite
		if outline.visible:
			outline.polygon = visual.polygon
			outline.scale = scaled_visual * 1.28 * _outline_pulse
			var outline_color := Color(0.04, 0.06, 0.08, 0.92)
			outline_color.a = 0.52 + 0.28 * downed_pulse if _is_downed else 0.92
			outline.color = outline_color
	if sprite_visual != null:
		sprite_visual.visible = use_sprite
		if sprite_visual.visible:
			sprite_visual.texture = _get_active_sprite_texture(now)
			var sprite_scale_x := _base_sprite_scale.x * dash_scale * squash_x
			if _sprite_facing_left:
				sprite_scale_x *= -1.0
			sprite_visual.scale = Vector2(sprite_scale_x, _base_sprite_scale.y * dash_scale * squash_y)
			var sprite_modulate := Color(1.0, 1.0, 1.0, 1.0)
			sprite_modulate.a = 0.56 + 0.24 * downed_pulse if _is_downed else 1.0
			sprite_visual.modulate = sprite_modulate
	if shadow != null:
		shadow.scale = Vector2(
			_base_shadow_scale.x * (1.0 + _turn_squash * 0.08),
			_base_shadow_scale.y * (1.0 - _turn_squash * 0.05)
		)
		var shadow_modulate: Color = shadow.modulate
		shadow_modulate.a = 0.1 + 0.14 * downed_pulse if _is_downed else 0.25
		shadow.modulate = shadow_modulate
	if dash_shield_ring != null:
		dash_shield_ring.visible = dash_shield_active and not _is_downed
		if dash_shield_ring.visible:
			var shield_pulse: float = 0.88 + 0.12 * sin(now * 14.0)
			dash_shield_ring.width = 3.5 + 2.0 * shield_remaining_ratio
			dash_shield_ring.scale = Vector2.ONE * (0.92 + 0.16 * shield_pulse)
			var shield_color: Color = player_config.tint.lerp(Color(0.9, 1.0, 1.0, 1.0), 0.45)
			shield_color.a = 0.42 + 0.28 * shield_remaining_ratio
			dash_shield_ring.default_color = shield_color
	var lean_target: float = 0.0 if _is_downed else clamp(_display_move_input.x, -1.0, 1.0) * 0.16
	body_root.rotation = lerp_angle(body_root.rotation, lean_target, 0.18)
	aim_pivot.rotation = aim_direction.angle()
	aim_pivot.position = Vector2(-_aim_line_recoil * 0.2, 0.0)
	if weapon_sprite != null:
		weapon_sprite.visible = use_sprite and _weapon_texture != null
		if weapon_sprite.visible:
			weapon_sprite.texture = _weapon_texture
			var weapon_scale_mult: float = 2.0 if _primary_weapon_id == "slug" else 1.0
			weapon_sprite.scale = Vector2(
				_base_weapon_scale.x * weapon_scale_mult,
				(-_base_weapon_scale.y if aim_direction.x < 0.0 else _base_weapon_scale.y) * weapon_scale_mult
			)
	aim_line_backdrop.visible = false
	aim_line.visible = false
	_update_secondary_preview(now)

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _enter_downed_state() -> void:
	_is_downed = true
	_shield_until = 0.0
	if _dash != null:
		_dash.clear_buffer()
	velocity = Vector2.ZERO
	_secondary_hold_active = false
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	downed.emit(self)
	_apply_visual_state(_current_time_seconds())

func _update_animation_state(move_input: Vector2, delta: float) -> void:
	if move_input.length() > 0.2 and _previous_move_input.length() > 0.2 and move_input.dot(_previous_move_input) < -0.2:
		_turn_squash = 1.0
	if move_input.x <= -0.1:
		_sprite_facing_left = true
	elif move_input.x >= 0.1:
		_sprite_facing_left = false
	_sprite_is_running = velocity.length() > 20.0 or move_input.length() > 0.2
	_display_move_input = _display_move_input.lerp(move_input, clamp(delta * 10.0, 0.0, 1.0))
	_previous_move_input = move_input if move_input.length() > 0.05 else _previous_move_input.move_toward(Vector2.ZERO, delta * 5.0)
	_turn_squash = move_toward(_turn_squash, 0.0, delta * 3.8)
	_aim_line_recoil = move_toward(_aim_line_recoil, 0.0, delta * 85.0)

func _activate_dash_shield(now: float) -> void:
	_shield_until = now + DASH_SHIELD_DURATION
	dash_started.emit(global_position, player_config.tint, DASH_SHIELD_DURATION)

func _should_buffer_primary_fire(now: float) -> bool:
	if aim_direction.length() <= 0.0:
		return false
	if primary_fire_interval < SLOW_PRIMARY_BUFFER_THRESHOLD:
		return false
	var remaining: float = _next_primary_fire_at - now
	return remaining > 0.0 and remaining <= PRIMARY_FIRE_BUFFER_DURATION

func _fire_primary(now: float, fire_direction: Vector2) -> void:
	_primary_fire_buffered_until = 0.0
	_next_primary_fire_at = now + primary_fire_interval
	_play_fire_recoil(_primary_impact_weight)
	var projectile_color: Color = _get_projectile_tint()
	muzzle_flash_requested.emit(
		global_position + fire_direction * 24.0,
		fire_direction,
		projectile_color,
		_primary_feedback_profile,
		_primary_impact_weight
	)
	for projectile_direction in _build_spread_directions(fire_direction, _primary_projectile_count, _primary_spread_radians):
		fire_requested.emit(
			global_position + projectile_direction * 26.0,
			projectile_direction,
			projectile_speed,
			projectile_damage,
			get_team(),
			projectile_color,
			self,
			_primary_feedback_profile,
			_primary_impact_weight
		)

func _play_fire_recoil(intensity: float = 1.0) -> void:
	_aim_line_recoil = max(_aim_line_recoil, 9.0 + 5.0 * intensity)
	_turn_squash = max(_turn_squash, 0.24 + 0.12 * intensity)

func _play_damage_flash() -> void:
	if _get_flash_target() == null:
		return
	_outline_pulse = 1.18
	var flash_material := _get_flash_material()
	flash_material.set_shader_parameter("flash_intensity", 1.0)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(flash_material, "shader_parameter/flash_intensity", 0.0, 0.12)

func _get_flash_material() -> ShaderMaterial:
	var flash_target := _get_flash_target()
	if _flash_material != null and flash_target != null and flash_target.material == _flash_material:
		return _flash_material
	_flash_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = FLASH_SHADER_CODE
	_flash_material.shader = shader
	_flash_material.set_shader_parameter("flash_intensity", 0.0)
	_flash_material.set_shader_parameter("flash_color", Color(1.0, 0.2, 0.2, 1.0))
	if flash_target != null:
		flash_target.material = _flash_material
	return _flash_material

func _get_flash_target() -> CanvasItem:
	if _uses_sprite_visual() and sprite_visual != null:
		return sprite_visual
	return visual

func _uses_sprite_visual() -> bool:
	return player_id == 1 and sprite_visual != null and _standing_sprite_texture != null

func _get_active_sprite_texture(now: float) -> Texture2D:
	if not _sprite_is_running:
		return _standing_sprite_texture
	if _running_sprite_texture == null:
		return _standing_sprite_texture
	if _running_sprite_alt_texture == null:
		return _running_sprite_texture
	return _running_sprite_texture if int(floor(now * 8.0)) % 2 == 0 else _running_sprite_alt_texture

func _load_sprite_texture(path: String) -> Texture2D:
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		push_warning("Failed to load sprite texture: %s" % path)
		return null
	return texture

func _get_weapon_texture_for_primary_id(primary_weapon_id: String) -> Texture2D:
	var normalized_weapon_id: String = primary_weapon_id.strip_edges().to_lower()
	if _weapon_textures_by_id.has(normalized_weapon_id):
		return _weapon_textures_by_id[normalized_weapon_id] as Texture2D
	if _weapon_textures_by_id.has("rifle"):
		return _weapon_textures_by_id["rifle"] as Texture2D
	return null

func _update_secondary_preview(now: float) -> void:
	if secondary_preview == null or secondary_trajectory == null or secondary_target_ring == null or secondary_target_cross == null:
		return

	var show_preview := _should_show_secondary_preview(now)
	secondary_preview.visible = show_preview
	secondary_trajectory.visible = show_preview
	secondary_target_ring.visible = show_preview
	secondary_target_cross.visible = show_preview
	if not show_preview:
		return

	var preview_tint: Color = _get_projectile_tint()
	var trajectory_tint: Color = preview_tint
	trajectory_tint.a = 0.95
	var ring_tint: Color = preview_tint
	ring_tint.a = 0.82
	var cross_tint: Color = preview_tint
	cross_tint.a = 0.95
	secondary_trajectory.default_color = trajectory_tint
	secondary_target_ring.default_color = ring_tint
	secondary_target_cross.default_color = cross_tint

	var origin_offset: Vector2 = aim_direction.normalized() * 22.0
	var initial_velocity: Vector2 = aim_direction.normalized() * secondary_projectile_speed + Vector2(0.0, -180.0)
	var gravity_force: float = float(_secondary_projectile_data.get("gravity_force", 520.0))
	var fuse_time: float = float(_secondary_projectile_data.get("fuse_time", 1.0))
	var explosion_radius: float = float(_secondary_projectile_data.get("explosion_radius", 92.0))

	var trajectory_points: Array = []
	var sample_count := 9
	for index in range(sample_count):
		var t := fuse_time * float(index) / float(sample_count - 1)
		trajectory_points.append(origin_offset + initial_velocity * t + Vector2(0.0, 0.5 * gravity_force * t * t))
	secondary_trajectory.points = PackedVector2Array(trajectory_points)

	var landing_local: Vector2 = origin_offset + initial_velocity * fuse_time + Vector2(0.0, 0.5 * gravity_force * fuse_time * fuse_time)
	secondary_target_ring.points = _build_circle_points(landing_local, explosion_radius, 28)
	secondary_target_cross.points = PackedVector2Array([
		landing_local + Vector2(-12, 0),
		landing_local + Vector2(12, 0),
		landing_local,
		landing_local + Vector2(0, -12),
		landing_local + Vector2(0, 12),
	])

func _build_circle_points(center: Vector2, radius: float, point_count: int) -> PackedVector2Array:
	var points: Array = []
	for index in range(point_count):
		var angle := TAU * float(index) / float(point_count)
		points.append(center + Vector2.RIGHT.rotated(angle) * radius)
	return PackedVector2Array(points)

func _should_show_secondary_preview(_now: float) -> bool:
	if _is_downed:
		return false
	if _is_proximity_mine_secondary():
		return false
	if aim_direction.length() <= 0.0:
		return false
	if get_secondary_cooldown_remaining() > 0.0:
		return false
	if not _supports_secondary_preview():
		return false
	return _secondary_hold_active and _is_secondary_pressed()

func _uses_hold_to_aim_secondary() -> bool:
	return _supports_secondary_preview()

func _supports_secondary_preview() -> bool:
	return not _is_proximity_mine_secondary()

func _is_proximity_mine_secondary() -> bool:
	var kind := str(_secondary_projectile_data.get("kind", ""))
	return kind == "mine" or kind == "shrapnel_mine" or kind == "heavy_mine" or kind == "cluster_mine" or kind == "siege_mine"

func _can_activate_secondary() -> bool:
	if get_secondary_cooldown_remaining() > 0.0:
		return false
	if _is_proximity_mine_secondary():
		return true
	return aim_direction.length() > 0.0

func _fire_secondary() -> void:
	var now := _current_time_seconds()
	if not _can_activate_secondary():
		return
	if _selected_secondary_index >= 0 and _selected_secondary_index < _secondary_cooldowns.size():
		_secondary_cooldowns[_selected_secondary_index] = now + secondary_cooldown
	var secondary_color: Color = _get_projectile_tint()
	var secondary_direction: Vector2 = aim_direction.normalized() if aim_direction.length() > 0.0 else Vector2.RIGHT
	var spawn_origin: Vector2 = global_position + secondary_direction * 14.0 if _is_proximity_mine_secondary() else global_position
	for projectile_direction in _build_spread_directions(secondary_direction, _secondary_projectile_count, _secondary_spread_radians):
		secondary_requested.emit(
			spawn_origin if _is_proximity_mine_secondary() else global_position + projectile_direction * 22.0,
			projectile_direction,
			secondary_projectile_speed,
			secondary_damage,
			get_team(),
			_secondary_projectile_data.duplicate(true),
			secondary_color
		)
