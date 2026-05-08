extends Control

const IconFactoryData = preload("res://scripts/ui/IconFactory.gd")

@onready var panel: Panel = $Panel
@onready var layout: VBoxContainer = $Panel/MarginContainer/Layout
@onready var title_label: Label = $Panel/MarginContainer/Layout/Title
@onready var detail_label: Label = $Panel/MarginContainer/Layout/Detail
@onready var timer_label: Label = $Panel/MarginContainer/Layout/TimerLabel
@onready var timer_bar: ProgressBar = $Panel/MarginContainer/Layout/TimerBar
@onready var vote_rows: VBoxContainer = $Panel/MarginContainer/Layout/VoteRows
@onready var result_label: Label = $Panel/MarginContainer/Layout/ResultLabel

var _icon_container: CenterContainer = null
var _icon_rect: TextureRect = null
var _type_badge_panel: PanelContainer = null
var _type_badge_label: Label = null

func _ready() -> void:
	_ensure_runtime_layout()

func setup_for_item(item: Dictionary, player_count: int) -> void:
	_ensure_runtime_layout()
	title_label.text = str(item.get("name", "Loot"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.add_theme_font_size_override("font_size", 13)
	detail_label.text = "%s\nTake: Interact button | Scrap: Scrap button" % str(item.get("description", "Choose to take or scrap the drop."))
	_type_badge_label.text = _get_type_badge_text(str(item.get("type", "")))
	_type_badge_panel.add_theme_stylebox_override("panel", _build_badge_style(_get_type_badge_color(str(item.get("type", "")))))
	_icon_rect.texture = _get_item_icon(item)
	result_label.text = ""
	result_label.visible = false
	_rebuild_vote_rows(player_count)

func update_vote_state(votes: Dictionary, player_count: int, time_remaining: float, duration: float) -> void:
	if timer_label != null:
		timer_label.text = "Time Remaining: %.1fs" % max(time_remaining, 0.0)
	if timer_bar != null:
		timer_bar.max_value = max(duration, 0.01)
		timer_bar.value = clamp(time_remaining, 0.0, duration)
	for index in range(min(player_count, vote_rows.get_child_count())):
		var row_label := vote_rows.get_child(index) as Label
		if row_label == null:
			continue
		var vote_value := str(votes.get(index, "waiting"))
		var vote_text := "Waiting..."
		if vote_value == "take":
			vote_text = "Take"
		elif vote_value == "scrap":
			vote_text = "Scrap"
		row_label.text = "P%d: %s" % [index + 1, vote_text]

func show_result(summary_text: String) -> void:
	if result_label == null:
		return
	result_label.visible = true
	result_label.text = summary_text

func _rebuild_vote_rows(player_count: int) -> void:
	for child in vote_rows.get_children():
		vote_rows.remove_child(child)
		child.queue_free()
	for index in range(player_count):
		var row_label := Label.new()
		row_label.text = "P%d: Waiting..." % (index + 1)
		vote_rows.add_child(row_label)

func _ensure_runtime_layout() -> void:
	if _icon_rect != null:
		return
	_icon_container = CenterContainer.new()
	_icon_container.custom_minimum_size = Vector2(0.0, 72.0)
	layout.add_child(_icon_container)
	layout.move_child(_icon_container, 0)

	_icon_rect = TextureRect.new()
	_icon_rect.custom_minimum_size = Vector2(64.0, 64.0)
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_container.add_child(_icon_rect)

	var badge_container := CenterContainer.new()
	layout.add_child(badge_container)
	layout.move_child(badge_container, 2)

	_type_badge_panel = PanelContainer.new()
	_type_badge_panel.custom_minimum_size = Vector2(120.0, 28.0)
	badge_container.add_child(_type_badge_panel)

	_type_badge_label = Label.new()
	_type_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_type_badge_label.add_theme_font_size_override("font_size", 12)
	_type_badge_panel.add_child(_type_badge_label)

func _get_item_icon(item: Dictionary) -> Texture2D:
	var item_type: String = str(item.get("type", ""))
	var item_id: String = str(item.get("id", ""))
	if item_type == "passive":
		return IconFactoryData.get_passive_icon(item_id)
	return IconFactoryData.get_weapon_icon(item_id)

func _get_type_badge_text(item_type: String) -> String:
	match item_type:
		"primary_weapon":
			return "Primary"
		"secondary_weapon":
			return "Secondary"
		"passive":
			return "Passive"
		_:
			return "Item"

func _get_type_badge_color(item_type: String) -> Color:
	match item_type:
		"primary_weapon":
			return Color(0.96, 0.54, 0.26, 1.0)
		"secondary_weapon":
			return Color(0.82, 0.46, 1.0, 1.0)
		"passive":
			return Color(0.56, 0.88, 1.0, 1.0)
		_:
			return Color(0.62, 0.7, 0.78, 1.0)

func _build_badge_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.2, accent.g * 0.2, accent.b * 0.2, 0.88)
	style.border_color = accent
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style
