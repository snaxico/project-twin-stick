extends Node2D

const ProjectileData = preload("res://scripts/weapons/Projectile.gd")

var _projectile_container: Node = null
var _instances_by_shape: Dictionary = {}
var _mesh_by_shape: Dictionary = {}

func set_projectile_container(container: Node) -> void:
	_projectile_container = container

func _physics_process(_delta: float) -> void:
	_update_instances()

func _update_instances() -> void:
	if _projectile_container == null or not is_instance_valid(_projectile_container):
		_hide_all_instances()
		return
	var projectiles_by_shape: Dictionary = {}
	for node in _projectile_container.get_children():
		if node == self:
			continue
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_method("is_projectile_active") or not node.is_projectile_active():
			continue
		var projectile_shape := str(node.projectile_shape)
		if not projectiles_by_shape.has(projectile_shape):
			projectiles_by_shape[projectile_shape] = []
		(projectiles_by_shape[projectile_shape] as Array).append(node)
	for shape_variant in projectiles_by_shape.keys():
		var shape := str(shape_variant)
		_update_shape_instances(shape, projectiles_by_shape[shape] as Array)
	for shape_variant in _instances_by_shape.keys():
		var shape := str(shape_variant)
		if not projectiles_by_shape.has(shape):
			_set_shape_count(shape, 0)

func _update_shape_instances(shape: String, projectiles: Array) -> void:
	var instance := _get_shape_instance(shape)
	var multimesh := instance.multimesh
	multimesh.instance_count = projectiles.size()
	for index in range(projectiles.size()):
		var projectile = projectiles[index]
		var render_scale: Vector2 = projectile.get_render_scale() if projectile.has_method("get_render_scale") else Vector2.ONE
		var instance_transform := Transform2D(float(projectile.direction.angle()), render_scale, 0.0, projectile.global_position)
		multimesh.set_instance_transform_2d(index, instance_transform)
		if projectile.has_method("get_render_color"):
			multimesh.set_instance_color(index, projectile.get_render_color())
	instance.visible = not projectiles.is_empty()

func _get_shape_instance(shape: String) -> MultiMeshInstance2D:
	if _instances_by_shape.has(shape):
		return _instances_by_shape[shape] as MultiMeshInstance2D
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = _get_shape_mesh(shape)
	var instance := MultiMeshInstance2D.new()
	instance.name = "ProjectileShape_%s" % shape
	instance.multimesh = multimesh
	add_child(instance)
	_instances_by_shape[shape] = instance
	return instance

func _get_shape_mesh(shape: String) -> ArrayMesh:
	if _mesh_by_shape.has(shape):
		return _mesh_by_shape[shape] as ArrayMesh
	var polygon := ProjectileData.build_shape_polygon(shape)
	var indices := Geometry2D.triangulate_polygon(polygon)
	var vertices := PackedVector3Array()
	for point in polygon:
		vertices.append(Vector3(point.x, point.y, 0.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_by_shape[shape] = mesh
	return mesh

func _set_shape_count(shape: String, count: int) -> void:
	if not _instances_by_shape.has(shape):
		return
	var instance := _instances_by_shape[shape] as MultiMeshInstance2D
	instance.multimesh.instance_count = count
	instance.visible = count > 0

func _hide_all_instances() -> void:
	for shape_variant in _instances_by_shape.keys():
		_set_shape_count(str(shape_variant), 0)
