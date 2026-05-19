extends Node

const MIX_RATE := 22050.0
const POOL_SIZE := 16

var _players: Array = []
var _player_busy_until: Array = []
var _next_player_index: int = 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("sfx_engine")
	_rng.randomize()
	for _index in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		var stream := AudioStreamGenerator.new()
		stream.mix_rate = MIX_RATE
		stream.buffer_length = 0.4
		player.stream = stream
		add_child(player)
		_players.append(player)
		_player_busy_until.append(0.0)

func play_fire(profile: String = "rifle", weight: float = 1.0) -> void:
	_play_buffer(_build_fire_frames(profile, weight), -9.8 + weight * 0.8)

func play_impact(weight: float = 1.0) -> void:
	_play_buffer(_build_hit_frames(weight), -11.4 + weight * 0.7)

func play_hit(weight: float = 1.0) -> void:
	play_impact(weight)

func play_explosion(weight: float = 1.0, profile: String = "shockwave") -> void:
	_play_buffer(_build_explosion_frames(weight, profile), -5.2 + weight * 0.9)

func play_dash(weight: float = 1.0) -> void:
	_play_buffer(_build_dash_frames(weight), -10.6 + weight * 0.5)

func play_damage() -> void:
	_play_buffer(_build_damage_frames(), -8.0)

func play_enemy_death(weight: float = 1.0) -> void:
	_play_buffer(_build_enemy_death_frames(weight), -9.8 + weight * 0.8)

func play_ui_click() -> void:
	_play_buffer(_build_ui_click_frames(), -14.0)

func play_room_clear() -> void:
	_play_buffer(_build_room_clear_frames(), -8.0)

func _play_buffer(frames: PackedVector2Array, volume_db: float) -> void:
	if frames.is_empty():
		return
	var player_index: int = _get_available_player_index()
	if player_index < 0:
		return
	var player: AudioStreamPlayer = _players[player_index]
	player.volume_db = volume_db
	player.stop()
	player.play()
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	if playback == null:
		return
	playback.push_buffer(frames)
	var duration: float = float(frames.size()) / MIX_RATE
	_player_busy_until[player_index] = _current_time_seconds() + duration + 0.03

func _get_available_player_index() -> int:
	if _players.is_empty():
		return -1
	var now := _current_time_seconds()
	for offset in range(_players.size()):
		var index := (_next_player_index + offset) % _players.size()
		if now >= float(_player_busy_until[index]):
			_next_player_index = (index + 1) % _players.size()
			return index
	return -1

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _build_fire_frames(profile: String, weight: float) -> PackedVector2Array:
	var duration := 0.04
	if profile == "slug":
		duration = 0.07
	elif profile == "scatter":
		duration = 0.05
	var sample_count := int(MIX_RATE * duration)
	var frames := PackedVector2Array()
	frames.resize(sample_count)
	var carrier := _rng.randf_range(1400.0, 2200.0)
	var tone_mix: float = 0.45
	var noise_mix: float = 0.7
	match profile:
		"scatter":
			carrier = _rng.randf_range(820.0, 1280.0)
			tone_mix = 0.38
			noise_mix = 0.95
		"slug":
			carrier = _rng.randf_range(220.0, 360.0)
			tone_mix = 0.72
			noise_mix = 0.3
	for index in range(sample_count):
		var t := float(index) / MIX_RATE
		var env := exp(-t * (42.0 - weight * 5.0))
		var noise := _rng.randf_range(-1.0, 1.0)
		var tone := sin(TAU * carrier * t) * tone_mix
		if profile == "slug":
			tone += sin(TAU * (carrier * 0.52) * t) * 0.42
		var sample := (noise * noise_mix + tone) * env * (0.48 + weight * 0.08)
		frames[index] = Vector2(sample, sample)
	return frames

func _build_hit_frames(weight: float) -> PackedVector2Array:
	var duration := 0.025 + weight * 0.01
	var sample_count := int(MIX_RATE * duration)
	var frames := PackedVector2Array()
	frames.resize(sample_count)
	var frequency := _rng.randf_range(760.0, 900.0 - weight * 80.0)
	for index in range(sample_count):
		var t := float(index) / MIX_RATE
		var env := exp(-t * (72.0 - weight * 10.0))
		var sample := (sin(TAU * frequency * t) + sin(TAU * (frequency * 0.45) * t) * 0.34) * env * (0.34 + weight * 0.08)
		frames[index] = Vector2(sample, sample)
	return frames

func _build_explosion_frames(weight: float, profile: String) -> PackedVector2Array:
	var duration := 0.22 + weight * 0.06
	var sample_count := int(MIX_RATE * duration)
	var frames := PackedVector2Array()
	frames.resize(sample_count)
	for index in range(sample_count):
		var t := float(index) / MIX_RATE
		var env := exp(-t * (10.5 - weight * 1.2))
		var rumble := sin(TAU * (58.0 - weight * 6.0) * t) * (0.42 + weight * 0.08)
		var body := sin(TAU * (180.0 - t * (320.0 + weight * 36.0)) * t) * 0.2
		var noise := _rng.randf_range(-1.0, 1.0) * (0.48 + weight * 0.09)
		if profile == "mine":
			body += sin(TAU * 96.0 * t) * 0.18
		var sample := (rumble + body + noise) * env * (0.56 + weight * 0.08)
		frames[index] = Vector2(sample, sample)
	return frames

func _build_dash_frames(weight: float) -> PackedVector2Array:
	var duration := 0.12 + weight * 0.03
	var sample_count := int(MIX_RATE * duration)
	var frames := PackedVector2Array()
	frames.resize(sample_count)
	for index in range(sample_count):
		var t := float(index) / MIX_RATE
		var progress := t / duration
		var env := exp(-t * (18.0 - weight * 2.0))
		var sweep := lerpf(220.0, 1640.0, progress)
		var sample := (sin(TAU * sweep * t) * (0.28 + weight * 0.08) + _rng.randf_range(-1.0, 1.0) * 0.18) * env
		frames[index] = Vector2(sample, sample)
	return frames

func _build_damage_frames() -> PackedVector2Array:
	var duration := 0.12
	var sample_count := int(MIX_RATE * duration)
	var frames := PackedVector2Array()
	frames.resize(sample_count)
	for index in range(sample_count):
		var t := float(index) / MIX_RATE
		var env := exp(-t * 18.0)
		var frequency := lerpf(220.0, 110.0, t / duration)
		var pulse: float = 1.0 if sin(TAU * frequency * t) >= 0.0 else -1.0
		var sample: float = pulse * env * 0.24 + sin(TAU * frequency * 0.5 * t) * env * 0.1
		frames[index] = Vector2(sample, sample)
	return frames

func _build_enemy_death_frames(weight: float) -> PackedVector2Array:
	var duration := 0.08 + weight * 0.03
	var sample_count := int(MIX_RATE * duration)
	var frames := PackedVector2Array()
	frames.resize(sample_count)
	for index in range(sample_count):
		var t := float(index) / MIX_RATE
		var env := exp(-t * (26.0 - weight * 2.5))
		var frequency := lerpf(340.0, 90.0, t / duration)
		var sample := (sin(TAU * frequency * t) + sin(TAU * (frequency * 0.42) * t) * 0.24 + _rng.randf_range(-1.0, 1.0) * 0.2) * env * (0.34 + weight * 0.08)
		frames[index] = Vector2(sample, sample)
	return frames

func _build_ui_click_frames() -> PackedVector2Array:
	var duration := 0.05
	var sample_count := int(MIX_RATE * duration)
	var frames := PackedVector2Array()
	frames.resize(sample_count)
	for index in range(sample_count):
		var t := float(index) / MIX_RATE
		var env := exp(-t * 45.0)
		var sample := (sin(TAU * 900.0 * t) * 0.35 + sin(TAU * 1300.0 * t) * 0.18) * env
		frames[index] = Vector2(sample, sample)
	return frames

func _build_room_clear_frames() -> PackedVector2Array:
	var duration := 0.22
	var sample_count := int(MIX_RATE * duration)
	var frames := PackedVector2Array()
	frames.resize(sample_count)
	for index in range(sample_count):
		var t := float(index) / MIX_RATE
		var progress := t / duration
		var env := exp(-t * 8.0)
		var frequency := lerpf(420.0, 880.0, progress)
		var sample := (sin(TAU * frequency * t) + sin(TAU * frequency * 1.5 * t) * 0.35) * env * 0.34
		frames[index] = Vector2(sample, sample)
	return frames
