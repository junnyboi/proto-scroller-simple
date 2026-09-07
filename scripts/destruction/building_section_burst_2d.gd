class_name BuildingSectionBurst2D
extends Node2D

const CONCRETE_TEXTURE: Texture2D = preload(
	"res://assets/city/destructibles/debris/concrete_chunk.png"
)
const GLASS_TEXTURE: Texture2D = preload(
	"res://assets/city/destructibles/debris/glass_shard.png"
)
const STEEL_TEXTURE: Texture2D = preload(
	"res://assets/city/destructibles/debris/steel_fragment.png"
)
const DUST_TEXTURE: Texture2D = preload(
	"res://assets/city/destructibles/debris/dust_puff.png"
)
const FLASH_TEXTURE: Texture2D = preload(
	"res://assets/city/destructibles/debris/impact_flash.png"
)

const ACTIVE_LIFETIME: float = 4.10
const FLASH_LIFETIME: float = 0.24
const RUIN_SMOKE_LIFETIME: float = 3.60
const RUBBLE_DUST_LIFETIME: float = 1.05
const DEBRIS_Z_INDEX: int = 20
const FLASH_Z_INDEX: int = 43

var fragments: CPUParticles2D
var falling_debris: CPUParticles2D
var dust: CPUParticles2D
var ruin_smoke: CPUParticles2D
var flash: Sprite2D
var material_id: StringName = &"concrete"
var district_id: StringName = &"BUSINESS"
var dust_only: bool = false
var activation_sequence: int = 0
var _age: float = ACTIVE_LIFETIME
var _active: bool = false
var _active_lifetime: float = ACTIVE_LIFETIME


func setup() -> void:
	if fragments != null:
		return
	top_level = true
	z_as_relative = false
	z_index = DEBRIS_Z_INDEX
	fragments = _make_particles("Fragments", 12, 1.05)
	fragments.angular_velocity_min = -540.0
	fragments.angular_velocity_max = 540.0
	fragments.damping_min = 22.0
	fragments.damping_max = 62.0
	add_child(fragments)
	falling_debris = _make_particles("FallingDebris", 10, 1.52)
	falling_debris.angular_velocity_min = -420.0
	falling_debris.angular_velocity_max = 420.0
	falling_debris.damping_min = 12.0
	falling_debris.damping_max = 38.0
	add_child(falling_debris)
	dust = _make_particles("DustCloud", 11, 1.18)
	dust.angular_velocity_min = -95.0
	dust.angular_velocity_max = 95.0
	dust.damping_min = 58.0
	dust.damping_max = 120.0
	dust.texture = DUST_TEXTURE
	add_child(dust)
	ruin_smoke = _make_particles("RuinSmoke", 7, RUIN_SMOKE_LIFETIME)
	ruin_smoke.texture = DUST_TEXTURE
	ruin_smoke.direction = Vector2.UP
	ruin_smoke.spread = 48.0
	ruin_smoke.gravity = Vector2(0.0, -8.0)
	ruin_smoke.initial_velocity_min = 20.0
	ruin_smoke.initial_velocity_max = 46.0
	ruin_smoke.damping_min = 5.0
	ruin_smoke.damping_max = 14.0
	ruin_smoke.scale_amount_min = 0.32
	ruin_smoke.scale_amount_max = 0.72
	ruin_smoke.explosiveness = 0.18
	ruin_smoke.randomness = 0.70
	ruin_smoke.color_ramp = _smoke_color_ramp()
	add_child(ruin_smoke)
	flash = Sprite2D.new()
	flash.name = "ImpactFlash"
	flash.texture = FLASH_TEXTURE
	flash.visible = false
	flash.z_as_relative = false
	flash.z_index = FLASH_Z_INDEX
	add_child(flash)
	deactivate()


func activate(
	origin: Vector2,
	impact_direction: Vector2,
	impact_speed: float,
	profile: StructuralMaterialProfile,
	sequence: int,
	p_district_id: StringName = &"BUSINESS"
) -> void:
	if fragments == null:
		setup()
	material_id = profile.material_id if profile != null else &"concrete"
	district_id = p_district_id
	dust_only = false
	activation_sequence = sequence
	global_position = origin
	var direction: Vector2 = impact_direction
	if direction.is_zero_approx():
		direction = Vector2.UP
	direction = Vector2(direction.x, minf(direction.y - 0.28, -0.18)).normalized()
	var speed: float = clampf(impact_speed, 220.0, 920.0)
	_configure_fragments(direction, speed, profile)
	_configure_falling_debris(direction, speed, profile)
	_configure_dust(direction, speed, profile, district_id)
	_configure_ruin_smoke(profile)
	_configure_flash(speed)
	_age = 0.0
	_active_lifetime = ACTIVE_LIFETIME
	_active = true
	visible = true
	set_process(true)
	fragments.restart()
	falling_debris.restart()
	dust.restart()
	ruin_smoke.restart()


func activate_rubble_dust(
	origin: Vector2,
	footprint_width: float,
	p_district_id: StringName,
	sequence: int
) -> void:
	if dust == null:
		setup()
	material_id = &"rubble_dust"
	district_id = p_district_id
	dust_only = true
	activation_sequence = sequence
	global_position = origin
	_configure_rubble_dust(footprint_width, district_id)
	_age = 0.0
	_active_lifetime = RUBBLE_DUST_LIFETIME + 0.12
	_active = true
	visible = true
	set_process(true)
	fragments.emitting = false
	falling_debris.emitting = false
	ruin_smoke.emitting = false
	flash.visible = false
	dust.restart()


func deactivate() -> void:
	_active = false
	_age = _active_lifetime
	set_process(false)
	if fragments != null:
		fragments.emitting = false
	if falling_debris != null:
		falling_debris.emitting = false
	if dust != null:
		dust.emitting = false
	if ruin_smoke != null:
		ruin_smoke.emitting = false
	if flash != null:
		flash.visible = false
	visible = false


func is_active() -> bool:
	return _active


func _process(delta: float) -> void:
	if not _active:
		return
	_age += delta
	if flash != null and _age < FLASH_LIFETIME:
		var progress: float = clampf(_age / FLASH_LIFETIME, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - progress, 3.0)
		flash.scale = Vector2.ONE * lerpf(0.18, 0.72, eased)
		flash.modulate.a = 1.0 - progress
	else:
		flash.visible = false
	if _age >= _active_lifetime:
		deactivate()


func _configure_fragments(
	direction: Vector2,
	impact_speed: float,
	profile: StructuralMaterialProfile
) -> void:
	fragments.texture = texture_for_material(material_id)
	fragments.direction = direction
	fragments.spread = profile.particle_spread if profile != null else 72.0
	fragments.gravity = Vector2(
		0.0,
		profile.particle_gravity if profile != null else 560.0
	)
	var speed_min: float = profile.particle_speed_min if profile != null else 0.35
	var speed_max: float = profile.particle_speed_max if profile != null else 0.95
	fragments.initial_velocity_min = impact_speed * speed_min
	fragments.initial_velocity_max = impact_speed * speed_max
	fragments.color = Color.WHITE
	match material_id:
		&"glass":
			fragments.amount = 12
			fragments.scale_amount_min = 0.06
			fragments.scale_amount_max = 0.18
		&"steel":
			fragments.amount = 6
			fragments.scale_amount_min = 0.09
			fragments.scale_amount_max = 0.22
		_:
			fragments.amount = 9
			fragments.scale_amount_min = 0.08
			fragments.scale_amount_max = 0.23


func _configure_dust(
	direction: Vector2,
	impact_speed: float,
	_profile: StructuralMaterialProfile,
	p_district_id: StringName
) -> void:
	dust.position = Vector2.ZERO
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	dust.lifetime = 1.18
	dust.damping_min = 58.0
	dust.damping_max = 120.0
	dust.explosiveness = 1.0
	dust.randomness = 0.32
	dust.direction = Vector2(direction.x * 0.42, -0.82).normalized()
	dust.initial_velocity_min = impact_speed * 0.12
	dust.initial_velocity_max = impact_speed * 0.30
	dust.scale_amount_min = 0.28
	dust.scale_amount_max = 0.60
	match material_id:
		&"glass":
			dust.amount = 5
			dust.spread = 78.0
			dust.gravity = Vector2(0.0, 230.0)
			dust.color = _district_dust_color(
				Color(0.42, 0.86, 0.94, 0.28),
				p_district_id
			)
		&"steel":
			dust.amount = 5
			dust.spread = 42.0
			dust.gravity = Vector2(0.0, 680.0)
			dust.color = _district_dust_color(
				Color(1.0, 0.58, 0.24, 0.45),
				p_district_id
			)
		_:
			dust.amount = 9
			dust.spread = 92.0
			dust.gravity = Vector2(0.0, 210.0)
			dust.color = _district_dust_color(
				Color(0.72, 0.64, 0.54, 0.55),
				p_district_id
			)


func _configure_rubble_dust(footprint_width: float, p_district_id: StringName) -> void:
	dust.position = Vector2.ZERO
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(maxf(footprint_width * 0.38, 18.0), 7.0)
	dust.amount = 9
	dust.lifetime = RUBBLE_DUST_LIFETIME
	dust.direction = Vector2.UP
	dust.spread = 68.0
	dust.gravity = Vector2(0.0, -10.0)
	dust.initial_velocity_min = 22.0
	dust.initial_velocity_max = 54.0
	dust.damping_min = 18.0
	dust.damping_max = 34.0
	dust.scale_amount_min = 0.22
	dust.scale_amount_max = 0.46
	dust.explosiveness = 0.88
	dust.randomness = 0.58
	dust.color = _district_dust_color(Color(0.66, 0.62, 0.56, 0.27), p_district_id)


func _configure_falling_debris(
	direction: Vector2,
	impact_speed: float,
	profile: StructuralMaterialProfile
) -> void:
	falling_debris.texture = texture_for_material(material_id)
	falling_debris.direction = Vector2(direction.x * 0.26, 0.96).normalized()
	falling_debris.spread = 28.0
	falling_debris.gravity = Vector2(
		0.0,
		(profile.particle_gravity if profile != null else 560.0) * 1.30
	)
	falling_debris.initial_velocity_min = impact_speed * 0.08
	falling_debris.initial_velocity_max = impact_speed * 0.22
	falling_debris.color = Color(0.64, 0.58, 0.52, 0.94)
	match material_id:
		&"glass":
			falling_debris.amount = 8
			falling_debris.scale_amount_min = 0.05
			falling_debris.scale_amount_max = 0.15
		&"steel":
			falling_debris.amount = 5
			falling_debris.scale_amount_min = 0.08
			falling_debris.scale_amount_max = 0.19
		_:
			falling_debris.amount = 6
			falling_debris.scale_amount_min = 0.08
			falling_debris.scale_amount_max = 0.22


func _configure_ruin_smoke(profile: StructuralMaterialProfile) -> void:
	ruin_smoke.position = Vector2(0.0, 18.0)
	ruin_smoke.amount = 5 if material_id == &"glass" else 7
	var profile_tint: Color = profile.debris_primary_color if profile != null else Color.GRAY
	ruin_smoke.color = profile_tint.lerp(Color(0.16, 0.16, 0.17, 1.0), 0.72)
	ruin_smoke.color.a = 0.24 if material_id != &"steel" else 0.19


func _configure_flash(impact_speed: float) -> void:
	flash.rotation = float(activation_sequence % 12) * TAU / 12.0
	flash.scale = Vector2.ONE * 0.18
	flash.modulate = _flash_color(material_id)
	flash.modulate.a = clampf(impact_speed / 520.0, 0.66, 1.0)
	flash.visible = true


func _make_particles(
	particle_name: String,
	amount: int,
	lifetime: float
) -> CPUParticles2D:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.name = particle_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.32
	particles.local_coords = false
	particles.emitting = false
	return particles


func _smoke_color_ramp() -> Gradient:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.16, 0.72, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.82, 0.82, 0.82, 0.0),
		Color(0.62, 0.62, 0.62, 0.72),
		Color(0.36, 0.36, 0.36, 0.30),
		Color(0.20, 0.20, 0.20, 0.0),
	])
	return gradient


static func texture_for_material(kind: StringName) -> Texture2D:
	match kind:
		&"glass":
			return GLASS_TEXTURE
		&"steel":
			return STEEL_TEXTURE
		_:
			return CONCRETE_TEXTURE


static func dust_color_for_district(district_id: StringName) -> Color:
	return _district_dust_color(Color(0.66, 0.62, 0.56, 0.27), district_id)


static func _district_dust_color(base: Color, district_id: StringName) -> Color:
	var district_tint: Color = PersistentRubbleBed2D.tint_for_district(district_id)
	var result: Color = base.lerp(district_tint, 0.30)
	result.a = base.a
	return result


static func _flash_color(kind: StringName) -> Color:
	match kind:
		&"glass":
			return Color(0.66, 0.97, 1.0, 1.0)
		&"steel":
			return Color(1.0, 0.62, 0.28, 1.0)
		_:
			return Color(0.88, 0.94, 0.96, 1.0)
