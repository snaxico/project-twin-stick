extends Area2D

signal pickup_collected(pickup, collector, pickup_type, value)

@export var magnet_radius: float = 56.0
@export var gold_pull_speed: float = 240.0
@export var food_pull_speed: float = 220.0
@export var bob_amount: float = 4.0
@export var bob_speed: float = 3.2

var pickup_type: String = "gold"
var value: int = 1

var _spawn_position := Vector2.ZERO
var _spawn_time := 0.0
var _is_collected := false

@onready var visual: Polygon2D = $Visual
@onready var outline: Line2D = $Outline
@onready var shadow: Polygon2D = $Shadow

func setup(next_pickup_type: String, next_value: int = 1) -> void:
	pickup_type = next_pickup_type
	value = max(next_value, 1)
	_spawn_position = global_position
	_spawn_time = _current_time_seconds()
	_apply_visual_state()

func collect(collector) -> void:
	if _is_collected:
		return
	if pickup_type == "food" and not _can_collect_food(collector):
		return
	_is_collected = true
	pickup_collected.emit(self, collector, pickup_type, value)
	queue_free()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_spawn_position = global_position
	_spawn_time = _current_time_seconds()
	_apply_visual_state()

func _physics_process(delta: float) -> void:
	if _is_collected:
		return
	var target: Node = _find_magnet_target()
	if target != null:
		var to_target: Vector2 = target.global_position - global_position
		var distance: float = to_target.length()
		if distance <= 18.0:
			collect(target)
			return
		if distance <= magnet_radius and distance > 0.001:
			var pull_speed := gold_pull_speed if pickup_type == "gold" else food_pull_speed
			global_position += to_target.normalized() * min(pull_speed * delta, distance)
			return
	var bob_offset := sin((_current_time_seconds() - _spawn_time) * bob_speed) * bob_amount
	global_position = _spawn_position + Vector2(0.0, bob_offset)

func _on_body_entered(body: Node) -> void:
	collect(body)

func _find_magnet_target():
	var candidates := get_tree().get_nodes_in_group("player_target")
	var best_target = null
	var best_distance := magnet_radius
	for candidate in candidates:
		if not is_instance_valid(candidate):
			continue
		if not _can_collect_candidate(candidate):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance <= best_distance:
			best_distance = distance
			best_target = candidate
	return best_target

func _can_collect_candidate(candidate) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false
	if candidate.has_method("is_alive") and not candidate.is_alive():
		return false
	if pickup_type == "food":
		return _can_collect_food(candidate)
	return true

func _can_collect_food(candidate) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false
	if candidate.has_method("is_alive") and not candidate.is_alive():
		return false
	if not candidate.has_method("get_health_state"):
		return false
	var health_state: Dictionary = candidate.get_health_state()
	return int(health_state.get("current", 0)) < int(health_state.get("max", 0))

func _apply_visual_state() -> void:
	if visual == null or outline == null or shadow == null:
		return
	if pickup_type == "food":
		visual.color = Color(0.74, 0.92, 0.32, 0.98)
		visual.polygon = PackedVector2Array([
			Vector2(-14, -6),
			Vector2(-4, -6),
			Vector2(-4, -16),
			Vector2(4, -16),
			Vector2(4, -6),
			Vector2(14, -6),
			Vector2(14, 6),
			Vector2(4, 6),
			Vector2(4, 16),
			Vector2(-4, 16),
			Vector2(-4, 6),
			Vector2(-14, 6),
		])
		outline.default_color = Color(0.1, 0.22, 0.08, 0.84)
	else:
		visual.color = Color(1.0, 0.84, 0.24, 0.98)
		visual.polygon = PackedVector2Array([
			Vector2(0, -16),
			Vector2(12, 0),
			Vector2(0, 16),
			Vector2(-12, 0),
		])
		outline.default_color = Color(0.32, 0.2, 0.04, 0.84)
	outline.points = visual.polygon
	shadow.polygon = visual.polygon

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
