class_name BossPhaseDefinition
extends Resource


@export var phase_id: StringName = &""
@export_range(0.0, 1.0, 0.01) var health_threshold: float = 1.0
@export var attack_choices: PackedStringArray = PackedStringArray()
@export var telegraph_profile: StringName = &""
@export_range(0.0, 10.0, 0.05) var recovery_duration: float = 0.5
@export var reservation_requirements: Dictionary = {}
@export var cancel_policy: StringName = &"CANCEL_ON_PHASE_END"
@export var safe_gap_required: bool = true
@export_range(0.0, 2048.0, 1.0) var minimum_safe_gap: float = 192.0
@export var structural_accelerants: Dictionary = {}


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if phase_id.is_empty():
		errors.append("phase_id is empty")
	if health_threshold <= 0.0 or health_threshold > 1.0:
		errors.append("invalid health threshold for %s" % phase_id)
	if attack_choices.is_empty():
		errors.append("no attack choices for %s" % phase_id)
	if telegraph_profile.is_empty():
		errors.append("telegraph profile missing for %s" % phase_id)
	if recovery_duration < 0.0:
		errors.append("negative recovery duration for %s" % phase_id)
	if cancel_policy.is_empty():
		errors.append("cancel policy missing for %s" % phase_id)
	if safe_gap_required and minimum_safe_gap <= 0.0:
		errors.append("safe gap missing for %s" % phase_id)
	for key: Variant in reservation_requirements:
		if StringName(key).is_empty() or int(reservation_requirements[key]) <= 0:
			errors.append("invalid reservation requirement for %s" % phase_id)
	for key: Variant in structural_accelerants:
		if StringName(key).is_empty():
			errors.append("invalid structural accelerant for %s" % phase_id)
	return errors
