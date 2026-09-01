class_name BasicHud
extends Control

@onready var stage_label: Label = %StageLabel
@onready var status_label: Label = %StatusLabel


func configure(definition: StageDefinition) -> void:
	stage_label.text = String(definition.display_name_key) if definition != null else ""
	status_label.text = "AWAITING STUB OUTCOME"


func set_status(value: String) -> void:
	status_label.text = value
