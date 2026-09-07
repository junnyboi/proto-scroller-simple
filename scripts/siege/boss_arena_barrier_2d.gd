class_name BossArenaBarrier2D
extends Node2D

const COLLISION_LAYER: int = 1 << 12
const OFFSET_FROM_BOSS_X: float = 520.0
const BARRIER_SIZE: Vector2 = Vector2(48.0, 2400.0)

var body: StaticBody2D
var collision: CollisionShape2D
var active: bool = false
var activation_count: int = 0


func _init() -> void:
	name = "BossArenaBarrier2D"
	body = StaticBody2D.new()
	body.name = "InvisibleRightBoundary"
	body.collision_layer = COLLISION_LAYER
	body.collision_mask = 0
	add_child(body)
	collision = CollisionShape2D.new()
	collision.name = "Collision"
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = BARRIER_SIZE
	collision.shape = shape
	collision.disabled = true
	body.add_child(collision)


func activate(boss_position: Vector2, robot: GiantRobotController) -> bool:
	if robot == null:
		return false
	global_position = boss_position + Vector2(OFFSET_FROM_BOSS_X, 0.0)
	collision.disabled = false
	robot.collision_mask |= COLLISION_LAYER
	active = true
	activation_count += 1
	return true


func deactivate(robot: GiantRobotController) -> void:
	collision.disabled = true
	if robot != null:
		robot.collision_mask &= ~COLLISION_LAYER
	active = false
