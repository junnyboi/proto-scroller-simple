class_name TemplateMain
extends Node

const BASIC_TITLE_SCENE: PackedScene = preload("res://scenes/template/basic_title.tscn")

var stage_factory: StageFactory = StageFactory.new()
var title_screen: BasicTitle
var current_stage: TemplateStage
var last_summary: TemplateRunSummary
var launch_seed: int = 0


func _ready() -> void:
	show_title()


func show_title() -> void:
	_release_stage()
	_release_title()
	title_screen = BASIC_TITLE_SCENE.instantiate() as BasicTitle
	title_screen.start_requested.connect(start_stage)
	add_child(title_screen)


func start_stage(stage_id: StringName = &"stage_01") -> bool:
	var next_stage: TemplateStage = stage_factory.create(stage_id, launch_seed)
	if next_stage == null:
		return false
	_release_stage()
	_release_title()
	current_stage = next_stage
	current_stage.run_finished.connect(_on_run_finished)
	current_stage.retry_requested.connect(_on_retry_requested)
	current_stage.title_requested.connect(show_title)
	add_child(current_stage)
	return true


func _on_run_finished(_completed: bool, summary: TemplateRunSummary) -> void:
	last_summary = summary


func _on_retry_requested() -> void:
	if current_stage == null or current_stage.definition == null:
		return
	var stage_id: StringName = current_stage.definition.stage_id
	start_stage(stage_id)


func _release_title() -> void:
	if title_screen == null:
		return
	remove_child(title_screen)
	title_screen.queue_free()
	title_screen = null


func _release_stage() -> void:
	if current_stage == null:
		return
	remove_child(current_stage)
	current_stage.queue_free()
	current_stage = null
