extends "res://scripts/arena/ArenaMechanic.gd"

const ARM_COUNT := 4
const ARM_LEN := 520.0
const ARM_W := 70.0
const SPIN := 0.5
const TICK := 0.4

var _angle := 0.0
var _tick := TICK


func _physics_process(delta: float) -> void:
	_angle = fmod(_angle + SPIN * delta, TAU)
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_apply_hits()
	queue_redraw()


func _apply_hits() -> void:
	var hit: Dictionary = {}
	var center := _arena.get_center()
	var candidates := _players.duplicate()
	if _coop != null:
		candidates.append_array(_coop.get_nearby_enemy_target_nodes(center, ARM_LEN + ARM_W))
	for actor in candidates:
		if actor == null or not is_instance_valid(actor) or not (actor is Node2D):
			continue
		var pos := (actor as Node2D).global_position
		for arm in range(ARM_COUNT):
			var tip := center + Vector2.RIGHT.rotated(_angle + TAU * float(arm) / float(ARM_COUNT)) * ARM_LEN
			if _point_segment_distance(pos, center, tip) <= ARM_W * 0.5:
				hit[actor] = true
				break
	for actor in hit.keys():
		if _players.has(actor):
			_damage_player(actor, 5)
		else:
			_damage_enemy(actor, 5)


func _draw() -> void:
	var center := _arena.get_center()
	for arm in range(ARM_COUNT):
		var dir := Vector2.RIGHT.rotated(_angle + TAU * float(arm) / float(ARM_COUNT))
		draw_line(center, center + dir * ARM_LEN, Color(1.0, 0.45, 0.18, 0.58), ARM_W)
	draw_circle(center, 54.0, Color(1.0, 0.62, 0.28, 0.65))
