class_name ScrollerStageRegistry
extends RefCounted

var stages: Array[ScrollerStageDefinition] = []


func _init() -> void:
	stages.append(load("res://resources/stages/business_act_1.tres") as ScrollerStageDefinition)


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	var identities: Dictionary = {}
	if stages.is_empty():
		errors.append("stage registry is empty")
	for stage: ScrollerStageDefinition in stages:
		if stage == null:
			errors.append("null stage")
			continue
		if identities.has(stage.stage_id):
			errors.append("duplicate stage identity")
		identities[stage.stage_id] = true
		errors.append_array(stage.validation_errors())
	return errors


func at(index: int) -> ScrollerStageDefinition:
	return stages[index] if index >= 0 and index < stages.size() else null


func has_next(index: int) -> bool:
	return at(index + 1) != null
