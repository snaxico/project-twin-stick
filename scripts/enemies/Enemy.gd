extends CharacterBody2D

signal enemy_died(enemy)
signal fire_requested(origin, direction, speed, damage, team)

enum EnemyType {
	CHASER,
	SPITTER,
	BOSS,
}

@export var move_speed: float = 120.0
@export var max_health: int = 3
@export var contact_damage: int = 1
@export var projectile_speed: float = 340.0
@export var projectile_damage: int = 1
@export var fire_interval: float = 1.3
@export var preferred_distance: float = 190.0

@onready var visual: Polygon2D = $BodyRoot/Visual

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

func setup(type_name: String, combat_owner) -> void:
	_combat_owner = combat_owner
	match type_name:
		"spitter":
			enemy_type = EnemyType.SPITTER
			max_health = 2
			move_speed = 90.0
			fire_interval = 1.15
			projectile_speed = 340.0
			projectile_damage = 1
			preferred_distance = 190.0
			_projectile_burst_count = 1
			_projectile_spread_radians = 0.0
		"boss":
			enemy_type = EnemyType.BOSS
			max_health = 18
			move_speed = 82.0
			fire_interval = 0.95
			projectile_speed = 380.0
			projectile_damage = 1
			contact_damage = 1
			preferred_distance = 240.0
			_projectile_burst_count = 5
			_projectile_spread_radians = 0.18
		_:
			enemy_type = EnemyType.CHASER
			max_health = 3
			move_speed = 125.0
			fire_interval = 1.3
			projectile_speed = 340.0
			projectile_damage = 1
			preferred_distance = 190.0
			_projectile_burst_count = 1
			_projectile_spread_radians = 0.0
	current_health = max_health
	_apply_type_visual()

func apply_room_modifier(enemy_bonus_health: int, enemy_speed_multiplier: float, enemy_fire_interval_multiplier: float, death_explosion_radius: float, death_explosion_damage: int, enemy_contact_damage_bonus: int) -> void:
	if enemy_type == EnemyType.BOSS:
		return
	max_health += enemy_bonus_health
	current_health = max_health
	move_speed *= enemy_speed_multiplier
	fire_interval *= enemy_fire_interval_multiplier
	contact_damage += enemy_contact_damage_bonus
	_death_explosion_radius = death_explosion_radius
	_death_explosion_damage = death_explosion_damage

func apply_boss_scale(player_count: int) -> void:
	if enemy_type != EnemyType.BOSS:
		return

	var scale: float = 1.0 + float(max(player_count - 1, 0)) * 0.6
	max_health = int(round(max_health * scale))
	current_health = max_health
	projectile_damage += max(player_count - 1, 0)

func _ready() -> void:
	if current_health <= 0:
		current_health = max_health
	add_to_group("aim_target")
	_apply_type_visual()

func get_team() -> String:
	return "enemy"

func is_alive() -> bool:
	return not _is_dead and current_health > 0

func is_boss() -> bool:
	return enemy_type == EnemyType.BOSS

func get_health_ratio_text() -> String:
	return "%d/%d" % [current_health, max_health]

func apply_damage(amount: int) -> void:
	if _is_dead:
		return

	current_health = max(current_health - amount, 0)
	if current_health == 0:
		_is_dead = true
		if _combat_owner != null and _death_explosion_radius > 0.0 and _death_explosion_damage > 0:
			_combat_owner.handle_enemy_death_explosion(global_position, _death_explosion_radius, _death_explosion_damage)
		enemy_died.emit(self)
		queue_free()

func _physics_process(_delta: float) -> void:
	if _is_dead:
		return

	var target = _get_closest_player()
	if target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var offset: Vector2 = target.global_position - global_position
	var distance: float = offset.length()
	var direction: Vector2 = offset.normalized() if distance > 0.0 else Vector2.ZERO
	var now := _current_time_seconds()

	match enemy_type:
		EnemyType.CHASER:
			velocity = direction * move_speed
		EnemyType.SPITTER:
			_update_ranged_movement(direction, distance, now)
		EnemyType.BOSS:
			_update_boss_behavior(direction, distance, now)

	move_and_slide()

	var contact_range := 40.0 if enemy_type == EnemyType.BOSS else 28.0
	if distance <= contact_range and now >= _next_contact_at:
		_next_contact_at = now + (1.0 if enemy_type == EnemyType.BOSS else 0.75)
		target.apply_damage(contact_damage)

func _update_ranged_movement(direction: Vector2, distance: float, now: float) -> void:
	if distance > preferred_distance + 30.0:
		velocity = direction * move_speed
	elif distance < preferred_distance - 30.0:
		velocity = -direction * move_speed
	else:
		velocity = Vector2.ZERO

	if distance > 0.0 and now >= _next_projectile_at:
		_next_projectile_at = now + fire_interval
		_emit_projectile_burst(direction)

func _update_boss_behavior(direction: Vector2, distance: float, now: float) -> void:
	if distance > preferred_distance + 55.0:
		velocity = direction * move_speed
	elif distance < preferred_distance - 55.0:
		velocity = -direction * move_speed * 0.7
	else:
		velocity = Vector2(-direction.y, direction.x) * move_speed * 0.45

	if distance > 0.0 and now >= _next_projectile_at:
		_next_projectile_at = now + fire_interval
		_emit_projectile_burst(direction)

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
			get_team()
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

func _get_closest_player():
	if _combat_owner == null:
		return null

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

	return best_player

func _apply_type_visual() -> void:
	if visual == null:
		return

	match enemy_type:
		EnemyType.SPITTER:
			visual.color = Color(0.85, 0.2, 0.2, 1.0)
			visual.polygon = PackedVector2Array([
				Vector2(-16, -16),
				Vector2(16, -16),
				Vector2(16, 16),
				Vector2(-16, 16),
			])
		EnemyType.BOSS:
			visual.color = Color(0.7, 0.05, 0.05, 1.0)
			visual.polygon = PackedVector2Array([
				Vector2(0, -34),
				Vector2(22, -28),
				Vector2(34, -8),
				Vector2(34, 16),
				Vector2(18, 34),
				Vector2(-18, 34),
				Vector2(-34, 16),
				Vector2(-34, -8),
				Vector2(-22, -28),
			])
		_:
			visual.color = Color(1.0, 0.15, 0.15, 1.0)
			visual.polygon = PackedVector2Array([
				Vector2(0, -18),
				Vector2(12, -14),
				Vector2(18, 0),
				Vector2(12, 14),
				Vector2(0, 18),
				Vector2(-12, 14),
				Vector2(-18, 0),
				Vector2(-12, -14),
			])

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
