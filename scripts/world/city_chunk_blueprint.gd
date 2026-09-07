class_name CityChunkBlueprint
extends RefCounted

var logical_index: int = 0
var generation_seed: int = 0
var district_index: int = 0
var district_id: StringName = &"BUSINESS"
var district_profile: CityDistrictProfile
var building_variant_index: int = 0
var building_variant_id: StringName = &"business_mercy_exchange_annex"
var building_variant: StructuralBuildingVariant
var lane_phase: float = 72.0
var asphalt_color: Color = Color("353b44")
var building_x: float = 1450.0
var car_x: float = 930.0
var car_y: float = 559.0
var lamp_x: float = 1220.0
var lamp_y: float = 480.0


static func generate(run_seed: int, chunk_index: int) -> CityChunkBlueprint:
	var blueprint: CityChunkBlueprint = CityChunkBlueprint.new()
	blueprint.logical_index = chunk_index
	blueprint.generation_seed = hash("%d:%d" % [run_seed, chunk_index])
	blueprint.district_profile = CityDistrictCatalog.district_for_chunk(chunk_index)
	blueprint.district_index = blueprint.district_profile.district_index
	blueprint.district_id = blueprint.district_profile.district_id
	blueprint.building_variant = CityDistrictCatalog.variant_for_chunk(
		run_seed,
		chunk_index
	)
	blueprint.building_variant_id = blueprint.building_variant.variant_id
	blueprint.building_variant_index = blueprint.district_profile.building_variants.find(
		blueprint.building_variant
	)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = blueprint.generation_seed
	blueprint.lane_phase = rng.randf_range(44.0, 116.0)
	var brightness: float = rng.randf_range(0.94, 1.04)
	blueprint.asphalt_color = blueprint.district_profile.asphalt_color * brightness
	blueprint.asphalt_color.a = 1.0
	if chunk_index != 0:
		blueprint.building_x = rng.randf_range(620.0, 724.0)
		blueprint.car_x = rng.randf_range(1010.0, 1110.0)
		blueprint.lamp_x = rng.randf_range(210.0, 300.0)
	if chunk_index == 1:
		blueprint.lamp_x = 1200.0
	return blueprint
