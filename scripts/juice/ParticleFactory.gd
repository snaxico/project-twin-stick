extends RefCounted

static var _particle_texture: Texture2D = null

static func create_muzzle_flash(color: Color, direction: Vector2, profile: String = "rifle", weight: float = 1.0) -> GPUParticles2D:
	var particles := _create_particles()
	particles.amount = 10 + int(round(weight * 4.0))
	particles.lifetime = 0.07 + weight * 0.015
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.speed_scale = 1.1 + weight * 0.12
	particles.modulate = color

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
	particles.amount = 12 + int(round(weight * 8.0))
	particles.lifetime = 0.12 + weight * 0.05
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.modulate = color

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(direction.x, direction.y, 0.0)
	material.spread = 64.0 + weight * 16.0
	material.initial_velocity_min = 110.0 + weight * 26.0
	material.initial_velocity_max = 220.0 + weight * 54.0
	material.scale_min = 0.4 + weight * 0.08
	material.scale_max = 0.75 + weight * 0.18
	material.damping_min = 8.0
	material.damping_max = 14.0
	particles.process_material = material
	_configure_one_shot(particles)
	return particles

static func create_explosion_burst(color: Color, weight: float = 1.0) -> GPUParticles2D:
	var particles := _create_particles()
	particles.amount = 24 + int(round(weight * 12.0))
	particles.lifetime = 0.22 + weight * 0.08
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.modulate = color

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(1.0, 0.0, 0.0)
	material.spread = 180.0
	material.initial_velocity_min = 90.0 + weight * 36.0
	material.initial_velocity_max = 210.0 + weight * 72.0
	material.scale_min = 0.5 + weight * 0.1
	material.scale_max = 1.1 + weight * 0.22
	material.damping_min = 7.0
	material.damping_max = 13.0
	particles.process_material = material
	_configure_one_shot(particles)
	return particles

static func create_death_burst(color: Color, weight: float = 1.0) -> GPUParticles2D:
	var particles := _create_particles()
	particles.amount = 16 + int(round(weight * 10.0))
	particles.lifetime = 0.18 + weight * 0.06
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.modulate = color

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(1.0, 0.0, 0.0)
	material.spread = 180.0
	material.initial_velocity_min = 80.0 + weight * 24.0
	material.initial_velocity_max = 180.0 + weight * 46.0
	material.scale_min = 0.4 + weight * 0.08
	material.scale_max = 0.9 + weight * 0.16
	material.damping_min = 8.0
	material.damping_max = 14.0
	particles.process_material = material
	_configure_one_shot(particles)
	return particles

static func create_dash_trail(color: Color, weight: float = 1.0) -> GPUParticles2D:
	var particles := _create_particles()
	particles.amount = 8 + int(round(weight * 4.0))
	particles.lifetime = 0.14 + weight * 0.05
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.modulate = color

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
	particles.modulate = color

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

static func create_impact_ring(color: Color, radius: float = 18.0, thickness: float = 3.0) -> Node2D:
	return _create_ring_effect(color, radius, radius * 1.7, 0.14, thickness)

static func create_explosion_ring(color: Color, radius: float = 88.0, thickness: float = 4.0) -> Node2D:
	return _create_ring_effect(color, radius * 0.24, radius, 0.28, thickness)

static func create_projectile_trail(color: Color) -> GPUParticles2D:
	var particles := _create_particles()
	particles.amount = 16
	particles.lifetime = 0.12
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.local_coords = false
	particles.modulate = color

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, 0.0, 0.0)
	material.spread = 180.0
	material.initial_velocity_min = 0.0
	material.initial_velocity_max = 8.0
	material.scale_min = 0.3
	material.scale_max = 0.55
	material.damping_min = 1.5
	material.damping_max = 3.5
	particles.process_material = material
	particles.emitting = true
	return particles

static func _create_ring_effect(color: Color, start_radius: float, end_radius: float, duration: float, thickness: float) -> Node2D:
	var node := Node2D.new()
	var ring := Line2D.new()
	ring.closed = true
	ring.width = thickness
	ring.default_color = color
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
	return particles

static func _configure_one_shot(particles: GPUParticles2D) -> void:
	particles.finished.connect(particles.queue_free)
	particles.emitting = true

static func _build_circle_points(radius: float, point_count: int) -> PackedVector2Array:
	var points: Array = []
	for index in range(point_count):
		var angle := TAU * float(index) / float(point_count)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
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
