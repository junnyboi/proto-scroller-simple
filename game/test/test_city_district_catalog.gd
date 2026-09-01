extends GutTest


func test_catalog_has_two_districts_and_ten_unique_buildings() -> void:
	var districts: Array[CityDistrictProfile] = CityDistrictCatalog.districts()
	assert_eq(districts.size(), CityDistrictCatalog.DISTRICT_COUNT)
	var district_ids: Dictionary[StringName, bool] = {}
	var variant_ids: Dictionary[StringName, bool] = {}
	for district: CityDistrictProfile in districts:
		assert_false(district_ids.has(district.district_id))
		district_ids[district.district_id] = true
		assert_eq(district.variant_count(), CityDistrictCatalog.VARIANTS_PER_DISTRICT)
		assert_eq(district.validation_errors().size(), 0)
		for variant: StructuralBuildingVariant in district.building_variants:
			assert_false(variant_ids.has(variant.variant_id))
			variant_ids[variant.variant_id] = true
			assert_eq(variant.material_ids.size(), StructuralBuilding2D.CELL_COUNT)
	assert_eq(variant_ids.size(), CityDistrictCatalog.BUILDING_VARIANT_COUNT)
	assert_eq(CityDistrictCatalog.validation_errors().size(), 0)


func test_forward_chunk_boundaries_select_the_authored_districts() -> void:
	var expectations: Dictionary[int, StringName] = {
		-64: &"BUSINESS",
		0: &"BUSINESS",
		8: &"BUSINESS",
		9: &"RESIDENTIAL",
		17: &"RESIDENTIAL",
		18: &"RESIDENTIAL",
		26: &"RESIDENTIAL",
		27: &"RESIDENTIAL",
		35: &"RESIDENTIAL",
		36: &"RESIDENTIAL",
		96: &"RESIDENTIAL",
	}
	for logical_index: int in expectations:
		var blueprint: CityChunkBlueprint = CityChunkBlueprint.generate(731, logical_index)
		assert_eq(blueprint.district_id, expectations[logical_index])
		assert_eq(
			blueprint.district_index,
			CityDistrictCatalog.district_index_for_chunk(logical_index)
		)


func test_blueprint_selection_is_replayable_and_order_independent() -> void:
	var indices: Array[int] = [-12, -1, 0, 6, 8, 9, 17, 18, 27, 36, 72]
	var forward: Dictionary[int, StringName] = {}
	for logical_index: int in indices:
		var blueprint: CityChunkBlueprint = CityChunkBlueprint.generate(917, logical_index)
		forward[logical_index] = blueprint.building_variant_id
	indices.reverse()
	for logical_index: int in indices:
		var replay: CityChunkBlueprint = CityChunkBlueprint.generate(917, logical_index)
		assert_eq(replay.building_variant_id, forward[logical_index])
		assert_eq(replay.district_id, replay.district_profile.district_id)
		assert_eq(replay.building_variant_id, replay.building_variant.variant_id)


func test_each_district_displays_five_unique_facades_then_two_distinct_repeats() -> void:
	for run_seed: int in [0, 731, 917, 4401]:
		for district: CityDistrictProfile in CityDistrictCatalog.districts():
			var encounter_counts: Dictionary[StringName, int] = {}
			var opening_roster: Dictionary[StringName, bool] = {}
			var repeat_roster: Dictionary[StringName, bool] = {}
			for local_index: int in range(
				CityDistrictCatalog.FACADE_ENCOUNTERS_PER_DISTRICT
			):
				var logical_index: int = district.start_chunk + local_index
				var variant: StructuralBuildingVariant = CityDistrictCatalog.variant_for_chunk(
					run_seed,
					logical_index
				)
				assert_true(district.building_variants.has(variant))
				assert_eq(
					CityDistrictCatalog.variant_for_chunk(run_seed, logical_index),
					variant
				)
				if local_index < CityDistrictCatalog.VARIANTS_PER_DISTRICT:
					opening_roster[variant.variant_id] = true
				else:
					repeat_roster[variant.variant_id] = true
				encounter_counts[variant.variant_id] = int(
					encounter_counts.get(variant.variant_id, 0)
				) + 1
			assert_eq(
				opening_roster.size(),
				CityDistrictCatalog.VARIANTS_PER_DISTRICT,
				"seed=%d district=%s" % [run_seed, district.district_id]
			)
			assert_eq(repeat_roster.size(), 2)
			assert_eq(
				encounter_counts.size(),
				CityDistrictCatalog.VARIANTS_PER_DISTRICT
			)
			var repeated_variants: int = 0
			for count: int in encounter_counts.values():
				assert_true(count == 1 or count == 2)
				if count == 2:
					repeated_variants += 1
			assert_eq(repeated_variants, 2)
	assert_eq(
		CityDistrictCatalog.variant_for_chunk(0, 0).variant_id,
		&"business_mercy_exchange_annex"
	)
	assert_eq(CityDistrictCatalog.FACADE_ENCOUNTERS_PER_DISTRICT, 7)
	assert_eq(CityDistrictCatalog.CHUNKS_PER_DISTRICT, 9)
	assert_eq(CityDistrictCatalog.TRANSITION_CORRIDOR_CHUNKS, 2)
	assert_true(CityDistrictCatalog.chunk_hosts_facade(6))
	assert_false(CityDistrictCatalog.chunk_hosts_facade(7))
	assert_false(CityDistrictCatalog.chunk_hosts_facade(8))
	assert_true(CityDistrictCatalog.chunk_hosts_facade(9))


func test_nonzero_run_seeds_rotate_the_opening_facade_without_losing_rosters() -> void:
	var opening_ids: Dictionary[StringName, bool] = {}
	for run_seed: int in range(1, 33):
		opening_ids[
			CityDistrictCatalog.variant_for_chunk(run_seed, 0).variant_id
		] = true
	assert_gt(opening_ids.size(), 1)
	assert_lte(opening_ids.size(), CityDistrictCatalog.VARIANTS_PER_DISTRICT)


func test_all_buildings_are_directly_addressable() -> void:
	var addressed: Dictionary[StringName, bool] = {}
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		for variant: StructuralBuildingVariant in district.building_variants:
			assert_eq(
				CityDistrictCatalog.variant_by_id(variant.variant_id),
				variant
			)
			addressed[variant.variant_id] = true
	assert_eq(addressed.size(), CityDistrictCatalog.BUILDING_VARIANT_COUNT)


func test_every_building_has_one_unique_grid_safe_production_facade() -> void:
	var facade_paths: Dictionary[String, bool] = {}
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		for variant: StructuralBuildingVariant in district.building_variants:
			var texture: Texture2D = variant.intact_texture
			var resource_path: String = texture.resource_path
			assert_true(
				resource_path.begins_with(
					"res://art/city/destructibles/districts/"
				)
			)
			assert_false(facade_paths.has(resource_path))
			facade_paths[resource_path] = true
			assert_eq(posmod(texture.get_width(), 6), 0)
			assert_eq(posmod(texture.get_height(), 6), 0)
	assert_eq(facade_paths.size(), CityDistrictCatalog.BUILDING_VARIANT_COUNT)
	var variant_source: String = FileAccess.get_file_as_string(
		"res://scripts/destruction/structural_building_variant.gd"
	)
	var catalog_source: String = FileAccess.get_file_as_string(
		"res://scripts/world/city_district_catalog.gd"
	)
	assert_false(variant_source.contains("damaged_texture"))
	assert_false(variant_source.contains("rubble_texture"))
	assert_false(catalog_source.contains("building_rubble.png"))
