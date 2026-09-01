class_name TemplateStage
extends Control

signal run_finished(completed: bool, summary: TemplateRunSummary)
signal retry_requested
signal title_requested

var definition: StageDefinition
var run_seed: int = 0

@onready var lifecycle: CompactRunLifecycle = %CompactRunLifecycle
@onready var hud: BasicHud = %BasicHud
@onready var debrief: CompactDebrief = %CompactDebrief
@onready var victory_button: Button = %StubVictoryButton
@onready var defeat_button: Button = %StubDefeatButton


func configure(p_definition: StageDefinition, p_run_seed: int = 0) -> void:
	definition = p_definition
	run_seed = p_run_seed


func _ready() -> void:
	assert(definition != null and definition.is_valid(), "TemplateStage requires a valid definition")
	lifecycle.setup(definition.stage_id, run_seed)
	lifecycle.run_finished.connect(_on_run_finished)
	debrief.retry_requested.connect(func() -> void: retry_requested.emit())
	debrief.title_requested.connect(func() -> void: title_requested.emit())
	victory_button.pressed.connect(request_stub_victory)
	defeat_button.pressed.connect(request_stub_defeat)
	hud.configure(definition)
	debrief.dismiss()


func request_stub_victory() -> bool:
	return lifecycle.finish_victory(100, 0)


func request_stub_defeat() -> bool:
	return lifecycle.finish_defeat(25, 0)


func _on_run_finished(completed: bool, summary: TemplateRunSummary) -> void:
	victory_button.disabled = true
	defeat_button.disabled = true
	hud.set_status("VICTORY" if completed else "DEFEAT")
	debrief.present(summary)
	run_finished.emit(completed, summary)
