class_name ScreenEffects
extends CanvasLayer

const SCREEN_SHADER_CODE := """
shader_type canvas_item;

uniform float low_health : hint_range(0.0, 1.0) = 0.0;
uniform float combat_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float paper_grain : hint_range(0.0, 1.0) = 0.07;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float dist = length(centered_uv) * 1.4;
	float vignette = smoothstep(0.28, 0.88, dist);
	float pulse = 0.5 + 0.5 * sin(TIME * 6.0);
	float low_health_edge = vignette * low_health * (0.35 + 0.65 * pulse);
	vec3 warm_tint = vec3(0.24, 0.14, 0.04) * combat_intensity * 0.08;
	vec3 danger_tint = vec3(0.72, 0.08, 0.05) * low_health_edge;
	vec2 grain_uv = UV * vec2(1280.0, 720.0) * 0.5;
	float grain_time = floor(TIME * 12.0);
	float noise = hash(grain_uv + vec2(grain_time * 1.3, grain_time * 0.7));
	float grain = (noise - 0.5) * paper_grain;
	float alpha = clamp(combat_intensity * 0.04 + low_health_edge * 0.42 + grain * 0.45, 0.0, 0.52);
	vec3 grain_tint = vec3(grain * 0.28);
	COLOR = vec4(warm_tint + danger_tint + grain_tint, alpha);
}
"""

var _overlay: ColorRect = null
var _material: ShaderMaterial = null
var _target_low_health := 0.0
var _target_combat_intensity := 0.0
var _current_low_health := 0.0
var _current_combat_intensity := 0.0
var _effect_level: String = "off"

func _ready() -> void:
	layer = 20
	_build_overlay()
	set_effect_level("off")

func set_effect_level(level: String) -> void:
	match level:
		"minimal", "full":
			_effect_level = level
		_:
			_effect_level = "off"
	var enabled: bool = _effect_level != "off"
	visible = enabled
	set_process(enabled)
	if _overlay != null:
		_overlay.visible = enabled
	if _material != null:
		_material.set_shader_parameter("paper_grain", 0.03 if _effect_level == "minimal" else 0.07 if _effect_level == "full" else 0.0)
		if not enabled:
			_material.set_shader_parameter("low_health", 0.0)
			_material.set_shader_parameter("combat_intensity", 0.0)
			_current_low_health = 0.0
			_current_combat_intensity = 0.0
			_target_low_health = 0.0
			_target_combat_intensity = 0.0

func set_low_health_ratio(ratio: float) -> void:
	_target_low_health = clamp(1.0 - ratio, 0.0, 1.0)

func set_combat_intensity(intensity: float) -> void:
	_target_combat_intensity = clamp(intensity, 0.0, 1.0)

func _process(delta: float) -> void:
	if _material == null or _effect_level == "off":
		return
	_current_low_health = move_toward(_current_low_health, _target_low_health, delta * 2.0)
	_current_combat_intensity = move_toward(_current_combat_intensity, _target_combat_intensity, delta * 1.5)
	var low_health_strength: float = 0.45 if _effect_level == "minimal" else 1.0
	var combat_strength: float = 0.0 if _effect_level == "minimal" else 1.0
	_material.set_shader_parameter("low_health", _current_low_health * low_health_strength)
	_material.set_shader_parameter("combat_intensity", _current_combat_intensity * combat_strength)

func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color.WHITE
	add_child(_overlay)

	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SCREEN_SHADER_CODE
	_material.shader = shader
	_material.set_shader_parameter("low_health", 0.0)
	_material.set_shader_parameter("combat_intensity", 0.0)
	_material.set_shader_parameter("paper_grain", 0.07)
	_overlay.material = _material
