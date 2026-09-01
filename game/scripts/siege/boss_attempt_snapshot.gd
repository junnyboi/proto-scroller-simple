class_name BossAttemptSnapshot
extends RefCounted

var valid: bool = false
var boss_state: Dictionary = {}
var score_state: Dictionary = {}
var event_history_state: Dictionary = {}
var recorder_state: Dictionary = {}
var reservation_state: Dictionary = {}
var gate_state: Dictionary = {}
var robot_state: Dictionary = {}


func capture(
	lease: ArenaLease,
	session: CommandBossSession,
	rampage: RampageSession,
	gate: BossGateMarker,
	robot: GiantRobotController,
	world_stream: CityWorldStream
) -> bool:
	if (
		lease == null
		or not lease.active
		or session == null
		or rampage == null
		or gate == null
		or robot == null
		or world_stream == null
	):
		return false
	boss_state = session.capture_attempt_state()
	score_state = rampage.run_score.capture_attempt_state()
	event_history_state = rampage.event_hub.capture_attempt_state()
	recorder_state = rampage.causal_chain_tracker.capture_attempt_state()
	reservation_state = session.utility_pool.capture_reservation_state()
	gate_state = gate.capture_state()
	robot_state = {
		"health": robot.current_health,
		"maximum": robot.max_health,
	}
	valid = true
	return true


func capture_boss_runtime(session: CommandBossSession) -> bool:
	if not valid or session == null or not session.active():
		return false
	boss_state = session.capture_attempt_state()
	return true


func restore(
	lease: ArenaLease,
	session: CommandBossSession,
	rampage: RampageSession,
	gate: BossGateMarker,
	robot: GiantRobotController,
	world_stream: CityWorldStream
) -> bool:
	if not valid or lease == null or not lease.active:
		return false
	session.restore_attempt_state(boss_state)
	rampage.run_score.restore_attempt_state(score_state)
	rampage.event_hub.restore_attempt_state(event_history_state)
	rampage.causal_chain_tracker.restore_attempt_state(recorder_state)
	session.utility_pool.restore_reservation_state(reservation_state)
	robot.max_health = float(robot_state.maximum)
	robot.current_health = float(robot_state.health)
	robot._seen_attacks.clear()
	robot.set_disabled(false)
	robot.health_changed.emit(robot.current_health, robot.max_health)
	var gate_anchor: Vector2 = Vector2(
		world_stream.runtime_x_for_logical_index(gate.gate_chunk()) - 80.0,
		0.0
	)
	gate.restore_ownership(gate_state, gate_anchor)
	return true


func clear() -> void:
	valid = false
	boss_state.clear()
	score_state.clear()
	event_history_state.clear()
	recorder_state.clear()
	reservation_state.clear()
	gate_state.clear()
	robot_state.clear()
