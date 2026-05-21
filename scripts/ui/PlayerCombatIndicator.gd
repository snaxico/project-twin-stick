class_name PlayerCombatIndicator
extends Control

const INDICATOR_SIZE := Vector2(56.0, 48.0)
const BAR_WIDTH := 44.0
const BAR_HEIGHT := 5.0
const LOW_HEALTH_THRESHOLD := 0.35
const COOLDOWN_ARC_CENTER := Vector2(INDICATOR_SIZE.x * 0.5, 18.0)
const COOLDOWN_ARC_RADIUS := 16.0
const COOLDOWN_ARC_WIDTH := 2.0
const COOLDOWN_ARC_STEPS := 28
const DASH_ARC_RADIUS := 10.0
const DASH_ARC_WIDTH := 1.5
const READY_PULSE_DURATION := 0.22

var _tint: Color = Color(0.28, 0.9, 0.82, 1.0)
var _current_health: int = 0
var _max_health: int = 1
var _health_ratio: float = 1.0
var _is_downed := false
var _low_health_phase := 0.0
var _shockwave_cooldown_remaining := 0.0
var _shockwave_cooldown_duration := 1.0
var _dash_cooldown_remaining := 0.0
var _dash_cooldown_duration := 1.0
var _shockwave_ready_pulse := 0.0
var _dash_ready_pulse := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = INDICATOR_SIZE
	visible = false

func configure_player(tint: Color) -> void:
	_tint = tint
	set_process(false)
	queue_redraw()

func update_state(current_health: int, max_health: int, is_downed: bool, shockwave_cooldown_remaining: float, shockwave_cooldown_duration: float, dash_cooldown_remaining: float, dash_cooldown_duration: float) -> void:
	var previous_shockwave_remaining := _shockwave_cooldown_remaining
	var previous_dash_remaining := _dash_cooldown_remaining
	_current_health = max(current_health, 0)
	_max_health = max(max_health, 1)
	_is_downed = is_downed
	_health_ratio = clampf(float(_current_health) / float(_max_health), 0.0, 1.0)
	_shockwave_cooldown_duration = maxf(shockwave_cooldown_duration, 0.01)
	_shockwave_cooldown_remaining = clampf(shockwave_cooldown_remaining, 0.0, _shockwave_cooldown_duration)
	_dash_cooldown_duration = maxf(dash_cooldown_duration, 0.01)
	_dash_cooldown_remaining = clampf(dash_cooldown_remaining, 0.0, _dash_cooldown_duration)
	if previous_shockwave_remaining > 0.0 and _shockwave_cooldown_remaining <= 0.0:
		_shockwave_ready_pulse = READY_PULSE_DURATION
	if previous_dash_remaining > 0.0 and _dash_cooldown_remaining <= 0.0:
		_dash_ready_pulse = READY_PULSE_DURATION
	visible = _is_downed or _current_health < _max_health or _shockwave_cooldown_remaining > 0.0 or _dash_cooldown_remaining > 0.0 or _shockwave_ready_pulse > 0.0 or _dash_ready_pulse > 0.0
	set_process(visible and (_is_downed or _health_ratio <= LOW_HEALTH_THRESHOLD or _shockwave_ready_pulse > 0.0 or _dash_ready_pulse > 0.0))
	queue_redraw()

func _process(delta: float) -> void:
	if _is_downed or _health_ratio <= LOW_HEALTH_THRESHOLD:
		_low_health_phase += delta * 5.0
	if _shockwave_ready_pulse > 0.0:
		_shockwave_ready_pulse = maxf(0.0, _shockwave_ready_pulse - delta)
	if _dash_ready_pulse > 0.0:
		_dash_ready_pulse = maxf(0.0, _dash_ready_pulse - delta)
	visible = _is_downed or _current_health < _max_health or _shockwave_cooldown_remaining > 0.0 or _dash_cooldown_remaining > 0.0 or _shockwave_ready_pulse > 0.0 or _dash_ready_pulse > 0.0
	set_process(_is_downed or _health_ratio <= LOW_HEALTH_THRESHOLD or _shockwave_ready_pulse > 0.0 or _dash_ready_pulse > 0.0)
	if visible:
		queue_redraw()

func _draw() -> void:
	if _shockwave_cooldown_remaining > 0.0:
		var ready_ratio := clampf((_shockwave_cooldown_duration - _shockwave_cooldown_remaining) / _shockwave_cooldown_duration, 0.0, 1.0)
		var end_angle := -PI * 0.5 + TAU * ready_ratio
		draw_arc(
			COOLDOWN_ARC_CENTER,
			COOLDOWN_ARC_RADIUS,
			-PI * 0.5,
			end_angle,
			COOLDOWN_ARC_STEPS,
			Color(_tint.r, _tint.g, _tint.b, 0.42),
			COOLDOWN_ARC_WIDTH
		)
	elif _shockwave_ready_pulse > 0.0:
		var pulse_alpha := clampf(_shockwave_ready_pulse / READY_PULSE_DURATION, 0.0, 1.0)
		draw_arc(
			COOLDOWN_ARC_CENTER,
			COOLDOWN_ARC_RADIUS,
			-PI * 0.5,
			-PI * 0.5 + TAU,
			COOLDOWN_ARC_STEPS,
			Color(_tint.r, _tint.g, _tint.b, 0.2 + pulse_alpha * 0.55),
			COOLDOWN_ARC_WIDTH + 1.0
		)

	if _dash_cooldown_remaining > 0.0:
		var dash_ready_ratio := clampf((_dash_cooldown_duration - _dash_cooldown_remaining) / _dash_cooldown_duration, 0.0, 1.0)
		var dash_start := PI * 0.12
		var dash_end := dash_start + PI * 0.76 * dash_ready_ratio
		draw_arc(
			COOLDOWN_ARC_CENTER,
			DASH_ARC_RADIUS,
			dash_start,
			dash_end,
			14,
			Color(1.0, 0.48, 0.82, 0.36),
			DASH_ARC_WIDTH
		)
	elif _dash_ready_pulse > 0.0:
		var dash_pulse_alpha := clampf(_dash_ready_pulse / READY_PULSE_DURATION, 0.0, 1.0)
		draw_arc(
			COOLDOWN_ARC_CENTER,
			DASH_ARC_RADIUS,
			PI * 0.12,
			PI * 0.88,
			14,
			Color(1.0, 0.62, 0.9, 0.18 + dash_pulse_alpha * 0.45),
			DASH_ARC_WIDTH + 0.8
		)

	if not (_is_downed or _current_health < _max_health):
		return

	var track_rect := Rect2((INDICATOR_SIZE.x - BAR_WIDTH) * 0.5, 40.0, BAR_WIDTH, BAR_HEIGHT)
	draw_rect(track_rect, Color(0.04, 0.06, 0.09, 0.68), true)
	draw_rect(track_rect, Color(0.78, 0.9, 1.0, 0.12), false, 1.0)

	var fill_color := _tint
	var alpha := 0.66
	if _is_downed:
		var pulse := 0.55 + 0.45 * (0.5 + 0.5 * sin(_low_health_phase))
		fill_color = Color(1.0, 0.28, 0.28, 1.0)
		alpha = 0.55 + pulse * 0.35
	elif _health_ratio <= LOW_HEALTH_THRESHOLD:
		var pulse := 0.65 + 0.35 * (0.5 + 0.5 * sin(_low_health_phase))
		fill_color = _tint.lerp(Color(1.0, 0.34, 0.3, 1.0), 0.5)
		alpha = 0.58 + pulse * 0.28
	elif _health_ratio >= 0.99:
		alpha = 0.34

	var fill_width := BAR_WIDTH * _health_ratio
	if fill_width > 0.0:
		draw_rect(Rect2(track_rect.position.x, track_rect.position.y, fill_width, BAR_HEIGHT), Color(fill_color.r, fill_color.g, fill_color.b, alpha), true)
