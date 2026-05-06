extends Area2D

@onready var visual: Polygon2D = $Visual
@onready var prompt_label: Label = $PromptLabel

var _interaction_enabled: bool = true

func _ready() -> void:
	set_interaction_enabled(true)

func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	if prompt_label != null:
		prompt_label.visible = enabled
	if visual != null:
		visual.visible = enabled

func is_player_in_range(player: Node2D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return player.global_position.distance_to(global_position) <= 110.0
