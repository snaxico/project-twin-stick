class_name Mine
extends Node2D

const ExplosionEffectData = preload("res://scripts/modifiers/MineExplosionEffect.gd")

const TRIGGER_RADIUS := 84.0
const EXPLOSION_RADIUS := 86.0
const DETONATE_DELAY := 0.2
const DAMAGE := 10

var _detonating := false
var _detonate_timer := 0.0
var _active := true

func arm() -> void:
	_active = true
	queue_redraw()

func deactivate() -> void:
	_active = false
	queue_free()

func update_mine(delta: float, player_nodes: Array) -> void:
	if not _active:
		return
	if _detonating:
		_detonate_timer -= delta
		if _detonate_timer <= 0.0:
			for player in player_nodes:
				if player == null or not is_instance_valid(player) or not player.has_method("is_alive") or not player.is_alive():
					continue
				if player.global_position.distance_to(global_position) <= EXPLOSION_RADIUS:
					player.apply_damage(DAMAGE)
			_spawn_explosion_effect()
			queue_free()
			return
		queue_redraw()
		return
	for player in player_nodes:
		if player == null or not is_instance_valid(player) or not player.has_method("is_alive") or not player.is_alive():
			continue
		if player.global_position.distance_to(global_position) <= TRIGGER_RADIUS:
			_detonating = true
			_detonate_timer = DETONATE_DELAY
			queue_redraw()
			return

func _spawn_explosion_effect() -> void:
	var effect := ExplosionEffectData.new()
	effect.global_position = global_position
	get_tree().current_scene.add_child(effect)
	effect.play(EXPLOSION_RADIUS)

func _draw() -> void:
	var body_color := Color(0.82, 0.18, 0.16, 0.92) if _detonating else Color(0.94, 0.62, 0.18, 0.9)
	var ring_color := Color(1.0, 0.94, 0.6, 0.96) if _detonating else Color(1.0, 0.88, 0.38, 0.7)
	draw_circle(Vector2.ZERO, 16.0, body_color)
	draw_arc(Vector2.ZERO, TRIGGER_RADIUS, 0.0, TAU, 32, ring_color, 3.0)
