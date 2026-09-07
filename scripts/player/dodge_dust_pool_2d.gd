class_name DodgeDustPool2D
extends Node2D

const CAPACITY: int = 6
const PARTICLES_PER_BURST: int = 16
const MAX_INTENSITY: float = 2.20

var spawn_count: int = 0
var recycle_count: int = 0
var last_direction: Vector2 = Vector2.ZERO
var last_origin: Vector2 = Vector2.ZERO
var last_intensity: float = 0.0
var _slots: Array[CPUParticles2D] = []
var _cursor: int = 0
var _dust_texture: ImageTexture


func setup() -> void:
	if not _slots.is_empty():
		return
	top_level = true
	z_as_relative = false
	z_index = 98
	_dust_texture = _build_dust_texture()
	for index: int in range(CAPACITY):
		var particles: CPUParticles2D = CPUParticles2D.new()
		particles.name = "DodgeDust%02d" % index
		particles.amount = PARTICLES_PER_BURST
		particles.lifetime = 0.52
		particles.one_shot = true
		particles.explosiveness = 1.0
		particles.local_coords = false
		particles.emitting = false
		particles.texture = _dust_texture
		particles.spread = 38.0
		particles.gravity = Vector2(0.0, 240.0)
		particles.initial_velocity_min = 120.0
		particles.initial_velocity_max = 265.0
		particles.damping_min = 95.0
		particles.damping_max = 155.0
		particles.angular_velocity_min = -95.0
		particles.angular_velocity_max = 95.0
		particles.scale_amount_min = 0.58
		particles.scale_amount_max = 0.95
		particles.color = Color(0.43, 0.39, 0.34, 0.56)
		add_child(particles)
		_slots.append(particles)


func spawn(origin: Vector2, facing: int, intensity: float = 1.0) -> CPUParticles2D:
	if _slots.is_empty():
		return null
	var direction_sign: int = 1 if facing >= 0 else -1
	var particles: CPUParticles2D = _acquire_slot()
	var strength: float = clampf(intensity, 0.5, MAX_INTENSITY)
	last_origin = origin
	last_direction = Vector2(-float(direction_sign), -0.18).normalized()
	last_intensity = strength
	particles.global_position = origin + Vector2(-float(direction_sign) * 22.0, 0.0)
	particles.direction = last_direction
	particles.amount = roundi(float(PARTICLES_PER_BURST) * strength)
	particles.initial_velocity_min = 120.0 * strength
	particles.initial_velocity_max = 265.0 * strength
	particles.scale_amount_min = 0.58 * strength
	particles.scale_amount_max = 0.95 * strength
	particles.emitting = false
	particles.restart()
	spawn_count += 1
	return particles


func slot_count() -> int:
	return _slots.size()


func active_slot_count() -> int:
	var active_count: int = 0
	for particles: CPUParticles2D in _slots:
		if particles.emitting:
			active_count += 1
	return active_count


func stop_all() -> void:
	for particles: CPUParticles2D in _slots:
		particles.emitting = false


func _acquire_slot() -> CPUParticles2D:
	for particles: CPUParticles2D in _slots:
		if not particles.emitting:
			return particles
	var particles: CPUParticles2D = _slots[_cursor]
	_cursor = (_cursor + 1) % _slots.size()
	particles.emitting = false
	recycle_count += 1
	return particles


func _build_dust_texture() -> ImageTexture:
	var image: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y: int in range(32):
		for x: int in range(32):
			var point: Vector2 = Vector2(float(x), float(y))
			var center_alpha: float = 1.0 - point.distance_to(Vector2(15.5, 17.0)) / 12.5
			var left_alpha: float = 1.0 - point.distance_to(Vector2(9.0, 15.0)) / 8.0
			var right_alpha: float = 1.0 - point.distance_to(Vector2(22.5, 14.0)) / 7.5
			var alpha: float = maxf(center_alpha, maxf(left_alpha, right_alpha))
			alpha = pow(clampf(alpha, 0.0, 1.0), 1.65)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)
