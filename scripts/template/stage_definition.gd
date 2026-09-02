class_name StageDefinition
extends Resource

@export var stage_id: StringName = &""
@export var display_name_key: StringName = &""
@export var background_id: StringName = &""
@export var foreground_id: StringName = &""
@export var waves: Array[Resource] = []
@export_range(0.05, 10.0, 0.05) var spawn_interval_seconds: float = 1.0
@export var allowed_enemy_ids: PackedStringArray = PackedStringArray()
@export var objective_key: StringName = &""
@export var filter_profile: StringName = &"default"


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if stage_id.is_empty():
		errors.append("stage_id is required")
	if display_name_key.is_empty():
		errors.append("display_name_key is required")
	if objective_key.is_empty():
		errors.append("objective_key is required")
	if spawn_interval_seconds <= 0.0:
		errors.append("spawn_interval_seconds must be positive")
	if waves.is_empty():
		errors.append("at least one wave is required")
	for wave_resource: Resource in waves:
		var wave: CompactWaveDefinition = wave_resource as CompactWaveDefinition
		if wave == null:
			errors.append("waves must use CompactWaveDefinition")
			continue
		for error: String in wave.validation_errors(allowed_enemy_ids):
			errors.append(error)
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()
