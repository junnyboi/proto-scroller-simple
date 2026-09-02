class_name CompactRunLifecycle
extends Node

signal run_finished(completed: bool, summary: TemplateRunSummary)

var stage_id: StringName = &""
var finalized: bool = false
var frozen_summary: TemplateRunSummary


func setup(p_stage_id: StringName) -> void:
	stage_id = p_stage_id
	finalized = false
	frozen_summary = null


func finish_victory(score: int = 0, waves_cleared: int = 0) -> bool:
	return _finish(true, score, waves_cleared)


func finish_defeat(score: int = 0, waves_cleared: int = 0) -> bool:
	return _finish(false, score, waves_cleared)


func _finish(completed: bool, score: int, waves_cleared: int) -> bool:
	if finalized:
		return false
	finalized = true
	frozen_summary = TemplateRunSummary.new(
		stage_id,
		completed,
		score,
		waves_cleared
	)
	run_finished.emit(completed, frozen_summary)
	return true
