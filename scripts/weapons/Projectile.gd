extends Area2D

const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")

@export var lifetime: float = 1.8

signal impact_requested(origin, direction, team, color)

var direction: Vector2 = Vector2.RIGHT
var speed: float = 500.0
var damage: int = 1
var team: String = ""
var tint_color: Color = Color(1.0, 0.96, 0.7, 1.0)
var allow_friendly_fire := false

@onready var visual: Polygon2D = $Visual
@onready var outline: Polygon2D = $Outline

var _expires_at := 0.0
var _trail_particles: GPUParticles2D = null

func setup(projectile_team: String, projectile_direction: Vector2, projectile_speed: float, projectile_damage: int, projectile_color: Color = Color(1.0, 0.96, 0.7, 1.0)) -> void:
	team = projectile_team
	direction = projectile_direction.normalized() if projectile_direction.length() > 0.0 else Vector2.RIGHT
	speed = projectile_speed
	damage = projectile_damage
	tint_color = projectile_color

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_expires_at = _current_time_seconds() + lifetime
	rotation = direction.angle()
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

	if body.has_method("get_team") and body.get_team() == team:
		if allow_friendly_fire and team == "player" and body.get_team() == "player":
			pass
		else:
			return

	if body.has_method("apply_damage"):
		if body.has_method("apply_knockback"):
			body.apply_knockback(direction, 200.0)
		body.apply_damage(damage)
		impact_requested.emit(global_position, -direction, team, _get_projectile_color())
		queue_free()
		return

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _apply_visual_state() -> void:
	if visual == null:
		return
	var projectile_color := _get_projectile_color()
	var enemy_shot := team == "enemy"
	visual.color = projectile_color.lightened(0.08) if enemy_shot else projectile_color
	visual.scale = Vector2(1.26, 1.26) if enemy_shot else Vector2(1.14, 1.14)
	visual.polygon = PackedVector2Array([
		Vector2(0, -9),
		Vector2(9, 0),
		Vector2(0, 9),
		Vector2(-9, 0),
	]) if enemy_shot else PackedVector2Array([
		Vector2(0, -8),
		Vector2(10, 0),
		Vector2(0, 8),
		Vector2(-10, 0),
	])
	if outline != null:
		outline.visible = true
		outline.color = Color(1.0, 0.96, 0.88, 0.96) if enemy_shot else Color(0.05, 0.08, 0.12, 0.82)
		outline.scale = visual.scale * 1.24
		outline.polygon = visual.polygon

func _get_projectile_color() -> Color:
	return tint_color
