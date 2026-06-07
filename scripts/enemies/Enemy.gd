extends CharacterBody2D

const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")
const PULSAR_ARENA_MARGIN := 260.0
const PULSAR_TELEPORT_MIN_DISTANCE := 400.0
const PULSAR_REACTIVE_TELEPORT_DISTANCE := 250.0
const SEPARATION_RADIUS := 64.0
const SEPARATION_STRENGTH := 120.0
const BLOOM_COLOR_MULTIPLIER := 1.45
const READABILITY_VISUAL_SCALE := 1.3

signal enemy_died(enemy)
signal fire_requested(origin, direction, speed, damage, team, color, projectile_scale)
signal hit_received(enemy, damage_amount, lethal)

enum EnemyType {
	CHASER,
	CHARGER,
	SPITTER,
	SPLITTER,
	SPLITTER_MINI,
	BOMBER,
	ELITE_CHARGER,
	ELITE_SPITTER,
	ELITE_SUPPORT,
	BOSS_WARDEN,
	BOSS_HYDRA,
	BOSS_HIVE,
	BOSS_PULSAR,
}

@export var contact_damage: int = 10
@export var projectile_speed: float = 340.0
@export var projectile_damage: int = 10

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var body_root: Node2D = $BodyRoot
@onready var visual: Polygon2D = $BodyRoot/Visual

var enemy_type: EnemyType = EnemyType.CHASER
var max_health: float = 21.0
var current_health: float = 21.0
var move_speed: float = 120.0
var fire_interval: float = 1.2
var _base_move_speed: float = 120.0
var _base_fire_interval: float = 1.2
var _aura_speed_mult := 1.0
var _aura_attack_mult := 1.0
var _modifier_speed_mult := 1.0
var _modifier_attack_mult := 1.0
var _target: Node2D = null
var _combat_owner: Node = null
var _random := RandomNumberGenerator.new()
var _next_contact_at := 0.0
var _next_fire_at := 0.0
var _next_ability_at := 0.0
var _next_spawn_at := 0.0
var _next_burst_at := 0.0
var _next_trail_at := 0.0
var _charge_until := 0.0
var _charge_direction := Vector2.RIGHT
var _charge_chain_remaining := 0
var _external_velocity := Vector2.ZERO
var _shield_active := false
var _slow_multiplier := 1.0
var _slow_until := 0.0
var _poison_dps := 0.0
var _poison_until := 0.0
var _poison_tick_at := 0.0
var _death_explosion_radius := 0.0
var _death_explosion_damage := 0
var _fuse_active := false
var _fuse_ends_at := 0.0
var _hydra_rotation := 0.0
var _boss_scale := 1.0
var _feedback_color := Color(1.0, 0.26, 0.22, 1.0)
var _feedback_weight := 1.0
var _alive := true
var _base_visual_scale := Vector2.ONE
var _base_collision_radius := 19.0
var _pulsar_teleport_at := 0.0
var _pulsar_telegraph_until := 0.0
var _pulsar_emp_at := 0.0
var _boss_phase_index := 0
var _elite_charge_slam_pending := false
var _elite_cd_mult := 1.0
var _warden_leap_pending := false
var _warden_leap_land_at := 0.0
var _warden_leap_target := Vector2.ZERO
var _warden_charge_slam_pending := false
var _warden_charge_windup_until := 0.0
var _profiled_attack_markers: Dictionary = {}
var _hydra_sweep_until := 0.0
var _hydra_sweep_windup_until := 0.0
var _hydra_sweep_started_at := 0.0
var _hydra_next_sweep_shot_at := 0.0
var _hydra_sweep_start_angle := 0.0
var _hydra_radial_burst_at := 0.0
var _hydra_orb_at := 0.0
var _hive_burrow_until := 0.0
var _hive_burrow_pending := false
var _hive_pressure_at := 0.0
var _boss_invulnerable_until := 0.0
var _boss_windup_until := 0.0
var _boss_deflector_nodes: Array = []
var _boss_deflector_phase_index := -1
var _target_refresh_frame_offset := 0
var _target_refresh_interval := 4

func _ready() -> void:
	_random.randomize()
	add_to_group("aim_target")
	if visual != null:
		_base_visual_scale = visual.scale
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		collision_shape.shape = (collision_shape.shape as CircleShape2D).duplicate()
		_base_collision_radius = (collision_shape.shape as CircleShape2D).radius

func setup(type_name: String, combat_owner: Node) -> void:
	_combat_owner = combat_owner
	_alive = true
	_target = null
	_external_velocity = Vector2.ZERO
	_shield_active = false
	_slow_multiplier = 1.0
	_slow_until = 0.0
	_poison_dps = 0.0
	_poison_until = 0.0
	_poison_tick_at = 0.0
	_death_explosion_radius = 0.0
	_death_explosion_damage = 0
	_fuse_active = false
	_fuse_ends_at = 0.0
	_hydra_rotation = _random.randf_range(0.0, TAU)
	_next_trail_at = 0.0
	_charge_chain_remaining = 0
	_boss_scale = 1.0
	_pulsar_teleport_at = 0.0
	_pulsar_telegraph_until = 0.0
	_pulsar_emp_at = 0.0
	_boss_phase_index = 0
	_elite_charge_slam_pending = false
	_elite_cd_mult = 1.0
	_warden_leap_pending = false
	_warden_leap_land_at = 0.0
	_warden_leap_target = Vector2.ZERO
	_warden_charge_slam_pending = false
	_warden_charge_windup_until = 0.0
	_hydra_sweep_until = 0.0
	_hydra_sweep_windup_until = 0.0
	_hydra_sweep_started_at = 0.0
	_hydra_next_sweep_shot_at = 0.0
	_hydra_sweep_start_angle = 0.0
	_hydra_radial_burst_at = 0.0
	_hydra_orb_at = 0.0
	_hive_burrow_until = 0.0
	_hive_burrow_pending = false
	_hive_pressure_at = 0.0
	_boss_invulnerable_until = 0.0
	_boss_windup_until = 0.0
	_boss_deflector_nodes.clear()
	_boss_deflector_phase_index = -1
	_target_refresh_frame_offset = int(get_instance_id() % _target_refresh_interval)
	_configure_type(type_name)
	current_health = max_health
	_update_visual_state()

func _configure_type(type_name: String) -> void:
	match type_name:
		"chaser":
			enemy_type = EnemyType.CHASER
			max_health = 20.0
			move_speed = 150.0
			fire_interval = 99.0
			projectile_damage = 0
			projectile_speed = 0.0
			contact_damage = 8
			_feedback_color = Color(0.96, 0.24, 0.26, 1.0)
			_feedback_weight = 0.9
		"charger":
			enemy_type = EnemyType.CHARGER
			max_health = 45.0
			move_speed = 196.0
			fire_interval = 99.0
			projectile_damage = 0
			projectile_speed = 0.0
			contact_damage = 18
			_feedback_color = Color(1.0, 0.48, 0.18, 1.0)
			_feedback_weight = 1.1
		"spitter":
			enemy_type = EnemyType.SPITTER
			max_health = 15.0
			move_speed = 350.0
			fire_interval = 1.35
			projectile_damage = 12
			projectile_speed = 380.0
			contact_damage = 6
			_feedback_color = Color(0.4, 0.9, 1.0, 1.0)
			_feedback_weight = 1.0
		"splitter":
			enemy_type = EnemyType.SPLITTER
			max_health = 25.0
			move_speed = 125.0
			fire_interval = 99.0
			projectile_damage = 0
			projectile_speed = 0.0
			contact_damage = 8
			_feedback_color = Color(0.3, 0.9, 0.4, 1.0)
			_feedback_weight = 1.0
		"splitter_mini":
			enemy_type = EnemyType.SPLITTER_MINI
			max_health = 8.0
			move_speed = 250.0
			fire_interval = 99.0
			projectile_damage = 0
			projectile_speed = 0.0
			contact_damage = 6
			_feedback_color = Color(1.0, 0.7, 0.95, 1.0)
			_feedback_weight = 0.65
		"bomber":
			enemy_type = EnemyType.BOMBER
			max_health = 30.0
			move_speed = 100.0
			fire_interval = 99.0
			projectile_damage = 0
			projectile_speed = 0.0
			contact_damage = 5
			_feedback_color = Color(0.9, 0.3, 0.15, 1.0)
			_feedback_weight = 1.15
		"elite_charger":
			enemy_type = EnemyType.ELITE_CHARGER
			max_health = 500.0
			move_speed = 250.0
			fire_interval = 99.0
			projectile_damage = 0
			projectile_speed = 0.0
			contact_damage = 28
			_feedback_color = Color(1.0, 0.54, 0.18, 1.0)
			_feedback_weight = 1.75
		"elite_spitter":
			enemy_type = EnemyType.ELITE_SPITTER
			max_health = 380.0
			move_speed = 320.0
			fire_interval = 0.8
			projectile_damage = 20
			projectile_speed = 470.0
			contact_damage = 12
			_feedback_color = Color(0.46, 0.98, 1.0, 1.0)
			_feedback_weight = 1.6
		"elite_support":
			enemy_type = EnemyType.ELITE_SUPPORT
			max_health = 440.0
			move_speed = 220.0
			fire_interval = 99.0
			projectile_damage = 0
			projectile_speed = 0.0
			contact_damage = 10
			_feedback_color = Color(0.72, 0.98, 0.48, 1.0)
			_feedback_weight = 1.55
		"boss_warden":
			enemy_type = EnemyType.BOSS_WARDEN
			max_health = 800.0
			move_speed = 178.0
			fire_interval = 99.0
			projectile_damage = 16
			projectile_speed = 0.0
			contact_damage = 35
			_feedback_color = Color(1.0, 0.32, 0.26, 1.0)
			_feedback_weight = 2.2
		"boss_hydra":
			enemy_type = EnemyType.BOSS_HYDRA
			max_health = 1000.0
			move_speed = 0.0
			fire_interval = 1.2
			projectile_damage = 16
			projectile_speed = 460.0
			contact_damage = 35
			_feedback_color = Color(0.44, 0.78, 1.0, 1.0)
			_feedback_weight = 2.0
		"boss_hive":
			enemy_type = EnemyType.BOSS_HIVE
			max_health = 900.0
			move_speed = 145.0
			fire_interval = 99.0
			projectile_damage = 16
			projectile_speed = 0.0
			contact_damage = 35
			_feedback_color = Color(0.8, 0.36, 0.9, 1.0)
			_feedback_weight = 2.0
		"boss_pulsar":
			enemy_type = EnemyType.BOSS_PULSAR
			max_health = 950.0
			move_speed = 0.0
			fire_interval = 0.9
			projectile_damage = 16
			projectile_speed = 440.0
			contact_damage = 35
			_feedback_color = Color(0.88, 0.96, 1.0, 1.0)
			_feedback_weight = 2.0
		_:
			_configure_type("chaser")
			return
	_base_move_speed = move_speed
	_base_fire_interval = fire_interval
	_next_fire_at = _current_time_seconds() + _random.randf_range(0.0, 0.4)
	_next_ability_at = _next_fire_at
	_next_spawn_at = _current_time_seconds() + 2.0
	_next_burst_at = _current_time_seconds() + 4.0

func apply_room_modifier(config: Dictionary) -> void:
	if config.is_empty():
		return
	var health_mult := float(config.get("health_multiplier", 1.0))
	var speed_mult := float(config.get("speed_multiplier", 1.0))
	var fire_interval_mult := float(config.get("fire_interval_multiplier", 1.0))
	max_health *= health_mult
	current_health *= health_mult
	_modifier_speed_mult *= speed_mult
	_modifier_attack_mult *= fire_interval_mult
	contact_damage += int(config.get("contact_damage_bonus", 0))
	_shield_active = bool(config.get("shielded", false))
	_death_explosion_radius = float(config.get("death_explosion_radius", _death_explosion_radius))
	_death_explosion_damage = int(config.get("death_explosion_damage", _death_explosion_damage))
	_update_visual_state()

func apply_boss_scale(player_count: int) -> void:
	if not is_boss():
		return
	_boss_scale = 1.0 + max(player_count - 1, 0) * 0.6
	if enemy_type == EnemyType.BOSS_WARDEN:
		max_health = 800.0 * _boss_scale
	elif enemy_type == EnemyType.BOSS_HYDRA:
		max_health = 1000.0 * _boss_scale
	elif enemy_type == EnemyType.BOSS_HIVE:
		max_health = 900.0 * _boss_scale
	elif enemy_type == EnemyType.BOSS_PULSAR:
		max_health = 950.0 * _boss_scale
	current_health = max_health

func begin_boss_windup(seconds: float) -> void:
	if not is_boss():
		return
	var now := _current_time_seconds()
	_boss_windup_until = now + maxf(seconds, 0.0)
	_boss_invulnerable_until = maxf(_boss_invulnerable_until, _boss_windup_until)
	_next_fire_at = maxf(_next_fire_at, _boss_windup_until + 0.3)
	_next_ability_at = maxf(_next_ability_at, _boss_windup_until + 0.5)
	_next_spawn_at = maxf(_next_spawn_at, _boss_windup_until + 0.8)
	_next_burst_at = maxf(_next_burst_at, _boss_windup_until + 0.8)
	_spawn_boss_attack_telegraph(220.0)

func apply_elite_act_scale(act: int) -> void:
	if not get_type_name().begins_with("elite_"):
		return
	if act < 2:
		return
	max_health *= 1.5
	current_health = max_health
	contact_damage = int(contact_damage * 1.3)
	projectile_damage = int(projectile_damage * 1.3)
	_elite_cd_mult = 0.75
	_update_visual_state()

func apply_aura(speed_mult: float, attack_mult: float) -> void:
	_aura_speed_mult = speed_mult
	_aura_attack_mult = attack_mult

func clear_aura() -> void:
	_aura_speed_mult = 1.0
	_aura_attack_mult = 1.0

func get_team() -> String:
	return "enemy"

func is_alive() -> bool:
	return _alive

func is_boss() -> bool:
	return enemy_type == EnemyType.BOSS_WARDEN or enemy_type == EnemyType.BOSS_HYDRA or enemy_type == EnemyType.BOSS_HIVE or enemy_type == EnemyType.BOSS_PULSAR

func get_feedback_color() -> Color:
	return _feedback_color

func get_feedback_weight() -> float:
	return _feedback_weight

func get_collision_radius() -> float:
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		return (collision_shape.shape as CircleShape2D).radius
	return _base_collision_radius

func get_type_name() -> String:
	match enemy_type:
		EnemyType.CHARGER:
			return "charger"
		EnemyType.SPITTER:
			return "spitter"
		EnemyType.SPLITTER:
			return "splitter"
		EnemyType.SPLITTER_MINI:
			return "splitter_mini"
		EnemyType.BOMBER:
			return "bomber"
		EnemyType.ELITE_CHARGER:
			return "elite_charger"
		EnemyType.ELITE_SPITTER:
			return "elite_spitter"
		EnemyType.ELITE_SUPPORT:
			return "elite_support"
		EnemyType.BOSS_WARDEN:
			return "boss_warden"
		EnemyType.BOSS_HYDRA:
			return "boss_hydra"
		EnemyType.BOSS_HIVE:
			return "boss_hive"
		EnemyType.BOSS_PULSAR:
			return "boss_pulsar"
		_:
			return "chaser"

func apply_damage(amount: int) -> void:
	if not _alive or amount <= 0:
		return
	_cleanup_boss_deflector_nodes()
	if is_boss() and (_boss_deflector_nodes.size() > 0 or _current_time_seconds() < _boss_invulnerable_until):
		_spawn_hit_particles(0.75, true)
		return
	if _shield_active:
		_shield_active = false
		_spawn_hit_particles(1.1, true)
		_update_visual_state()
		return
	current_health = max(current_health - amount, 0.0)
	var lethal := current_health <= 0.0
	hit_received.emit(self, amount, lethal)
	if lethal:
		_die()
	else:
		_spawn_hit_particles(1.0)
		_update_visual_state()

func apply_knockback(direction: Vector2, force: float) -> void:
	if force <= 0.0:
		return
	if is_boss():
		return
	var normalized := direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT
	_external_velocity += normalized * force * 0.003

func apply_slow(multiplier: float, duration: float) -> void:
	_slow_multiplier = min(_slow_multiplier, clampf(multiplier, 0.15, 1.0))
	_slow_until = max(_slow_until, _current_time_seconds() + max(duration, 0.1))

func apply_stacking_slow(step: float, floor_multiplier: float, duration: float) -> void:
	var clamped_floor := clampf(floor_multiplier, 0.01, 1.0)
	var clamped_step := clampf(step, 0.01, 1.0)
	var next_multiplier := maxf(_slow_multiplier * clamped_step, clamped_floor)
	_slow_multiplier = min(_slow_multiplier, next_multiplier)
	_slow_until = max(_slow_until, _current_time_seconds() + max(duration, 0.1))

func apply_poison(dps: float, duration: float) -> void:
	_poison_dps += max(dps, 0.0)
	_poison_until = max(_poison_until, _current_time_seconds() + max(duration, 0.1))
	_poison_tick_at = min(_poison_tick_at, _current_time_seconds() + 0.2) if _poison_tick_at > 0.0 else _current_time_seconds() + 0.2

func _physics_process(delta: float) -> void:
	if not _alive:
		return
	var now := _current_time_seconds()
	_update_status_effects(now)
	_update_boss_phase_transition(now)
	_refresh_target_if_due()
	if is_boss() and now < _boss_windup_until:
		velocity = _external_velocity
		move_and_slide()
		_update_dynamic_visuals()
		return
	var desired_velocity := Vector2.ZERO
	if _target != null:
		var offset := _target.global_position - global_position
		var distance := offset.length()
		var direction := offset.normalized() if distance > 0.0 else Vector2.RIGHT
		match enemy_type:
			EnemyType.CHASER, EnemyType.SPLITTER, EnemyType.SPLITTER_MINI:
				desired_velocity = direction * _get_effective_move_speed()
			EnemyType.CHARGER, EnemyType.ELITE_CHARGER:
				desired_velocity = _update_charger_behavior(direction, distance, now)
			EnemyType.SPITTER, EnemyType.ELITE_SPITTER:
				desired_velocity = _update_spitter_behavior(direction, distance, now)
			EnemyType.BOMBER:
				desired_velocity = _update_bomber_behavior(direction, distance, now)
			EnemyType.ELITE_SUPPORT:
				desired_velocity = _update_support_behavior(direction, distance, now)
			EnemyType.BOSS_WARDEN:
				desired_velocity = _update_warden_behavior(direction, distance, now)
			EnemyType.BOSS_HYDRA:
				desired_velocity = _update_hydra_behavior(now)
			EnemyType.BOSS_HIVE:
				desired_velocity = _update_hive_behavior(direction, distance, now)
			EnemyType.BOSS_PULSAR:
				desired_velocity = _update_pulsar_behavior(direction, distance, now)
		_attempt_contact_damage(now)
	if _external_velocity.length() > 0.0:
		_external_velocity = _external_velocity.move_toward(Vector2.ZERO, delta * 14.0)
	desired_velocity += _apply_separation()
	velocity = desired_velocity + _external_velocity
	move_and_slide()
	_update_dynamic_visuals()

func _apply_separation() -> Vector2:
	if is_boss() or _combat_owner == null:
		return Vector2.ZERO
	var enemy_nodes: Array = []
	if _combat_owner.has_method("get_nearby_enemy_target_nodes"):
		enemy_nodes = _combat_owner.get_nearby_enemy_target_nodes(global_position, SEPARATION_RADIUS)
	elif _combat_owner.has_method("get_enemy_target_nodes"):
		enemy_nodes = _combat_owner.get_enemy_target_nodes()
	if enemy_nodes.size() < 3:
		return Vector2.ZERO
	var push := Vector2.ZERO
	for neighbor in enemy_nodes:
		if neighbor == self or neighbor == null or not is_instance_valid(neighbor) or not (neighbor is Node2D):
			continue
		if neighbor.has_method("is_boss") and neighbor.is_boss():
			continue
		if neighbor.has_method("is_alive") and not neighbor.is_alive():
			continue
		var offset := global_position - (neighbor as Node2D).global_position
		var distance := offset.length()
		if distance <= 0.0 or distance >= SEPARATION_RADIUS:
			continue
		push += offset.normalized() * (1.0 - distance / SEPARATION_RADIUS) * SEPARATION_STRENGTH
	var max_push := _get_effective_move_speed() * 0.8
	if push.length() > max_push:
		push = push.normalized() * max_push
	return push

func _update_status_effects(now: float) -> void:
	if now >= _slow_until:
		_slow_multiplier = 1.0
	if _poison_dps > 0.0 and now >= _poison_tick_at:
		_poison_tick_at = now + 0.5
		if now <= _poison_until:
			apply_damage(maxi(1, int(round(_poison_dps * 0.5))))
		else:
			_poison_dps = 0.0

func _update_boss_phase_transition(now: float) -> void:
	if not is_boss():
		return
	var next_phase := 0
	var phase := _get_phase_ratio()
	if phase >= 0.66:
		next_phase = 2
	elif phase >= 0.33:
		next_phase = 1
	if next_phase <= _boss_phase_index:
		return
	_boss_phase_index = next_phase
	_next_ability_at = minf(_next_ability_at, now + 0.4)
	_next_burst_at = minf(_next_burst_at, now + 0.8)
	_next_spawn_at = minf(_next_spawn_at, now + 1.0)
	if enemy_type == EnemyType.BOSS_HYDRA and _combat_owner != null and _combat_owner.has_method("spawn_enemy_minion_mix"):
		_combat_owner.spawn_enemy_minion_mix(global_position, _random.randi_range(4, 6), ["chaser", "splitter"])
	if enemy_type == EnemyType.BOSS_HIVE:
		_cleanup_boss_deflector_nodes()
		if _boss_deflector_nodes.is_empty():
			_boss_deflector_phase_index = -1
			_spawn_boss_deflector(4)
	if _combat_owner != null and _combat_owner.has_method("notify_boss_phase_transition"):
		_combat_owner.notify_boss_phase_transition(self, _boss_phase_index)
	_spawn_phase_transition_telegraph()

func _spawn_phase_transition_telegraph() -> void:
	_spawn_hit_particles(1.35, true)
	if _combat_owner != null and _combat_owner.has_method("spawn_enemy_shockwave"):
		_combat_owner.spawn_enemy_shockwave(global_position, 230.0, 0, 760.0, _feedback_color, true)
	var parent_node := get_parent()
	if parent_node == null:
		return
	var ring := ParticleFactoryData.create_explosion_ring(_feedback_color.lightened(0.2), 180.0 + float(_boss_phase_index) * 55.0, 4.5)
	ring.global_position = global_position
	parent_node.add_child(ring)

func _spawn_boss_attack_telegraph(radius: float) -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	var ring := ParticleFactoryData.create_impact_ring(_feedback_color.lightened(0.18), radius, 3.4)
	ring.global_position = global_position
	parent_node.add_child(ring)

func _find_target() -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	var taunt_target := _find_taunting_decoy(tree)
	if taunt_target != null:
		return taunt_target
	var best_target: Node2D = null
	var best_distance := INF
	for candidate in tree.get_nodes_in_group("player_target"):
		if not is_instance_valid(candidate) or not (candidate is Node2D):
			continue
		if candidate.has_method("is_targetable") and not candidate.is_targetable():
			continue
		if candidate.has_method("is_alive") and not candidate.is_alive():
			continue
		var distance := global_position.distance_to((candidate as Node2D).global_position)
		if distance < best_distance:
			best_distance = distance
			best_target = candidate as Node2D
	return best_target

func _find_taunting_decoy(tree: SceneTree) -> Node2D:
	var best_target: Node2D = null
	var best_distance := INF
	for candidate in tree.get_nodes_in_group("decoy_taunt"):
		if not is_instance_valid(candidate) or not (candidate is Node2D):
			continue
		if candidate.has_method("is_taunting") and not candidate.is_taunting():
			continue
		if candidate.has_method("is_alive") and not candidate.is_alive():
			continue
		var target_node := candidate as Node2D
		var taunt_radius := float(candidate.get_taunt_radius()) if candidate.has_method("get_taunt_radius") else 700.0
		var distance := global_position.distance_to(target_node.global_position)
		if distance <= taunt_radius and distance < best_distance:
			best_distance = distance
			best_target = target_node
	return best_target

func _refresh_target_if_due() -> void:
	var frame := Engine.get_physics_frames()
	if _target != null and is_instance_valid(_target) and frame % _target_refresh_interval != _target_refresh_frame_offset:
		return
	_target = _find_target()

func _get_lead_direction(fallback_direction: Vector2, _shot_speed: float, lead_time: float) -> Vector2:
	if _target == null or not is_instance_valid(_target):
		return fallback_direction
	var target_position := _target.global_position
	if _target is CharacterBody2D:
		target_position += (_target as CharacterBody2D).velocity * lead_time
	var offset := target_position - global_position
	return offset.normalized() if offset.length() > 0.0 else fallback_direction

func _attempt_contact_damage(now: float) -> void:
	if now < _next_contact_at:
		return
	var tree := get_tree()
	if tree == null:
		return
	var any_hit := false
	var contact_range := _get_contact_range()
	var range_squared := contact_range * contact_range
	for candidate in tree.get_nodes_in_group("player_target"):
		if not is_instance_valid(candidate) or not (candidate is Node2D):
			continue
		if candidate.has_method("is_alive") and not candidate.is_alive():
			continue
		var target_node := candidate as Node2D
		if global_position.distance_squared_to(target_node.global_position) > range_squared:
			continue
		if not candidate.has_method("apply_damage"):
			continue
		var can_apply_hit_feedback := true
		if candidate.has_method("can_receive_damage"):
			can_apply_hit_feedback = bool(candidate.can_receive_damage())
		candidate.apply_damage(contact_damage)
		if can_apply_hit_feedback and candidate.has_method("apply_knockback"):
			var knockback_direction := (target_node.global_position - global_position).normalized()
			if knockback_direction.length() <= 0.0:
				knockback_direction = Vector2.RIGHT
			candidate.apply_knockback(knockback_direction, _get_contact_knockback_force())
		any_hit = true
	if any_hit:
		_next_contact_at = now + (0.65 if is_boss() else 0.45)

func _get_contact_range() -> float:
	if collision_shape == null or not (collision_shape.shape is CircleShape2D):
		return 60.0
	return (collision_shape.shape as CircleShape2D).radius + 45.0

func _update_charger_behavior(direction: Vector2, distance: float, now: float) -> Vector2:
	var phase := _get_phase_ratio()
	var is_elite := enemy_type == EnemyType.ELITE_CHARGER
	var charge_speed := _get_effective_move_speed() * ((3.8 + phase) if is_elite else (3.0 + phase * 0.8))
	if now < _charge_until:
		return _charge_direction * charge_speed
	if is_elite and _elite_charge_slam_pending:
		_elite_charge_slam_pending = false
		if _combat_owner != null and _combat_owner.has_method("spawn_enemy_shockwave"):
			_combat_owner.spawn_enemy_shockwave(global_position, 190.0, 12, 620.0, _feedback_color, false)
	var charge_cooldown := lerpf(1.8, 1.1, phase) if is_elite else lerpf(2.4, 1.35, phase)
	var charge_range := 760.0 if is_elite else 440.0
	if distance <= charge_range and now >= _next_ability_at:
		_charge_direction = direction
		_charge_until = now + (0.72 if is_elite else 0.55)
		_next_ability_at = now + charge_cooldown * (_elite_cd_mult if is_elite else 1.0)
		_elite_charge_slam_pending = is_elite
		if _combat_owner != null and _combat_owner.has_method("handle_enemy_charge_windup"):
			_combat_owner.handle_enemy_charge_windup(global_position)
	return direction * _get_effective_move_speed()

func _update_spitter_behavior(direction: Vector2, distance: float, now: float) -> Vector2:
	var desired_velocity := Vector2.ZERO
	if distance < 340.0:
		desired_velocity = -direction * _get_effective_move_speed() * 0.8
	elif distance > 640.0:
		desired_velocity = direction * _get_effective_move_speed() * 0.8
	if now >= _next_fire_at and distance > 120.0:
		var is_elite := enemy_type == EnemyType.ELITE_SPITTER
		_next_fire_at = now + _get_effective_fire_interval() * (_elite_cd_mult if is_elite else 1.0)
		var attack_direction := _get_lead_direction(direction, projectile_speed, 0.35) if enemy_type == EnemyType.ELITE_SPITTER else direction
		_emit_projectiles_at(attack_direction, 1 if enemy_type == EnemyType.SPITTER else 5, 0.16 if enemy_type == EnemyType.ELITE_SPITTER else 0.0, 0.9 if enemy_type == EnemyType.ELITE_SPITTER else 0.7)
	if enemy_type == EnemyType.ELITE_SPITTER and now >= _next_ability_at:
		_next_ability_at = now + 4.0 * _elite_cd_mult
		if _combat_owner != null and _combat_owner.has_method("spawn_enemy_shockwave"):
			_combat_owner.spawn_enemy_shockwave(global_position, 180.0, 10, 520.0, _feedback_color, false)
	return desired_velocity

func _update_bomber_behavior(direction: Vector2, distance: float, now: float) -> Vector2:
	if not _fuse_active and distance <= 180.0:
		_fuse_active = true
		_fuse_ends_at = now + 1.5
	if _fuse_active and now >= _fuse_ends_at:
		_trigger_bomber_explosion()
		return Vector2.ZERO
	return direction * _get_effective_move_speed()

func _update_support_behavior(direction: Vector2, _distance: float, now: float) -> Vector2:
	var perpendicular := direction.orthogonal().normalized()
	var orbit_bias := perpendicular if int(now * 2.0) % 2 == 0 else -perpendicular
	if now >= _next_ability_at:
		_next_ability_at = now + 3.5 * _elite_cd_mult
		if _combat_owner != null and _combat_owner.has_method("spawn_enemy_minions"):
			_combat_owner.spawn_enemy_minions(global_position, _random.randi_range(1, 2), 0.0, "splitter_mini")
		if _combat_owner != null and _combat_owner.has_method("spawn_enemy_shockwave"):
			_combat_owner.spawn_enemy_shockwave(global_position, 210.0, 9, 420.0, _feedback_color, false)
	return (direction * 0.45 + orbit_bias * 0.55).normalized() * _get_effective_move_speed()

func _update_warden_behavior(direction: Vector2, _distance: float, now: float) -> Vector2:
	var phase := _get_phase_ratio()
	if now >= _next_spawn_at:
		_profile_attack_first_use("warden_minions")
		_next_spawn_at = now + (7.0 if phase < 0.66 else 5.0)
		if _combat_owner != null and _combat_owner.has_method("spawn_enemy_minions"):
			_combat_owner.spawn_enemy_minions(global_position, 1 + _boss_phase_index, phase)
	if _warden_leap_pending:
		if now < _warden_leap_land_at:
			return Vector2.ZERO
		_warden_leap_pending = false
		global_position = _warden_leap_target
		if _combat_owner != null and _combat_owner.has_method("spawn_enemy_shockwave"):
			_combat_owner.spawn_enemy_shockwave(global_position, 140.0, 20, 620.0, _feedback_color, false)
	if now < _charge_until:
		if now < _warden_charge_windup_until:
			return Vector2.ZERO
		if _combat_owner != null and _combat_owner.has_method("spawn_enemy_hazard_zone") and now >= _next_trail_at:
			_next_trail_at = now + 0.08
			_combat_owner.spawn_enemy_hazard_zone(global_position, 52.0, 2.0, 10, Color(1.0, 0.68, 0.28, 0.28))
		return _charge_direction * (_get_effective_move_speed() * (3.4 + phase))
	if _warden_charge_slam_pending:
		_warden_charge_slam_pending = false
		_profile_attack_first_use("warden_charge_slam")
		if _combat_owner != null and _combat_owner.has_method("spawn_enemy_shockwave"):
			_combat_owner.spawn_enemy_shockwave(global_position, 80.0, 12, 420.0, _feedback_color, false)
	if _charge_chain_remaining > 0:
		_charge_chain_remaining -= 1
		_charge_direction = direction
		_warden_charge_windup_until = now + 0.8
		_charge_until = _warden_charge_windup_until + 0.5
		_next_trail_at = now
		_warden_charge_slam_pending = true
		if _combat_owner != null and _combat_owner.has_method("handle_enemy_charge_windup"):
			_combat_owner.handle_enemy_charge_windup(global_position)
		return _charge_direction * (_get_effective_move_speed() * (3.6 + phase))
	if now >= _next_burst_at:
		_profile_attack_first_use("warden_ground_pound")
		_next_burst_at = now + lerpf(5.0, 4.0, phase)
		_spawn_boss_attack_telegraph(220.0)
		if _combat_owner != null and _combat_owner.has_method("schedule_enemy_shockwave"):
			_combat_owner.schedule_enemy_shockwave(global_position, 260.0, 15, 700.0, _feedback_color, 0.8, false)
	if now >= _next_fire_at:
		_profile_attack_first_use("warden_leap")
		_next_fire_at = now + lerpf(6.0, 5.0, phase)
		_warden_leap_pending = true
		_warden_leap_land_at = now + 0.8
		_warden_leap_target = _target.global_position if _target != null and is_instance_valid(_target) else global_position + direction * 320.0
		_spawn_boss_attack_telegraph(140.0)
		if _combat_owner != null and _combat_owner.has_method("spawn_enemy_hazard_zone"):
			_combat_owner.spawn_enemy_hazard_zone(_warden_leap_target, 140.0, 0.6, 0, Color(1.0, 0.28, 0.18, 0.28))
	elif now >= _next_ability_at:
		_profile_attack_first_use("warden_charge_combo")
		_charge_direction = direction
		_warden_charge_windup_until = now + 0.8
		_charge_until = _warden_charge_windup_until + 0.55
		_next_trail_at = now
		_charge_chain_remaining = 2 if _boss_phase_index >= 2 else 1 if _boss_phase_index >= 1 else 0
		_warden_charge_slam_pending = true
		_next_ability_at = now + (2.2 if phase >= 0.5 else 3.1)
		if _combat_owner != null and _combat_owner.has_method("handle_enemy_charge_windup"):
			_combat_owner.handle_enemy_charge_windup(global_position)
	return direction * _get_effective_move_speed() * (1.0 + phase * 0.8)

func _update_hydra_behavior(now: float) -> Vector2:
	var phase := _get_phase_ratio()
	var rotation_speed := deg_to_rad(10.0 if phase < 0.25 else 18.0 if phase < 0.5 else 24.0)
	var rotation_sign := -1.0 if phase >= 0.5 and int(floor(now)) % 4 < 2 else 1.0
	_hydra_rotation = fmod(_hydra_rotation + rotation_speed * rotation_sign * get_physics_process_delta_time(), TAU)
	if _hydra_radial_burst_at > 0.0 and now >= _hydra_radial_burst_at:
		_profile_attack_first_use("hydra_radial_burst")
		_hydra_radial_burst_at = 0.0
		for burst_index in range(12):
			var burst_angle := _hydra_rotation + TAU * float(burst_index) / 12.0
			_emit_projectile_burst(Vector2.RIGHT.rotated(burst_angle), 1, 0.0, 1.12)
	if _hydra_sweep_until > now and now >= _hydra_sweep_windup_until:
		if now >= _hydra_next_sweep_shot_at:
			_profile_attack_first_use("hydra_sweep")
			_hydra_next_sweep_shot_at = now + 0.1
			var sweep_ratio := clampf((now - _hydra_sweep_started_at) / maxf(_hydra_sweep_until - _hydra_sweep_started_at, 0.01), 0.0, 1.0)
			var sweep_angle := _hydra_sweep_start_angle + deg_to_rad(120.0) * sweep_ratio
			_emit_projectile_burst(Vector2.RIGHT.rotated(sweep_angle), 5, 0.08, 1.05)
	if now >= _next_fire_at:
		_profile_attack_first_use("hydra_arm_fire")
		_next_fire_at = now + (0.9 if phase < 0.25 else 0.68 if phase < 0.5 else 0.52 if phase < 0.75 else 0.38)
		var arm_count := 3 if phase < 0.5 else 4
		for arm_index in range(arm_count):
			var base_angle := _hydra_rotation + TAU * float(arm_index) / float(arm_count)
			match arm_index:
				0:
					_emit_projectile_burst(Vector2.RIGHT.rotated(base_angle), 1, 0.0, 1.0)
				1:
					_emit_projectile_burst(Vector2.RIGHT.rotated(base_angle), 3, 0.18, 1.0)
				2:
					_emit_projectile_burst(Vector2.RIGHT.rotated(base_angle + now * 0.8), 3 if phase >= 0.25 else 1, 0.08, 0.95)
				_:
					_emit_projectile_burst(Vector2.RIGHT.rotated(base_angle), 2 if phase >= 0.75 else 1, 0.06, 1.05)
	if now >= _next_burst_at:
		_profile_attack_first_use("hydra_radial_telegraph")
		_next_burst_at = now + (6.0 if phase < 0.75 else 4.0)
		_spawn_boss_attack_telegraph(240.0)
		_hydra_radial_burst_at = now + 0.8
	if now >= _next_ability_at and _combat_owner != null and _combat_owner.has_method("get_player_target_nodes"):
		_profile_attack_first_use("hydra_aimed_snipes")
		_next_ability_at = now + lerpf(4.0, 3.0, phase)
		var shot_count := 2 if phase >= 0.66 else 1
		for player in _combat_owner.get_player_target_nodes():
			if player == null or not is_instance_valid(player) or not player.has_method("is_alive") or not player.is_alive():
				continue
			var player_direction: Vector2 = (player.global_position - global_position).normalized()
			_emit_projectile_burst_custom(player_direction, shot_count, 0.04, 1.0, 550.0, projectile_damage)
	if now >= _hydra_orb_at:
		_profile_attack_first_use("hydra_homing_orbs")
		_hydra_orb_at = now + lerpf(8.0, 7.0, phase)
		if _combat_owner != null and _combat_owner.has_method("spawn_enemy_homing_orbs"):
			_combat_owner.spawn_enemy_homing_orbs(global_position, 3 if phase >= 0.5 else 2, 120.0, 4.0, projectile_damage, _feedback_color)
	if _hydra_sweep_until <= now and now >= _next_trail_at:
		_profile_attack_first_use("hydra_sweep_telegraph")
		_next_trail_at = now + lerpf(10.0, 8.0, phase)
		_hydra_sweep_windup_until = now + 0.8
		_hydra_sweep_started_at = _hydra_sweep_windup_until
		_hydra_sweep_until = _hydra_sweep_windup_until + 1.5
		_hydra_next_sweep_shot_at = _hydra_sweep_windup_until
		_hydra_sweep_start_angle = _hydra_rotation - deg_to_rad(60.0)
		_spawn_boss_attack_telegraph(280.0)
	if now >= _next_spawn_at:
		_profile_attack_first_use("hydra_minions")
		_next_spawn_at = now + (8.0 if phase < 0.66 else 5.5)
		if _combat_owner != null and _combat_owner.has_method("spawn_enemy_minions"):
			_combat_owner.spawn_enemy_minions(global_position, 1 + _boss_phase_index, phase)
	return Vector2.ZERO

func _update_hive_behavior(direction: Vector2, distance: float, now: float) -> Vector2:
	var phase := _get_phase_ratio()
	_update_boss_deflector_positions(now)
	if _boss_deflector_phase_index < 0:
		_profile_attack_first_use("hive_deflectors")
		_spawn_boss_deflector(4)
	if _hive_burrow_pending:
		if now < _hive_burrow_until:
			return Vector2.ZERO
		_hive_burrow_pending = false
		_profile_attack_first_use("hive_burrow_relocate")
		global_position = _find_hive_relocate_position()
		if _combat_owner != null and _combat_owner.has_method("spawn_enemy_burst"):
			_combat_owner.spawn_enemy_burst(global_position, 5 + int(phase * 3.0), phase)
	if distance < 240.0:
		direction = -direction
	if _hive_pressure_at <= 0.0:
		_hive_pressure_at = now + 3.0
	if now >= _hive_pressure_at:
		_profile_attack_first_use("hive_pressure_adds")
		_hive_pressure_at = now + lerpf(4.5, 3.4, phase)
		if _target != null and is_instance_valid(_target) and _combat_owner != null and _combat_owner.has_method("spawn_hive_pressure_adds"):
			_combat_owner.spawn_hive_pressure_adds(_target.global_position, 1 + _boss_phase_index, phase)
	if now >= _next_spawn_at:
		_profile_attack_first_use("hive_minion_mix")
		_next_spawn_at = now + lerpf(2.0, 0.8, phase)
		if _combat_owner != null and _combat_owner.has_method("spawn_enemy_minion_mix"):
			var types := ["chaser", "splitter"]
			if phase >= 0.33:
				types.append("charger")
			if phase >= 0.66:
				types.append("bomber")
			_combat_owner.spawn_enemy_minion_mix(global_position, 1 + int(phase * 2.0), types)
	if now >= _next_burst_at:
		_profile_attack_first_use("hive_poison_cloud")
		_next_burst_at = now + lerpf(6.0, 5.0, phase)
		_spawn_boss_attack_telegraph(160.0)
		var poison_origin := _target.global_position if _target != null and is_instance_valid(_target) else global_position
		if _combat_owner != null and _combat_owner.has_method("spawn_enemy_hazard_zone"):
			_combat_owner.spawn_enemy_hazard_zone(poison_origin, 160.0, 0.8, 0, Color(0.38, 0.9, 0.24, 0.22))
		if _combat_owner != null and _combat_owner.has_method("schedule_enemy_hazard_zone"):
			_combat_owner.schedule_enemy_hazard_zone(poison_origin, 160.0, 4.0, 5, Color(0.38, 0.9, 0.24, 0.32), 0.8)
	if now >= _next_ability_at:
		_profile_attack_first_use("hive_burrow_telegraph")
		_next_ability_at = now + lerpf(12.0, 10.0, phase)
		_hive_burrow_pending = true
		_hive_burrow_until = now + 1.0
		_boss_invulnerable_until = _hive_burrow_until
		_spawn_boss_attack_telegraph(180.0)
	return direction * _get_effective_move_speed()

func _spawn_boss_deflector(count: int) -> void:
	if not is_boss() or _combat_owner == null or not _combat_owner.has_method("spawn_boss_deflector_minions"):
		return
	_cleanup_boss_deflector_nodes()
	if not _boss_deflector_nodes.is_empty():
		return
	_boss_deflector_nodes = _combat_owner.spawn_boss_deflector_minions(global_position, count)
	_boss_deflector_phase_index = _boss_phase_index

func _cleanup_boss_deflector_nodes() -> void:
	var kept: Array = []
	for node in _boss_deflector_nodes:
		if node != null and is_instance_valid(node) and node.has_method("is_alive") and node.is_alive():
			kept.append(node)
	_boss_deflector_nodes = kept

func _update_boss_deflector_positions(now: float) -> void:
	_cleanup_boss_deflector_nodes()
	var count := _boss_deflector_nodes.size()
	if count <= 0:
		return
	for index in range(count):
		var node = _boss_deflector_nodes[index]
		if node == null or not is_instance_valid(node):
			continue
		var angle := now * 1.4 + TAU * float(index) / float(count)
		node.global_position = global_position + Vector2.RIGHT.rotated(angle) * 155.0

func _find_hive_relocate_position() -> Vector2:
	var arena_rect := Rect2(Vector2.ZERO, Vector2(3600.0, 2100.0))
	if _combat_owner != null and _combat_owner.has_method("get_arena_rect"):
		arena_rect = _combat_owner.get_arena_rect()
	var best_position := global_position
	var best_distance_sq := -1.0
	for _attempt in range(10):
		var candidate := Vector2(
			_random.randf_range(arena_rect.position.x + 260.0, arena_rect.end.x - 260.0),
			_random.randf_range(arena_rect.position.y + 260.0, arena_rect.end.y - 260.0)
		)
		var nearest_distance_sq := INF
		if _combat_owner != null and _combat_owner.has_method("get_player_target_nodes"):
			for player in _combat_owner.get_player_target_nodes():
				if player == null or not is_instance_valid(player):
					continue
				nearest_distance_sq = minf(nearest_distance_sq, candidate.distance_squared_to(player.global_position))
		if nearest_distance_sq > best_distance_sq:
			best_distance_sq = nearest_distance_sq
			best_position = candidate
	return best_position

func _update_pulsar_behavior(direction: Vector2, _distance: float, now: float) -> Vector2:
	var phase := _get_phase_ratio()
	if _pulsar_teleport_at <= 0.0:
		_pulsar_teleport_at = now + _get_pulsar_teleport_interval(phase)
	if _pulsar_emp_at <= 0.0:
		_pulsar_emp_at = now + lerpf(15.0, 12.0, phase)
	if _pulsar_telegraph_until > now:
		return Vector2.ZERO
	if _distance <= PULSAR_REACTIVE_TELEPORT_DISTANCE and now + 0.5 < _pulsar_teleport_at:
		_start_pulsar_telegraph(now)
		return Vector2.ZERO
	if now >= _pulsar_teleport_at:
		_start_pulsar_telegraph(now)
		return Vector2.ZERO
	if _pulsar_telegraph_until > 0.0 and now >= _pulsar_telegraph_until:
		_finish_pulsar_teleport(now, phase)
		return Vector2.ZERO
	if now >= _pulsar_emp_at:
		_profile_attack_first_use("pulsar_emp")
		_pulsar_emp_at = now + lerpf(15.0, 12.0, phase)
		_spawn_boss_attack_telegraph(520.0)
		if _combat_owner != null and _combat_owner.has_method("schedule_pulsar_emp"):
			_combat_owner.schedule_pulsar_emp(global_position, 2.0, _feedback_color, 0.8)
	if now >= _next_ability_at:
		_profile_attack_first_use("pulsar_shockwave_hazard")
		_next_ability_at = now + (4.0 if phase < 0.25 else 3.0 if phase < 0.5 else 2.4 if phase < 0.75 else 2.0)
		_spawn_boss_attack_telegraph(210.0)
		if _combat_owner != null and _combat_owner.has_method("schedule_enemy_shockwave"):
			_combat_owner.schedule_enemy_shockwave(global_position, 180.0 + phase * 60.0, 0, 780.0, _feedback_color, 0.8, false)
		if _combat_owner != null and _combat_owner.has_method("schedule_enemy_hazard_zone"):
			_combat_owner.schedule_enemy_hazard_zone(global_position, 180.0 + phase * 50.0, 3.0 if phase < 0.5 else 5.0 if phase < 0.75 else 7.0, 5, Color(0.4, 0.84, 1.0, 0.32), 0.8)
			if _combat_owner.has_method("get_player_target_nodes"):
				for player in _combat_owner.get_player_target_nodes():
					if player != null and is_instance_valid(player) and player.has_method("is_alive") and player.is_alive():
						_combat_owner.schedule_enemy_hazard_zone(player.global_position, 126.0, 2.8, 5, Color(0.52, 0.9, 1.0, 0.22), 0.8)
	if now >= _next_spawn_at:
		_profile_attack_first_use("pulsar_minions")
		_next_spawn_at = now + (7.0 if phase < 0.66 else 4.5)
		if _combat_owner != null and _combat_owner.has_method("spawn_enemy_minions"):
			_combat_owner.spawn_enemy_minions(global_position, 1 + _boss_phase_index, phase)
	if now >= _next_fire_at and _combat_owner != null and _combat_owner.has_method("get_player_target_nodes"):
		_profile_attack_first_use("pulsar_aimed_fire")
		_next_fire_at = now + (1.0 if phase < 0.25 else 0.75 if phase < 0.5 else 0.48 if phase < 0.75 else 0.18)
		for player in _combat_owner.get_player_target_nodes():
			if player == null or not is_instance_valid(player) or not player.has_method("is_alive") or not player.is_alive():
				continue
			var player_direction: Vector2 = (player.global_position - global_position).normalized()
			if player_direction.length() <= 0.0:
				player_direction = direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT
			_emit_projectiles_at(player_direction, 3 if phase < 0.5 else 5 if phase < 0.75 else 7, 0.09, 0.95)
	return Vector2.ZERO

func _get_contact_knockback_force() -> float:
	if is_boss():
		return 500.0
	if get_type_name().begins_with("elite_"):
		return 350.0
	return 200.0

func _get_pulsar_teleport_interval(phase: float) -> float:
	return lerpf(5.0, 3.5, clampf(phase, 0.0, 1.0))

func _start_pulsar_telegraph(now: float) -> void:
	_pulsar_teleport_at = INF
	_profile_attack_first_use("pulsar_teleport")
	_pulsar_telegraph_until = now + 0.5
	_spawn_hit_particles(1.25)
	var parent_node := get_parent()
	if parent_node == null:
		return
	var ring := ParticleFactoryData.create_impact_ring(_feedback_color.lightened(0.3), 72.0, 3.2)
	ring.global_position = global_position
	parent_node.add_child(ring)

func _finish_pulsar_teleport(now: float, phase: float) -> void:
	_pulsar_telegraph_until = 0.0
	global_position = _find_pulsar_teleport_position()
	if _combat_owner != null and _combat_owner.has_method("spawn_enemy_shockwave"):
		_combat_owner.spawn_enemy_shockwave(global_position, 180.0 + phase * 60.0, 0, 780.0, _feedback_color, false)
	var parent_node := get_parent()
	if parent_node != null:
		var burst := ParticleFactoryData.create_explosion_burst(_feedback_color, 0.95)
		burst.global_position = global_position
		parent_node.add_child(burst)
	_pulsar_teleport_at = now + _get_pulsar_teleport_interval(phase)
	_next_ability_at = maxf(_next_ability_at, now + 0.45)

func _find_pulsar_teleport_position() -> Vector2:
	var arena_rect := Rect2(Vector2.ZERO, Vector2(3600.0, 2100.0))
	if _combat_owner != null and _combat_owner.has_method("get_arena_rect"):
		arena_rect = _combat_owner.get_arena_rect()
	var target := _select_pulsar_teleport_target()
	if target != null:
		for _attempt in range(8):
			var ahead_direction := _get_target_ahead_direction(target)
			var side_jitter := ahead_direction.orthogonal() * _random.randf_range(-120.0, 120.0)
			var distance := _random.randf_range(350.0, 500.0)
			var candidate := target.global_position + ahead_direction * distance + side_jitter
			candidate = candidate.clamp(arena_rect.position + Vector2.ONE * PULSAR_ARENA_MARGIN, arena_rect.end - Vector2.ONE * PULSAR_ARENA_MARGIN)
			if candidate.distance_to(global_position) >= PULSAR_TELEPORT_MIN_DISTANCE:
				return candidate
	for _attempt in range(8):
		var candidate := Vector2(
			_random.randf_range(arena_rect.position.x + PULSAR_ARENA_MARGIN, arena_rect.end.x - PULSAR_ARENA_MARGIN),
			_random.randf_range(arena_rect.position.y + PULSAR_ARENA_MARGIN, arena_rect.end.y - PULSAR_ARENA_MARGIN)
		)
		if candidate.distance_to(global_position) >= PULSAR_TELEPORT_MIN_DISTANCE:
			return candidate
	return Vector2(
		clampf(global_position.x + _random.randf_range(-700.0, 700.0), arena_rect.position.x + PULSAR_ARENA_MARGIN, arena_rect.end.x - PULSAR_ARENA_MARGIN),
		clampf(global_position.y + _random.randf_range(-500.0, 500.0), arena_rect.position.y + PULSAR_ARENA_MARGIN, arena_rect.end.y - PULSAR_ARENA_MARGIN)
	)

func _select_pulsar_teleport_target() -> Node2D:
	var candidates: Array = []
	if _combat_owner != null and _combat_owner.has_method("get_player_target_nodes"):
		candidates = _combat_owner.get_player_target_nodes()
	var best_target: Node2D = null
	var best_distance_sq := -1.0
	for player in candidates:
		if player == null or not is_instance_valid(player) or not (player is Node2D):
			continue
		if player.has_method("is_alive") and not player.is_alive():
			continue
		var distance_sq := global_position.distance_squared_to((player as Node2D).global_position)
		if distance_sq > best_distance_sq:
			best_distance_sq = distance_sq
			best_target = player as Node2D
	return best_target

func _get_target_ahead_direction(target: Node2D) -> Vector2:
	if target is CharacterBody2D:
		var target_velocity := (target as CharacterBody2D).velocity
		if target_velocity.length() > 40.0:
			return target_velocity.normalized()
	var offset := target.global_position - global_position
	return offset.normalized() if offset.length() > 0.0 else Vector2.RIGHT

func _profile_attack_first_use(attack_name: String) -> void:
	if not RunState.debug_profiling or _profiled_attack_markers.has(attack_name):
		return
	_profiled_attack_markers[attack_name] = true
	var frame_ms := (Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	print("attack_marker,%s,%s,%.3f,%.3f" % [get_type_name(), attack_name, _current_time_seconds(), frame_ms])

func _emit_projectiles_at(direction: Vector2, projectile_count: int, spread: float, projectile_scale: float) -> void:
	_emit_projectile_burst(direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT, projectile_count, spread, projectile_scale)

func _emit_projectile_burst(base_direction: Vector2, projectile_count: int, spread_radians: float, projectile_scale: float) -> void:
	if _combat_owner != null and _combat_owner.has_method("spawn_enemy_attack_trail"):
		_combat_owner.spawn_enemy_attack_trail(global_position, base_direction, _feedback_color, projectile_scale)
	var normalized := base_direction.normalized() if base_direction.length() > 0.0 else Vector2.RIGHT
	var directions := _build_spread_directions(normalized, projectile_count, spread_radians)
	for projectile_direction in directions:
		fire_requested.emit(
			global_position + projectile_direction * 24.0,
			projectile_direction,
			projectile_speed,
			projectile_damage,
			"enemy",
			_feedback_color,
			projectile_scale
		)

func _emit_projectile_burst_custom(base_direction: Vector2, projectile_count: int, spread_radians: float, projectile_scale: float, shot_speed: float, shot_damage: int) -> void:
	if _combat_owner != null and _combat_owner.has_method("spawn_enemy_attack_trail"):
		_combat_owner.spawn_enemy_attack_trail(global_position, base_direction, _feedback_color, projectile_scale)
	var normalized := base_direction.normalized() if base_direction.length() > 0.0 else Vector2.RIGHT
	var directions := _build_spread_directions(normalized, projectile_count, spread_radians)
	for projectile_direction in directions:
		fire_requested.emit(
			global_position + projectile_direction * 24.0,
			projectile_direction,
			shot_speed,
			shot_damage,
			"enemy",
			_feedback_color,
			projectile_scale
		)

func _build_spread_directions(base_direction: Vector2, projectile_count: int, spread_radians: float) -> Array:
	var directions: Array = []
	if projectile_count <= 1 or spread_radians <= 0.0:
		return [base_direction]
	var center_offset := float(projectile_count - 1) * 0.5
	for index in range(projectile_count):
		var offset := (float(index) - center_offset) * spread_radians
		directions.append(base_direction.rotated(offset))
	return directions

func _get_effective_move_speed() -> float:
	return _base_move_speed * _modifier_speed_mult * _aura_speed_mult * _slow_multiplier

func _get_effective_fire_interval() -> float:
	return max(_base_fire_interval * _modifier_attack_mult / max(_aura_attack_mult, 0.01), 0.15)

func _get_phase_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return clampf(1.0 - (current_health / max_health), 0.0, 1.0)

func _trigger_bomber_explosion() -> void:
	if not _alive:
		return
	if _combat_owner != null and _combat_owner.has_method("handle_enemy_death_explosion"):
		_combat_owner.handle_enemy_death_explosion(global_position, 120.0, 25)
	_die(true)

func _die(already_exploded: bool = false) -> void:
	if not _alive:
		return
	_alive = false
	clear_aura()
	if get_type_name() == "bomber" and not already_exploded and _combat_owner != null and _combat_owner.has_method("handle_enemy_death_explosion"):
		_combat_owner.handle_enemy_death_explosion(global_position, 120.0, 25)
	if _death_explosion_radius > 0.0 and _death_explosion_damage > 0 and _combat_owner != null and _combat_owner.has_method("handle_enemy_death_explosion"):
		_combat_owner.handle_enemy_death_explosion(global_position, _death_explosion_radius, _death_explosion_damage)
	_spawn_death_particles()
	enemy_died.emit(self)
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	if body_root != null:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(body_root, "scale", body_root.scale * 0.75, 0.18)
		tween.tween_property(body_root, "modulate:a", 0.0, 0.18)
		tween.set_parallel(false)
		tween.tween_callback(queue_free)
	else:
		queue_free()

func _spawn_hit_particles(weight: float, shield_pop: bool = false) -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	var burst := ParticleFactoryData.create_impact_sparks(Color.WHITE if shield_pop else _feedback_color, Vector2.UP, weight)
	burst.global_position = global_position
	parent_node.add_child(burst)

func _spawn_death_particles() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	var death_weight := 2.2 if is_boss() else _feedback_weight * 1.25
	var burst := ParticleFactoryData.create_death_burst(_feedback_color.lightened(0.08), death_weight)
	burst.global_position = global_position
	parent_node.add_child(burst)
	if is_boss() or get_type_name().begins_with("elite_"):
		var ring_radius := 150.0 if is_boss() else 96.0
		var ring := ParticleFactoryData.create_explosion_ring(_feedback_color, ring_radius, 4.0)
		ring.global_position = global_position
		parent_node.add_child(ring)
		var debris := ParticleFactoryData.create_debris_ring(_feedback_color.lightened(0.18), ring_radius * 0.9, 18 if is_boss() else 12, 0.34 if is_boss() else 0.24)
		debris.global_position = global_position
		parent_node.add_child(debris)
	else:
		var pop := ParticleFactoryData.create_impact_ring(_feedback_color.lightened(0.16), 32.0, 2.5)
		pop.global_position = global_position
		parent_node.add_child(pop)

func _update_visual_state() -> void:
	_refresh_static_visuals()

func _refresh_static_visuals() -> void:
	if visual == null:
		return
	var is_elite := get_type_name().begins_with("elite_")
	var scale_mult := 1.0
	match enemy_type:
		EnemyType.SPLITTER_MINI:
			scale_mult = 0.55
		EnemyType.BOSS_WARDEN, EnemyType.BOSS_HYDRA, EnemyType.BOSS_HIVE, EnemyType.BOSS_PULSAR:
			scale_mult = 2.5
		EnemyType.ELITE_CHARGER, EnemyType.ELITE_SPITTER, EnemyType.ELITE_SUPPORT:
			scale_mult = 1.7
		EnemyType.BOMBER:
			scale_mult = 1.2
		EnemyType.SPLITTER:
			scale_mult = 1.1
	visual.scale = _base_visual_scale * scale_mult * READABILITY_VISUAL_SCALE
	visual.color = _bloom_color(_feedback_color.lightened(0.24)) if _shield_active else _bloom_color(_feedback_color)
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = _base_collision_radius * max(0.7, scale_mult)
	if is_elite:
		body_root.scale = Vector2.ONE * 1.06
	else:
		body_root.scale = Vector2.ONE

func _update_dynamic_visuals() -> void:
	if visual == null or body_root == null:
		return
	body_root.rotation = lerp_angle(body_root.rotation, velocity.angle() if velocity.length() > 0.1 else body_root.rotation, 0.18)
	if _fuse_active:
		visual.modulate = Color(1.2, 1.0, 0.8, 1.0)
	else:
		visual.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _bloom_color(color: Color) -> Color:
	return Color(color.r * BLOOM_COLOR_MULTIPLIER, color.g * BLOOM_COLOR_MULTIPLIER, color.b * BLOOM_COLOR_MULTIPLIER, color.a)

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
