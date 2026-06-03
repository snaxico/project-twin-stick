extends Node

const MAX_DURATION_MS := 70
const MIN_INTERVAL_MS := 120
const DEFAULT_SCALE := 0.05

var _active_until_ms := 0
var _last_start_ms := -MIN_INTERVAL_MS
var _active_weight := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

func request_hit_stop(weight: float = 1.0, duration_ms: int = 50, scale: float = DEFAULT_SCALE) -> void:
	var now := Time.get_ticks_msec()
	var clamped_duration := clampi(duration_ms, 1, MAX_DURATION_MS)
	if now - _last_start_ms < MIN_INTERVAL_MS and weight <= _active_weight:
		return
	var target_until := now + clamped_duration
	if now < _active_until_ms and weight < _active_weight:
		return
	_active_weight = maxf(weight, _active_weight if now < _active_until_ms else 0.0)
	_active_until_ms = maxi(_active_until_ms, target_until)
	_last_start_ms = now
	Engine.time_scale = clampf(scale, 0.01, 1.0)

func request_dilation(duration_ms: int = 70, scale: float = 0.18) -> void:
	request_hit_stop(0.5, duration_ms, scale)

func clear() -> void:
	_active_until_ms = 0
	_active_weight = 0.0
	Engine.time_scale = 1.0

func _process(_delta: float) -> void:
	if _active_until_ms <= 0:
		return
	if Time.get_ticks_msec() >= _active_until_ms:
		clear()

func _exit_tree() -> void:
	clear()
