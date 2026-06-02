extends CharacterBody2D

const PlayerConfigData = preload("res://scripts/player/PlayerConfig.gd")
const AutoTargetData = preload("res://scripts/player/AutoTarget.gd")
const DashData = preload("res://scripts/player/Dash.gd")
const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")

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
signal ability_activated(player, slot_index, ability_id, origin, direction, stats)
signal health_changed(current_health, max_health)
signal downed(player)
signal revived(player)
signal muzzle_flash_requested(origin, direction, color, feedback_profile, impact_weight)
signal damage_taken(player, amount, current_health)

@export_range(1, 4, 1) var player_id: int = 1
@export var move_speed: float = 390.0
@export var max_health: int = 50
@export var weapon_fire_interval: float = 0.25
@export var projectile_speed: float = 850.0
@export var projectile_damage: int = 16

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
var _input_locked := false
var _is_downed := false
var _move_facing := Vector2.RIGHT
var _auto_attack_direction := Vector2.RIGHT
var _auto_target: Node2D = null
var _next_weapon_fire_at := 0.0
var _weapon_id := "rifle"
var _weapon_profile_name := "Rifle"
var _weapon_range := 950.0
var _weapon_area := 4.0
var _weapon_feedback_profile := "rifle"
var _weapon_impact_weight := 1.0
var _weapon_stats: Dictionary = {}
var _ability_slots: Array = []
var _ability_pressed_last_frame := [false, false]
var _dash_states: Dictionary = {}
var _active_dash_slot_index := -1
var _shield_until := 0.0
var _invisible_until := 0.0
var _external_impulse := Vector2.ZERO
var _mutation_ids: Array = []
var _base_move_speed: float = 390.0
var _base_max_health: int = 50
var _base_weapon_fire_interval: float = 0.25
var _base_projectile_damage: int = 16
var _modifier_move_speed_sources: Dictionary = {}
var _modifier_attack_speed_sources: Dictionary = {}
var _modifier_damage_sources: Dictionary = {}
var _buff_move_speed: float = 1.0
var _buff_attack_speed: float = 1.0
var _buff_damage: float = 1.0
var _base_visual_scale := Vector2.ONE
var _base_shadow_scale := Vector2.ONE
var _next_speed_line_at := 0.0
var _next_reflex_particle_at := 0.0
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

func get_team() -> String:
	return "player"

func is_alive() -> bool:
	return not _is_downed and current_health > 0

func is_downed() -> bool:
	return _is_downed

func is_targetable() -> bool:
	return is_alive() and _current_time_seconds() >= _invisible_until

func get_health_ratio_text() -> String:
	return "DOWN" if _is_downed else "%d/%d" % [current_health, max_health]

func get_health_state() -> Dictionary:
	return {"current": current_health, "max": max_health}

func get_weapon_profile_name() -> String:
	return _weapon_profile_name

func get_primary_skill_profile_name() -> String:
	var ability_data := get_ability_hud_data(0)
	return str(ability_data.get("name", "Ability"))

func get_weapon_hud_data() -> Dictionary:
	return {
		"weapon_id": _weapon_id,
		"name": _weapon_profile_name,
	}

func get_primary_skill_hud_data() -> Dictionary:
	return get_ability_hud_data(0)

func get_secondary_skill_hud_data() -> Dictionary:
	return get_ability_hud_data(1)

func get_ability_hud_data(slot_index: int) -> Dictionary:
	var slot := _get_ability_slot(slot_index)
	return {
		"skill_id": str(slot.get("id", "")),
		"name": str(slot.get("name", "Ability")),
		"cooldown_remaining": get_ability_cooldown_remaining(slot_index),
		"cooldown_duration": float(slot.get("cooldown", 1.0)),
	}

func get_mutation_ids() -> Array:
	return _mutation_ids.duplicate()

func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	if locked:
		for dash_state in _dash_states.values():
			(dash_state as DashData).clear_buffer()
		velocity = Vector2.ZERO
	_auto_target = null
	_ability_pressed_last_frame = [false, false]

func apply_loadout(loadout: Dictionary) -> void:
	_mutation_ids = (loadout.get("mutations", []) as Array).duplicate()
	_base_move_speed = float(loadout.get("move_speed", move_speed))
	_base_max_health = max(1, int(loadout.get("max_health", max_health)))
	max_health = _base_max_health
	current_health = clampi(current_health, 0, max_health)
	if current_health <= 0 and not _is_downed:
		current_health = max_health
	_weapon_id = str(loadout.get("weapon_id", "rifle"))
	_weapon_profile_name = str(loadout.get("weapon_name", "Rifle"))
	_weapon_stats = (loadout.get("weapon_stats", {}) as Dictionary).duplicate(true)
	_base_projectile_damage = int(round(float(_weapon_stats.get("damage", projectile_damage))))
	_base_weapon_fire_interval = 1.0 / max(float(_weapon_stats.get("fire_rate", 4.0)), 0.01)
	projectile_speed = float(_weapon_stats.get("projectile_speed", projectile_speed))
	_weapon_range = float(_weapon_stats.get("range", _weapon_range))
	_weapon_area = float(_weapon_stats.get("area", _weapon_area))
	_ability_slots = [
		_build_runtime_ability((loadout.get("ability_slot_1", {}) as Dictionary).duplicate(true), str(loadout.get("ability_slot_1_id", "shockwave"))),
		_build_runtime_ability((loadout.get("ability_slot_2", {}) as Dictionary).duplicate(true), str(loadout.get("ability_slot_2_id", "dash")))
	]
	_dash_states.clear()
	for slot_index in range(_ability_slots.size()):
		var slot: Dictionary = _ability_slots[slot_index]
		if str(slot.get("id", "")) == "dash":
			var dash_state := DashData.new()
			dash_state.dash_duration = max(0.05, float((slot.get("stats", {}) as Dictionary).get("duration", slot.get("duration", 0.2))))
			dash_state.cooldown_duration = max(0.1, float(slot.get("cooldown", 3.0)))
			dash_state.dash_speed = float((slot.get("stats", {}) as Dictionary).get("dash_speed", 1180.0))
			_dash_states[slot_index] = dash_state
	_ability_pressed_last_frame = [false, false]
	_shield_until = 0.0
	_invisible_until = 0.0
	_external_impulse = Vector2.ZERO
	_next_speed_line_at = 0.0
	_next_reflex_particle_at = 0.0
	_recompute_effective_stats()
	health_changed.emit(current_health, max_health)

func apply_zone_modifier(source: String, move_mult: float, attack_mult: float, damage_mult: float = 1.0) -> void:
	_modifier_move_speed_sources[source] = move_mult
	_modifier_attack_speed_sources[source] = attack_mult
	if damage_mult != 1.0:
		_modifier_damage_sources[source] = damage_mult
	_recompute_effective_stats()

func clear_zone_modifier(source: String) -> void:
	_modifier_move_speed_sources.erase(source)
	_modifier_attack_speed_sources.erase(source)
	_modifier_damage_sources.erase(source)
	_recompute_effective_stats()

func apply_temp_buff(buff_type: String, value: float) -> void:
	match buff_type:
		"speed":
			_buff_move_speed = 1.0 + value
		"damage":
			_buff_damage = 1.0 + value
		"attack_speed":
			_buff_attack_speed = 1.0 + value
	_recompute_effective_stats()

func clear_temp_buffs() -> void:
	_buff_move_speed = 1.0
	_buff_attack_speed = 1.0
	_buff_damage = 1.0
	_recompute_effective_stats()

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

func heal(amount: int) -> bool:
	if amount <= 0 or _is_downed or current_health >= max_health:
		return false
	current_health = clampi(current_health + amount, 0, max_health)
	health_changed.emit(current_health, max_health)
	return true

func apply_damage(amount: int) -> void:
	if _is_downed or amount <= 0:
		return
	if _is_damage_immune(_current_time_seconds()):
		return
	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	damage_taken.emit(self, amount, current_health)
	_play_damage_flash()
	if current_health <= 0:
		_enter_downed_state()

func can_receive_damage() -> bool:
	return not _is_downed and not _is_damage_immune(_current_time_seconds())

func apply_knockback(direction: Vector2, force: float) -> void:
	apply_impulse(direction, force)

func apply_impulse(direction: Vector2, force: float) -> void:
	if force <= 0.0:
		return
	var normalized := direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT
	_external_impulse += normalized * force * 0.0022

func get_primary_skill_cooldown_remaining() -> float:
	return get_ability_cooldown_remaining(0)

func get_secondary_skill_cooldown_remaining() -> float:
	return get_ability_cooldown_remaining(1)

func get_ability_cooldown_remaining(slot_index: int) -> float:
	var slot := _get_ability_slot(slot_index)
	var ability_id := str(slot.get("id", ""))
	var now := _current_time_seconds()
	if ability_id == "dash" and _dash_states.has(slot_index):
		return (_dash_states[slot_index] as DashData).get_cooldown_remaining(now)
	return max(float(slot.get("cooldown_until", 0.0)) - now, 0.0)

func is_secondary_skill_active() -> bool:
	return _is_slot_active(1, _current_time_seconds())

func is_secondary_skill_shield_active() -> bool:
	return _is_damage_immune(_current_time_seconds())

func _physics_process(delta: float) -> void:
	var now := _current_time_seconds()
	_update_buffered_dashes(now)
	if _input_locked or _is_downed:
		velocity = Vector2.ZERO
		move_and_slide()
		_apply_visual_state(now, delta)
		return

	var move_input := _get_move_input()
	if move_input.length() > 0.0:
		_move_facing = move_input.normalized()
	if _external_impulse.length() > 0.0:
		_external_impulse = _external_impulse.move_toward(Vector2.ZERO, delta * 12.0)

	_auto_target = _find_auto_target()
	if _auto_target != null:
		_auto_attack_direction = (_auto_target.global_position - global_position).normalized()
	if _can_attack(now) and _auto_target != null and now >= _next_weapon_fire_at:
		_fire_weapon(now, _auto_attack_direction)

	for slot_index in range(2):
		var slot_pressed := _is_ability_pressed(slot_index)
		if slot_pressed and not bool(_ability_pressed_last_frame[slot_index]):
			_try_activate_ability(slot_index, now)
		_ability_pressed_last_frame[slot_index] = slot_pressed

	velocity = _get_current_velocity(move_input, now)
	move_and_slide()
	_emit_movement_feedback(now, move_input)
	_emit_reflex_feedback(now)
	_apply_visual_state(now, delta)

func _find_auto_target() -> Node2D:
	return _auto_targeter.find_nearest(self, _weapon_range)

func _build_runtime_ability(definition: Dictionary, fallback_id: String) -> Dictionary:
	var ability_id := str(definition.get("id", fallback_id))
	var stats: Dictionary = (definition.get("stats", {}) as Dictionary).duplicate(true)
	stats["duration"] = float(definition.get("duration", 0.0))
	return {
		"id": ability_id,
		"name": str(definition.get("name", ability_id.capitalize())),
		"type": str(definition.get("type", "instant")),
		"cooldown": float(definition.get("cooldown", 1.0)),
		"duration": float(definition.get("duration", 0.0)),
		"cooldown_until": 0.0,
		"active_until": 0.0,
		"stats": stats,
	}

func _get_ability_slot(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= _ability_slots.size():
		return {}
	return _ability_slots[slot_index]

func _set_ability_slot(slot_index: int, slot: Dictionary) -> void:
	if slot_index < 0 or slot_index >= _ability_slots.size():
		return
	_ability_slots[slot_index] = slot

func _update_buffered_dashes(now: float) -> void:
	for slot_index_variant in _dash_states.keys():
		var slot_index := int(slot_index_variant)
		var dash_state := _dash_states[slot_index] as DashData
		if dash_state.consume_buffer_if_ready(now):
			_on_dash_started(slot_index, now)

func _get_current_velocity(move_input: Vector2, now: float) -> Vector2:
	for slot_index_variant in _dash_states.keys():
		var slot_index := int(slot_index_variant)
		var dash_state := _dash_states[slot_index] as DashData
		if dash_state.is_active(now):
			_active_dash_slot_index = slot_index
			return dash_state.get_velocity(move_input, _move_facing, move_speed, now) + _external_impulse
	_active_dash_slot_index = -1
	return move_input * move_speed + _external_impulse

func _is_damage_immune(now: float) -> bool:
	if now < _shield_until:
		return true
	for dash_state in _dash_states.values():
		if (dash_state as DashData).is_active(now):
			return true
	return false

func _can_attack(now: float) -> bool:
	return not _is_slot_active_by_id("shield", now) and not _is_downed

func _fire_weapon(now: float, fire_direction: Vector2) -> void:
	var rapid_fire_level := _get_mutation_level("rapid_fire")
	var velocity_level := _get_mutation_level("velocity")
	var knockback_level := _get_mutation_level("knockback")
	var muzzle_weight := _weapon_impact_weight
	if rapid_fire_level >= 3:
		muzzle_weight += 0.28
	if _is_slot_active_by_id("overcharge", now):
		muzzle_weight += 0.2
	_next_weapon_fire_at = now + _get_current_weapon_fire_interval()
	_play_fire_recoil()
	muzzle_flash_requested.emit(global_position + fire_direction * 24.0, fire_direction, player_config.tint, _weapon_feedback_profile, muzzle_weight)
	var projectile_config := _weapon_stats.duplicate(true)
	projectile_config["weapon_id"] = _weapon_id
	projectile_config["speed"] = float(projectile_config.get("projectile_speed", projectile_speed))
	projectile_config["damage"] = projectile_damage
	projectile_config["team"] = get_team()
	projectile_config["color"] = player_config.tint
	projectile_config["shooter"] = self
	projectile_config["feedback_profile"] = _weapon_feedback_profile
	projectile_config["impact_weight"] = _weapon_impact_weight
	projectile_config["max_distance"] = float(projectile_config.get("range", _weapon_range))
	projectile_config["collision_half_width"] = float(projectile_config.get("area", _weapon_area))
	projectile_config["projectile_multiplier"] = 2 if _is_slot_active_by_id("overcharge", now) else 1
	projectile_config["rapid_fire_level"] = rapid_fire_level
	projectile_config["velocity_level"] = velocity_level
	projectile_config["knockback_level"] = knockback_level
	projectile_config["source_type"] = "weapon"
	fire_requested.emit(global_position + fire_direction * 24.0, fire_direction, projectile_config)

func _get_current_weapon_fire_interval() -> float:
	var interval := weapon_fire_interval
	if _is_slot_active_by_id("overcharge", _current_time_seconds()):
		interval *= 0.5
	return max(interval, 0.05)

func _try_activate_ability(slot_index: int, now: float) -> void:
	var slot := _get_ability_slot(slot_index)
	if slot.is_empty():
		return
	var ability_id := str(slot.get("id", ""))
	if ability_id.is_empty():
		return
	var direction := _move_facing if _move_facing.length() > 0.0 else Vector2.RIGHT
	if _auto_target != null:
		direction = _auto_attack_direction
	match ability_id:
		"dash":
			var dash_state := _dash_states.get(slot_index, null) as DashData
			if dash_state == null:
				return
			if dash_state.try_trigger(_move_facing, now):
				_on_dash_started(slot_index, now)
		"blink":
			if not _is_slot_ready(slot_index, now):
				return
			var blink_distance := float((slot.get("stats", {}) as Dictionary).get("distance", 240.0))
			global_position += (direction if direction.length() > 0.0 else Vector2.RIGHT).normalized() * blink_distance
			_set_slot_cooldown(slot_index, now)
			_emit_ability(slot_index, direction)
		"shield":
			if not _is_slot_ready(slot_index, now):
				return
			_shield_until = max(_shield_until, now + float(slot.get("duration", 3.0)))
			_set_slot_active(slot_index, now)
			_set_slot_cooldown(slot_index, now)
			_emit_ability(slot_index, direction)
		"decoy":
			if not _is_slot_ready(slot_index, now):
				return
			var invis_duration := float((slot.get("stats", {}) as Dictionary).get("invisibility_duration", 1.2))
			_invisible_until = max(_invisible_until, now + invis_duration)
			_set_slot_active(slot_index, now)
			_set_slot_cooldown(slot_index, now)
			_emit_ability(slot_index, direction)
		"overcharge", "turret", "minefield", "orbit":
			if not _is_slot_ready(slot_index, now):
				return
			_set_slot_active(slot_index, now)
			_set_slot_cooldown(slot_index, now)
			_emit_ability(slot_index, direction)
		_:
			if not _is_slot_ready(slot_index, now):
				return
			_set_slot_cooldown(slot_index, now)
			_emit_ability(slot_index, direction)

func _on_dash_started(slot_index: int, now: float) -> void:
	_shield_until = max(_shield_until, now + float((_get_ability_slot(slot_index).get("stats", {}) as Dictionary).get("invulnerability_duration", 0.2)))
	_emit_ability(slot_index, (_dash_states[slot_index] as DashData).get_direction())

func _emit_ability(slot_index: int, direction: Vector2) -> void:
	var slot := _get_ability_slot(slot_index)
	var payload: Dictionary = (slot.get("stats", {}) as Dictionary).duplicate(true)
	payload["ability_id"] = str(slot.get("id", ""))
	payload["cooldown"] = float(slot.get("cooldown", 0.0))
	payload["duration"] = float(slot.get("duration", 0.0))
	payload["color"] = player_config.tint
	payload["slot_index"] = slot_index
	payload["owner"] = self
	ability_activated.emit(self, slot_index, str(slot.get("id", "")), global_position, direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT, payload)

func _is_slot_ready(slot_index: int, now: float) -> bool:
	return get_ability_cooldown_remaining(slot_index) <= 0.0 and not _is_slot_active(slot_index, now)

func _set_slot_cooldown(slot_index: int, now: float) -> void:
	var slot := _get_ability_slot(slot_index)
	slot["cooldown_until"] = now + float(slot.get("cooldown", 0.0))
	_set_ability_slot(slot_index, slot)

func _set_slot_active(slot_index: int, now: float) -> void:
	var slot := _get_ability_slot(slot_index)
	slot["active_until"] = now + float(slot.get("duration", 0.0))
	_set_ability_slot(slot_index, slot)

func _is_slot_active(slot_index: int, now: float) -> bool:
	var slot := _get_ability_slot(slot_index)
	if slot.is_empty():
		return false
	var ability_id := str(slot.get("id", ""))
	if ability_id == "dash" and _dash_states.has(slot_index):
		return (_dash_states[slot_index] as DashData).is_active(now)
	return now < float(slot.get("active_until", 0.0))

func _is_slot_active_by_id(ability_id: String, now: float) -> bool:
	for slot_index in range(_ability_slots.size()):
		var slot: Dictionary = _ability_slots[slot_index]
		if str(slot.get("id", "")) == ability_id and _is_slot_active(slot_index, now):
			return true
	return false

func _get_move_input() -> Vector2:
	var keyboard_vector := Input.get_vector("p%d_move_left" % player_id, "p%d_move_right" % player_id, "p%d_move_up" % player_id, "p%d_move_down" % player_id)
	var gamepad_vector := _get_gamepad_stick_vector(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	return gamepad_vector if player_config.control_source == "gamepad" else keyboard_vector

func _get_gamepad_stick_vector(axis_x: JoyAxis, axis_y: JoyAxis) -> Vector2:
	if gamepad_device_id < 0 or not Input.get_connected_joypads().has(gamepad_device_id):
		return Vector2.ZERO
	var vector := Vector2(Input.get_joy_axis(gamepad_device_id, axis_x), Input.get_joy_axis(gamepad_device_id, axis_y))
	return vector if vector.length() >= 0.2 else Vector2.ZERO

func _is_ability_pressed(slot_index: int) -> bool:
	if player_config.control_source == "gamepad":
		if gamepad_device_id < 0:
			return false
		if slot_index == 0:
			return Input.get_joy_axis(gamepad_device_id, JOY_AXIS_TRIGGER_RIGHT) >= 0.5 or Input.is_joy_button_pressed(gamepad_device_id, JOY_BUTTON_X)
		return Input.get_joy_axis(gamepad_device_id, JOY_AXIS_TRIGGER_LEFT) >= 0.5 or Input.is_joy_button_pressed(gamepad_device_id, JOY_BUTTON_B)
	return Input.is_action_pressed("p%d_secondary" % player_id) if slot_index == 0 else Input.is_action_pressed("p%d_dash" % player_id)

func _enter_downed_state() -> void:
	_is_downed = true
	velocity = Vector2.ZERO
	_shield_until = 0.0
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	downed.emit(self)

func _apply_visual_state(now: float, delta: float = 0.0) -> void:
	if visual == null or body_root == null:
		return
	var dash_active := _active_dash_slot_index >= 0 and _is_slot_active(_active_dash_slot_index, now)
	var shield_active := now < _shield_until
	var overcharge_active := _is_slot_active_by_id("overcharge", now)
	var tough_level := _get_mutation_level("tough")
	var mutation_glow := clampf(float(_mutation_ids.size()) / 18.0, 0.0, 0.5)
	var bonus_glow := float(max(tough_level - 1, 0)) * 0.1 + (0.18 if overcharge_active else 0.0)
	var dash_scale := 1.14 if dash_active else 1.0
	var squash_x := 1.0 + _turn_squash * 0.18
	var squash_y := 1.0 - _turn_squash * 0.12
	if visual.polygon != _chevron_polygon:
		visual.polygon = _chevron_polygon
	visual.color = player_config.tint.lightened(mutation_glow + bonus_glow) if not _is_downed else player_config.tint.darkened(0.55)
	visual.modulate.a = 0.45 if now < _invisible_until else 1.0
	visual.scale = Vector2(_base_visual_scale.x * dash_scale * squash_x, _base_visual_scale.y * dash_scale * squash_y)
	if outline != null and outline.polygon != _chevron_polygon:
		outline.polygon = _chevron_polygon
	if outline != null:
		outline.scale = visual.scale * 1.28
		outline.color = player_config.tint.lightened(0.2 + mutation_glow * 0.4 + bonus_glow * 0.5) if shield_active or overcharge_active else Color(0.04, 0.06, 0.08, 0.92)
		outline.modulate.a = 0.65 if now < _invisible_until else 1.0
	if shadow != null:
		shadow.scale = _base_shadow_scale * (1.08 if tough_level >= 2 else 1.0)
		shadow.modulate.a = 0.18 if now < _invisible_until else 1.0
	if dash_shield_ring != null:
		dash_shield_ring.visible = (shield_active or dash_active) and not _is_downed
		dash_shield_ring.default_color = player_config.tint.lerp(Color(0.92, 1.0, 1.0, 1.0), 0.42 if shield_active else 0.18)
		dash_shield_ring.width = 5.0 if tough_level >= 2 else 4.0
	body_root.rotation = lerp_angle(body_root.rotation, _move_facing.angle(), 0.22)
	_turn_squash = move_toward(_turn_squash, 0.0, delta * 4.0)

func _emit_movement_feedback(now: float, move_input: Vector2) -> void:
	if _is_downed or move_input.length() < 0.45:
		return
	var move_speed_level := _get_mutation_level("move_speed")
	if move_speed_level < 2 or now < _next_speed_line_at or get_parent() == null:
		return
	_next_speed_line_at = now + 0.12
	var trail := ParticleFactoryData.create_dash_trail(player_config.tint.lightened(0.18), 0.55 + float(move_speed_level - 1) * 0.2)
	trail.global_position = global_position - _move_facing * 14.0
	get_parent().add_child(trail)

func _emit_reflex_feedback(now: float) -> void:
	if _get_mutation_level("quick_reflexes") < 2 or now < _next_reflex_particle_at or get_parent() == null:
		return
	if get_ability_cooldown_remaining(0) <= 0.0 and get_ability_cooldown_remaining(1) <= 0.0:
		return
	_next_reflex_particle_at = now + 0.42
	var crackle_direction := _move_facing.orthogonal().normalized() if _move_facing.length() > 0.0 else Vector2.UP
	var crackle := ParticleFactoryData.create_attack_trail(player_config.tint.lightened(0.28), crackle_direction, 0.7)
	crackle.global_position = global_position
	get_parent().add_child(crackle)

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

func _get_mutation_level(mutation_id: String) -> int:
	var count := 0
	for entry in _mutation_ids:
		if str(entry) == mutation_id:
			count += 1
	return count

func _combined_modifier(sources: Dictionary) -> float:
	var result := 1.0
	for value in sources.values():
		result *= float(value)
	return result

func _recompute_effective_stats() -> void:
	move_speed = _base_move_speed * _combined_modifier(_modifier_move_speed_sources) * _buff_move_speed
	weapon_fire_interval = _base_weapon_fire_interval / (_combined_modifier(_modifier_attack_speed_sources) * _buff_attack_speed)
	projectile_damage = int(round(float(_base_projectile_damage) * _combined_modifier(_modifier_damage_sources) * _buff_damage))
