class_name EngineUpgradeRuntime
extends UpgradeRuntime

const SPEED_MULTIPLIERS: Array[float] = [1.0, 1.08, 1.16, 1.24]
const ACCEL_MULTIPLIERS: Array[float] = [1.0, 1.12, 1.24, 1.36]
const DECEL_MULTIPLIERS: Array[float] = [1.0, 1.08, 1.16, 1.24]

var robot: GiantRobotController


func setup_robot(p_robot: GiantRobotController) -> void:
	robot = p_robot
	setup(&"ENGINE", 3)


func is_available(_context: Dictionary = {}) -> bool:
	return not stopped and robot != null


func apply_rank(total_rank: int, _context: Dictionary = {}) -> bool:
	var next_rank: int = clampi(total_rank, 0, runtime_max_rank)
	if current_rank == next_rank:
		return false
	current_rank = next_rank
	return robot.set_engine_multipliers(
		SPEED_MULTIPLIERS[current_rank],
		ACCEL_MULTIPLIERS[current_rank],
		DECEL_MULTIPLIERS[current_rank]
	)


func reset_run() -> void:
	super.reset_run()
	if robot != null:
		robot.set_engine_multipliers(1.0, 1.0, 1.0)
