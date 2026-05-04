extends RefCounted

static var _particle_texture: Texture2D = null

static func create_muzzle_flash(color: Color, direction: Vector2) -> GPUParticles2D:
	var particles := _create_particles()
	particles.amount = 10
	particles.lifetime = 0.08
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.speed_scale = 1.2
	particles.modulate = color

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(direction.x, direction.y, 0.0)
	material.spread = 22.0
	material.initial_velocity_min = 70.0
	material.initial_velocity_max = 130.0
	material.scale_min = 0.8
	material.scale_max = 1.35
	material.damping_min = 10.0
	material.damping_max = 16.0
	particles.process_material = material
	_configure_one_shot(particles)
	return particles

static func create_impact_sparks(color: Color, direction: Vector2) -> GPUParticles2D:
	var particles := _create_particles()
	particles.amount = 16
	particles.lifetime = 0.16
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.modulate = color

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(direction.x, direction.y, 0.0)
	material.spread = 80.0
	material.initial_velocity_min = 110.0
	material.initial_velocity_max = 220.0
	material.scale_min = 0.4
	material.scale_max = 0.75
	material.damping_min = 8.0
	material.damping_max = 14.0
	particles.process_material = material
	_configure_one_shot(particles)
	return particles

static func create_explosion_burst(color: Color) -> GPUParticles2D:
	var particles := _create_particles()
	particles.amount = 28
	particles.lifetime = 0.28
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.modulate = color

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(1.0, 0.0, 0.0)
	material.spread = 180.0
	material.initial_velocity_min = 90.0
	material.initial_velocity_max = 210.0
	material.scale_min = 0.5
	material.scale_max = 1.1
	material.damping_min = 7.0
	material.damping_max = 13.0
	particles.process_material = material
	_configure_one_shot(particles)
	return particles

static func create_death_burst(color: Color) -> GPUParticles2D:
	var particles := _create_particles()
	particles.amount = 18
	particles.lifetime = 0.22
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.modulate = color

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(1.0, 0.0, 0.0)
	material.spread = 180.0
	material.initial_velocity_min = 80.0
	material.initial_velocity_max = 180.0
	material.scale_min = 0.4
	material.scale_max = 0.9
	material.damping_min = 8.0
	material.damping_max = 14.0
	particles.process_material = material
	_configure_one_shot(particles)
	return particles

static func create_dash_trail(color: Color) -> GPUParticles2D:
	var particles := _create_particles()
	particles.amount = 8
	particles.lifetime = 0.18
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.modulate = color

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 150.0
	material.initial_velocity_min = 18.0
	material.initial_velocity_max = 45.0
	material.scale_min = 0.45
	material.scale_max = 0.9
	material.damping_min = 3.0
	material.damping_max = 7.0
	particles.process_material = material
	_configure_one_shot(particles)
	return particles

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

static func _create_particles() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.texture = _get_particle_texture()
	particles.local_coords = false
	return particles

static func _configure_one_shot(particles: GPUParticles2D) -> void:
	particles.finished.connect(particles.queue_free)
	particles.emitting = true

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
