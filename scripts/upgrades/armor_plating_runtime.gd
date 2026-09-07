class_name ArmorPlatingRuntime
extends UpgradeRuntime

const HEALTH_PER_RANK: float = 80.0

var robot: GiantRobotController


func setup_robot(p_robot: GiantRobotController) -> void:
	robot = p_robot
	setup(&"ARMOR_PLATING", 5)


func is_available(_context: Dictionary = {}) -> bool:
	return not stopped and robot != null


func apply_rank(total_rank: int, _context: Dictionary = {}) -> bool:
	var next_rank: int = clampi(total_rank, 0, runtime_max_rank)
	if current_rank == next_rank:
		return false
	current_rank = next_rank
	return robot.set_durability_bonus(HEALTH_PER_RANK * float(current_rank))


func reset_run() -> void:
	super.reset_run()
	if robot != null:
		robot.set_durability_bonus(0.0)
