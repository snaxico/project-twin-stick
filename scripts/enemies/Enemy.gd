extends CharacterBody2D

signal enemy_died(enemy)
signal fire_requested(origin, direction, speed, damage, team, color, projectile_scale)
signal hit_received(enemy, damage_amount, lethal)

const FLASH_SHADER_CODE := """
shader_type canvas_item;

uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 base = COLOR;
	COLOR = mix(base, flash_color, flash_intensity * flash_color.a);
}
"""

enum EnemyType {
	CHASER,
	CHARGER,
	SPITTER,
	BOSS,
	ELITE_CHARGER,
	ELITE_SPITTER,
	ELITE_SUPPORT,
}

@export var move_speed: float = 120.0
@export var max_health: int = 30
@export var contact_damage: int = 10
@export var projectile_speed: float = 340.0
@export var projectile_damage: int = 10
@export var fire_interval: float = 1.3
@export var preferred_distance: float = 190.0

@onready var shadow: Polygon2D = $Shadow
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var body_root: Node2D = $BodyRoot
@onready var outline: Polygon2D = $BodyRoot/Outline
@onready var visual: Polygon2D = $BodyRoot/Visual

const FEELER_LENGTH: float = 48.0
const FEELER_SPREAD: float = 0.52
const SEPARATION_RADIUS: float = 22.0
const SEPARATION_STRENGTH: float = 60.0
const SEPARATION_FALLOFF_POWER: float = 2.0
const CROWD_OPTIMIZATION_THRESHOLD: int = 18
const TARGET_REFRESH_INTERVAL: float = 0.10
const STEERING_REFRESH_INTERVAL: float = 0.08

var enemy_type: EnemyType = EnemyType.CHASER
var current_health: int = 0

var _combat_owner = null
var _next_contact_at := 0.0
var _next_projectile_at := 0.0
var _is_dead := false
var _death_explosion_radius: float = 0.0
var _death_explosion_damage: int = 0
var _projectile_burst_count := 1
var _projectile_spread_radians := 0.0
var _projectile_visual_scale := 1.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _flash_material: ShaderMaterial = null
var _flash_tween: Tween = null
var _base_body_root_position := Vector2.ZERO
var _base_shadow_scale := Vector2.ONE
var _idle_phase := 0.0
var _lunge_direction := Vector2.ZERO
var _lunge_windup_ends_at := 0.0
var _lunge_ends_at := 0.0
var _next_lunge_at := 0.0
var _charge_direction := Vector2.ZERO
var _charge_windup_ends_at := 0.0
var _charge_dash_ends_at := 0.0
var _charge_recovery_ends_at := 0.0
var _next_charge_at := 0.0
var _contact_range := 28.0
var _outline_pulse := 1.0
var _blocked_time := 0.0
var _last_position := Vector2.ZERO
var _detour_sign := 1.0
var _next_attack_trail_at := 0.0
var _cached_target = null
var _next_target_refresh_at := 0.0
var _cached_separation := Vector2.ZERO
var _next_separation_refresh_at := 0.0
var _cached_left_penalty := 0.0
var _cached_right_penalty := 0.0
var _next_feeler_refresh_at := 0.0
var _feeler_excludes_cache: Array = []
var _feeler_excludes_frame := -1
var _circle_sign := 1.0
var _elite_charger_use_slam := false
var _elite_support_next_pulse_at := 0.0
var _elite_spitter_next_pulse_at := 0.0
var _base_move_speed: float = 0.0
var _base_fire_interval: float = 0.0
var _aura_speed_modifier: float = 1.0
var _aura_attack_modifier: float = 1.0

func setup(type_name: String, combat_owner) -> void:
	_combat_owner = combat_owner
	match type_name:
		"charger":
			enemy_type = EnemyType.CHARGER
			max_health = 40
			move_speed = 247.5
			fire_interval = 2.0
			projectile_speed = 0.0
			projectile_damage = 0
			contact_damage = 15
			preferred_distance = 200.0
			_projectile_burst_count = 0
			_projectile_spread_radians = 0.0
			_projectile_visual_scale = 1.0
		"spitter":
			enemy_type = EnemyType.SPITTER
			max_health = 30
			move_speed = 312.0
			fire_interval = 1.0
			projectile_speed = 340.0
			projectile_damage = 10
			contact_damage = 8
			preferred_distance = 350.0
			_projectile_burst_count = 1
			_projectile_spread_radians = 0.0
			_projectile_visual_scale = 0.8
		"boss":
			enemy_type = EnemyType.BOSS
			max_health = 180
			move_speed = 157.5
			fire_interval = 1.0
			projectile_speed = 380.0
			projectile_damage = 10
			contact_damage = 10
			preferred_distance = 110.0
			_projectile_burst_count = 5
			_projectile_spread_radians = 0.14
			_projectile_visual_scale = 1.0
		"elite_charger":
			enemy_type = EnemyType.ELITE_CHARGER
			max_health = 1440
			move_speed = 371.25
			fire_interval = 0.0
			projectile_speed = 0.0
			projectile_damage = 0
			contact_damage = 15
			preferred_distance = 0.0
			_projectile_burst_count = 0
			_projectile_spread_radians = 0.0
			_projectile_visual_scale = 1.0
		"elite_spitter":
			enemy_type = EnemyType.ELITE_SPITTER
			max_health = 576
			move_speed = 312.0
			fire_interval = 0.33
			projectile_speed = 340.0
			projectile_damage = 10
			contact_damage = 8
			preferred_distance = 400.0
			_projectile_burst_count = 3
			_projectile_spread_radians = 0.18
			_projectile_visual_scale = 0.9
		"elite_support":
			enemy_type = EnemyType.ELITE_SUPPORT
			max_health = 900
			move_speed = 280.0
			fire_interval = 2.0
			projectile_speed = 0.0
			projectile_damage = 0
			contact_damage = 5
			preferred_distance = 250.0
			_projectile_burst_count = 0
			_projectile_spread_radians = 0.0
			_projectile_visual_scale = 1.0
		_:
			enemy_type = EnemyType.CHASER
			max_health = 21
			move_speed = 292.5
			fire_interval = 1.3
			projectile_speed = 340.0
			projectile_damage = 10
			contact_damage = 10
			preferred_distance = 190.0
			_projectile_burst_count = 1
			_projectile_spread_radians = 0.0
			_projectile_visual_scale = 1.0
	current_health = max_health
	_base_move_speed = move_speed
	_base_fire_interval = fire_interval
	_reset_behavior_state()
	_apply_type_visual()

func apply_room_modifier(enemy_bonus_health: int, enemy_speed_multiplier: float, enemy_fire_interval_multiplier: float, death_explosion_radius: float, death_explosion_damage: int, enemy_contact_damage_bonus: int) -> void:
	if enemy_type == EnemyType.BOSS:
		return
	max_health = max(max_health + enemy_bonus_health, 10)
	current_health = max(current_health, max_health)
	move_speed *= enemy_speed_multiplier
	fire_interval *= enemy_fire_interval_multiplier
	contact_damage += enemy_contact_damage_bonus
	_death_explosion_radius = death_explosion_radius
	_death_explosion_damage = death_explosion_damage
	_base_move_speed = move_speed
	_base_fire_interval = fire_interval
	clear_aura()

func apply_aura(speed_mult: float, attack_mult: float) -> void:
	_aura_speed_modifier = speed_mult
	_aura_attack_modifier = attack_mult
	move_speed = _base_move_speed * _aura_speed_modifier
	if _base_fire_interval > 0.0:
		fire_interval = _base_fire_interval / max(_aura_attack_modifier, 0.01)

func clear_aura() -> void:
	_aura_speed_modifier = 1.0
	_aura_attack_modifier = 1.0
	move_speed = _base_move_speed
	fire_interval = _base_fire_interval

func apply_boss_scale(player_count: int) -> void:
	if enemy_type != EnemyType.BOSS:
		return
	var health_scale: float = 1.0 + float(maxi(player_count - 1, 0)) * 0.6
	max_health = int(round(max_health * health_scale))
	current_health = max_health
	projectile_damage += maxi(player_count - 1, 0) * 10
	_base_move_speed = move_speed
	_base_fire_interval = fire_interval

func heal(amount: int) -> void:
	if amount <= 0 or _is_dead:
		return
	current_health = mini(current_health + amount, max_health)

func _ready() -> void:
	if current_health <= 0:
		current_health = max_health
	add_to_group("aim_target")
	if body_root != null:
		_base_body_root_position = body_root.position
	if shadow != null:
		_base_shadow_scale = shadow.scale
	_idle_phase = float(get_instance_id() % 17) * 0.43
	_last_position = global_position
	_detour_sign = -1.0 if int(get_instance_id() % 2) == 0 else 1.0
	_circle_sign = -1.0 if int(get_instance_id() % 2) == 0 else 1.0
	_apply_type_visual()
	_play_spawn_in_animation()

func get_team() -> String:
	return "enemy"

func is_alive() -> bool:
	return not _is_dead and current_health > 0

func is_boss() -> bool:
	return enemy_type == EnemyType.BOSS

func get_health_ratio_text() -> String:
	return "%d/%d" % [current_health, max_health]

func get_health_ratio() -> float:
	if max_health <= 0:
		return 0.0
	return clamp(float(current_health) / float(max_health), 0.0, 1.0)

func get_feedback_weight() -> float:
	match enemy_type:
		EnemyType.CHARGER:
			return 1.35
		EnemyType.SPITTER:
			return 1.1
		EnemyType.BOSS:
			return 1.9
		EnemyType.ELITE_CHARGER:
			return 2.2
		EnemyType.ELITE_SPITTER:
			return 1.55
		EnemyType.ELITE_SUPPORT:
			return 1.75
		_:
			return 0.9

func get_type_name() -> String:
	match enemy_type:
		EnemyType.CHARGER:
			return "charger"
		EnemyType.SPITTER:
			return "spitter"
		EnemyType.BOSS:
			return "boss"
		EnemyType.ELITE_CHARGER:
			return "elite_charger"
		EnemyType.ELITE_SPITTER:
			return "elite_spitter"
		EnemyType.ELITE_SUPPORT:
			return "elite_support"
		_:
			return "chaser"

func get_feedback_color() -> Color:
	return visual.color if visual != null else Color(1.0, 0.28, 0.28, 1.0)

func apply_damage(amount: int) -> void:
	if _is_dead:
		return
	current_health = max(current_health - amount, 0)
	_play_flash(Color.WHITE, 0.12)
	hit_received.emit(self, amount, current_health == 0)
	if current_health == 0:
		_die()

func apply_knockback(direction: Vector2, force: float) -> void:
	if _is_dead:
		return
	var normalized_direction := direction.normalized()
	if normalized_direction.length() <= 0.0:
		return
	_knockback_velocity += normalized_direction * force

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	var now := _current_time_seconds()
	var target = _get_closest_player(now)
	if target == null:
		_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		velocity = _knockback_velocity
		move_and_slide()
		_apply_motion_polish(now, delta)
		return

	var offset: Vector2 = target.global_position - global_position
	var distance: float = offset.length()
	var direction: Vector2 = offset.normalized() if distance > 0.0 else Vector2.ZERO
	var base_velocity := Vector2.ZERO

	match enemy_type:
		EnemyType.CHASER:
			base_velocity = _update_chaser_behavior(direction, distance, now)
		EnemyType.CHARGER:
			base_velocity = _update_charger_behavior(direction, distance, now)
		EnemyType.SPITTER:
			base_velocity = _update_spitter_behavior(direction, distance, now)
		EnemyType.BOSS:
			base_velocity = _update_boss_behavior(direction, distance, now)
		EnemyType.ELITE_CHARGER:
			base_velocity = _update_elite_charger_behavior(direction, distance, now)
		EnemyType.ELITE_SPITTER:
			base_velocity = _update_elite_spitter_behavior(direction, distance, now)
		EnemyType.ELITE_SUPPORT:
			base_velocity = _update_elite_support_behavior(direction, distance, now)

	var dash_locked := (
		(enemy_type == EnemyType.CHARGER and now < _charge_dash_ends_at)
		or (enemy_type == EnemyType.ELITE_CHARGER and now < _charge_dash_ends_at)
	)
	if not dash_locked:
		base_velocity += _compute_separation_force(now)
		base_velocity = _apply_obstacle_detour(base_velocity, direction, now)
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	velocity = base_velocity + _knockback_velocity
	move_and_slide()
	_update_blocked_state(base_velocity, direction, delta)
	_maybe_emit_attack_trail(now)
	_apply_motion_polish(now, delta)

	var contact_range: float = maxf(_contact_range, _get_combined_contact_range(target))
	if distance <= contact_range and now >= _next_contact_at:
		_next_contact_at = now + (0.65 if enemy_type == EnemyType.BOSS else 0.45)
		target.apply_damage(contact_damage)

func _apply_obstacle_detour(base_velocity: Vector2, direction: Vector2, now: float) -> Vector2:
	if direction.length() <= 0.0 or base_velocity.length() <= 20.0:
		return base_velocity
	var move_direction: Vector2 = base_velocity.normalized()
	var left_penalty := 0.0
	var right_penalty := 0.0
	if _should_throttle_crowd_queries():
		if now >= _next_feeler_refresh_at:
			var left_direction := move_direction.rotated(-FEELER_SPREAD)
			var right_direction := move_direction.rotated(FEELER_SPREAD)
			_cached_left_penalty = _sample_feeler_penalty(left_direction)
			_cached_right_penalty = _sample_feeler_penalty(right_direction)
			_next_feeler_refresh_at = now + STEERING_REFRESH_INTERVAL + float(get_instance_id() % 5) * 0.005
		left_penalty = _cached_left_penalty
		right_penalty = _cached_right_penalty
	else:
		var left_direction := move_direction.rotated(-FEELER_SPREAD)
		var right_direction := move_direction.rotated(FEELER_SPREAD)
		left_penalty = _sample_feeler_penalty(left_direction)
		right_penalty = _sample_feeler_penalty(right_direction)
	if left_penalty <= 0.0 and right_penalty <= 0.0:
		if _blocked_time < 0.4:
			return base_velocity
		var tangent: Vector2 = Vector2(-direction.y, direction.x) * _detour_sign
		var detour_direction: Vector2 = (direction * 0.22 + tangent * 0.78).normalized()
		return detour_direction * max(base_velocity.length(), move_speed * 0.7)
	var left_normal := move_direction.rotated(-PI * 0.5)
	var right_normal := move_direction.rotated(PI * 0.5)
	var avoidance := Vector2.ZERO
	if left_penalty > 0.0 and right_penalty > 0.0 and absf(left_penalty - right_penalty) < 0.08:
		avoidance = right_normal if _detour_sign > 0.0 else left_normal
	elif left_penalty > right_penalty:
		avoidance = right_normal
	else:
		avoidance = left_normal
	var steer_strength: float = clamp(maxf(left_penalty, right_penalty) * 0.6, 0.0, 0.6)
	var steer_direction := (move_direction * (1.0 - steer_strength) + avoidance.normalized() * steer_strength).normalized()
	return steer_direction * base_velocity.length()

func _update_blocked_state(base_velocity: Vector2, direction: Vector2, delta: float) -> void:
	var moved_distance: float = global_position.distance_to(_last_position)
	var trying_to_move: bool = base_velocity.length() > 20.0 and direction.length() > 0.0
	if trying_to_move and moved_distance < 1.5:
		_blocked_time += delta
		if _blocked_time > 0.9:
			_detour_sign *= -1.0
			_blocked_time = 0.45
	else:
		_blocked_time = maxf(_blocked_time - delta * 2.0, 0.0)
	_last_position = global_position

func _sample_feeler_penalty(feeler_direction: Vector2) -> float:
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + feeler_direction * FEELER_LENGTH)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 1
	query.exclude = _build_feeler_excludes()
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 0.0
	var distance: float = global_position.distance_to(hit.get("position", global_position + feeler_direction * FEELER_LENGTH))
	return clamp(1.0 - distance / FEELER_LENGTH, 0.0, 1.0)

func _build_feeler_excludes() -> Array:
	var frame := Engine.get_physics_frames()
	if _feeler_excludes_frame == frame:
		return _feeler_excludes_cache
	var excludes: Array = [get_rid()]
	if _combat_owner != null and _combat_owner.has_method("get_enemy_target_nodes"):
		for candidate in _combat_owner.get_enemy_target_nodes():
			if candidate == self or not is_instance_valid(candidate) or not (candidate is CollisionObject2D):
				continue
			excludes.append((candidate as CollisionObject2D).get_rid())
	if _combat_owner != null and _combat_owner.has_method("get_player_target_nodes"):
		for player in _combat_owner.get_player_target_nodes():
			if not is_instance_valid(player) or not (player is CollisionObject2D):
				continue
			excludes.append((player as CollisionObject2D).get_rid())
	_feeler_excludes_cache = excludes
	_feeler_excludes_frame = frame
	return _feeler_excludes_cache

func _compute_separation_force(now: float) -> Vector2:
	if _should_throttle_crowd_queries() and now < _next_separation_refresh_at:
		return _cached_separation
	var separation := Vector2.ZERO
	if _combat_owner == null or not _combat_owner.has_method("get_enemy_target_nodes"):
		return separation
	for candidate in _combat_owner.get_enemy_target_nodes():
		if candidate == self or not is_instance_valid(candidate) or not (candidate is CharacterBody2D):
			continue
		if candidate.has_method("is_alive") and not candidate.is_alive():
			continue
		var offset: Vector2 = global_position - (candidate as CharacterBody2D).global_position
		var distance: float = offset.length()
		if distance <= 0.0 or distance >= SEPARATION_RADIUS:
			continue
		var strength: float = pow(1.0 - distance / SEPARATION_RADIUS, SEPARATION_FALLOFF_POWER) * SEPARATION_STRENGTH
		separation += offset.normalized() * strength
	var max_separation: float = move_speed * 0.35
	if separation.length() > max_separation:
		separation = separation.normalized() * max_separation
	_cached_separation = separation
	if _should_throttle_crowd_queries():
		_next_separation_refresh_at = now + STEERING_REFRESH_INTERVAL + float(get_instance_id() % 4) * 0.004
	else:
		_next_separation_refresh_at = now
	return _cached_separation

func _maybe_emit_attack_trail(now: float) -> void:
	if _combat_owner == null or now < _next_attack_trail_at or velocity.length() < 40.0:
		return
	var weight: float = 0.0
	if enemy_type == EnemyType.CHASER and now < _lunge_ends_at:
		weight = 0.95
	elif (enemy_type == EnemyType.CHARGER or enemy_type == EnemyType.ELITE_CHARGER) and now < _charge_dash_ends_at:
		weight = 1.25
	elif enemy_type == EnemyType.BOSS and now < _next_projectile_at and velocity.length() > move_speed * 0.8:
		weight = 1.2
	if weight <= 0.0 or not _combat_owner.has_method("spawn_enemy_attack_trail"):
		return
	_combat_owner.spawn_enemy_attack_trail(global_position, velocity.normalized(), get_feedback_color(), weight)
	_next_attack_trail_at = now + 0.045

func _update_chaser_behavior(direction: Vector2, distance: float, now: float) -> Vector2:
	if now < _lunge_windup_ends_at:
		return Vector2.ZERO
	if now < _lunge_ends_at:
		return _lunge_direction * move_speed * 2.35
	if distance > 0.0 and distance < 520.0 and now >= _next_lunge_at:
		_lunge_direction = direction
		_lunge_windup_ends_at = now + 0.08
		_lunge_ends_at = _lunge_windup_ends_at + 0.24
		_next_lunge_at = now + 0.55
		return Vector2.ZERO
	return direction * move_speed

func _update_charger_behavior(direction: Vector2, distance: float, now: float) -> Vector2:
	if now < _charge_windup_ends_at:
		return Vector2.ZERO
	if now < _charge_recovery_ends_at:
		return direction * move_speed * 0.55
	if now < _charge_dash_ends_at:
		return _charge_direction * move_speed * 5.45
	if distance > 60.0 and distance < 720.0 and now >= _next_charge_at:
		_charge_direction = direction
		_charge_windup_ends_at = now + 0.18
		_charge_dash_ends_at = _charge_windup_ends_at + 0.32
		_charge_recovery_ends_at = _charge_dash_ends_at + 0.45
		_next_charge_at = _charge_recovery_ends_at + 0.1
		_play_charger_windup_telegraph()
		return Vector2.ZERO
	return direction * move_speed * 1.05

func _update_spitter_behavior(direction: Vector2, distance: float, now: float) -> Vector2:
	if distance > 0.0 and now >= _next_projectile_at:
		_next_projectile_at = now + fire_interval
		_emit_projectile_burst(direction)
	if distance < 180.0:
		return -direction * move_speed
	if distance > preferred_distance + 50.0:
		return direction * move_speed * 0.92
	return Vector2(-direction.y, direction.x) * move_speed * _circle_sign * 0.8

func _update_boss_behavior(direction: Vector2, distance: float, now: float) -> Vector2:
	var base_velocity := Vector2.ZERO
	if distance > preferred_distance + 35.0:
		base_velocity = direction * move_speed * 1.05
	elif distance < preferred_distance - 35.0:
		base_velocity = -direction * move_speed * 0.4
	else:
		base_velocity = Vector2(-direction.y, direction.x) * move_speed * 0.28
	if distance > 0.0 and now >= _next_projectile_at:
		_next_projectile_at = now + fire_interval
		_emit_projectile_burst(direction)
	return base_velocity

func _update_elite_charger_behavior(direction: Vector2, distance: float, now: float) -> Vector2:
	if now < _charge_windup_ends_at:
		return Vector2.ZERO
	if now < _charge_recovery_ends_at:
		return direction * move_speed * 0.45
	if now < _charge_dash_ends_at:
		return _charge_direction * move_speed * 5.8
	if _elite_charger_use_slam and distance <= 140.0 and now >= _next_charge_at:
		_elite_charger_use_slam = false
		_next_charge_at = now + 1.2
		_emit_small_slam(180.0, 15, 950.0)
		return direction * move_speed * 0.5
	if distance > 80.0 and distance < 840.0 and now >= _next_charge_at:
		_charge_direction = direction
		_charge_windup_ends_at = now + 0.12
		_charge_dash_ends_at = _charge_windup_ends_at + 0.4
		_charge_recovery_ends_at = _charge_dash_ends_at + 0.35
		_next_charge_at = _charge_recovery_ends_at + 0.2
		_elite_charger_use_slam = true
		_play_charger_windup_telegraph()
		return Vector2.ZERO
	return direction * move_speed

func _update_elite_spitter_behavior(direction: Vector2, distance: float, now: float) -> Vector2:
	var velocity_out := _update_spitter_behavior(direction, distance, now)
	if now >= _elite_spitter_next_pulse_at:
		_elite_spitter_next_pulse_at = now + 4.0
		_emit_player_pulse(200.0, 10, 950.0)
	return velocity_out

func _update_elite_support_behavior(direction: Vector2, distance: float, now: float) -> Vector2:
	if now >= _elite_support_next_pulse_at:
		_elite_support_next_pulse_at = now + 2.0
		_emit_player_pulse(400.0, 15, 760.0)
		_heal_allies_in_radius(400.0, 20)
	if distance > 400.0:
		return direction * move_speed
	if distance < 100.0:
		return -direction * move_speed
	if distance > preferred_distance + 50.0:
		return direction * move_speed * 0.75
	if distance < preferred_distance - 50.0:
		return -direction * move_speed * 0.55
	return Vector2(-direction.y, direction.x) * move_speed * _circle_sign * 0.62

func _emit_projectile_burst(base_direction: Vector2) -> void:
	var normalized_direction := base_direction.normalized()
	if normalized_direction.length() <= 0.0:
		return
	for projectile_direction in _build_spread_directions(normalized_direction, _projectile_burst_count, _projectile_spread_radians):
		fire_requested.emit(
			global_position + projectile_direction * 20.0,
			projectile_direction,
			projectile_speed,
			projectile_damage,
			get_team(),
			visual.color.lightened(0.08),
			_projectile_visual_scale
		)

func _build_spread_directions(base_direction: Vector2, projectile_count: int, spread_radians: float) -> Array:
	var directions: Array = []
	if projectile_count <= 1 or spread_radians <= 0.0:
		directions.append(base_direction)
		return directions
	var center_offset := (projectile_count - 1) * 0.5
	for index in range(projectile_count):
		var offset := (float(index) - center_offset) * spread_radians
		directions.append(base_direction.rotated(offset))
	return directions

func _get_closest_player(now: float):
	if _combat_owner == null:
		return null
	if _should_throttle_crowd_queries() and is_instance_valid(_cached_target) and _cached_target.is_alive() and now < _next_target_refresh_at:
		return _cached_target
	var players: Array = _combat_owner.get_active_players()
	var best_player = null
	var best_distance := INF
	for player in players:
		if not is_instance_valid(player):
			continue
		var distance := global_position.distance_to(player.global_position)
		if distance < best_distance:
			best_distance = distance
			best_player = player
	_cached_target = best_player
	if _should_throttle_crowd_queries():
		_next_target_refresh_at = now + TARGET_REFRESH_INTERVAL + float(get_instance_id() % 3) * 0.01
	else:
		_next_target_refresh_at = now
	return best_player

func _should_throttle_crowd_queries() -> bool:
	if _combat_owner == null or not _combat_owner.has_method("get_enemy_target_nodes"):
		return false
	return _combat_owner.get_enemy_target_nodes().size() >= CROWD_OPTIMIZATION_THRESHOLD

func _apply_type_visual() -> void:
	if visual == null:
		return
	match enemy_type:
		EnemyType.CHARGER:
			visual.color = Color(1.0, 0.54, 0.12, 1.0)
			visual.polygon = PackedVector2Array([Vector2(0, -28), Vector2(24, -10), Vector2(18, 24), Vector2(-18, 24), Vector2(-24, -10)])
			visual.scale = Vector2(1.28, 1.28)
			_set_collision_radius(28.0)
			_contact_range = 38.0
		EnemyType.SPITTER:
			visual.color = Color(0.85, 0.35, 0.85, 1.0)
			visual.polygon = _build_regular_polygon(6, 22.0)
			visual.scale = Vector2.ONE
			_set_collision_radius(22.0)
			_contact_range = 30.0
		EnemyType.BOSS:
			visual.color = Color(0.92, 0.12, 0.16, 1.0)
			visual.polygon = PackedVector2Array([
				Vector2(0, -42), Vector2(14, -34), Vector2(24, -46), Vector2(34, -28), Vector2(48, -12),
				Vector2(44, 22), Vector2(26, 44), Vector2(8, 50), Vector2(-8, 50), Vector2(-26, 44),
				Vector2(-44, 22), Vector2(-48, -12), Vector2(-34, -28), Vector2(-24, -46), Vector2(-14, -34),
			])
			visual.scale = Vector2(1.5, 1.5)
			_set_collision_radius(44.0)
			_contact_range = 54.0
		EnemyType.ELITE_CHARGER:
			visual.color = Color(1.0, 0.85, 0.15, 1.0)
			visual.polygon = _build_regular_polygon(6, 28.0)
			visual.scale = Vector2(2.5, 2.5)
			_set_collision_radius(65.0)
			_contact_range = 78.0
		EnemyType.ELITE_SPITTER:
			visual.color = Color(0.2, 0.85, 0.95, 1.0)
			visual.polygon = _build_regular_polygon(6, 22.0)
			visual.scale = Vector2(1.6, 1.6)
			_set_collision_radius(35.0)
			_contact_range = 42.0
		EnemyType.ELITE_SUPPORT:
			visual.color = Color(0.7, 0.25, 0.9, 1.0)
			visual.polygon = _build_regular_polygon(6, 24.0)
			visual.scale = Vector2(1.8, 1.8)
			_set_collision_radius(42.0)
			_contact_range = 46.0
		_:
			visual.color = Color(1.0, 0.24, 0.2, 1.0)
			visual.polygon = PackedVector2Array([Vector2(0, -30), Vector2(20, 12), Vector2(0, 22), Vector2(-20, 12)])
			visual.scale = Vector2(0.78, 0.78)
			_set_collision_radius(15.0)
			_contact_range = 24.0
	if outline != null:
		outline.polygon = visual.polygon
		outline.scale = visual.scale * 1.28
		outline.color = Color(0.12, 0.02, 0.02, 0.94) if enemy_type == EnemyType.BOSS else Color(0.04, 0.06, 0.08, 0.92)

func _build_regular_polygon(point_count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := -PI * 0.5 + TAU * float(index) / float(point_count)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

func _set_collision_radius(radius: float) -> void:
	if collision_shape == null:
		return
	var circle := collision_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = radius

func _get_combined_contact_range(target: Node) -> float:
	var own_radius: float = _get_collision_radius(self)
	var target_radius: float = _get_collision_radius(target)
	if own_radius <= 0.0 or target_radius <= 0.0:
		return 0.0
	return own_radius + target_radius

func _get_collision_radius(node: Node) -> float:
	if node == null:
		return 0.0
	var shape_node := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return 0.0
	var circle := shape_node.shape as CircleShape2D
	if circle == null:
		return 0.0
	return circle.radius

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _die() -> void:
	_is_dead = true
	clear_aura()
	velocity = Vector2.ZERO
	_knockback_velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if _combat_owner != null and _death_explosion_radius > 0.0 and _death_explosion_damage > 0:
		_combat_owner.handle_enemy_death_explosion(global_position, _death_explosion_radius, _death_explosion_damage)
	_play_flash(Color.WHITE, 0.18)
	enemy_died.emit(self)
	_queue_free_after_flash()

func _play_flash(color: Color, duration: float) -> void:
	if visual == null:
		return
	_outline_pulse = 1.2
	var flash_material := _get_flash_material()
	flash_material.set_shader_parameter("flash_color", color)
	flash_material.set_shader_parameter("flash_intensity", 1.0)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(flash_material, "shader_parameter/flash_intensity", 0.0, duration)

func _play_charger_windup_telegraph() -> void:
	_play_flash(Color.WHITE, 0.22)
	_outline_pulse = 1.45
	if body_root != null:
		body_root.modulate = Color(1.18, 1.18, 1.18, 1.0)
		var tween := create_tween()
		tween.tween_property(body_root, "modulate", Color.WHITE, 0.22)
	if _combat_owner != null and _combat_owner.has_method("handle_enemy_charge_windup"):
		_combat_owner.handle_enemy_charge_windup(global_position)

func _get_flash_material() -> ShaderMaterial:
	if _flash_material != null:
		return _flash_material
	_flash_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = FLASH_SHADER_CODE
	_flash_material.shader = shader
	_flash_material.set_shader_parameter("flash_intensity", 0.0)
	_flash_material.set_shader_parameter("flash_color", Color.WHITE)
	visual.material = _flash_material
	return _flash_material

func _queue_free_after_flash() -> void:
	await get_tree().create_timer(0.12).timeout
	queue_free()

func _apply_motion_polish(now: float, delta: float = 0.0) -> void:
	if body_root == null:
		return
	if delta > 0.0:
		_outline_pulse = move_toward(_outline_pulse, 1.0, delta * 5.0)
	var bob_amount := 3.5
	var bob_frequency := 3.4
	match enemy_type:
		EnemyType.CHASER:
			bob_amount = 3.8
			bob_frequency = 5.3
		EnemyType.CHARGER, EnemyType.ELITE_CHARGER:
			bob_amount = 2.2
			bob_frequency = 1.9
		EnemyType.BOSS:
			bob_amount = 5.8
			bob_frequency = 1.6
		EnemyType.SPITTER, EnemyType.ELITE_SPITTER:
			bob_amount = 2.8
			bob_frequency = 3.2
		EnemyType.ELITE_SUPPORT:
			bob_amount = 2.6
			bob_frequency = 2.2
	var bob := sin(now * bob_frequency + _idle_phase) * bob_amount
	var squash_scale := Vector2.ONE
	if enemy_type == EnemyType.CHASER and now < _lunge_windup_ends_at:
		squash_scale = Vector2(1.18, 0.82)
	elif enemy_type == EnemyType.CHASER and now < _lunge_ends_at:
		squash_scale = Vector2(0.88, 1.24)
	elif (enemy_type == EnemyType.CHARGER or enemy_type == EnemyType.ELITE_CHARGER) and now < _charge_windup_ends_at:
		squash_scale = Vector2(1.26, 0.76)
	elif (enemy_type == EnemyType.CHARGER or enemy_type == EnemyType.ELITE_CHARGER) and now < _charge_dash_ends_at:
		squash_scale = Vector2(0.84, 1.30)
	body_root.position = _base_body_root_position + Vector2(0.0, bob)
	body_root.rotation = lerp_angle(body_root.rotation, clamp(velocity.x / max(move_speed, 1.0), -1.0, 1.0) * 0.08, 0.12)
	body_root.scale = squash_scale
	if outline != null:
		outline.scale = visual.scale * 1.28 * _outline_pulse
	if shadow != null:
		shadow.scale = Vector2(
			_base_shadow_scale.x * (1.0 - abs(bob) * 0.01),
			_base_shadow_scale.y * (1.0 + abs(bob) * 0.015)
		)

func _play_spawn_in_animation() -> void:
	if body_root == null:
		return
	body_root.scale = Vector2(0.1, 0.1)
	body_root.modulate.a = 0.0
	if shadow != null:
		shadow.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(body_root, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(body_root, "modulate:a", 1.0, 0.24)
	if shadow != null:
		tween.tween_property(shadow, "modulate:a", 0.25, 0.24)

func _reset_behavior_state() -> void:
	_lunge_direction = Vector2.ZERO
	_lunge_windup_ends_at = 0.0
	_lunge_ends_at = 0.0
	_next_lunge_at = 0.0
	_charge_direction = Vector2.ZERO
	_charge_windup_ends_at = 0.0
	_charge_dash_ends_at = 0.0
	_charge_recovery_ends_at = 0.0
	_next_charge_at = 0.0
	_blocked_time = 0.0
	_last_position = global_position
	_detour_sign = -1.0 if int(get_instance_id() % 2) == 0 else 1.0
	_circle_sign = -1.0 if int(get_instance_id() % 2) == 0 else 1.0
	_next_attack_trail_at = 0.0
	_elite_support_next_pulse_at = 0.0
	_elite_spitter_next_pulse_at = 0.0
	_elite_charger_use_slam = false

func _emit_player_pulse(radius: float, damage: int, knockback_force: float) -> void:
	if _combat_owner == null:
		return
	for player in _combat_owner.get_active_players():
		if player == null or not is_instance_valid(player):
			continue
		var offset: Vector2 = player.global_position - global_position
		if offset.length() > radius:
			continue
		player.apply_damage(damage)
		if player.has_method("apply_knockback"):
			player.apply_knockback(offset.normalized(), knockback_force)

func _heal_allies_in_radius(radius: float, amount: int) -> void:
	if _combat_owner == null or not _combat_owner.has_method("get_enemy_target_nodes"):
		return
	for enemy in _combat_owner.get_enemy_target_nodes():
		if enemy == self or enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(global_position) > radius:
			continue
		if enemy.has_method("heal"):
			enemy.heal(amount)

func _emit_small_slam(radius: float, damage: int, knockback_force: float) -> void:
	_emit_player_pulse(radius, damage, knockback_force)
