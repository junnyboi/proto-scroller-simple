class_name CompactWaveDefinition
extends Resource

@export_range(0.0, 10.0, 0.05) var start_delay_seconds: float = 0.5
@export var spawns: Array[CompactSpawnRecord] = []


func validation_errors(allowed_enemy_ids: PackedStringArray) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if start_delay_seconds < 0.0:
		errors.append("start_delay_seconds cannot be negative")
	if spawns.is_empty():
		errors.append("at least one spawn record is required")
	for record: CompactSpawnRecord in spawns:
		if record == null:
			errors.append("spawn records cannot be null")
			continue
		for error: String in record.validation_errors(allowed_enemy_ids):
			errors.append(error)
	return errors


func is_valid(allowed_enemy_ids: PackedStringArray) -> bool:
	return validation_errors(allowed_enemy_ids).is_empty()
