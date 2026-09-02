class_name CompactSpawnRecord
extends Resource

@export var enemy_id: StringName = &""
@export_range(1, 8, 1) var count: int = 1
@export_range(0.05, 5.0, 0.05) var interval_seconds: float = 0.5
@export var marker_id: StringName = &"right_ground"


func validation_errors(allowed_enemy_ids: PackedStringArray) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if enemy_id.is_empty() or not allowed_enemy_ids.has(String(enemy_id)):
		errors.append("enemy_id must be allowlisted")
	if count <= 0:
		errors.append("count must be positive")
	if interval_seconds <= 0.0:
		errors.append("interval_seconds must be positive")
	if marker_id.is_empty():
		errors.append("marker_id is required")
	return errors


func is_valid(allowed_enemy_ids: PackedStringArray) -> bool:
	return validation_errors(allowed_enemy_ids).is_empty()
