class_name ShockwaveUpgradeRuntime
extends UpgradeRuntime

const CAPACITY: int = 10
const CAMERA_IMPULSE: float = 9.0

var rings: Array[ShockwaveRing2D] = []
var rampage_session: RampageSession
var robot: GiantRobotController
var camera_rig: CameraRig
var spawn_count: int = 0
var denial_count: int = 0


func _init() -> void:
	setup(&"SHOCKWAVE", 3)
	for index: int in range(CAPACITY):
		var ring: ShockwaveRing2D = ShockwaveRing2D.new()
		ring.name = "ShockwaveRing%02d" % index
		add_child(ring)
		rings.append(ring)


func setup_combat(
	attacks: ContextualAttackController,
	p_rampage_session: RampageSession,
	p_robot: GiantRobotController,
	p_camera_rig: CameraRig
) -> void:
	rampage_session = p_rampage_session
	robot = p_robot
	camera_rig = p_camera_rig
	if attacks != null:
		attacks.attack_active.connect(_on_attack_active)


func apply_rank(total_rank: int, _context: Dictionary = {}) -> bool:
	var next_rank: int = clampi(total_rank, 0, runtime_max_rank)
	if current_rank == next_rank:
		return false
	current_rank = next_rank
	return true


func set_paused(value: bool) -> void:
	super.set_paused(value)
	for ring: ShockwaveRing2D in rings:
		ring.paused = value


func stop_and_release() -> void:
	super.stop_and_release()
	for ring: ShockwaveRing2D in rings:
		ring.deactivate()


func reset_run() -> void:
	super.reset_run()
	spawn_count = 0
	denial_count = 0
	for ring: ShockwaveRing2D in rings:
		ring.paused = false
		ring.deactivate()


func active_count() -> int:
	var total: int = 0
	for ring: ShockwaveRing2D in rings:
		if ring.active:
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
	if stopped or current_rank <= 0 or spec == null or not spec.is_ground_smash():
		return
	var visual_ground: Node2D = robot.get_node_or_null(
		^"VisualRoot/VisualGroundOrigin"
	) as Node2D
	var origin: Vector2 = (
		visual_ground.global_position
		if visual_ground != null
		else robot.global_position + Vector2(0.0, 126.0)
	)
	var event: GameplayEvent = GameplayEvent.new(
		StringName("shockwave:%d" % spec.attack_id),
		spec.attack_id,
		GameplayEvent.Kind.GROUND_SMASH_SHOCKWAVE,
		GameplayEvent.SHOCKWAVE_CUE,
		0,
		0.0,
		false,
		origin,
		&""
	)
	event.root_attack_id = spec.attack_id
	event.source_id = robot.get_instance_id()
	if not rampage_session.publish(event):
		return
	if camera_rig != null:
		camera_rig.add_impact_impulse(Vector2(0.0, -CAMERA_IMPULSE))
	for ring: ShockwaveRing2D in rings:
		if not ring.active:
			ring.activate(origin, float(current_rank))
			spawn_count += 1
			return
	denial_count += 1
