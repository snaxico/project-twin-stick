extends Control

const GAME_WORLD_SCENE = preload("res://scenes/game/GameWorld.tscn")
const MapNodeButtonData = preload("res://scripts/ui/MapNodeButton.gd")
const MODIFIERS_DATA_PATH := "res://data/modifiers.json"

signal return_to_menu_requested(open_meta_menu: bool)

@onready var map_panel: Panel = $MapPanel
@onready var map_title_label: Label = $MapPanel/MarginContainer/MapLayout/MapTitle
@onready var map_status_label: Label = $MapPanel/MarginContainer/MapLayout/MapStatus
@onready var map_graph_area: Control = $MapPanel/MarginContainer/MapLayout/MapGraphFrame/GraphMargin/MapGraphArea
@onready var map_line_layer: Node2D = $MapPanel/MarginContainer/MapLayout/MapGraphFrame/GraphMargin/MapGraphArea/MapLineLayer
@onready var map_button_layer: Control = $MapPanel/MarginContainer/MapLayout/MapGraphFrame/GraphMargin/MapGraphArea/MapButtonLayer
@onready var map_detail_title_label: Label = $MapPanel/MarginContainer/MapLayout/MapDetailPanel/MarginContainer/MapDetailLayout/MapDetailTitle
@onready var map_detail_body_label: Label = $MapPanel/MarginContainer/MapLayout/MapDetailPanel/MarginContainer/MapDetailLayout/MapDetailBody
@onready var resolution_panel: Panel = $ResolutionPanel
@onready var resolution_title_label: Label = $ResolutionPanel/MarginContainer/ResolutionLayout/ResolutionTitle
@onready var resolution_detail_label: Label = $ResolutionPanel/MarginContainer/ResolutionLayout/ResolutionDetail
@onready var resolution_button: Button = $ResolutionPanel/MarginContainer/ResolutionLayout/ResolutionButton
@onready var run_summary_panel: Panel = $RunSummaryPanel
@onready var game_container: Control = $GameContainer

var _active_game = null
var _post_resolution_action: String = "next"
var _map_buttons: Dictionary = {}
var _map_button_size := Vector2(92.0, 88.0)
var _virtual_graph_height := 0.0
var _graph_scroll_offset := 0.0
var _modifier_definitions: Dictionary = {}

func _ready() -> void:
	_load_modifier_definitions()
	run_summary_panel.visible = false
	resolution_button.pressed.connect(_on_resolution_button_pressed)
	map_graph_area.resized.connect(_refresh_map_panel)
	if RunState.is_debug_single_room_mode():
		call_deferred("_launch_single_debug_room")
		return
	if RunState.is_endless_mode():
		call_deferred("_launch_first_endless_room")
		return
	_show_map()

func _show_map() -> void:
	_set_music_context("map")
	if RunState.is_run_complete():
		_show_resolution("Run Victory", RunState.get_run_summary_text(), "Return to Menu")
		_post_resolution_action = "return_to_menu"
		return
	map_panel.visible = true
	resolution_panel.visible = false
	run_summary_panel.visible = false
	_clear_active_game()
	var map_rows: Array = RunState.get_map_rows()
	var current_floor: int = min(RunState.current_step_index + 1, max(map_rows.size(), 1))
	var xp_progress: Dictionary = RunState.get_xp_progress()
	map_title_label.text = "Choose Route"
	map_status_label.text = "Floor %d of %d  |  Lv %d  |  XP %d/%d  |  Pending Picks %d" % [
		current_floor,
		map_rows.size(),
		int(xp_progress.get("level", 0)),
		int(xp_progress.get("current", 0)),
		int(xp_progress.get("needed", 80)),
		int(xp_progress.get("pending", 0)),
	]
	map_detail_title_label.text = "Path Preview"
	map_detail_body_label.text = "Focus a node to inspect its objective and route."
	call_deferred("_refresh_map_panel")

func _refresh_map_panel() -> void:
	_rebuild_map_graph()
	var reachable_ids: Array = RunState.get_reachable_node_ids()
	if not reachable_ids.is_empty() and _map_buttons.has(reachable_ids[0]):
		(_map_buttons[reachable_ids[0]] as Button).grab_focus()

func _rebuild_map_graph() -> void:
	_clear_map_graph()
	_map_buttons.clear()
	var options: Array = RunState.get_current_options()
	if options.is_empty():
		return
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	map_button_layer.add_child(margin)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)
	for option in options:
		var node := option as Dictionary
		var node_id := str(node.get("id", ""))
		var button := _build_route_card(node)
		row.add_child(button)
		_map_buttons[node_id] = button

func _clear_map_graph() -> void:
	for child in map_line_layer.get_children():
		child.queue_free()
	for child in map_button_layer.get_children():
		child.queue_free()

func _get_node_graph_position(node: Dictionary, map_rows: Array) -> Vector2:
	var width: float = maxf(map_graph_area.size.x, 320.0)
	var row := int(node.get("row", 0))
	var margin_x: float = 84.0
	var margin_y: float = 42.0
	var row_spacing: float = 132.0
	var base_y: float = _virtual_graph_height - margin_y - float(row) * row_spacing
	var y: float = base_y - _graph_scroll_offset
	var column_count_in_row: int = _count_columns_in_row(node, map_rows)
	var column_rank: int = _get_column_rank(node, map_rows)
	var x: float = width * 0.5 if column_count_in_row <= 1 else margin_x + (width - margin_x * 2.0) * float(column_rank) / float(max(column_count_in_row - 1, 1))
	if column_count_in_row > 1 and row % 2 == 1:
		x += 18.0 if column_rank % 2 == 0 else -18.0
	return Vector2(x, y)

func _get_virtual_graph_height(map_rows: Array) -> float:
	return maxf(map_graph_area.size.y, 120.0 + float(max(map_rows.size() - 1, 0)) * 132.0)

func _get_graph_scroll_offset(_map_rows: Array, virtual_height: float) -> float:
	var viewport_height := maxf(map_graph_area.size.y, 280.0)
	if virtual_height <= viewport_height:
		return 0.0
	var focus_row := 0
	if not RunState.current_node_id.is_empty():
		focus_row = int(RunState.get_map_node(RunState.current_node_id).get("row", 0))
	else:
		var reachable_ids: Array = RunState.get_reachable_node_ids()
		if not reachable_ids.is_empty():
			focus_row = int(RunState.get_map_node(str(reachable_ids[0])).get("row", 0))
	var row_spacing := 132.0
	var margin_y := 42.0
	var focus_virtual_y := virtual_height - margin_y - float(focus_row) * row_spacing
	var desired_screen_y := viewport_height * 0.72
	return clampf(focus_virtual_y - desired_screen_y, 0.0, virtual_height - viewport_height)

func _count_columns_in_row(node: Dictionary, map_rows: Array) -> int:
	var row_index := int(node.get("row", 0))
	if row_index < 0 or row_index >= map_rows.size():
		return 1
	return max((map_rows[row_index] as Array).size(), 1)

func _get_column_rank(node: Dictionary, map_rows: Array) -> int:
	var row_index := int(node.get("row", 0))
	if row_index < 0 or row_index >= map_rows.size():
		return 0
	var row: Array = map_rows[row_index]
	var node_id := str(node.get("id", ""))
	for index in range(row.size()):
		if str((row[index] as Dictionary).get("id", "")) == node_id:
			return index
	return 0

func _add_connection_line(from_position: Vector2, to_position: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = color
	line.antialiased = true
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var mid_y := lerpf(from_position.y, to_position.y, 0.5)
	line.points = PackedVector2Array([
		from_position,
		Vector2(from_position.x, mid_y),
		Vector2(to_position.x, mid_y),
		to_position,
	])
	map_line_layer.add_child(line)

func _build_map_button(node: Dictionary, button_center: Vector2, is_reachable: bool) -> Button:
	var button := MapNodeButtonData.new()
	button.custom_minimum_size = _map_button_size
	button.size = _map_button_size
	button.position = button_center - _map_button_size * 0.5
	button.focus_mode = Control.FOCUS_ALL if is_reachable else Control.FOCUS_NONE
	button.mouse_entered.connect(_on_map_node_hovered.bind(str(node.get("id", ""))))
	button.focus_entered.connect(_on_map_node_hovered.bind(str(node.get("id", ""))))
	button.pressed.connect(_on_map_node_pressed.bind(str(node.get("id", ""))))
	var modifier_colors: Array = []
	for mod_id_variant in (node.get("modifiers", []) as Array):
		modifier_colors.append(_get_modifier_dot_color(str(mod_id_variant)))
	button.configure(
		node,
		is_reachable,
		RunState.visited_node_ids.has(str(node.get("id", ""))),
		str(node.get("id", "")) == RunState.current_node_id,
		modifier_colors
	)
	return button

func _build_route_card(node: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(220.0, 168.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var room_type := str(node.get("room_type", "combat"))
	var tag := room_type.to_upper()
	if room_type == "boss":
		tag = "BOSS: %s" % str(node.get("boss_type", "Boss")).capitalize()
	elif room_type == "elite":
		tag = "ELITE"
	var modifiers: Array = node.get("modifiers", []) as Array
	var modifier_text := "None" if modifiers.is_empty() else _build_modifier_badge_text(modifiers)
	var enemies: Array = node.get("enemy_pool", []) as Array
	var enemy_text := "Boss" if room_type == "boss" else ", ".join(enemies)
	var side_objective := str(node.get("side_objective", ""))
	var objective_text := "Objective: %s" % _format_modifier_name(side_objective) if not side_objective.is_empty() else "Objective: Clear"
	button.text = "%s\n%s\nAct %d Depth %d\n%s\nMods: %s\nEnemies: %s\n%s" % [
		str(node.get("title", "Room")),
		tag,
		int(node.get("act", 1)),
		int(node.get("depth", 1)),
		objective_text,
		modifier_text,
		enemy_text,
		str(node.get("description", "")),
	]
	button.mouse_entered.connect(_on_map_node_hovered.bind(str(node.get("id", ""))))
	button.focus_entered.connect(_on_map_node_hovered.bind(str(node.get("id", ""))))
	button.pressed.connect(_on_map_node_pressed.bind(str(node.get("id", ""))))
	return button

func _get_modifier_dot_color(mod_id: String) -> Color:
	var minor_ids := ["accelerating_waves", "enemy_speed", "swarm", "shielded", "explosive_death"]
	if minor_ids.has(mod_id):
		return Color(1.0, 0.82, 0.28, 0.92)
	return Color(0.92, 0.28, 0.22, 0.92)

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

func _get_connection_color(from_id: String, to_id: String) -> Color:
	if RunState.get_reachable_node_ids().has(to_id):
		return Color(0.95, 0.92, 0.72, 0.8)
	if RunState.visited_node_ids.has(from_id) or from_id == RunState.current_node_id:
		return Color(0.62, 0.72, 0.82, 0.6)
	return Color(0.24, 0.28, 0.34, 0.65)

func _on_map_node_hovered(node_id: String) -> void:
	var node: Dictionary = RunState.get_map_node(node_id)
	if node.is_empty():
		return
	map_detail_title_label.text = str(node.get("title", "Room"))
	var modifiers: Array = node.get("modifiers", []) as Array
	var mod_names := ""
	if not modifiers.is_empty():
		var names: Array = []
		for mod_id in modifiers:
			names.append(_format_modifier_name(str(mod_id)))
		mod_names = "\nModifiers: %s" % ", ".join(names)
	var boss_text := ""
	if str(node.get("room_type", "combat")) == "boss":
		boss_text = "\nBoss: %s" % str(node.get("boss_type", "")).capitalize()
	map_detail_body_label.text = "Act %d\n%s%s%s" % [
		int(node.get("act", 1)),
		str(node.get("description", "")),
		boss_text,
		mod_names,
	]

func _on_map_node_pressed(node_id: String) -> void:
	if not RunState.select_map_node(node_id):
		return
	var node: Dictionary = RunState.get_map_node(node_id)
	match str(node.get("room_type", "combat")):
		"combat", "elite", "boss":
			_launch_room(node)
		_:
			_show_outcome(RunState.resolve_current_noncombat_node())

func _launch_room(node: Dictionary) -> void:
	var room_type := str(node.get("room_type", "combat"))
	_set_music_context(room_type if room_type == "boss" or room_type == "elite" else "combat")
	map_panel.visible = false
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
	if str(outcome.get("post_action", "")) == "endless_next":
		_launch_endless_room()
		return
	_show_outcome(outcome)

func _on_room_failed() -> void:
	RunState.run_outcome = "failed"
	_show_resolution("Run Failed", "The party was defeated.\n%s" % RunState.get_run_summary_text(), "Return to Menu")
	_post_resolution_action = "return_to_menu"

func _on_game_return_to_menu_requested() -> void:
	_clear_active_game()
	return_to_menu_requested.emit(false)

func _show_outcome(outcome: Dictionary) -> void:
	_post_resolution_action = str(outcome.get("post_action", "next"))
	_show_resolution(str(outcome.get("title", "Result")), str(outcome.get("summary", "")), str(outcome.get("button_text", "Continue")))

func _show_resolution(title: String, detail: String, button_text: String) -> void:
	_set_music_context("map")
	map_panel.visible = false
	resolution_panel.visible = true
	run_summary_panel.visible = false
	_clear_active_game()
	resolution_title_label.text = title
	resolution_detail_label.text = detail
	resolution_button.text = button_text
	call_deferred("_focus_resolution_panel")

func _on_resolution_button_pressed() -> void:
	match _post_resolution_action:
		"return_to_menu":
			return_to_menu_requested.emit(false)
		_:
			_show_map()

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

func _launch_first_endless_room() -> void:
	_launch_endless_room()

func _launch_endless_room() -> void:
	var options: Array = RunState.get_current_options()
	if options.is_empty():
		_show_resolution("Endless Complete", RunState.get_run_summary_text(), "Return to Menu")
		_post_resolution_action = "return_to_menu"
		return
	var node: Dictionary = options[0]
	if not RunState.select_map_node(str(node.get("id", ""))):
		_show_resolution("Endless Error", "The next endless room could not be selected.", "Return to Menu")
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

func _format_objective(_objective: String) -> String:
	return "Kill All"

func _format_modifier_name(mod_id: String) -> String:
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
