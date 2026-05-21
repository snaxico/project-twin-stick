class_name MineFieldModifier
extends Node2D

const MineData = preload("res://scripts/modifiers/Mine.gd")

const CYCLE_DURATION := 10.0
const SPAWN_DURATION := 1.0
const ACTIVE_DURATION := 8.0
const MINES_PER_QUADRANT := 5

var _arena_rect := Rect2()
var _player_nodes: Array = []
var _elapsed := 0.0
var _cycle_index := -1
var _mines: Array = []

func setup(arena_rect: Rect2, player_nodes: Array) -> void:
	_arena_rect = arena_rect
	_player_nodes = player_nodes
	_spawn_cycle_mines()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	var current_cycle := int(floor(_elapsed / CYCLE_DURATION)) % 4
	if current_cycle != _cycle_index:
		_cycle_index = current_cycle
		_clear_mines()
		_spawn_cycle_mines()
	var phase_elapsed := fmod(_elapsed, CYCLE_DURATION)
	if phase_elapsed < SPAWN_DURATION or phase_elapsed >= SPAWN_DURATION + ACTIVE_DURATION:
		return
	for mine in _mines:
		if mine != null and is_instance_valid(mine):
			mine.update_mine(delta, _player_nodes)

func _spawn_cycle_mines() -> void:
	_cycle_index = int(floor(_elapsed / CYCLE_DURATION)) % 4
	var quadrants := [_cycle_index % 4, (_cycle_index + 1) % 4]
	for quadrant in quadrants:
		for _index in range(MINES_PER_QUADRANT):
			var mine = MineData.new()
			mine.position = _random_point_in_quadrant(quadrant)
			add_child(mine)
			mine.arm()
			_mines.append(mine)

func _clear_mines() -> void:
	for mine in _mines:
		if mine != null and is_instance_valid(mine):
			mine.queue_free()
	_mines.clear()

func _random_point_in_quadrant(quadrant: int) -> Vector2:
	var center := _arena_rect.position + _arena_rect.size * 0.5
	var min_x := _arena_rect.position.x + 160.0
	var max_x := _arena_rect.end.x - 160.0
	var min_y := _arena_rect.position.y + 160.0
	var max_y := _arena_rect.end.y - 160.0
	match quadrant:
		0:
			return Vector2(randf_range(min_x, center.x - 120.0), randf_range(min_y, center.y - 120.0))
		1:
			return Vector2(randf_range(center.x + 120.0, max_x), randf_range(min_y, center.y - 120.0))
		2:
			return Vector2(randf_range(min_x, center.x - 120.0), randf_range(center.y + 120.0, max_y))
		_:
			return Vector2(randf_range(center.x + 120.0, max_x), randf_range(center.y + 120.0, max_y))
