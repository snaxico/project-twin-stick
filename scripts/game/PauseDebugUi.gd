extends Node

const PauseInputProxyData = preload("res://scripts/ui/PauseInputProxy.gd")
const EncyclopediaUIData = preload("res://scripts/ui/EncyclopediaUI.gd")
const CoopFormat = preload("res://scripts/game/CoopFormat.gd")
const HudPaletteData = preload("res://scripts/game/HudPalette.gd")
const EnemyTypes = preload("res://scripts/game/EnemyTypes.gd")
const IconFactoryData = preload("res://scripts/ui/IconFactory.gd")

const HUD_SLOT_2_COLOR := HudPaletteData.SLOT_2_COLOR
const ABILITY_TRIGGER_LABELS := ["A", "X", "B", "Y"]
const DEBUG_ENEMY_SPAWN_CATALOG := [
	{"label": "Chaser", "value": "chaser"},
	{"label": "Charger", "value": "charger"},
	{"label": "Spitter", "value": "spitter"},
	{"label": "Splitter", "value": "splitter"},
	{"label": "Splitter Mini", "value": "splitter_mini"},
	{"label": "Bomber", "value": "bomber"},
	{"label": "Champion Charger", "value": "elite_charger"},
	{"label": "Champion Spitter", "value": "elite_spitter"},
	{"label": "Champion Support", "value": "elite_support"},
	{"label": "Champion Warden", "value": "boss_warden"},
	{"label": "Champion Hydra", "value": "boss_hydra"},
	{"label": "Champion Hive", "value": "boss_hive"},
	{"label": "Champion Pulsar", "value": "boss_pulsar"},
]

var _coop: Node = null
var _ui_layer: CanvasLayer = null
var _pause_panel: Panel = null
var _resume_button: Button = null
var _pause_retry_button: Button = null
var _pause_main_menu_button: Button = null
var _mutation_system = null
var _ability_registry = null
var _game_paused := false
var _pause_input_proxy = null
var _debug_overlay_panel: PanelContainer = null
var _debug_spawn_option: OptionButton = null
var _debug_weapon_option: OptionButton = null
var _debug_god_check: CheckBox = null


func setup(
	coop: Node,
	ui_layer: CanvasLayer,
	pause_panel: Panel,
	resume_button: Button,
	pause_retry_button: Button,
	pause_main_menu_button: Button,
	mutation_system,
	ability_registry
) -> void:
	_coop = coop
	_ui_layer = ui_layer
	_pause_panel = pause_panel
	_resume_button = resume_button
	_pause_retry_button = pause_retry_button
	_pause_main_menu_button = pause_main_menu_button
	_mutation_system = mutation_system
	_ability_registry = ability_registry


func bind_ui() -> void:
	_resume_button.pressed.connect(_on_resume_pressed)
	_pause_retry_button.pressed.connect(_on_retry_pressed)
	_pause_main_menu_button.pressed.connect(_on_main_menu_pressed)
	_configure_pause_focus()
	_pause_input_proxy = PauseInputProxyData.new()
	_pause_panel.add_child(_pause_input_proxy)
	_pause_input_proxy.pause_pressed.connect(_on_pause_proxy_pressed)


func configure_pause_focus() -> void:
	_configure_pause_focus()


func build_debug_overlay() -> void:
	if not _is_debug_menu_enabled():
		return
	_debug_overlay_panel = PanelContainer.new()
	_debug_overlay_panel.visible = false
	_debug_overlay_panel.position = Vector2(28.0, 136.0)
	_debug_overlay_panel.custom_minimum_size = Vector2(360.0, 0.0)
	_ui_layer.add_child(_debug_overlay_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_debug_overlay_panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	var title := Label.new()
	title.text = "Debug Overlay"
	title.add_theme_font_size_override("font_size", 17)
	layout.add_child(title)
	var spawn_row := HBoxContainer.new()
	spawn_row.add_theme_constant_override("separation", 8)
	layout.add_child(spawn_row)
	_debug_spawn_option = OptionButton.new()
	_debug_spawn_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in DEBUG_ENEMY_SPAWN_CATALOG:
		_debug_spawn_option.add_item(str(entry["label"]))
		_debug_spawn_option.set_item_metadata(_debug_spawn_option.item_count - 1, str(entry["value"]))
	spawn_row.add_child(_debug_spawn_option)
	var spawn_button := Button.new()
	spawn_button.text = "Spawn Selected"
	spawn_button.pressed.connect(_on_debug_spawn_pressed)
	spawn_row.add_child(spawn_button)
	var weapon_row := HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 8)
	layout.add_child(weapon_row)
	_debug_weapon_option = OptionButton.new()
	_debug_weapon_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for weapon in RunState.get_weapon_catalog():
		var weapon_dict: Dictionary = weapon as Dictionary
		var weapon_id := str(weapon_dict.get("id", ""))
		if weapon_id.is_empty():
			continue
		_debug_weapon_option.add_item(str(weapon_dict.get("name", weapon_id.capitalize())))
		_debug_weapon_option.set_item_metadata(_debug_weapon_option.item_count - 1, weapon_id)
	weapon_row.add_child(_debug_weapon_option)
	var set_weapon_button := Button.new()
	set_weapon_button.text = "Set Weapon"
	set_weapon_button.pressed.connect(_on_debug_set_weapon_pressed)
	weapon_row.add_child(set_weapon_button)
	var level_button := Button.new()
	level_button.text = "Give P1 Weapon Level"
	level_button.pressed.connect(_on_debug_give_weapon_level_pressed)
	layout.add_child(level_button)
	var clear_button := Button.new()
	clear_button.text = "Clear Enemies"
	clear_button.pressed.connect(_on_debug_clear_enemies_pressed)
	layout.add_child(clear_button)
	_debug_god_check = CheckBox.new()
	_debug_god_check.text = "God Mode"
	_debug_god_check.button_pressed = RunState.debug_profiling
	_debug_god_check.toggled.connect(_on_debug_god_toggled)
	layout.add_child(_debug_god_check)


func set_game_paused(paused: bool) -> void:
	_game_paused = paused
	_pause_panel.visible = paused
	_coop.call("lock_player_input", paused)
	set_runtime_pause_state(paused)
	get_tree().paused = paused
	if paused:
		_ensure_pause_encyclopedia_button()
		_resume_button.grab_focus()
		populate_pause_build_overlay()


func set_runtime_pause_state(paused: bool) -> void:
	for group in (_coop.call("get_runtime_pause_node_groups") as Array):
		_set_nodes_physics_paused(group as Array, paused)
	for node in (_coop.call("get_runtime_pause_singletons") as Array):
		_set_single_node_physics_paused(node, paused)


func handle_unhandled_input(event: InputEvent) -> bool:
	if _is_debug_menu_enabled() and event.is_action_pressed("debug_overlay_toggle"):
		toggle_debug_overlay()
		return true
	if event.is_action_pressed("pause"):
		if _pause_panel.visible:
			_on_resume_pressed()
		else:
			set_game_paused(true)
		return true
	return false


func is_game_paused() -> bool:
	return _game_paused


func on_pause_proxy_pressed() -> void:
	if _game_paused:
		_on_resume_pressed()


func toggle_debug_overlay() -> void:
	if _debug_overlay_panel == null or not is_instance_valid(_debug_overlay_panel):
		return
	_debug_overlay_panel.visible = not _debug_overlay_panel.visible


func ensure_debug_overlay_action() -> void:
	if not InputMap.has_action("debug_overlay_toggle"):
		InputMap.add_action("debug_overlay_toggle")
	if InputMap.action_get_events("debug_overlay_toggle").is_empty():
		var key_event := InputEventKey.new()
		key_event.keycode = KEY_F4
		key_event.physical_keycode = KEY_F4
		InputMap.action_add_event("debug_overlay_toggle", key_event)


func open_encyclopedia_overlay() -> void:
	var existing := _ui_layer.get_node_or_null("EncyclopediaUI")
	if existing != null:
		existing.queue_free()
	var encyclopedia := EncyclopediaUIData.new()
	encyclopedia.name = "EncyclopediaUI"
	_ui_layer.add_child(encyclopedia)


func populate_pause_build_overlay() -> void:
	var pause_layout := _pause_panel.get_node_or_null("CenterContainer/PauseLayout")
	if pause_layout == null:
		return
	var existing := pause_layout.get_node_or_null("BuildOverlay")
	if existing != null:
		pause_layout.remove_child(existing)
		existing.queue_free()
	var overlay := VBoxContainer.new()
	overlay.name = "BuildOverlay"
	overlay.add_theme_constant_override("separation", 10)
	pause_layout.add_child(overlay)
	var resume := pause_layout.get_node_or_null("ResumeButton")
	if resume != null:
		pause_layout.move_child(overlay, resume.get_index())
	var player_nodes := _coop.call("get_player_target_nodes") as Array
	var player_configs := _coop.call("get_player_configs") as Array
	var compiled_loadouts := _coop.call("get_compiled_loadouts") as Array
	for player_index in range(player_nodes.size()):
		var player = player_nodes[player_index]
		var header := Label.new()
		header.text = "P%d Build" % (player_index + 1)
		header.add_theme_font_size_override("font_size", 15)
		var player_tint: Color = player_configs[player_index].tint
		header.add_theme_color_override("font_color", player_tint.lightened(0.2))
		overlay.add_child(header)
		var loadout: Dictionary = compiled_loadouts[player_index] if player_index < compiled_loadouts.size() else RunState.get_player_runtime_loadout_for(player_index)
		var weapon_stats: Dictionary = loadout.get("weapon_stats", {}) as Dictionary
		var weapon_label := Label.new()
		weapon_label.text = "%s Lv%d - %d dmg @ %.1f/s" % [
			str(loadout.get("weapon_name", "Rifle")),
			int(loadout.get("weapon_level", 1)),
			int(round(float(weapon_stats.get("damage", 16.0)))),
			float(weapon_stats.get("fire_rate", 4.0)),
		]
		weapon_label.add_theme_font_size_override("font_size", 12)
		weapon_label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0, 0.9))
		overlay.add_child(weapon_label)
		var ability_cards := HBoxContainer.new()
		ability_cards.add_theme_constant_override("separation", 8)
		overlay.add_child(ability_cards)
		for slot_index in range(4):
			ability_cards.add_child(_create_build_ability_card(player, player_tint, slot_index))
		var mutations: Array = _mutation_system.get_active_mutations(player_index)
		var counts: Dictionary = {}
		for mutation in mutations:
			var mutation_dict: Dictionary = mutation as Dictionary
			var mutation_id := str(mutation_dict.get("id", ""))
			if mutation_id.is_empty():
				continue
			counts[mutation_id] = {
				"name": str(mutation_dict.get("name", mutation_id)),
				"count": int(counts.get(mutation_id, {}).get("count", 0)) + 1,
				"rarity": str(mutation_dict.get("rarity", "common")),
				"group": str(mutation_dict.get("group", "attribute")),
				"description": str(mutation_dict.get("description", "")),
			}
		if counts.is_empty():
			var empty_label := Label.new()
			empty_label.text = "  No upgrades yet"
			empty_label.add_theme_font_size_override("font_size", 11)
			empty_label.modulate = Color(0.7, 0.78, 0.88, 0.7)
			overlay.add_child(empty_label)
		else:
			var chip_flow := FlowContainer.new()
			chip_flow.add_theme_constant_override("h_separation", 6)
			chip_flow.add_theme_constant_override("v_separation", 4)
			overlay.add_child(chip_flow)
			var sorted_mutations := counts.values()
			sorted_mutations.sort_custom(Callable(self, "_compare_mutation_entries"))
			for entry_variant in sorted_mutations:
				chip_flow.add_child(_create_mutation_chip(entry_variant as Dictionary))
		var stats_line := Label.new()
		var fire_rate := float(player.get_current_fire_rate()) if player.has_method("get_current_fire_rate") else 0.0
		stats_line.text = "Move %d  -  HP %d  -  Fire %.1f/s" % [
			int(round(float(player.move_speed))),
			int(player.max_health),
			fire_rate,
		]
		stats_line.add_theme_font_size_override("font_size", 11)
		stats_line.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0, 0.78))
		overlay.add_child(stats_line)


func _configure_pause_focus() -> void:
	var encyclopedia_button := _pause_panel.get_node_or_null("CenterContainer/PauseLayout/EncyclopediaButton") as Button
	var buttons: Array[Button] = [_resume_button]
	if encyclopedia_button != null:
		buttons.append(encyclopedia_button)
	buttons.append(_pause_retry_button)
	buttons.append(_pause_main_menu_button)
	for index in range(buttons.size()):
		var button := buttons[index] as Button
		button.focus_mode = Control.FOCUS_ALL
		var previous_button := buttons[(index - 1 + buttons.size()) % buttons.size()] as Button
		var next_button := buttons[(index + 1) % buttons.size()] as Button
		button.focus_neighbor_top = button.get_path_to(previous_button)
		button.focus_neighbor_bottom = button.get_path_to(next_button)


func _ensure_pause_encyclopedia_button() -> void:
	var pause_layout := _pause_panel.get_node_or_null("CenterContainer/PauseLayout")
	if pause_layout == null or pause_layout.get_node_or_null("EncyclopediaButton") != null:
		return
	var button := Button.new()
	button.name = "EncyclopediaButton"
	button.text = "Encyclopedia"
	button.pressed.connect(open_encyclopedia_overlay)
	pause_layout.add_child(button)
	var retry_index := _pause_retry_button.get_index() if _pause_retry_button != null else pause_layout.get_child_count() - 1
	pause_layout.move_child(button, retry_index)
	_configure_pause_focus()


func _set_nodes_physics_paused(nodes: Array, paused: bool) -> void:
	for node in nodes:
		_set_single_node_physics_paused(node, paused)


func _set_single_node_physics_paused(node, paused: bool) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.set_process(not paused)
	node.set_physics_process(not paused)


func _on_retry_pressed() -> void:
	set_game_paused(false)
	_coop.call("restart_current_room")


func _on_resume_pressed() -> void:
	set_game_paused(false)


func _on_main_menu_pressed() -> void:
	set_game_paused(false)
	_coop.call("request_return_to_menu")


func _on_pause_proxy_pressed() -> void:
	on_pause_proxy_pressed()


func _on_debug_spawn_pressed() -> void:
	if _debug_spawn_option == null:
		return
	var enemy_type := str(_debug_spawn_option.get_selected_metadata())
	var arena_center := _coop.call("get_arena_center") as Vector2
	var spawn_position := arena_center
	var target: Node2D = _coop.call("get_nearest_player_to", arena_center)
	if target != null and is_instance_valid(target):
		spawn_position = target.global_position + Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * 360.0
	var spawned = _coop.call("spawn_enemy_instance", enemy_type, spawn_position)
	if spawned != null and spawned.has_method("apply_champion_scale") and EnemyTypes.is_champion(enemy_type):
		spawned.apply_champion_scale(int(_coop.call("get_room_depth")), int(_coop.call("get_player_count")))


func _on_debug_give_weapon_level_pressed() -> void:
	RunState.level_up_weapon(0)
	_coop.call("rebuild_player_loadouts")
	_coop.call("refresh_hud")


func _on_debug_set_weapon_pressed() -> void:
	if _debug_weapon_option == null:
		return
	var weapon_id := str(_debug_weapon_option.get_selected_metadata())
	if weapon_id.is_empty():
		return
	RunState.set_active_weapon(0, weapon_id)
	_coop.call("rebuild_player_loadouts")
	_coop.call("refresh_hud")


func _on_debug_clear_enemies_pressed() -> void:
	for enemy in (_coop.call("get_enemy_target_nodes") as Array).duplicate():
		if enemy != null and is_instance_valid(enemy) and enemy.has_method("apply_damage"):
			enemy.apply_damage(999999)


func _on_debug_god_toggled(pressed: bool) -> void:
	RunState.debug_profiling = pressed


func _is_debug_menu_enabled() -> bool:
	if OS.is_debug_build():
		return true
	for arg in OS.get_cmdline_user_args():
		if arg == "--debug-menu":
			return true
	return false


func _create_build_ability_card(player, player_tint: Color, slot_index: int) -> PanelContainer:
	var slot_data: Dictionary = player.get_ability_hud_data(slot_index)
	var ability_id := str(slot_data.get("skill_id", ""))
	var cooldown := float(slot_data.get("base_cooldown", 0.0))
	if cooldown <= 0.0:
		cooldown = float(_ability_registry.get_definition(ability_id).get("cooldown", 0.0))
	var slot_color := CoopFormat.get_slot_color(player_tint, slot_index, HUD_SLOT_2_COLOR)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(slot_color.r * 0.12, slot_color.g * 0.12, slot_color.b * 0.12, 0.84)
	style.border_color = Color(slot_color.r, slot_color.g, slot_color.b, 0.9)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	card.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 2)
	margin.add_child(layout)
	var trigger := Label.new()
	trigger.text = str(ABILITY_TRIGGER_LABELS[slot_index]) if slot_index >= 0 and slot_index < ABILITY_TRIGGER_LABELS.size() else "A%d" % (slot_index + 1)
	trigger.add_theme_font_size_override("font_size", 10)
	trigger.add_theme_color_override("font_color", slot_color.lightened(0.25))
	layout.add_child(trigger)
	var name_label := Label.new()
	name_label.text = str(slot_data.get("name", "Ability"))
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 0.96))
	layout.add_child(name_label)
	var cooldown_label := Label.new()
	cooldown_label.text = "CD %.1fs" % cooldown
	cooldown_label.add_theme_font_size_override("font_size", 10)
	cooldown_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96, 0.78))
	layout.add_child(cooldown_label)
	return card


func _create_mutation_chip(entry: Dictionary) -> PanelContainer:
	var rarity := str(entry.get("rarity", "common"))
	var rarity_rank := CoopFormat.rarity_rank(rarity)
	var rarity_color := Color(1.0, 0.42, 0.92, 1.0) if rarity_rank >= 2 else (Color(1.0, 0.78, 0.32, 1.0) if rarity_rank == 1 else Color(0.48, 0.74, 1.0, 1.0))
	var group_color := IconFactoryData.get_group_color(str(entry.get("group", "attribute")))
	var chip := PanelContainer.new()
	chip.tooltip_text = str(entry.get("description", ""))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(group_color.r, group_color.g, group_color.b, 0.18 if rarity_rank >= 1 else 0.14)
	style.border_color = rarity_color if rarity_rank >= 1 else group_color
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	chip.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 3)
	chip.add_child(margin)
	var label := Label.new()
	var level_text := " Lv%d" % int(entry.get("count", 1)) if int(entry.get("count", 1)) > 1 and rarity_rank <= 0 else ""
	label.text = "%s%s" % [str(entry.get("name", "")), level_text]
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", rarity_color.lightened(0.18))
	margin.add_child(label)
	return chip


func _compare_mutation_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_rarity_rank := CoopFormat.rarity_rank(str(left.get("rarity", "common")))
	var right_rarity_rank := CoopFormat.rarity_rank(str(right.get("rarity", "common")))
	if left_rarity_rank != right_rarity_rank:
		return left_rarity_rank > right_rarity_rank
	return str(left.get("name", "")).naturalnocasecmp_to(str(right.get("name", ""))) < 0
