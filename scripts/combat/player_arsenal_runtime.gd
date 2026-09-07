class_name PlayerArsenalRuntime
extends Node

enum TargetClass {
	ANY,
	GROUND,
	AIR,
}

const MAX_RANGE: float = 700.0
const RELEASE_PADDING: float = 40.0
const OBSTRUCTION_MASK: int = (1 << 0) | (1 << 3)

var robot: GiantRobotController
var projectile_pool: ProjectilePool
var actors: Array[EnemyActor2D] = []
var shop_effects: WeaponShopUpgradeRuntime


func setup(
	p_robot: GiantRobotController,
	p_projectile_pool: ProjectilePool,
	encounters: EncounterRuntime
) -> void:
	robot = p_robot
	projectile_pool = p_projectile_pool
	actors.clear()
	actors.append_array(encounters.all_actors())


func acquire_target(
	maximum_range: float = MAX_RANGE,
	minimum_range: float = 0.0,
	target_class: TargetClass = TargetClass.ANY,
	require_line_of_sight: bool = true
) -> EnemyActor2D:
	var best: EnemyActor2D = null
	var best_distance: float = INF
	var minimum_squared: float = minimum_range * minimum_range
	var maximum_squared: float = maximum_range * maximum_range
	for enemy: EnemyActor2D in actors:
		if not target_matches_class(enemy, target_class):
			continue
		var distance_squared: float = robot.global_position.distance_squared_to(
			enemy.global_position
		)
		if distance_squared < minimum_squared or distance_squared > maximum_squared:
			continue
		if require_line_of_sight and not _has_line_of_sight(enemy):
			continue
		if (
			distance_squared < best_distance
			or (
				is_equal_approx(distance_squared, best_distance)
				and (best == null or enemy.get_instance_id() < best.get_instance_id())
			)
		):
			best = enemy
			best_distance = distance_squared
	return best


func target_is_current(
	target: EnemyActor2D,
	generation: int,
	maximum_range: float = MAX_RANGE,
	minimum_range: float = 0.0,
	target_class: TargetClass = TargetClass.ANY,
	require_line_of_sight: bool = false
) -> bool:
	if not target_matches_class(target, target_class):
		return false
	if target.activation_generation != generation:
		return false
	var distance_squared: float = robot.global_position.distance_squared_to(
		target.global_position
	)
	if distance_squared < minimum_range * minimum_range:
		return false
	var release_range: float = maximum_range + RELEASE_PADDING
	if distance_squared > release_range * release_range:
		return false
	return not require_line_of_sight or _has_line_of_sight(target)


func target_matches_class(target: EnemyActor2D, target_class: TargetClass) -> bool:
	if target == null or not is_instance_valid(target) or not target.active or target.dead:
		return false
	var airborne: bool = target.is_in_group(AerialDebrisLauncher.AIRBORNE_GROUP)
	if target_class == TargetClass.AIR:
		return airborne
	if target_class == TargetClass.GROUND:
		return not airborne
	return true


func reserve_attack_id() -> int:
	return robot.reserve_attack_id()


func scale_damage(
	base_damage: float,
	damage_kind: StringName,
	target: Node,
	attack_id: int
) -> float:
	if shop_effects == null:
		return base_damage
	return shop_effects.scale_weapon_damage(base_damage, damage_kind, target, attack_id)


func scale_cooldown(base_seconds: float) -> float:
	return (
		shop_effects.scale_weapon_cooldown(base_seconds)
		if shop_effects != null
		else base_seconds
	)


func _has_line_of_sight(target: EnemyActor2D) -> bool:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		robot.global_position,
		target.global_position,
		OBSTRUCTION_MASK,
		[robot.get_rid()]
	)
	return robot.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
