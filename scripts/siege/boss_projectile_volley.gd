class_name BossProjectileVolley
extends RefCounted

const TELEGRAPH_PRESENTATION_VARIANT: StringName = &"boss_projectile"

var encounter_runtime: EncounterRuntime
var rig: BossRig2D
var owner: EnemyActor2D
var attack_particle_pool: BossAttackParticlePool2D
var boss_id: StringName = &""
var kind: StringName = &""
var visual_key: StringName = &""
var projectile_speed: float = 0.0
var base_damage: float = 0.0
var presentation_scale: float = 1.0
var telegraph_id: int = 0
var last_fired_count: int = 0
var denial_count: int = 0

var _reservation_ids: Array[int] = []
var _origins: Array[Vector2] = []
var _targets: Array[Vector2] = []
var _delays: Array[float] = []
var _active_projectiles: Array[Projectile2D] = []
var _elapsed: float = 0.0
var _next_shot_index: int = 0
var _committed: bool = false
var _outgoing_damage_multiplier: float = EnemyActor2D.ENEMY_DAMAGE_MULTIPLIER
var _projectile_lifetime: float = 2.5


func setup(
	runtime: EncounterRuntime,
	boss_rig: BossRig2D,
	boss_owner: EnemyActor2D,
	particle_pool: BossAttackParticlePool2D = null,
	particle_boss_id: StringName = &""
) -> void:
	cancel()
	encounter_runtime = runtime
	rig = boss_rig
	owner = boss_owner
	attack_particle_pool = particle_pool
	boss_id = particle_boss_id


func begin(
	projectile_kind: StringName,
	projectile_visual_key: StringName,
	socket_names: Array[StringName],
	target_points: Array[Vector2],
	shot_delays: Array[float],
	speed: float,
	damage: float,
	shot_scale: float,
	telegraph_seconds: float
) -> bool:
	var origin_points: Array[Vector2] = []
	if rig == null:
		return false
	for socket_name: StringName in socket_names:
		var socket: Marker2D = rig.socket(socket_name)
		if socket == null:
			return false
		origin_points.append(socket.global_position)
	return begin_from_origins(
		projectile_kind,
		projectile_visual_key,
		origin_points,
		target_points,
		shot_delays,
		speed,
		damage,
		shot_scale,
		telegraph_seconds
	)


func begin_from_origins(
	projectile_kind: StringName,
	projectile_visual_key: StringName,
	origin_points: Array[Vector2],
	target_points: Array[Vector2],
	shot_delays: Array[float],
	speed: float,
	damage: float,
	shot_scale: float,
	telegraph_seconds: float
) -> bool:
	cancel()
	if (
		encounter_runtime == null
		or encounter_runtime.projectile_pool == null
		or owner == null
		or not is_instance_valid(owner)
		or not owner.active
		or owner.dead
		or origin_points.is_empty()
		or origin_points.size() != target_points.size()
		or origin_points.size() != shot_delays.size()
	):
		return false
	kind = projectile_kind
	visual_key = projectile_visual_key
	projectile_speed = maxf(speed, 1.0)
	_outgoing_damage_multiplier = float(RuntimeTweakAccess.next_attack_value(
		&"enemy.outgoing_damage_multiplier", EnemyActor2D.ENEMY_DAMAGE_MULTIPLIER
	))
	base_damage = maxf(damage, 0.0) * float(RuntimeTweakAccess.next_attack_value(
		&"boss.standard_projectile_damage_multiplier", 1.0
	))
	_projectile_lifetime = float(RuntimeTweakAccess.next_attack_value(
		&"projectile.hostile_lifetime", 2.5
	))
	presentation_scale = maxf(shot_scale, 0.01)
	for shot_index: int in range(origin_points.size()):
		var reservation_id: int = encounter_runtime.projectile_pool.reserve(kind)
		if reservation_id == 0:
			denial_count += 1
			cancel()
			return false
		_reservation_ids.append(reservation_id)
		_origins.append(origin_points[shot_index])
		_targets.append(target_points[shot_index])
		_delays.append(maxf(shot_delays[shot_index], 0.0))
	_play_particle_telegraphs(maxf(telegraph_seconds, 0.0))
	return true


func commit() -> bool:
	if _reservation_ids.is_empty() or owner == null or not owner.active or owner.dead:
		cancel()
		return false
	_cancel_telegraph()
	_committed = true
	_elapsed = 0.0
	_next_shot_index = 0
	last_fired_count = 0
	_fire_due_shots()
	return true


func advance(delta: float) -> void:
	_prune_projectiles()
	if not _committed or delta <= 0.0:
		return
	_elapsed += delta
	_fire_due_shots()


func cancel() -> void:
	_cancel_telegraph()
	if encounter_runtime != null and encounter_runtime.projectile_pool != null:
		for reservation_id: int in _reservation_ids:
			if reservation_id != 0:
				encounter_runtime.projectile_pool.cancel_reservation(reservation_id)
		for projectile: Projectile2D in _active_projectiles:
			if projectile != null and is_instance_valid(projectile) and projectile.active:
				encounter_runtime.projectile_pool.release(projectile)
	_reservation_ids.clear()
	_origins.clear()
	_targets.clear()
	_delays.clear()
	_active_projectiles.clear()
	_elapsed = 0.0
	_next_shot_index = 0
	_committed = false
	kind = &""
	visual_key = &""
	projectile_speed = 0.0
	base_damage = 0.0
	_outgoing_damage_multiplier = EnemyActor2D.ENEMY_DAMAGE_MULTIPLIER
	_projectile_lifetime = 2.5
	presentation_scale = 1.0


func pending_reservation_count() -> int:
	return maxi(_reservation_ids.size() - _next_shot_index, 0)


func active_projectile_count() -> int:
	_prune_projectiles()
	return _active_projectiles.size()


func planned_shot_count() -> int:
	return _reservation_ids.size()


func active() -> bool:
	return telegraph_id != 0 or pending_reservation_count() > 0 or active_projectile_count() > 0


func signature() -> Dictionary:
	return {
		"kind": kind,
		"visual_key": visual_key,
		"presentation_scale": presentation_scale,
		"telegraph_id": telegraph_id,
		"planned": planned_shot_count(),
		"pending": pending_reservation_count(),
		"active": active_projectile_count(),
		"fired": last_fired_count,
		"denials": denial_count,
		"origins": _origins.duplicate(),
		"targets": _targets.duplicate(),
		"particle_signature": BossAttackParticleCatalog.signature_for_boss(boss_id),
	}


func _fire_due_shots() -> void:
	while _next_shot_index < _reservation_ids.size():
		if _elapsed + 0.0001 < _delays[_next_shot_index]:
			return
		var reservation_id: int = _reservation_ids[_next_shot_index]
		var origin: Vector2 = _origins[_next_shot_index]
		var target: Vector2 = _targets[_next_shot_index]
		var direction: Vector2 = origin.direction_to(target)
		if direction.is_zero_approx():
			direction = Vector2.LEFT
		var projectile: Projectile2D = encounter_runtime.projectile_pool.acquire_reserved(
			reservation_id,
			origin,
			direction,
			projectile_speed,
			BossEncounterDefinition.scale_outgoing_damage(
				maxf(base_damage, 0.0) * owner.cycle_attack_multiplier
					* _outgoing_damage_multiplier
			),
			owner,
			owner.projectile_target_mask,
			kind,
			visual_key,
			presentation_scale,
			_projectile_lifetime
		)
		_reservation_ids[_next_shot_index] = 0
		if projectile != null:
			_active_projectiles.append(projectile)
			last_fired_count += 1
			if attack_particle_pool != null:
				attack_particle_pool.play_release(
					boss_id,
					origin,
					direction,
					presentation_scale
				)
		_next_shot_index += 1
	if _next_shot_index >= _reservation_ids.size():
		_committed = false


func _cancel_telegraph() -> void:
	if (
		telegraph_id != 0
		and encounter_runtime != null
		and encounter_runtime.telegraphs != null
	):
		encounter_runtime.telegraphs.cancel(telegraph_id)
	telegraph_id = 0


func _play_particle_telegraphs(telegraph_seconds: float) -> void:
	if (
		attack_particle_pool == null
		or telegraph_seconds <= 0.0
		or BossAttackParticleCatalog.profile_for_boss(boss_id).is_empty()
	):
		return
	for shot_index: int in range(_origins.size()):
		var direction: Vector2 = _origins[shot_index].direction_to(
			_targets[shot_index]
		)
		attack_particle_pool.play_telegraph(
			boss_id,
			_origins[shot_index],
			direction,
			presentation_scale
		)


func _prune_projectiles() -> void:
	for index: int in range(_active_projectiles.size() - 1, -1, -1):
		var projectile: Projectile2D = _active_projectiles[index]
		if projectile == null or not is_instance_valid(projectile) or not projectile.active:
			_active_projectiles.remove_at(index)
