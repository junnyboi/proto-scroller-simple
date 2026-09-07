class_name SiegeDrillHitbox
extends Node2D

const MOUNT_TEXTURE: Texture2D = preload(
	"res://assets/player/weapons/siege_drill_mount.png"
)
const ENEMY_LAYER: int = 1 << 2
const HURTBOX_LAYER: int = 1 << 6
const PROP_LAYER: int = 1 << 7
const DEBRIS_LAYER: int = 1 << 8
const REMAINS_LAYER: int = 1 << 9
const TARGET_MASK: int = (
	ENEMY_LAYER | HURTBOX_LAYER | PROP_LAYER | DEBRIS_LAYER | REMAINS_LAYER
)
const QUERY_SIZE: Vector2 = Vector2(126.0, 92.0)
const FORWARD_OFFSET: float = 106.0
const VISUAL_SCALE_MULTIPLIER: float = 1.5
const ROBOT_VISUAL_PATH: NodePath = ^"VisualRoot/RobotAnimatedSprite"
const MAX_RESULTS: int = 24
const ACTOR_DAMAGE: Array[float] = [0.0, 40.0, 48.0, 56.0]
const STRUCTURAL_DAMAGE: Array[float] = [0.0, 36.0, 44.0, 52.0]
const IMPULSE_PER_MASS: Array[float] = [0.0, 360.0, 420.0, 480.0]

var active: bool = false
var current_rank: int = 0
var attack_id: int = 0
var facing: int = 1
var accepted_hit_count: int = 0
var last_query_count: int = 0
var _robot: GiantRobotController
var _shape: RectangleShape2D = RectangleShape2D.new()
var _parameters: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
var _visual: Sprite2D = Sprite2D.new()
var _hit_target_ids: PackedInt64Array = PackedInt64Array()
var _hit_target_count: int = 0


func _init() -> void:
	name = "SiegeDrillHitbox"
	z_index = 104
	_shape.size = QUERY_SIZE
	_parameters.shape = _shape
	_parameters.collision_mask = TARGET_MASK
	_parameters.collide_with_areas = true
	_parameters.collide_with_bodies = true
	_visual.name = "SiegeDrillMount"
	_visual.texture = MOUNT_TEXTURE
	_visual.centered = true
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_visual.visible = false
	add_child(_visual)
	_hit_target_ids.resize(MAX_RESULTS)


func setup_robot(robot: GiantRobotController) -> void:
	_robot = robot
	_parameters.exclude = [robot.get_rid()] if robot != null else []
	retract()


func deploy(p_rank: int, p_facing: int, p_attack_id: int) -> bool:
	if _robot == null or p_rank <= 0 or p_attack_id <= 0:
		return false
	current_rank = clampi(p_rank, 1, 3)
	facing = -1 if p_facing < 0 else 1
	attack_id = p_attack_id
	accepted_hit_count = 0
	last_query_count = 0
	_clear_hit_targets()
	active = true
	_visual.visible = true
	_sync_transform()
	return true


func advance() -> int:
	if not active or _robot == null:
		return 0
	_sync_transform()
	return _resolve_contacts()


func retract() -> void:
	active = false
	current_rank = 0
	attack_id = 0
	accepted_hit_count = 0
	last_query_count = 0
	_clear_hit_targets()
	_visual.visible = false


func hit_target_count() -> int:
	return _hit_target_count


func _sync_transform() -> void:
	facing = -1 if _robot.facing < 0 else 1
	global_position = _robot_visual_center() + Vector2(
		float(facing) * FORWARD_OFFSET,
		0.0
	)
	_visual.scale = Vector2(float(facing), 1.0) * VISUAL_SCALE_MULTIPLIER


func _robot_visual_center() -> Vector2:
	var robot_visual: Node2D = _robot.get_node_or_null(ROBOT_VISUAL_PATH) as Node2D
	return robot_visual.global_position if robot_visual != null else _robot.global_position


func _resolve_contacts() -> int:
	_parameters.transform = Transform2D(0.0, global_position)
	var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(
		_parameters,
		MAX_RESULTS
	)
	if results.size() > 1:
		results.sort_custom(
			_sort_by_forward_distance.bind(_robot.global_position, facing)
		)
	last_query_count = results.size()
	var accepted_this_step: int = 0
	for result: Dictionary in results:
		var collider: Node2D = result.get("collider") as Node2D
		if collider == null or collider == _robot or _robot.is_ancestor_of(collider):
			continue
		if (collider.global_position.x - _robot.global_position.x) * float(facing) <= 0.0:
			continue
		var receiver: Node = DamageReceiverLookup.find(collider)
		var target: Node = receiver if receiver != null else collider
		var target_id: int = target.get_instance_id()
		if _has_hit_target(target_id):
			continue
		_remember_hit_target(target_id)
		var event: DamageEvent = _make_event(collider, receiver)
		var accepted: bool = _deliver_damage(receiver, event)
		var rigid_hit: bool = _apply_rigid_impulse(target, collider, event)
		if not accepted and not rigid_hit:
			continue
		accepted_hit_count += 1
		accepted_this_step += 1
	return accepted_this_step


func _clear_hit_targets() -> void:
	_hit_target_count = 0
	_hit_target_ids.fill(0)


func _has_hit_target(target_id: int) -> bool:
	for index: int in range(_hit_target_count):
		if _hit_target_ids[index] == target_id:
			return true
	return false


func _remember_hit_target(target_id: int) -> void:
	if _hit_target_count >= MAX_RESULTS:
		return
	_hit_target_ids[_hit_target_count] = target_id
	_hit_target_count += 1


func _make_event(collider: Node2D, receiver: Node) -> DamageEvent:
	var damage: float = (
		STRUCTURAL_DAMAGE[current_rank]
		if receiver is Destructible2D or receiver is StructuralBuilding2D
		else ACTOR_DAMAGE[current_rank]
	)
	var direction: Vector2 = Vector2(float(facing), -0.08).normalized()
	return DamageEvent.new(
		attack_id,
		_robot,
		damage,
		&"jab_cross",
		collider.global_position,
		direction,
		IMPULSE_PER_MASS[current_rank],
		attack_id,
		0,
		DamageEvent.FLAG_SIEGE_DRILL
	)


func _deliver_damage(receiver: Node, event: DamageEvent) -> bool:
	if receiver == null or not receiver.has_method("receive_damage"):
		return false
	if receiver is EnemyWreck2D:
		return (receiver as EnemyWreck2D).reduce_to_rubble(event)
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


func _sort_by_forward_distance(
	a: Dictionary,
	b: Dictionary,
	origin: Vector2,
	p_facing: int
) -> bool:
	var first: Node2D = a.get("collider") as Node2D
	var second: Node2D = b.get("collider") as Node2D
	if first == null:
		return false
	if second == null:
		return true
	var first_distance: float = (first.global_position.x - origin.x) * float(p_facing)
	var second_distance: float = (second.global_position.x - origin.x) * float(p_facing)
	if not is_equal_approx(first_distance, second_distance):
		return first_distance < second_distance
	return first.get_instance_id() < second.get_instance_id()
