class_name TemplateMain
extends Node

const BASIC_TITLE_SCENE: PackedScene = preload("res://scenes/template/basic_title.tscn")
const TEMPLATE_STAGE_SCENE: PackedScene = preload("res://scenes/template/template_stage.tscn")
const STAGE_01: StageDefinition = preload("res://resources/template/stages/stage_01.tres")

var title_screen: BasicTitle
var current_stage: TemplateStage


func _ready() -> void:
	show_title()


func show_title() -> void:
	_release_stage()
	_release_title()
	title_screen = BASIC_TITLE_SCENE.instantiate() as BasicTitle
	title_screen.start_requested.connect(start_stage)
	add_child(title_screen)


func start_stage() -> void:
	var next_stage: TemplateStage = TEMPLATE_STAGE_SCENE.instantiate() as TemplateStage
	next_stage.configure(STAGE_01)
	_release_stage()
	_release_title()
	current_stage = next_stage
	current_stage.retry_requested.connect(_on_retry_requested)
	current_stage.title_requested.connect(show_title)
	add_child(current_stage)


func _on_retry_requested() -> void:
	if current_stage == null:
		return
	start_stage()


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
