class_name TemplateRunSummary
extends RefCounted

var stage_id: StringName
var completed: bool
var score: int
var waves_cleared: int


func _init(
	p_stage_id: StringName,
	p_completed: bool,
	p_score: int,
	p_waves_cleared: int
) -> void:
	stage_id = p_stage_id
	completed = p_completed
	score = maxi(p_score, 0)
	waves_cleared = maxi(p_waves_cleared, 0)
