extends RefCounted

const BLOOM_COLOR_MULTIPLIER := 1.45

static var _particle_texture: Texture2D = null

static func create_muzzle_flash(color: Color, direction: Vector2, profile: String = "rifle", weight: float = 1.0) -> GPUParticles2D:
	var particles := _create_particles()
	particles.amount = 10 + int(round(weight * 4.0))
	particles.lifetime = 0.07 + weight * 0.015
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.speed_scale = 1.1 + weight * 0.12
	particles.modulate = _bloom_color(color)

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(direction.x, direction.y, 0.0)
	material.spread = 30.0 if profile == "scatter" else 10.0 if profile == "slug" else 22.0
	material.initial_velocity_min = 70.0 + weight * 18.0
	material.initial_velocity_max = 130.0 + weight * 30.0
	material.scale_min = 0.7 + weight * 0.12
	material.scale_max = 1.2 + weight * 0.24
	material.damping_min = 10.0
	material.damping_max = 16.0
	particles.process_material = material
	_configure_one_shot(particles)
	return particles

static func create_impact_sparks(color: Color, direction: Vector2, weight: float = 1.0) -> GPUParticles2D:
	var particles := _create_particles()
	particles.amount = 12 + int(round(weight * 11.0))
	particles.lifetime = 0.12 + weight * 0.05 + (0.03 if weight >= 1.35 else 0.0)
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.modulate = _bloom_color(color)

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(direction.x, direction.y, 0.0)
	material.spread = 64.0 + weight * 16.0
	material.initial_velocity_min = 110.0 + weight * 26.0
	material.initial_velocity_max = 220.0 + weight * 54.0
	var heavy_scale_boost: float = 1.25 if weight >= 1.35 else 1.0
	material.scale_min = (0.4 + weight * 0.08) * heavy_scale_boost
	material.scale_max = (0.75 + weight * 0.18) * heavy_scale_boost
	material.damping_min = 8.0
	material.damping_max = 14.0
	particles.process_material = material
	_configure_one_shot(particles)
	return particles

static func create_explosion_burst(color: Color, weight: float = 1.0) -> GPUParticles2D:
	var particles := _create_particles()
	particles.amount = 24 + int(round(weight * 16.0))
	particles.lifetime = 0.22 + weight * 0.08 + (0.05 if weight >= 1.35 else 0.0)
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.modulate = _bloom_color(color)

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(1.0, 0.0, 0.0)
	material.spread = 180.0
	material.initial_velocity_min = 90.0 + weight * 36.0
	material.initial_velocity_max = 210.0 + weight * 72.0
	var heavy_scale_boost: float = 1.25 if weight >= 1.35 else 1.0
	material.scale_min = (0.5 + weight * 0.1) * heavy_scale_boost
	material.scale_max = (1.1 + weight * 0.22) * heavy_scale_boost
	material.damping_min = 7.0
	material.damping_max = 13.0
	particles.process_material = material
	_configure_one_shot(particles)
	return particles

static func create_death_burst(color: Color, weight: float = 1.0) -> GPUParticles2D:
	var particles := _create_particles()
	particles.amount = 40 + int(round(weight * 34.0))
	particles.lifetime = 0.2 + weight * 0.07 + (0.05 if weight >= 1.35 else 0.0)
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.modulate = _bloom_color(color)

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(1.0, 0.0, 0.0)
	material.spread = 180.0
	material.initial_velocity_min = 80.0 + weight * 24.0
	material.initial_velocity_max = 180.0 + weight * 46.0
	var heavy_scale_boost: float = 1.25 if weight >= 1.35 else 1.0
	material.scale_min = (0.48 + weight * 0.1) * heavy_scale_boost
	material.scale_max = (1.05 + weight * 0.2) * heavy_scale_boost
	material.damping_min = 8.0
	material.damping_max = 14.0
	particles.process_material = material
	_configure_one_shot(particles)
	return particles

static func create_debris_ring(color: Color, radius: float = 84.0, spoke_count: int = 12, duration: float = 0.22) -> Node2D:
	var node := Node2D.new()
	for index in range(maxi(spoke_count, 1)):
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / float(maxi(spoke_count, 1)))
		var spoke := Line2D.new()
		spoke.width = 2.0
		spoke.default_color = _bloom_color(color)
		spoke.points = PackedVector2Array([direction * radius * 0.22, direction * radius])
		node.add_child(spoke)
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "scale", Vector2.ONE * 1.2, duration)
	tween.tween_property(node, "modulate:a", 0.0, duration)
	tween.set_parallel(false)
	tween.tween_callback(node.queue_free)
	return node

static func create_dash_trail(color: Color, weight: float = 1.0) -> GPUParticles2D:
	var particles := _create_particles()
	particles.amount = 8 + int(round(weight * 4.0))
	particles.lifetime = 0.14 + weight * 0.05
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.modulate = _bloom_color(color)

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 150.0
	material.initial_velocity_min = 18.0 + weight * 10.0
	material.initial_velocity_max = 45.0 + weight * 18.0
	material.scale_min = 0.45 + weight * 0.05
	material.scale_max = 0.9 + weight * 0.14
	material.damping_min = 3.0
	material.damping_max = 7.0
	particles.process_material = material
	_configure_one_shot(particles)
	return particles

static func create_dash_burst(color: Color, direction: Vector2, weight: float = 1.0) -> GPUParticles2D:
	var particles := _create_particles()
	particles.amount = 16 + int(round(weight * 5.0))
	particles.lifetime = 0.12 + weight * 0.03
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.modulate = _bloom_color(color)

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(-direction.x, -direction.y, 0.0)
	material.spread = 100.0
	material.initial_velocity_min = 70.0 + weight * 20.0
	material.initial_velocity_max = 130.0 + weight * 30.0
	material.scale_min = 0.4 + weight * 0.06
	material.scale_max = 0.9 + weight * 0.14
	material.damping_min = 4.0
	material.damping_max = 9.0
	particles.process_material = material
	_configure_one_shot(particles)
	return particles

static func create_attack_trail(color: Color, direction: Vector2, weight: float = 1.0) -> GPUParticles2D:
	var particles := _create_particles()
	particles.amount = 6 + int(round(weight * 3.0))
	particles.lifetime = 0.10 + min(weight, 2.0) * 0.02
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.modulate = _bloom_color(color)

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(-direction.x, -direction.y, 0.0)
	material.spread = 34.0 + weight * 12.0
	material.initial_velocity_min = 48.0 + weight * 18.0
	material.initial_velocity_max = 84.0 + weight * 28.0
	material.scale_min = 0.45 + weight * 0.06
	material.scale_max = 0.9 + weight * 0.1
	material.damping_min = 6.0
	material.damping_max = 10.0
	particles.process_material = material
	_configure_one_shot(particles)
	return particles

static func create_impact_ring(color: Color, radius: float = 18.0, thickness: float = 3.0) -> Node2D:
	return _create_ring_effect(color, radius, radius * 1.85, 0.13, thickness)

static func create_explosion_ring(color: Color, radius: float = 88.0, thickness: float = 4.0) -> Node2D:
	return _create_ring_effect(color, radius * 0.22, radius * 1.05, 0.26, thickness)

static func create_projectile_trail(color: Color, style: String = "default") -> GPUParticles2D:
	var particles := _create_particles()
	match style:
		"thin", "sharp":
			particles.amount = 14
			particles.lifetime = 0.11
		"short":
			particles.amount = 10
			particles.lifetime = 0.08
		"heavy_slow":
			particles.amount = 30
			particles.lifetime = 0.22
		"embers":
			particles.amount = 36
			particles.lifetime = 0.26
		_:
			particles.amount = 22
			particles.lifetime = 0.16
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.local_coords = false
	particles.modulate = _bloom_color(color)

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, 0.0, 0.0)
	match style:
		"thin":
			material.spread = 70.0
			material.initial_velocity_min = 4.0
			material.initial_velocity_max = 18.0
			material.scale_min = 0.22
			material.scale_max = 0.42
		"short":
			material.spread = 95.0
			material.initial_velocity_min = 2.0
			material.initial_velocity_max = 12.0
			material.scale_min = 0.2
			material.scale_max = 0.36
		"heavy_slow":
			material.spread = 180.0
			material.initial_velocity_min = 0.0
			material.initial_velocity_max = 9.0
			material.scale_min = 0.52
			material.scale_max = 0.95
		"sharp":
			material.spread = 32.0
			material.initial_velocity_min = 10.0
			material.initial_velocity_max = 26.0
			material.scale_min = 0.18
			material.scale_max = 0.32
		"embers":
			material.spread = 160.0
			material.initial_velocity_min = 5.0
			material.initial_velocity_max = 28.0
			material.scale_min = 0.38
			material.scale_max = 0.78
		_:
			material.spread = 180.0
			material.initial_velocity_min = 0.0
			material.initial_velocity_max = 14.0
			material.scale_min = 0.38
			material.scale_max = 0.72
	material.damping_min = 1.5
	material.damping_max = 3.5
	particles.process_material = material
	particles.emitting = true
	return particles

static func create_neon_crescent(color: Color, radius: float, direction: Vector2, arc_degrees: float = 115.0) -> Node2D:
	var node := Node2D.new()
	node.rotation = direction.angle() if direction.length() > 0.0 else 0.0
	var outer := Line2D.new()
	outer.width = 10.0
	outer.antialiased = true
	outer.default_color = _bloom_color(Color(color.r, color.g, color.b, 0.82))
	outer.points = _build_arc_points(radius, deg_to_rad(-arc_degrees * 0.5), deg_to_rad(arc_degrees * 0.5), 18)
	node.add_child(outer)
	var inner := Line2D.new()
	inner.width = 3.0
	inner.antialiased = true
	inner.default_color = _bloom_color(Color(1.0, 1.0, 1.0, 0.72))
	inner.points = outer.points
	node.add_child(inner)
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "rotation", node.rotation + 0.42, 0.16)
	tween.tween_property(node, "modulate:a", 0.0, 0.16)
	tween.set_parallel(false)
	tween.tween_callback(node.queue_free)
	return node

static func create_flame_cone(color: Color, length: float, half_angle: float, direction: Vector2) -> Node2D:
	var node := Node2D.new()
	node.rotation = direction.angle() if direction.length() > 0.0 else 0.0
	var flame := Polygon2D.new()
	flame.color = _bloom_color(Color(color.r, color.g * 0.72, color.b * 0.35, 0.34))
	flame.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2.RIGHT.rotated(-half_angle) * length,
		Vector2(length * 0.82, 0.0),
		Vector2.RIGHT.rotated(half_angle) * length,
	])
	node.add_child(flame)
	var edge := Line2D.new()
	edge.width = 4.0
	edge.antialiased = true
	edge.default_color = _bloom_color(Color(1.0, 0.72, 0.22, 0.62))
	edge.points = PackedVector2Array([Vector2.RIGHT.rotated(-half_angle) * length, Vector2(length * 0.86, 0.0), Vector2.RIGHT.rotated(half_angle) * length])
	node.add_child(edge)
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "scale", Vector2(1.06, 0.92), 0.06)
	tween.tween_property(node, "modulate:a", 0.0, 0.12)
	tween.set_parallel(false)
	tween.tween_callback(node.queue_free)
	return node

static func create_lightning_path(points: PackedVector2Array, color: Color, width: float = 5.0) -> Node2D:
	var node := Node2D.new()
	var line := Line2D.new()
	line.width = width
	line.antialiased = true
	line.default_color = _bloom_color(Color(color.r * 0.68, minf(color.g * 1.25, 1.0), 1.0, 0.9))
	line.points = points
	node.add_child(line)
	var core := Line2D.new()
	core.width = maxf(1.4, width * 0.34)
	core.antialiased = true
	core.default_color = _bloom_color(Color(0.92, 1.0, 1.0, 0.86))
	core.points = points
	node.add_child(core)
	for point in points:
		var ring := _create_ring_effect(color.lightened(0.18), 5.0, 16.0, 0.12, 2.0)
		ring.global_position = point
		node.add_child(ring)
	var tween := node.create_tween()
	tween.tween_property(node, "modulate:a", 0.0, 0.13)
	tween.tween_callback(node.queue_free)
	return node

static func create_zone_pulse(color: Color, radius: float, weight: float = 1.0) -> Node2D:
	var node := Node2D.new()
	var ring := create_explosion_ring(color, radius, 3.0 + weight)
	node.add_child(ring)
	var burst := create_explosion_burst(color, 0.55 + weight * 0.25)
	node.add_child(burst)
	var cleanup := node.create_tween()
	cleanup.tween_interval(0.42)
	cleanup.tween_callback(node.queue_free)
	return node

static func _create_ring_effect(color: Color, start_radius: float, end_radius: float, duration: float, thickness: float) -> Node2D:
	var node := Node2D.new()
	var ring := Line2D.new()
	ring.closed = true
	ring.width = thickness
	ring.default_color = _bloom_color(color)
	ring.points = _build_circle_points(end_radius, 28)
	var safe_end_radius: float = max(end_radius, 0.01)
	var start_scale: float = clamp(start_radius / safe_end_radius, 0.01, 1.0)
	node.scale = Vector2.ONE * start_scale
	node.add_child(ring)
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "scale", Vector2.ONE, duration)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.set_parallel(false)
	tween.tween_callback(node.queue_free)
	return node

static func _create_particles() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.texture = _get_particle_texture()
	particles.local_coords = false
	var canvas_material := CanvasItemMaterial.new()
	canvas_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = canvas_material
	return particles

static func _bloom_color(color: Color) -> Color:
	return Color(color.r * BLOOM_COLOR_MULTIPLIER, color.g * BLOOM_COLOR_MULTIPLIER, color.b * BLOOM_COLOR_MULTIPLIER, color.a)

static func _configure_one_shot(particles: GPUParticles2D) -> void:
	particles.finished.connect(particles.queue_free)
	particles.emitting = true

static func _build_circle_points(radius: float, point_count: int) -> PackedVector2Array:
	var points: Array = []
	for index in range(point_count):
		var angle := TAU * float(index) / float(point_count)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return PackedVector2Array(points)

static func _build_arc_points(radius: float, start_angle: float, end_angle: float, point_count: int) -> PackedVector2Array:
	var points: Array = []
	for index in range(maxi(point_count, 2)):
		var ratio := float(index) / float(maxi(point_count - 1, 1))
		points.append(Vector2.RIGHT.rotated(lerpf(start_angle, end_angle, ratio)) * radius)
	return PackedVector2Array(points)

static func _get_particle_texture() -> Texture2D:
	if _particle_texture != null:
		return _particle_texture

	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in range(8):
		for x in range(8):
			var distance := Vector2(float(x) - 3.5, float(y) - 3.5).length()
			if distance <= 3.5:
				image.set_pixel(x, y, Color.WHITE)
	_particle_texture = ImageTexture.create_from_image(image)
	return _particle_texture
