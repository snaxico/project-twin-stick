class_name AfterburnWake
extends Node2D

const FireTrailZoneData = preload("res://scripts/weapons/FireTrailZone.gd")

var owner_node: Node2D = null
var effects_parent: Node = null
var wake_duration := 3.0
var emit_interval := 0.15
var segment_lifetime := 1.5
var segment_radius := 70.0
var damage := 10
var tick_interval := 0.35
var knockback_force := 80.0
var source_player_index := -1
var _remaining := 0.0
var _emit_accumulator := 0.0


func configure(wake_owner: Node2D, stats: Dictionary, target_parent: Node) -> void:
	owner_node = wake_owner
	effects_parent = target_parent
	wake_duration = maxf(0.1, float(stats.get("duration", wake_duration)))
	emit_interval = maxf(0.05, float(stats.get("wake_emit_interval", emit_interval)))
	segment_lifetime = maxf(0.1, float(stats.get("segment_lifetime", segment_lifetime)))
	segment_radius = maxf(8.0, float(stats.get("trail_radius", segment_radius)))
	damage = maxi(1, int(round(float(stats.get("damage", damage)))))
	tick_interval = maxf(0.1, float(stats.get("tick_interval", tick_interval)))
	knockback_force = maxf(0.0, float(stats.get("knockback_force", knockback_force)))
	source_player_index = int(stats.get("source_player_index", -1))
	_remaining = wake_duration
	_emit_accumulator = emit_interval


func _physics_process(delta: float) -> void:
	if owner_node == null or not is_instance_valid(owner_node) or effects_parent == null or not is_instance_valid(effects_parent):
		queue_free()
		return
	_remaining -= delta
	_emit_accumulator += delta
	while _emit_accumulator >= emit_interval and _remaining > 0.0:
		_emit_accumulator -= emit_interval
		_emit_segment(owner_node.global_position)
	if _remaining <= 0.0:
		queue_free()


func _emit_segment(position: Vector2) -> void:
	var zone := FireTrailZoneData.new()
	zone.global_position = position
	zone.configure(
		segment_radius,
		damage,
		segment_lifetime,
		tick_interval,
		"player",
		knockback_force,
		source_player_index
	)
	effects_parent.add_child(zone)
