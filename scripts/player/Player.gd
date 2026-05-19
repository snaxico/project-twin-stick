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
signal primary_skill_requested(origin, direction, stats)
signal health_changed(current_health, max_health)
signal downed(player)
signal revived(player)
signal muzzle_flash_requested(origin, direction, color, feedback_profile, impact_weight)
signal secondary_skill_trail_requested(origin, color)
signal secondary_skill_started(origin, color, shield_duration)
signal damage_taken(player, amount, current_health)

@export_range(1, 4, 1) var player_id: int = 1
@export var move_speed: float = 390.0
@export var max_health: int = 50
@export var weapon_fire_interval: float = 0.33
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
var _secondary_skill_pressed_last_frame := false
var _primary_skill_pressed_last_frame := false
var _is_downed := false
var _input_locked := false
var _move_facing := Vector2.RIGHT
var _auto_attack_direction := Vector2.RIGHT
var _auto_target: Node2D = null
var _next_weapon_fire_at := 0.0
var _dash_cooldown := 5.0
var _primary_skill_cooldown_until := 0.0
var _primary_skill_cooldown := 5.0
var _primary_skill_radius := 250.0
var _primary_skill_damage := 30
var _primary_skill_knockback := 950.0
var _primary_skill_expand_duration := 0.15
var _weapon_id := "rifle"
var _weapon_profile_name := "Rifle"
var _primary_skill_id := "shockwave"
var _primary_skill_profile_name := "Shockwave"
var _weapon_range := 950.0
var _weapon_area := 4.0
var _weapon_feedback_profile := "rifle"
var _weapon_impact_weight := 1.0
var _primary_skill_feedback_profile := "shockwave"
var _primary_skill_impact_weight := 1.9
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

func is_secondary_skill_active() -> bool:
	return _dash.is_active(_current_time_seconds())

func is_secondary_skill_shield_active() -> bool:
	return _current_time_seconds() < _shield_until

func get_secondary_skill_cooldown_remaining() -> float:
	return _dash.get_cooldown_remaining(_current_time_seconds())

func get_team() -> String:
	return "player"

func is_alive() -> bool:
	return not _is_downed and current_health > 0

func is_downed() -> bool:
	return _is_downed

func get_health_ratio_text() -> String:
	return "DOWN" if _is_downed else "%d/%d" % [current_health, max_health]

func get_primary_skill_cooldown_remaining() -> float:
	return max(_primary_skill_cooldown_until - _current_time_seconds(), 0.0)

func get_health_state() -> Dictionary:
	return {"current": current_health, "max": max_health}

func get_weapon_profile_name() -> String:
	return _weapon_profile_name

func get_primary_skill_profile_name() -> String:
	return _primary_skill_profile_name

func get_weapon_hud_data() -> Dictionary:
	return {
		"weapon_id": _weapon_id,
		"name": _weapon_profile_name,
	}

func get_primary_skill_hud_data() -> Dictionary:
	return {
		"skill_id": _primary_skill_id,
		"name": _primary_skill_profile_name,
		"cooldown_remaining": get_primary_skill_cooldown_remaining(),
		"cooldown_duration": _primary_skill_cooldown,
	}

func get_secondary_skill_hud_data() -> Dictionary:
	return {
		"skill_id": "dash",
		"name": "Dash",
		"cooldown_remaining": get_secondary_skill_cooldown_remaining(),
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
	_secondary_skill_pressed_last_frame = false
	_primary_skill_pressed_last_frame = false

func apply_loadout(loadout: Dictionary) -> void:
	move_speed = float(loadout.get("move_speed", move_speed))
	_weapon_id = str(loadout.get("weapon_id", "rifle"))
	_weapon_profile_name = str(loadout.get("weapon_name", "Rifle"))
	_primary_skill_id = str(loadout.get("primary_skill_id", "shockwave"))
	_primary_skill_profile_name = str(loadout.get("primary_skill_name", "Shockwave"))
	_mutation_ids = (loadout.get("mutations", []) as Array).duplicate()
	var weapon_stats: Dictionary = (loadout.get("weapon_stats", {}) as Dictionary).duplicate(true)
	var skill_stats: Dictionary = (loadout.get("primary_skill_stats", {}) as Dictionary).duplicate(true)
	projectile_damage = int(round(float(weapon_stats.get("damage", projectile_damage))))
	weapon_fire_interval = 1.0 / max(float(weapon_stats.get("fire_rate", 3.0)), 0.01)
	projectile_speed = float(weapon_stats.get("projectile_speed", projectile_speed))
	_weapon_range = float(weapon_stats.get("range", _weapon_range))
	_weapon_area = float(weapon_stats.get("area", _weapon_area))
	_dash_cooldown = max(0.25, float(skill_stats.get("dash_cooldown", skill_stats.get("cooldown", _dash_cooldown))))
	_primary_skill_cooldown = max(0.25, float(skill_stats.get("cooldown", _primary_skill_cooldown)))
	_primary_skill_radius = float(skill_stats.get("radius", _primary_skill_radius))
	_primary_skill_damage = int(round(float(skill_stats.get("damage", _primary_skill_damage))))
	_primary_skill_knockback = float(skill_stats.get("knockback_force", _primary_skill_knockback))
	_primary_skill_expand_duration = max(0.05, float(skill_stats.get("expand_duration", _primary_skill_expand_duration)))
	_dash.cooldown_duration = _dash_cooldown
	_primary_skill_cooldown_until = 0.0
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
	if is_secondary_skill_shield_active():
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
		if now >= _next_weapon_fire_at:
			_fire_weapon(now, _auto_attack_direction)

	var dash_pressed := _is_secondary_skill_pressed()
	if dash_pressed and not _secondary_skill_pressed_last_frame:
		if _dash.try_trigger(_move_facing, now):
			_activate_dash_shield(now, _dash.get_direction())
	_secondary_skill_pressed_last_frame = dash_pressed
	if _dash.consume_buffer_if_ready(now):
		_activate_dash_shield(now, _dash.get_direction())

	var primary_skill_pressed := _is_primary_skill_pressed()
	if primary_skill_pressed and not _primary_skill_pressed_last_frame and _can_activate_primary_skill(now):
		_fire_primary_skill(now)
	_primary_skill_pressed_last_frame = primary_skill_pressed

	if is_secondary_skill_active() and now >= _next_dash_trail_at:
		_next_dash_trail_at = now + 0.045
		secondary_skill_trail_requested.emit(global_position + Vector2(0.0, -10.0), player_config.tint)

	velocity = _dash.get_velocity(move_input, _move_facing, move_speed, now)
	move_and_slide()
	_apply_visual_state(now, delta)

func _find_auto_target() -> Node2D:
	return _auto_targeter.find_nearest(self, _weapon_range)

func _activate_dash_shield(now: float, dash_direction: Vector2) -> void:
	_shield_until = now + DASH_SHIELD_DURATION
	_dash_hit_targets.clear()
	if _dash_damage_enabled:
		_apply_dash_damage(dash_direction)
	secondary_skill_started.emit(global_position, player_config.tint, DASH_SHIELD_DURATION)

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

func _fire_weapon(now: float, fire_direction: Vector2) -> void:
	_next_weapon_fire_at = now + weapon_fire_interval
	_play_fire_recoil()
	muzzle_flash_requested.emit(global_position + fire_direction * 24.0, fire_direction, player_config.tint, _weapon_feedback_profile, _weapon_impact_weight)
	var projectile_config := {
		"weapon_id": _weapon_id,
		"speed": projectile_speed,
		"damage": projectile_damage,
		"team": get_team(),
		"color": player_config.tint,
		"shooter": self,
		"feedback_profile": _weapon_feedback_profile,
		"impact_weight": _weapon_impact_weight,
		"max_distance": _weapon_range,
		"collision_half_width": _weapon_area,
	}
	fire_requested.emit(global_position + fire_direction * 24.0, fire_direction, projectile_config)

func _can_activate_primary_skill(now: float) -> bool:
	return now >= _primary_skill_cooldown_until

func _fire_primary_skill(now: float) -> void:
	_primary_skill_cooldown_until = now + _primary_skill_cooldown
	primary_skill_requested.emit(global_position, Vector2.ZERO, {
		"skill_id": _primary_skill_id,
		"damage": _primary_skill_damage,
		"radius": _primary_skill_radius,
		"knockback_force": _primary_skill_knockback,
		"expand_duration": _primary_skill_expand_duration,
		"color": player_config.tint,
		"feedback_profile": _primary_skill_feedback_profile,
		"impact_weight": _primary_skill_impact_weight,
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

func _is_secondary_skill_pressed() -> bool:
	if player_config.control_source == "gamepad":
		if gamepad_device_id < 0:
			return false
		return Input.get_joy_axis(gamepad_device_id, JOY_AXIS_TRIGGER_LEFT) >= 0.5 or Input.is_joy_button_pressed(gamepad_device_id, JOY_BUTTON_B)
	return Input.is_action_pressed("p%d_dash" % player_id)

func _is_primary_skill_pressed() -> bool:
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
	var dash_active := is_secondary_skill_active()
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
		dash_shield_ring.visible = is_secondary_skill_shield_active() and not _is_downed
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
