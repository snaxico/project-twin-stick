extends Node

const AudioBusConfigData = preload("res://scripts/juice/AudioBusConfig.gd")

const MIX_RATE := 22050.0
const BUFFER_SECONDS := 0.22

var _player: AudioStreamPlayer = null
var _phase_bass := 0.0
var _phase_pulse := 0.0
var _phase_lead := 0.0
var _phase_noise := 0.0
var _target_intensity := 0.0
var _current_intensity := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("music_engine")
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_rng.randomize()
	AudioBusConfigData.ensure_audio_buses()
	_player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = 0.8
	_player.stream = stream
	_player.bus = AudioBusConfigData.MUSIC_BUS
	_player.volume_db = -7.5
	add_child(_player)
	_player.play()
	set_process(true)

func _exit_tree() -> void:
	set_process(false)
	if _player != null and is_instance_valid(_player):
		_player.stop()
		_player.stream = null
	_player = null

func set_context(context: String) -> void:
	match context:
		"boss", "elite":
			_target_intensity = 1.0
		"combat":
			_target_intensity = 0.62
		_:
			_target_intensity = 0.18

func _process(delta: float) -> void:
	_current_intensity = move_toward(_current_intensity, _target_intensity, delta * 0.55)
	if _player == null or not is_instance_valid(_player):
		return
	var playback := _player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frames_available := playback.get_frames_available()
	var target_frames := int(MIX_RATE * BUFFER_SECONDS)
	while frames_available >= target_frames:
		playback.push_buffer(_build_music_frames(target_frames))
		frames_available -= target_frames

func _build_music_frames(sample_count: int) -> PackedVector2Array:
	var frames := PackedVector2Array()
	frames.resize(sample_count)
	var bass_frequency := 55.0
	var pulse_frequency := 110.0
	var lead_frequency := 220.0
	for index in range(sample_count):
		var t := float(index) / MIX_RATE
		var beat_gate := 0.5 + 0.5 * sin(TAU * 2.0 * (_phase_pulse + t))
		beat_gate = pow(maxf(beat_gate, 0.0), 4.0)
		var bass := sin(TAU * bass_frequency * (_phase_bass + t)) * 0.18
		var pulse := sin(TAU * pulse_frequency * (_phase_pulse + t)) * 0.08 * _current_intensity
		var lead := sin(TAU * lead_frequency * (_phase_lead + t)) * 0.04 * maxf(_current_intensity - 0.45, 0.0)
		var air := sin(TAU * 440.0 * (_phase_noise + t)) * 0.012 * _current_intensity
		var sample := (bass + pulse * beat_gate + lead + air) * (0.42 + _current_intensity * 0.35)
		var pan := sin(TAU * 0.07 * (_phase_noise + t)) * 0.12
		frames[index] = Vector2(sample * (1.0 - pan), sample * (1.0 + pan))
	var elapsed := float(sample_count) / MIX_RATE
	_phase_bass = fmod(_phase_bass + elapsed, 1.0)
	_phase_pulse = fmod(_phase_pulse + elapsed, 1.0)
	_phase_lead = fmod(_phase_lead + elapsed, 1.0)
	_phase_noise = fmod(_phase_noise + elapsed, 1.0)
	return frames
