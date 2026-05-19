extends Area2D

signal generator_destroyed(generator)
signal hit_received(generator, damage_amount, lethal)
signal spawn_requested(generator, enemy_type)

@export var normal_max_health: int = 100
@export var elite_max_health: int = 140
@export var hit_flash_duration: float = 0.12

var max_health: int = 100
var current_health: int = 100

var _alive := true
var _is_elite := false
var _spawn_interval := 3.2
var _spitter_chance := 0.0
var _next_spawn_at := 0.0
var _rng := RandomNumberGenerator.new()

@onready var body_root: Node2D = $BodyRoot
@onready var visual: Polygon2D = $BodyRoot/Visual
@onready var core: Polygon2D = $BodyRoot/Core
@onready var glow_ring: Line2D = $BodyRoot/GlowRing

func _ready() -> void:
	_apply_visual_state()

func setup(generator_config: Dictionary) -> void:
	_is_elite = bool(generator_config.get("is_elite", false))
	max_health = elite_max_health if _is_elite else normal_max_health
	max_health = max(int(generator_config.get("max_health", max_health)), 1)
	current_health = max_health
	_spawn_interval = max(float(generator_config.get("spawn_interval", 3.2)), 0.6)
	_spitter_chance = clamp(float(generator_config.get("spitter_chance", 0.0)), 0.0, 1.0)
	_rng.randomize()
	_next_spawn_at = _current_time_seconds() + min(_spawn_interval, 1.2)
	_alive = true
	monitoring = true
	monitorable = true
	_apply_visual_state()

func apply_damage(amount: int) -> void:
	if not _alive:
		return
	var applied_damage: int = max(amount, 0)
	if applied_damage <= 0:
		return
	current_health = max(current_health - applied_damage, 0)
	var lethal: bool = current_health <= 0
	_play_hit_flash(lethal)
	hit_received.emit(self, applied_damage, lethal)
	if lethal:
		_destroy()

func is_alive() -> bool:
	return _alive

func get_health_ratio() -> float:
	return clamp(float(current_health) / max(float(max_health), 1.0), 0.0, 1.0)

func get_health_ratio_text() -> String:
	return "%d/%d" % [current_health, max_health]

func _physics_process(_delta: float) -> void:
	if not _alive:
		return
	var now := _current_time_seconds()
	body_root.rotation = sin(now * 1.7) * 0.04
	if now >= _next_spawn_at:
		_next_spawn_at = now + _spawn_interval
		spawn_requested.emit(self, _roll_enemy_type())

func _roll_enemy_type() -> String:
	if _rng.randf() < _spitter_chance:
		return "spitter"
	return "chaser"

func _destroy() -> void:
	if not _alive:
		return
	_alive = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	generator_destroyed.emit(self)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.24, 1.24), 0.14)
	tween.tween_property(self, "modulate:a", 0.0, 0.14)
	tween.finished.connect(queue_free)

func _play_hit_flash(lethal: bool) -> void:
	if visual == null or core == null:
		return
	var base_body_color: Color = visual.color
	var base_core_color: Color = core.color
	visual.color = Color(1.0, 0.94, 0.72, 1.0) if lethal else base_body_color.lightened(0.28)
	core.color = Color(1.0, 0.9, 0.4, 1.0)
	var tween := create_tween()
	tween.tween_property(visual, "color", base_body_color, hit_flash_duration)
	tween.parallel().tween_property(core, "color", base_core_color, hit_flash_duration)

func _apply_visual_state() -> void:
	if visual == null or core == null or glow_ring == null:
		return
	if _is_elite:
		visual.color = Color(0.64, 0.18, 0.18, 1.0)
		core.color = Color(1.0, 0.54, 0.26, 0.96)
		glow_ring.default_color = Color(1.0, 0.5, 0.26, 0.76)
		scale = Vector2(1.08, 1.08)
	else:
		visual.color = Color(0.3, 0.46, 0.22, 1.0)
		core.color = Color(0.84, 0.96, 0.44, 0.92)
		glow_ring.default_color = Color(0.68, 0.92, 0.42, 0.68)
		scale = Vector2.ONE

func _current_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
