class_name JabCrossImpact
extends Node2D

signal jab_cross_resolved(spec: AttackSpec, accepted_targets: int, velocity_retention: float)
signal enemy_hit_resolved(spec: AttackSpec, enemy_count: int, world_position: Vector2)

const ENEMY_LAYER: int = 1 << 2
const HURTBOX_LAYER: int = 1 << 6
const PROP_LAYER: int = 1 << 7
const DEBRIS_LAYER: int = 1 << 8
const REMAINS_LAYER: int = 1 << 9

@export_flags_2d_physics var target_mask: int = (
	ENEMY_LAYER | HURTBOX_LAYER | PROP_LAYER | DEBRIS_LAYER | REMAINS_LAYER
)
@export_range(1, 32, 1) var max_results: int = 32

@export_group("Velocity Response")
@export_range(0.0, 1.0, 0.01) var light_retention: float = 0.94
@export_range(0.0, 1.0, 0.01) var prop_retention: float = 0.92
@export_range(0.0, 1.0, 0.01) var wreck_retention: float = 0.60
@export_range(0.0, 1.0, 0.01) var tank_retention: float = 0.54
@export_range(0.0, 1.0, 0.01) var glass_retention: float = 0.94
@export_range(0.0, 1.0, 0.01) var concrete_retention: float = 0.72
@export_range(0.0, 1.0, 0.01) var steel_breach_retention: float = 0.38
@export_range(0.0, 0.25, 0.01) var steel_rebound_ratio: float = 0.06

var last_query_count: int = 0
var last_accepted_targets: int = 0
var last_velocity_retention: float = 1.0
var last_opening_compression: bool = false
var _shape: RectangleShape2D = RectangleShape2D.new()
var _parameters: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()


func _init() -> void:
	_parameters.shape = _shape


func resolve(spec: AttackSpec, robot: GiantRobotController) -> int:
	if spec == null or robot == null or not spec.is_jab_cross():
		return 0
	last_opening_compression = spec.opening_compression
	_shape.size = (
		spec.hit_size * Vector2(1.20, 1.08)
		if spec.opening_compression
		else spec.hit_size
	)
	_parameters.transform = Transform2D(
		0.0,
		robot.global_position + Vector2(
			spec.hit_offset.x * float(spec.facing),
			spec.hit_offset.y
		)
	)
	_parameters.collision_mask = target_mask
	_parameters.collide_with_areas = true
	_parameters.collide_with_bodies = true
	_parameters.exclude = [robot.get_rid()]
	var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(
		_parameters,
		max_results
	)
	if results.size() > 1:
		results.sort_custom(_sort_by_forward_distance.bind(robot.global_position, spec.facing))
	last_query_count = results.size()
	last_accepted_targets = 0
	last_velocity_retention = 1.0
	var impact_speed: float = absf(robot.velocity.x)
	var blocked_by_steel: bool = false
	var enemy_count: int = 0
	var enemy_hit_position: Vector2 = robot.global_position
	var seen_targets: Dictionary[int, bool] = {}
	for result: Dictionary in results:
		var collider: Node2D = result.get("collider") as Node2D
		if collider == null or robot.is_ancestor_of(collider):
			continue
		if (collider.global_position.x - robot.global_position.x) * float(spec.facing) <= 0.0:
			continue
		var receiver: Node = DamageReceiverLookup.find(collider)
		var target: Node = receiver if receiver != null else collider
		var target_id: int = target.get_instance_id()
		if seen_targets.has(target_id):
			continue
		seen_targets[target_id] = true
		var intact_steel: bool = _is_intact_steel(receiver)
		var event: DamageEvent = _make_event(spec, robot, collider, receiver)
		var accepted: bool = _deliver_damage(receiver, event)
		var rigid_hit: bool = _apply_rigid_impulse(target, collider, event)
		if not accepted and not rigid_hit:
			continue
		last_accepted_targets += 1
		if accepted and receiver is EnemyActor2D:
			enemy_count += 1
			if enemy_count == 1:
				enemy_hit_position = collider.global_position
		last_velocity_retention = minf(
			last_velocity_retention,
			_retention_for_target(target)
		)
		blocked_by_steel = blocked_by_steel or (
			intact_steel and _is_intact_steel(receiver)
		)
		if intact_steel or receiver is Destructible2D:
			break
	if blocked_by_steel:
		last_velocity_retention = -steel_rebound_ratio
		robot.velocity.x = -float(spec.facing) * impact_speed * steel_rebound_ratio
	else:
		robot.velocity.x *= last_velocity_retention
	jab_cross_resolved.emit(spec, last_accepted_targets, last_velocity_retention)
	if enemy_count > 0:
		enemy_hit_resolved.emit(spec, enemy_count, enemy_hit_position)
	return last_accepted_targets


func _make_event(
	spec: AttackSpec,
	robot: GiantRobotController,
	collider: Node2D,
	receiver: Node
) -> DamageEvent:
	var damage: float = (
		spec.structural_damage
		if receiver is Destructible2D or receiver is StructuralBuilding2D
		else spec.actor_damage
	)
	var direction: Vector2 = Vector2(float(spec.facing), -0.08).normalized()
	var effect_flags: int = spec.effect_flags
	if spec.is_fully_charged():
		effect_flags |= DamageEvent.FLAG_FULL_CHARGE
	return DamageEvent.new(
		spec.attack_id,
		robot,
		damage,
		&"jab_cross",
		collider.global_position,
		direction,
		spec.impulse_per_mass,
		spec.attack_id,
		0,
		effect_flags,
		spec.kinetic_debris_bonus
	)


func _deliver_damage(receiver: Node, event: DamageEvent) -> bool:
	if receiver == null:
		return false
	return bool(receiver.call("receive_damage", event))


func _apply_rigid_impulse(target: Node, collider: Node, event: DamageEvent) -> bool:
	var body: RigidBody2D = target as RigidBody2D
	if body == null:
		body = collider as RigidBody2D
	if body == null:
		body = collider.get_parent() as RigidBody2D
	if body == null or event.impulse_per_mass <= 0.0:
		return false
	if body.freeze:
		body.freeze = false
		body.sleeping = false
	body.apply_central_impulse(event.direction * event.impulse_per_mass * body.mass)
	return true


func _is_intact_steel(receiver: Node) -> bool:
	if not receiver is Destructible2D:
		return false
	var cell: Destructible2D = receiver as Destructible2D
	var profile: StructuralMaterialProfile = cell.get_material_profile()
	return profile != null and profile.material_id == &"steel" and not cell.is_destroyed()


func _retention_for_target(target: Node) -> float:
	var retention: float = light_retention
	if target is Destructible2D:
		var profile: StructuralMaterialProfile = (target as Destructible2D).get_material_profile()
		if profile != null:
			if profile.material_id == &"steel":
				retention = steel_breach_retention
			elif profile.material_id == &"concrete":
				retention = concrete_retention
			else:
				retention = glass_retention
	elif target is EnemyWreck2D:
		retention = wreck_retention
	elif target is TankEnemy:
		retention = tank_retention
	elif target is DestructibleProp2D:
		retention = prop_retention
	return retention


func _sort_by_forward_distance(
	a: Dictionary,
	b: Dictionary,
	origin: Vector2,
	facing: int
) -> bool:
	var first: Node2D = a.get("collider") as Node2D
	var second: Node2D = b.get("collider") as Node2D
	if first == null:
		return false
	if second == null:
		return true
	var first_distance: float = (first.global_position.x - origin.x) * float(facing)
	var second_distance: float = (second.global_position.x - origin.x) * float(facing)
	return first_distance < second_distance
