extends Control

const GAME_WORLD_SCENE = preload("res://scenes/game/GameWorld.tscn")
const MODIFIERS_DATA_PATH := "res://data/modifiers.json"

signal return_to_menu_requested(open_meta_menu: bool)

@onready var next_room_panel: Panel = $NextRoomPanel
@onready var next_room_title_label: Label = $NextRoomPanel/MarginContainer/NextRoomLayout/NextRoomTitle
@onready var next_room_status_label: Label = $NextRoomPanel/MarginContainer/NextRoomLayout/NextRoomStatus
@onready var next_room_card_row: HBoxContainer = $NextRoomPanel/MarginContainer/NextRoomLayout/NextRoomCardRow
@onready var resolution_panel: Panel = $ResolutionPanel
@onready var resolution_title_label: Label = $ResolutionPanel/MarginContainer/ResolutionLayout/ResolutionTitle
@onready var resolution_detail_label: Label = $ResolutionPanel/MarginContainer/ResolutionLayout/ResolutionDetail
@onready var resolution_button: Button = $ResolutionPanel/MarginContainer/ResolutionLayout/ResolutionButton
@onready var resolution_secondary_button: Button = $ResolutionPanel/MarginContainer/ResolutionLayout/ResolutionSecondaryButton
@onready var run_summary_panel: Panel = $RunSummaryPanel
@onready var game_container: Control = $GameContainer

var _active_game = null
var _post_resolution_action: String = "next"
var _secondary_resolution_action: String = ""
var _modifier_definitions: Dictionary = {}

func _ready() -> void:
	_load_modifier_definitions()
	next_room_panel.visible = false
	run_summary_panel.visible = false
	resolution_panel.visible = false
	resolution_button.pressed.connect(_on_resolution_button_pressed)
	resolution_secondary_button.pressed.connect(_on_resolution_secondary_button_pressed)
	if RunState.is_debug_single_room_mode():
		call_deferred("_launch_single_debug_room")
		return
	call_deferred("_show_next_room_choice")

func _show_next_room_choice() -> void:
	_set_music_context("map")
	next_room_panel.visible = true
	resolution_panel.visible = false
	run_summary_panel.visible = false
	_clear_active_game()
	_clear_next_room_cards()
	var options: Array = RunState.get_current_options()
	if options.is_empty():
		_show_resolution("Route Missing", "No next room was available.", "Return to Menu")
		_post_resolution_action = "return_to_menu"
		return
	var xp_progress: Dictionary = RunState.get_xp_progress()
	var room_number := int(options[0].get("depth", RunState.rooms_completed + 1))
	next_room_title_label.text = "Choose Next Room"
	next_room_status_label.text = "Room %d  |  Lv %d  |  XP %d/%d  |  Pending Picks %d" % [
		room_number,
		int(xp_progress.get("level", 0)),
		int(xp_progress.get("current", 0)),
		int(xp_progress.get("needed", 80)),
		int(xp_progress.get("pending", 0)),
	]
	var first_button: Button = null
	for option in options:
		var button := _build_route_card(option as Dictionary)
		next_room_card_row.add_child(button)
		if first_button == null:
			first_button = button
	if first_button != null:
		first_button.call_deferred("grab_focus")

func _clear_next_room_cards() -> void:
	for child in next_room_card_row.get_children():
		child.queue_free()

func _build_route_card(node: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(252.0, 196.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var room_type := str(node.get("room_type", "combat"))
	var tag := "COMBAT"
	if room_type == "boss":
		tag = "CHAMPION: %s" % _format_boss_name(str(node.get("boss_type", "Boss")))
	var modifiers: Array = node.get("modifiers", []) as Array
	var modifier_text := "None" if modifiers.is_empty() else _build_modifier_badge_text(modifiers)
	var enemies: Array = node.get("enemy_pool", []) as Array
	var enemy_text := "Champion" if room_type == "boss" else ", ".join(enemies)
	var side_objective := str(node.get("side_objective", ""))
	var objective_text := "Objective: %s" % _format_modifier_name(side_objective) if not side_objective.is_empty() else "Objective: Clear"
	button.text = "%s\n%s\nRoom %d\n%s\nMods: %s\nEnemies: %s\n%s" % [
		str(node.get("title", "Room")),
		tag,
		int(node.get("depth", 1)),
		objective_text,
		modifier_text,
		enemy_text,
		str(node.get("description", "")),
	]
	button.pressed.connect(_on_next_room_card_pressed.bind(str(node.get("id", ""))))
	return button

func _build_modifier_badge_text(modifiers: Array) -> String:
	var badges: Array = []
	for mod_id_variant in modifiers:
		var mod_id := str(mod_id_variant)
		badges.append(_modifier_abbreviation(mod_id))
	return " ".join(badges)

func _modifier_abbreviation(mod_id: String) -> String:
	match mod_id:
		"accelerating_waves":
			return "AW"
		"enemy_speed":
			return "ES"
		"swarm":
			return "SW"
		"shielded":
			return "SH"
		"explosive_death":
			return "XD"
		"fire_floor":
			return "FF"
		"ice_zone":
			return "IZ"
		"mine_field":
			return "MF"
		"shrinking_arena":
			return "SA"
		_:
			return mod_id.substr(0, mini(mod_id.length(), 2)).to_upper()

func _on_next_room_card_pressed(node_id: String) -> void:
	if not RunState.select_map_node(node_id):
		return
	var node: Dictionary = RunState.get_map_node(node_id)
	match str(node.get("room_type", "combat")):
		"combat", "boss":
			_launch_room(node)
		_:
			_show_outcome(RunState.resolve_current_noncombat_node())

func _launch_room(node: Dictionary) -> void:
	var room_type := str(node.get("room_type", "combat"))
	_set_music_context("boss" if room_type == "boss" else "combat")
	next_room_panel.visible = false
	resolution_panel.visible = false
	_clear_active_game()
	_active_game = GAME_WORLD_SCENE.instantiate()
	_active_game.configure_players(RunState.player_configs)
	_active_game.configure_room(node)
	game_container.add_child(_active_game)
	_active_game.room_cleared.connect(_on_room_cleared)
	_active_game.all_players_dead.connect(_on_room_failed)
	_active_game.return_to_menu_requested.connect(_on_game_return_to_menu_requested)

func _on_room_cleared(health_states: Array, clear_context: Dictionary = {}) -> void:
	var outcome := RunState.resolve_current_combat_victory(health_states, clear_context)
	_show_outcome(outcome)

func _on_room_failed() -> void:
	if RunState.run_outcome != "won":
		RunState.run_outcome = "failed"
	_show_resolution("Run Failed", "The party was defeated.\nReached room %d.\n%s" % [max(RunState.rooms_completed + 1, 1), RunState.get_run_summary_text()], "Return to Menu")
	_post_resolution_action = "return_to_menu"

func _on_game_return_to_menu_requested() -> void:
	_clear_active_game()
	return_to_menu_requested.emit(false)

func _show_outcome(outcome: Dictionary) -> void:
	_post_resolution_action = str(outcome.get("post_action", "next"))
	_show_resolution(str(outcome.get("title", "Result")), str(outcome.get("summary", "")), str(outcome.get("button_text", "Continue")))
	if _post_resolution_action == "win_milestone":
		_secondary_resolution_action = "return_to_menu"
		resolution_secondary_button.text = "End Run"
		resolution_secondary_button.visible = true

func _show_resolution(title: String, detail: String, button_text: String) -> void:
	_set_music_context("map")
	next_room_panel.visible = false
	resolution_panel.visible = true
	run_summary_panel.visible = false
	_clear_active_game()
	resolution_title_label.text = title
	resolution_detail_label.text = detail
	resolution_button.text = button_text
	_secondary_resolution_action = ""
	resolution_secondary_button.visible = false
	call_deferred("_focus_resolution_panel")

func _on_resolution_button_pressed() -> void:
	match _post_resolution_action:
		"return_to_menu":
			return_to_menu_requested.emit(false)
		"win_milestone":
			_show_next_room_choice()
		_:
			_show_next_room_choice()

func _on_resolution_secondary_button_pressed() -> void:
	if _secondary_resolution_action == "return_to_menu":
		return_to_menu_requested.emit(false)

func _launch_single_debug_room() -> void:
	var options: Array = RunState.get_current_options()
	if options.is_empty():
		_show_resolution("Encounter Missing", "No single-room encounter was configured.", "Return to Encounter Builder")
		_post_resolution_action = "return_to_menu"
		return
	var node: Dictionary = options[0]
	if not RunState.select_map_node(str(node.get("id", ""))):
		_show_resolution("Encounter Missing", "The configured encounter could not be selected.", "Return to Encounter Builder")
		_post_resolution_action = "return_to_menu"
		return
	_launch_room(node)

func _clear_active_game() -> void:
	if _active_game != null and is_instance_valid(_active_game):
		_active_game.queue_free()
	_active_game = null

func _set_music_context(context: String) -> void:
	if MusicEngine != null and MusicEngine.has_method("set_context"):
		MusicEngine.set_context(context)

func _format_modifier_name(mod_id: String) -> String:
	if mod_id.is_empty():
		return ""
	var definition := _modifier_definitions.get(mod_id, {}) as Dictionary
	if not definition.is_empty():
		return str(definition.get("name", mod_id))
	var words := mod_id.split("_")
	var parts: Array = []
	for word in words:
		if word.is_empty():
			continue
		parts.append(word.capitalize())
	return " ".join(parts)

func _format_boss_name(boss_type: String) -> String:
	if boss_type.is_empty():
		return "Champion"
	return boss_type.capitalize()

func _load_modifier_definitions() -> void:
	_modifier_definitions.clear()
	if not FileAccess.file_exists(MODIFIERS_DATA_PATH):
		return
	var file := FileAccess.open(MODIFIERS_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	for entry in ((parsed as Dictionary).get("modifiers", []) as Array):
		if not (entry is Dictionary):
			continue
		var definition: Dictionary = (entry as Dictionary).duplicate(true)
		var modifier_id := str(definition.get("id", ""))
		if modifier_id.is_empty():
			continue
		_modifier_definitions[modifier_id] = definition

func _focus_resolution_panel() -> void:
	resolution_button.grab_focus()
