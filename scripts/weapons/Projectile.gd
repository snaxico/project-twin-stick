extends Area2D

const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")
const PLAYER_BULLET_TEXTURE_PATH := "res://assets/sprites/weapons/player_bullet.png"

@export var lifetime: float = 1.8

signal impact_requested(origin, direction, team, color)

var direction: Vector2 = Vector2.RIGHT
var speed: float = 500.0
var damage: int = 1
var team: String = ""
var tint_color: Color = Color(1.0, 0.96, 0.7, 1.0)
var allow_friendly_fire := false
var _shooter_node: Node = null

@onready var visual: Polygon2D = $Visual
@onready var outline: Polygon2D = $Outline
@onready var sprite_visual: Sprite2D = $SpriteVisual

var _expires_at := 0.0
var _trail_particles: GPUParticles2D = null
var _player_bullet_texture: Texture2D = null

func setup(projectile_team: String, projectile_direction: Vector2, projectile_speed: float, projectile_damage: int, projectile_color: Color = Color(1.0, 0.96, 0.7, 1.0), projectile_shooter: Node = null) -> void:
	team = projectile_team
	direction = projectile_direction.normalized() if projectile_direction.length() > 0.0 else Vector2.RIGHT
	speed = projectile_speed
	damage = projectile_damage
	tint_color = projectile_color
	_shooter_node = projectile_shooter

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_expires_at = _current_time_seconds() + lifetime
	rotation = direction.angle()
	_player_bullet_texture = _load_sprite_texture(PLAYER_BULLET_TEXTURE_PATH)
	_apply_visual_state()
	_trail_particles = ParticleFactoryData.create_projectile_trail(_get_projectile_color())
	add_child(_trail_particles)

func _physics_process(delta: float) -> void:
	rotation = direction.angle()
	global_position += direction * speed * delta
	if _current_time_seconds() >= _expires_at:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body is StaticBody2D:
		impact_requested.emit(global_position, -direction, team, _get_projectile_color())
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
	if target.has_method("get_team"):
		var target_team := str(target.get_team())
		if target_team == team:
			if allow_friendly_fire and team == "player" and target_team == "player" and target != _shooter_node:
				pass
			else:
				return
	if target.has_method("apply_knockback"):
		target.apply_knockback(direction, 200.0)
	target.apply_damage(damage)
	impact_requested.emit(global_position, -direction, team, _get_projectile_color())
	queue_free()

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _apply_visual_state() -> void:
	if visual == null:
		return
	var projectile_color := _get_projectile_color()
	var enemy_shot := team == "enemy"
	var use_player_sprite: bool = not enemy_shot and sprite_visual != null and _player_bullet_texture != null
	visual.visible = not use_player_sprite
	if enemy_shot:
		visual.color = projectile_color.lightened(0.12)
		visual.scale = Vector2(1.32, 1.32)
		visual.polygon = PackedVector2Array([
			Vector2(0, -9),
			Vector2(9, 0),
			Vector2(0, 9),
			Vector2(-9, 0),
		])
	else:
		visual.color = projectile_color
		visual.scale = Vector2(1.2, 1.2)
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

func _load_sprite_texture(path: String) -> Texture2D:
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		push_warning("Failed to load projectile sprite texture: %s" % path)
		return null
	return texture

func _get_projectile_color() -> Color:
	return tint_color
