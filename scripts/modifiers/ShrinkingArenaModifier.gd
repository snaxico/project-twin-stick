class_name ShrinkingArenaModifier
extends Node2D

const SHRINK_STEP_TIME := 10.0
const SHRINK_STEP := 0.05
const MIN_SCALE := 0.6

var _base_rect := Rect2()
var _elapsed := 0.0
var _current_scale := 1.0

func setup(arena_rect: Rect2) -> void:
	_base_rect = arena_rect
	set_physics_process(true)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	var steps: int = int(floor(_elapsed / SHRINK_STEP_TIME))
	_current_scale = maxf(MIN_SCALE, 1.0 - float(steps) * SHRINK_STEP)
	queue_redraw()

func get_current_rect() -> Rect2:
	var center := _base_rect.position + _base_rect.size * 0.5
	var size := _base_rect.size * _current_scale
	return Rect2(center - size * 0.5, size)

func clamp_node(node: Node2D) -> void:
	var rect := get_current_rect()
	node.global_position.x = clampf(node.global_position.x, rect.position.x + 24.0, rect.end.x - 24.0)
	node.global_position.y = clampf(node.global_position.y, rect.position.y + 24.0, rect.end.y - 24.0)

func _draw() -> void:
	var rect := get_current_rect()
	draw_rect(rect, Color(1.0, 0.36, 0.26, 0.05), true)
	draw_rect(rect, Color(1.0, 0.58, 0.44, 0.8), false, 8.0)
