extends CharacterBody2D

signal enemy_died(enemy)
signal fire_requested(origin, direction, speed, damage, team, color)
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
	SPITTER,
	CHARGER,
	BOSS,
}

@export var move_speed: float = 120.0
@export var max_health: int = 3
@export var contact_damage: int = 1
@export var projectile_speed: float = 340.0
@export var projectile_damage: int = 1
@export var fire_interval: float = 1.3
@export var preferred_distance: float = 190.0

@onready var shadow: Polygon2D = $Shadow
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var body_root: Node2D = $BodyRoot
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
var _knockback_velocity: Vector2 = Vector2.ZERO
var _flash_material: ShaderMaterial = null
var _flash_tween: Tween = null
var _base_body_root_position := Vector2.ZERO
var _base_shadow_scale := Vector2.ONE
var _idle_phase := 0.0
var _strafe_sign := 1.0
var _next_strafe_flip_at := 0.0
var _burst_shots_remaining := 0
var _burst_shot_index := 0
var _next_burst_shot_at := 0.0
var _lunge_direction := Vector2.ZERO
var _lunge_windup_ends_at := 0.0
var _lunge_ends_at := 0.0
var _next_lunge_at := 0.0
var _charge_direction := Vector2.ZERO
var _charge_windup_ends_at := 0.0
var _charge_dash_ends_at := 0.0
var _next_charge_at := 0.0

func setup(type_name: String, combat_owner) -> void:
	_combat_owner = combat_owner
	match type_name:
		"spitter":
			enemy_type = EnemyType.SPITTER
			max_health = 2
			move_speed = 84.0
			fire_interval = 1.85
			projectile_speed = 340.0
			projectile_damage = 1
			preferred_distance = 230.0
			_projectile_burst_count = 1
			_projectile_spread_radians = 0.0
		"charger":
			enemy_type = EnemyType.CHARGER
			max_health = 4
			move_speed = 88.0
			fire_interval = 2.0
			projectile_speed = 0.0
			projectile_damage = 0
			contact_damage = 2
			preferred_distance = 200.0
			_projectile_burst_count = 0
			_projectile_spread_radians = 0.0
		"boss":
			enemy_type = EnemyType.BOSS
			max_health = 18
			move_speed = 82.0
			fire_interval = 1.3
			projectile_speed = 380.0
			projectile_damage = 1
			contact_damage = 1
			preferred_distance = 240.0
			_projectile_burst_count = 5
			_projectile_spread_radians = 0.14
		_:
			enemy_type = EnemyType.CHASER
			max_health = 3
			move_speed = 108.0
			fire_interval = 1.3
			projectile_speed = 340.0
			projectile_damage = 1
			preferred_distance = 190.0
			_projectile_burst_count = 1
			_projectile_spread_radians = 0.0
	current_health = max_health
	_reset_behavior_state()
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
	if body_root != null:
		_base_body_root_position = body_root.position
	if shadow != null:
		_base_shadow_scale = shadow.scale
	_idle_phase = float(get_instance_id() % 17) * 0.43
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

func _physics_process(_delta: float) -> void:
	if _is_dead:
		return

	var now := _current_time_seconds()
	var target = _get_closest_player()
	if target == null:
		_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 900.0 * _delta)
		velocity = _knockback_velocity
		move_and_slide()
		_apply_motion_polish(now)
		return

	var offset: Vector2 = target.global_position - global_position
	var distance: float = offset.length()
	var direction: Vector2 = offset.normalized() if distance > 0.0 else Vector2.ZERO
	var base_velocity := Vector2.ZERO

	match enemy_type:
		EnemyType.CHASER:
			base_velocity = _update_chaser_behavior(direction, distance, now)
		EnemyType.SPITTER:
			base_velocity = _update_spitter_behavior(direction, distance, now)
		EnemyType.CHARGER:
			base_velocity = _update_charger_behavior(direction, distance, now)
		EnemyType.BOSS:
			base_velocity = _update_boss_behavior(direction, distance, now)

	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 900.0 * _delta)
	velocity = base_velocity + _knockback_velocity
	move_and_slide()
	_apply_motion_polish(now)

	var contact_range := 40.0 if enemy_type == EnemyType.BOSS else 28.0
	if distance <= contact_range and now >= _next_contact_at:
		_next_contact_at = now + (1.0 if enemy_type == EnemyType.BOSS else 0.75)
		target.apply_damage(contact_damage)

func _update_chaser_behavior(direction: Vector2, distance: float, now: float) -> Vector2:
	if now < _lunge_windup_ends_at:
		return Vector2.ZERO
	if now < _lunge_ends_at:
		return _lunge_direction * move_speed * 2.35
	if distance > 0.0 and distance < 250.0 and now >= _next_lunge_at:
		_lunge_direction = direction
		_lunge_windup_ends_at = now + 0.16
		_lunge_ends_at = _lunge_windup_ends_at + 0.22
		_next_lunge_at = now + 1.25
		return Vector2.ZERO
	return direction * move_speed * 0.86

func _update_spitter_behavior(direction: Vector2, distance: float, now: float) -> Vector2:
	var base_velocity := Vector2.ZERO
	if distance > preferred_distance + 36.0:
		base_velocity = direction * move_speed
	elif distance < preferred_distance - 34.0:
		base_velocity = -direction * move_speed
	else:
		if now >= _next_strafe_flip_at:
			_next_strafe_flip_at = now + 0.9
			_strafe_sign *= -1.0
		base_velocity = Vector2(-direction.y, direction.x) * move_speed * 0.7 * _strafe_sign

	if distance > 0.0:
		if _burst_shots_remaining > 0 and now >= _next_burst_shot_at:
			_emit_spitter_shot(direction)
			_burst_shots_remaining -= 1
			_burst_shot_index += 1
			if _burst_shots_remaining > 0:
				_next_burst_shot_at = now + 0.18
			else:
				_next_projectile_at = now + fire_interval
		elif _burst_shots_remaining == 0 and now >= _next_projectile_at:
			_burst_shots_remaining = 3
			_burst_shot_index = 0
			_next_burst_shot_at = now
	return base_velocity

func _update_charger_behavior(direction: Vector2, distance: float, now: float) -> Vector2:
	if now < _charge_windup_ends_at:
		return Vector2.ZERO
	if now < _charge_dash_ends_at:
		return _charge_direction * move_speed * 3.4
	if distance > 115.0 and distance < 360.0 and now >= _next_charge_at:
		_charge_direction = direction
		_charge_windup_ends_at = now + 0.34
		_charge_dash_ends_at = _charge_windup_ends_at + 0.24
		_next_charge_at = now + 2.3
		return Vector2.ZERO
	if distance > preferred_distance:
		return direction * move_speed * 0.92
	return Vector2(-direction.y, direction.x) * move_speed * 0.35

func _update_boss_behavior(direction: Vector2, distance: float, now: float) -> Vector2:
	var base_velocity := Vector2.ZERO
	if distance > preferred_distance + 55.0:
		base_velocity = direction * move_speed
	elif distance < preferred_distance - 55.0:
		base_velocity = -direction * move_speed * 0.7
	else:
		base_velocity = Vector2(-direction.y, direction.x) * move_speed * 0.45

	if distance > 0.0 and now >= _next_projectile_at:
		_next_projectile_at = now + fire_interval
		_emit_projectile_burst(direction)
	return base_velocity

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
			visual.color.lightened(0.08)
		)

func _emit_spitter_shot(base_direction: Vector2) -> void:
	var spread_offsets := [0.0, -0.12, 0.12]
	var offset_index := clampi(_burst_shot_index, 0, spread_offsets.size() - 1)
	var projectile_direction := base_direction.normalized().rotated(float(spread_offsets[offset_index]))
	fire_requested.emit(
		global_position + projectile_direction * 20.0,
		projectile_direction,
		projectile_speed,
		projectile_damage,
		get_team(),
		visual.color.lightened(0.08)
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
			visual.color = Color(0.76, 0.26, 0.78, 1.0)
			visual.polygon = PackedVector2Array([
				Vector2(-24, -9),
				Vector2(-10, -16),
				Vector2(10, -16),
				Vector2(24, -9),
				Vector2(20, 9),
				Vector2(-20, 9),
			])
			visual.scale = Vector2(1.0, 1.0)
			_set_collision_radius(21.0)
		EnemyType.CHARGER:
			visual.color = Color(0.52, 0.26, 0.12, 1.0)
			visual.polygon = PackedVector2Array([
				Vector2(-18, -18),
				Vector2(18, -18),
				Vector2(28, -2),
				Vector2(20, 24),
				Vector2(-20, 24),
			])
			visual.scale = Vector2(1.34, 1.34)
			_set_collision_radius(28.0)
		EnemyType.BOSS:
			visual.color = Color(0.46, 0.03, 0.07, 1.0)
			visual.polygon = PackedVector2Array([
				Vector2(0, -42),
				Vector2(14, -34),
				Vector2(24, -46),
				Vector2(34, -28),
				Vector2(48, -12),
				Vector2(44, 22),
				Vector2(26, 44),
				Vector2(8, 50),
				Vector2(-8, 50),
				Vector2(-26, 44),
				Vector2(-44, 22),
				Vector2(-48, -12),
				Vector2(-34, -28),
				Vector2(-24, -46),
				Vector2(-14, -34),
			])
			visual.scale = Vector2(1.5, 1.5)
			_set_collision_radius(44.0)
		_:
			visual.color = Color(1.0, 0.16, 0.12, 1.0)
			visual.polygon = PackedVector2Array([
				Vector2(0, -26),
				Vector2(14, 4),
				Vector2(0, 16),
				Vector2(-14, 4),
			])
			visual.scale = Vector2(0.72, 0.72)
			_set_collision_radius(14.0)

func _set_collision_radius(radius: float) -> void:
	if collision_shape == null:
		return
	var circle := collision_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = radius

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _die() -> void:
	_is_dead = true
	velocity = Vector2.ZERO
	_knockback_velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if _combat_owner != null and _death_explosion_radius > 0.0 and _death_explosion_damage > 0:
		_combat_owner.handle_enemy_death_explosion(global_position, _death_explosion_radius, _death_explosion_damage)
	_play_flash(Color.WHITE, 0.14)
	enemy_died.emit(self)
	_queue_free_after_flash()

func _play_flash(color: Color, duration: float) -> void:
	if visual == null:
		return
	var material := _get_flash_material()
	material.set_shader_parameter("flash_color", color)
	material.set_shader_parameter("flash_intensity", 1.0)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(material, "shader_parameter/flash_intensity", 0.0, duration)

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
	await get_tree().create_timer(0.1).timeout
	queue_free()

func _apply_motion_polish(now: float) -> void:
	if body_root == null:
		return
	var bob_amount := 3.5
	var bob_frequency := 3.4
	match enemy_type:
		EnemyType.CHASER:
			bob_amount = 3.8
			bob_frequency = 5.3
		EnemyType.SPITTER:
			bob_amount = 2.8
			bob_frequency = 2.7
		EnemyType.CHARGER:
			bob_amount = 2.2
			bob_frequency = 1.9
		EnemyType.BOSS:
			bob_amount = 5.8
			bob_frequency = 1.6
	var bob := sin(now * bob_frequency + _idle_phase) * bob_amount
	var scale := Vector2.ONE
	if enemy_type == EnemyType.CHASER and now < _lunge_windup_ends_at:
		scale = Vector2(1.1, 0.88)
	elif enemy_type == EnemyType.CHASER and now < _lunge_ends_at:
		scale = Vector2(0.94, 1.18)
	elif enemy_type == EnemyType.CHARGER and now < _charge_windup_ends_at:
		scale = Vector2(1.18, 0.82)
	elif enemy_type == EnemyType.CHARGER and now < _charge_dash_ends_at:
		scale = Vector2(0.92, 1.22)
	body_root.position = _base_body_root_position + Vector2(0.0, bob)
	body_root.rotation = lerp_angle(body_root.rotation, clamp(velocity.x / max(move_speed, 1.0), -1.0, 1.0) * 0.08, 0.12)
	body_root.scale = scale
	if shadow != null:
		shadow.scale = Vector2(
			_base_shadow_scale.x * (1.0 - abs(bob) * 0.01),
			_base_shadow_scale.y * (1.0 + abs(bob) * 0.015)
		)

func _play_spawn_in_animation() -> void:
	if body_root == null:
		return
	body_root.scale = Vector2(0.18, 0.18)
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
	_strafe_sign = -1.0 if int(get_instance_id() % 2) == 0 else 1.0
	_next_strafe_flip_at = 0.0
	_burst_shots_remaining = 0
	_burst_shot_index = 0
	_next_burst_shot_at = 0.0
	_lunge_direction = Vector2.ZERO
	_lunge_windup_ends_at = 0.0
	_lunge_ends_at = 0.0
	_next_lunge_at = 0.0
	_charge_direction = Vector2.ZERO
	_charge_windup_ends_at = 0.0
	_charge_dash_ends_at = 0.0
	_next_charge_at = 0.0
