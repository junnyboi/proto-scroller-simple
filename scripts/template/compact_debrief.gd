class_name CompactDebrief
extends Control

signal retry_requested
signal title_requested

@onready var result_label: Label = %ResultLabel
@onready var summary_label: Label = %SummaryLabel
@onready var retry_button: Button = %RetryButton
@onready var title_button: Button = %TitleButton


func _ready() -> void:
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
	title_button.pressed.connect(func() -> void: title_requested.emit())


func present(summary: TemplateRunSummary) -> void:
	result_label.text = "VICTORY" if summary.completed else "DEFEAT"
	summary_label.text = "Stage: %s\nScore: %d" % [
		String(summary.stage_id),
		summary.score,
	]
	visible = true
	retry_button.grab_focus()


func dismiss() -> void:
	visible = false
