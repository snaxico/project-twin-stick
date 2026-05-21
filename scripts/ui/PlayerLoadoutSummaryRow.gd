class_name PlayerLoadoutSummaryRow
extends PanelContainer

const IconFactoryData = preload("res://scripts/ui/IconFactory.gd")

const MAX_MUTATION_CHIPS := 6

var _style: StyleBoxFlat = null
var _player_label: Label = null
var _gold_label: Label = null
var _weapon_icon: TextureRect = null
var _primary_icon: TextureRect = null
var _dash_icon: TextureRect = null
var _mutation_row: HBoxContainer = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

func configure_player(player_label: String, tint: Color) -> void:
	if _player_label == null:
		_build()
	_player_label.text = player_label
	_player_label.add_theme_color_override("font_color", tint.lightened(0.18))
	_style.border_color = tint.lightened(0.08)
	add_theme_stylebox_override("panel", _style)

func update_row(data: Dictionary) -> void:
	if _player_label == null:
		_build()
	_gold_label.text = "%dg" % int(data.get("gold", 0))
	_weapon_icon.texture = IconFactoryData.get_weapon_icon(str(data.get("weapon_id", "rifle")))
	_primary_icon.texture = IconFactoryData.get_weapon_icon(str(data.get("primary_skill_id", "shockwave")))
	_dash_icon.texture = IconFactoryData.get_weapon_icon("dash")
	_rebuild_mutation_chips(data.get("mutations", []) as Array)

func _build() -> void:
	if _player_label != null:
		return
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.04, 0.06, 0.09, 0.34)
	_style.border_color = Color(0.44, 0.5, 0.58, 0.4)
	_style.set_border_width_all(1)
	_style.corner_radius_top_left = 6
	_style.corner_radius_top_right = 6
	_style.corner_radius_bottom_left = 6
	_style.corner_radius_bottom_right = 6
	_style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", _style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	_player_label = Label.new()
	_player_label.add_theme_font_size_override("font_size", 13)
	row.add_child(_player_label)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 14)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 0.95))
	row.add_child(_gold_label)

	_weapon_icon = _build_icon(18.0)
	row.add_child(_weapon_icon)
	_primary_icon = _build_icon(18.0)
	row.add_child(_primary_icon)
	_dash_icon = _build_icon(18.0)
	row.add_child(_dash_icon)

	_mutation_row = HBoxContainer.new()
	_mutation_row.add_theme_constant_override("separation", 3)
	row.add_child(_mutation_row)

func _build_icon(size_px: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(size_px, size_px)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon

func _rebuild_mutation_chips(mutations: Array) -> void:
	for child in _mutation_row.get_children():
		child.queue_free()
	if mutations.is_empty():
		return
	var aggregated: Array = _aggregate_mutations(mutations)
	var visible_count := mini(aggregated.size(), MAX_MUTATION_CHIPS)
	for index in range(visible_count):
		var chip_data: Dictionary = aggregated[index] as Dictionary
		_mutation_row.add_child(_build_mutation_chip(chip_data))
	if aggregated.size() > MAX_MUTATION_CHIPS:
		var overflow := Label.new()
		overflow.text = "+%d" % (aggregated.size() - MAX_MUTATION_CHIPS)
		overflow.add_theme_font_size_override("font_size", 10)
		overflow.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0, 0.84))
		_mutation_row.add_child(overflow)

func _aggregate_mutations(mutations: Array) -> Array:
	var counts: Dictionary = {}
	var defs: Dictionary = {}
	for mutation_variant in mutations:
		if not (mutation_variant is Dictionary):
			continue
		var mutation: Dictionary = mutation_variant as Dictionary
		var mutation_id := str(mutation.get("id", ""))
		if mutation_id.is_empty():
			continue
		counts[mutation_id] = int(counts.get(mutation_id, 0)) + 1
		if not defs.has(mutation_id):
			defs[mutation_id] = mutation
	var result: Array = []
	for mutation_id in counts.keys():
		var definition: Dictionary = (defs[mutation_id] as Dictionary).duplicate(true)
		definition["count"] = int(counts[mutation_id])
		result.append(definition)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var rarity_a := str(a.get("rarity", "common"))
		var rarity_b := str(b.get("rarity", "common"))
		if rarity_a != rarity_b:
			return rarity_a == "rare"
		return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0
	)
	return result

func _build_mutation_chip(mutation: Dictionary) -> Control:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(18.0, 18.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.16, 0.2, 0.28)
	var is_rare := str(mutation.get("rarity", "common")) == "rare"
	style.border_color = Color(0.95, 0.8, 0.28, 0.64) if is_rare else Color(0.8, 0.88, 0.98, 0.26)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	chip.add_theme_stylebox_override("panel", style)
	chip.tooltip_text = "%s\n%s" % [str(mutation.get("name", "")), str(mutation.get("description", ""))]

	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = IconFactoryData.get_mutation_icon(str(mutation.get("id", "")))
	chip.add_child(icon)

	var count := int(mutation.get("count", 1))
	if count > 1:
		var badge := Label.new()
		badge.anchor_left = 1.0
		badge.anchor_top = 1.0
		badge.anchor_right = 1.0
		badge.anchor_bottom = 1.0
		badge.offset_left = -12.0
		badge.offset_top = -10.0
		badge.offset_right = 0.0
		badge.offset_bottom = 0.0
		badge.text = str(count)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 8)
		badge.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0, 0.96))
		chip.add_child(badge)
	return chip
