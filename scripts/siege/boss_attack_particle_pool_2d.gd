class_name BossAttackParticlePool2D
extends Node2D

const SLOT_CAPACITY: int = 12
const PRESENTATION_Z_INDEX: int = 79

var play_count: int = 0
var telegraph_play_count: int = 0
var release_play_count: int = 0
var recycle_count: int = 0
var last_boss_id: StringName = &""
var last_signature: StringName = &""
var last_cue: StringName = &""
var _slots: Array[CPUParticles2D] = []
var _cursor: int = 0


func setup() -> void:
	if not _slots.is_empty():
		return
	top_level = true
	z_as_relative = false
	z_index = PRESENTATION_Z_INDEX
	for index: int in range(SLOT_CAPACITY):
		var particles: CPUParticles2D = CPUParticles2D.new()
		particles.name = "BossAttackParticleBurst%02d" % index
		particles.one_shot = true
		particles.explosiveness = 0.96
		particles.randomness = 0.42
		particles.local_coords = false
		particles.emitting = false
		add_child(particles)
		_slots.append(particles)


func play_telegraph(
	boss_id: StringName,
	world_position: Vector2,
	toward_target: Vector2,
	presentation_scale: float = 1.0
) -> CPUParticles2D:
	return _play(
		boss_id, world_position, toward_target, presentation_scale, &"TELEGRAPH"
	)


func play_release(
	boss_id: StringName,
	world_position: Vector2,
	toward_target: Vector2,
	presentation_scale: float = 1.0
) -> CPUParticles2D:
	return _play(
		boss_id, world_position, toward_target, presentation_scale, &"RELEASE"
	)


func stop_all() -> void:
	for particles: CPUParticles2D in _slots:
		particles.emitting = false


func slot_count() -> int:
	return _slots.size()


func active_slot_count() -> int:
	var active_count: int = 0
	for particles: CPUParticles2D in _slots:
		if particles.emitting:
			active_count += 1
	return active_count


func signature_snapshot() -> Dictionary:
	return {
		"slots": slot_count(),
		"active": active_slot_count(),
		"plays": play_count,
		"telegraphs": telegraph_play_count,
		"releases": release_play_count,
		"recycles": recycle_count,
		"boss_id": last_boss_id,
		"signature": last_signature,
		"cue": last_cue,
	}


func _play(
	boss_id: StringName,
	world_position: Vector2,
	toward_target: Vector2,
	presentation_scale: float,
	cue: StringName
) -> CPUParticles2D:
	var profile: Dictionary = BossAttackParticleCatalog.profile_for_boss(boss_id)
	if profile.is_empty() or _slots.is_empty():
		return null
	var particles: CPUParticles2D = _acquire_slot()
	_configure_slot(particles, profile, toward_target, presentation_scale, cue)
	particles.global_position = world_position
	particles.restart()
	particles.emitting = true
	play_count += 1
	if cue == &"TELEGRAPH":
		telegraph_play_count += 1
	else:
		release_play_count += 1
	last_boss_id = boss_id
	last_signature = StringName(profile.get("signature", &""))
	last_cue = cue
	return particles


func _acquire_slot() -> CPUParticles2D:
	for particles: CPUParticles2D in _slots:
		if not particles.emitting:
			return particles
	var particles: CPUParticles2D = _slots[_cursor]
	_cursor = (_cursor + 1) % _slots.size()
	particles.emitting = false
	recycle_count += 1
	return particles


func _configure_slot(
	particles: CPUParticles2D,
	profile: Dictionary,
	toward_target: Vector2,
	presentation_scale: float,
	cue: StringName
) -> void:
	var is_release: bool = cue == &"RELEASE"
	var direction: Vector2 = toward_target.normalized()
	if direction.is_zero_approx():
		direction = Vector2.DOWN
	var scale_value: float = clampf(presentation_scale, 0.75, 2.0)
	particles.texture = profile.get("texture") as Texture2D
	particles.amount = int(profile.get(
		"release_amount" if is_release else "telegraph_amount", 24
	))
	particles.lifetime = 0.46 if is_release else 0.72
	particles.direction = direction if is_release else -direction
	particles.spread = 28.0 if is_release else 74.0
	particles.gravity = (
		profile.get("gravity", Vector2.ZERO) as Vector2
	) * (0.34 if is_release else 0.12)
	particles.initial_velocity_min = float(profile.get(
		"burst_velocity_min", 100.0
	)) * scale_value * (1.0 if is_release else 0.38)
	particles.initial_velocity_max = float(profile.get(
		"burst_velocity_max", 220.0
	)) * scale_value * (1.0 if is_release else 0.46)
	particles.radial_accel_min = float(profile.get("radial_accel", 0.0))
	particles.radial_accel_max = particles.radial_accel_min
	particles.tangential_accel_min = float(profile.get("tangential_accel", 0.0))
	particles.tangential_accel_max = particles.tangential_accel_min
	var angular_velocity: float = float(profile.get("angular_velocity", 0.0))
	particles.angular_velocity_min = -angular_velocity
	particles.angular_velocity_max = angular_velocity
	particles.damping_min = 18.0
	particles.damping_max = 56.0
	particles.scale_amount_min = float(profile.get("scale_min", 0.04)) * scale_value
	particles.scale_amount_max = float(profile.get("scale_max", 0.10)) * scale_value
	particles.color = Color.WHITE
	particles.color_ramp = BossAttackParticleCatalog.color_ramp(
		profile, 1.0 if is_release else 0.86
	)
