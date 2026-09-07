class_name ChassisRepairPickup2D
extends Area2D

signal collected(pickup: ChassisRepairPickup2D, repaired_health: float)
signal expired(pickup: ChassisRepairPickup2D)

const ROBOT_LAYER: int = 1 << 1
const REPAIR_AMOUNT: float = 50.0
const LIFETIME_SECONDS: float = 12.0
const HOVER_AMPLITUDE: float = 7.0
const HOVER_SPEED: float = 2.8
const PICKUP_TEXTURE: Texture2D = preload(
	"res://assets/city/pickups/aegis_patch_cell.png"
)

var active: bool = false
var repair_amount: float = REPAIR_AMOUNT
var _lifetime_remaining: float = 0.0
var _phase: float = 0.0
var _origin: Vector2 = Vector2.ZERO
var _visual: Sprite2D
var _collision: CollisionShape2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = ROBOT_LAYER
	monitoring = false
	monitorable = false
	body_entered.connect(_on_body_entered)
	_visual = Sprite2D.new()
	_visual.name = "Visual"
	_visual.texture = PICKUP_TEXTURE
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_visual.scale = Vector2.ONE * 0.25
	add_child(_visual)
	_collision = CollisionShape2D.new()
	_collision.name = "CollisionShape2D"
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 38.0
	_collision.shape = circle
	add_child(_collision)
	reset_pickup()


func _process(delta: float) -> void:
	if not active:
		return
	_lifetime_remaining = maxf(_lifetime_remaining - delta, 0.0)
	_phase += delta * HOVER_SPEED
	position.y = _origin.y + sin(_phase) * HOVER_AMPLITUDE
	var pulse: float = 1.0 + sin(_phase * 1.4) * 0.035
	_visual.scale = Vector2.ONE * 0.25 * pulse
	if is_zero_approx(_lifetime_remaining):
		reset_pickup()
		expired.emit(self)


func activate(
	world_position: Vector2,
	p_repair_amount: float = REPAIR_AMOUNT,
	p_lifetime_seconds: float = LIFETIME_SECONDS
) -> void:
	_origin = world_position
	position = world_position
	_phase = 0.0
	_lifetime_remaining = maxf(p_lifetime_seconds, 0.01)
	repair_amount = maxf(p_repair_amount, 0.0)
	active = true
	visible = true
	set_deferred("monitoring", true)
	_collision.set_deferred("disabled", false)
	set_process(true)


func reset_pickup() -> void:
	active = false
	visible = false
	set_deferred("monitoring", false)
	if _collision != null:
		_collision.set_deferred("disabled", true)
	_lifetime_remaining = 0.0
	_phase = 0.0
	repair_amount = REPAIR_AMOUNT
	position = Vector2(-4096.0, -4096.0)
	_origin = position
	set_process(false)


func try_collect(robot: GiantRobotController) -> bool:
	if not active or robot == null:
		return false
	var repaired_health: float = robot.repair_chassis(repair_amount)
	if repaired_health <= 0.0:
		return false
	reset_pickup()
	collected.emit(self, repaired_health)
	return true


func remaining_lifetime() -> float:
	return _lifetime_remaining


func _on_body_entered(body: Node) -> void:
	var robot: GiantRobotController = body as GiantRobotController
	if robot != null:
		try_collect(robot)
