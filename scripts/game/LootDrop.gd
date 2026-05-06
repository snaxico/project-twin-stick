extends Area2D

signal interact_requested(player)

const BASE_COLOR := Color(0.98, 0.82, 0.22, 1.0)
const PASSIVE_COLOR := Color(0.56, 0.88, 1.0, 1.0)
const PRIMARY_COLOR := Color(0.96, 0.54, 0.26, 1.0)
const SECONDARY_COLOR := Color(0.82, 0.46, 1.0, 1.0)

@onready var visual: Polygon2D = $Visual
@onready var item_label: Label = $ItemLabel
@onready var prompt_label: Label = $PromptLabel

var item_data: Dictionary = {}
var _base_position: Vector2 = Vector2.ZERO
var _bob_time: float = 0.0
var _interaction_enabled: bool = true

func _ready() -> void:
	_base_position = global_position
	if not item_data.is_empty():
		_apply_item_visuals()
	set_prompt_visible(true)

func _process(delta: float) -> void:
	_bob_time += delta
	global_position = _base_position + Vector2(0.0, sin(_bob_time * 2.4) * 6.0)

func setup(item: Dictionary) -> void:
	item_data = item.duplicate(true)
	if is_inside_tree():
		_apply_item_visuals()
	set_prompt_visible(true)

func _apply_item_visuals() -> void:
	if item_label != null:
		item_label.text = str(item_data.get("name", "Loot"))
	if visual != null:
		visual.color = _get_item_color(item_data)

func set_prompt_visible(should_show: bool) -> void:
	if prompt_label == null:
		return
	prompt_label.visible = should_show and _interaction_enabled

func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	set_prompt_visible(enabled)

func is_player_in_range(player: Node2D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return player.global_position.distance_to(global_position) <= 96.0

func request_interact(player) -> void:
	if not _interaction_enabled:
		return
	interact_requested.emit(player)

func _get_item_color(item: Dictionary) -> Color:
	match str(item.get("type", "")):
		"primary_weapon":
			return PRIMARY_COLOR
		"secondary_weapon":
			return SECONDARY_COLOR
		_:
			return PASSIVE_COLOR if str(item.get("type", "")) == "passive" else BASE_COLOR
