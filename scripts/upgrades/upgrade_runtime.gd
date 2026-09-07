class_name UpgradeRuntime
extends Node

var current_rank: int = 0
var runtime_upgrade_id: StringName
var runtime_max_rank: int = 1
var paused: bool = false
var stopped: bool = false


func setup(p_upgrade_id: StringName, p_max_rank: int) -> void:
	runtime_upgrade_id = p_upgrade_id
	runtime_max_rank = maxi(p_max_rank, 1)


func upgrade_id() -> StringName:
	return runtime_upgrade_id


func max_rank() -> int:
	return runtime_max_rank


func is_available(_context: Dictionary = {}) -> bool:
	return not stopped


func apply_rank(total_rank: int, _context: Dictionary = {}) -> bool:
	var next_rank: int = clampi(total_rank, 0, runtime_max_rank)
	if current_rank == next_rank:
		return false
	current_rank = next_rank
	return true


func set_paused(value: bool) -> void:
	paused = value


func continue_cycle() -> void:
	paused = false


func stop_and_release() -> void:
	stopped = true
	paused = true


func reset_run() -> void:
	current_rank = 0
	paused = false
	stopped = false


func snapshot() -> Dictionary:
	return {
		"upgrade_id": runtime_upgrade_id,
		"rank": current_rank,
		"max_rank": runtime_max_rank,
		"paused": paused,
		"stopped": stopped,
	}
