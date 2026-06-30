extends Node

const MutationPickUIScene = preload("res://scenes/ui/MutationPickUI.tscn")
const CoopFormat = preload("res://scripts/game/CoopFormat.gd")

const MUTATION_REROLL_BASE_COST := 100

var _coop: Node = null
var _ui_layer: CanvasLayer = null
var _mutation_system = null
var _mutation_pick_ui = null
var _mutation_pick_reroll_counts: Array = []
var _mutation_pick_round_force_rare := false


func setup(coop: Node, ui_layer: CanvasLayer, mutation_system) -> void:
	_coop = coop
	_ui_layer = ui_layer
	_mutation_system = mutation_system


func show_pick(force_rare: bool, title: String, subtitle: String) -> void:
	if _mutation_pick_ui != null and is_instance_valid(_mutation_pick_ui):
		_mutation_pick_ui.queue_free()
	_mutation_pick_round_force_rare = force_rare
	_reset_mutation_pick_reroll_counts()
	var options_by_player: Array = []
	var player_count := int(_coop.call("get_player_count"))
	for player_index in range(player_count):
		options_by_player.append(_roll_initial_mutation_options_for_player(player_index, force_rare))
	_mutation_pick_ui = MutationPickUIScene.instantiate()
	_mutation_pick_ui.configure_for_players(_coop.call("get_player_configs") as Array, options_by_player, title, subtitle)
	_mutation_pick_ui.set_reroll_state(RunState.get_current_score(), _build_mutation_pick_reroll_costs())
	_mutation_pick_ui.selections_confirmed.connect(Callable(_coop, "_on_mutation_selections_confirmed"))
	_mutation_pick_ui.reroll_requested.connect(_on_mutation_reroll_requested)
	_mutation_pick_ui.skip_requested.connect(_on_mutation_skip_requested)
	_ui_layer.add_child(_mutation_pick_ui)
	_coop.call("set_awaiting_pick", true)
	_coop.call("request_pick_dilation")


func close_pick() -> void:
	if _mutation_pick_ui != null and is_instance_valid(_mutation_pick_ui):
		_mutation_pick_ui.queue_free()
	_mutation_pick_ui = null
	_coop.call("set_awaiting_pick", false)


func reset_reroll_counts() -> void:
	_reset_mutation_pick_reroll_counts()


func _roll_initial_mutation_options_for_player(player_index: int, round_force_rare: bool) -> Array:
	var inventory: PlayerInventory = RunState.get_player_inventory(player_index)
	var force_player_rare: bool = round_force_rare or (inventory != null and inventory.rare_dry_streak >= 3)
	var options: Array = _mutation_system.roll_mutation_options(
		player_index,
		3,
		float(_coop.call("get_current_rare_chance")),
		force_player_rare,
		float(_coop.call("get_signature_share", int(_coop.call("get_room_depth"))))
	)
	if inventory != null:
		if _options_contain_rare(options):
			inventory.rare_dry_streak = 0
		else:
			inventory.rare_dry_streak += 1
	return options


func _roll_reroll_mutation_options_for_player(player_index: int) -> Array:
	return _mutation_system.roll_mutation_options(
		player_index,
		3,
		float(_coop.call("get_current_rare_chance")),
		_mutation_pick_round_force_rare,
		float(_coop.call("get_signature_share", int(_coop.call("get_room_depth"))))
	)


func _reset_mutation_pick_reroll_counts() -> void:
	_mutation_pick_reroll_counts.clear()
	for _player_index in range(int(_coop.call("get_player_count"))):
		_mutation_pick_reroll_counts.append(0)


func _build_mutation_pick_reroll_costs() -> Array:
	var costs: Array = []
	for player_index in range(int(_coop.call("get_player_count"))):
		costs.append(_get_mutation_pick_reroll_cost(player_index))
	return costs


func _get_mutation_pick_reroll_cost(player_index: int) -> int:
	if player_index < 0 or player_index >= _mutation_pick_reroll_counts.size():
		return MUTATION_REROLL_BASE_COST
	return MUTATION_REROLL_BASE_COST * int(pow(2.0, float(maxi(int(_mutation_pick_reroll_counts[player_index]), 0))))


func _on_mutation_reroll_requested(player_index: int) -> void:
	if _mutation_pick_ui == null or not is_instance_valid(_mutation_pick_ui):
		return
	if player_index < 0 or player_index >= int(_coop.call("get_player_count")):
		return
	var cost := _get_mutation_pick_reroll_cost(player_index)
	if not RunState.spend_run_score(cost):
		_mutation_pick_ui.set_reroll_state(RunState.get_current_score(), _build_mutation_pick_reroll_costs())
		return
	_mutation_pick_reroll_counts[player_index] = int(_mutation_pick_reroll_counts[player_index]) + 1
	_mutation_pick_ui.replace_options_for_player(player_index, _roll_reroll_mutation_options_for_player(player_index))
	_mutation_pick_ui.set_reroll_state(RunState.get_current_score(), _build_mutation_pick_reroll_costs())
	_coop.call("play_sfx", "play_ui_click", [])
	_coop.call("notify_run_score_changed")


func _on_mutation_skip_requested(_player_index: int) -> void:
	_coop.call("play_sfx", "play_ui_click", [])
	if _mutation_pick_ui != null and is_instance_valid(_mutation_pick_ui):
		_mutation_pick_ui.set_reroll_state(RunState.get_current_score(), _build_mutation_pick_reroll_costs())


func _options_contain_rare(options: Array) -> bool:
	for option_variant in options:
		var option := option_variant as Dictionary
		if CoopFormat.rarity_rank(str(option.get("rarity", "common"))) >= 1:
			return true
	return false
