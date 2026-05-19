class_name PlayerConfig
extends RefCounted

var player_id: int = 1
var control_source: String = "hybrid"
var tint: Color = Color(0.2, 0.9, 1.0, 1.0)

func _init(
	initial_player_id: int = 1,
	initial_control_source: String = "hybrid",
	initial_tint: Color = Color(0.2, 0.9, 1.0, 1.0),
) -> void:
	player_id = initial_player_id
	control_source = initial_control_source
	tint = initial_tint

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
