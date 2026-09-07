class_name SiegeDrillRuntime
extends UpgradeRuntime

const HITBOX_CAPACITY: int = 1

var robot: GiantRobotController
var attacks: ContextualAttackController
var hitbox: SiegeDrillHitbox = SiegeDrillHitbox.new()
var deployment_count: int = 0


func _init() -> void:
	setup(&"SIEGE_DRILL", 3)
	add_child(hitbox)


func setup_combat(
	p_robot: GiantRobotController,
	p_attacks: ContextualAttackController
) -> void:
	robot = p_robot
	attacks = p_attacks
	hitbox.setup_robot(robot)
	if robot != null:
		if not robot.dodge_started.is_connected(_on_dodge_started):
			robot.dodge_started.connect(_on_dodge_started)
		if not robot.dodge_finished.is_connected(_on_dodge_finished):
			robot.dodge_finished.connect(_on_dodge_finished)
	if attacks != null and not attacks.attack_started.is_connected(_on_attack_started):
		attacks.attack_started.connect(_on_attack_started)
	set_physics_process(true)


func is_available(_context: Dictionary = {}) -> bool:
	return not stopped and robot != null and attacks != null


func apply_rank(total_rank: int, _context: Dictionary = {}) -> bool:
	var changed: bool = super.apply_rank(total_rank)
	if current_rank <= 0:
		hitbox.retract()
	return changed


func set_paused(value: bool) -> void:
	super.set_paused(value)


func stop_and_release() -> void:
	super.stop_and_release()
	hitbox.retract()


func reset_run() -> void:
	super.reset_run()
	deployment_count = 0
	hitbox.retract()


func snapshot() -> Dictionary:
	var data: Dictionary = super.snapshot()
	data.merge({
		"hitbox_capacity": HITBOX_CAPACITY,
		"active": hitbox.active,
		"deployments": deployment_count,
		"accepted_hits": hitbox.accepted_hit_count,
		"seen_targets": hitbox.hit_target_count(),
	}, true)
	return data


func _physics_process(_delta: float) -> void:
	if paused or stopped or not hitbox.active:
		return
	if robot == null or robot.locomotion_state != GiantRobotController.LocomotionState.DODGE:
		hitbox.retract()
		return
	hitbox.advance()


func _on_dodge_started(facing: int, _duration: float) -> void:
	if paused or stopped or current_rank <= 0 or robot == null:
		return
	var attack_id: int = robot.reserve_attack_id()
	if hitbox.deploy(current_rank, facing, attack_id):
		deployment_count += 1


func _on_dodge_finished() -> void:
	hitbox.retract()


func _on_attack_started(_spec: AttackSpec) -> void:
	hitbox.retract()
