extends Control

const IconFactoryData = preload("res://scripts/ui/IconFactory.gd")

@onready var layout: VBoxContainer = $Panel/MarginContainer/Layout
@onready var title_label: Label = $Panel/MarginContainer/Layout/Title
@onready var wallet_label: Label = $Panel/MarginContainer/Layout/Wallet
@onready var status_label: Label = $Panel/MarginContainer/Layout/Status
@onready var offer_1_label: Label = $Panel/MarginContainer/Layout/Offer1
@onready var offer_2_label: Label = $Panel/MarginContainer/Layout/Offer2
@onready var offer_3_label: Label = $Panel/MarginContainer/Layout/Offer3
@onready var ready_label: Label = $Panel/MarginContainer/Layout/ReadyLabel
@onready var hint_label: Label = $Panel/MarginContainer/Layout/Hint

var _wallet_icon_rect: TextureRect = null
var _offer_panels: Array = []
var _offer_icon_rects: Array = []
var _offer_name_labels: Array = []
var _offer_cost_labels: Array = []
var _offer_description_labels: Array = []
var _offer_type_labels: Array = []
var _ready_panel: PanelContainer = null

func setup_for_player(player_index: int, offers: Array, gold_value: int, selected_index: int, ready_players: Dictionary, ready_deadline_text: String) -> void:
	_ensure_runtime_layout()
	title_label.text = "P%d Shop" % (player_index + 1)
	hint_label.text = "Move left/right. Confirm to buy. Select Ready when done. Cancel closes the panel."
	update_state(player_index, offers, gold_value, selected_index, ready_players, ready_deadline_text, "")

func update_state(_player_index: int, offers: Array, gold_value: int, selected_index: int, ready_players: Dictionary, ready_deadline_text: String, status_text: String) -> void:
	_ensure_runtime_layout()
	wallet_label.text = str(gold_value)
	status_label.text = status_text
	for offer_index in range(3):
		_set_offer_panel(offers, offer_index, selected_index == offer_index)
	var ready_texts: Array = []
	for ready_key in ready_players.keys():
		if bool(ready_players[ready_key]):
			ready_texts.append("P%d Ready" % (int(ready_key) + 1))
	ready_label.text = "Ready / Leave Shop%s" % ["" if ready_deadline_text.is_empty() else "  %s" % ready_deadline_text]
	if not ready_texts.is_empty():
		ready_label.text += "\n" + " | ".join(ready_texts)
	_ready_panel.add_theme_stylebox_override("panel", _build_entry_style(selected_index == 3, Color(0.74, 0.92, 0.42, 1.0)))

func _ensure_runtime_layout() -> void:
	if _wallet_icon_rect != null:
		return
	var wallet_index: int = wallet_label.get_index()
	var wallet_row := HBoxContainer.new()
	wallet_row.add_theme_constant_override("separation", 6)
	layout.remove_child(wallet_label)
	layout.add_child(wallet_row)
	layout.move_child(wallet_row, wallet_index)

	_wallet_icon_rect = TextureRect.new()
	_wallet_icon_rect.custom_minimum_size = Vector2(18.0, 18.0)
	_wallet_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wallet_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_wallet_icon_rect.texture = IconFactoryData.get_ui_icon("gold")
	wallet_row.add_child(_wallet_icon_rect)
	wallet_row.add_child(wallet_label)

	offer_1_label.visible = false
	offer_2_label.visible = false
	offer_3_label.visible = false

	var insertion_index: int = offer_1_label.get_index()
	for _index in range(3):
		var entry_panel: PanelContainer = PanelContainer.new()
		entry_panel.custom_minimum_size = Vector2(0.0, 72.0)
		var entry_margin := MarginContainer.new()
		entry_margin.add_theme_constant_override("margin_left", 8)
		entry_margin.add_theme_constant_override("margin_top", 8)
		entry_margin.add_theme_constant_override("margin_right", 8)
		entry_margin.add_theme_constant_override("margin_bottom", 8)
		entry_panel.add_child(entry_margin)

		var entry_row := HBoxContainer.new()
		entry_row.add_theme_constant_override("separation", 10)
		entry_margin.add_child(entry_row)

		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(48.0, 48.0)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		entry_row.add_child(icon_rect)

		var text_column := VBoxContainer.new()
		text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_column.add_theme_constant_override("separation", 2)
		entry_row.add_child(text_column)

		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", 18)
		text_column.add_child(name_label)

		var cost_row := HBoxContainer.new()
		cost_row.add_theme_constant_override("separation", 4)
		text_column.add_child(cost_row)

		var cost_icon := TextureRect.new()
		cost_icon.custom_minimum_size = Vector2(16.0, 16.0)
		cost_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cost_icon.texture = IconFactoryData.get_ui_icon("gold")
		cost_row.add_child(cost_icon)

		var cost_label := Label.new()
		cost_row.add_child(cost_label)

		var type_label := Label.new()
		type_label.add_theme_font_size_override("font_size", 12)
		text_column.add_child(type_label)

		var description_label := Label.new()
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.add_theme_font_size_override("font_size", 12)
		text_column.add_child(description_label)

		layout.add_child(entry_panel)
		layout.move_child(entry_panel, insertion_index + _index)
		_offer_panels.append(entry_panel)
		_offer_icon_rects.append(icon_rect)
		_offer_name_labels.append(name_label)
		_offer_cost_labels.append(cost_label)
		_offer_description_labels.append(description_label)
		_offer_type_labels.append(type_label)

	var ready_index: int = ready_label.get_index()
	_ready_panel = PanelContainer.new()
	layout.remove_child(ready_label)
	layout.add_child(_ready_panel)
	layout.move_child(_ready_panel, ready_index)
	var ready_margin := MarginContainer.new()
	ready_margin.add_theme_constant_override("margin_left", 8)
	ready_margin.add_theme_constant_override("margin_top", 8)
	ready_margin.add_theme_constant_override("margin_right", 8)
	ready_margin.add_theme_constant_override("margin_bottom", 8)
	_ready_panel.add_child(ready_margin)
	ready_margin.add_child(ready_label)

func _set_offer_panel(offers: Array, offer_index: int, selected: bool) -> void:
	var panel: PanelContainer = _offer_panels[offer_index] as PanelContainer
	var icon_rect: TextureRect = _offer_icon_rects[offer_index] as TextureRect
	var name_label: Label = _offer_name_labels[offer_index] as Label
	var cost_label: Label = _offer_cost_labels[offer_index] as Label
	var description_label: Label = _offer_description_labels[offer_index] as Label
	var type_label: Label = _offer_type_labels[offer_index] as Label
	if offer_index >= offers.size() or not (offers[offer_index] is Dictionary):
		panel.add_theme_stylebox_override("panel", _build_entry_style(false, Color(0.48, 0.56, 0.64, 1.0)))
		icon_rect.texture = null
		name_label.text = "---"
		cost_label.text = ""
		type_label.text = ""
		description_label.text = ""
		description_label.visible = false
		return
	var offer: Dictionary = offers[offer_index]
	var item_type: String = str(offer.get("type", ""))
	var accent: Color = _get_type_color(item_type)
	panel.add_theme_stylebox_override("panel", _build_entry_style(selected, accent))
	icon_rect.texture = _get_item_icon(offer)
	name_label.text = str(offer.get("name", "Offer"))
	cost_label.text = str(int(offer.get("cost", 0)))
	type_label.text = _get_type_badge_text(item_type)
	type_label.modulate = accent.lightened(0.15)
	description_label.text = str(offer.get("description", ""))
	description_label.visible = selected and not description_label.text.is_empty()

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

func _get_type_color(item_type: String) -> Color:
	match item_type:
		"primary_weapon":
			return Color(0.96, 0.54, 0.26, 1.0)
		"secondary_weapon":
			return Color(0.82, 0.46, 1.0, 1.0)
		"passive":
			return Color(0.56, 0.88, 1.0, 1.0)
		_:
			return Color(0.62, 0.7, 0.78, 1.0)

func _build_entry_style(selected: bool, accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.9) if selected else Color(0.06, 0.07, 0.1, 0.68)
	style.border_color = accent if selected else accent.darkened(0.35)
	style.set_border_width_all(2 if selected else 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
