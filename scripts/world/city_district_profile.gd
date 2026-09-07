class_name CityDistrictProfile
extends Resource

const EXPECTED_VARIANT_COUNT: int = 5

@export var district_index: int = 0
@export var district_id: StringName = &"BUSINESS"
@export var display_name: String = "The Ledger Spine"
@export var start_chunk: int = 0
@export var end_chunk: int = 7
@export var asphalt_color: Color = Color("353b44")
@export var accent_color: Color = Color("6ba6b5")
@export var concept_board_path: String = ""
@export var building_variants: Array[StructuralBuildingVariant] = []


func contains_logical_chunk(logical_index: int) -> bool:
	var forward_chunk: int = maxi(logical_index, 0)
	return (
		forward_chunk >= start_chunk
		and (end_chunk < 0 or forward_chunk <= end_chunk)
	)


func variant_count() -> int:
	return building_variants.size()


func variant_by_id(variant_id: StringName) -> StructuralBuildingVariant:
	for variant: StructuralBuildingVariant in building_variants:
		if variant.variant_id == variant_id:
			return variant
	return null


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if district_id.is_empty():
		errors.append("district_id is empty")
	if display_name.is_empty():
		errors.append("display_name is empty for %s" % district_id)
	if start_chunk < 0:
		errors.append("start_chunk is negative for %s" % district_id)
	if end_chunk >= 0 and end_chunk < start_chunk:
		errors.append("end_chunk precedes start_chunk for %s" % district_id)
	if building_variants.size() != EXPECTED_VARIANT_COUNT:
		errors.append(
			"variant_count=%d expected=%d for %s"
			% [
				building_variants.size(),
				EXPECTED_VARIANT_COUNT,
				district_id,
			]
		)
	var seen: Dictionary[StringName, bool] = {}
	for variant: StructuralBuildingVariant in building_variants:
		if variant == null:
			errors.append("null building variant in %s" % district_id)
			continue
		if seen.has(variant.variant_id):
			errors.append("duplicate variant %s in %s" % [variant.variant_id, district_id])
		seen[variant.variant_id] = true
		for error: String in variant.validation_errors():
			errors.append("%s: %s" % [district_id, error])
	return errors
