class_name BasicTitle
extends Control

signal start_requested(stage_id: StringName)

@onready var start_button: Button = %StartButton


func _ready() -> void:
	start_button.pressed.connect(request_start)
	start_button.grab_focus()


func request_start(stage_id: StringName = &"stage_01") -> void:
	start_requested.emit(stage_id)
