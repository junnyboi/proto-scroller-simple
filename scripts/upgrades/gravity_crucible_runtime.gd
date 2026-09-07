class_name GravityCrucibleRuntime
extends UpgradeRuntime

const CAPACITY: int = 60
const EXPLOSION_VISUAL_CAPACITY: int = 12
const CAPTURE_THRESHOLD_SECONDS: float = 0.35
const CAPTURE_CAPS: Array[int] = [0, CAPACITY, CAPACITY, CAPACITY]
const CAPTURE_RADII: Array[float] = [0.0, 1000.0, 1000.0, 1000.0]
const ORBIT_RADII: Array[float] = [0.0, 96.0, 108.0, 120.0]
const THROW_SPEEDS: Array[float] = [0.0, 1450.0, 1750.0, 2050.0]
const IMPACT_DAMAGE: Array[float] = [0.0, 30.0, 42.0, 56.0]
const ORBIT_HEIGHT: float = -34.0
const ORBIT_SPEED: float = 3.8
const ORBIT_ARC_SPACING: float = 48.0
const PULL_SPEED: float = 1800.0
const RELEASE_TARGET_RADIUS: float = 1000.0
const LOW_CHARGE_GRAVITY_MULTIPLIER: float = 1.35
const MAX_LOW_CHARGE_SPREAD_RADIANS: float = PI * 0.10
const FULL_CHARGE_STRAIGHT_SECONDS: float = 0.85
const MAX_CHARGE_ATTACK_MULTIPLIER: float = 2.0
const AIM_SPREAD_PATTERN: Array[float] = [
	-1.0, 0.72, -0.48, 1.0, -0.82, 0.36, 0.58, -0.24,
]

var robot: GiantRobotController
var attacks: ContextualAttackController
var debris_pool: DebrisPool
var enemy_scrap_pool: DebrisPool
var remains_factory: EnemyRemainsFactory
var air_target_lock_runtime: AirTargetLockRuntime
var encounter_runtime: EncounterRuntime
var captured: Array[Node2D] = []
var captured_categories: PackedInt32Array = PackedInt32Array()
var explosion_visuals: Array[MissileExplosionVisual2D] = []
var _candidates: Array[Dictionary] = []
var _charging: bool = false
var _capture_started: bool = false
var _charge_attack_id: int = 0
var _orbit_time: float = 0.0
var capture_count_total: int = 0
var release_count_total: int = 0
var explosion_count_total: int = 0
var _explosion_visual_cursor: int = 0


func _init() -> void:
	setup(&"GRAVITY_CRUCIBLE", 3)
	captured.resize(CAPACITY)
	captured_categories.resize(CAPACITY)
	for index: int in range(EXPLOSION_VISUAL_CAPACITY):
		var visual: MissileExplosionVisual2D = MissileExplosionVisual2D.new()
		visual.name = "CrucibleExplosion%02d" % index
		add_child(visual)
		explosion_visuals.append(visual)


func setup_combat(
	p_robot: GiantRobotController,
	p_attacks: ContextualAttackController,
	p_debris_pool: DebrisPool,
	p_enemy_scrap_pool: DebrisPool,
	p_remains_factory: EnemyRemainsFactory,
	p_air_target_lock_runtime: AirTargetLockRuntime,
	p_encounter_runtime: EncounterRuntime
) -> void:
	robot = p_robot
	attacks = p_attacks
	debris_pool = p_debris_pool
	enemy_scrap_pool = p_enemy_scrap_pool
	remains_factory = p_remains_factory
	air_target_lock_runtime = p_air_target_lock_runtime
	encounter_runtime = p_encounter_runtime
	_connect_detonation_source(debris_pool)
	_connect_detonation_source(enemy_scrap_pool)
	_connect_detonation_source(remains_factory)
	if attacks != null:
		if not attacks.charge_started.is_connected(_on_charge_started):
			attacks.charge_started.connect(_on_charge_started)
		if not attacks.charge_updated.is_connected(_on_charge_updated):
			attacks.charge_updated.connect(_on_charge_updated)
		if not attacks.charge_released.is_connected(_on_charge_released):
			attacks.charge_released.connect(_on_charge_released)
		if not attacks.attack_cancelled.is_connected(_on_attack_cancelled):
			attacks.attack_cancelled.connect(_on_attack_cancelled)


func is_available(_context: Dictionary = {}) -> bool:
	return (
		not stopped
		and robot != null
		and attacks != null
		and debris_pool != null
		and enemy_scrap_pool != null
		and remains_factory != null
		and encounter_runtime != null
	)


func apply_rank(total_rank: int, _context: Dictionary = {}) -> bool:
	var changed: bool = super.apply_rank(total_rank)
	if current_rank <= 0:
		_cancel_capture()
	return changed


func set_paused(value: bool) -> void:
	super.set_paused(value)
	for visual: MissileExplosionVisual2D in explosion_visuals:
		visual.paused = value


func stop_and_release() -> void:
	_cancel_capture()
	for visual: MissileExplosionVisual2D in explosion_visuals:
		visual.deactivate()
	super.stop_and_release()


func reset_run() -> void:
	_cancel_capture()
	super.reset_run()
	capture_count_total = 0
	release_count_total = 0
	explosion_count_total = 0
	_explosion_visual_cursor = 0
	for visual: MissileExplosionVisual2D in explosion_visuals:
		visual.paused = false
		visual.deactivate()


func captured_count() -> int:
	var count: int = 0
	for body: Node2D in captured:
		if body != null:
			count += 1
	return count


static func attack_multiplier_for_charge(charge_progress: float) -> float:
	return lerpf(
		1.0,
		MAX_CHARGE_ATTACK_MULTIPLIER,
		clampf(charge_progress, 0.0, 1.0)
	)


func snapshot() -> Dictionary:
	var data: Dictionary = super.snapshot()
	data.merge({
		"capacity": CAPACITY,
		"captured": captured_count(),
		"capture_total": capture_count_total,
		"release_total": release_count_total,
		"explosion_total": explosion_count_total,
		"explosion_visual_slots": explosion_visuals.size(),
		"capture_started": _capture_started,
	}, true)
	return data


func _process(delta: float) -> void:
	if paused or stopped or not _capture_started or robot == null:
		return
	_capture_candidates()
	_orbit_time += maxf(delta, 0.0)
	_update_orbits(maxf(delta, 0.0))


func _on_charge_started(spec: AttackSpec) -> void:
	_cancel_capture()
	if stopped or current_rank <= 0 or spec == null:
		return
	_charging = true
	_charge_attack_id = spec.attack_id
	_orbit_time = 0.0


func _on_charge_updated(
	spec: AttackSpec,
	duration: float,
	_progress: float,
	_multiplier: float
) -> void:
	if (
		paused
		or stopped
		or current_rank <= 0
		or not _charging
		or spec == null
		or spec.attack_id != _charge_attack_id
		or _capture_started
		or duration < CAPTURE_THRESHOLD_SECONDS
	):
		return
	_capture_started = true
	_capture_candidates()
	_update_orbits(0.0)


func _on_charge_released(
	spec: AttackSpec,
	_duration: float,
	multiplier: float
) -> void:
	if spec == null or spec.attack_id != _charge_attack_id:
		_cancel_capture()
		return
	if _capture_started:
		_release_capture(spec, clampf(multiplier - 1.0, 0.0, 1.0))
	else:
		_clear_runtime_state()


func _on_attack_cancelled(_spec: AttackSpec) -> void:
	_cancel_capture()


func _capture_candidates() -> void:
	if robot == null:
		return
	_candidates.clear()
	var radius_squared: float = CAPTURE_RADII[current_rank] * CAPTURE_RADII[current_rank]
	_append_debris_candidates(debris_pool, 0, radius_squared)
	_append_debris_candidates(enemy_scrap_pool, 1, radius_squared)
	for index: int in range(remains_factory.active_count()):
		var wreck: EnemyWreck2D = remains_factory.active_wreck_at(index)
		if wreck == null or not wreck.is_crucible_eligible():
			continue
		var distance_squared: float = robot.global_position.distance_squared_to(
			wreck.global_position
		)
		if distance_squared <= radius_squared:
			_candidates.append({
				"body": wreck,
				"distance": distance_squared,
				"category": 2,
				"id": wreck.get_instance_id(),
			})
	_candidates.sort_custom(_candidate_before)
	var slot_index: int = _next_empty_slot()
	for candidate: Dictionary in _candidates:
		if slot_index >= CAPTURE_CAPS[current_rank]:
			break
		var body: Node2D = candidate.body as Node2D
		if not _begin_body_capture(body):
			continue
		captured[slot_index] = body
		captured_categories[slot_index] = int(candidate.category)
		capture_count_total += 1
		slot_index = _next_empty_slot(slot_index + 1)
	_candidates.clear()


func _next_empty_slot(start_index: int = 0) -> int:
	var limit: int = CAPTURE_CAPS[current_rank]
	for slot_index: int in range(maxi(start_index, 0), limit):
		if captured[slot_index] == null:
			return slot_index
	return limit


func _append_debris_candidates(
	pool: DebrisPool,
	category: int,
	radius_squared: float
) -> void:
	if pool == null:
		return
	for index: int in range(pool.active_count()):
		var debris: DebrisBody2D = pool.active_body_at(index)
		if debris == null or not debris.is_crucible_eligible():
			continue
		var distance_squared: float = robot.global_position.distance_squared_to(
			debris.global_position
		)
		if distance_squared <= radius_squared:
			_candidates.append({
				"body": debris,
				"distance": distance_squared,
				"category": category,
				"id": debris.get_instance_id(),
			})


func _update_orbits(delta: float) -> void:
	var count: int = captured_count()
	if count <= 0:
		return
	var orbit_radius: float = maxf(
		ORBIT_RADII[current_rank],
		float(count) * ORBIT_ARC_SPACING / TAU
	)
	var valid_index: int = 0
	for slot_index: int in range(CAPACITY):
		var body: Node2D = captured[slot_index]
		if body == null:
			continue
		if not _is_body_captured(body):
			_cancel_capture()
			return
		var angle: float = (
			_orbit_time * ORBIT_SPEED
			+ TAU * float(valid_index) / float(count)
		)
		var horizontal: float = cos(angle) * orbit_radius
		var vertical: float = sin(angle) * orbit_radius * 0.42
		var orbit_position: Vector2 = robot.global_position + Vector2(
			horizontal,
			ORBIT_HEIGHT + vertical
		)
		var pulled_position: Vector2 = body.global_position.move_toward(
			orbit_position,
			PULL_SPEED * delta
		)
		body.call(&"update_crucible_capture", pulled_position, angle)
		valid_index += 1


func _release_capture(spec: AttackSpec, charge_progress: float) -> void:
	var launch_speed: float = THROW_SPEEDS[current_rank] * charge_progress
	var impact_damage: float = (
		IMPACT_DAMAGE[current_rank]
		* charge_progress
		* attack_multiplier_for_charge(charge_progress)
	)
	var gravity_multiplier: float = lerpf(
		LOW_CHARGE_GRAVITY_MULTIPLIER,
		0.0,
		charge_progress
	)
	var gravity_restore_delay: float = (
		FULL_CHARGE_STRAIGHT_SECONDS if charge_progress >= 1.0 else 0.0
	)
	var direction: Vector2 = Vector2(float(spec.facing), -0.12).normalized()
	var source_event: DamageEvent = DamageEvent.new(
		spec.attack_id,
		robot,
		0.0,
		&"debris_impact",
		robot.global_position,
		direction,
		launch_speed,
		spec.attack_id,
		0,
		spec.effect_flags | DamageEvent.FLAG_GRAVITY_CRUCIBLE,
		spec.kinetic_debris_bonus
	)
	var release_index: int = 0
	var release_total: int = captured_count()
	var targets: Array[EnemyActor2D] = _nearby_enemies()
	for slot_index: int in range(CAPACITY):
		var body: Node2D = captured[slot_index]
		if body == null:
			continue
		var launch_direction: Vector2 = _release_direction(
			body,
			release_index,
			release_total,
			targets,
			spec.facing,
			launch_speed,
			charge_progress
		)
		var launch_velocity: Vector2 = launch_direction * launch_speed
		var delivery_id: int = 3_000_000 + spec.attack_id * 10 + release_index + 1
		if bool(body.call(
			&"release_from_crucible",
			launch_velocity,
			(10.0 + float(release_index % 5)) * charge_progress
			* (-1.0 if release_index % 2 else 1.0),
			source_event,
			impact_damage,
			delivery_id,
			gravity_multiplier,
			gravity_restore_delay
		)):
			release_count_total += 1
		release_index += 1
	_clear_runtime_state()


func _nearby_enemies() -> Array[EnemyActor2D]:
	var locked_targets: Array[EnemyActor2D] = _locked_air_targets()
	if not locked_targets.is_empty():
		return locked_targets
	var targets: Array[EnemyActor2D] = []
	if encounter_runtime == null or robot == null:
		return targets
	var radius_squared: float = RELEASE_TARGET_RADIUS * RELEASE_TARGET_RADIUS
	for index: int in range(encounter_runtime.actor_registry_count()):
		var enemy: EnemyActor2D = encounter_runtime.actor_at_registry_index(index)
		if enemy == null or not enemy.active or enemy.dead:
			continue
		if robot.global_position.distance_squared_to(enemy.global_position) <= radius_squared:
			targets.append(enemy)
	targets.sort_custom(_enemy_before)
	return targets


func _locked_air_targets() -> Array[EnemyActor2D]:
	var targets: Array[EnemyActor2D] = []
	if air_target_lock_runtime == null:
		return targets
	var target: EnemyActor2D = air_target_lock_runtime.current_target()
	if (
		target != null
		and is_instance_valid(target)
		and target.active
		and not target.dead
		and target.is_in_group(AerialDebrisLauncher.AIRBORNE_GROUP)
	):
		targets.append(target)
	return targets


func _release_direction(
	body: Node2D,
	release_index: int,
	release_total: int,
	targets: Array[EnemyActor2D],
	facing: int,
	launch_speed: float,
	charge_progress: float
) -> Vector2:
	if not targets.is_empty():
		var target: EnemyActor2D = targets[release_index % targets.size()]
		var travel_time: float = body.global_position.distance_to(
			target.global_position
		) / maxf(launch_speed, 1.0)
		var predicted_position: Vector2 = (
			target.global_position
			+ target.velocity * clampf(travel_time, 0.0, 0.75)
		)
		var targeted_direction: Vector2 = body.global_position.direction_to(
			predicted_position
		)
		if not targeted_direction.is_zero_approx():
			var spread_scale: float = 1.0 - charge_progress
			var spread_angle: float = (
				AIM_SPREAD_PATTERN[release_index % AIM_SPREAD_PATTERN.size()]
				* MAX_LOW_CHARGE_SPREAD_RADIANS
				* spread_scale
			)
			return targeted_direction.rotated(spread_angle)
	var facing_angle: float = 0.0 if facing >= 0 else PI
	var radial_angle: float = (
		facing_angle
		+ TAU * float(release_index) / maxf(float(release_total), 1.0)
	)
	return Vector2.from_angle(radial_angle)


func _cancel_capture() -> void:
	for slot_index: int in range(CAPACITY):
		var body: Node2D = captured[slot_index]
		if body != null and is_instance_valid(body):
			body.call(&"cancel_crucible_capture")
	_clear_runtime_state()


func _clear_runtime_state() -> void:
	for index: int in range(CAPACITY):
		captured[index] = null
		captured_categories[index] = 0
	_candidates.clear()
	_charging = false
	_capture_started = false
	_charge_attack_id = 0
	_orbit_time = 0.0


func _begin_body_capture(body: Node2D) -> bool:
	return body != null and bool(body.call(&"begin_crucible_capture"))


func _is_body_captured(body: Node2D) -> bool:
	return body != null and bool(body.call(&"is_crucible_captured"))


func _candidate_before(first: Dictionary, second: Dictionary) -> bool:
	var first_distance: float = float(first.distance)
	var second_distance: float = float(second.distance)
	if not is_equal_approx(first_distance, second_distance):
		return first_distance < second_distance
	var first_category: int = int(first.category)
	var second_category: int = int(second.category)
	if first_category != second_category:
		return first_category < second_category
	return int(first.id) < int(second.id)


func _enemy_before(first: EnemyActor2D, second: EnemyActor2D) -> bool:
	var first_distance: float = robot.global_position.distance_squared_to(
		first.global_position
	)
	var second_distance: float = robot.global_position.distance_squared_to(
		second.global_position
	)
	if not is_equal_approx(first_distance, second_distance):
		return first_distance < second_distance
	return first.get_instance_id() < second.get_instance_id()


func _connect_detonation_source(source: Node) -> void:
	if source == null or not source.has_signal(&"crucible_detonated"):
		return
	if not source.is_connected(&"crucible_detonated", _on_crucible_detonated):
		source.connect(&"crucible_detonated", _on_crucible_detonated)


func _on_crucible_detonated(_body: Node2D, event: DamageEvent) -> void:
	if event == null or explosion_visuals.is_empty():
		return
	explosion_visuals[_explosion_visual_cursor].activate(event.hit_position, 1.35)
	_explosion_visual_cursor = (
		(_explosion_visual_cursor + 1) % explosion_visuals.size()
	)
	explosion_count_total += 1
