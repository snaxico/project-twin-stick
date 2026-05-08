extends Area2D

const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")
const PLAYER_BULLET_TEXTURE_PATH := "res://assets/sprites/weapons/player_bullet.png"
const BASE_COLLISION_HALF_WIDTH := 4.0

@export var lifetime: float = 1.8

signal impact_requested(origin, direction, team, color, feedback_profile, impact_weight, target, combat_context)

var direction: Vector2 = Vector2.RIGHT
var speed: float = 500.0
var damage: int = 1
var team: String = ""
var tint_color: Color = Color(1.0, 0.96, 0.7, 1.0)
var allow_friendly_fire := false
var feedback_profile: String = "rifle"
var impact_weight: float = 1.0
var max_distance: float = 0.0
var collision_half_width: float = BASE_COLLISION_HALF_WIDTH
var pierce_count: int = 0
var source_type: String = "projectile"
var weapon_id: String = ""
var weapon_tags: Array = []
var trigger_passives: Array = []
var _shooter_node: Node = null

@onready var visual: Polygon2D = $Visual
@onready var outline: Polygon2D = $Outline
@onready var sprite_visual: Sprite2D = $SpriteVisual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _expires_at := 0.0
var _trail_particles: GPUParticles2D = null
var _player_bullet_texture: Texture2D = null
var _spawn_position := Vector2.ZERO
var _base_collision_radius := 0.0
var _base_visual_scale := Vector2.ONE
var _base_sprite_scale := Vector2.ONE
var _hit_targets: Array = []

func setup(projectile_team: String, projectile_direction: Vector2, projectile_speed: float, projectile_damage: int, projectile_color: Color = Color(1.0, 0.96, 0.7, 1.0), projectile_shooter: Node = null, projectile_feedback_profile: String = "rifle", projectile_impact_weight: float = 1.0) -> void:
	team = projectile_team
	direction = projectile_direction.normalized() if projectile_direction.length() > 0.0 else Vector2.RIGHT
	speed = projectile_speed
	damage = projectile_damage
	tint_color = projectile_color
	_shooter_node = projectile_shooter
	feedback_profile = projectile_feedback_profile
	impact_weight = projectile_impact_weight
	max_distance = 0.0
	collision_half_width = BASE_COLLISION_HALF_WIDTH
	pierce_count = 0
	source_type = "projectile"
	weapon_id = ""
	weapon_tags = []
	trigger_passives = []
	_hit_targets.clear()

func setup_from_config(projectile_team: String, projectile_direction: Vector2, config: Dictionary) -> void:
	setup(
		projectile_team,
		projectile_direction,
		float(config.get("speed", speed)),
		int(config.get("damage", damage)),
		config.get("color", tint_color),
		config.get("shooter", null),
		str(config.get("feedback_profile", feedback_profile)),
		float(config.get("impact_weight", impact_weight))
	)
	max_distance = max(0.0, float(config.get("max_distance", max_distance)))
	collision_half_width = max(0.1, float(config.get("collision_half_width", collision_half_width)))
	pierce_count = max(0, int(config.get("pierce_count", pierce_count)))
	source_type = str(config.get("source_type", source_type))
	weapon_id = str(config.get("weapon_id", weapon_id))
	weapon_tags = (config.get("weapon_tags", []) as Array).duplicate(true)
	trigger_passives = (config.get("trigger_passives", []) as Array).duplicate(true)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_expires_at = _current_time_seconds() + lifetime
	rotation = direction.angle()
	_spawn_position = global_position
	_player_bullet_texture = _load_sprite_texture(PLAYER_BULLET_TEXTURE_PATH)
	if visual != null:
		_base_visual_scale = visual.scale
	if sprite_visual != null:
		_base_sprite_scale = sprite_visual.scale
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		collision_shape.shape = (collision_shape.shape as CircleShape2D).duplicate()
		_base_collision_radius = (collision_shape.shape as CircleShape2D).radius
	_apply_visual_state()
	_trail_particles = ParticleFactoryData.create_projectile_trail(_get_projectile_color())
	add_child(_trail_particles)

func _physics_process(delta: float) -> void:
	rotation = direction.angle()
	global_position += direction * speed * delta
	if max_distance > 0.0 and global_position.distance_squared_to(_spawn_position) >= max_distance * max_distance:
		queue_free()
		return
	if _current_time_seconds() >= _expires_at:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body is StaticBody2D:
		impact_requested.emit(global_position, -direction, team, _get_projectile_color(), feedback_profile, impact_weight, body, _build_combat_context(body))
		queue_free()
		return

	_attempt_hit_target(body)

func _on_area_entered(area: Area2D) -> void:
	_attempt_hit_target(area)

func _attempt_hit_target(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("apply_damage"):
		return
	if _hit_targets.has(target):
		return
	if target.has_method("get_team"):
		var target_team := str(target.get_team())
		if target_team == team:
			if allow_friendly_fire and team == "player" and target_team == "player" and target != _shooter_node:
				pass
			else:
				return
	if target.has_method("apply_knockback"):
		target.apply_knockback(direction, 180.0 + impact_weight * 90.0)
	target.apply_damage(damage)
	_hit_targets.append(target)
	impact_requested.emit(global_position, -direction, team, _get_projectile_color(), feedback_profile, impact_weight, target, _build_combat_context(target))
	if pierce_count > 0:
		pierce_count -= 1
		return
	queue_free()

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _apply_visual_state() -> void:
	if visual == null:
		return
	var projectile_color: Color = _get_projectile_color()
	var enemy_shot: bool = team == "enemy"
	var use_player_sprite: bool = not enemy_shot and sprite_visual != null and _player_bullet_texture != null
	var size_scale: float = maxf(collision_half_width / BASE_COLLISION_HALF_WIDTH, 0.25)
	visual.visible = not use_player_sprite
	if enemy_shot:
		visual.color = projectile_color.lightened(0.12)
		visual.scale = _base_visual_scale * 1.32 * size_scale
		visual.polygon = PackedVector2Array([
			Vector2(0, -9),
			Vector2(9, 0),
			Vector2(0, 9),
			Vector2(-9, 0),
		])
	else:
		visual.color = projectile_color
		visual.scale = _base_visual_scale * 1.2 * size_scale
		visual.polygon = PackedVector2Array([
			Vector2(0, -8),
			Vector2(10, 0),
			Vector2(0, 8),
			Vector2(-10, 0),
		])
	if outline != null:
		outline.visible = not use_player_sprite
		if enemy_shot:
			outline.color = Color(1.0, 0.92, 0.82, 0.96)
		else:
			var player_outline_color: Color = projectile_color
			player_outline_color.a = 0.88
			outline.color = player_outline_color
		outline.scale = visual.scale * 1.24
		outline.polygon = visual.polygon
	if sprite_visual != null:
		sprite_visual.visible = use_player_sprite
		if sprite_visual.visible:
			sprite_visual.texture = _player_bullet_texture
			sprite_visual.modulate = Color.WHITE
			sprite_visual.scale = _base_sprite_scale * size_scale
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = _base_collision_radius * size_scale

func _load_sprite_texture(path: String) -> Texture2D:
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		push_warning("Failed to load projectile sprite texture: %s" % path)
		return null
	return texture

func _get_projectile_color() -> Color:
	return tint_color

func _build_combat_context(target: Node) -> Dictionary:
	return {
		"owner": _shooter_node,
		"weapon_id": weapon_id,
		"weapon_tags": weapon_tags,
		"origin": global_position,
		"direction": direction,
		"target": target,
		"damage": damage,
		"color": _get_projectile_color(),
		"feedback_profile": feedback_profile,
		"impact_weight": impact_weight,
		"is_tick": false,
		"source_type": source_type,
		"trigger_passives": trigger_passives,
	}
