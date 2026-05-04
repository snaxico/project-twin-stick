extends Control

const GAME_WORLD_SCENE = preload("res://scenes/game/GameWorld.tscn")

signal return_to_menu_requested(open_meta_menu: bool)

@onready var map_panel: Panel = $MapPanel
@onready var map_title_label: Label = $MapPanel/MarginContainer/MapLayout/MapTitle
@onready var map_status_label: Label = $MapPanel/MarginContainer/MapLayout/MapStatus
@onready var option_button_1: Button = $MapPanel/MarginContainer/MapLayout/OptionButton1
@onready var option_button_2: Button = $MapPanel/MarginContainer/MapLayout/OptionButton2
@onready var resolution_panel: Panel = $ResolutionPanel
@onready var resolution_title_label: Label = $ResolutionPanel/MarginContainer/ResolutionLayout/ResolutionTitle
@onready var resolution_detail_label: Label = $ResolutionPanel/MarginContainer/ResolutionLayout/ResolutionDetail
@onready var resolution_button: Button = $ResolutionPanel/MarginContainer/ResolutionLayout/ResolutionButton
@onready var run_summary_panel: Panel = $RunSummaryPanel
@onready var run_summary_title_label: Label = $RunSummaryPanel/MarginContainer/SummaryLayout/SummaryTitle
@onready var run_summary_detail_label: Label = $RunSummaryPanel/MarginContainer/SummaryLayout/SummaryDetail
@onready var run_summary_unlocks_label: Label = $RunSummaryPanel/MarginContainer/SummaryLayout/SummaryUnlocks
@onready var run_summary_button: Button = $RunSummaryPanel/MarginContainer/SummaryLayout/SummaryButton
@onready var choice_panel: Panel = $ChoicePanel
@onready var choice_title_label: Label = $ChoicePanel/MarginContainer/ChoiceLayout/ChoiceTitle
@onready var choice_detail_label: Label = $ChoicePanel/MarginContainer/ChoiceLayout/ChoiceDetail
@onready var choice_button_1: Button = $ChoicePanel/MarginContainer/ChoiceLayout/ChoiceButton1
@onready var choice_button_2: Button = $ChoicePanel/MarginContainer/ChoiceLayout/ChoiceButton2
@onready var choice_button_3: Button = $ChoicePanel/MarginContainer/ChoiceLayout/ChoiceButton3
@onready var choice_continue_button: Button = $ChoicePanel/MarginContainer/ChoiceLayout/ChoiceContinueButton
@onready var game_container: Control = $GameContainer

var _active_game = null
var _post_resolution_action: String = "next"
var _pending_followup: Dictionary = {}
var _choice_context: Dictionary = {}
var _open_meta_menu_on_return: bool = false

func _ready() -> void:
	option_button_1.pressed.connect(_on_option_button_1_pressed)
	option_button_2.pressed.connect(_on_option_button_2_pressed)
	resolution_button.pressed.connect(_on_resolution_button_pressed)
	run_summary_button.pressed.connect(_on_run_summary_button_pressed)
	choice_button_1.pressed.connect(_on_choice_button_1_pressed)
	choice_button_2.pressed.connect(_on_choice_button_2_pressed)
	choice_button_3.pressed.connect(_on_choice_button_3_pressed)
	choice_continue_button.pressed.connect(_on_choice_continue_button_pressed)
	_show_map()

func _show_map() -> void:
	if RunState.is_run_complete():
		_show_resolution("Run Victory", RunState.get_run_summary_text(), "Return to Menu")
		_post_resolution_action = "return_to_menu"
		return

	map_panel.visible = true
	resolution_panel.visible = false
	run_summary_panel.visible = false
	choice_panel.visible = false
	_clear_active_game()

	var current_options := RunState.get_current_options()
	map_title_label.text = "Node Map"
	map_status_label.text = "Step %d of %d. Shared Gold: %d. Choose the next room." % [RunState.current_step_index + 1, RunState.node_map.size(), RunState.gold]

	_configure_option_button(option_button_1, current_options[0] if current_options.size() > 0 else {})
	_configure_option_button(option_button_2, current_options[1] if current_options.size() > 1 else {})

func _configure_option_button(button: Button, node: Dictionary) -> void:
	if node.is_empty():
		button.visible = false
		return

	button.visible = true
	var modifier_text := "None"
	var modifier_data = node.get("modifier", {})
	if modifier_data is Dictionary and not modifier_data.is_empty():
		modifier_text = str(modifier_data.get("name", "Unknown"))

	var description := str(node.get("description", ""))
	if description.is_empty():
		description = str(node.get("reward_label", ""))

	button.text = "%s\nModifier: %s\nReward: %s\n%s" % [
		str(node.get("title", "Room")),
		modifier_text,
		str(node.get("reward_label", "No reward")),
		description,
	]

func _on_option_button_1_pressed() -> void:
	_select_option(0)

func _on_option_button_2_pressed() -> void:
	_select_option(1)

func _select_option(index: int) -> void:
	var current_options := RunState.get_current_options()
	if index < 0 or index >= current_options.size():
		return

	var node: Dictionary = current_options[index]
	RunState.set_current_node(node)

	match str(node.get("room_type", "combat")):
		"combat", "elite", "boss":
			_launch_room(node)
		_:
			var outcome := RunState.resolve_current_noncombat_node()
			_show_outcome(outcome)

func _launch_room(node: Dictionary) -> void:
	map_panel.visible = false
	resolution_panel.visible = false
	choice_panel.visible = false
	_clear_active_game()

	_active_game = GAME_WORLD_SCENE.instantiate()
	_active_game.configure_players(RunState.player_configs)
	_active_game.configure_room(node)
	game_container.add_child(_active_game)
	_active_game.room_cleared.connect(_on_room_cleared)
	_active_game.all_players_dead.connect(_on_room_failed)

func _on_room_cleared(health_states: Array) -> void:
	var outcome := RunState.resolve_current_combat_victory(health_states)
	if str(outcome.get("post_action", "")) == "return_to_menu":
		var meta_reward := ProfileState.award_run_meta_gold(RunState.run_outcome, RunState.rooms_completed)
		_show_run_summary(outcome, meta_reward, true)
		return
	_show_outcome(outcome)

func _on_room_failed() -> void:
	RunState.run_outcome = "failed"
	_pending_followup = {}
	var meta_reward := ProfileState.award_run_meta_gold(RunState.run_outcome, RunState.rooms_completed)
	var outcome := {
		"title": "Run Failed",
		"summary": "The party was defeated.\n%s" % RunState.get_run_summary_text(),
	}
	_show_run_summary(outcome, meta_reward, false)

func _show_resolution(title: String, detail: String, button_text: String) -> void:
	map_panel.visible = false
	resolution_panel.visible = true
	run_summary_panel.visible = false
	choice_panel.visible = false
	_clear_active_game()
	resolution_title_label.text = title
	resolution_detail_label.text = detail
	resolution_button.text = button_text

func _on_resolution_button_pressed() -> void:
	var pending_action := str(_pending_followup.get("action", ""))
	if pending_action == "reward" or pending_action == "shop":
		_show_choice_panel(_pending_followup)
		_pending_followup = {}
		return

	match _post_resolution_action:
		"return_to_menu":
			_pending_followup = {}
			return_to_menu_requested.emit(_open_meta_menu_on_return)
		"complete":
			_pending_followup = {}
			_show_map()
		_:
			_pending_followup = {}
			_show_map()

func _clear_active_game() -> void:
	if _active_game != null and is_instance_valid(_active_game):
		_active_game.queue_free()
		_active_game = null

func _show_outcome(outcome: Dictionary) -> void:
	_pending_followup = {}
	_open_meta_menu_on_return = false
	_post_resolution_action = str(outcome.get("post_action", "next"))
	var action := str(outcome.get("action", "next"))
	if action == "reward" or action == "shop":
		_pending_followup = outcome.duplicate(true)
	_show_resolution(
		str(outcome.get("title", "Result")),
		str(outcome.get("summary", "")),
		str(outcome.get("button_text", "Continue"))
	)

func _show_choice_panel(context: Dictionary) -> void:
	map_panel.visible = false
	resolution_panel.visible = false
	run_summary_panel.visible = false
	choice_panel.visible = true
	_clear_active_game()
	_choice_context = context.duplicate(true)

	var choice_mode := str(context.get("choice_mode", "reward"))
	var title := "Choose One Shared Upgrade" if choice_mode == "reward" else "Shop"
	var detail := "Pick one shared upgrade for the run." if choice_mode == "reward" else "Shared Gold: %d\nBuy one upgrade or leave." % RunState.gold
	choice_title_label.text = title
	choice_detail_label.text = detail

	var choices: Array = context.get("choices", [])
	_configure_choice_button(choice_button_1, choices[0] if choices.size() > 0 else {}, choice_mode)
	_configure_choice_button(choice_button_2, choices[1] if choices.size() > 1 else {}, choice_mode)
	_configure_choice_button(choice_button_3, choices[2] if choices.size() > 2 else {}, choice_mode)
	choice_continue_button.visible = choice_mode == "shop"
	choice_continue_button.text = "Leave Shop"

func _configure_choice_button(button: Button, item: Dictionary, choice_mode: String) -> void:
	if item.is_empty():
		button.visible = false
		button.disabled = true
		return

	button.visible = true
	button.disabled = false
	var cost_text := ""
	if choice_mode == "shop":
		cost_text = "\nCost: %d Gold" % int(item.get("cost", 0))
	button.text = "%s\n%s\n%s%s" % [
		str(item.get("name", "Upgrade")),
		str(item.get("category", "Shared")),
		str(item.get("description", "")),
		cost_text,
	]

func _on_choice_button_1_pressed() -> void:
	_select_choice(0)

func _on_choice_button_2_pressed() -> void:
	_select_choice(1)

func _on_choice_button_3_pressed() -> void:
	_select_choice(2)

func _select_choice(index: int) -> void:
	var choices: Array = _choice_context.get("choices", [])
	if index < 0 or index >= choices.size():
		return

	var item: Dictionary = choices[index]
	var choice_mode := str(_choice_context.get("choice_mode", "reward"))
	var result := RunState.purchase_shop_item(str(item.get("id", ""))) if choice_mode == "shop" else RunState.claim_reward_item(str(item.get("id", "")))
	if not bool(result.get("success", false)):
		choice_detail_label.text = str(result.get("summary", "Could not apply that choice."))
		return

	_show_resolution(str(result.get("title", "Upgrade Applied")), str(result.get("summary", "")), "Continue")
	_post_resolution_action = "next"
	_choice_context = {}

func _on_choice_continue_button_pressed() -> void:
	_choice_context = {}
	_show_map()

func _show_run_summary(outcome: Dictionary, meta_reward: Dictionary, did_win: bool) -> void:
	map_panel.visible = false
	resolution_panel.visible = false
	run_summary_panel.visible = true
	choice_panel.visible = false
	_clear_active_game()
	_pending_followup = {}
	_choice_context = {}
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

func _on_run_summary_button_pressed() -> void:
	return_to_menu_requested.emit(true)
