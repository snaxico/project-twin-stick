class_name PerfProbe
extends RefCounted

static var _enabled := false
static var _frame_index := -1
static var _frame_usec: Dictionary = {}
static var _sum_usec: Dictionary = {}
static var _max_usec: Dictionary = {}
static var _sample_frames := 0


static func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	reset()


static func reset() -> void:
	_frame_index = -1
	_frame_usec.clear()
	_sum_usec.clear()
	_max_usec.clear()
	_sample_frames = 0


static func begin(_bucket: String) -> int:
	if not _enabled:
		return 0
	return Time.get_ticks_usec()


static func end(bucket: String, started_at_usec: int) -> void:
	if not _enabled or started_at_usec <= 0:
		return
	_roll_frame()
	_frame_usec[bucket] = int(_frame_usec.get(bucket, 0)) + maxi(0, Time.get_ticks_usec() - started_at_usec)


static func sample_frame() -> void:
	if not _enabled:
		return
	_roll_frame()
	for bucket_variant in _frame_usec.keys():
		var bucket := str(bucket_variant)
		var elapsed := int(_frame_usec[bucket])
		_sum_usec[bucket] = int(_sum_usec.get(bucket, 0)) + elapsed
		_max_usec[bucket] = maxi(int(_max_usec.get(bucket, 0)), elapsed)
	_sample_frames += 1
	_frame_usec.clear()


static func snapshot() -> Dictionary:
	var frames := maxi(_sample_frames, 1)
	var rows: Array = []
	for bucket_variant in _sum_usec.keys():
		var bucket := str(bucket_variant)
		rows.append({
			"bucket": bucket,
			"avg_ms": float(_sum_usec[bucket]) / 1000.0 / float(frames),
			"max_ms": float(_max_usec.get(bucket, 0)) / 1000.0,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("avg_ms", 0.0)) > float(b.get("avg_ms", 0.0))
	)
	return {
		"frames": _sample_frames,
		"rows": rows,
	}


static func _roll_frame() -> void:
	var current_frame := Engine.get_process_frames()
	if _frame_index < 0:
		_frame_index = current_frame
		return
	if current_frame != _frame_index:
		_frame_index = current_frame
		_frame_usec.clear()
