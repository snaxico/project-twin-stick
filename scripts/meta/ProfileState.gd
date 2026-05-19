extends Node

const SAVE_PATH := "user://profile_state.save"

var screen_effect_level: String = "full"

func _ready() -> void:
	load_profile()

func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save_profile()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	screen_effect_level = "full"

func save_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"screen_effect_level": screen_effect_level,
	}, "\t"))

func reset_profile() -> void:
	screen_effect_level = "full"
	save_profile()

func get_screen_effect_level() -> String:
	return "full"

func set_screen_effect_level(_level: String) -> void:
	screen_effect_level = "full"
	save_profile()

func _sanitize_screen_effect_level(_level: String) -> String:
	return "full"
