class_name PauseInputProxy
extends Node

signal pause_pressed

func _unhandled_input(event: InputEvent) -> void:
	var parent_item := get_parent() as CanvasItem
	if parent_item != null and not parent_item.visible:
		return
	if event.is_action_pressed("pause"):
		pause_pressed.emit()
		get_viewport().set_input_as_handled()
