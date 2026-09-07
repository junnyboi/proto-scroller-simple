class_name AerialDebrisLauncher
extends RefCounted

const AIRBORNE_GROUP: StringName = &"airborne_enemy"
const LAUNCH_COUNT: int = 3
const IMPACT_DAMAGE: float = 4.0
const GRAVITY: float = 980.0
const MIN_OVERHEAD_CLEARANCE: float = 100.0
const OVERHEAD_CONE_COSINE: float = 0.8660254
const FOCUSED_SPAWN_SPACING: float = 8.0
const FOCUSED_TARGET_SPACING: float = 12.0
const WIDE_SPAWN_SPACING: float = 18.0
const WIDE_TARGET_SPACING: float = 42.0
const FALLBACK_HORIZONTAL_SPEED: float = 105.0
const FALLBACK_FACING_BIAS: float = 65.0
const FALLBACK_VERTICAL_SPEED: float = 620.0


static func launch(
	tree: SceneTree,
	pool: DebrisPool,
	source: Node,
	origin: Vector2,
	impulse_per_mass: float,
	attack_id: int,
	options: DamageQueryOptions = null,
	focused_target: EnemyActor2D = null
) -> int:
	if tree == null or pool == null or source == null:
		return 0
	var target: EnemyActor2D = focused_target
	if not is_valid_focused_target(target, origin):
		target = _nearest_target(tree, origin)
	var kinetic_bonus: float = options.kinetic_debris_bonus if options != null else 0.0
	var fallback_launch: bool = target == null and kinetic_bonus > 0.0
	if target == null and not fallback_launch:
		return 0
	var concentrated: bool = target != null and _is_in_overhead_cone(target, origin)
	var spawn_spacing: float = (
		FOCUSED_SPAWN_SPACING if concentrated else WIDE_SPAWN_SPACING
	)
	var target_spacing: float = (
		FOCUSED_TARGET_SPACING if concentrated else WIDE_TARGET_SPACING
	)
	var launched: int = 0
	for debris_index: int in range(LAUNCH_COUNT):
		var spawn_position: Vector2 = origin + Vector2(
			float(debris_index - 1) * spawn_spacing,
			-10.0
		)
		var body_mass: float = 3.5 + float(debris_index) * 1.25
		var target_offset: Vector2 = Vector2(
			float(debris_index - 1) * target_spacing,
			float(abs(debris_index - 1)) * (3.0 if concentrated else 8.0)
		)
		var launch_velocity: Vector2 = (
			_fallback_velocity(source, debris_index, impulse_per_mass)
			if fallback_launch
			else _ballistic_velocity(
				spawn_position,
				target,
				target_offset,
				impulse_per_mass
			)
		)
		var debris: DebrisBody2D = pool.acquire(
			Transform2D(0.0, spawn_position),
			launch_velocity * body_mass,
			float(debris_index - 1) * body_mass * 7.0,
			body_mass,
			Vector2(30.0 + float(debris_index) * 5.0, 18.0),
				&"concrete"
			)
		var source_event: DamageEvent = DamageEvent.new(
			attack_id,
			source,
			0.0,
			&"ground_smash",
			spawn_position,
			Vector2.UP,
			impulse_per_mass,
			options.root_attack_id if options != null else attack_id,
			0,
			options.effect_flags if options != null else DamageEvent.FLAG_NONE,
			options.kinetic_debris_bonus if options != null else 0.0
		)
		pool.arm_kinetic_debris(debris, source_event)
		debris.arm_aerial_impact(
			source,
			attack_id * 10 + debris_index + 1,
			IMPACT_DAMAGE,
			target,
			attack_id
		)
		launched += 1
	return launched


static func _fallback_velocity(
	source: Node,
	debris_index: int,
	impulse_per_mass: float
) -> Vector2:
	var facing: float = 1.0
	if source is GiantRobotController:
		facing = float((source as GiantRobotController).facing)
	var force_scale: float = clampf(impulse_per_mass / 1020.0, 0.85, 1.35)
	return Vector2(
		float(debris_index - 1) * FALLBACK_HORIZONTAL_SPEED + facing * FALLBACK_FACING_BIAS,
		-FALLBACK_VERTICAL_SPEED - float(abs(debris_index - 1)) * 45.0
	) * force_scale


static func _nearest_target(tree: SceneTree, origin: Vector2) -> EnemyActor2D:
	var nearest: EnemyActor2D
	var nearest_distance: float = INF
	var nearest_overhead: EnemyActor2D
	var nearest_overhead_distance: float = INF
	for candidate: Node in tree.get_nodes_in_group(AIRBORNE_GROUP):
		if not candidate is EnemyActor2D:
			continue
		var enemy: EnemyActor2D = candidate as EnemyActor2D
		if not enemy.active or enemy.dead or enemy.global_position.y > origin.y - MIN_OVERHEAD_CLEARANCE:
			continue
		var distance: float = origin.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
		if _is_in_overhead_cone(enemy, origin) and distance < nearest_overhead_distance:
			nearest_overhead = enemy
			nearest_overhead_distance = distance
	return nearest_overhead if nearest_overhead != null else nearest


static func nearest_overhead_target(
	tree: SceneTree,
	origin: Vector2
) -> EnemyActor2D:
	if tree == null:
		return null
	var nearest: EnemyActor2D
	var nearest_distance: float = INF
	for candidate: Node in tree.get_nodes_in_group(AIRBORNE_GROUP):
		if not candidate is EnemyActor2D:
			continue
		var enemy: EnemyActor2D = candidate as EnemyActor2D
		if not is_valid_focused_target(enemy, origin):
			continue
		var distance: float = origin.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


static func is_valid_focused_target(
	target: EnemyActor2D,
	origin: Vector2
) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not target.active or target.dead:
		return false
	return _is_in_overhead_cone(target, origin)


static func _is_in_overhead_cone(target: EnemyActor2D, origin: Vector2) -> bool:
	if target == null:
		return false
	var offset: Vector2 = target.global_position - origin
	if offset.y > -MIN_OVERHEAD_CLEARANCE or offset.is_zero_approx():
		return false
	return offset.normalized().dot(Vector2.UP) >= OVERHEAD_CONE_COSINE


static func _ballistic_velocity(
	origin: Vector2,
	target: EnemyActor2D,
	target_offset: Vector2,
	impulse_per_mass: float
) -> Vector2:
	var horizontal_distance: float = absf(target.global_position.x - origin.x)
	var flight_time: float = clampf(horizontal_distance / 620.0, 0.65, 1.15)
	var predicted_target: Vector2 = (
		target.global_position
		+ target.velocity * flight_time * 0.65
		+ target_offset
	)
	var gravity_drop: Vector2 = Vector2(0.0, 0.5 * GRAVITY * flight_time * flight_time)
	var velocity: Vector2 = (predicted_target - origin - gravity_drop) / flight_time
	var force_scale: float = clampf(impulse_per_mass / 1020.0, 0.85, 1.35)
	return velocity * force_scale
