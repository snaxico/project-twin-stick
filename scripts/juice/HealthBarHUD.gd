extends Control

var _title_label: Label = null
var _value_label: Label = null
var _background_rect: ColorRect = null
var _ghost_rect: ColorRect = null
var _fill_rect: ColorRect = null

var _fill_color: Color = Color(0.2, 0.85, 0.2, 1.0)
var _title_text: String = ""
var _current_ratio: float = 1.0
var _ghost_ratio: float = 1.0
var _current_status_text: String = ""
var _ghost_tween: Tween = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(300.0, 40.0)
	_build()
	_layout_children()

func configure(title_text: String, fill_color: Color) -> void:
	_title_text = title_text
	_fill_color = fill_color
	if _title_label != null:
		_title_label.text = title_text
	if _fill_rect != null:
		_fill_rect.color = fill_color

func set_health(current_health: int, max_health: int, status_text: String = "") -> void:
	var target_ratio := 0.0
	if max_health > 0:
		target_ratio = clamp(float(current_health) / float(max_health), 0.0, 1.0)
	if is_equal_approx(target_ratio, _current_ratio) and _current_status_text == status_text:
		return

	var previous_ratio := _current_ratio
	_current_ratio = target_ratio
	_current_status_text = status_text
	if _value_label != null:
		_value_label.text = status_text if not status_text.is_empty() else "%d/%d" % [current_health, max_health]
	if _title_label != null:
		_title_label.text = _title_text

	_apply_fill_ratio(_current_ratio)
	if _ghost_tween != null and _ghost_tween.is_valid():
		_ghost_tween.kill()
	if target_ratio >= previous_ratio:
		_ghost_ratio = target_ratio
		_apply_ghost_ratio(_ghost_ratio)
		return

	_ghost_tween = create_tween()
	_ghost_tween.tween_interval(0.08)
	_ghost_tween.tween_method(_set_ghost_ratio, _ghost_ratio, target_ratio, 0.24)

func _build() -> void:
	if _title_label != null:
		return

	_title_label = Label.new()
	_value_label = Label.new()
	_background_rect = ColorRect.new()
	_ghost_rect = ColorRect.new()
	_fill_rect = ColorRect.new()

	add_child(_title_label)
	add_child(_background_rect)
	add_child(_ghost_rect)
	add_child(_fill_rect)
	add_child(_value_label)

	_title_label.text = _title_text
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_background_rect.color = Color(0.08, 0.08, 0.08, 0.86)
	_ghost_rect.color = Color(1.0, 1.0, 1.0, 0.18)
	_fill_rect.color = _fill_color

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_children()

func _layout_children() -> void:
	if _title_label == null:
		return
	var width: float = max(size.x, custom_minimum_size.x)
	var bar_top: float = 20.0
	var bar_height: float = 14.0

	_title_label.position = Vector2.ZERO
	_title_label.size = Vector2(width * 0.55, 18.0)
	_value_label.position = Vector2(width * 0.55, 0.0)
	_value_label.size = Vector2(width * 0.45, 18.0)

	_background_rect.position = Vector2(0.0, bar_top)
	_background_rect.size = Vector2(width, bar_height)
	_apply_ghost_ratio(_ghost_ratio)
	_apply_fill_ratio(_current_ratio)

func _apply_fill_ratio(ratio: float) -> void:
	if _fill_rect == null or _background_rect == null:
		return
	_fill_rect.position = _background_rect.position
	_fill_rect.size = Vector2(_background_rect.size.x * ratio, _background_rect.size.y)

func _apply_ghost_ratio(ratio: float) -> void:
	if _ghost_rect == null or _background_rect == null:
		return
	_ghost_rect.position = _background_rect.position
	_ghost_rect.size = Vector2(_background_rect.size.x * ratio, _background_rect.size.y)

func _set_ghost_ratio(value: float) -> void:
	_ghost_ratio = value
	_apply_ghost_ratio(_ghost_ratio)
