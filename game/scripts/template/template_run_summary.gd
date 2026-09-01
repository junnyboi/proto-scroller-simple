class_name TemplateRunSummary
extends RefCounted

var stage_id: StringName
var completed: bool
var result: StringName
var score: int
var waves_cleared: int
var elapsed_msec: int
var run_seed: int
var configuration_hash: String
var ranked_eligible: bool
var build_revision: String


func _init(
	p_stage_id: StringName,
	p_completed: bool,
	p_score: int,
	p_waves_cleared: int,
	p_elapsed_msec: int,
	p_run_seed: int,
	p_configuration_hash: String = "",
	p_ranked_eligible: bool = true,
	p_build_revision: String = ""
) -> void:
	stage_id = p_stage_id
	completed = p_completed
	result = &"VICTORY" if completed else &"DEFEAT"
	score = maxi(p_score, 0)
	waves_cleared = maxi(p_waves_cleared, 0)
	elapsed_msec = maxi(p_elapsed_msec, 0)
	run_seed = p_run_seed
	configuration_hash = p_configuration_hash
	ranked_eligible = p_ranked_eligible
	build_revision = p_build_revision


func snapshot() -> Dictionary:
	return {
		"stage_id": stage_id,
		"completed": completed,
		"result": result,
		"score": score,
		"waves_cleared": waves_cleared,
		"elapsed_msec": elapsed_msec,
		"run_seed": run_seed,
		"configuration_hash": configuration_hash,
		"ranked_eligible": ranked_eligible,
		"build_revision": build_revision,
	}
