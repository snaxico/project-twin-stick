extends CharacterBody2D

const PlayerConfigData = preload("res://scripts/player/PlayerConfig.gd")
const AutoTargetData = preload("res://scripts/player/AutoTarget.gd")
const DashData = preload("res://scripts/player/Dash.gd")

const DASH_SHIELD_DURATION := 0.5
const FLASH_SHADER_CODE := """
shader_type canvas_item;

uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.2, 0.2, 1.0);

void fragment() {
	vec4 base = COLOR;
	COLOR = mix(base, flash_color, flash_intensity * flash_color.a);
}
"""

signal fire_requested(origin, direction, config)
signal shockwave_requested(origin, direction, stats)
signal health_changed(current_health, max_health)
signal downed(player)
signal revived(player)
signal muzzle_flash_requested(origin, direction, color, feedback_profile, impact_weight)
signal dash_trail_requested(origin, color)
signal dash_started(origin, color, shield_duration)
signal damage_taken(player, amount, current_health)

@export_range(1, 4, 1) var player_id: int = 1
@export var move_speed: float = 390.0
@export var max_health: int = 50
@export var primary_fire_interval: float = 0.33
@export var projectile_speed: float = 850.0
@export var projectile_damage: int = 14

@onready var shadow: Polygon2D = $Shadow
@onready var dash_shield_ring: Line2D = $DashShieldRing
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var body_root: Node2D = $BodyRoot
@onready var outline: Polygon2D = $BodyRoot/Outline
@onready var visual: Polygon2D = $BodyRoot/Visual

var player_index: int = 0
var player_config = PlayerConfigData.new()
var gamepad_device_id: int = -1
var current_health: int = 0

var _auto_targeter = AutoTargetData.new()
var _dash = DashData.new()
var _dash_pressed_last_frame := false
var _shockwave_pressed_last_frame := false
var _is_downed := false
var _input_locked := false
var _move_facing := Vector2.RIGHT
var _auto_attack_direction := Vector2.RIGHT
var _auto_target: Node2D = null
var _next_primary_fire_at := 0.0
var _dash_cooldown := 5.0
var _shockwave_cooldown_until := 0.0
var _shockwave_cooldown := 5.0
var _shockwave_radius := 250.0
var _shockwave_damage := 30
var _shockwave_knockback := 950.0
var _shockwave_expand_duration := 0.15
var _primary_weapon_id := "rifle"
var _primary_profile_name := "Rifle"
var _secondary_weapon_id := "shockwave"
var _secondary_profile_name := "Shockwave"
var _primary_range := 950.0
var _primary_area := 4.0
var _primary_feedback_profile := "rifle"
var _primary_impact_weight := 1.0
var _secondary_feedback_profile := "shockwave"
var _secondary_impact_weight := 1.9
var _mutation_ids: Array = []
var _dash_damage_enabled := false
var _dash_damage_multiplier := 0.0
var _dash_hit_targets: Array = []
var _shield_until := 0.0
var _next_dash_trail_at := 0.0
var _base_visual_scale := Vector2.ONE
var _base_shadow_scale := Vector2.ONE
var _chevron_polygon := PackedVector2Array([
	Vector2(16, 0),
	Vector2(-12, -14),
	Vector2(-6, 0),
	Vector2(-12, 14),
])
var _turn_squash := 0.0
var _flash_material: ShaderMaterial = null
var _flash_tween: Tween = null

func _ready() -> void:
	add_to_group("player_target")
	current_health = max_health
	if visual != null:
		_base_visual_scale = visual.scale
	if shadow != null:
		_base_shadow_scale = shadow.scale
	health_changed.emit(current_health, max_health)
	_apply_visual_state(_current_time_seconds())

func setup(config, assigned_gamepad_device_id: int) -> void:
	player_config = config
	player_id = config.player_id
	gamepad_device_id = assigned_gamepad_device_id

func is_dash_active() -> bool:
	return _dash.is_active(_current_time_seconds())

func is_dash_shield_active() -> bool:
	return _current_time_seconds() < _shield_until

func get_dash_cooldown_remaining() -> float:
	return _dash.get_cooldown_remaining(_current_time_seconds())

func get_team() -> String:
	return "player"

func is_alive() -> bool:
	return not _is_downed and current_health > 0

func is_downed() -> bool:
	return _is_downed

func get_health_ratio_text() -> String:
	return "DOWN" if _is_downed else "%d/%d" % [current_health, max_health]

func get_secondary_cooldown_remaining() -> float:
	return max(_shockwave_cooldown_until - _current_time_seconds(), 0.0)

func get_health_state() -> Dictionary:
	return {"current": current_health, "max": max_health}

func get_primary_profile_name() -> String:
	return _primary_profile_name

func get_secondary_profile_name() -> String:
	return _secondary_profile_name

func get_primary_hud_data() -> Dictionary:
	return {
		"weapon_id": _primary_weapon_id,
		"name": _primary_profile_name,
	}

func get_secondary_hud_data() -> Dictionary:
	return {
		"weapon_id": _secondary_weapon_id,
		"name": _secondary_profile_name,
		"cooldown_remaining": get_secondary_cooldown_remaining(),
		"cooldown_duration": _shockwave_cooldown,
	}

func get_dash_hud_data() -> Dictionary:
	return {
		"weapon_id": "dash",
		"name": "Dash",
		"cooldown_remaining": get_dash_cooldown_remaining(),
		"cooldown_duration": _dash_cooldown,
	}

func get_mutation_ids() -> Array:
	return _mutation_ids.duplicate()

func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	if locked:
		_dash.clear_buffer()
		velocity = Vector2.ZERO
	_auto_target = null
	_dash_pressed_last_frame = false
	_shockwave_pressed_last_frame = false

func apply_loadout(loadout: Dictionary) -> void:
	move_speed = float(loadout.get("move_speed", move_speed))
	_primary_weapon_id = str(loadout.get("primary_weapon_id", "rifle"))
	_primary_profile_name = str(loadout.get("primary_name", "Rifle"))
	_secondary_weapon_id = str(loadout.get("secondary_weapon_id", "shockwave"))
	_secondary_profile_name = str(loadout.get("secondary_name", "Shockwave"))
	_mutation_ids = (loadout.get("mutations", []) as Array).duplicate()
	var primary_stats: Dictionary = (loadout.get("primary_stats", {}) as Dictionary).duplicate(true)
	var secondary_stats: Dictionary = (loadout.get("secondary_stats", {}) as Dictionary).duplicate(true)
	projectile_damage = int(round(float(primary_stats.get("damage", projectile_damage))))
	primary_fire_interval = 1.0 / max(float(primary_stats.get("fire_rate", 3.0)), 0.01)
	projectile_speed = float(primary_stats.get("projectile_speed", projectile_speed))
	_primary_range = float(primary_stats.get("range", _primary_range))
	_primary_area = float(primary_stats.get("area", _primary_area))
	_dash_cooldown = max(0.25, float(secondary_stats.get("dash_cooldown", secondary_stats.get("cooldown", _dash_cooldown))))
	_shockwave_cooldown = max(0.25, float(secondary_stats.get("cooldown", _shockwave_cooldown)))
	_shockwave_radius = float(secondary_stats.get("radius", _shockwave_radius))
	_shockwave_damage = int(round(float(secondary_stats.get("damage", _shockwave_damage))))
	_shockwave_knockback = float(secondary_stats.get("knockback_force", _shockwave_knockback))
	_shockwave_expand_duration = max(0.05, float(secondary_stats.get("expand_duration", _shockwave_expand_duration)))
	_dash.cooldown_duration = _dash_cooldown
	_shockwave_cooldown_until = 0.0
	_dash_damage_multiplier = float(loadout.get("dash_damage_multiplier", 0.0))
	_dash_damage_enabled = _dash_damage_multiplier > 0.0

func set_health_state(state: Dictionary) -> void:
	max_health = int(state.get("max", max_health))
	current_health = clampi(int(state.get("current", current_health)), 0, max_health)
	if current_health <= 0:
		_enter_downed_state()
	else:
		health_changed.emit(current_health, max_health)

func revive(health_amount: int) -> void:
	_is_downed = false
	current_health = clampi(health_amount, 1, max_health)
	collision_layer = 1
	collision_mask = 1
	set_physics_process(true)
	revived.emit(self)
	health_changed.emit(current_health, max_health)

func apply_damage(amount: int) -> void:
	if _is_downed:
		return
	if is_dash_shield_active():
		return
	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	damage_taken.emit(self, amount, current_health)
	_play_damage_flash()
	if current_health <= 0:
		_enter_downed_state()

func _physics_process(delta: float) -> void:
	var now := _current_time_seconds()
	if _input_locked or _is_downed:
		velocity = Vector2.ZERO
		move_and_slide()
		_apply_visual_state(now, delta)
		return

	var move_input := _get_move_input()
	if move_input.length() > 0.0:
		_move_facing = move_input.normalized()

	_auto_target = _find_auto_target()
	if _auto_target != null:
		_auto_attack_direction = (_auto_target.global_position - global_position).normalized()
		if now >= _next_primary_fire_at:
			_fire_primary(now, _auto_attack_direction)

	var dash_pressed := _is_dash_pressed()
	if dash_pressed and not _dash_pressed_last_frame:
		if _dash.try_trigger(_move_facing, now):
			_activate_dash_shield(now, _dash.get_direction())
	_dash_pressed_last_frame = dash_pressed
	if _dash.consume_buffer_if_ready(now):
		_activate_dash_shield(now, _dash.get_direction())

	var shockwave_pressed := _is_shockwave_pressed()
	if shockwave_pressed and not _shockwave_pressed_last_frame and _can_activate_shockwave(now):
		_fire_shockwave(now)
	_shockwave_pressed_last_frame = shockwave_pressed

	if is_dash_active() and now >= _next_dash_trail_at:
		_next_dash_trail_at = now + 0.045
		dash_trail_requested.emit(global_position + Vector2(0.0, -10.0), player_config.tint)

	velocity = _dash.get_velocity(move_input, _move_facing, move_speed, now)
	move_and_slide()
	_apply_visual_state(now, delta)

func _find_auto_target() -> Node2D:
	return _auto_targeter.find_nearest(self, _primary_range)

func _activate_dash_shield(now: float, dash_direction: Vector2) -> void:
	_shield_until = now + DASH_SHIELD_DURATION
	_dash_hit_targets.clear()
	if _dash_damage_enabled:
		_apply_dash_damage(dash_direction)
	dash_started.emit(global_position, player_config.tint, DASH_SHIELD_DURATION)

func _apply_dash_damage(dash_direction: Vector2) -> void:
	var normalized_direction: Vector2 = dash_direction.normalized() if dash_direction.length() > 0.0 else Vector2.RIGHT
	var dash_end: Vector2 = global_position + normalized_direction * _dash.dash_speed * _dash.dash_duration
	var damage_amount: int = maxi(1, int(round(float(projectile_damage) * _dash_damage_multiplier)))
	for candidate in get_tree().get_nodes_in_group("aim_target"):
		if candidate == null or not is_instance_valid(candidate) or not candidate.has_method("apply_damage"):
			continue
		if _dash_hit_targets.has(candidate):
			continue
		if _distance_to_segment((candidate as Node2D).global_position, global_position, dash_end) > 42.0:
			continue
		candidate.apply_damage(damage_amount)
		_dash_hit_targets.append(candidate)

func _distance_to_segment(point: Vector2, from_point: Vector2, to_point: Vector2) -> float:
	var segment := to_point - from_point
	if segment.length_squared() <= 0.001:
		return point.distance_to(from_point)
	var weight := clampf((point - from_point).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(from_point + segment * weight)

func _fire_primary(now: float, fire_direction: Vector2) -> void:
	_next_primary_fire_at = now + primary_fire_interval
	_play_fire_recoil()
	muzzle_flash_requested.emit(global_position + fire_direction * 24.0, fire_direction, player_config.tint, _primary_feedback_profile, _primary_impact_weight)
	var projectile_config := {
		"weapon_id": _primary_weapon_id,
		"speed": projectile_speed,
		"damage": projectile_damage,
		"team": get_team(),
		"color": player_config.tint,
		"shooter": self,
		"feedback_profile": _primary_feedback_profile,
		"impact_weight": _primary_impact_weight,
		"max_distance": _primary_range,
		"collision_half_width": _primary_area,
	}
	fire_requested.emit(global_position + fire_direction * 24.0, fire_direction, projectile_config)

func _can_activate_shockwave(now: float) -> bool:
	return now >= _shockwave_cooldown_until

func _fire_shockwave(now: float) -> void:
	_shockwave_cooldown_until = now + _shockwave_cooldown
	shockwave_requested.emit(global_position, Vector2.ZERO, {
		"weapon_id": _secondary_weapon_id,
		"damage": _shockwave_damage,
		"radius": _shockwave_radius,
		"knockback_force": _shockwave_knockback,
		"expand_duration": _shockwave_expand_duration,
		"color": player_config.tint,
		"feedback_profile": _secondary_feedback_profile,
		"impact_weight": _secondary_impact_weight,
		"shooter": self,
	})

func _get_move_input() -> Vector2:
	var keyboard_vector := Input.get_vector("p%d_move_left" % player_id, "p%d_move_right" % player_id, "p%d_move_up" % player_id, "p%d_move_down" % player_id)
	var gamepad_vector := _get_gamepad_stick_vector(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	return gamepad_vector if player_config.control_source == "gamepad" else keyboard_vector

func _get_gamepad_stick_vector(axis_x: JoyAxis, axis_y: JoyAxis) -> Vector2:
	if gamepad_device_id < 0 or not Input.get_connected_joypads().has(gamepad_device_id):
		return Vector2.ZERO
	var vector := Vector2(Input.get_joy_axis(gamepad_device_id, axis_x), Input.get_joy_axis(gamepad_device_id, axis_y))
	return vector if vector.length() >= 0.2 else Vector2.ZERO

func _is_dash_pressed() -> bool:
	if player_config.control_source == "gamepad":
		if gamepad_device_id < 0:
			return false
		return Input.get_joy_axis(gamepad_device_id, JOY_AXIS_TRIGGER_LEFT) >= 0.5 or Input.is_joy_button_pressed(gamepad_device_id, JOY_BUTTON_B)
	return Input.is_action_pressed("p%d_dash" % player_id)

func _is_shockwave_pressed() -> bool:
	if player_config.control_source == "gamepad":
		return gamepad_device_id >= 0 and Input.get_joy_axis(gamepad_device_id, JOY_AXIS_TRIGGER_RIGHT) >= 0.5
	return Input.is_action_pressed("p%d_secondary" % player_id)

func _enter_downed_state() -> void:
	_is_downed = true
	velocity = Vector2.ZERO
	_shield_until = 0.0
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	downed.emit(self)

func _apply_visual_state(_now: float, delta: float = 0.0) -> void:
	if visual == null or body_root == null:
		return
	var dash_active := is_dash_active()
	var dash_scale := 1.14 if dash_active else 1.0
	var squash_x := 1.0 + _turn_squash * 0.18
	var squash_y := 1.0 - _turn_squash * 0.12
	if visual.polygon != _chevron_polygon:
		visual.polygon = _chevron_polygon
	visual.color = player_config.tint if not _is_downed else player_config.tint.darkened(0.55)
	visual.scale = Vector2(_base_visual_scale.x * dash_scale * squash_x, _base_visual_scale.y * dash_scale * squash_y)
	if outline != null and outline.polygon != _chevron_polygon:
		outline.polygon = _chevron_polygon
	if outline != null:
		outline.scale = visual.scale * 1.28
		outline.color = Color(0.04, 0.06, 0.08, 0.92)
	if shadow != null:
		shadow.scale = _base_shadow_scale
	if dash_shield_ring != null:
		dash_shield_ring.visible = is_dash_shield_active() and not _is_downed
		dash_shield_ring.default_color = player_config.tint.lerp(Color(0.92, 1.0, 1.0, 1.0), 0.38)
	body_root.rotation = lerp_angle(body_root.rotation, _move_facing.angle(), 0.22)
	_turn_squash = move_toward(_turn_squash, 0.0, delta * 4.0)

func _play_fire_recoil() -> void:
	_turn_squash = max(_turn_squash, 0.28)

func _play_damage_flash() -> void:
	var flash_material := _get_flash_material(visual)
	flash_material.set_shader_parameter("flash_intensity", 1.0)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(flash_material, "shader_parameter/flash_intensity", 0.0, 0.12)

func _get_flash_material(target: CanvasItem) -> ShaderMaterial:
	if _flash_material != null and target.material == _flash_material:
		return _flash_material
	_flash_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = FLASH_SHADER_CODE
	_flash_material.shader = shader
	target.material = _flash_material
	return _flash_material

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
