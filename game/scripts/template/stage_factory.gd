class_name StageFactory
extends RefCounted

const TEMPLATE_STAGE_SCENE: PackedScene = preload("res://scenes/template/template_stage.tscn")
const STAGE_01: StageDefinition = preload("res://resources/template/stages/stage_01.tres")


func known_stage_ids() -> PackedStringArray:
	return PackedStringArray([STAGE_01.stage_id])


func definition(stage_id: StringName) -> StageDefinition:
	if stage_id == STAGE_01.stage_id:
		return STAGE_01
	return null


func create(stage_id: StringName, run_seed: int = 0) -> TemplateStage:
	var selected: StageDefinition = definition(stage_id)
	if selected == null or not selected.is_valid():
		return null
	var stage: TemplateStage = TEMPLATE_STAGE_SCENE.instantiate() as TemplateStage
	stage.configure(selected, run_seed)
	return stage
