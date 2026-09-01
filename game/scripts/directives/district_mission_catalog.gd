class_name DistrictMissionCatalog
extends RefCounted

const CHOICES_PER_DISTRICT: int = 3
const POOLS: Array[DistrictMissionPool] = [
	preload("res://resources/directives/districts/business_pool.tres"),
	preload("res://resources/directives/districts/residential_pool.tres"),
]


static func pools() -> Array[DistrictMissionPool]:
	return POOLS.duplicate()


static func pool_for(district_id: StringName) -> DistrictMissionPool:
	for pool: DistrictMissionPool in POOLS:
		if pool.district_id == district_id:
			return pool
	return null


static func profiles_for(district_id: StringName) -> Array[DirectiveProfile]:
	var pool: DistrictMissionPool = pool_for(district_id)
	return pool.profiles.duplicate() if pool != null else []


static func choices_for(
	district_id: StringName,
	run_seed: int,
	cycle: int
) -> Array[DirectiveProfile]:
	var choices: Array[DirectiveProfile] = profiles_for(district_id)
	choices.sort_custom(
		func(left: DirectiveProfile, right: DirectiveProfile) -> bool:
			return String(left.directive_id) < String(right.directive_id)
	)
	if choices.is_empty():
		return choices
	var start_index: int = posmod(
		hash("%d:%d:%s" % [run_seed, maxi(cycle, 1), district_id]),
		choices.size()
	)
	var ordered: Array[DirectiveProfile] = []
	for offset: int in range(choices.size()):
		ordered.append(choices[(start_index + offset) % choices.size()])
	return ordered


static func all_profiles() -> Array[DirectiveProfile]:
	var result: Array[DirectiveProfile] = []
	for pool: DistrictMissionPool in POOLS:
		result.append_array(pool.profiles)
	return result


static func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var expected_ids: Dictionary[StringName, bool] = {}
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		expected_ids[district.district_id] = true
	var pool_ids: Dictionary[StringName, bool] = {}
	var mission_ids: Dictionary[StringName, bool] = {}
	for pool: DistrictMissionPool in POOLS:
		if pool == null:
			errors.append("null district mission pool")
			continue
		if not expected_ids.has(pool.district_id):
			errors.append("unknown mission district %s" % pool.district_id)
		if pool_ids.has(pool.district_id):
			errors.append("duplicate mission district %s" % pool.district_id)
		pool_ids[pool.district_id] = true
		for error: String in pool.validation_errors():
			errors.append(error)
		for profile: DirectiveProfile in pool.profiles:
			if profile == null:
				continue
			if mission_ids.has(profile.directive_id):
				errors.append("duplicate global mission %s" % profile.directive_id)
			mission_ids[profile.directive_id] = true
	if pool_ids.size() != CityDistrictCatalog.DISTRICT_COUNT:
		errors.append(
			"mission_pool_count=%d expected=%d"
			% [pool_ids.size(), CityDistrictCatalog.DISTRICT_COUNT]
		)
	return errors
