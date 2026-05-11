extends Control

const GAME_WORLD_SCENE = preload("res://scenes/game/GameWorld.tscn")
const TRANSITION_WIPE_SHADER_CODE := """
shader_type canvas_item;

uniform float cutoff : hint_range(-0.3, 1.3) = -0.25;

void fragment() {
	float edge = smoothstep(cutoff - 0.18, cutoff, UV.x);
	COLOR = vec4(0.0, 0.0, 0.0, edge);
}
"""
const MAP_BUTTON_SIZE := Vector2(96.0, 60.0)
const MAP_BUTTON_MIN_SIZE := Vector2(72.0, 46.0)
const MAP_HORIZONTAL_PADDING := 52.0
const MAP_VERTICAL_PADDING := 34.0

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
@onready var run_summary_title_label: Label = $RunSummaryPanel/MarginContainer/SummaryLayout/SummaryTitle
@onready var run_summary_detail_label: Label = $RunSummaryPanel/MarginContainer/SummaryLayout/SummaryDetail
@onready var run_summary_unlocks_label: Label = $RunSummaryPanel/MarginContainer/SummaryLayout/SummaryUnlocks
@onready var run_summary_button: Button = $RunSummaryPanel/MarginContainer/SummaryLayout/SummaryButton
@onready var game_container: Control = $GameContainer

var _active_game = null
var _post_resolution_action: String = "next"
var _open_meta_menu_on_return: bool = false
var _panel_base_positions: Dictionary = {}
var _transition_overlay: ColorRect = null
var _transition_material: ShaderMaterial = null
var _map_buttons: Dictionary = {}
var _map_hover_node_id: String = ""
var _map_button_size: Vector2 = MAP_BUTTON_SIZE

func _get_sfx_engine():
	return get_tree().get_first_node_in_group("sfx_engine")

func _ready() -> void:
	_build_transition_overlay()
	resolution_button.pressed.connect(_on_resolution_button_pressed)
	run_summary_button.pressed.connect(_on_run_summary_button_pressed)
	map_graph_area.resized.connect(_on_map_graph_area_resized)
	_register_button_animations()
	_configure_menu_focus()
	_show_map()

func _unhandled_input(event: InputEvent) -> void:
	if not map_panel.visible or _active_game != null:
		return
	if _handle_map_navigation(event):
		get_viewport().set_input_as_handled()

func _show_map() -> void:
	Engine.time_scale = 1.0
	_play_transition_wipe()
	if RunState.is_run_complete():
		_show_resolution("Run Victory", RunState.get_run_summary_text(), "Return to Menu")
		_post_resolution_action = "return_to_menu"
		return

	map_panel.visible = true
	_set_panel_state(map_panel, true)
	_set_panel_state(resolution_panel, false)
	_set_panel_state(run_summary_panel, false)
	_clear_active_game()

	var map_rows: Array = RunState.get_map_rows()
	if RunState.is_debug_single_room_mode():
		map_title_label.text = "Debug Room Setup"
		map_status_label.text = "%s. Launch the configured room again or return to the main menu." % RunState.get_gold_summary_text(true)
	else:
		var current_floor: int = min(RunState.current_step_index + 1, max(map_rows.size(), 1))
		map_title_label.text = "Choose Route"
		map_status_label.text = "Floor %d of %d. %s." % [current_floor, map_rows.size(), RunState.get_gold_summary_text(true)]

	map_detail_title_label.text = "Path Preview"
	map_detail_body_label.text = "Focus a node to inspect its room, modifier, reward, and route state."
	call_deferred("_refresh_map_panel")

func _refresh_map_panel() -> void:
	_rebuild_map_graph()
	_focus_map_panel()

func _rebuild_map_graph() -> void:
	_clear_map_graph()
	_map_buttons = {}
	var map_rows: Array = RunState.get_map_rows()
	if map_rows.is_empty():
		return
	_map_button_size = _get_map_button_size(map_rows.size())

	var node_positions: Dictionary = {}
	for row in map_rows:
		for node in row:
			if not (node is Dictionary):
				continue
			node_positions[str(node.get("id", ""))] = _get_node_graph_position(node, map_rows.size())

	for row in map_rows:
		for node in row:
			if not (node is Dictionary):
				continue
			var from_id := str(node.get("id", ""))
			var from_position: Vector2 = node_positions.get(from_id, Vector2.ZERO)
			for next_node_id in node.get("next_node_ids", []):
				var to_id := str(next_node_id)
				if not node_positions.has(to_id):
					continue
				_add_connection_line(from_position, node_positions[to_id], _get_connection_color(from_id, to_id))

	var default_focus_id := ""
	var reachable_ids: Array = RunState.get_reachable_node_ids()
	for row in map_rows:
		for node in row:
			if not (node is Dictionary):
				continue
			var node_id := str(node.get("id", ""))
			var button := _build_map_button(node, node_positions[node_id], reachable_ids.has(node_id))
			map_button_layer.add_child(button)
			_map_buttons[node_id] = button
			if default_focus_id.is_empty() and reachable_ids.has(node_id):
				default_focus_id = node_id

	_wire_reachable_focus()
	if not _map_hover_node_id.is_empty() and _map_buttons.has(_map_hover_node_id):
		_show_node_details(_map_hover_node_id)
	elif not default_focus_id.is_empty():
		_show_node_details(default_focus_id)

func _clear_map_graph() -> void:
	for child in map_line_layer.get_children():
		child.queue_free()
	for child in map_button_layer.get_children():
		child.queue_free()

func _get_node_graph_position(node: Dictionary, row_count: int) -> Vector2:
	var width: float = maxf(map_graph_area.size.x, MAP_HORIZONTAL_PADDING * 2.0 + _map_button_size.x)
	var height: float = maxf(map_graph_area.size.y, MAP_VERTICAL_PADDING * 2.0 + _map_button_size.y)
	var usable_width: float = maxf(width - MAP_HORIZONTAL_PADDING * 2.0, 1.0)
	var usable_height: float = maxf(height - MAP_VERTICAL_PADDING * 2.0, 1.0)
	var row := int(node.get("row", 0))
	var column := int(node.get("column", 0))
	var x: float = MAP_HORIZONTAL_PADDING if row_count <= 1 else MAP_HORIZONTAL_PADDING + usable_width * float(row) / float(row_count - 1)
	var y: float = MAP_VERTICAL_PADDING + usable_height * float(column) / float(max(RunState.MAP_COLUMN_COUNT - 1, 1))
	return Vector2(x, y)

func _get_map_button_size(row_count: int) -> Vector2:
	var width: float = maxf(map_graph_area.size.x, MAP_HORIZONTAL_PADDING * 2.0 + MAP_BUTTON_MIN_SIZE.x)
	var height: float = maxf(map_graph_area.size.y, MAP_VERTICAL_PADDING * 2.0 + MAP_BUTTON_MIN_SIZE.y)
	var usable_width: float = maxf(width - MAP_HORIZONTAL_PADDING * 2.0, 1.0)
	var usable_height: float = maxf(height - MAP_VERTICAL_PADDING * 2.0, 1.0)
	var row_spacing: float = usable_width if row_count <= 1 else usable_width / float(max(row_count - 1, 1))
	var column_spacing: float = usable_height / float(max(RunState.MAP_COLUMN_COUNT - 1, 1))
	var button_width: float = clampf(row_spacing - 18.0, MAP_BUTTON_MIN_SIZE.x, MAP_BUTTON_SIZE.x)
	var button_height: float = clampf(column_spacing - 14.0, MAP_BUTTON_MIN_SIZE.y, MAP_BUTTON_SIZE.y)
	return Vector2(button_width, button_height)

func _add_connection_line(from_position: Vector2, to_position: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = color
	line.antialiased = true
	line.points = PackedVector2Array([from_position, to_position])
	map_line_layer.add_child(line)

func _build_map_button(node: Dictionary, button_center: Vector2, is_reachable: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = _map_button_size
	button.size = _map_button_size
	button.position = button_center - _map_button_size * 0.5
	button.focus_mode = Control.FOCUS_ALL if is_reachable else Control.FOCUS_NONE
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.text = _build_node_button_text(node)
	button.modulate = _get_node_color(node, is_reachable)
	button.mouse_entered.connect(_on_map_node_hovered.bind(str(node.get("id", ""))))
	button.focus_entered.connect(_on_map_node_hovered.bind(str(node.get("id", ""))))
	button.pressed.connect(_on_map_node_pressed.bind(str(node.get("id", ""))))
	_register_button_animation(button)
	return button

func _build_node_button_text(node: Dictionary) -> String:
	var room_type := str(node.get("room_type", "combat"))
	match room_type:
		"combat":
			return "Fight\n+%d Gold" % int(node.get("currency_reward", 0))
		"elite":
			return "Elite\n+%d Gold" % int(node.get("currency_reward", 0))
		"rest":
			return "Rest\nRecover"
		"shop":
			return "Shop\nSpend Gold"
		"boss":
			return "Boss\nFinish Run"
		_:
			return "Room"

func _get_node_color(node: Dictionary, is_reachable: bool) -> Color:
	var node_id := str(node.get("id", ""))
	var room_type := str(node.get("room_type", "combat"))
	if node_id == RunState.current_node_id:
		return Color(1.0, 0.84, 0.32, 1.0)
	if room_type == "boss":
		return Color(0.86, 0.22, 0.26, 1.0) if is_reachable else Color(0.42, 0.16, 0.18, 0.92)
	if is_reachable:
		return Color(0.92, 0.94, 1.0, 1.0)
	if RunState.visited_node_ids.has(node_id):
		return Color(0.48, 0.58, 0.68, 0.96)
	return Color(0.22, 0.25, 0.3, 0.94)

func _get_connection_color(from_id: String, to_id: String) -> Color:
	if RunState.get_reachable_node_ids().has(to_id):
		return Color(0.95, 0.92, 0.72, 0.8)
	if RunState.visited_node_ids.has(from_id) or from_id == RunState.current_node_id:
		return Color(0.62, 0.72, 0.82, 0.6)
	return Color(0.24, 0.28, 0.34, 0.65)

func _wire_reachable_focus() -> void:
	var reachable_buttons: Array = []
	for node_id in RunState.get_reachable_node_ids():
		if not _map_buttons.has(node_id):
			continue
		var button: Button = _map_buttons[node_id]
		var node: Dictionary = RunState.get_map_node(str(node_id))
		reachable_buttons.append({
			"button": button,
			"column": int(node.get("column", 0)),
		})
	reachable_buttons.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("column", 0)) < int(b.get("column", 0))
	)
	for index in range(reachable_buttons.size()):
		var button: Button = reachable_buttons[index]["button"]
		button.focus_neighbor_top = button.get_path()
		button.focus_neighbor_bottom = button.get_path()
		button.focus_neighbor_left = button.get_path()
		button.focus_neighbor_right = button.get_path()
		if index > 0:
			var previous_path: NodePath = (reachable_buttons[index - 1]["button"] as Button).get_path()
			button.focus_neighbor_top = previous_path
			button.focus_neighbor_left = previous_path
		if index < reachable_buttons.size() - 1:
			var next_path: NodePath = (reachable_buttons[index + 1]["button"] as Button).get_path()
			button.focus_neighbor_bottom = next_path
			button.focus_neighbor_right = next_path

func _handle_map_navigation(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	var direction: int = 0
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		direction = -1
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		direction = 1
	if direction == 0:
		return false

	var ordered_ids: Array = _get_reachable_node_ids_in_focus_order()
	if ordered_ids.is_empty():
		return false

	var focused_control := get_viewport().gui_get_focus_owner()
	var focused_button := focused_control as Button
	if focused_button == null:
		(_map_buttons[ordered_ids[0]] as Button).grab_focus()
		_show_node_details(str(ordered_ids[0]))
		return true

	var current_index: int = -1
	for index in range(ordered_ids.size()):
		if _map_buttons.get(ordered_ids[index], null) == focused_button:
			current_index = index
			break
	if current_index == -1:
		(_map_buttons[ordered_ids[0]] as Button).grab_focus()
		_show_node_details(str(ordered_ids[0]))
		return true

	var target_index: int = clampi(current_index + direction, 0, ordered_ids.size() - 1)
	if target_index == current_index:
		return true
	var target_id: String = str(ordered_ids[target_index])
	(_map_buttons[target_id] as Button).grab_focus()
	_show_node_details(target_id)
	return true

func _get_reachable_node_ids_in_focus_order() -> Array:
	var entries: Array = []
	for node_id in RunState.get_reachable_node_ids():
		var node: Dictionary = RunState.get_map_node(str(node_id))
		if node.is_empty() or not _map_buttons.has(node_id):
			continue
		entries.append({
			"id": str(node_id),
			"column": int(node.get("column", 0)),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("column", 0)) < int(b.get("column", 0))
	)
	var ordered_ids: Array = []
	for entry in entries:
		ordered_ids.append(str(entry.get("id", "")))
	return ordered_ids

func _show_node_details(node_id: String) -> void:
	var node: Dictionary = RunState.get_map_node(node_id)
	if node.is_empty():
		return
	_map_hover_node_id = node_id
	var state_text := "Locked"
	if RunState.get_reachable_node_ids().has(node_id):
		state_text = "Reachable"
	elif node_id == RunState.current_node_id:
		state_text = "Current Route"
	elif RunState.visited_node_ids.has(node_id):
		state_text = "Visited"
	map_detail_title_label.text = "%s (%s)" % [str(node.get("title", "Room")), state_text]
	var detail_lines: Array = []
	detail_lines.append("Type: %s" % _format_room_type(str(node.get("room_type", "combat"))))
	if node.has("room_objective"):
		detail_lines.append("Objective: %s" % _format_objective(str(node.get("room_objective", "survive"))))
	var modifier_data = node.get("modifier", {})
	if modifier_data is Dictionary and not modifier_data.is_empty():
		detail_lines.append("Modifier: %s" % str(modifier_data.get("name", "Unknown")))
	else:
		detail_lines.append("Modifier: None")
	detail_lines.append("Reward: %s" % str(node.get("reward_label", "No reward")))
	detail_lines.append(str(node.get("description", "")))
	map_detail_body_label.text = "\n".join(detail_lines)

func _format_room_type(room_type: String) -> String:
	match room_type:
		"combat":
			return "Combat"
		"elite":
			return "Elite"
		"rest":
			return "Rest"
		"shop":
			return "Shop"
		"boss":
			return "Boss"
		_:
			return room_type.capitalize()

func _format_objective(objective: String) -> String:
	match objective:
		"capture_the_hill":
			return "Capture The Hill"
		"destroy_generators":
			return "Destroy Generators"
		_:
			return "Survive"

func _on_map_node_hovered(node_id: String) -> void:
	_show_node_details(node_id)

func _on_map_node_pressed(node_id: String) -> void:
	if not RunState.select_map_node(node_id):
		return
	_play_ui_click()
	var node: Dictionary = RunState.get_map_node(node_id)
	match str(node.get("room_type", "combat")):
		"combat", "elite", "boss", "shop":
			_launch_room(node)
		_:
			var outcome: Dictionary = RunState.resolve_current_noncombat_node()
			_show_outcome(outcome)

func _launch_room(node: Dictionary) -> void:
	Engine.time_scale = 1.0
	_play_transition_wipe()
	map_panel.visible = false
	_set_panel_state(map_panel, false)
	_set_panel_state(resolution_panel, false)
	_clear_active_game()

	_active_game = GAME_WORLD_SCENE.instantiate()
	_active_game.configure_players(RunState.player_configs)
	_active_game.configure_room(node)
	game_container.add_child(_active_game)
	_active_game.room_cleared.connect(_on_room_cleared)
	_active_game.all_players_dead.connect(_on_room_failed)

func _on_room_cleared(health_states: Array, clear_context: Dictionary = {}) -> void:
	var outcome: Dictionary = RunState.resolve_current_combat_victory(health_states, clear_context)
	if str(outcome.get("post_action", "")) == "return_to_menu":
		var meta_reward := ProfileState.award_run_meta_gold(RunState.run_outcome, RunState.rooms_completed)
		_show_run_summary(outcome, meta_reward, true)
		return
	_show_outcome(outcome)

func _on_room_failed() -> void:
	if RunState.is_debug_single_room_mode():
		_post_resolution_action = "complete"
		_show_resolution("Debug Room Failed", "The party was defeated.\n%s" % RunState.get_gold_summary_text(), "Return to Debug Map")
		return
	RunState.run_outcome = "failed"
	var meta_reward := ProfileState.award_run_meta_gold(RunState.run_outcome, RunState.rooms_completed)
	var outcome := {
		"title": "Run Failed",
		"summary": "The party was defeated.\n%s" % RunState.get_run_summary_text(),
	}
	_show_run_summary(outcome, meta_reward, false)

func _show_resolution(title: String, detail: String, button_text: String) -> void:
	Engine.time_scale = 1.0
	_play_transition_wipe()
	map_panel.visible = false
	_set_panel_state(map_panel, false)
	_set_panel_state(resolution_panel, true)
	_set_panel_state(run_summary_panel, false)
	_clear_active_game()
	resolution_title_label.text = title
	resolution_detail_label.text = detail
	resolution_button.text = button_text
	call_deferred("_focus_resolution_panel")

func _on_resolution_button_pressed() -> void:
	_play_ui_click()

	match _post_resolution_action:
		"return_to_menu":
			return_to_menu_requested.emit(_open_meta_menu_on_return)
		"complete":
			_show_map()
		_:
			_show_map()

func _clear_active_game() -> void:
	Engine.time_scale = 1.0
	if _active_game != null and is_instance_valid(_active_game):
		_active_game.queue_free()
	_active_game = null

func _show_outcome(outcome: Dictionary) -> void:
	_open_meta_menu_on_return = false
	_post_resolution_action = str(outcome.get("post_action", "next"))
	_show_resolution(
		str(outcome.get("title", "Result")),
		str(outcome.get("summary", "")),
		str(outcome.get("button_text", "Continue"))
	)

func _show_run_summary(outcome: Dictionary, meta_reward: Dictionary, did_win: bool) -> void:
	Engine.time_scale = 1.0
	_play_transition_wipe()
	_set_panel_state(map_panel, false)
	_set_panel_state(resolution_panel, false)
	_set_panel_state(run_summary_panel, true)
	_clear_active_game()
	_post_resolution_action = "return_to_menu"
	_open_meta_menu_on_return = true

	var summary_title := "Run Victory" if did_win else "Run Failed"
	run_summary_title_label.text = summary_title
	run_summary_detail_label.text = "%s\n\n%s" % [
		str(outcome.get("summary", "")),
		str(meta_reward.get("summary", "")),
	]

	var unlock_names: Array = meta_reward.get("newly_affordable_unlock_names", [])
	var unlock_text := ""
	if unlock_names.is_empty():
		var affordable_count := int(meta_reward.get("affordable_unlock_count", 0))
		unlock_text = "No new unlocks became affordable this run."
		if affordable_count > 0:
			unlock_text = "%s\nAffordable unlocks waiting in meta menu: %d" % [unlock_text, affordable_count]
	else:
		unlock_text = "Newly available unlocks:\n- %s" % "\n- ".join(unlock_names)
	run_summary_unlocks_label.text = unlock_text
	run_summary_button.text = "Open Meta Menu"
	call_deferred("_focus_summary_panel")

func _on_run_summary_button_pressed() -> void:
	_play_ui_click()
	return_to_menu_requested.emit(true)

func _play_ui_click() -> void:
	var sfx_engine = _get_sfx_engine()
	if sfx_engine != null:
		sfx_engine.play_ui_click()

func _register_button_animations() -> void:
	var controls: Array = [
		resolution_button,
		run_summary_button,
	]
	for control in controls:
		_register_button_animation(control)

func _configure_menu_focus() -> void:
	var controls: Array = [
		resolution_button,
		run_summary_button,
	]
	for control in controls:
		if control == null:
			continue
		control.focus_mode = Control.FOCUS_ALL

func _focus_map_panel() -> void:
	var reachable_ids: Array = RunState.get_reachable_node_ids()
	for node_id in reachable_ids:
		if _map_buttons.has(node_id):
			(_map_buttons[node_id] as Button).grab_focus()
			return

func _focus_resolution_panel() -> void:
	resolution_button.grab_focus()

func _focus_summary_panel() -> void:
	run_summary_button.grab_focus()

func _register_button_animation(control: Control) -> void:
	if control == null:
		return
	control.pivot_offset = control.size * 0.5
	control.mouse_entered.connect(_on_button_hovered.bind(control))
	control.mouse_exited.connect(_on_button_unhovered.bind(control))
	var button := control as BaseButton
	if button != null:
		button.button_down.connect(_on_button_pressed.bind(control))
		button.button_up.connect(_on_button_released.bind(control))

func _on_button_hovered(control: Control) -> void:
	_animate_button_scale(control, Vector2.ONE * 1.04, 0.12)

func _on_button_unhovered(control: Control) -> void:
	_animate_button_scale(control, Vector2.ONE, 0.12)

func _on_button_pressed(control: Control) -> void:
	_animate_button_scale(control, Vector2.ONE * 0.97, 0.06)

func _on_button_released(control: Control) -> void:
	_animate_button_scale(control, Vector2.ONE * 1.03, 0.08)

func _animate_button_scale(control: Control, target_scale: Vector2, duration: float) -> void:
	if control == null:
		return
	var tween := create_tween()
	tween.tween_property(control, "scale", target_scale, duration)

func _set_panel_state(panel: Control, should_show: bool) -> void:
	if panel == null:
		return
	if not _panel_base_positions.has(panel):
		_panel_base_positions[panel] = panel.position
	var base_position: Vector2 = _panel_base_positions[panel]
	if should_show:
		panel.visible = true
		panel.position = base_position + Vector2(0.0, 16.0)
		panel.modulate.a = 0.0
		var tween_in := create_tween()
		tween_in.set_parallel(true)
		tween_in.tween_property(panel, "position", base_position, 0.18)
		tween_in.tween_property(panel, "modulate:a", 1.0, 0.18)
		return
	if not panel.visible:
		return
	var tween_out := create_tween()
	tween_out.set_parallel(true)
	tween_out.tween_property(panel, "position", base_position + Vector2(0.0, 12.0), 0.14)
	tween_out.tween_property(panel, "modulate:a", 0.0, 0.14)
	tween_out.set_parallel(false)
	tween_out.tween_callback(func() -> void:
		panel.visible = false
		panel.position = base_position
		panel.modulate.a = 1.0
	)

func _build_transition_overlay() -> void:
	_transition_overlay = ColorRect.new()
	_transition_overlay.name = "TransitionOverlay"
	_transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_overlay.visible = false
	_transition_overlay.color = Color.WHITE
	add_child(_transition_overlay)

	_transition_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = TRANSITION_WIPE_SHADER_CODE
	_transition_material.shader = shader
	_transition_material.set_shader_parameter("cutoff", -0.25)
	_transition_overlay.material = _transition_material

func _play_transition_wipe() -> void:
	if _transition_overlay == null or _transition_material == null:
		return
	_transition_overlay.visible = true
	_transition_material.set_shader_parameter("cutoff", -0.25)
	var tween := create_tween()
	tween.tween_property(_transition_material, "shader_parameter/cutoff", 1.25, 0.32)
	tween.tween_callback(func() -> void:
		_transition_overlay.visible = false
	)

func _on_map_graph_area_resized() -> void:
	if map_panel.visible:
		call_deferred("_rebuild_map_graph")
