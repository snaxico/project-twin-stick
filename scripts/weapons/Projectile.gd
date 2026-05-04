extends Area2D

@export var lifetime: float = 1.8

var direction: Vector2 = Vector2.RIGHT
var speed: float = 500.0
var damage: int = 1
var team: String = ""

var _expires_at := 0.0

func setup(projectile_team: String, projectile_direction: Vector2, projectile_speed: float, projectile_damage: int) -> void:
	team = projectile_team
	direction = projectile_direction.normalized() if projectile_direction.length() > 0.0 else Vector2.RIGHT
	speed = projectile_speed
	damage = projectile_damage

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_expires_at = _current_time_seconds() + lifetime

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	if _current_time_seconds() >= _expires_at:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body is StaticBody2D:
		queue_free()
		return

	if body.has_method("get_team") and body.get_team() == team:
		return

	if body.has_method("apply_damage"):
		body.apply_damage(damage)
		queue_free()

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
