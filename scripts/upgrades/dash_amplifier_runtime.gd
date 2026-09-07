class_name DashAmplifierRuntime
extends UpgradeRuntime

const SPEED_MULTIPLIERS: Array[float] = [1.0, 1.08, 1.16, 1.24]
const DURATION_MULTIPLIERS: Array[float] = [1.0, 1.15, 1.30, 1.45]
const DUST_INTENSITY_SCALES: Array[float] = [1.0, 1.2, 1.5, 1.8]

var robot: GiantRobotController


func setup_robot(p_robot: GiantRobotController) -> void:
	robot = p_robot
	setup(&"DASH_AMPLIFIER", 3)


func is_available(_context: Dictionary = {}) -> bool:
	return not stopped and robot != null


func apply_rank(total_rank: int, _context: Dictionary = {}) -> bool:
	var next_rank: int = clampi(total_rank, 0, runtime_max_rank)
	if current_rank == next_rank:
		return false
	current_rank = next_rank
	_set_dust_intensity_scale(DUST_INTENSITY_SCALES[current_rank])
	return robot._set_dodge_multipliers(
		SPEED_MULTIPLIERS[current_rank],
		DURATION_MULTIPLIERS[current_rank]
	)


func reset_run() -> void:
	super.reset_run()
	if robot != null:
		robot._set_dodge_multipliers(1.0, 1.0)
		_set_dust_intensity_scale(1.0)


func _set_dust_intensity_scale(scale: float) -> void:
	if robot == null:
		return
	var presenter: RobotAnimationPresenter = (
		robot.get_node_or_null(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	if presenter != null:
		presenter.dust_intensity_scale = scale
