extends Node

const ProjectileSceneData = preload("res://scenes/weapons/Projectile.tscn")
const FireTrailZoneData = preload("res://scripts/weapons/FireTrailZone.gd")
const ProjectileRendererData = preload("res://scripts/weapons/ProjectileRenderer.gd")
const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")
const ArenaGeometry = preload("res://scripts/game/ArenaGeometry.gd")

const MAX_ACTIVE_PROJECTILES := 180
const ENEMY_PROJECTILE_COLOR := Color(1.0, 0.0, 0.0, 1.0)
const COMBAT_VFX_LOAD_THRESHOLD := 150
const BEAM_VISUAL_GRACE := 0.16

var _coop: Node = null
var _projectile_container: Node2D = null
var _effects_container: Node2D = null
var _projectile_pool: Array = []
var _active_projectiles: Array = []
var _active_homing_projectiles: Array = []
var _beam_states: Dictionary = {}
var _projectile_renderer = null


func setup(coop: Node, projectile_container: Node2D, effects_container: Node2D) -> void:
	_coop = coop
	_projectile_container = projectile_container
	_effects_container = effects_container


func clear_runtime() -> void:
	_projectile_pool.clear()
	_active_projectiles.clear()
	_active_homing_projectiles.clear()
	_beam_states.clear()
	_projectile_renderer = null


func ensure_renderer() -> void:
	if _projectile_renderer != null and is_instance_valid(_projectile_renderer):
		return
	_projectile_renderer = ProjectileRendererData.new()
	_projectile_renderer.name = "ProjectileRenderer"
	_projectile_renderer.set_projectile_container(_projectile_container)
	_projectile_container.add_child(_projectile_renderer)


func tick(delta: float) -> void:
	_update_homing_projectiles(delta)


func handle_player_fire(origin: Vector2, direction: Vector2, projectile_config: Dictionary) -> void:
	if str(projectile_config.get("projectile_kind", "bullet")) == "beam":
		_process_beam_fire(origin, direction, projectile_config)
		return
	cleanup_active_projectiles()
	if _active_projectiles.size() >= MAX_ACTIVE_PROJECTILES:
		return
	var split_extra_count := int(projectile_config.get("split_extra_count", 0))
	var spread_step := deg_to_rad(float(projectile_config.get("split_spread_degrees", 15.0)))
	var projectile_count: int = (1 + split_extra_count) * maxi(1, int(projectile_config.get("projectile_multiplier", 1)))
	var directions := ArenaGeometry.build_spread_directions(direction, projectile_count, spread_step)
	for projectile_direction in directions:
		if _active_projectiles.size() >= MAX_ACTIVE_PROJECTILES:
			return
		_activate_projectile("player", origin, projectile_direction, projectile_config)


func handle_enemy_fire(origin: Vector2, direction: Vector2, speed: float, damage: int, team: String, projectile_scale: float) -> void:
	cleanup_active_projectiles()
	if _active_projectiles.size() >= MAX_ACTIVE_PROJECTILES:
		return
	_activate_projectile(team, origin, direction, {
		"speed": speed,
		"damage": damage,
		"color": ENEMY_PROJECTILE_COLOR,
		"feedback_profile": "enemy",
		"impact_weight": projectile_scale,
		"collision_half_width": 6.0 * projectile_scale,
		"use_lifetime": true,
	})


func spawn_enemy_homing_orbs(origin: Vector2, count: int, speed: float, duration: float, damage: int, _color: Color) -> void:
	for index in range(count):
		var target: Node2D = _coop.call("get_nearest_player_to", origin)
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / float(max(count, 1)))
		if target != null:
			direction = (target.global_position - origin).normalized()
		var projectile = ProjectileSceneData.instantiate()
		_projectile_container.add_child(projectile)
		projectile.impact_requested.connect(_on_projectile_impact)
		projectile.activate_from_config("enemy", direction, {
			"speed": speed,
			"damage": damage,
			"color": ENEMY_PROJECTILE_COLOR,
			"feedback_profile": "enemy",
			"impact_weight": 1.4,
			"collision_half_width": 12.0,
			"use_lifetime": true,
		}, origin + direction * 32.0)
		_active_homing_projectiles.append({
			"projectile": projectile,
			"target": target,
			"expires_at": _current_time_seconds() + duration,
		})


func update_beam_visual_timeouts(now: float) -> void:
	for key in _beam_states.keys():
		var state: Dictionary = _beam_states[key]
		var line = state.get("visual", null)
		if line == null or not is_instance_valid(line):
			continue
		if line.visible and now - float(state.get("last_update_at", 0.0)) > BEAM_VISUAL_GRACE:
			line.visible = false


func should_suppress_combat_vfx() -> bool:
	cleanup_active_projectiles()
	var enemy_count := int(_coop.call("get_enemy_count")) if _coop != null and _coop.has_method("get_enemy_count") else 0
	return enemy_count + _active_projectiles.size() >= COMBAT_VFX_LOAD_THRESHOLD


func _process_beam_fire(origin: Vector2, direction: Vector2, projectile_config: Dictionary) -> void:
	if direction.length() <= 0.0:
		return
	var shooter = projectile_config.get("shooter", null)
	var shooter_key := int(shooter.get_instance_id()) if shooter != null and is_instance_valid(shooter) else 0
	var state: Dictionary = _beam_states.get(shooter_key, {
		"held_targets": {},
		"visual": null,
		"fire_pool": null,
		"next_fire_pool_at": 0.0,
	})
	var beam_range := float(projectile_config.get("range", projectile_config.get("max_distance", 750.0)))
	var tick_interval := maxf(float(projectile_config.get("tick_interval", 0.1)), 0.05)
	var beam_width := maxf(float(projectile_config.get("area", 18.0)), 18.0)
	var beam_direction := direction.normalized()
	var held_targets: Dictionary = state.get("held_targets", {}) as Dictionary
	var current_target_ids := {}
	var hit_position := origin + beam_direction * beam_range
	for enemy in _coop.call("get_nearby_enemy_target_nodes", origin + beam_direction * beam_range * 0.5, beam_range * 0.6 + beam_width):
		if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("is_alive") or not enemy.is_alive():
			continue
		var enemy_position: Vector2 = enemy.global_position
		var offset := enemy_position - origin
		var projected := offset.dot(beam_direction)
		if projected < 0.0 or projected > beam_range:
			continue
		var closest := origin + beam_direction * projected
		if enemy_position.distance_squared_to(closest) > beam_width * beam_width:
			continue
		var target_id := int(enemy.get_instance_id())
		var held_time := float(held_targets.get(target_id, 0.0)) + tick_interval
		held_targets[target_id] = held_time
		current_target_ids[target_id] = true
		var ramp_seconds := maxf(float(projectile_config.get("ramp_seconds", 1.5)), 0.01)
		var start_fraction := clampf(float(projectile_config.get("ramp_start_fraction", 0.3)), 0.0, 1.0)
		var ramp_ratio := clampf(held_time / ramp_seconds, 0.0, 1.0)
		var dps := float(projectile_config.get("max_damage_per_second", projectile_config.get("damage", 120.0))) * lerpf(start_fraction, 1.0, ramp_ratio)
		var damage: int = max(1, int(round(dps * tick_interval)))
		enemy.apply_damage(damage)
		if float(projectile_config.get("slow_duration", 0.0)) > 0.0:
			if float(projectile_config.get("slow_step", 0.0)) > 0.0 and enemy.has_method("apply_stacking_slow"):
				enemy.apply_stacking_slow(float(projectile_config.get("slow_step", 0.0)), float(projectile_config.get("slow_floor", 0.15)), float(projectile_config.get("slow_duration", 0.0)))
			elif enemy.has_method("apply_slow"):
				enemy.apply_slow(float(projectile_config.get("slow_multiplier", 1.0)), float(projectile_config.get("slow_duration", 0.0)))
		if float(projectile_config.get("poison_duration", 0.0)) > 0.0 and float(projectile_config.get("poison_dps", 0.0)) > 0.0 and enemy.has_method("apply_poison"):
			enemy.apply_poison(float(projectile_config.get("poison_dps", 0.0)), float(projectile_config.get("poison_duration", 0.0)))
		if bool(projectile_config.get("ignite_on_death", false)) and enemy.has_method("apply_ignite_on_death"):
			enemy.apply_ignite_on_death(
				float(projectile_config.get("ignite_radius", 0.0)),
				maxi(1, int(round(float(damage) * float(projectile_config.get("ignite_damage_percent", 0.0)))))
			)
		if bool(projectile_config.get("shatter_on_frozen_death", false)) and enemy.has_method("apply_shatter_on_death"):
			enemy.apply_shatter_on_death(
				float(projectile_config.get("shatter_radius", 0.0)),
				maxi(1, int(round(float(damage) * float(projectile_config.get("shatter_damage_percent", 0.0)))))
			)
		hit_position = closest
	for target_id in held_targets.keys():
		if not current_target_ids.has(target_id):
			held_targets.erase(target_id)
	state["held_targets"] = held_targets
	_update_beam_visual(state, origin, beam_direction, beam_range, projectile_config)
	_update_beam_fire_pool(state, hit_position, projectile_config)
	_beam_states[shooter_key] = state


func _update_beam_visual(state: Dictionary, origin: Vector2, direction: Vector2, beam_range: float, projectile_config: Dictionary) -> void:
	var line: Line2D = state.get("visual", null)
	if line == null or not is_instance_valid(line):
		line = Line2D.new()
		line.name = "BeamTrace"
		line.width = maxf(float(projectile_config.get("area", 18.0)), 18.0)
		line.antialiased = true
		line.z_index = 5
		_effects_container.add_child(line)
		state["visual"] = line
	var color: Color = projectile_config.get("color", Color.WHITE)
	line.default_color = Color(color.r, color.g, color.b, 0.55)
	line.global_position = Vector2.ZERO
	line.points = PackedVector2Array([origin, origin + direction.normalized() * beam_range])
	line.modulate.a = 1.0
	line.visible = true
	state["last_update_at"] = _current_time_seconds()


func _update_beam_fire_pool(state: Dictionary, hit_position: Vector2, projectile_config: Dictionary) -> void:
	if not bool(projectile_config.get("leaves_fire_trail", false)):
		return
	var now := _current_time_seconds()
	if now < float(state.get("next_fire_pool_at", 0.0)):
		var existing_pool = state.get("fire_pool", null)
		if existing_pool != null and is_instance_valid(existing_pool):
			existing_pool.global_position = hit_position
		return
	var radius := float(projectile_config.get("impact_pool_radius", 0.0))
	var lifetime := float(projectile_config.get("impact_pool_lifetime", 0.0))
	var damage_percent := float(projectile_config.get("impact_pool_damage_percent", 0.0))
	if radius <= 0.0 or lifetime <= 0.0 or damage_percent <= 0.0:
		return
	var pool = state.get("fire_pool", null)
	if pool == null or not is_instance_valid(pool):
		pool = FireTrailZoneData.new()
		_effects_container.add_child(pool)
		state["fire_pool"] = pool
	pool.global_position = hit_position
	pool.configure(
		radius,
		max(1, int(round(float(projectile_config.get("max_damage_per_second", projectile_config.get("damage", 1.0))) * damage_percent))),
		lifetime,
		maxf(float(projectile_config.get("trail_tick_interval", 0.5)), 0.1),
		"player"
	)
	state["next_fire_pool_at"] = now + maxf(float(projectile_config.get("beam_fire_pool_cooldown", 0.5)), 0.1)


func _update_homing_projectiles(_delta: float) -> void:
	var now := _current_time_seconds()
	var kept: Array = []
	for entry_variant in _active_homing_projectiles:
		var entry := entry_variant as Dictionary
		var projectile = entry.get("projectile", null)
		if projectile == null or not is_instance_valid(projectile):
			continue
		if projectile.has_method("is_projectile_active") and not projectile.is_projectile_active():
			continue
		if now >= float(entry.get("expires_at", 0.0)):
			if projectile.has_method("_finish_projectile"):
				projectile._finish_projectile()
			else:
				projectile.queue_free()
			continue
		var target = entry.get("target", null)
		if target == null or not is_instance_valid(target) or not target.has_method("is_alive") or not target.is_alive():
			target = _coop.call("get_nearest_player_to", projectile.global_position)
			entry["target"] = target
		if target != null and is_instance_valid(target):
			var desired: Vector2 = (target.global_position - projectile.global_position).normalized()
			if desired.length() > 0.0:
				projectile.direction = projectile.direction.lerp(desired, 0.08).normalized()
		kept.append(entry)
	_active_homing_projectiles = kept


func _activate_projectile(team: String, origin: Vector2, direction: Vector2, projectile_config: Dictionary) -> void:
	var projectile = _acquire_projectile()
	if projectile == null:
		return
	projectile.activate_from_config(team, direction, projectile_config, origin)
	if not _active_projectiles.has(projectile):
		_active_projectiles.append(projectile)


func _acquire_projectile():
	for projectile in _projectile_pool:
		if projectile != null and is_instance_valid(projectile) and projectile.has_method("is_projectile_active") and not projectile.is_projectile_active():
			return projectile
	if _projectile_pool.size() >= MAX_ACTIVE_PROJECTILES:
		return null
	var projectile = ProjectileSceneData.instantiate()
	if projectile.has_method("prepare_for_pool"):
		projectile.prepare_for_pool()
	else:
		projectile.set_pooled(true)
	projectile.impact_requested.connect(_on_projectile_impact)
	projectile.split_requested.connect(_on_projectile_split_requested)
	projectile.projectile_deactivated.connect(_on_projectile_deactivated)
	_projectile_container.add_child(projectile)
	_projectile_pool.append(projectile)
	return projectile


func _on_projectile_split_requested(origin: Vector2, _direction: Vector2, team: String, projectile_config: Dictionary, current_target: Node) -> void:
	if team != "player":
		return
	cleanup_active_projectiles()
	if _active_projectiles.size() >= MAX_ACTIVE_PROJECTILES:
		return
	var search_radius := float(projectile_config.get("range", projectile_config.get("max_distance", 900.0)))
	var best_target: Node2D = null
	var best_distance_sq := INF
	for enemy in _coop.call("get_nearby_enemy_target_nodes", origin, search_radius):
		if enemy == null or not is_instance_valid(enemy) or enemy == current_target:
			continue
		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue
		if not (enemy is Node2D):
			continue
		var distance_sq := (enemy as Node2D).global_position.distance_squared_to(origin)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best_target = enemy as Node2D
	if best_target == null:
		return
	var split_direction := (best_target.global_position - origin).normalized()
	if split_direction.length() <= 0.0:
		return
	_activate_projectile("player", origin, split_direction, projectile_config)


func _on_projectile_deactivated(projectile) -> void:
	_active_projectiles.erase(projectile)


func cleanup_active_projectiles() -> void:
	var kept: Array = []
	for projectile in _active_projectiles:
		if projectile != null and is_instance_valid(projectile) and projectile.has_method("is_projectile_active") and projectile.is_projectile_active():
			kept.append(projectile)
	_active_projectiles = kept


func _on_projectile_impact(origin: Vector2, direction: Vector2, team: String, color: Color, feedback_profile: String, impact_weight: float, target: Node, combat_context: Dictionary) -> void:
	var suppress_vfx := should_suppress_combat_vfx()
	if not suppress_vfx:
		_spawn_projectile_hit_effect(origin, direction, color, impact_weight, target)
	if _coop != null and _coop.has_method("_play_sfx"):
		_coop.call("_play_sfx", "play_impact_profile", [impact_weight, feedback_profile])
	var explosion_radius := float(combat_context.get("explosion_radius", 0.0))
	var explosion_damage := int(combat_context.get("explosion_damage", 0))
	if explosion_radius > 0.0 and explosion_damage > 0:
		if team == "player":
			for enemy in _coop.call("get_nearby_enemy_target_nodes", origin, explosion_radius):
				if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
					continue
				if enemy == target:
					continue
				if enemy.global_position.distance_squared_to(origin) <= explosion_radius * explosion_radius:
					enemy.apply_damage(explosion_damage)
		else:
			for player in _coop.call("get_player_target_nodes"):
				if player == null or not is_instance_valid(player) or not player.is_alive():
					continue
				if player.global_position.distance_to(origin) <= explosion_radius:
					player.apply_damage(explosion_damage)
		if not suppress_vfx:
			var ring := ParticleFactoryData.create_explosion_ring(color, explosion_radius, 3.0)
			ring.global_position = origin
			_effects_container.add_child(ring)


func _spawn_projectile_hit_effect(origin: Vector2, direction: Vector2, color: Color, impact_weight: float, target: Node) -> void:
	var effect_color := color.lightened(0.2)
	if target != null and is_instance_valid(target) and target.has_method("get_feedback_color"):
		effect_color = target.get_feedback_color().lightened(0.12)
	var effect_direction := direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT
	var sparks := ParticleFactoryData.create_impact_sparks(effect_color, effect_direction, impact_weight)
	sparks.global_position = origin
	_effects_container.add_child(sparks)
	if target != null and is_instance_valid(target) and not (target is StaticBody2D):
		var ring := ParticleFactoryData.create_impact_ring(effect_color, 18.0 + impact_weight * 8.0, 2.5 + impact_weight)
		ring.global_position = origin
		_effects_container.add_child(ring)


func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
