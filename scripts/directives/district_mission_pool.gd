class_name DistrictMissionPool
extends Resource

const CHOICES_PER_DISTRICT: int = 3

@export var district_id: StringName = &""
@export var profiles: Array[DirectiveProfile] = []


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if district_id.is_empty():
		errors.append("mission pool district_id is empty")
	if profiles.size() != CHOICES_PER_DISTRICT:
		errors.append(
			"district %s mission_count=%d expected=%d"
			% [district_id, profiles.size(), CHOICES_PER_DISTRICT]
		)
	var ids: Dictionary[StringName, bool] = {}
	for profile: DirectiveProfile in profiles:
		if profile == null:
			errors.append("district %s has null mission profile" % district_id)
			continue
		if profile.district_id != district_id:
			errors.append(
				"mission %s owner=%s expected=%s"
				% [profile.directive_id, profile.district_id, district_id]
			)
		if ids.has(profile.directive_id):
			errors.append("duplicate mission %s in %s" % [profile.directive_id, district_id])
		ids[profile.directive_id] = true
		for error: String in profile.validation_errors():
			errors.append(error)
	return errors
