extends CharacterBody2D

const PlayerConfigData = preload("res://scripts/player/PlayerConfig.gd")
const AutoTargetData = preload("res://scripts/player/AutoTarget.gd")
const DashData = preload("res://scripts/player/Dash.gd")
const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")
const ClassVisualsData = preload("res://scripts/game/ClassVisuals.gd")
const CONTACT_INVULN_DURATION := 0.35
const BLOOM_COLOR_MULTIPLIER := 1.45
const MANUAL_AIM_DEADZONE := 0.35
const MOUSE_AIM_IDLE_SECONDS := 0.65
const MAX_MOMENTUM_TIER := 4
const ABILITY_SLOT_COUNT := 4
const ABILITY_FACE_BUTTONS := [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_B, JOY_BUTTON_Y]
const BLOODTHIRST_OVERSHIELD_DECAY_PER_SECOND := 15.0
const BLOODTHIRST_MAX_OVERSHIELD_RATIO := 0.12
const OVERHEAT_MAX_HEAT := 100.0
const OVERHEAT_HEAT_PER_CAST := 12.0
const OVERHEAT_DECAY_PER_SECOND := 6.0
const OVERHEAT_DECAY_DELAY := 1.5
const OVERHEAT_DAMAGE_PER_HEAT := 0.006
const OVERHEAT_VULNERABILITY_PER_HEAT := 0.0025
const OVERHEAT_ULTIMATE_HEAT_THRESHOLD := 70.0

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
signal shield_burst_requested(origin, radius, damage, color)

@export_range(1, 4, 1) var player_id: int = 1
@export var move_speed: float = 560.0
@export var max_health: int = 100
@export var weapon_fire_interval: float = 0.25
@export var projectile_speed: float = 850.0
@export var projectile_damage: int = 10

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
var _aim_facing := Vector2.RIGHT
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
var _class_id := ""
var _passive_id := ""
var _ability_slots: Array = []
var _ability_pressed_last_frame := []
var _dash_states: Dictionary = {}
var _active_dash_slot_index := -1
var _shield_until := 0.0
var _shield_was_active := false
var _pending_shield_burst: Dictionary = {}
var _dash_invuln_until := 0.0
var _invisible_until := 0.0
var _external_impulse := Vector2.ZERO
var _mutation_ids: Array = []
var _base_move_speed: float = 560.0
var _base_max_health: int = 100
var _base_weapon_fire_interval: float = 0.25
var _base_projectile_damage: int = 10
var _heal_disabled := false
var _modifier_move_speed_sources: Dictionary = {}
var _modifier_attack_speed_sources: Dictionary = {}
var _modifier_damage_sources: Dictionary = {}
var _buff_move_speed: float = 1.0
var _buff_attack_speed: float = 1.0
var _buff_damage: float = 1.0
var _momentum_tier := 0
var _momentum_move_bonus := 0.0
var _momentum_fire_rate_bonus := 0.0
var _overshield := 0.0
var _wake_heal_tokens := 0.0
var _wake_heal_capacity := 0.0
var _wake_heal_refill_per_second := 0.0
var _overheat_heat := 0.0
var _overheat_damage_bonus := 0.0
var _last_heat_gain_at := -999.0
var _ultimate_charge := 0.0
var _base_visual_scale := Vector2.ONE
var _base_shadow_scale := Vector2.ONE
var _aim_reticle: Line2D = null
var _last_mouse_position := Vector2.INF
var _mouse_manual_aim_until := 0.0
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
var _contact_invuln_until: float = 0.0
var _dash_hit_targets: Dictionary = {}

func _ready() -> void:
	add_to_group("player")
	add_to_group("player_target")
	current_health = max_health
	if visual != null:
		_base_visual_scale = visual.scale * 1.35
		visual.scale = _base_visual_scale
	if shadow != null:
		_base_shadow_scale = shadow.scale * 1.35
		shadow.scale = _base_shadow_scale
	_create_aim_reticle()
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
	return {
		"current": current_health,
		"max": max_health,
		"overshield": int(ceil(_overshield)),
		"overshield_max": float(max_health) * BLOODTHIRST_MAX_OVERSHIELD_RATIO if _passive_id == "bloodthirst" else 0.0,
		"heat": int(round(_overheat_heat)),
		"ultimate": _ultimate_charge,
		"class_id": _class_id,
		"passive_id": _passive_id,
	}

func has_passive(passive_id: String) -> bool:
	return _passive_id == passive_id

func has_class(class_id: String) -> bool:
	return _class_id == class_id

func set_ultimate_charge(value: float) -> void:
	_ultimate_charge = clampf(value, 0.0, 1.0)

func get_ultimate_charge() -> float:
	return _ultimate_charge

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
	var cooldown_duration := float(slot.get("cooldown", 1.0))
	var is_ultimate := _is_ultimate_slot(slot_index, slot)
	if _is_ultimate_slot(slot_index, slot):
		cooldown_duration = 1.0
	return {
		"skill_id": str(slot.get("id", "")),
		"name": str(slot.get("name", "Ability")),
		"cooldown_remaining": get_ability_cooldown_remaining(slot_index),
		"cooldown_duration": cooldown_duration,
		"base_cooldown": float(slot.get("base_cooldown", slot.get("cooldown", 1.0))),
		"charges_current": int(slot.get("charges_current", 1)),
		"charges_max": int(slot.get("charges_max", 1)),
		"is_ultimate": is_ultimate,
		"is_ready": _is_slot_ready(slot_index, _current_time_seconds()),
		"ready_ratio": _get_ultimate_ready_ratio(slot) if is_ultimate else 1.0 - clampf(get_ability_cooldown_remaining(slot_index) / maxf(cooldown_duration, 0.01), 0.0, 1.0),
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
	_ability_pressed_last_frame = _build_ability_pressed_state()

func apply_loadout(loadout: Dictionary) -> void:
	var previous_wake_capacity := _wake_heal_capacity
	_mutation_ids = (loadout.get("mutations", []) as Array).duplicate()
	_class_id = str(loadout.get("class_id", ""))
	_passive_id = str(loadout.get("passive_id", ""))
	_base_move_speed = float(loadout.get("move_speed", move_speed))
	_base_max_health = max(1, int(loadout.get("max_health", max_health)))
	max_health = _base_max_health
	current_health = clampi(current_health, 0, max_health)
	if current_health <= 0 and not _is_downed:
		current_health = max_health
	_weapon_id = str(loadout.get("weapon_id", "rifle"))
	_weapon_profile_name = str(loadout.get("weapon_name", "Rifle"))
	_weapon_stats = (loadout.get("weapon_stats", {}) as Dictionary).duplicate(true)
	_heal_disabled = bool(loadout.get("heal_disabled", false))
	_base_projectile_damage = int(round(float(_weapon_stats.get("damage", _weapon_stats.get("max_damage_per_second", projectile_damage)))))
	if str(_weapon_stats.get("projectile_kind", "bullet")) == "beam":
		_base_weapon_fire_interval = maxf(float(_weapon_stats.get("tick_interval", 0.1)), 0.05)
	else:
		_base_weapon_fire_interval = 1.0 / max(float(_weapon_stats.get("fire_rate", 4.0)), 0.01)
	projectile_speed = float(_weapon_stats.get("projectile_speed", projectile_speed))
	_weapon_range = float(_weapon_stats.get("range", _weapon_range))
	_weapon_area = float(_weapon_stats.get("area", _weapon_area))
	_ability_slots.clear()
	for slot_index in range(ABILITY_SLOT_COUNT):
		var slot_number := slot_index + 1
		var slot_key := "ability_slot_%d" % slot_number
		var slot_id_key := "ability_slot_%d_id" % slot_number
		var fallback_id := str(AbilityRegistry.DEFAULT_LOADOUT[slot_index]) if slot_index < AbilityRegistry.DEFAULT_LOADOUT.size() else ""
		_ability_slots.append(_build_runtime_ability((loadout.get(slot_key, {}) as Dictionary).duplicate(true), str(loadout.get(slot_id_key, fallback_id))))
	_dash_states.clear()
	for slot_index in range(_ability_slots.size()):
		var slot: Dictionary = _ability_slots[slot_index]
		if str(slot.get("id", "")) == "dash":
			var dash_state := DashData.new()
			dash_state.dash_duration = max(0.05, float((slot.get("stats", {}) as Dictionary).get("duration", slot.get("duration", 0.2))))
			dash_state.cooldown_duration = max(0.1, float(slot.get("cooldown", 3.0)))
			dash_state.dash_speed = float((slot.get("stats", {}) as Dictionary).get("dash_speed", 1180.0))
			_dash_states[slot_index] = dash_state
	_configure_wake_healing(_wake_heal_cap_from_slots(), previous_wake_capacity)
	_ability_pressed_last_frame = _build_ability_pressed_state()
	_shield_until = 0.0
	_shield_was_active = false
	_pending_shield_burst.clear()
	_dash_invuln_until = 0.0
	_invisible_until = 0.0
	_external_impulse = Vector2.ZERO
	_dash_hit_targets.clear()
	_next_speed_line_at = 0.0
	_next_reflex_particle_at = 0.0
	_modifier_move_speed_sources["upgrade_move_speed"] = 1.0 + float(loadout.get("move_speed_bonus", 0.0))
	_modifier_attack_speed_sources["upgrade_fire_rate"] = 1.0 + float(_weapon_stats.get("fire_rate_bonus", 0.0))
	_modifier_damage_sources["upgrade_damage"] = 1.0 + float(_weapon_stats.get("damage_bonus", 0.0))
	if _passive_id != "bloodthirst":
		_overshield = 0.0
	if _passive_id != "overheat":
		_overheat_heat = 0.0
		_overheat_damage_bonus = 0.0
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

func set_momentum_tier(tier: int, move_bonus: float, fire_rate_bonus: float) -> void:
	_momentum_tier = clampi(tier, 0, 4)
	_momentum_move_bonus = maxf(move_bonus, 0.0)
	_momentum_fire_rate_bonus = maxf(fire_rate_bonus, 0.0)
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
	if _heal_disabled or amount <= 0 or _is_downed or current_health >= max_health:
		return false
	current_health = clampi(current_health + amount, 0, max_health)
	health_changed.emit(current_health, max_health)
	return true

func apply_bloodthirst_heal(amount: int, overshield_multiplier: float = 1.0) -> void:
	if _passive_id != "bloodthirst" or amount <= 0 or _is_downed:
		return
	var remaining := amount
	if current_health < max_health:
		var healed := mini(max_health - current_health, remaining)
		current_health += healed
		remaining -= healed
	if current_health >= max_health and remaining > 0:
		var overshield_gain := float(remaining) * maxf(overshield_multiplier, 0.0)
		_overshield = minf(_overshield + overshield_gain, float(max_health) * BLOODTHIRST_MAX_OVERSHIELD_RATIO)
	health_changed.emit(current_health, max_health)

func try_apply_wake_heal(amount: int) -> bool:
	if amount <= 0 or _wake_heal_capacity <= 0.0 or _wake_heal_tokens + 0.0001 < float(amount):
		return false
	if not heal(amount):
		return false
	_wake_heal_tokens = maxf(0.0, _wake_heal_tokens - float(amount))
	return true

func apply_damage(amount: int) -> void:
	if _is_downed or amount <= 0:
		return
	if RunState.debug_profiling:
		return
	var now := _current_time_seconds()
	if _is_damage_immune(now):
		return
	_contact_invuln_until = now + CONTACT_INVULN_DURATION
	var incoming_amount := int(ceil(float(amount) * (1.0 + _get_overheat_vulnerability_bonus())))
	if _overshield > 0.0:
		var absorbed := minf(_overshield, float(incoming_amount))
		_overshield -= absorbed
		incoming_amount -= int(round(absorbed))
	if incoming_amount <= 0:
		health_changed.emit(current_health, max_health)
		return
	current_health = max(current_health - incoming_amount, 0)
	health_changed.emit(current_health, max_health)
	damage_taken.emit(self, incoming_amount, current_health)
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
	if _is_ultimate_slot(slot_index, slot):
		return 0.0 if _is_ultimate_ready(slot_index, slot) else 1.0 - _get_ultimate_ready_ratio(slot)
	if ability_id == "dash" and _dash_states.has(slot_index):
		return (_dash_states[slot_index] as DashData).get_cooldown_remaining(now)
	return max(float(slot.get("cooldown_until", 0.0)) - now, 0.0)

func apply_ability_lockout(seconds: float) -> void:
	var now := _current_time_seconds()
	var delay: float = max(seconds, 0.0)
	for slot_index in range(_ability_slots.size()):
		var slot := _get_ability_slot(slot_index)
		var ability_id := str(slot.get("id", ""))
		if ability_id == "dash" and _dash_states.has(slot_index):
			(_dash_states[slot_index] as DashData).extend_cooldown(delay, now)
			continue
		slot["cooldown_until"] = max(float(slot.get("cooldown_until", 0.0)), now) + delay
		_set_ability_slot(slot_index, slot)

func recharge_dash_slots() -> void:
	var now := _current_time_seconds()
	for dash_state in _dash_states.values():
		(dash_state as DashData).recharge(now)

func is_secondary_skill_active() -> bool:
	return _is_slot_active(1, _current_time_seconds())

func is_secondary_skill_shield_active() -> bool:
	return _is_damage_immune(_current_time_seconds())

func _physics_process(delta: float) -> void:
	var now := _current_time_seconds()
	_update_passive_runtime(delta, now)
	_update_shield_burst(now)
	_update_buffered_dashes(now)
	if _input_locked or _is_downed:
		velocity = Vector2.ZERO
		_update_aim_reticle(false)
		move_and_slide()
		_apply_visual_state(now, delta)
		return

	var move_input := _get_move_input()
	if move_input.length() > 0.0:
		_move_facing = move_input.normalized()
	if _external_impulse.length() > 0.0:
		_external_impulse = _external_impulse.move_toward(Vector2.ZERO, delta * 12.0)

	var manual_aim_vector := _get_manual_aim_vector(now)
	var manual_aim_active := manual_aim_vector.length() > MANUAL_AIM_DEADZONE
	if manual_aim_active:
		_aim_facing = manual_aim_vector.normalized()
	_auto_target = _find_auto_target(manual_aim_active)
	var fire_direction := _get_weapon_fire_direction(manual_aim_active)
	_update_aim_reticle(manual_aim_active and fire_direction.length() > 0.0)
	if _can_attack(now) and fire_direction.length() > 0.0 and now >= _next_weapon_fire_at:
		_fire_weapon(now, fire_direction.normalized())

	for slot_index in range(_ability_slots.size()):
		var slot_pressed := _is_ability_pressed(slot_index)
		if slot_pressed and not bool(_ability_pressed_last_frame[slot_index]):
			_try_activate_ability(slot_index, now)
		_ability_pressed_last_frame[slot_index] = slot_pressed

	velocity = _get_current_velocity(move_input, now)
	move_and_slide()
	_apply_shockdash_hits(now)
	_update_shield_burst(now)
	_emit_movement_feedback(now, move_input)
	_emit_reflex_feedback(now)
	_apply_visual_state(now, delta)

func _find_auto_target(manual_aim_active: bool = false) -> Node2D:
	if manual_aim_active:
		return null
	if str(player_config.aim_mode) == "movement":
		return null
	if str(player_config.aim_mode) == "manual":
		return null
	return _auto_targeter.find_nearest(self, _weapon_range)

func _get_weapon_fire_direction(manual_aim_active: bool) -> Vector2:
	var aim_mode := str(player_config.aim_mode)
	if manual_aim_active:
		return _aim_facing
	if aim_mode == "manual":
		return Vector2.ZERO
	if _auto_target != null:
		_auto_attack_direction = (_auto_target.global_position - global_position).normalized()
		return _auto_attack_direction
	if aim_mode == "movement":
		return _move_facing
	return Vector2.ZERO

func _build_runtime_ability(definition: Dictionary, fallback_id: String) -> Dictionary:
	var ability_id := str(definition.get("id", fallback_id))
	var stats: Dictionary = (definition.get("stats", {}) as Dictionary).duplicate(true)
	stats["duration"] = float(definition.get("duration", 0.0))
	var slot := {
		"id": ability_id,
		"name": str(definition.get("name", ability_id.capitalize())),
		"type": str(definition.get("type", "instant")),
		"slot": str(definition.get("slot", "")),
		"cooldown": float(definition.get("cooldown", 1.0)),
		"duration": float(definition.get("duration", 0.0)),
		"cooldown_until": 0.0,
		"active_until": 0.0,
		"base_cooldown": float(definition.get("base_cooldown", definition.get("cooldown", 1.0))),
		"stats": stats,
	}
	return slot

func _get_overcharge_fire_rate_multiplier(now: float) -> float:
	var stats := _get_active_ability_stats("overcharge", now)
	return maxf(float(stats.get("fire_rate_multiplier", 1.0)), 1.0)

func _get_overcharge_projectile_multiplier(now: float) -> int:
	var stats := _get_active_ability_stats("overcharge", now)
	return maxi(1, int(stats.get("projectile_multiplier", 1)))

func _get_active_ability_stats(ability_id: String, now: float) -> Dictionary:
	for slot_index in range(_ability_slots.size()):
		var slot: Dictionary = _ability_slots[slot_index]
		if str(slot.get("id", "")) == ability_id and _is_slot_active(slot_index, now):
			return slot.get("stats", {}) as Dictionary
	return {}

func _get_ability_slot(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= _ability_slots.size():
		return {}
	return _ability_slots[slot_index]

func _set_ability_slot(slot_index: int, slot: Dictionary) -> void:
	if slot_index < 0 or slot_index >= _ability_slots.size():
		return
	_ability_slots[slot_index] = slot

func _update_shield_burst(now: float) -> void:
	if _shield_was_active and now >= _shield_until:
		_shield_was_active = false
		var burst_stats := _get_shield_burst_stats()
		if not burst_stats.is_empty():
			_pending_shield_burst = burst_stats
	if _pending_shield_burst.is_empty():
		return
	if _has_non_shield_invulnerability(now) or _is_downed:
		return
	var burst_radius := float(_pending_shield_burst.get("burst_radius", 0.0))
	var burst_damage := int(_pending_shield_burst.get("burst_damage", 0))
	_pending_shield_burst.clear()
	if burst_radius <= 0.0 or burst_damage <= 0:
		return
	shield_burst_requested.emit(global_position, burst_radius, burst_damage, player_config.tint)

func _get_shield_burst_stats() -> Dictionary:
	for slot in _ability_slots:
		var slot_dict: Dictionary = slot as Dictionary
		if str(slot_dict.get("id", "")) != "shield":
			continue
		var stats: Dictionary = slot_dict.get("stats", {}) as Dictionary
		if int(stats.get("burst_damage", 0)) > 0:
			return stats.duplicate(true)
	return {}

func _has_non_shield_invulnerability(now: float) -> bool:
	if now < _contact_invuln_until:
		return true
	if now < _dash_invuln_until:
		return true
	for dash_state in _dash_states.values():
		if (dash_state as DashData).is_active(now):
			return true
	return false

func _apply_shockdash_hits(now: float) -> void:
	for slot_index_variant in _dash_states.keys():
		var slot_index := int(slot_index_variant)
		var dash_state := _dash_states[slot_index] as DashData
		if not dash_state.is_active(now):
			continue
		var slot := _get_ability_slot(slot_index)
		var stats: Dictionary = slot.get("stats", {}) as Dictionary
		var passthrough_damage := int(stats.get("passthrough_damage", 0))
		if passthrough_damage <= 0:
			continue
		var hit_targets: Array = (_dash_hit_targets.get(slot_index, []) as Array)
		var player_hit_radius := _get_dash_hit_radius()
		var query_radius := player_hit_radius + 64.0
		for enemy in _get_nearby_enemy_targets(query_radius):
			if enemy == null or not is_instance_valid(enemy) or hit_targets.has(enemy):
				continue
			if enemy.has_method("is_alive") and not enemy.is_alive():
				continue
			if not (enemy is Node2D):
				continue
			var enemy_node := enemy as Node2D
			var enemy_radius := _get_enemy_overlap_radius(enemy)
			var overlap_radius := player_hit_radius + enemy_radius
			if enemy_node.global_position.distance_squared_to(global_position) > overlap_radius * overlap_radius:
				continue
			if enemy.has_method("apply_damage"):
				enemy.apply_damage(passthrough_damage, player_index)
			hit_targets.append(enemy)
		_dash_hit_targets[slot_index] = hit_targets

func _get_enemy_overlap_radius(enemy: Node) -> float:
	if enemy != null and enemy.has_method("get_collision_radius"):
		return maxf(float(enemy.get_collision_radius()), 1.0)
	return 19.0

func _get_dash_hit_radius() -> float:
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		var scale_mult := maxf(absf(collision_shape.global_scale.x), absf(collision_shape.global_scale.y))
		return maxf((collision_shape.shape as CircleShape2D).radius * scale_mult, 1.0)
	return 34.0

func _get_nearby_enemy_targets(radius: float) -> Array:
	var tree := get_tree()
	if tree == null:
		return []
	var node: Node = self
	while node != null:
		if node.has_method("get_nearby_enemy_target_nodes"):
			return node.get_nearby_enemy_target_nodes(global_position, radius)
		node = node.get_parent()
	var combat_owner := tree.current_scene
	if combat_owner != null and combat_owner.has_method("get_nearby_enemy_target_nodes"):
		return combat_owner.get_nearby_enemy_target_nodes(global_position, radius)
	return tree.get_nodes_in_group("aim_target")

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

func _get_manual_aim_vector(now: float) -> Vector2:
	var gamepad_vector := _get_gamepad_aim_vector() if player_config.uses_gamepad() else Vector2.ZERO
	if gamepad_vector.length() > 0.0:
		return gamepad_vector
	return _get_mouse_aim_vector(now) if player_config.uses_keyboard() else Vector2.ZERO

func _get_gamepad_aim_vector() -> Vector2:
	var left_action := "p%d_aim_left" % player_id
	var right_action := "p%d_aim_right" % player_id
	var up_action := "p%d_aim_up" % player_id
	var down_action := "p%d_aim_down" % player_id
	if _has_gamepad_action_events([left_action, right_action, up_action, down_action]):
		var vector := Vector2(
			_get_gamepad_action_strength(right_action) - _get_gamepad_action_strength(left_action),
			_get_gamepad_action_strength(down_action) - _get_gamepad_action_strength(up_action)
		)
		return vector.normalized() if vector.length() > 1.0 else vector
	return _get_gamepad_stick_vector(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)

func _get_mouse_aim_vector(now: float) -> Vector2:
	var mouse_position := get_global_mouse_position()
	if _last_mouse_position == Vector2.INF:
		_last_mouse_position = mouse_position
	if mouse_position.distance_squared_to(_last_mouse_position) > 1.0:
		_mouse_manual_aim_until = now + MOUSE_AIM_IDLE_SECONDS
		_last_mouse_position = mouse_position
	if _is_keyboard_action_pressed("p%d_fire" % player_id) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_mouse_manual_aim_until = now + MOUSE_AIM_IDLE_SECONDS
	if now > _mouse_manual_aim_until:
		return Vector2.ZERO
	var vector := mouse_position - global_position
	return vector.normalized() if vector.length() > 1.0 else Vector2.ZERO

func _is_damage_immune(now: float) -> bool:
	if now < _shield_until:
		return true
	if now < _dash_invuln_until:
		return true
	if now < _contact_invuln_until:
		return true
	for dash_state in _dash_states.values():
		if (dash_state as DashData).is_active(now):
			return true
	return false

func _can_attack(now: float) -> bool:
	return not _is_slot_active_by_id("shield", now) and not _is_downed

func _fire_weapon(now: float, fire_direction: Vector2) -> void:
	var muzzle_weight := _weapon_impact_weight
	if _is_slot_active_by_id("overcharge", now):
		muzzle_weight += 0.2
	_next_weapon_fire_at = now + _get_current_weapon_fire_interval()
	_play_fire_recoil()
	muzzle_flash_requested.emit(global_position + fire_direction * 24.0, fire_direction, player_config.tint, _weapon_feedback_profile, muzzle_weight)
	var projectile_config := _weapon_stats.duplicate(true)
	projectile_config["weapon_id"] = _weapon_id
	projectile_config["speed"] = float(projectile_config.get("projectile_speed", projectile_speed))
	projectile_config["damage"] = projectile_damage
	if str(projectile_config.get("projectile_kind", "bullet")) == "beam":
		projectile_config["max_damage_per_second"] = projectile_damage
	projectile_config["team"] = get_team()
	projectile_config["color"] = player_config.tint
	projectile_config["shooter"] = self
	projectile_config["feedback_profile"] = _weapon_feedback_profile
	projectile_config["impact_weight"] = _weapon_impact_weight
	projectile_config["max_distance"] = float(projectile_config.get("range", _weapon_range))
	projectile_config["collision_half_width"] = float(projectile_config.get("area", _weapon_area))
	projectile_config["tick_interval"] = _get_current_weapon_fire_interval()
	projectile_config["projectile_multiplier"] = 1 if str(projectile_config.get("projectile_kind", "bullet")) == "beam" else _get_overcharge_projectile_multiplier(now)
	var overcharge_stats := _get_active_ability_stats("overcharge", now)
	if not overcharge_stats.is_empty() and str(projectile_config.get("projectile_kind", "bullet")) != "beam":
		var pierce_bonus := int(overcharge_stats.get("pierce_bonus", 0))
		if pierce_bonus > 0:
			projectile_config["pierce_count"] = int(projectile_config.get("pierce_count", 0)) + pierce_bonus
		var projectile_speed_mult := float(overcharge_stats.get("projectile_speed_mult", 1.0))
		if projectile_speed_mult > 1.0:
			projectile_config["speed"] = float(projectile_config.get("speed", projectile_speed)) * projectile_speed_mult
	var max_momentum_pierce := int(projectile_config.get("pierce_at_max_momentum", 0))
	if max_momentum_pierce > 0 and _momentum_tier >= MAX_MOMENTUM_TIER and str(projectile_config.get("projectile_kind", "bullet")) != "beam":
		projectile_config["pierce_count"] = int(projectile_config.get("pierce_count", 0)) + max_momentum_pierce
	projectile_config["source_type"] = "weapon"
	projectile_config["source_player_index"] = player_index
	fire_requested.emit(global_position + fire_direction * 24.0, fire_direction, projectile_config)

func _get_current_weapon_fire_interval() -> float:
	var overcharge_multiplier := _get_overcharge_fire_rate_multiplier(_current_time_seconds())
	var interval := _base_weapon_fire_interval / _additive_modifier(
		_modifier_attack_speed_sources,
		(_buff_attack_speed - 1.0) + _momentum_fire_rate_bonus + maxf(overcharge_multiplier - 1.0, 0.0)
	)
	return max(interval, 0.05)

func get_current_fire_rate() -> float:
	return 1.0 / max(_get_current_weapon_fire_interval(), 0.01)

func _try_activate_ability(slot_index: int, now: float) -> void:
	var slot := _get_ability_slot(slot_index)
	if slot.is_empty():
		return
	var ability_id := str(slot.get("id", ""))
	if ability_id.is_empty():
		return
	var direction := _get_ability_cast_direction(now)
	if _is_ultimate_slot(slot_index, slot) and not _is_ultimate_ready(slot_index, slot):
		return
	match ability_id:
		"dash":
			var dash_state := _dash_states.get(slot_index, null) as DashData
			if dash_state == null:
				return
			if dash_state.try_trigger(_move_facing, now):
				_on_dash_started(slot_index, now)
		"shield":
			if not _is_slot_ready(slot_index, now):
				return
			_shield_until = max(_shield_until, now + float(slot.get("duration", 3.0)))
			_shield_was_active = true
			_pending_shield_burst.clear()
			_set_slot_active(slot_index, now)
			_set_slot_cooldown(slot_index, now)
			_emit_ability(slot_index, direction)
		"overcharge", "turret", "orbit":
			if not _is_slot_ready(slot_index, now):
				return
			_set_slot_active(slot_index, now)
			_set_slot_cooldown(slot_index, now)
			_emit_ability(slot_index, direction)
		"minefield":
			if not _is_slot_ready(slot_index, now):
				return
			_set_slot_cooldown(slot_index, now)
			_emit_ability(slot_index, direction)
		_:
			if not _is_slot_ready(slot_index, now):
				return
			_set_slot_cooldown(slot_index, now)
			_emit_ability(slot_index, direction)

func _get_ability_cast_direction(now: float) -> Vector2:
	var manual_aim_vector := _get_manual_aim_vector(now)
	var manual_aim_active := manual_aim_vector.length() > MANUAL_AIM_DEADZONE
	if manual_aim_active:
		_aim_facing = manual_aim_vector.normalized()
	_auto_target = _find_auto_target(manual_aim_active)
	return _resolve_ability_cast_direction(manual_aim_active)

func _resolve_ability_cast_direction(manual_aim_active: bool) -> Vector2:
	var weapon_direction := _get_weapon_fire_direction(manual_aim_active)
	if weapon_direction.length_squared() > 0.001:
		return weapon_direction.normalized()
	return _aim_facing.normalized() if _aim_facing.length_squared() > 0.001 else Vector2.RIGHT

func _on_dash_started(slot_index: int, now: float) -> void:
	_dash_invuln_until = maxf(_dash_invuln_until, now + float((_get_ability_slot(slot_index).get("stats", {}) as Dictionary).get("invulnerability_duration", 0.2)))
	_dash_hit_targets[slot_index] = []
	_emit_ability(slot_index, (_dash_states[slot_index] as DashData).get_direction())

func _emit_ability(slot_index: int, direction: Vector2) -> void:
	var slot := _get_ability_slot(slot_index)
	var ability_id := str(slot.get("id", ""))
	var is_ultimate := _is_ultimate_slot(slot_index, slot)
	if _passive_id == "overheat" and not (is_ultimate and ability_id == "firestorm"):
		_add_overheat(OVERHEAT_HEAT_PER_CAST)
	var payload: Dictionary = (slot.get("stats", {}) as Dictionary).duplicate(true)
	payload["ability_id"] = ability_id
	payload["cooldown"] = float(slot.get("cooldown", 0.0))
	payload["duration"] = float(slot.get("duration", 0.0))
	payload["color"] = player_config.tint
	payload["slot_index"] = slot_index
	payload["owner"] = self
	payload["source_player_index"] = player_index
	if is_ultimate:
		if _passive_id == "overheat" and ability_id == "firestorm":
			_set_overheat_heat(0.0)
		else:
			_ultimate_charge = 0.0
	ability_activated.emit(self, slot_index, ability_id, global_position, direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT, payload)

func _update_passive_runtime(delta: float, now: float) -> void:
	if not _is_downed and _wake_heal_capacity > 0.0:
		_wake_heal_tokens = minf(_wake_heal_capacity, _wake_heal_tokens + _wake_heal_refill_per_second * delta)
	if _overshield > 0.0:
		_overshield = maxf(0.0, _overshield - BLOODTHIRST_OVERSHIELD_DECAY_PER_SECOND * delta)
	if _passive_id != "overheat":
		return
	if _overheat_heat <= 0.0 or now < _last_heat_gain_at + OVERHEAT_DECAY_DELAY:
		return
	_set_overheat_heat(maxf(0.0, _overheat_heat - OVERHEAT_DECAY_PER_SECOND * delta))

func _wake_heal_cap_from_slots() -> float:
	for slot_variant in _ability_slots:
		var slot := slot_variant as Dictionary
		if str(slot.get("id", "")) != "afterburn":
			continue
		var stats := slot.get("stats", {}) as Dictionary
		return maxf(0.0, float(stats.get("wake_heal_cap_per_second", 0.0)))
	return 0.0

func _configure_wake_healing(new_capacity: float, previous_capacity: float) -> void:
	new_capacity = maxf(0.0, new_capacity)
	if previous_capacity <= 0.0 and new_capacity > 0.0:
		_wake_heal_tokens = new_capacity
	elif previous_capacity > 0.0 and new_capacity > 0.0:
		_wake_heal_tokens = new_capacity * clampf(_wake_heal_tokens / previous_capacity, 0.0, 1.0)
	else:
		_wake_heal_tokens = 0.0
	_wake_heal_capacity = new_capacity
	_wake_heal_refill_per_second = new_capacity

func _add_overheat(amount: float) -> void:
	_last_heat_gain_at = _current_time_seconds()
	_set_overheat_heat(minf(OVERHEAT_MAX_HEAT, _overheat_heat + amount))

func _set_overheat_heat(value: float) -> void:
	var previous_damage_bonus := _overheat_damage_bonus
	_overheat_heat = clampf(value, 0.0, OVERHEAT_MAX_HEAT)
	_overheat_damage_bonus = _overheat_heat * OVERHEAT_DAMAGE_PER_HEAT
	if not is_equal_approx(previous_damage_bonus, _overheat_damage_bonus):
		_recompute_effective_stats()

func _get_overheat_vulnerability_bonus() -> float:
	if _passive_id != "overheat":
		return 0.0
	return _overheat_heat * OVERHEAT_VULNERABILITY_PER_HEAT

func _is_slot_ready(slot_index: int, now: float) -> bool:
	var slot := _get_ability_slot(slot_index)
	if _is_ultimate_slot(slot_index, slot):
		return _is_ultimate_ready(slot_index, slot)
	return get_ability_cooldown_remaining(slot_index) <= 0.0 and not _is_slot_active(slot_index, now)

func _is_ultimate_slot(slot_index: int, slot: Dictionary) -> bool:
	if str(slot.get("slot", "")) == "ultimate":
		return true
	return slot_index == ABILITY_SLOT_COUNT - 1 and str(slot.get("id", "")) in ["slipstream", "blood_frenzy", "overload_grid", "firestorm"]

func _is_ultimate_ready(slot_index: int, slot: Dictionary) -> bool:
	if not _is_ultimate_slot(slot_index, slot):
		return false
	if _passive_id == "overheat" and str(slot.get("id", "")) == "firestorm":
		return _overheat_heat >= OVERHEAT_ULTIMATE_HEAT_THRESHOLD
	return _ultimate_charge >= 1.0

func _get_ultimate_ready_ratio(slot: Dictionary) -> float:
	if _passive_id == "overheat" and str(slot.get("id", "")) == "firestorm":
		return clampf(_overheat_heat / OVERHEAT_ULTIMATE_HEAT_THRESHOLD, 0.0, 1.0)
	return clampf(_ultimate_charge, 0.0, 1.0)

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
	var vector := Vector2.ZERO
	if player_config.uses_keyboard():
		vector += _get_keyboard_movement_vector()
	if player_config.uses_gamepad():
		vector += _get_gamepad_movement_vector()
	return vector.normalized() if vector.length() > 1.0 else vector

func _get_keyboard_movement_vector() -> Vector2:
	var vector := Vector2(
		_get_keyboard_action_strength("p%d_move_right" % player_id) - _get_keyboard_action_strength("p%d_move_left" % player_id),
		_get_keyboard_action_strength("p%d_move_down" % player_id) - _get_keyboard_action_strength("p%d_move_up" % player_id)
	)
	return vector.normalized() if vector.length() > 1.0 else vector

func _get_gamepad_movement_vector() -> Vector2:
	var left_action := "p%d_move_left" % player_id
	var right_action := "p%d_move_right" % player_id
	var up_action := "p%d_move_up" % player_id
	var down_action := "p%d_move_down" % player_id
	if _has_gamepad_action_events([left_action, right_action, up_action, down_action]):
		var vector := Vector2(
			_get_gamepad_action_strength(right_action) - _get_gamepad_action_strength(left_action),
			_get_gamepad_action_strength(down_action) - _get_gamepad_action_strength(up_action)
		)
		return vector.normalized() if vector.length() > 1.0 else vector
	return _get_gamepad_stick_vector(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)

func _get_gamepad_stick_vector(axis_x: JoyAxis, axis_y: JoyAxis) -> Vector2:
	if gamepad_device_id < 0 or not Input.get_connected_joypads().has(gamepad_device_id):
		return Vector2.ZERO
	var vector := Vector2(Input.get_joy_axis(gamepad_device_id, axis_x), Input.get_joy_axis(gamepad_device_id, axis_y))
	return vector if vector.length() >= 0.2 else Vector2.ZERO

func _is_ability_pressed(slot_index: int) -> bool:
	if player_config.uses_gamepad():
		if gamepad_device_id < 0:
			if player_config.uses_keyboard():
				return _is_keyboard_ability_pressed(slot_index)
			return false
		var action := "p%d_ability_%d" % [player_id, slot_index + 1]
		if _has_gamepad_action_events([action]):
			if _get_gamepad_action_strength(action) >= 0.5:
				return true
		if slot_index >= 0 and slot_index < ABILITY_FACE_BUTTONS.size() and Input.is_joy_button_pressed(gamepad_device_id, ABILITY_FACE_BUTTONS[slot_index]):
			return true
	if player_config.uses_keyboard():
		return _is_keyboard_ability_pressed(slot_index)
	return false

func _is_keyboard_ability_pressed(slot_index: int) -> bool:
	return _is_keyboard_action_pressed("p%d_ability_%d" % [player_id, slot_index + 1])

func _build_ability_pressed_state() -> Array:
	var state: Array = []
	for _slot_index in range(ABILITY_SLOT_COUNT):
		state.append(false)
	return state

func _has_gamepad_action_events(actions: Array) -> bool:
	for action_variant in actions:
		for event in InputMap.action_get_events(str(action_variant)):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				return true
	return false

func _get_gamepad_action_strength(action: String) -> float:
	if gamepad_device_id < 0 or not Input.get_connected_joypads().has(gamepad_device_id):
		return 0.0
	var strength := 0.0
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			var button_event := event as InputEventJoypadButton
			if button_event.device == -1 or button_event.device == gamepad_device_id:
				strength = maxf(strength, 1.0 if Input.is_joy_button_pressed(gamepad_device_id, button_event.button_index) else 0.0)
		elif event is InputEventJoypadMotion:
			var axis_event := event as InputEventJoypadMotion
			if axis_event.device != -1 and axis_event.device != gamepad_device_id:
				continue
			var axis_value := Input.get_joy_axis(gamepad_device_id, axis_event.axis)
			var signed_value := axis_value * signf(axis_event.axis_value)
			strength = maxf(strength, clampf((signed_value - 0.2) / 0.8, 0.0, 1.0))
	return strength

func _get_keyboard_action_strength(action: String) -> float:
	return 1.0 if _is_keyboard_action_pressed(action) else 0.0

func _is_keyboard_action_pressed(action: String) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			var physical_key := key_event.physical_keycode
			if physical_key != 0 and Input.is_physical_key_pressed(physical_key):
				return true
			if key_event.keycode != 0 and Input.is_key_pressed(key_event.keycode):
				return true
		elif event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if Input.is_mouse_button_pressed(mouse_event.button_index):
				return true
	return false

func _enter_downed_state() -> void:
	_is_downed = true
	velocity = Vector2.ZERO
	_shield_until = 0.0
	_dash_invuln_until = 0.0
	_shield_was_active = false
	_pending_shield_burst.clear()
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
	var body_polygon := ClassVisualsData.get_silhouette_points(_class_id)
	if body_polygon.is_empty():
		body_polygon = _chevron_polygon
	if visual.polygon != body_polygon:
		visual.polygon = body_polygon
	var class_accent := ClassVisualsData.get_accent_color(_class_id)
	var body_color := class_accent.lerp(player_config.tint, 0.36).lightened(mutation_glow + bonus_glow)
	visual.color = _bloom_color(body_color) if not _is_downed else player_config.tint.darkened(0.55)
	visual.modulate.a = 0.45 if now < _invisible_until else 1.0
	visual.scale = Vector2(_base_visual_scale.x * dash_scale * squash_x, _base_visual_scale.y * dash_scale * squash_y)
	if outline != null and outline.polygon != body_polygon:
		outline.polygon = body_polygon
	if outline != null:
		outline.scale = visual.scale * 1.28
		outline.color = _bloom_color(class_accent.lerp(player_config.tint, 0.22).lightened(0.2 + mutation_glow * 0.4 + bonus_glow * 0.5)) if shield_active or overcharge_active else Color(0.04, 0.06, 0.08, 0.92)
		outline.modulate.a = 0.65 if now < _invisible_until else 1.0
	if shadow != null:
		shadow.scale = _base_shadow_scale * (1.08 if tough_level >= 2 else 1.0)
		shadow.modulate.a = 0.18 if now < _invisible_until else 1.0
	if dash_shield_ring != null:
		dash_shield_ring.visible = (shield_active or dash_active or _momentum_tier > 0) and not _is_downed
		dash_shield_ring.default_color = _bloom_color(player_config.tint.lerp(Color(0.92, 1.0, 1.0, 1.0), 0.42 if shield_active else 0.18))
		dash_shield_ring.width = 5.0 + float(_momentum_tier) * 0.55 if tough_level >= 2 or _momentum_tier > 0 else 4.0
	body_root.rotation = lerp_angle(body_root.rotation, _move_facing.angle(), 0.22)
	_turn_squash = move_toward(_turn_squash, 0.0, delta * 4.0)

func _emit_movement_feedback(now: float, move_input: Vector2) -> void:
	if _is_downed or move_input.length() < 0.45:
		return
	var move_speed_level := _get_mutation_level("move_speed")
	if now < _next_speed_line_at or get_parent() == null:
		return
	_next_speed_line_at = now + 0.18
	var class_accent := ClassVisualsData.get_accent_color(_class_id).lerp(player_config.tint, 0.28)
	var trail_weight := 0.48 + float(max(move_speed_level - 1, 0)) * 0.18
	match ClassVisualsData.get_trail_style(_class_id):
		"weight":
			trail_weight += 0.26
		"arcane":
			trail_weight += 0.12
		"ember":
			trail_weight += 0.2
	var trail := ParticleFactoryData.create_dash_trail(class_accent.lightened(0.18), trail_weight)
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

func _create_aim_reticle() -> void:
	if _aim_reticle != null:
		return
	_aim_reticle = Line2D.new()
	_aim_reticle.name = "AimReticle"
	_aim_reticle.width = 2.0
	_aim_reticle.default_color = Color(player_config.tint.r, player_config.tint.g, player_config.tint.b, 0.30)
	_aim_reticle.antialiased = true
	_aim_reticle.visible = false
	_aim_reticle.z_index = 8
	add_child(_aim_reticle)

func _update_aim_reticle(visible_now: bool) -> void:
	if _aim_reticle == null:
		return
	_aim_reticle.visible = visible_now and not _is_downed
	if not _aim_reticle.visible:
		return
	var direction := _aim_facing.normalized() if _aim_facing.length() > 0.0 else Vector2.RIGHT
	var reticle_length := minf(_weapon_range, 170.0)
	_aim_reticle.default_color = Color(player_config.tint.r, player_config.tint.g, player_config.tint.b, 0.30)
	_aim_reticle.points = PackedVector2Array([
		direction * 26.0,
		direction * reticle_length,
	])

func _bloom_color(color: Color) -> Color:
	return Color(color.r * BLOOM_COLOR_MULTIPLIER, color.g * BLOOM_COLOR_MULTIPLIER, color.b * BLOOM_COLOR_MULTIPLIER, color.a)

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

func _additive_modifier(sources: Dictionary, extra_bonus: float = 0.0) -> float:
	var total_bonus := maxf(extra_bonus, 0.0)
	for value in sources.values():
		total_bonus += float(value) - 1.0
	return maxf(0.01, 1.0 + total_bonus)

func _recompute_effective_stats() -> void:
	move_speed = _base_move_speed * _additive_modifier(_modifier_move_speed_sources, (_buff_move_speed - 1.0) + _momentum_move_bonus)
	weapon_fire_interval = _base_weapon_fire_interval / _additive_modifier(_modifier_attack_speed_sources, (_buff_attack_speed - 1.0) + _momentum_fire_rate_bonus)
	projectile_damage = int(round(float(_base_projectile_damage) * _additive_modifier(_modifier_damage_sources, (_buff_damage - 1.0) + _overheat_damage_bonus)))
