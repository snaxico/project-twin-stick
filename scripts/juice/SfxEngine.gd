extends Node

const AudioBusConfigData = preload("res://scripts/juice/AudioBusConfig.gd")

const MIX_RATE := 22050.0
const POOL_SIZE := 16
const SFX_BUS_NAME := "SFX"

var _players: Array = []
var _player_busy_until: Array = []
var _next_player_index: int = 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("sfx_engine")
	_rng.randomize()
	_ensure_sfx_bus()
	for _index in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		var stream := AudioStreamGenerator.new()
		stream.mix_rate = MIX_RATE
		stream.buffer_length = 0.4
		player.stream = stream
		player.bus = SFX_BUS_NAME
		add_child(player)
		_players.append(player)
		_player_busy_until.append(0.0)

func play_fire(profile: String = "rifle", weight: float = 1.0) -> void:
	_play_buffer(_build_fire_frames(profile, weight), -14.0 + weight * 0.45)

func play_impact(weight: float = 1.0) -> void:
	_play_buffer(_build_hit_frames(weight), -12.6 + weight * 0.55)

func play_impact_profile(weight: float = 1.0, profile: String = "hit") -> void:
	_play_buffer(_build_profiled_hit_frames(weight, profile), -12.4 + weight * 0.55)

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

func play_level_up() -> void:
	_play_buffer(_build_level_up_frames(), -6.8)

func play_pickup(weight: float = 1.0) -> void:
	_play_buffer(_build_pickup_frames(weight), -10.0 + weight * 0.45)

func _ensure_sfx_bus() -> void:
	AudioBusConfigData.ensure_audio_buses()

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

func _pitch_variation() -> float:
	return _rng.randf_range(0.92, 1.08)

func _build_fire_frames(profile: String, weight: float) -> PackedVector2Array:
	var duration := 0.055
	if profile == "slug":
		duration = 0.085
	elif profile == "scatter":
		duration = 0.065
	elif profile == "beam":
		duration = 0.038
	elif profile == "burn":
		duration = 0.072
	elif profile == "slash":
		duration = 0.05
	elif profile == "zap":
		duration = 0.045
	var sample_count := int(MIX_RATE * duration)
	var frames := PackedVector2Array()
	frames.resize(sample_count)
	var pitch := _pitch_variation()
	var carrier := _rng.randf_range(1400.0, 2200.0) * pitch
	var tone_mix: float = 0.38
	var noise_mix: float = 0.42
	match profile:
		"scatter":
			carrier = _rng.randf_range(820.0, 1280.0) * pitch
			tone_mix = 0.38
			noise_mix = 0.58
		"slug":
			carrier = _rng.randf_range(220.0, 360.0) * pitch
			tone_mix = 0.72
			noise_mix = 0.22
		"beam":
			carrier = _rng.randf_range(1760.0, 2320.0) * pitch
			tone_mix = 0.54
			noise_mix = 0.1
		"burn":
			carrier = _rng.randf_range(180.0, 260.0) * pitch
			tone_mix = 0.24
			noise_mix = 0.68
		"slash":
			carrier = _rng.randf_range(520.0, 760.0) * pitch
			tone_mix = 0.2
			noise_mix = 0.72
		"zap":
			carrier = _rng.randf_range(2100.0, 2850.0) * pitch
			tone_mix = 0.46
			noise_mix = 0.28
	var detune := _rng.randf_range(1.01, 1.04)
	for index in range(sample_count):
		var t := float(index) / MIX_RATE
		var attack := clampf(t / 0.008, 0.0, 1.0)
		var env := attack * exp(-t * (28.0 - weight * 3.0))
		var pitch_env := 1.0 + (0.16 if profile != "slug" else -0.1) * exp(-t * 24.0)
		if profile == "beam":
			pitch_env = 1.0 + 0.04 * sin(TAU * 42.0 * t)
		elif profile == "zap":
			pitch_env = 1.0 + _rng.randf_range(-0.08, 0.08)
		var noise := _rng.randf_range(-1.0, 1.0)
		var tone := sin(TAU * carrier * pitch_env * t) * tone_mix
		tone += sin(TAU * carrier * detune * pitch_env * t) * tone_mix * 0.22
		tone += sin(TAU * carrier * 1.92 * pitch_env * t) * tone_mix * 0.12
		if profile == "slug":
			tone += sin(TAU * (carrier * 0.52) * t) * 0.42
		elif profile == "slash":
			tone += sin(TAU * lerpf(carrier * 1.6, carrier * 0.42, t / duration) * t) * 0.28
		elif profile == "burn":
			noise *= lerpf(1.35, 0.8, t / duration)
		var sample := (noise * noise_mix + tone) * env * (0.28 + weight * 0.05)
		frames[index] = Vector2(sample, sample)
	return frames

func _build_hit_frames(weight: float) -> PackedVector2Array:
	var duration := 0.04 + weight * 0.012
	var sample_count := int(MIX_RATE * duration)
	var frames := PackedVector2Array()
	frames.resize(sample_count)
	var pitch := _pitch_variation()
	var frequency := _rng.randf_range(760.0, 900.0 - weight * 80.0) * pitch
	for index in range(sample_count):
		var t := float(index) / MIX_RATE
		var attack := clampf(t / 0.006, 0.0, 1.0)
		var env := attack * exp(-t * (44.0 - weight * 6.0))
		var progress := t / duration
		var sweep := frequency * lerpf(1.18, 0.72, progress)
		var sample := (
			sin(TAU * sweep * t) * 0.72
			+ sin(TAU * sweep * 0.45 * t) * 0.34
			+ sin(TAU * sweep * 2.01 * t) * 0.12
			+ _rng.randf_range(-1.0, 1.0) * 0.16
		) * env * (0.24 + weight * 0.06)
		frames[index] = Vector2(sample, sample)
	return frames

func _build_profiled_hit_frames(weight: float, profile: String) -> PackedVector2Array:
	var duration := 0.052 + weight * 0.014
	var sample_count := int(MIX_RATE * duration)
	var frames := PackedVector2Array()
	frames.resize(sample_count)
	var pitch := _pitch_variation()
	var base_frequency := 780.0 * pitch
	var noise_mix := 0.18
	match profile:
		"spread":
			base_frequency = 1120.0 * pitch
			noise_mix = 0.28
		"zip":
			base_frequency = 1640.0 * pitch
			noise_mix = 0.08
		"thump":
			base_frequency = 180.0 * pitch
			noise_mix = 0.2
		"ping":
			base_frequency = 1320.0 * pitch
			noise_mix = 0.04
		"crackle":
			base_frequency = 520.0 * pitch
			noise_mix = 0.5
		"boom":
			base_frequency = 110.0 * pitch
			noise_mix = 0.42
		"chime":
			base_frequency = 1480.0 * pitch
			noise_mix = 0.03
		"squelch":
			base_frequency = 240.0 * pitch
			noise_mix = 0.36
		"beam":
			base_frequency = 1820.0 * pitch
			noise_mix = 0.05
		"slash":
			base_frequency = 620.0 * pitch
			noise_mix = 0.42
		"zap":
			base_frequency = 2240.0 * pitch
			noise_mix = 0.2
		"burn":
			base_frequency = 190.0 * pitch
			noise_mix = 0.62
	for index in range(sample_count):
		var t := float(index) / MIX_RATE
		var progress := t / duration
		var attack := clampf(t / 0.007, 0.0, 1.0)
		var env := attack * exp(-t * (34.0 - weight * 4.0))
		var sweep := base_frequency * (1.0 + progress * 0.22)
		if profile == "thump" or profile == "boom" or profile == "squelch" or profile == "slash" or profile == "burn":
			sweep = base_frequency * (1.0 - progress * 0.35)
		elif profile == "zap":
			sweep = base_frequency * (1.0 + _rng.randf_range(-0.22, 0.28))
		var sample := (
			sin(TAU * sweep * t) * 0.42
			+ sin(TAU * sweep * 1.015 * t) * 0.14
			+ sin(TAU * sweep * 0.5 * t) * 0.2
			+ sin(TAU * sweep * 2.0 * t) * 0.08
			+ _rng.randf_range(-1.0, 1.0) * noise_mix
		) * env * (0.25 + weight * 0.06)
		frames[index] = Vector2(sample, sample)
	return frames

func _build_explosion_frames(weight: float, profile: String) -> PackedVector2Array:
	var duration := 0.22 + weight * 0.06
	if profile == "boss":
		duration += 0.08
	var sample_count := int(MIX_RATE * duration)
	var frames := PackedVector2Array()
	frames.resize(sample_count)
	var pitch := _pitch_variation()
	for index in range(sample_count):
		var t := float(index) / MIX_RATE
		var progress := t / duration
		var env := exp(-t * (10.5 - weight * 1.2))
		var rumble := sin(TAU * (58.0 - weight * 6.0) * pitch * t) * (0.42 + weight * 0.08)
		var body := sin(TAU * (180.0 - t * (320.0 + weight * 36.0)) * pitch * t) * 0.2
		var noise := _rng.randf_range(-1.0, 1.0) * (0.48 + weight * 0.09)
		if profile == "mine":
			body += sin(TAU * 96.0 * t) * 0.18
		elif profile == "boss":
			rumble += sin(TAU * lerpf(42.0, 30.0, progress) * t) * 0.36
			body += sin(TAU * lerpf(280.0, 74.0, progress) * t) * 0.28
		elif profile != "shockwave":
			body += sin(TAU * lerpf(620.0, 220.0, progress) * pitch * t) * 0.18
		var sample := (rumble + body + noise) * env * (0.56 + weight * 0.08)
		frames[index] = Vector2(sample, sample)
	return frames

func _build_dash_frames(weight: float) -> PackedVector2Array:
	var duration := 0.12 + weight * 0.03
	var sample_count := int(MIX_RATE * duration)
	var frames := PackedVector2Array()
	frames.resize(sample_count)
	var pitch := _pitch_variation()
	for index in range(sample_count):
		var t := float(index) / MIX_RATE
		var progress := t / duration
		var env := exp(-t * (18.0 - weight * 2.0))
		var sweep := lerpf(220.0, 1640.0, progress) * pitch
		var sample := (
			sin(TAU * sweep * t) * (0.28 + weight * 0.08)
			+ sin(TAU * sweep * 1.5 * t) * 0.1
			+ _rng.randf_range(-1.0, 1.0) * 0.18
		) * env
		frames[index] = Vector2(sample, sample)
	return frames

func _build_damage_frames() -> PackedVector2Array:
	var duration := 0.12
	var sample_count := int(MIX_RATE * duration)
	var frames := PackedVector2Array()
	frames.resize(sample_count)
	var pitch := _pitch_variation()
	for index in range(sample_count):
		var t := float(index) / MIX_RATE
		var env := exp(-t * 18.0)
		var frequency := lerpf(220.0, 110.0, t / duration) * pitch
		var pulse: float = 1.0 if sin(TAU * frequency * t) >= 0.0 else -1.0
		var sample: float = pulse * env * 0.24 + sin(TAU * frequency * 0.5 * t) * env * 0.1 + _rng.randf_range(-1.0, 1.0) * env * 0.08
		frames[index] = Vector2(sample, sample)
	return frames

func _build_enemy_death_frames(weight: float) -> PackedVector2Array:
	var duration := 0.08 + weight * 0.03
	var sample_count := int(MIX_RATE * duration)
	var frames := PackedVector2Array()
	frames.resize(sample_count)
	var pitch := _pitch_variation()
	for index in range(sample_count):
		var t := float(index) / MIX_RATE
		var env := exp(-t * (26.0 - weight * 2.5))
		var frequency := lerpf(340.0, 90.0, t / duration) * pitch
		var sample := (
			sin(TAU * frequency * t)
			+ sin(TAU * (frequency * 0.42) * t) * 0.24
			+ sin(TAU * (frequency * 1.85) * t) * 0.12
			+ _rng.randf_range(-1.0, 1.0) * 0.24
		) * env * (0.34 + weight * 0.08)
		frames[index] = Vector2(sample, sample)
	return frames

func _build_ui_click_frames() -> PackedVector2Array:
	var duration := 0.05
	var sample_count := int(MIX_RATE * duration)
	var frames := PackedVector2Array()
	frames.resize(sample_count)
	var pitch := _pitch_variation()
	for index in range(sample_count):
		var t := float(index) / MIX_RATE
		var env := exp(-t * 45.0)
		var sample := (sin(TAU * 900.0 * pitch * t) * 0.35 + sin(TAU * 1300.0 * pitch * t) * 0.18) * env
		frames[index] = Vector2(sample, sample)
	return frames

func _build_room_clear_frames() -> PackedVector2Array:
	var duration := 0.22
	var sample_count := int(MIX_RATE * duration)
	var frames := PackedVector2Array()
	frames.resize(sample_count)
	var pitch := _pitch_variation()
	for index in range(sample_count):
		var t := float(index) / MIX_RATE
		var progress := t / duration
		var env := exp(-t * 8.0)
		var frequency := lerpf(420.0, 880.0, progress) * pitch
		var sample := (sin(TAU * frequency * t) + sin(TAU * frequency * 1.5 * t) * 0.35 + sin(TAU * frequency * 2.0 * t) * 0.14) * env * 0.34
		frames[index] = Vector2(sample, sample)
	return frames

func _build_level_up_frames() -> PackedVector2Array:
	var duration := 0.38
	var sample_count := int(MIX_RATE * duration)
	var frames := PackedVector2Array()
	frames.resize(sample_count)
	var pitch := _pitch_variation()
	for index in range(sample_count):
		var t := float(index) / MIX_RATE
		var progress := t / duration
		var env := sin(progress * PI) * exp(-t * 1.8)
		var root := lerpf(220.0, 440.0, progress) * pitch
		var fifth := root * 1.5
		var octave := root * 2.0
		var bass := sin(TAU * 72.0 * t) * exp(-t * 5.0) * 0.34
		var sparkle := sin(TAU * octave * t) * 0.18 + sin(TAU * fifth * t) * 0.22
		var sample := (bass + sparkle + sin(TAU * root * t) * 0.28) * env * 0.62
		frames[index] = Vector2(sample, sample)
	return frames

func _build_pickup_frames(weight: float) -> PackedVector2Array:
	var duration := 0.13 + weight * 0.02
	var sample_count := int(MIX_RATE * duration)
	var frames := PackedVector2Array()
	frames.resize(sample_count)
	var pitch := _pitch_variation()
	for index in range(sample_count):
		var t := float(index) / MIX_RATE
		var progress := t / duration
		var env := sin(progress * PI) * exp(-t * 4.0)
		var root := lerpf(720.0, 1180.0, progress) * pitch
		var sparkle := sin(TAU * root * 2.0 * t) * 0.14 + _rng.randf_range(-1.0, 1.0) * 0.06
		var sample := (sin(TAU * root * t) * 0.32 + sin(TAU * root * 1.25 * t) * 0.18 + sparkle) * env * (0.42 + weight * 0.08)
		frames[index] = Vector2(sample, sample)
	return frames
