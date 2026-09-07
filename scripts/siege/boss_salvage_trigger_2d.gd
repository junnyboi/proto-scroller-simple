class_name BossSalvageTrigger2D
extends Area2D

signal claimed

const ROBOT_LAYER: int = 1 << 1
const TRIGGER_SIZE: Vector2 = Vector2(360.0, 180.0)
const ARM_DELAY_SECONDS: float = 0.08

var definition: BossEncounterDefinition
var active: bool = false
var armed: bool = false
var elapsed: float = 0.0
var claim_count: int = 0
var _collision: CollisionShape2D


func _init() -> void:
	name = "BossSalvageTrigger2D"
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	z_index = 43
	_collision = CollisionShape2D.new()
	_collision.name = "Collision"
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = TRIGGER_SIZE
	_collision.shape = shape
	_collision.position = Vector2(0.0, -70.0)
	_collision.disabled = true
	add_child(_collision)
	body_entered.connect(_on_body_entered)
	visible = false


func configure(p_definition: BossEncounterDefinition, world_position: Vector2) -> void:
	definition = p_definition
	global_position = world_position
	active = definition != null
	armed = false
	elapsed = 0.0
	collision_mask = ROBOT_LAYER if active else 0
	monitoring = active
	monitorable = active
	_collision.disabled = not active
	visible = active
	set_process(active)
	queue_redraw()


func deactivate() -> void:
	definition = null
	active = false
	armed = false
	elapsed = 0.0
	collision_mask = 0
	monitoring = false
	monitorable = false
	_collision.disabled = true
	visible = false
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	if not armed and elapsed >= ARM_DELAY_SECONDS:
		armed = true
	for body: Node2D in get_overlapping_bodies():
		if _is_robot(body):
			_claim()
			return
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if active and armed and _is_robot(body):
		_claim()


func _claim() -> void:
	if not active:
		return
	active = false
	claim_count += 1
	collision_mask = 0
	monitoring = false
	_collision.set_deferred(&"disabled", true)
	visible = false
	claimed.emit()


func _is_robot(body: Node) -> bool:
	return body is GiantRobotController


func _draw() -> void:
	if not active:
		return
	var pulse: float = 0.72 + sin(elapsed * 5.0) * 0.18
	var color: Color = Color(1.0, 0.68, 0.20, pulse)
	draw_arc(Vector2(0.0, -24.0), 92.0, 0.0, TAU, 40, color, 5.0)
	draw_line(Vector2(-118.0, 8.0), Vector2(118.0, 8.0), Color(color, pulse * 0.55), 3.0)
