class_name BasicTitle
extends Control

signal start_requested

@onready var start_button: Button = %StartButton


func _ready() -> void:
	start_button.pressed.connect(request_start)
	start_button.grab_focus()


func request_start() -> void:
	start_requested.emit()
