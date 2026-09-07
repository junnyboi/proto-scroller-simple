class_name DistrictPressureProfile
extends Resource

@export var district_id: StringName = &""
@export_range(0, 4, 1) var district_index: int = 0
@export_range(0, 4, 1) var threat_allowance: int = 0
@export_range(1, 20, 1) var live_threat_ceiling: int = 8
@export_range(0.5, 1.0, 0.01) var cadence_scale: float = 1.0
@export_range(0.5, 1.0, 0.01) var recovery_scale: float = 1.0
@export_range(0, 2, 1) var elite_bonus: int = 0
@export_range(0, 4, 1) var hazard_pressure_bonus: int = 0
@export_range(0, 2, 1) var hazard_event_bonus: int = 0
@export_range(1, 5, 1) var readiness_level: int = 1


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if district_id.is_empty():
		errors.append("district pressure profile has no district_id")
	if district_index < 0 or district_index >= CityDistrictCatalog.DISTRICT_COUNT:
		errors.append("district_index=%d is outside the district catalog" % district_index)
	if threat_allowance < 0 or threat_allowance > 4:
		errors.append("threat_allowance=%d is outside 0..4" % threat_allowance)
	if live_threat_ceiling < 1 or live_threat_ceiling > 20:
		errors.append("live_threat_ceiling=%d is outside 1..20" % live_threat_ceiling)
	if cadence_scale <= 0.0 or cadence_scale > 1.0:
		errors.append("cadence_scale=%.2f is outside (0, 1]" % cadence_scale)
	if recovery_scale <= 0.0 or recovery_scale > 1.0:
		errors.append("recovery_scale=%.2f is outside (0, 1]" % recovery_scale)
	if elite_bonus < 0 or elite_bonus > 2:
		errors.append("elite_bonus=%d is outside 0..2" % elite_bonus)
	if hazard_pressure_bonus < 0 or hazard_pressure_bonus > 4:
		errors.append("hazard_pressure_bonus=%d is outside 0..4" % hazard_pressure_bonus)
	if hazard_event_bonus < 0 or hazard_event_bonus > 2:
		errors.append("hazard_event_bonus=%d is outside 0..2" % hazard_event_bonus)
	if readiness_level != district_index + 1:
		errors.append(
			"readiness_level=%d expected=%d for %s"
			% [readiness_level, district_index + 1, district_id]
		)
	return errors
