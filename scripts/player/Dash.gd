class_name Dash
extends RefCounted

var dash_duration: float = 0.4
var cooldown_duration: float = 1.5
var dash_speed: float = 640.0

var _active_until: float = 0.0
var _cooldown_until: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT

func try_trigger(direction: Vector2, now: float) -> bool:
	if not is_ready(now):
		return false

	if direction.length() > 0.0:
		_dash_direction = direction.normalized()

	_active_until = now + dash_duration
	_cooldown_until = now + dash_duration + cooldown_duration
	return true

func get_velocity(move_input: Vector2, fallback_direction: Vector2, move_speed: float, now: float) -> Vector2:
	if is_active(now):
		if _dash_direction.length() == 0.0:
			_dash_direction = fallback_direction.normalized() if fallback_direction.length() > 0.0 else Vector2.RIGHT
		return _dash_direction * dash_speed
	return move_input * move_speed

func is_active(now: float) -> bool:
	return now < _active_until

func is_ready(now: float) -> bool:
	return now >= _cooldown_until

func get_cooldown_remaining(now: float) -> float:
	return max(_cooldown_until - now, 0.0)
