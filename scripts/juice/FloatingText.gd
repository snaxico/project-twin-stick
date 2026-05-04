extends Label

func show_text(content: String, color: Color, start_position: Vector2) -> void:
	text = content
	position = start_position
	modulate = color
	scale = Vector2.ONE * 0.92
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", start_position + Vector2(0.0, -30.0), 0.8)
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_property(self, "scale", Vector2.ONE, 0.18)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
