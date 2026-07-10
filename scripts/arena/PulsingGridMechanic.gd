extends "res://scripts/arena/ArenaMechanic.gd"

const COLS := 6
const ROWS := 4
const PHASE_PERIOD := 3.0
const TELEGRAPH := 0.5
const DAMAGE_INTERVAL := 0.5
const MINE_TRIGGER := 110.0
const MINE_BLAST := 150.0
const MINE_DMG := 22

var _variant := "fire_grid"
var _t := 0.0
var _dmg_at := 0.0
var _spent_mines: Dictionary = {}


func set_variant(id: String) -> void:
	_variant = id


func _exit_tree() -> void:
	if _variant != "frost_grid":
		return
	for player in _players:
		if player != null and is_instance_valid(player) and player.has_method("clear_zone_modifier"):
			player.clear_zone_modifier("frost_grid")


func _physics_process(delta: float) -> void:
	_t += delta
	_dmg_at -= delta
	var phase := int(floor(_t / PHASE_PERIOD)) % 2
	var phase_t := fmod(_t, PHASE_PERIOD)
	if phase_t < delta + 0.01:
		_spent_mines.clear()
	if _variant == "frost_grid":
		_update_frost_slow(phase, phase_t)
	if _dmg_at <= 0.0:
		_dmg_at = DAMAGE_INTERVAL
		_apply_damage(phase, phase_t)
	queue_redraw()


func _apply_damage(phase: int, phase_t: float) -> void:
	if phase_t < TELEGRAPH:
		return
	for col in range(COLS):
		for row in range(ROWS):
			if (col + row) % 2 != phase:
				continue
			var cell := _cell_rect(col, row)
			match _variant:
				"fire_grid":
					_damage_actors_in_cell(cell, 5)
				"frost_grid":
					_damage_actors_in_cell(cell, 3)
				"mine_grid":
					_try_mine_cell(col, row, cell)


func _damage_actors_in_cell(cell: Rect2, amount: int) -> void:
	for player in _players:
		if player != null and is_instance_valid(player) and player is Node2D and cell.has_point((player as Node2D).global_position):
			_damage_player(player, amount)
	if _coop == null:
		return
	for enemy in _coop.get_nearby_enemy_target_nodes(cell.get_center(), maxf(cell.size.x, cell.size.y)):
		if enemy != null and is_instance_valid(enemy) and enemy is Node2D and cell.has_point((enemy as Node2D).global_position):
			_damage_enemy(enemy, amount)


func _try_mine_cell(col: int, row: int, cell: Rect2) -> void:
	var key := Vector2i(col, row)
	if _spent_mines.has(key):
		return
	var center := cell.get_center()
	var trigger_sq := MINE_TRIGGER * MINE_TRIGGER
	for player in _players:
		if player != null and is_instance_valid(player) and player is Node2D and (player as Node2D).global_position.distance_squared_to(center) <= trigger_sq:
			_spent_mines[key] = true
			damage_circle(center, MINE_BLAST, MINE_DMG)
			return
	if _coop == null:
		return
	for enemy in _coop.get_nearby_enemy_target_nodes(center, MINE_TRIGGER):
		if enemy != null and is_instance_valid(enemy) and enemy is Node2D and (enemy as Node2D).global_position.distance_squared_to(center) <= trigger_sq:
			_spent_mines[key] = true
			damage_circle(center, MINE_BLAST, MINE_DMG)
			return


func _update_frost_slow(phase: int, phase_t: float) -> void:
	var live := phase_t >= TELEGRAPH
	for player in _players:
		if player == null or not is_instance_valid(player) or not (player is Node2D):
			continue
		var inside_any := false
		if live:
			for col in range(COLS):
				for row in range(ROWS):
					if (col + row) % 2 == phase and _cell_rect(col, row).has_point((player as Node2D).global_position):
						inside_any = true
		if inside_any and player.has_method("apply_zone_modifier"):
			player.apply_zone_modifier("frost_grid", 0.5, 1.0)
		elif player.has_method("clear_zone_modifier"):
			player.clear_zone_modifier("frost_grid")


func _cell_rect(col: int, row: int) -> Rect2:
	var cell_size := Vector2(_arena.size.x / float(COLS), _arena.size.y / float(ROWS))
	return Rect2(_arena.position + Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size)


func _draw() -> void:
	var phase := int(floor(_t / PHASE_PERIOD)) % 2
	var phase_t := fmod(_t, PHASE_PERIOD)
	var color := _variant_color()
	for col in range(COLS):
		for row in range(ROWS):
			if (col + row) % 2 != phase:
				continue
			var cell := _cell_rect(col, row)
			var alpha := 0.16 if phase_t < TELEGRAPH else 0.28
			draw_rect(cell, Color(color.r, color.g, color.b, alpha), true)
			draw_rect(cell, Color(color.r, color.g, color.b, 0.65), false, 2.0)
			if _variant == "mine_grid" and not _spent_mines.has(Vector2i(col, row)):
				draw_circle(cell.get_center(), 10.0, Color(color.r, color.g, color.b, 0.9))
				draw_arc(cell.get_center(), MINE_TRIGGER, 0.0, TAU, 32, Color(color.r, color.g, color.b, 0.32), 2.0)


func _variant_color() -> Color:
	match _variant:
		"frost_grid":
			return Color(0.45, 0.82, 1.0, 1.0)
		"mine_grid":
			return Color(1.0, 0.78, 0.25, 1.0)
		_:
			return Color(1.0, 0.32, 0.14, 1.0)
