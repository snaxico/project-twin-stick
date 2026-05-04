class_name PlayerConfig
extends RefCounted

enum AimMode {
	HEAVY_AUTO,
	FULL_AUTO,
	MANUAL,
}

var player_id: int = 1
var control_source: String = "hybrid"
var tint: Color = Color(0.341176, 0.862745, 0.807843, 1.0)
var aim_mode: AimMode = AimMode.HEAVY_AUTO

func _init(
	initial_player_id: int = 1,
	initial_control_source: String = "hybrid",
	initial_tint: Color = Color(0.341176, 0.862745, 0.807843, 1.0),
	initial_aim_mode: AimMode = AimMode.HEAVY_AUTO
) -> void:
	player_id = initial_player_id
	control_source = initial_control_source
	tint = initial_tint
	aim_mode = initial_aim_mode

func cycle_aim_mode() -> void:
	aim_mode = wrapi(aim_mode + 1, AimMode.HEAVY_AUTO, AimMode.MANUAL + 1)

func get_aim_mode_name() -> String:
	match aim_mode:
		AimMode.HEAVY_AUTO:
			return "Heavy Auto"
		AimMode.FULL_AUTO:
			return "Full Auto"
		AimMode.MANUAL:
			return "Manual"
		_:
			return "Unknown"

func uses_keyboard() -> bool:
	return control_source == "keyboard" or control_source == "hybrid"

func uses_gamepad() -> bool:
	return control_source == "gamepad" or control_source == "hybrid"

func get_control_source_name() -> String:
	match control_source:
		"keyboard":
			return "Keyboard"
		"gamepad":
			return "Gamepad"
		"hybrid":
			return "Hybrid"
		_:
			return "Unknown"
