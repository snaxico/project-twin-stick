extends Node2D

const HazardZoneData = preload("res://scripts/game/HazardZone.gd")
const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")

var _coop: Node = null
var _effects_parent: Node = null
var _projectiles_parent: Node = null
var _scheduled_enemy_shockwaves: Array = []
var _scheduled_player_shockwaves: Array = []
var _scheduled_enemy_hazards: Array = []
var _scheduled_pulsar_emps: Array = []


func setup(coop: Node, effects_parent: Node, projectiles_parent: Node) -> void:
	_coop = coop
	_effects_parent = effects_parent
	_projectiles_parent = projectiles_parent


func clear_runtime() -> void:
	_scheduled_enemy_shockwaves.clear()
	_scheduled_player_shockwaves.clear()
	_scheduled_enemy_hazards.clear()
	_scheduled_pulsar_emps.clear()


func update_scheduled_enemy_shockwaves() -> void:
	if _scheduled_enemy_shockwaves.is_empty():
		return
	var remaining: Array = []
	for scheduled in _scheduled_enemy_shockwaves:
		var trigger_at := float((scheduled as Dictionary).get("trigger_at", INF))
		if float(_coop.call("get_room_elapsed")) >= trigger_at:
			spawn_enemy_shockwave(
				scheduled.get("origin", Vector2.ZERO),
				float(scheduled.get("radius", 0.0)),
				int(scheduled.get("damage", 0)),
				float(scheduled.get("knockback_force", 0.0)),
				scheduled.get("color", Color.WHITE),
				bool(scheduled.get("destroy_projectiles", false))
			)
		else:
			remaining.append(scheduled)
	_scheduled_enemy_shockwaves = remaining


func update_scheduled_player_shockwaves() -> void:
	if _scheduled_player_shockwaves.is_empty():
		return
	var remaining: Array = []
	for scheduled in _scheduled_player_shockwaves:
		var trigger_at := float((scheduled as Dictionary).get("trigger_at", INF))
		if float(_coop.call("get_room_elapsed")) >= trigger_at:
			spawn_player_shockwave(
				scheduled.get("origin", Vector2.ZERO),
				(scheduled.get("stats", {}) as Dictionary).duplicate(true)
			)
		else:
			remaining.append(scheduled)
	_scheduled_player_shockwaves = remaining


func update_scheduled_enemy_hazards() -> void:
	if _scheduled_enemy_hazards.is_empty():
		return
	var remaining: Array = []
	for scheduled in _scheduled_enemy_hazards:
		var entry := scheduled as Dictionary
		if float(_coop.call("get_room_elapsed")) >= float(entry.get("trigger_at", INF)):
			spawn_enemy_hazard_zone(
				entry.get("origin", Vector2.ZERO),
				float(entry.get("radius", 0.0)),
				float(entry.get("duration", 0.0)),
				int(entry.get("damage", 0)),
				entry.get("color", Color.WHITE)
			)
		else:
			remaining.append(scheduled)
	_scheduled_enemy_hazards = remaining


func update_scheduled_pulsar_emps() -> void:
	if _scheduled_pulsar_emps.is_empty():
		return
	var remaining: Array = []
	for scheduled in _scheduled_pulsar_emps:
		var entry := scheduled as Dictionary
		if float(_coop.call("get_room_elapsed")) >= float(entry.get("trigger_at", INF)):
			spawn_pulsar_emp(
				entry.get("origin", Vector2.ZERO),
				float(entry.get("lockout_seconds", 0.0)),
				entry.get("color", Color.WHITE)
			)
		else:
			remaining.append(scheduled)
	_scheduled_pulsar_emps = remaining


func spawn_player_shockwave(origin: Vector2, stats: Dictionary) -> void:
	var radius := float(stats.get("radius", 250.0))
	var damage := int(round(float(stats.get("damage", 30.0))))
	var knockback_force := float(stats.get("knockback_force", 950.0))
	for enemy in _coop.call("get_nearby_enemy_target_nodes", origin, radius):
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var offset: Vector2 = enemy.global_position - origin
		var distance: float = offset.length()
		if distance > radius:
			continue
		enemy.apply_damage(damage)
		_coop.call("spawn_target_hit_spark", enemy.global_position, offset.normalized() if distance > 0.0 else Vector2.UP, stats.get("color", Color.WHITE), 1.0)
		if enemy.has_method("apply_knockback"):
			var radial_direction: Vector2 = offset.normalized() if distance > 0.0 else Vector2.RIGHT
			var distance_ratio := 1.0 - clampf(distance / max(radius, 0.01), 0.0, 1.0)
			enemy.apply_knockback(radial_direction, knockback_force * (0.7 + distance_ratio * 0.75))
	for projectile in _projectiles_parent.get_children():
		if projectile == null or not is_instance_valid(projectile):
			continue
		if projectile.has_method("is_projectile_active") and not projectile.is_projectile_active():
			continue
		if not ("team" in projectile) or str(projectile.team) != "enemy":
			continue
		if projectile.global_position.distance_to(origin) <= radius:
			var projectile_direction: Vector2 = projectile.global_position - origin
			var sparks := ParticleFactoryData.create_impact_sparks(
				(stats.get("color", Color.WHITE) as Color).lightened(0.1),
				projectile_direction.normalized() if projectile_direction.length() > 0.0 else Vector2.UP,
				0.75
			)
			sparks.global_position = projectile.global_position
			_effects_parent.add_child(sparks)
			if projectile.has_method("_finish_projectile"):
				projectile._finish_projectile()
			else:
				projectile.queue_free()
	_coop.call("spawn_shockwave_visual", origin, radius, stats.get("color", Color.WHITE), float(stats.get("expand_duration", 0.15)))
	_coop.call("add_screen_trauma", 0.18)


func schedule_player_shockwave_resonance(origin: Vector2, stats: Dictionary) -> void:
	var extra_pulses: int = maxi(0, int(stats.get("extra_pulses", 0)))
	if extra_pulses <= 0:
		return
	var pulse_interval: float = maxf(0.01, float(stats.get("pulse_interval", 0.15)))
	for pulse_index in range(extra_pulses):
		_scheduled_player_shockwaves.append({
			"trigger_at": float(_coop.call("get_room_elapsed")) + pulse_interval * float(pulse_index + 1),
			"origin": origin,
			"stats": stats.duplicate(true),
		})


func spawn_enemy_shockwave(origin: Vector2, radius: float, damage: int, knockback_force: float, color: Color, destroy_projectiles: bool = false) -> void:
	for player in _coop.call("get_player_target_nodes"):
		if player == null or not is_instance_valid(player) or not player.is_alive():
			continue
		var offset: Vector2 = player.global_position - origin
		var distance: float = offset.length()
		if distance > radius:
			continue
		if damage > 0:
			player.apply_damage(damage)
		player.apply_knockback(offset.normalized() if distance > 0.0 else Vector2.RIGHT, knockback_force)
	if destroy_projectiles:
		for projectile in _projectiles_parent.get_children():
			if projectile == null or not is_instance_valid(projectile):
				continue
			if projectile.has_method("is_projectile_active") and not projectile.is_projectile_active():
				continue
			if not ("team" in projectile):
				continue
			if projectile.global_position.distance_to(origin) > radius:
				continue
			if projectile.has_method("_finish_projectile"):
				projectile._finish_projectile()
			else:
				projectile.queue_free()
	_coop.call("spawn_shockwave_visual", origin, radius, color, 0.18)


func schedule_enemy_shockwave(origin: Vector2, radius: float, damage: int, knockback_force: float, color: Color, delay: float, destroy_projectiles: bool = false) -> void:
	if delay <= 0.0:
		spawn_enemy_shockwave(origin, radius, damage, knockback_force, color, destroy_projectiles)
		return
	_scheduled_enemy_shockwaves.append({
		"trigger_at": float(_coop.call("get_room_elapsed")) + delay,
		"origin": origin,
		"radius": radius,
		"damage": damage,
		"knockback_force": knockback_force,
		"color": color,
		"destroy_projectiles": destroy_projectiles,
	})


func schedule_enemy_hazard_zone(origin: Vector2, radius: float, duration: float, damage: int, color: Color, delay: float) -> void:
	if delay <= 0.0:
		spawn_enemy_hazard_zone(origin, radius, duration, damage, color)
		return
	_scheduled_enemy_hazards.append({
		"trigger_at": float(_coop.call("get_room_elapsed")) + delay,
		"origin": origin,
		"radius": radius,
		"duration": duration,
		"damage": damage,
		"color": color,
	})


func spawn_enemy_hazard_zone(origin: Vector2, radius: float, duration: float, damage: int, color: Color) -> void:
	var zone := HazardZoneData.new()
	zone.global_position = origin
	zone.configure(radius, duration, damage, color)
	_effects_parent.add_child(zone)
	_coop.call("register_hazard_zone", zone)


func spawn_enemy_minions(origin: Vector2, count: int, phase: float, forced_type: String = "") -> void:
	for index in range(count):
		var enemy_type := forced_type
		if enemy_type.is_empty():
			enemy_type = "chaser"
			if phase >= 0.25 and randf() < phase:
				enemy_type = "charger"
		if phase >= 0.55 and randf() < phase * 0.7:
			enemy_type = "spitter"
		var angle := TAU * float(index) / float(max(count, 1))
		_coop.call("queue_enemy_spawn", enemy_type, origin + Vector2.RIGHT.rotated(angle) * 96.0)


func spawn_enemy_minion_mix(origin: Vector2, count: int, types: Array) -> void:
	if types.is_empty():
		return
	for index in range(count):
		var enemy_type := str(types[index % types.size()])
		var angle := TAU * float(index) / float(max(count, 1))
		_coop.call("queue_enemy_spawn", enemy_type, origin + Vector2.RIGHT.rotated(angle) * 112.0)


func apply_enemy_support_aura(origin: Vector2, radius: float, speed_mult: float, attack_mult: float, duration: float) -> void:
	for enemy in _coop.call("get_nearby_enemy_target_nodes", origin, radius):
		if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("apply_aura"):
			continue
		if enemy.has_method("is_champion") and bool(enemy.is_champion()):
			continue
		enemy.apply_aura(speed_mult, attack_mult)
		var aura_target = enemy
		var timer := get_tree().create_timer(maxf(duration, 0.1))
		timer.timeout.connect(func() -> void:
			if aura_target != null and is_instance_valid(aura_target) and aura_target.has_method("clear_aura"):
				aura_target.clear_aura()
		)


func spawn_champion_deflector_minions(origin: Vector2, count: int) -> Array:
	var shield_nodes: Array = []
	for index in range(count):
		var angle := TAU * float(index) / float(max(count, 1))
		var node = _coop.call("spawn_enemy_instance", "splitter_mini", origin + Vector2.RIGHT.rotated(angle) * 150.0, 3.75)
		if node != null:
			shield_nodes.append(node)
	return shield_nodes


func spawn_hive_shield_minions(origin: Vector2, count: int) -> Array:
	return spawn_champion_deflector_minions(origin, count)


func spawn_pulsar_emp(origin: Vector2, lockout_seconds: float, color: Color) -> void:
	for player in _coop.call("get_player_target_nodes"):
		if player != null and is_instance_valid(player) and player.has_method("apply_ability_lockout"):
			player.apply_ability_lockout(lockout_seconds)
	spawn_enemy_shockwave(origin, 520.0, 0, 420.0, color, false)
	_coop.call("spawn_screen_flash", Color(color.r, color.g, color.b, 0.18), 0.22)


func schedule_pulsar_emp(origin: Vector2, lockout_seconds: float, color: Color, delay: float) -> void:
	if delay <= 0.0:
		spawn_pulsar_emp(origin, lockout_seconds, color)
		return
	_scheduled_pulsar_emps.append({
		"trigger_at": float(_coop.call("get_room_elapsed")) + delay,
		"origin": origin,
		"lockout_seconds": lockout_seconds,
		"color": color,
	})


func spawn_enemy_burst(origin: Vector2, count: int, phase: float) -> void:
	for index in range(count):
		var enemy_type := "chaser"
		if phase >= 0.33 and index % 3 == 0:
			enemy_type = "charger"
		if phase >= 0.66 and index % 4 == 0:
			enemy_type = "spitter"
		var angle := TAU * float(index) / float(max(count, 1))
		_coop.call("queue_enemy_spawn", enemy_type, origin + Vector2.RIGHT.rotated(angle) * 160.0)


func handle_enemy_charge_windup(origin: Vector2) -> void:
	var ring := ParticleFactoryData.create_impact_ring(Color(1.0, 0.76, 0.48, 0.82), 64.0, 3.0)
	ring.global_position = origin
	_effects_parent.add_child(ring)


func spawn_enemy_attack_trail(origin: Vector2, direction: Vector2, color: Color, weight: float) -> void:
	var trail := ParticleFactoryData.create_attack_trail(color, direction, weight)
	trail.global_position = origin
	_effects_parent.add_child(trail)


func handle_enemy_death_explosion(origin: Vector2, radius: float, damage: int) -> void:
	for player in _coop.call("get_player_target_nodes"):
		if player == null or not is_instance_valid(player) or not player.is_alive():
			continue
		if player.global_position.distance_to(origin) <= radius:
			player.apply_damage(damage)
	var burst := ParticleFactoryData.create_explosion_burst(Color(1.0, 0.54, 0.22, 1.0), 1.1)
	burst.global_position = origin
	_effects_parent.add_child(burst)
	var ring := ParticleFactoryData.create_explosion_ring(Color(1.0, 0.78, 0.48, 0.88), radius, 3.0)
	ring.global_position = origin
	_effects_parent.add_child(ring)
