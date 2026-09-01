class_name CityDistrictCatalog
extends RefCounted

const DISTRICT_COUNT: int = 2
const VARIANTS_PER_DISTRICT: int = 5
const FACADE_ENCOUNTERS_PER_DISTRICT: int = 7
const FACADE_PASSES_PER_DISTRICT: int = 2
const BUILDING_VARIANT_COUNT: int = DISTRICT_COUNT * VARIANTS_PER_DISTRICT
const FACADE_SIZE_SCALE: float = 1.2
const TRANSITION_CORRIDOR_CHUNKS: int = 2
const CHUNKS_PER_DISTRICT: int = (
	FACADE_ENCOUNTERS_PER_DISTRICT + TRANSITION_CORRIDOR_CHUNKS
)

const INITIAL_DISTRICT_TEXTURES: Dictionary = {
	&"business_mercy_exchange_annex": preload(
		"res://art/city/destructibles/districts/business/mercy_exchange_annex.png"
	),
	&"business_helix_clearinghouse_spine": preload(
		"res://art/city/destructibles/districts/business/helix_clearinghouse_spine.png"
	),
	&"business_orison_custody_vault": preload(
		"res://art/city/destructibles/districts/business/orison_custody_vault.png"
	),
	&"business_vanta_compliance_tribunal": preload(
		"res://art/city/destructibles/districts/business/vanta_compliance_tribunal.png"
	),
	&"business_crown_reserve_treasury": preload(
		"res://art/city/destructibles/districts/business/crown_reserve_data_treasury.png"
	),
}
const FACADE_TEXTURE_PATHS: Dictionary = {
	&"business_mercy_exchange_annex": (
		"res://art/city/destructibles/districts/business/mercy_exchange_annex.png"
	),
	&"business_helix_clearinghouse_spine": (
		"res://art/city/destructibles/districts/business/helix_clearinghouse_spine.png"
	),
	&"business_orison_custody_vault": (
		"res://art/city/destructibles/districts/business/orison_custody_vault.png"
	),
	&"business_vanta_compliance_tribunal": (
		"res://art/city/destructibles/districts/business/vanta_compliance_tribunal.png"
	),
	&"business_crown_reserve_treasury": (
		"res://art/city/destructibles/districts/business/crown_reserve_data_treasury.png"
	),
	&"residential_emberpot_canteen_house": (
		"res://art/city/destructibles/districts/residential/emberpot_canteen_house.png"
	),
	&"residential_bluewire_laundry_walkup": (
		"res://art/city/destructibles/districts/residential/bluewire_laundry_walkup.png"
	),
	&"residential_rainvault_cooperative": (
		"res://art/city/destructibles/districts/residential/rainvault_cooperative.png"
	),
	&"residential_sixfold_balcony_court": (
		"res://art/city/destructibles/districts/residential/sixfold_balcony_court.png"
	),
	&"residential_nightglass_mutual_clinic": (
		"res://art/city/destructibles/districts/residential/nightglass_mutual_clinic.png"
	),
}

static var _districts: Array[CityDistrictProfile] = []
static var _variants_by_id: Dictionary[StringName, StructuralBuildingVariant] = {}


static func districts() -> Array[CityDistrictProfile]:
	_ensure_catalog()
	return _districts.duplicate()


static func district_index_for_chunk(logical_index: int) -> int:
	var forward_chunk: int = maxi(logical_index, 0)
	return mini(
		floori(float(forward_chunk) / float(CHUNKS_PER_DISTRICT)),
		DISTRICT_COUNT - 1
	)


static func district_for_chunk(logical_index: int) -> CityDistrictProfile:
	_ensure_catalog()
	return _districts[district_index_for_chunk(logical_index)]


static func local_chunk_index(logical_index: int) -> int:
	var district_index: int = district_index_for_chunk(logical_index)
	return logical_index - district_index * CHUNKS_PER_DISTRICT


static func chunk_hosts_facade(logical_index: int) -> bool:
	var local_index: int = local_chunk_index(logical_index)
	return local_index >= 0 and local_index < FACADE_ENCOUNTERS_PER_DISTRICT


static func variant_for_chunk(
	run_seed: int,
	logical_index: int
) -> StructuralBuildingVariant:
	var district: CityDistrictProfile = district_for_chunk(logical_index)
	var local_index: int = logical_index - district.start_chunk
	var facade_pass: int = maxi(local_index, 0) / VARIANTS_PER_DISTRICT
	var order: PackedInt32Array = _variant_order(run_seed, district, facade_pass)
	var roster_offset: int = _variant_offset(run_seed, district, facade_pass)
	if facade_pass > 0 and _pass_sequences_match(
		run_seed,
		district,
		facade_pass - 1,
		facade_pass
	):
		roster_offset = posmod(roster_offset + 1, district.variant_count())
	var roster_index: int = posmod(
		local_index % VARIANTS_PER_DISTRICT + roster_offset,
		district.variant_count()
	)
	var variant_index: int = order[roster_index]
	return district.building_variants[variant_index]


static func _variant_offset(
	run_seed: int,
	district: CityDistrictProfile,
	facade_pass: int
) -> int:
	if run_seed == 0:
		return 0
	return posmod(
		hash(
			"%d:%s:facade_offset:%d"
			% [run_seed, district.district_id, facade_pass]
		),
		district.variant_count()
	)


static func _pass_sequences_match(
	run_seed: int,
	district: CityDistrictProfile,
	first_pass: int,
	second_pass: int
) -> bool:
	var first_order: PackedInt32Array = _variant_order(run_seed, district, first_pass)
	var second_order: PackedInt32Array = _variant_order(run_seed, district, second_pass)
	var first_offset: int = _variant_offset(run_seed, district, first_pass)
	var second_offset: int = _variant_offset(run_seed, district, second_pass)
	for index: int in range(district.variant_count()):
		if (
			first_order[posmod(index + first_offset, district.variant_count())]
			!= second_order[posmod(index + second_offset, district.variant_count())]
		):
			return false
	return true


static func _variant_order(
	run_seed: int,
	district: CityDistrictProfile,
	facade_pass: int = 0
) -> PackedInt32Array:
	var order: PackedInt32Array = PackedInt32Array()
	for variant_index: int in range(district.variant_count()):
		order.append(variant_index)
	var first_mutable_index: int = 1 if district.district_index == 0 else 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(
		"%d:%s:facade_order:%d" % [run_seed, district.district_id, facade_pass]
	)
	for cursor: int in range(order.size() - 1, first_mutable_index, -1):
		var swap_index: int = rng.randi_range(first_mutable_index, cursor)
		var held_index: int = order[cursor]
		order[cursor] = order[swap_index]
		order[swap_index] = held_index
	return order


static func variant_by_id(variant_id: StringName) -> StructuralBuildingVariant:
	_ensure_catalog()
	return _variants_by_id.get(variant_id) as StructuralBuildingVariant


static func validation_errors() -> PackedStringArray:
	_ensure_catalog()
	var errors: PackedStringArray = PackedStringArray()
	if _districts.size() != DISTRICT_COUNT:
		errors.append(
			"district_count=%d expected=%d" % [_districts.size(), DISTRICT_COUNT]
		)
	var district_ids: Dictionary[StringName, bool] = {}
	var variant_ids: Dictionary[StringName, bool] = {}
	for expected_index: int in range(_districts.size()):
		var district: CityDistrictProfile = _districts[expected_index]
		if district.district_index != expected_index:
			errors.append(
				"district_index=%d expected=%d for %s"
				% [district.district_index, expected_index, district.district_id]
			)
		if district.start_chunk != expected_index * CHUNKS_PER_DISTRICT:
			errors.append("unexpected start_chunk for %s" % district.district_id)
		var expected_end: int = (
			-1
			if expected_index == DISTRICT_COUNT - 1
			else district.start_chunk + CHUNKS_PER_DISTRICT - 1
		)
		if district.end_chunk != expected_end:
			errors.append("unexpected end_chunk for %s" % district.district_id)
		if district_ids.has(district.district_id):
			errors.append("duplicate district_id %s" % district.district_id)
		district_ids[district.district_id] = true
		for error: String in district.validation_errors():
			errors.append(error)
		for variant: StructuralBuildingVariant in district.building_variants:
			if variant_ids.has(variant.variant_id):
				errors.append("duplicate global variant_id %s" % variant.variant_id)
			variant_ids[variant.variant_id] = true
	if variant_ids.size() != BUILDING_VARIANT_COUNT:
		errors.append(
			"building_variant_count=%d expected=%d"
			% [variant_ids.size(), BUILDING_VARIANT_COUNT]
		)
	return errors


static func _ensure_catalog() -> void:
	if not _districts.is_empty():
		return
	_districts = [
		_district(
			0,
			&"BUSINESS",
			"The Ledger Spine",
			Color("353b44"),
			Color("6ba6b5"),
			"../docs/concepts/districts/business-district-concept.jpg",
			[
				_variant(
					&"business_mercy_exchange_annex",
					"Mercy Exchange Annex",
					Vector2(500.0, 445.0),
					["concrete", "steel", "concrete", "glass", "concrete", "steel"],
					&"ticker_glass_unzip",
					Color("e5f6fb")
				),
				_variant(
					&"business_helix_clearinghouse_spine",
					"Helix Clearinghouse Spine",
					Vector2(390.0, 520.0),
					["glass", "steel", "glass", "concrete", "steel", "concrete"],
					&"service_spine_peel",
					Color("dceef2")
				),
				_variant(
					&"business_orison_custody_vault",
					"Orison Custody Vault",
					Vector2(590.0, 360.0),
					["concrete", "glass", "concrete", "steel", "concrete", "steel"],
					&"blast_pier_center_sag",
					Color("eee8dc")
				),
				_variant(
					&"business_vanta_compliance_tribunal",
					"Vanta Compliance Tribunal",
					Vector2(500.0, 455.0),
					["steel", "glass", "concrete", "concrete", "steel", "glass"],
					&"diagonal_transfer_peel",
					Color("e6eff1")
				),
				_variant(
					&"business_crown_reserve_treasury",
					"Crown Reserve Data Treasury",
					Vector2(570.0, 500.0),
					["glass", "concrete", "glass", "steel", "steel", "concrete"],
					&"archive_crown_power_loss",
					Color("e8f3ef")
				),
			]
		),
		_district(
			1,
			&"RESIDENTIAL",
			"Ashwater Commons",
			Color("3b4145"),
			Color("3f7c7c"),
			"../docs/concepts/districts/residential-district-concept.jpg",
			[
				_variant(
					&"residential_emberpot_canteen_house",
					"Emberpot Canteen House",
					Vector2(410.0, 340.0),
					["concrete", "steel", "concrete", "glass", "steel", "concrete"],
					&"kitchen_service_flare",
					Color("fff0d8")
				),
				_variant(
					&"residential_bluewire_laundry_walkup",
					"Bluewire Laundry Walk-Up",
					Vector2(430.0, 405.0),
					["concrete", "steel", "concrete", "concrete", "steel", "glass"],
					&"service_spine_unzip",
					Color("e1eef0")
				),
				_variant(
					&"residential_rainvault_cooperative",
					"Rainvault Cooperative",
					Vector2(500.0, 445.0),
					["concrete", "glass", "steel", "concrete", "steel", "glass"],
					&"cistern_pressure_cascade",
					Color("e0eee8")
				),
				_variant(
					&"residential_sixfold_balcony_court",
					"Sixfold Balcony Court",
					Vector2(480.0, 390.0),
					["glass", "concrete", "steel", "concrete", "steel", "concrete"],
					&"balcony_zipper_shear",
					Color("f2e5dc")
				),
				_variant(
					&"residential_nightglass_mutual_clinic",
					"Nightglass Mutual Clinic",
					Vector2(450.0, 355.0),
					["glass", "concrete", "steel", "glass", "concrete", "steel"],
					&"clinic_blackout_backfeed",
					Color("e6f6f7")
				),
			]
		),
	]
	_variants_by_id.clear()
	for district: CityDistrictProfile in _districts:
		for variant: StructuralBuildingVariant in district.building_variants:
			_variants_by_id[variant.variant_id] = variant


static func _district(
	index: int,
	id: StringName,
	name: String,
	road_color: Color,
	accent: Color,
	concept_path: String,
	variants: Array
) -> CityDistrictProfile:
	var profile: CityDistrictProfile = CityDistrictProfile.new()
	profile.district_index = index
	profile.district_id = id
	profile.display_name = name
	profile.start_chunk = index * CHUNKS_PER_DISTRICT
	profile.end_chunk = (
		-1 if index == DISTRICT_COUNT - 1 else profile.start_chunk + CHUNKS_PER_DISTRICT - 1
	)
	profile.asphalt_color = road_color
	profile.accent_color = accent
	profile.concept_board_path = concept_path
	for value: Variant in variants:
		var variant: StructuralBuildingVariant = value as StructuralBuildingVariant
		variant.district_id = id
		profile.building_variants.append(variant)
	return profile


static func _variant(
	id: StringName,
	name: String,
	size: Vector2,
	materials: Array,
	signature: StringName,
	tint: Color
) -> StructuralBuildingVariant:
	var variant: StructuralBuildingVariant = StructuralBuildingVariant.new()
	variant.variant_id = id
	variant.display_name = name
	var initial_texture: Texture2D = INITIAL_DISTRICT_TEXTURES.get(id) as Texture2D
	if initial_texture != null:
		variant.intact_texture = initial_texture
	else:
		var facade_path: String = String(FACADE_TEXTURE_PATHS.get(id, ""))
		variant.configure_texture_path(facade_path)
	variant.display_size = size * FACADE_SIZE_SCALE
	variant.material_ids = PackedStringArray(materials)
	variant.visual_tint = tint
	variant.destruction_signature = signature
	return variant
