class_name Dash
extends RefCounted

const INPUT_BUFFER_DURATION := 0.12

var dash_duration: float = 0.4
var cooldown_duration: float = 2.0
var dash_speed: float = 640.0

var _active_until: float = 0.0
var _cooldown_until: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT
var _buffered_until: float = 0.0
var _buffered_direction: Vector2 = Vector2.RIGHT

func try_trigger(direction: Vector2, now: float) -> bool:
	if direction.length() > 0.0:
		_dash_direction = direction.normalized()
		_buffered_direction = _dash_direction

	if not is_ready(now):
		if get_cooldown_remaining(now) <= INPUT_BUFFER_DURATION:
			_buffered_until = now + INPUT_BUFFER_DURATION
		return false

	_active_until = now + dash_duration
	_cooldown_until = now + dash_duration + cooldown_duration
	_buffered_until = 0.0
	return true

func consume_buffer_if_ready(now: float) -> bool:
	if _buffered_until <= 0.0:
		return false
	if now > _buffered_until:
		_buffered_until = 0.0
		return false
	if not is_ready(now):
		return false
	_dash_direction = _buffered_direction if _buffered_direction.length() > 0.0 else _dash_direction
	_active_until = now + dash_duration
	_cooldown_until = now + dash_duration + cooldown_duration
	_buffered_until = 0.0
	return true

func clear_buffer() -> void:
	_buffered_until = 0.0

func get_velocity(move_input: Vector2, fallback_direction: Vector2, move_speed: float, now: float) -> Vector2:
	if is_active(now):
		if _dash_direction.length() == 0.0:
			_dash_direction = fallback_direction.normalized() if fallback_direction.length() > 0.0 else Vector2.RIGHT
		return _dash_direction * dash_speed
	return move_input * move_speed

func get_direction() -> Vector2:
	return _dash_direction if _dash_direction.length() > 0.0 else Vector2.RIGHT

func is_active(now: float) -> bool:
	return now < _active_until

func is_ready(now: float) -> bool:
	return now >= _cooldown_until

func get_cooldown_remaining(now: float) -> float:
	return max(_cooldown_until - now, 0.0)
