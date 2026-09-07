class_name BossPhaseRuntime
extends Node

var utility_pool: BossUtilityPool
var encounter_runtime: EncounterRuntime
var projectile_pool: ProjectilePool
var active_phase: BossPhaseDefinition
var generation_token: int = 0
var phase_reservation_id: int = 0
var active_support: Array[EnemyActor2D] = []
var projectile_reservations: Array[int] = []


func setup(
	p_utility_pool: BossUtilityPool,
	p_encounter_runtime: EncounterRuntime,
	p_projectile_pool: ProjectilePool
) -> void:
	utility_pool = p_utility_pool
	encounter_runtime = p_encounter_runtime
	projectile_pool = p_projectile_pool


func begin_phase(phase: BossPhaseDefinition, token: int) -> bool:
	cleanup_phase()
	if phase == null or utility_pool == null or not utility_pool.is_current_generation(token):
		return false
	active_phase = phase
	generation_token = token
	if not phase.reservation_requirements.is_empty():
		phase_reservation_id = utility_pool.reserve_requirements(
			phase.reservation_requirements,
			token
		)
		if phase_reservation_id == 0:
			active_phase = null
			return false
	utility_pool.register_generation_cleanup(_cleanup_generation.bind(token), token)
	return true


func acquire_support(
	kind: StringName,
	spawn_position: Vector2,
	role_id: StringName = &"",
	trait_id: StringName = &""
) -> EnemyActor2D:
	if not _phase_is_current() or encounter_runtime == null:
		return null
	var family_key: StringName = StringName(
		"procedural_%s" % String(EnemyArchetypeCatalog.family_for(kind))
	)
	if phase_reservation_id == 0:
		return null
	if not utility_pool.consume_reservation(phase_reservation_id, family_key):
		return null
	var support: EnemyActor2D = encounter_runtime.acquire(
		kind,
		spawn_position,
		role_id,
		trait_id
	)
	if support != null:
		active_support.append(support)
	return support


func track_support(support: EnemyActor2D) -> bool:
	if (
		not _phase_is_current()
		or support == null
		or not is_instance_valid(support)
		or active_support.has(support)
	):
		return false
	active_support.append(support)
	return true


func reserve_projectile(kind: StringName) -> int:
	if not _phase_is_current() or projectile_pool == null:
		return 0
	var reservation_id: int = projectile_pool.reserve(kind)
	if reservation_id != 0:
		projectile_reservations.append(reservation_id)
	return reservation_id


func acquire_reserved_projectile(
	reservation_id: int,
	origin: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	source: Node,
	target_mask: int,
	kind: StringName,
	visual_key: StringName = &"",
	presentation_scale: float = 1.0
) -> Projectile2D:
	if not projectile_reservations.has(reservation_id) or projectile_pool == null:
		return null
	projectile_reservations.erase(reservation_id)
	return projectile_pool.acquire_reserved(
		reservation_id,
		origin,
		direction,
		speed,
		damage,
		source,
		target_mask,
		kind,
		visual_key,
		presentation_scale
	)


func cancel_projectile_reservation(reservation_id: int) -> void:
	if projectile_pool != null:
		projectile_pool.cancel_reservation(reservation_id)
	projectile_reservations.erase(reservation_id)


func cleanup_phase() -> void:
	for reservation_id: int in projectile_reservations:
		if projectile_pool != null:
			projectile_pool.cancel_reservation(reservation_id)
	projectile_reservations.clear()
	for support: EnemyActor2D in active_support:
		if encounter_runtime != null and is_instance_valid(support):
			encounter_runtime.release(support)
	active_support.clear()
	if utility_pool != null and phase_reservation_id != 0:
		utility_pool.cancel_reservation(phase_reservation_id)
	phase_reservation_id = 0
	active_phase = null
	generation_token = 0


func reservation_count() -> int:
	return int(phase_reservation_id != 0) + projectile_reservations.size()


static func safe_gap_width(
	occupied_intervals: Array[Vector2],
	arena_interval: Vector2
) -> float:
	var minimum: float = minf(arena_interval.x, arena_interval.y)
	var maximum: float = maxf(arena_interval.x, arena_interval.y)
	var clipped: Array[Vector2] = []
	for interval: Vector2 in occupied_intervals:
		var start: float = clampf(minf(interval.x, interval.y), minimum, maximum)
		var finish: float = clampf(maxf(interval.x, interval.y), minimum, maximum)
		if finish > start:
			clipped.append(Vector2(start, finish))
	clipped.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var largest: float = 0.0
	var cursor: float = minimum
	for interval: Vector2 in clipped:
		largest = maxf(largest, interval.x - cursor)
		cursor = maxf(cursor, interval.y)
	largest = maxf(largest, maximum - cursor)
	return largest


static func has_safe_gap(
	occupied_intervals: Array[Vector2],
	arena_interval: Vector2,
	minimum_gap: float
) -> bool:
	return safe_gap_width(occupied_intervals, arena_interval) >= maxf(minimum_gap, 0.0)


func _phase_is_current() -> bool:
	return (
		active_phase != null
		and utility_pool != null
		and utility_pool.is_current_generation(generation_token)
	)


func _cleanup_generation(token: int) -> void:
	if generation_token == token:
		cleanup_phase()
