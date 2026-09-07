class_name BuildingDamageAttachment2D
extends Node2D

enum Kind {
	CABLE,
	PIPE,
}

const MAX_SPARK_PARTICLES: int = 14
const MAX_WATER_PARTICLES: int = 22
const CABLE_SWAY_SPEED: float = 3.2
const CABLE_SWAY_RADIANS: float = 0.14
const CABLE_GUST_RADIANS: float = 0.075

static var _spark_texture: ImageTexture
static var _water_texture: ImageTexture

var kind: Kind = Kind.CABLE
var sprite: Sprite2D
var particles: CPUParticles2D
var activation_count: int = 0
var sway_rotation_offset: float = 0.0
var _display_size: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0
var _sway_seed: float = 0.0
var _sway_time: float = 0.0


func setup(
	p_kind: Kind,
	texture: Texture2D,
	display_size: Vector2,
	pattern_seed: int
) -> void:
	kind = p_kind
	_display_size = display_size
	_sway_seed = float(pattern_seed) * 0.731
	sprite = Sprite2D.new()
	sprite.name = "AttachmentSprite"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var texture_size: Vector2 = texture.get_size()
	var fit_scale: float = minf(
		display_size.x / maxf(texture_size.x, 1.0),
		display_size.y / maxf(texture_size.y, 1.0)
	)
	sprite.scale = Vector2.ONE * fit_scale
	sprite.position.y = display_size.y * 0.5
	add_child(sprite)
	particles = _create_particles()
	add_child(particles)
	z_index = 1
	set_attachment_visible(false)


func configure_transform(
	visual_center: Vector2,
	p_rotation: float,
	flip_h: bool
) -> void:
	position = visual_center - Vector2(0.0, _display_size.y * 0.5)
	_base_rotation = p_rotation
	rotation = _base_rotation
	sprite.flip_h = flip_h
	particles.position = Vector2(0.0, _display_size.y * 0.82)


func configure_seed(pattern_seed: int) -> void:
	_sway_seed = float(pattern_seed) * 0.731
	_sway_time = 0.0
	sway_rotation_offset = 0.0
	rotation = _base_rotation


func set_attachment_visible(value: bool) -> void:
	visible = value
	set_process(value and kind == Kind.CABLE)
	if not value:
		stop_effects()
		sway_rotation_offset = 0.0
		rotation = _base_rotation
		if sprite != null:
			sprite.position.x = 0.0


func emit_damage_effect(direction: Vector2, severity: float) -> void:
	if not visible or particles == null:
		return
	var horizontal_sign: float = signf(direction.x)
	if is_zero_approx(horizontal_sign):
		horizontal_sign = -1.0 if sprite.flip_h else 1.0
	if kind == Kind.CABLE:
		particles.amount = clampi(
			roundi(lerpf(8.0, float(MAX_SPARK_PARTICLES), severity)),
			8,
			MAX_SPARK_PARTICLES
		)
		particles.direction = Vector2(horizontal_sign, -0.42).normalized()
	else:
		particles.amount = clampi(
			roundi(lerpf(14.0, float(MAX_WATER_PARTICLES), severity)),
			14,
			MAX_WATER_PARTICLES
		)
		var spray_sign: float = -1.0 if sprite.flip_h else 1.0
		particles.direction = Vector2(spray_sign, 0.28).normalized()
	particles.emitting = false
	particles.restart()
	particles.emitting = true
	activation_count += 1


func stop_effects() -> void:
	if particles != null:
		particles.emitting = false


func active_effect_count() -> int:
	return 1 if particles != null and particles.emitting else 0


func display_size() -> Vector2:
	return _display_size


func _process(delta: float) -> void:
	if kind != Kind.CABLE or not visible:
		return
	_sway_time += delta
	var primary: float = sin(_sway_time * CABLE_SWAY_SPEED + _sway_seed)
	var secondary: float = sin(_sway_time * 5.7 + _sway_seed * 1.91) * 0.32
	var gust_wave: float = sin(_sway_time * 1.27 + _sway_seed * 0.43)
	var gust: float = signf(gust_wave) * pow(absf(gust_wave), 7.0)
	sway_rotation_offset = (
		(primary + secondary) * CABLE_SWAY_RADIANS
		+ gust * CABLE_GUST_RADIANS
	)
	rotation = _base_rotation + sway_rotation_offset
	sprite.position.x = sin(_sway_time * 4.1 + _sway_seed * 2.4) * 2.8


func _create_particles() -> CPUParticles2D:
	var effect: CPUParticles2D = CPUParticles2D.new()
	effect.name = "CableSparks" if kind == Kind.CABLE else "WaterSpray"
	effect.amount = MAX_SPARK_PARTICLES if kind == Kind.CABLE else MAX_WATER_PARTICLES
	effect.lifetime = 0.48 if kind == Kind.CABLE else 0.72
	effect.one_shot = true
	effect.explosiveness = 0.92
	effect.randomness = 0.32
	effect.local_coords = false
	effect.emitting = false
	effect.texture = _particle_texture(kind)
	effect.spread = 78.0 if kind == Kind.CABLE else 34.0
	effect.gravity = Vector2(0.0, 520.0 if kind == Kind.CABLE else 380.0)
	effect.initial_velocity_min = 110.0 if kind == Kind.CABLE else 145.0
	effect.initial_velocity_max = 285.0 if kind == Kind.CABLE else 245.0
	effect.damping_min = 20.0 if kind == Kind.CABLE else 35.0
	effect.damping_max = 55.0 if kind == Kind.CABLE else 70.0
	effect.angular_velocity_min = -360.0 if kind == Kind.CABLE else -90.0
	effect.angular_velocity_max = 360.0 if kind == Kind.CABLE else 90.0
	effect.scale_amount_min = 0.42 if kind == Kind.CABLE else 0.38
	effect.scale_amount_max = 0.88 if kind == Kind.CABLE else 0.72
	effect.color_ramp = _particle_gradient(kind)
	return effect


static func _particle_texture(p_kind: Kind) -> ImageTexture:
	if p_kind == Kind.CABLE:
		if _spark_texture == null:
			_spark_texture = ImageTexture.create_from_image(_build_spark_image())
		return _spark_texture
	if _water_texture == null:
		_water_texture = ImageTexture.create_from_image(_build_water_image())
	return _water_texture


static func _particle_gradient(p_kind: Kind) -> Gradient:
	var gradient: Gradient = Gradient.new()
	if p_kind == Kind.CABLE:
		gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		gradient.colors = PackedColorArray([
			Color(1.0, 0.98, 0.72, 1.0),
			Color(1.0, 0.48, 0.08, 0.92),
			Color(0.72, 0.12, 0.02, 0.0),
		])
	else:
		gradient.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
		gradient.colors = PackedColorArray([
			Color(0.82, 0.98, 1.0, 0.95),
			Color(0.22, 0.72, 0.92, 0.72),
			Color(0.08, 0.38, 0.68, 0.0),
		])
	return gradient


static func _build_spark_image() -> Image:
	var image: Image = Image.create(18, 6, false, Image.FORMAT_RGBA8)
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var vertical: float = 1.0 - absf(float(y) - 2.5) / 3.0
			var taper: float = 1.0 - absf(float(x) - 8.5) / 9.0
			var alpha: float = pow(clampf(vertical * taper, 0.0, 1.0), 0.72)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return image


static func _build_water_image() -> Image:
	var image: Image = Image.create(10, 18, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(4.5, 9.0)
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var point: Vector2 = Vector2(float(x), float(y))
			var normalized: Vector2 = (point - center) / Vector2(4.2, 8.5)
			var alpha: float = pow(clampf(1.0 - normalized.length(), 0.0, 1.0), 0.72)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return image
