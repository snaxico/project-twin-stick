extends Area2D

const ParticleFactoryData = preload("res://scripts/juice/ParticleFactory.gd")

@export var lifetime: float = 1.8

signal impact_requested(origin, direction, team, color)

var direction: Vector2 = Vector2.RIGHT
var speed: float = 500.0
var damage: int = 1
var team: String = ""
var tint_color: Color = Color(1.0, 0.96, 0.7, 1.0)

@onready var visual: Polygon2D = $Visual

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
		return

	if body.has_method("apply_damage"):
		if body.has_method("apply_knockback"):
			body.apply_knockback(direction, 200.0)
		body.apply_damage(damage)
		impact_requested.emit(global_position, -direction, team, _get_projectile_color())
		queue_free()

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _apply_visual_state() -> void:
	if visual == null:
		return
	visual.color = _get_projectile_color()
	visual.scale = Vector2(1.12, 1.12)

func _get_projectile_color() -> Color:
	return tint_color
