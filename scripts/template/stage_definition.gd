class_name StageDefinition
extends Resource

@export var stage_id: StringName = &""
@export var display_name: String = ""
@export var waves: Array[Resource] = []
@export var allowed_enemy_ids: PackedStringArray = PackedStringArray()


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if stage_id.is_empty():
		errors.append("stage_id is required")
	if display_name.is_empty():
		errors.append("display_name is required")
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
