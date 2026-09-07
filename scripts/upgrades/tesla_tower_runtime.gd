class_name TeslaTowerRuntime
extends UpgradeRuntime

const TOWER_CAPACITY: int = 1
const ARC_CAPACITY: int = TeslaTower2D.ARC_CAPACITY
const DEPLOYMENT_OFFSET: Vector2 = Vector2(0.0, 40.0)

var robot: GiantRobotController
var attacks: ContextualAttackController
var encounter: EncounterRuntime
var tower: TeslaTower2D
var deployment_count: int = 0


func _init() -> void:
	setup(&"TESLA_TOWER", 3)


func _ready() -> void:
	tower = TeslaTower2D.new()
	tower.name = "TeslaTower"
	add_child(tower)
	if robot != null and encounter != null:
		tower.setup(robot, encounter)


func setup_combat(
	p_robot: GiantRobotController,
	p_attacks: ContextualAttackController,
	p_encounter: EncounterRuntime
) -> void:
	robot = p_robot
	attacks = p_attacks
	encounter = p_encounter
	if tower != null:
		tower.setup(robot, encounter)
	if attacks != null and not attacks.charge_released.is_connected(_on_charge_released):
		attacks.charge_released.connect(_on_charge_released)
	if robot != null and not robot.defeated.is_connected(_on_robot_defeated):
		robot.defeated.connect(_on_robot_defeated)


func is_available(_context: Dictionary = {}) -> bool:
	return (
		not stopped
		and robot != null
		and attacks != null
		and encounter != null
		and tower != null
	)


func apply_rank(total_rank: int, _context: Dictionary = {}) -> bool:
	var changed: bool = super.apply_rank(total_rank)
	if current_rank <= 0 and tower != null:
		tower.deactivate()
	return changed


func set_paused(value: bool) -> void:
	super.set_paused(value)
	if tower != null:
		tower.set_paused(value)


func stop_and_release() -> void:
	if tower != null:
		tower.deactivate()
	super.stop_and_release()


func reset_run() -> void:
	if tower != null:
		tower.deactivate()
	super.reset_run()
	deployment_count = 0


func snapshot() -> Dictionary:
	var data: Dictionary = super.snapshot()
	data.merge({
		"tower_capacity": TOWER_CAPACITY,
		"arc_capacity": ARC_CAPACITY,
		"deployments": deployment_count,
		"tower": tower.snapshot() if tower != null else {},
	}, true)
	return data


func _on_charge_released(
	spec: AttackSpec,
	_duration: float,
	_multiplier: float
) -> void:
	if (
		stopped
		or current_rank <= 0
		or spec == null
		or not spec.is_fully_charged()
		or tower == null
	):
		return
	var visual_ground: Node2D = robot.get_node_or_null(
		^"VisualRoot/VisualGroundOrigin"
	) as Node2D
	var origin: Vector2 = (
		visual_ground.global_position
		if visual_ground != null
		else robot.global_position + Vector2(0.0, 126.0)
	) + DEPLOYMENT_OFFSET
	if tower.activate(origin, current_rank, spec.attack_id):
		deployment_count += 1


func _on_robot_defeated() -> void:
	if tower != null:
		tower.deactivate()
