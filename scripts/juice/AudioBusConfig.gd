extends RefCounted

const MASTER_BUS := "Master"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const DEFAULT_MASTER_VOLUME := 1.0
const DEFAULT_MUSIC_VOLUME := 0.65
const DEFAULT_SFX_VOLUME := 0.8

static func ensure_audio_buses() -> void:
	_ensure_bus(MUSIC_BUS, MASTER_BUS)
	_ensure_bus(SFX_BUS, MASTER_BUS)
	_ensure_sfx_effects()

static func set_bus_volume(bus_name: String, linear_volume: float) -> void:
	ensure_audio_buses()
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var clamped := clampf(linear_volume, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, clamped <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(clamped, 0.001)))

static func get_bus_volume(bus_name: String, fallback: float = 1.0) -> float:
	ensure_audio_buses()
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return fallback
	if AudioServer.is_bus_mute(bus_index):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(bus_index)), 0.0, 1.0)

static func _ensure_bus(bus_name: String, send_bus: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var bus_index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, send_bus)

static func _ensure_sfx_effects() -> void:
	var bus_index := AudioServer.get_bus_index(SFX_BUS)
	if bus_index < 0:
		return
	if AudioServer.get_bus_effect_count(bus_index) > 0:
		return
	var low_pass := AudioEffectLowPassFilter.new()
	low_pass.cutoff_hz = 5200.0
	low_pass.resonance = 0.18
	AudioServer.add_bus_effect(bus_index, low_pass)
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -2.0
	limiter.threshold_db = -4.5
	limiter.soft_clip_db = 1.2
	AudioServer.add_bus_effect(bus_index, limiter)
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.32
	reverb.wet = 0.08
	reverb.dry = 0.92
	reverb.damping = 0.65
	AudioServer.add_bus_effect(bus_index, reverb)
