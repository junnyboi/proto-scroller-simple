class_name FlamethrowerConeResolver
extends RefCounted

const RAW_RESULT_LIMIT: int = 16
const TARGET_MASK: int = (1 << 2) | (1 << 3) | (1 << 6)

var last_query_count: int = 0
var last_accepted_count: int = 0
var accepted_positions: Array[Vector2] = []
var _shape: CircleShape2D = CircleShape2D.new()
var _parameters: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()


func _init() -> void:
	_parameters.shape = _shape
	_parameters.collision_mask = TARGET_MASK
	_parameters.collide_with_areas = true
	_parameters.collide_with_bodies = true


func resolve_tick(
	robot: GiantRobotController,
	origin: Vector2,
	direction: Vector2,
	flame_range: float,
	half_angle: float,
	damage: float,
	maximum_targets: int,
	attack_id: int,
	root_attack_id: int
) -> int:
	_shape.radius = flame_range
	_parameters.transform = Transform2D(0.0, origin)
	_parameters.exclude = [robot.get_rid()]
	var results: Array[Dictionary] = (
		robot.get_world_2d().direct_space_state.intersect_shape(
			_parameters,
			RAW_RESULT_LIMIT
		)
	)
	if results.size() > 1:
		results.sort_custom(_sort_result.bind(origin))
	last_query_count = results.size()
	last_accepted_count = 0
	accepted_positions.clear()
	var seen: Dictionary[int, bool] = {}
	var cosine_limit: float = cos(half_angle)
	for result: Dictionary in results:
		var collider: Node2D = result.get("collider") as Node2D
		if collider == null:
			continue
		var offset: Vector2 = collider.global_position - origin
		if offset.is_zero_approx() or offset.normalized().dot(direction) < cosine_limit:
			continue
		var receiver: Node = DamageReceiverLookup.find(collider)
		if receiver == null or receiver == robot:
			continue
		if (
			receiver is EnemyActor2D
			and (receiver as EnemyActor2D).is_in_group(AerialDebrisLauncher.AIRBORNE_GROUP)
		):
			continue
		var receiver_id: int = receiver.get_instance_id()
		if seen.has(receiver_id):
			continue
		seen[receiver_id] = true
		var event: DamageEvent = DamageEvent.new(
			attack_id,
			robot,
			damage,
			&"flamethrower",
			collider.global_position,
			direction,
			20.0,
			root_attack_id
		)
		if bool(receiver.call("receive_damage", event)):
			last_accepted_count += 1
			accepted_positions.append(collider.global_position)
		if last_accepted_count >= maximum_targets:
			break
	return last_accepted_count


func target_direction(
	arsenal: PlayerArsenalRuntime,
	origin: Vector2,
	flame_range: float
) -> Vector2:
	var best_target: EnemyActor2D = null
	var best_distance_squared: float = INF
	for enemy: EnemyActor2D in arsenal.actors:
		if not arsenal.target_matches_class(
			enemy,
			PlayerArsenalRuntime.TargetClass.GROUND
		):
			continue
		var offset: Vector2 = enemy.global_position - origin
		var distance_squared: float = offset.length_squared()
		if offset.is_zero_approx() or distance_squared > flame_range * flame_range:
			continue
		if (
			distance_squared < best_distance_squared
			or (
				is_equal_approx(distance_squared, best_distance_squared)
				and best_target != null
				and enemy.get_instance_id() < best_target.get_instance_id()
			)
		):
			best_target = enemy
			best_distance_squared = distance_squared
	if best_target == null:
		return Vector2.ZERO
	return (best_target.global_position - origin).normalized()


func _sort_result(a: Dictionary, b: Dictionary, origin: Vector2) -> bool:
	var a_node: Node2D = a.get("collider") as Node2D
	var b_node: Node2D = b.get("collider") as Node2D
	var a_distance: float = origin.distance_squared_to(a_node.global_position)
	var b_distance: float = origin.distance_squared_to(b_node.global_position)
	if not is_equal_approx(a_distance, b_distance):
		return a_distance < b_distance
	return a_node.get_instance_id() < b_node.get_instance_id()
