class_name DeployableNode
extends Node2D

var max_health := 100
var current_health := 100
var _deployable_alive := true
var _deployable_targetable := true

func configure_deployable_health(health_amount: int, targetable: bool = true) -> void:
	max_health = maxi(1, health_amount)
	current_health = max_health
	_deployable_alive = true
	_deployable_targetable = targetable
	add_to_group("player_deployable")
	queue_redraw()

func is_alive() -> bool:
	return _deployable_alive

func is_targetable() -> bool:
	return _deployable_alive and _deployable_targetable

func get_team() -> String:
	return "player"

func can_receive_damage() -> bool:
	return _deployable_alive

func apply_damage(amount: int) -> void:
	if not _deployable_alive or amount <= 0:
		return
	current_health = maxi(0, current_health - amount)
	if current_health <= 0:
		destroy_deployable()
		return
	queue_redraw()

func heal_deployable(amount: int) -> void:
	if not _deployable_alive or amount <= 0:
		return
	current_health = mini(max_health, current_health + amount)
	queue_redraw()

func destroy_deployable() -> void:
	if not _deployable_alive:
		return
	_deployable_alive = false
	_remove_deployable_groups()
	_on_deployable_destroyed()
	queue_free()

func despawn_deployable() -> void:
	_deployable_alive = false
	_remove_deployable_groups()
	queue_free()

func _remove_deployable_groups() -> void:
	if is_in_group("player_deployable"):
		remove_from_group("player_deployable")

func _on_deployable_destroyed() -> void:
	pass

func _draw_deployable_health_bar(y_offset: float, width: float = 36.0) -> void:
	if max_health <= 0 or current_health >= max_health:
		return
	var ratio := clampf(float(current_health) / float(max_health), 0.0, 1.0)
	var left := -width * 0.5
	draw_rect(Rect2(Vector2(left, y_offset), Vector2(width, 4.0)), Color(0.08, 0.12, 0.16, 0.72))
	draw_rect(Rect2(Vector2(left, y_offset), Vector2(width * ratio, 4.0)), Color(0.3, 1.0, 0.72, 0.92))
