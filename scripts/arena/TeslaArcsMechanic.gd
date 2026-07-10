extends "res://scripts/arena/ArenaMechanic.gd"

const PYLONS := [Vector2(820, 560), Vector2(2780, 560), Vector2(820, 1540), Vector2(2780, 1540)]
const PAIR_SCHEDULE := [[[0, 1], [2, 3]], [[0, 2], [1, 3]], [[0, 3], [1, 2]]]
const ARC_PERIOD := 2.6
const TELEGRAPH := 0.6
const ACTIVE := 1.0
const TICK := 0.4
const ARC_W := 46.0

var _t := 0.0
var _tick := TICK


func _physics_process(delta: float) -> void:
	_t += delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_apply_hits()
	queue_redraw()


func _apply_hits() -> void:
	var phase_t := fmod(_t, ARC_PERIOD)
	if phase_t < TELEGRAPH or phase_t > TELEGRAPH + ACTIVE:
		return
	var schedule: Array = PAIR_SCHEDULE[int(floor(_t / ARC_PERIOD)) % PAIR_SCHEDULE.size()]
	var hit: Dictionary = {}
	var candidates := _players.duplicate()
	if _coop != null:
		candidates.append_array(_coop.get_enemy_target_nodes())
	for actor in candidates:
		if actor == null or not is_instance_valid(actor) or not (actor is Node2D):
			continue
		var pos := (actor as Node2D).global_position
		for pair_variant in schedule:
			var pair: Array = pair_variant as Array
			if _point_segment_distance(pos, PYLONS[int(pair[0])], PYLONS[int(pair[1])]) <= ARC_W:
				hit[actor] = true
				break
	for actor in hit.keys():
		if _players.has(actor):
			_damage_player(actor, 6)
		else:
			_damage_enemy(actor, 6)


func _draw() -> void:
	var phase_t := fmod(_t, ARC_PERIOD)
	var schedule: Array = PAIR_SCHEDULE[int(floor(_t / ARC_PERIOD)) % PAIR_SCHEDULE.size()]
	for p in PYLONS:
		draw_circle(p, 22.0, Color(0.55, 0.9, 1.0, 0.8))
	var live := phase_t >= TELEGRAPH and phase_t <= TELEGRAPH + ACTIVE
	var color := Color(0.48, 0.92, 1.0, 0.86 if live else 0.28)
	for pair_variant in schedule:
		var pair: Array = pair_variant as Array
		draw_line(PYLONS[int(pair[0])], PYLONS[int(pair[1])], color, ARC_W if live else 10.0)
