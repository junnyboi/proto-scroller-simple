class_name CompactRunLifecycle
extends Node

signal run_finished(completed: bool, summary: TemplateRunSummary)

var stage_id: StringName = &""
var run_seed: int = 0
var finalized: bool = false
var frozen_summary: TemplateRunSummary
var finalization_count: int = 0
var _started_msec: int = 0


func setup(p_stage_id: StringName, p_run_seed: int = 0) -> void:
	stage_id = p_stage_id
	run_seed = p_run_seed
	finalized = false
	frozen_summary = null
	finalization_count = 0
	_started_msec = Time.get_ticks_msec()


func finish_victory(score: int = 0, waves_cleared: int = 0) -> bool:
	return _finish(true, score, waves_cleared)


func finish_defeat(score: int = 0, waves_cleared: int = 0) -> bool:
	return _finish(false, score, waves_cleared)


func _finish(completed: bool, score: int, waves_cleared: int) -> bool:
	if finalized:
		return false
	finalized = true
	finalization_count += 1
	frozen_summary = TemplateRunSummary.new(
		stage_id,
		completed,
		score,
		waves_cleared,
		Time.get_ticks_msec() - _started_msec,
		run_seed
	)
	run_finished.emit(completed, frozen_summary)
	return true
