class_name BasicHud
extends Control

@onready var stage_label: Label = %StageLabel
@onready var status_label: Label = %StatusLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var wave_label: Label = %WaveLabel
@onready var score_label: Label = %ScoreLabel


func configure(definition: StageDefinition) -> void:
	stage_label.text = definition.display_name if definition != null else ""
	status_label.text = "COMBAT ACTIVE"
	set_wave(1, definition.waves.size() if definition != null else 1)
	set_score(0)


func set_status(value: String) -> void:
	status_label.text = value


func set_health(current_health: float, maximum_health: float) -> void:
	health_bar.max_value = maxf(maximum_health, 1.0)
	health_bar.value = clampf(current_health, 0.0, health_bar.max_value)
	health_label.text = "HP %d / %d" % [roundi(current_health), roundi(maximum_health)]


func set_wave(current_wave: int, total_waves: int) -> void:
	wave_label.text = "WAVE %d / %d" % [
		clampi(current_wave, 0, maxi(total_waves, 1)),
		maxi(total_waves, 1),
	]


func set_score(value: int) -> void:
	score_label.text = "SCORE %06d" % [maxi(value, 0)]
