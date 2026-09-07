class_name WorldMutationLedger
extends RefCounted

var run_seed: int = 0
var write_count: int = 0
var restore_count: int = 0
var _states: Dictionary[StringName, Dictionary] = {}


func reset(p_run_seed: int) -> void:
	run_seed = p_run_seed
	write_count = 0
	restore_count = 0
	_states.clear()


func store(object_key: StringName, state: Dictionary) -> void:
	if object_key.is_empty():
		return
	if bool(state.get("pristine", false)):
		_states.erase(object_key)
		return
	_states[object_key] = state.duplicate(true)
	write_count += 1


func restore(object_key: StringName) -> Dictionary:
	if object_key.is_empty() or not _states.has(object_key):
		return {}
	restore_count += 1
	return _states[object_key].duplicate(true)


func has_state(object_key: StringName) -> bool:
	return _states.has(object_key)


func state_count() -> int:
	return _states.size()


func make_object_id(logical_chunk: int, role: StringName) -> StringName:
	return StringName("chunk:%d:%s" % [logical_chunk, role])
