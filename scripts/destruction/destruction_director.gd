class_name DestructionDirector
extends Node2D

signal explosion_resolved(origin: Vector2, accepted_targets: int)
signal enemy_hits_resolved(attack_id: int, world_position: Vector2, enemy_count: int)

const GROUND_SMASH_PROP_DAMAGE_SCALE: float = 5.0

@export_flags_2d_physics var blast_mask: int = 0
@export_range(1, 64, 1) var max_results: int = 32
@export_range(1, 8, 1) var max_explosions_per_tick: int = 4

var _queue: Array[Dictionary] = []
var _blast_shape: CircleShape2D = CircleShape2D.new()
var _blast_parameters: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()


func _init() -> void:
	_blast_parameters.shape = _blast_shape


func queue_explosion(
	origin: Vector2,
	radius: float,
	peak_damage: float,
	impulse_per_mass: float,
	attack_id: int,
	source: Node = null,
	options: DamageQueryOptions = null
) -> void:
	if radius <= 0.0 or peak_damage <= 0.0:
		return
	_queue.append({
		"origin": origin,
		"radius": radius,
		"peak_damage": peak_damage,
		"impulse_per_mass": maxf(impulse_per_mass, 0.0),
		"attack_id": attack_id,
		"source": source,
		"root_attack_id": options.root_attack_id if options != null else attack_id,
		"causal_depth": options.causal_depth if options != null else 0,
		"effect_flags": options.effect_flags if options != null else DamageEvent.FLAG_NONE,
		"kinetic_debris_bonus": options.kinetic_debris_bonus if options != null else 0.0,
		"result_limit": options.result_limit if options != null else 0,
		"structural_limit": options.structural_limit if options != null else 0,
		"debris_limit": options.debris_limit if options != null else 0,
		"damage_type": options.damage_type if options != null else &"explosive",
		"player_damage_scale": options.player_damage_scale if options != null else 1.0,
		"enemy_damage_scale": options.enemy_damage_scale if options != null else 1.0,
		"structural_damage_scale": (
			options.structural_damage_scale if options != null else 1.0
		),
	})


func cancel_effect_flags(effect_flags: int) -> void:
	for index: int in range(_queue.size() - 1, -1, -1):
		if int(_queue[index].effect_flags) & effect_flags:
			_queue.remove_at(index)


func rebase_cached_world_state(offset: Vector2) -> void:
	for record: Dictionary in _queue:
		record.origin = (record.origin as Vector2) + offset


func _physics_process(_delta: float) -> void:
	var count: int = mini(max_explosions_per_tick, _queue.size())
	for explosion_index: int in range(count):
		_resolve_explosion(_queue.pop_front())


func _resolve_explosion(data: Dictionary) -> void:
	var origin: Vector2 = data["origin"] as Vector2
	var radius: float = data["radius"] as float
	_blast_shape.radius = radius
	_blast_parameters.transform = Transform2D(0.0, origin)
	_blast_parameters.collision_mask = blast_mask
	_blast_parameters.collide_with_areas = true
	_blast_parameters.collide_with_bodies = true
	_blast_parameters.exclude = []
	if is_instance_valid(data["source"] as Node):
		var source_object: CollisionObject2D = data["source"] as CollisionObject2D
		if source_object != null:
			_blast_parameters.exclude = [source_object.get_rid()]
	var query_limit: int = int(data.result_limit)
	if query_limit <= 0:
		query_limit = max_results
	var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(
		_blast_parameters,
		mini(query_limit, max_results)
	)
	var seen: Dictionary[int, bool] = {}
	var accepted_targets: int = 0
	var enemy_count: int = 0
	var enemy_hit_position: Vector2 = origin
	var structural_targets: int = 0
	var debris_targets: int = 0
	for result: Dictionary in results:
		var collider: Object = result.get("collider") as Object
		if collider == null:
			continue
		var collider_node: Node = collider as Node
		var source_node: Node = data["source"] as Node
		if _is_source_related(collider_node, source_node):
			continue
		var collider_id: int = collider.get_instance_id()
		if seen.has(collider_id):
			continue
		seen[collider_id] = true
		var target_node: Node2D = collider as Node2D
		if target_node == null:
			continue
		var receiver: Node = _damage_receiver(target_node)
		var debris: DebrisBody2D = target_node as DebrisBody2D
		if (
			debris != null
			and debris.is_aerial_shrapnel_for_attack(int(data.attack_id))
		):
			continue
		if receiver is Destructible2D and int(data.structural_limit) > 0:
			if structural_targets >= int(data.structural_limit):
				continue
			structural_targets += 1
		if receiver is DebrisBody2D and int(data.debris_limit) > 0:
			if debris_targets >= int(data.debris_limit):
				continue
			debris_targets += 1
		var offset: Vector2 = target_node.global_position - origin
		var distance: float = offset.length()
		var direction: Vector2 = offset.normalized()
		if direction.is_zero_approx():
			direction = Vector2.UP
		var normalized_distance: float = clampf(distance / radius, 0.0, 1.0)
		var falloff: float = pow(1.0 - normalized_distance, 2.0)
		if falloff <= 0.0:
			continue
		var event: DamageEvent = DamageEvent.new(
			data["attack_id"] as int,
			data["source"] as Node,
			(data["peak_damage"] as float) * falloff,
			StringName(data.damage_type),
			origin,
			direction,
			(data["impulse_per_mass"] as float) * falloff,
			int(data.root_attack_id),
			int(data.causal_depth),
				int(data.effect_flags),
				float(data.kinetic_debris_bonus)
			)
		var receiver_scale: float = _damage_scale_for(receiver, data)
		if receiver_scale <= 0.0:
			continue
		var scaled_event: DamageEvent = event.scaled(receiver_scale)
		var accepted: bool = _deliver_damage(receiver, scaled_event)
		_apply_rigid_impulse(target_node, scaled_event)
		if accepted:
			accepted_targets += 1
			if receiver is EnemyActor2D:
				enemy_count += 1
				if enemy_count == 1:
					enemy_hit_position = target_node.global_position
	explosion_resolved.emit(origin, accepted_targets)
	if enemy_count > 0:
		enemy_hits_resolved.emit(int(data.attack_id), enemy_hit_position, enemy_count)


func _is_source_related(candidate: Node, source: Node) -> bool:
	if candidate == null or source == null:
		return false
	return candidate == source or source.is_ancestor_of(candidate)


func _deliver_damage(receiver: Node, event: DamageEvent) -> bool:
	if receiver != null:
		return bool(receiver.call("receive_damage", event))
	return false


func _damage_scale_for(receiver: Node, data: Dictionary) -> float:
	if receiver is GiantRobotController:
		return maxf(float(data.player_damage_scale), 0.0)
	if receiver is EnemyActor2D:
		return maxf(float(data.enemy_damage_scale), 0.0)
	if receiver is Destructible2D or receiver is StructuralBuilding2D:
		return maxf(float(data.structural_damage_scale), 0.0)
	if receiver is DestructibleProp2D and StringName(data.damage_type) == &"ground_smash":
		return GROUND_SMASH_PROP_DAMAGE_SCALE
	return 1.0


func _damage_receiver(start_node: Node) -> Node:
	return DamageReceiverLookup.find(start_node)


func _apply_rigid_impulse(start_node: Node, event: DamageEvent) -> void:
	var body: RigidBody2D = start_node as RigidBody2D
	if body == null:
		body = start_node.get_parent() as RigidBody2D
	if body == null or event.impulse_per_mass <= 0.0:
		return
	var impulse: Vector2 = event.direction * event.impulse_per_mass * body.mass
	var impact_offset: Vector2 = event.hit_position - body.global_position
	body.apply_impulse(impulse, impact_offset)
