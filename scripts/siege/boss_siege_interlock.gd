class_name BossSiegeInterlock
extends RefCounted

const RECOVERY_SECONDS: float = 1.0
var siege: UrbanSiegeRuntime
var owned: bool = false
var captured_state: Dictionary = {}


func setup(p_siege: UrbanSiegeRuntime) -> void:
	siege = p_siege


func acquire() -> bool:
	if owned or siege == null or siege.director == null:
		return false
	captured_state = {
		"run_seed": siege.run_seed,
		"cycle_count": siege.cycle_count,
		"director": siege.director.suspend_for_boss(),
	}
	owned = true
	siege.set_boss_gate_owned(true)
	return true


func resume_after_success() -> bool:
	if not owned or siege == null:
		return false
	siege.run_seed = int(captured_state.get("run_seed", siege.run_seed))
	siege.cycle_count = int(captured_state.get("cycle_count", siege.cycle_count))
	owned = false
	var resumed: bool = siege.director.resume_after_boss(RECOVERY_SECONDS)
	siege.set_boss_gate_owned(false)
	captured_state.clear()
	return resumed


func complete_after_handoff(completed_act_index: int) -> bool:
	if not owned or siege == null:
		return false
	siege.run_seed = int(captured_state.get("run_seed", siege.run_seed))
	siege.cycle_count = int(captured_state.get("cycle_count", siege.cycle_count))
	var advanced: bool = siege.director.advance_after_district_handoff(
		completed_act_index
	)
	if not advanced:
		return false
	owned = false
	siege.set_boss_gate_owned(false)
	captured_state.clear()
	return true


func discard() -> void:
	if siege != null:
		siege.director.discard_boss_suspension()
		siege.set_boss_gate_owned(false)
	owned = false
	captured_state.clear()


func capture_state() -> Dictionary:
	return captured_state.duplicate(true)


func is_owned() -> bool:
	return owned
