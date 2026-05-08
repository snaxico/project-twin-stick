class_name IconFactory
extends RefCounted

const ICON_SIZE: int = 64
const UI_ICON_SIZE: int = 32

const REAL_WEAPON_TEXTURE_PATHS: Dictionary = {
	"rifle": "res://assets/sprites/weapons/player_rifle.png",
	"scatter": "res://assets/sprites/weapons/player_scattergun.png",
	"slug": "res://assets/sprites/weapons/player_slug.png",
}

const PASSIVE_CATEGORY_COLORS: Dictionary = {
	"overclocked_receiver": Color(0.95, 0.85, 0.25, 1.0),
	"rapid_loader": Color(0.95, 0.85, 0.25, 1.0),
	"tungsten_cores": Color(0.9, 0.35, 0.3, 1.0),
	"charged_payload": Color(0.9, 0.35, 0.3, 1.0),
	"chain_reaction": Color(0.9, 0.35, 0.3, 1.0),
	"high_velocity_rounds": Color(0.9, 0.35, 0.3, 1.0),
	"velocity_rig": Color(0.5, 0.75, 0.95, 1.0),
	"blast_amplifier": Color(0.85, 0.4, 0.75, 1.0),
	"quick_deploy": Color(0.4, 0.85, 0.45, 1.0),
	"quick_release_valve": Color(0.4, 0.85, 0.45, 1.0),
	"armor_piercing_rounds": Color(0.85, 0.88, 0.92, 1.0),
	"ember_bloom": Color(0.6, 0.4, 0.9, 1.0),
	"feedback_arc": Color(0.6, 0.4, 0.9, 1.0),
	"culling_burst": Color(0.6, 0.4, 0.9, 1.0),
	"detonation_web": Color(0.6, 0.4, 0.9, 1.0),
	"ablative_coating": Color(0.9, 0.55, 0.6, 1.0),
	"reinforced_plating": Color(0.9, 0.55, 0.6, 1.0),
	"sprint_servos": Color(0.3, 0.8, 0.7, 1.0),
}

const PASSIVE_MARKERS: Dictionary = {
	"overclocked_receiver": "line",
	"rapid_loader": "double_line",
	"tungsten_cores": "dot",
	"charged_payload": "cross",
	"chain_reaction": "ring",
	"high_velocity_rounds": "slash",
	"velocity_rig": "vertical",
	"blast_amplifier": "burst",
	"quick_deploy": "chevron",
	"quick_release_valve": "double_chevron",
	"armor_piercing_rounds": "pierce",
	"ember_bloom": "triangle",
	"feedback_arc": "zigzag",
	"culling_burst": "burst",
	"detonation_web": "web",
	"ablative_coating": "shield",
	"reinforced_plating": "plate",
	"sprint_servos": "wing",
}

static var _texture_cache: Dictionary = {}

static func get_weapon_icon(weapon_id: String) -> Texture2D:
	var normalized_id: String = weapon_id.strip_edges().to_lower()
	if normalized_id.is_empty():
		return null
	var real_texture: Texture2D = _get_real_weapon_texture(normalized_id)
	if real_texture != null:
		return real_texture
	var cache_key: String = "weapon:%s" % normalized_id
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key] as Texture2D
	var texture: Texture2D = _build_weapon_icon(normalized_id)
	_texture_cache[cache_key] = texture
	return texture

static func get_passive_icon(passive_id: String) -> Texture2D:
	var normalized_id: String = passive_id.strip_edges().to_lower()
	if normalized_id.is_empty():
		return null
	var cache_key: String = "passive:%s" % normalized_id
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key] as Texture2D
	var texture: Texture2D = _build_passive_icon(normalized_id)
	_texture_cache[cache_key] = texture
	return texture

static func get_ui_icon(icon_name: String) -> Texture2D:
	var normalized_name: String = icon_name.strip_edges().to_lower()
	if normalized_name.is_empty():
		return null
	var cache_key: String = "ui:%s" % normalized_name
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key] as Texture2D
	var texture: Texture2D = _build_ui_icon(normalized_name)
	_texture_cache[cache_key] = texture
	return texture

static func _get_real_weapon_texture(weapon_id: String) -> Texture2D:
	if not REAL_WEAPON_TEXTURE_PATHS.has(weapon_id):
		return null
	var path: String = str(REAL_WEAPON_TEXTURE_PATHS[weapon_id])
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

static func _build_weapon_icon(weapon_id: String) -> Texture2D:
	var image: Image = Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	if weapon_id.contains("mine"):
		_draw_secondary_icon(image, weapon_id)
	elif weapon_id.contains("grenade"):
		_draw_secondary_icon(image, weapon_id)
	else:
		_draw_primary_icon(image, weapon_id)
	return ImageTexture.create_from_image(image)

static func _build_passive_icon(passive_id: String) -> Texture2D:
	var image: Image = Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var base_color: Color = PASSIVE_CATEGORY_COLORS.get(passive_id, Color(0.72, 0.8, 0.9, 1.0))
	_draw_diamond(image, Vector2(32.0, 32.0), 24.0, base_color)
	_draw_diamond_outline(image, Vector2(32.0, 32.0), 24.0, Color(0.08, 0.1, 0.14, 0.82), 2.0)
	_draw_passive_marker(image, passive_id)
	return ImageTexture.create_from_image(image)

static func _build_ui_icon(icon_name: String) -> Texture2D:
	var image: Image = Image.create(UI_ICON_SIZE, UI_ICON_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	match icon_name:
		"heart":
			_draw_heart_icon(image)
		_:
			_draw_coin_icon(image)
	return ImageTexture.create_from_image(image)

static func _draw_primary_icon(image: Image, weapon_id: String) -> void:
	var base_color: Color = Color(0.56, 0.7, 0.92, 1.0)
	match weapon_id:
		"incinerator":
			base_color = Color(0.96, 0.55, 0.15, 1.0)
		"beam_lance":
			base_color = Color(0.3, 0.85, 0.95, 1.0)
		"arc_caster":
			base_color = Color(0.4, 0.5, 1.0, 1.0)
	_draw_rounded_rect(image, Rect2(10.0, 16.0, 44.0, 32.0), 8.0, base_color)
	_draw_rounded_rect_outline(image, Rect2(10.0, 16.0, 44.0, 32.0), 8.0, Color(0.08, 0.1, 0.14, 0.9), 2.0)
	match weapon_id:
		"incinerator":
			_draw_triangle(image, Vector2(26.0, 17.0), Vector2(32.0, 8.0), Vector2(38.0, 17.0), Color(1.0, 0.84, 0.35, 0.95))
		"beam_lance":
			_draw_line_thick(image, Vector2(16.0, 32.0), Vector2(48.0, 32.0), 4.0, Color(0.94, 1.0, 1.0, 0.92))
		"arc_caster":
			var zigzag_points: Array = [
				Vector2(18.0, 38.0),
				Vector2(24.0, 26.0),
				Vector2(31.0, 34.0),
				Vector2(38.0, 22.0),
				Vector2(46.0, 30.0),
			]
			for index in range(zigzag_points.size() - 1):
				_draw_line_thick(image, zigzag_points[index], zigzag_points[index + 1], 3.0, Color(0.94, 0.98, 1.0, 0.96))
		_:
			_draw_line_thick(image, Vector2(18.0, 32.0), Vector2(46.0, 32.0), 3.0, Color(0.94, 0.98, 1.0, 0.86))

static func _draw_secondary_icon(image: Image, weapon_id: String) -> void:
	var base_color: Color = Color(0.7, 0.75, 0.3, 1.0)
	match weapon_id:
		"cluster_grenade":
			base_color = Color(0.6, 0.65, 0.25, 1.0)
		"siege_grenade":
			base_color = Color(0.85, 0.55, 0.2, 1.0)
		"mine":
			base_color = Color(0.55, 0.6, 0.65, 1.0)
		"shrapnel_mine":
			base_color = Color(0.45, 0.5, 0.55, 1.0)
		"heavy_mine":
			base_color = Color(0.7, 0.5, 0.35, 1.0)
	_draw_filled_circle(image, Vector2(32.0, 34.0), 18.0, base_color)
	_draw_ring(image, Vector2(32.0, 34.0), 18.0, 2.0, Color(0.08, 0.1, 0.14, 0.92))
	match weapon_id:
		"grenade":
			_draw_line_thick(image, Vector2(32.0, 10.0), Vector2(32.0, 18.0), 3.0, Color(0.16, 0.2, 0.1, 0.94))
			_draw_line_thick(image, Vector2(28.0, 14.0), Vector2(36.0, 14.0), 3.0, Color(0.16, 0.2, 0.1, 0.94))
		"cluster_grenade":
			_draw_filled_circle(image, Vector2(24.0, 30.0), 3.0, Color(0.12, 0.14, 0.08, 0.92))
			_draw_filled_circle(image, Vector2(32.0, 24.0), 3.0, Color(0.12, 0.14, 0.08, 0.92))
			_draw_filled_circle(image, Vector2(40.0, 30.0), 3.0, Color(0.12, 0.14, 0.08, 0.92))
		"siege_grenade":
			_draw_line_thick(image, Vector2(32.0, 8.0), Vector2(32.0, 20.0), 4.0, Color(0.2, 0.12, 0.08, 0.96))
			_draw_line_thick(image, Vector2(26.0, 14.0), Vector2(38.0, 14.0), 4.0, Color(0.2, 0.12, 0.08, 0.96))
		"mine":
			_draw_spikes(image, Vector2(32.0, 34.0), 18.0, 4, 6.0, Color(0.14, 0.18, 0.22, 0.96))
		"shrapnel_mine":
			_draw_spikes(image, Vector2(32.0, 34.0), 18.0, 8, 5.0, Color(0.12, 0.16, 0.2, 0.96))
		"heavy_mine":
			_draw_spikes(image, Vector2(32.0, 34.0), 18.0, 4, 7.0, Color(0.2, 0.14, 0.1, 0.96))
			_draw_ring(image, Vector2(32.0, 34.0), 10.0, 2.0, Color(0.26, 0.18, 0.12, 0.94))

static func _draw_passive_marker(image: Image, passive_id: String) -> void:
	var marker_color: Color = Color(0.08, 0.1, 0.14, 0.88)
	match str(PASSIVE_MARKERS.get(passive_id, "dot")):
		"line":
			_draw_line_thick(image, Vector2(20.0, 32.0), Vector2(44.0, 32.0), 4.0, marker_color)
		"double_line":
			_draw_line_thick(image, Vector2(18.0, 28.0), Vector2(46.0, 28.0), 3.0, marker_color)
			_draw_line_thick(image, Vector2(18.0, 36.0), Vector2(46.0, 36.0), 3.0, marker_color)
		"dot":
			_draw_filled_circle(image, Vector2(32.0, 32.0), 5.0, marker_color)
		"cross":
			_draw_line_thick(image, Vector2(22.0, 22.0), Vector2(42.0, 42.0), 3.0, marker_color)
			_draw_line_thick(image, Vector2(42.0, 22.0), Vector2(22.0, 42.0), 3.0, marker_color)
		"ring":
			_draw_ring(image, Vector2(32.0, 32.0), 10.0, 3.0, marker_color)
		"slash":
			_draw_line_thick(image, Vector2(22.0, 42.0), Vector2(42.0, 22.0), 3.0, marker_color)
		"vertical":
			_draw_line_thick(image, Vector2(32.0, 20.0), Vector2(32.0, 44.0), 4.0, marker_color)
		"burst":
			_draw_line_thick(image, Vector2(20.0, 32.0), Vector2(44.0, 32.0), 3.0, marker_color)
			_draw_line_thick(image, Vector2(32.0, 20.0), Vector2(32.0, 44.0), 3.0, marker_color)
			_draw_line_thick(image, Vector2(24.0, 24.0), Vector2(40.0, 40.0), 3.0, marker_color)
			_draw_line_thick(image, Vector2(40.0, 24.0), Vector2(24.0, 40.0), 3.0, marker_color)
		"chevron":
			_draw_line_thick(image, Vector2(22.0, 36.0), Vector2(32.0, 24.0), 3.0, marker_color)
			_draw_line_thick(image, Vector2(32.0, 24.0), Vector2(42.0, 36.0), 3.0, marker_color)
		"double_chevron":
			_draw_line_thick(image, Vector2(18.0, 38.0), Vector2(28.0, 26.0), 3.0, marker_color)
			_draw_line_thick(image, Vector2(28.0, 26.0), Vector2(38.0, 38.0), 3.0, marker_color)
			_draw_line_thick(image, Vector2(26.0, 38.0), Vector2(36.0, 26.0), 3.0, marker_color)
			_draw_line_thick(image, Vector2(36.0, 26.0), Vector2(46.0, 38.0), 3.0, marker_color)
		"pierce":
			_draw_line_thick(image, Vector2(22.0, 32.0), Vector2(42.0, 32.0), 4.0, marker_color)
			_draw_triangle(image, Vector2(42.0, 26.0), Vector2(50.0, 32.0), Vector2(42.0, 38.0), marker_color)
		"triangle":
			_draw_triangle(image, Vector2(32.0, 20.0), Vector2(44.0, 40.0), Vector2(20.0, 40.0), marker_color)
		"zigzag":
			_draw_line_thick(image, Vector2(18.0, 36.0), Vector2(26.0, 24.0), 3.0, marker_color)
			_draw_line_thick(image, Vector2(26.0, 24.0), Vector2(34.0, 36.0), 3.0, marker_color)
			_draw_line_thick(image, Vector2(34.0, 36.0), Vector2(46.0, 20.0), 3.0, marker_color)
		"web":
			_draw_ring(image, Vector2(32.0, 32.0), 9.0, 2.0, marker_color)
			_draw_line_thick(image, Vector2(32.0, 18.0), Vector2(32.0, 46.0), 2.0, marker_color)
			_draw_line_thick(image, Vector2(18.0, 32.0), Vector2(46.0, 32.0), 2.0, marker_color)
		"shield":
			_draw_triangle(image, Vector2(24.0, 24.0), Vector2(40.0, 24.0), Vector2(32.0, 42.0), marker_color)
		"plate":
			_draw_rounded_rect(image, Rect2(22.0, 24.0, 20.0, 16.0), 4.0, marker_color)
		"wing":
			_draw_line_thick(image, Vector2(18.0, 36.0), Vector2(30.0, 24.0), 3.0, marker_color)
			_draw_line_thick(image, Vector2(30.0, 24.0), Vector2(44.0, 30.0), 3.0, marker_color)
		_:
			_draw_filled_circle(image, Vector2(32.0, 32.0), 5.0, marker_color)

static func _draw_coin_icon(image: Image) -> void:
	_draw_filled_circle(image, Vector2(16.0, 16.0), 11.0, Color(1.0, 0.84, 0.24, 1.0))
	_draw_ring(image, Vector2(16.0, 16.0), 11.0, 2.0, Color(0.45, 0.28, 0.04, 0.95))
	_draw_ring(image, Vector2(16.0, 16.0), 6.0, 2.0, Color(1.0, 0.94, 0.58, 0.92))

static func _draw_heart_icon(image: Image) -> void:
	var heart_color: Color = Color(0.9, 0.3, 0.35, 1.0)
	_draw_filled_circle(image, Vector2(11.0, 12.0), 6.0, heart_color)
	_draw_filled_circle(image, Vector2(21.0, 12.0), 6.0, heart_color)
	_draw_triangle(image, Vector2(6.0, 14.0), Vector2(26.0, 14.0), Vector2(16.0, 28.0), heart_color)

static func _draw_spikes(image: Image, center: Vector2, radius: float, spike_count: int, spike_length: float, color: Color) -> void:
	for spike_index in range(spike_count):
		var angle: float = TAU * float(spike_index) / float(spike_count)
		var inner: Vector2 = center + Vector2.RIGHT.rotated(angle) * radius
		var outer: Vector2 = center + Vector2.RIGHT.rotated(angle) * (radius + spike_length)
		_draw_line_thick(image, inner, outer, 3.0, color)

static func _draw_rounded_rect(image: Image, rect: Rect2, radius: float, color: Color) -> void:
	var left: int = int(rect.position.x)
	var top: int = int(rect.position.y)
	var right: int = int(rect.position.x + rect.size.x)
	var bottom: int = int(rect.position.y + rect.size.y)
	for y in range(top, bottom):
		for x in range(left, right):
			var px: float = float(x) + 0.5
			var py: float = float(y) + 0.5
			if _point_in_rounded_rect(px, py, rect, radius):
				image.set_pixel(x, y, color)

static func _draw_rounded_rect_outline(image: Image, rect: Rect2, radius: float, color: Color, thickness: float) -> void:
	var outer: Rect2 = rect
	var inner: Rect2 = Rect2(rect.position + Vector2(thickness, thickness), rect.size - Vector2.ONE * thickness * 2.0)
	var left: int = int(outer.position.x)
	var top: int = int(outer.position.y)
	var right: int = int(outer.position.x + outer.size.x)
	var bottom: int = int(outer.position.y + outer.size.y)
	for y in range(top, bottom):
		for x in range(left, right):
			var px: float = float(x) + 0.5
			var py: float = float(y) + 0.5
			var in_outer: bool = _point_in_rounded_rect(px, py, outer, radius)
			var in_inner: bool = _point_in_rounded_rect(px, py, inner, max(radius - thickness, 0.0))
			if in_outer and not in_inner:
				image.set_pixel(x, y, color)

static func _point_in_rounded_rect(px: float, py: float, rect: Rect2, radius: float) -> bool:
	if px < rect.position.x or py < rect.position.y or px > rect.position.x + rect.size.x or py > rect.position.y + rect.size.y:
		return false
	var inner_rect: Rect2 = Rect2(rect.position + Vector2(radius, 0.0), Vector2(rect.size.x - radius * 2.0, rect.size.y))
	if inner_rect.has_point(Vector2(px, py)):
		return true
	inner_rect = Rect2(rect.position + Vector2(0.0, radius), Vector2(rect.size.x, rect.size.y - radius * 2.0))
	if inner_rect.has_point(Vector2(px, py)):
		return true
	var corners: Array = [
		Vector2(rect.position.x + radius, rect.position.y + radius),
		Vector2(rect.position.x + rect.size.x - radius, rect.position.y + radius),
		Vector2(rect.position.x + radius, rect.position.y + rect.size.y - radius),
		Vector2(rect.position.x + rect.size.x - radius, rect.position.y + rect.size.y - radius),
	]
	for corner in corners:
		if corner.distance_to(Vector2(px, py)) <= radius:
			return true
	return false

static func _draw_filled_circle(image: Image, center: Vector2, radius: float, color: Color) -> void:
	var left: int = maxi(int(floor(center.x - radius)), 0)
	var top: int = maxi(int(floor(center.y - radius)), 0)
	var right: int = mini(int(ceil(center.x + radius)), image.get_width() - 1)
	var bottom: int = mini(int(ceil(center.y + radius)), image.get_height() - 1)
	for y in range(top, bottom + 1):
		for x in range(left, right + 1):
			if center.distance_to(Vector2(float(x) + 0.5, float(y) + 0.5)) <= radius:
				image.set_pixel(x, y, color)

static func _draw_ring(image: Image, center: Vector2, radius: float, thickness: float, color: Color) -> void:
	var outer: float = radius
	var inner: float = max(radius - thickness, 0.0)
	var left: int = maxi(int(floor(center.x - outer)), 0)
	var top: int = maxi(int(floor(center.y - outer)), 0)
	var right: int = mini(int(ceil(center.x + outer)), image.get_width() - 1)
	var bottom: int = mini(int(ceil(center.y + outer)), image.get_height() - 1)
	for y in range(top, bottom + 1):
		for x in range(left, right + 1):
			var distance: float = center.distance_to(Vector2(float(x) + 0.5, float(y) + 0.5))
			if distance <= outer and distance >= inner:
				image.set_pixel(x, y, color)

static func _draw_diamond(image: Image, center: Vector2, radius: float, color: Color) -> void:
	var left: int = maxi(int(floor(center.x - radius)), 0)
	var top: int = maxi(int(floor(center.y - radius)), 0)
	var right: int = mini(int(ceil(center.x + radius)), image.get_width() - 1)
	var bottom: int = mini(int(ceil(center.y + radius)), image.get_height() - 1)
	for y in range(top, bottom + 1):
		for x in range(left, right + 1):
			var dx: float = abs((float(x) + 0.5) - center.x)
			var dy: float = abs((float(y) + 0.5) - center.y)
			if dx + dy <= radius:
				image.set_pixel(x, y, color)

static func _draw_diamond_outline(image: Image, center: Vector2, radius: float, color: Color, thickness: float) -> void:
	var outer: float = radius
	var inner: float = max(radius - thickness * 2.0, 0.0)
	var left: int = maxi(int(floor(center.x - outer)), 0)
	var top: int = maxi(int(floor(center.y - outer)), 0)
	var right: int = mini(int(ceil(center.x + outer)), image.get_width() - 1)
	var bottom: int = mini(int(ceil(center.y + outer)), image.get_height() - 1)
	for y in range(top, bottom + 1):
		for x in range(left, right + 1):
			var dx: float = abs((float(x) + 0.5) - center.x)
			var dy: float = abs((float(y) + 0.5) - center.y)
			var metric: float = dx + dy
			if metric <= outer and metric >= inner:
				image.set_pixel(x, y, color)

static func _draw_line_thick(image: Image, start: Vector2, end: Vector2, thickness: float, color: Color) -> void:
	var min_x: int = maxi(int(floor(minf(start.x, end.x) - thickness)), 0)
	var max_x: int = mini(int(ceil(maxf(start.x, end.x) + thickness)), image.get_width() - 1)
	var min_y: int = maxi(int(floor(minf(start.y, end.y) - thickness)), 0)
	var max_y: int = mini(int(ceil(maxf(start.y, end.y) + thickness)), image.get_height() - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var point: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5)
			if _distance_to_segment(point, start, end) <= thickness * 0.5:
				image.set_pixel(x, y, color)

static func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment: Vector2 = end - start
	var segment_length_sq: float = segment.length_squared()
	if segment_length_sq <= 0.0001:
		return point.distance_to(start)
	var t: float = clamp((point - start).dot(segment) / segment_length_sq, 0.0, 1.0)
	var projection: Vector2 = start + segment * t
	return point.distance_to(projection)

static func _draw_triangle(image: Image, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var min_x: int = maxi(int(floor(minf(a.x, minf(b.x, c.x)))), 0)
	var max_x: int = mini(int(ceil(maxf(a.x, maxf(b.x, c.x)))), image.get_width() - 1)
	var min_y: int = maxi(int(floor(minf(a.y, minf(b.y, c.y)))), 0)
	var max_y: int = mini(int(ceil(maxf(a.y, maxf(b.y, c.y)))), image.get_height() - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var point: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5)
			if _point_in_triangle(point, a, b, c):
				image.set_pixel(x, y, color)

static func _point_in_triangle(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var denominator: float = ((b.y - c.y) * (a.x - c.x)) + ((c.x - b.x) * (a.y - c.y))
	if abs(denominator) <= 0.0001:
		return false
	var alpha: float = (((b.y - c.y) * (point.x - c.x)) + ((c.x - b.x) * (point.y - c.y))) / denominator
	var beta: float = (((c.y - a.y) * (point.x - c.x)) + ((a.x - c.x) * (point.y - c.y))) / denominator
	var gamma: float = 1.0 - alpha - beta
	return alpha >= 0.0 and beta >= 0.0 and gamma >= 0.0
