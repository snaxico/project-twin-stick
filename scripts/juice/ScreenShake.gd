extends Node

@export var max_shake: float = 34.0
@export var trauma_decay: float = 3.4

var _trauma: float = 0.0
var _random := RandomNumberGenerator.new()
var _camera: Camera2D = null

func _ready() -> void:
	_random.randomize()
	_camera = get_parent() as Camera2D

func _process(delta: float) -> void:
	if _camera == null:
		return
	if _trauma <= 0.0:
		_camera.offset = _camera.offset.move_toward(Vector2.ZERO, max_shake * delta * 4.0)
		return

	_trauma = max(_trauma - trauma_decay * delta, 0.0)
	var intensity := _trauma * _trauma
	_camera.offset = Vector2(
		_random.randf_range(-1.0, 1.0),
		_random.randf_range(-1.0, 1.0)
	) * max_shake * intensity

func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func clear() -> void:
	_trauma = 0.0
	if _camera != null:
		_camera.offset = Vector2.ZERO
