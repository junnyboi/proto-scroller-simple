class_name DirectionalPunchShockwaveRuntime
extends UpgradeRuntime

const CAPACITY: int = 10
const PULSE_DELAY_SECONDS: float = 0.085
const ORIGIN_Y_OFFSET: float = 18.0
const PUNCH_LANE_OFFSET_Y: float = 18.0
const FORWARD_OFFSET: float = 96.0

var waves: Array[DirectionalShockwave2D] = []
var robot: GiantRobotController
var spawn_count: int = 0
var denial_count: int = 0


func _init() -> void:
	setup(&"PUNCH_SHOCKWAVE", 3)
	for index: int in range(CAPACITY):
		var wave: DirectionalShockwave2D = DirectionalShockwave2D.new()
		wave.name = "DirectionalPunchShockwave%02d" % index
		add_child(wave)
		waves.append(wave)


func setup_combat(
	attacks: ContextualAttackController,
	p_robot: GiantRobotController
) -> void:
	robot = p_robot
	if attacks != null and not attacks.attack_active.is_connected(_on_attack_active):
		attacks.attack_active.connect(_on_attack_active)


func apply_rank(total_rank: int, _context: Dictionary = {}) -> bool:
	var next_rank: int = clampi(total_rank, 0, runtime_max_rank)
	if current_rank == next_rank:
		return false
	current_rank = next_rank
	return true


func set_paused(value: bool) -> void:
	super.set_paused(value)
	for wave: DirectionalShockwave2D in waves:
		wave.paused = value


func stop_and_release() -> void:
	super.stop_and_release()
	for wave: DirectionalShockwave2D in waves:
		wave.deactivate()


func reset_run() -> void:
	super.reset_run()
	spawn_count = 0
	denial_count = 0
	for wave: DirectionalShockwave2D in waves:
		wave.paused = false
		wave.deactivate()


func active_count() -> int:
	var total: int = 0
	for wave: DirectionalShockwave2D in waves:
		if wave.active:
			total += 1
	return total


func snapshot() -> Dictionary:
	var data: Dictionary = super.snapshot()
	data.merge({
		"capacity": CAPACITY,
		"active": active_count(),
		"spawned": spawn_count,
		"denied": denial_count,
	}, true)
	return data


func _on_attack_active(spec: AttackSpec) -> void:
	if stopped or current_rank <= 0 or spec == null or not spec.is_jab_cross():
		return
	if robot == null:
		return
	var visual_root: Node2D = robot.get_node_or_null(^"VisualRoot") as Node2D
	var visual_anchor: Vector2 = (
		visual_root.global_position if visual_root != null else robot.global_position
	)
	var origin: Vector2 = visual_anchor + Vector2(
		float(spec.facing) * FORWARD_OFFSET,
		ORIGIN_Y_OFFSET
	)
	for pulse_index: int in range(2):
		var wave: DirectionalShockwave2D = _available_wave()
		if wave == null:
			denial_count += 1
			continue
		var delivery_id: int = spec.attack_id * 10 + pulse_index + 1
		var lane_direction: float = -1.0 if pulse_index == 0 else 1.0
		var wave_origin: Vector2 = origin + Vector2(
			0.0,
			lane_direction * PUNCH_LANE_OFFSET_Y
		)
		wave.activate(
			wave_origin,
			spec.facing,
			delivery_id,
			spec.attack_id,
			robot,
			current_rank,
			spec.effect_flags,
			float(pulse_index) * PULSE_DELAY_SECONDS
		)
		spawn_count += 1


func _available_wave() -> DirectionalShockwave2D:
	for wave: DirectionalShockwave2D in waves:
		if not wave.active:
			return wave
	return null
