class_name DistrictPressureCatalog
extends RefCounted

const MAX_LIVE_THREAT: int = 20

static var _profiles: Array[DistrictPressureProfile] = []
static var _profiles_by_id: Dictionary[StringName, DistrictPressureProfile] = {}


static func profiles() -> Array[DistrictPressureProfile]:
	_ensure_catalog()
	return _profiles.duplicate()


static func profile_by_index(index: int) -> DistrictPressureProfile:
	_ensure_catalog()
	return _profiles[clampi(index, 0, _profiles.size() - 1)]


static func authored_profile(district_id: StringName) -> DistrictPressureProfile:
	_ensure_catalog()
	return _profiles_by_id.get(district_id) as DistrictPressureProfile


static func effective_profile(
	district_id: StringName,
	player_level: int
) -> DistrictPressureProfile:
	var authored: DistrictPressureProfile = authored_profile(district_id)
	if authored == null:
		return profile_by_index(0)
	var readiness_index: int = clampi(player_level - 1, 0, authored.district_index)
	return profile_by_index(readiness_index)


static func coerce_profile(value: Variant) -> DistrictPressureProfile:
	if value is DistrictPressureProfile:
		return value as DistrictPressureProfile
	return profile_by_index(int(value))


static func validation_errors() -> PackedStringArray:
	_ensure_catalog()
	var errors: PackedStringArray = PackedStringArray()
	if _profiles.size() != CityDistrictCatalog.DISTRICT_COUNT:
		errors.append(
			"pressure_profile_count=%d expected=%d"
			% [_profiles.size(), CityDistrictCatalog.DISTRICT_COUNT]
		)
	var previous: DistrictPressureProfile = null
	for index: int in range(_profiles.size()):
		var profile: DistrictPressureProfile = _profiles[index]
		var city_district: CityDistrictProfile = CityDistrictCatalog.districts()[index]
		errors.append_array(profile.validation_errors())
		if profile.district_id != city_district.district_id:
			errors.append("pressure district mismatch at index %d" % index)
		if previous != null:
			if profile.threat_allowance < previous.threat_allowance:
				errors.append("threat allowance regressed at %s" % profile.district_id)
			if profile.live_threat_ceiling < previous.live_threat_ceiling:
				errors.append("live threat ceiling regressed at %s" % profile.district_id)
			if profile.cadence_scale > previous.cadence_scale:
				errors.append("cadence eased at %s" % profile.district_id)
			if profile.recovery_scale > previous.recovery_scale:
				errors.append("recovery eased at %s" % profile.district_id)
			if profile.elite_bonus < previous.elite_bonus:
				errors.append("elite bonus regressed at %s" % profile.district_id)
			if profile.hazard_pressure_bonus < previous.hazard_pressure_bonus:
				errors.append("hazard pressure regressed at %s" % profile.district_id)
			if profile.hazard_event_bonus < previous.hazard_event_bonus:
				errors.append("hazard event count regressed at %s" % profile.district_id)
		previous = profile
	return errors


static func _ensure_catalog() -> void:
	if not _profiles.is_empty():
		return
	_profiles = [
		_profile(&"BUSINESS", 0, 0, 8, 1.00, 1.00, 0, 0, 0),
		_profile(&"RESIDENTIAL", 1, 1, 11, 0.96, 1.00, 0, 1, 0),
	]
	_profiles_by_id.clear()
	for profile: DistrictPressureProfile in _profiles:
		_profiles_by_id[profile.district_id] = profile


static func _profile(
	district_id: StringName,
	district_index: int,
	threat_allowance: int,
	live_threat_ceiling: int,
	cadence_scale: float,
	recovery_scale: float,
	elite_bonus: int,
	hazard_pressure_bonus: int,
	hazard_event_bonus: int
) -> DistrictPressureProfile:
	var profile: DistrictPressureProfile = DistrictPressureProfile.new()
	profile.district_id = district_id
	profile.district_index = district_index
	profile.threat_allowance = threat_allowance
	profile.live_threat_ceiling = live_threat_ceiling
	profile.cadence_scale = cadence_scale
	profile.recovery_scale = recovery_scale
	profile.elite_bonus = elite_bonus
	profile.hazard_pressure_bonus = hazard_pressure_bonus
	profile.hazard_event_bonus = hazard_event_bonus
	profile.readiness_level = district_index + 1
	return profile
