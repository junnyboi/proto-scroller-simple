extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const BASE_FACADE_SIZES: Dictionary[StringName, Vector2] = {
	&"business_mercy_exchange_annex": Vector2(500.0, 445.0),
	&"business_helix_clearinghouse_spine": Vector2(390.0, 520.0),
	&"business_orison_custody_vault": Vector2(590.0, 360.0),
	&"business_vanta_compliance_tribunal": Vector2(500.0, 455.0),
	&"business_crown_reserve_treasury": Vector2(570.0, 500.0),
	&"residential_emberpot_canteen_house": Vector2(410.0, 340.0),
	&"residential_bluewire_laundry_walkup": Vector2(430.0, 405.0),
	&"residential_rainvault_cooperative": Vector2(500.0, 445.0),
	&"residential_sixfold_balcony_court": Vector2(480.0, 390.0),
	&"residential_nightglass_mutual_clinic": Vector2(450.0, 355.0),
	&"entertainment_voltage_chapel": Vector2(420.0, 360.0),
	&"entertainment_orpheum_vanta": Vector2(540.0, 410.0),
	&"entertainment_halcyon_stack_hotel": Vector2(470.0, 500.0),
	&"entertainment_prism_crown_revue": Vector2(610.0, 390.0),
	&"entertainment_house_of_static": Vector2(570.0, 500.0),
	&"military_ordnance_transload_bastion": Vector2(620.0, 350.0),
	&"military_revetment_armory_stack": Vector2(390.0, 330.0),
	&"military_aegis_signal_citadel": Vector2(420.0, 500.0),
	&"military_manticore_repair_gantry": Vector2(650.0, 390.0),
	&"military_prefect_war_keep": Vector2(560.0, 500.0),
	&"royal_laureate_processional_gate": Vector2(540.0, 400.0),
	&"royal_aurelian_conservatory": Vector2(620.0, 400.0),
	&"royal_tribunal_nine_seals": Vector2(650.0, 470.0),
	&"royal_ministry_privilege_spire": Vector2(420.0, 540.0),
	&"royal_palace_last_sovereign": Vector2(680.0, 540.0),
}


func _hollow_progress(pattern: BuildingDamagePattern2D) -> float:
	return float(pattern.cavity_material().get_shader_parameter("hollow_progress"))


func _hollow_extents(pattern: BuildingDamagePattern2D) -> Vector2:
	return pattern.cavity_material().get_shader_parameter("hollow_extents_uv") as Vector2


func _region_uv_rect(pattern: BuildingDamagePattern2D) -> Vector4:
	return pattern.cavity_material().get_shader_parameter("region_uv_rect") as Vector4


func test_all_twenty_five_facades_are_exactly_twenty_percent_larger() -> void:
	assert_almost_eq(CityDistrictCatalog.FACADE_SIZE_SCALE, 1.2, 0.0001)
	var checked_variants: int = 0
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		for variant: StructuralBuildingVariant in district.building_variants:
			var base_size: Vector2 = BASE_FACADE_SIZES.get(
				variant.variant_id,
				Vector2.ZERO
			) as Vector2
			assert_ne(base_size, Vector2.ZERO, String(variant.variant_id))
			assert_eq(
				variant.display_size,
				base_size * CityDistrictCatalog.FACADE_SIZE_SCALE,
				String(variant.variant_id)
			)
			assert_lt(variant.display_size.x, CityStreetChunk.CHUNK_WIDTH)
			checked_variants += 1
	assert_eq(checked_variants, CityDistrictCatalog.BUILDING_VARIANT_COUNT)
	assert_eq(BASE_FACADE_SIZES.size(), CityDistrictCatalog.BUILDING_VARIANT_COUNT)


func test_all_twenty_five_variants_reconfigure_one_cell_tree_in_place() -> void:
	var bootstrap: StructuralBuildingVariant = CityDistrictCatalog.districts()[0].building_variants[0]
	var building: StructuralBuilding2D = StructuralBuilding2D.new()
	building.intact_texture = bootstrap.intact_texture
	building.display_size = bootstrap.display_size
	add_child_autofree(building)
	await get_tree().process_frame
	var cell_ids: PackedInt64Array = PackedInt64Array()
	for row: int in range(StructuralBuilding2D.ROWS):
		for column: int in range(StructuralBuilding2D.COLUMNS):
			cell_ids.append(building.get_cell(column, row).get_instance_id())
	var baseline_child_count: int = building.get_child_count()
	var configured_count: int = 0
	var silhouette_variants: Dictionary[int, bool] = {}
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		for variant: StructuralBuildingVariant in district.building_variants:
			assert_true(building.apply_variant(variant))
			assert_eq(building.current_variant_id(), variant.variant_id)
			assert_eq(building.display_size, variant.display_size)
			assert_eq(building.get_child_count(), baseline_child_count)
			var cell_index: int = 0
			for row: int in range(StructuralBuilding2D.ROWS):
				for column: int in range(StructuralBuilding2D.COLUMNS):
					var cell: Destructible2D = building.get_cell(column, row)
					assert_eq(cell.get_instance_id(), cell_ids[cell_index])
					assert_eq(
						cell.get_material_profile().material_id,
						variant.material_id_at(column, row)
					)
					var sprite: Sprite2D = cell.get_node(^"IntactVisual") as Sprite2D
					assert_eq(sprite.texture, variant.intact_texture)
					var pattern: BuildingDamagePattern2D = cell.get_node(
						^"DamagedVisual"
					) as BuildingDamagePattern2D
					assert_not_null(pattern.cavity_material())
					assert_eq(sprite.material, pattern.cavity_material())
					assert_almost_eq(_hollow_progress(pattern), 0.0, 0.0001)
					var silhouette_variant: int = pattern._ruin_silhouette_variant()
					assert_gte(silhouette_variant, 0)
					assert_lt(
						silhouette_variant,
						BuildingDamagePattern2D.RUIN_SILHOUETTE_VARIANT_COUNT
					)
					assert_eq(
						int(
							pattern.cavity_material().get_shader_parameter(
								"silhouette_variant"
							)
						),
						silhouette_variant
					)
					silhouette_variants[silhouette_variant] = true
					var uv_region: Vector4 = _region_uv_rect(pattern)
					assert_almost_eq(uv_region.x, float(column) / 3.0, 0.0001)
					assert_almost_eq(uv_region.y, float(row) / 2.0, 0.0001)
					assert_almost_eq(uv_region.z, 1.0 / 3.0, 0.0001)
					assert_almost_eq(uv_region.w, 1.0 / 2.0, 0.0001)
					assert_null(cell.get_node_or_null(^"RubbleVisual"))
					assert_null(cell.get_node_or_null(^"RubbleEdgeVisual"))
					assert_lt(
						(
							sprite.region_rect.size * sprite.scale
							- variant.display_size / Vector2(3.0, 2.0)
						).length(),
						0.01
					)
					cell_index += 1
			configured_count += 1
	assert_eq(configured_count, CityDistrictCatalog.BUILDING_VARIANT_COUNT)
	assert_eq(
		silhouette_variants.size(),
		BuildingDamagePattern2D.RUIN_SILHOUETTE_VARIANT_COUNT
	)


func test_all_twenty_five_facades_keep_alpha_and_every_section_can_break() -> void:
	var bootstrap: StructuralBuildingVariant = CityDistrictCatalog.districts()[0].building_variants[0]
	var building: StructuralBuilding2D = StructuralBuilding2D.new()
	building.intact_texture = bootstrap.intact_texture
	building.display_size = bootstrap.display_size
	add_child_autofree(building)
	await get_tree().process_frame
	var checked_variants: int = 0
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		for variant: StructuralBuildingVariant in district.building_variants:
			assert_eq(variant.district_id, district.district_id)
			assert_true(building.apply_variant(variant))
			var source_image: Image = variant.intact_texture.get_image()
			assert_not_null(source_image)
			assert_ne(source_image.detect_alpha(), Image.ALPHA_NONE, String(variant.variant_id))
			for row: int in range(StructuralBuilding2D.ROWS):
				for column: int in range(StructuralBuilding2D.COLUMNS):
					assert_true(building.apply_variant(variant))
					var cell: Destructible2D = building.get_cell(column, row)
					var event: DamageEvent = DamageEvent.new(
						950_000 + checked_variants * 10 + row * 3 + column,
						null,
						cell.max_health + 1.0,
						&"variant_section_probe",
						cell.global_position,
						Vector2.RIGHT,
						0.0
					)
					assert_true(cell.receive_damage(event), "%s[%d,%d]" % [
						variant.variant_id,
						column,
						row,
					])
					await get_tree().physics_frame
					assert_true(cell.is_destroyed())
					var pattern: BuildingDamagePattern2D = cell.get_node(
						^"DamagedVisual"
					) as BuildingDamagePattern2D
					assert_true(pattern.visible, String(variant.variant_id))
					assert_true(pattern.is_destroyed_stage(), String(variant.variant_id))
					assert_true(
						(cell.get_node(^"IntactVisual") as Sprite2D).visible,
						String(variant.variant_id)
					)
					assert_eq(
						pattern.contour().size(),
						BuildingDamagePattern2D.CONTOUR_POINTS,
						String(variant.variant_id)
					)
					assert_gt(pattern.crack_count(), 0, String(variant.variant_id))
					assert_almost_eq(
						pattern.cavity_darken_strength(),
						BuildingDamagePattern2D.DESTROYED_DARKEN_STRENGTH,
						0.0001,
						String(variant.variant_id)
					)
					assert_almost_eq(
						_hollow_progress(pattern),
						1.0,
						0.0001,
						String(variant.variant_id)
					)
					assert_gte(
						_hollow_extents(pattern).x,
						0.35,
						String(variant.variant_id)
					)
					assert_gte(
						_hollow_extents(pattern).y,
						0.38,
						String(variant.variant_id)
					)
					assert_true(
						pattern.cavity_material().shader.code.contains(
							"opening_metric < boundary - edge_softness"
						),
						String(variant.variant_id)
					)
					assert_true(
						pattern.cavity_material().shader.code.contains("top_break_depth"),
						String(variant.variant_id)
					)
					assert_true(
						pattern.cavity_material().shader.code.contains(
							"silhouette_variant == 5"
						),
						String(variant.variant_id)
					)
					assert_eq(pattern._is_ground_level_ruin(), row == 1)
					assert_eq(
						pattern._ruin_rubble_sprite_count(),
						BuildingDamagePattern2D.RUIN_RUBBLE_SPRITE_COUNT if row == 1 else 0,
						String(variant.variant_id)
					)
					var rubble_bed: PersistentRubbleBed2D = pattern._ruin_rubble_bed()
					if row == 1:
						assert_not_null(rubble_bed, String(variant.variant_id))
						assert_true(rubble_bed.uses_only_rubble_fragments())
						assert_eq(rubble_bed.material_id(), variant.material_id_at(column, row))
						assert_eq(pattern._district_style_id(), district.district_id)
						assert_eq(rubble_bed.district_id(), district.district_id)
						assert_eq(
							rubble_bed.district_tint(),
							PersistentRubbleBed2D.tint_for_district(district.district_id)
						)
						assert_almost_eq(
							rubble_bed.baseline_y(),
							variant.display_size.y / 4.0,
							0.001,
							String(variant.variant_id)
						)
						assert_eq(rubble_bed.z_index, 3)
						for rubble: Sprite2D in rubble_bed.get_children():
							assert_gt(rubble.modulate.get_luminance(), 0.50)
					else:
						assert_null(rubble_bed, String(variant.variant_id))
					assert_null(cell.get_node_or_null(^"RubbleVisual"))
					assert_null(cell.get_node_or_null(^"RubbleEdgeVisual"))
					var hurtbox: CollisionShape2D = cell.get_node(
						^"Hurtbox/CollisionShape2D"
					) as CollisionShape2D
					assert_true(hurtbox.disabled)
			checked_variants += 1
	assert_eq(checked_variants, CityDistrictCatalog.BUILDING_VARIANT_COUNT)


func test_stream_runtime_applies_variants_outside_assertions() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/world/streamed_destructible_runtime.gd"
	)
	assert_false(source.contains("assert(building.apply_variant"))
	assert_true(
		source.contains(
			"var variant_applied: bool = building.apply_variant(blueprint.building_variant)"
		)
	)


func test_streaming_reuses_six_buildings_across_all_district_boundaries() -> void:
	var city: CitySlice = await _spawn_city()
	var building_ids: PackedInt64Array = PackedInt64Array()
	for building: StructuralBuilding2D in city.streamed_destructibles.buildings:
		building_ids.append(building.get_instance_id())
	var baseline_nodes: int = int(RuntimeBudget.snapshot(city).node_count)
	var live_facade_paths: Dictionary[String, bool] = {}
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		var district_facade_paths: Dictionary[String, bool] = {}
		for local_index: int in range(CityDistrictCatalog.VARIANTS_PER_DISTRICT):
			var logical_index: int = district.start_chunk + local_index
			await _move_to_logical_chunk(city, logical_index)
			var blueprint: CityChunkBlueprint = CityChunkBlueprint.generate(
				city.world_stream.run_seed,
				logical_index
			)
			var building: StructuralBuilding2D = city.building
			var sprite: Sprite2D = building.get_cell(0, 0).get_node(
				^"IntactVisual"
			) as Sprite2D
			assert_eq(building.current_variant_id(), blueprint.building_variant_id)
			assert_eq(building.get_meta(&"district_id"), blueprint.district_id)
			assert_eq(building.get_meta(&"district_index"), blueprint.district_index)
			assert_eq(building.display_size, blueprint.building_variant.display_size)
			assert_eq(sprite.texture, blueprint.building_variant.intact_texture)
			assert_eq(
				sprite.texture.resource_path,
				blueprint.building_variant.intact_texture.resource_path
			)
			district_facade_paths[sprite.texture.resource_path] = true
			live_facade_paths[sprite.texture.resource_path] = true
			for row: int in range(StructuralBuilding2D.ROWS):
				for column: int in range(StructuralBuilding2D.COLUMNS):
					assert_eq(
						building.get_material_profile(column, row).material_id,
						blueprint.building_variant.material_id_at(column, row)
					)
			assert_eq(int(RuntimeBudget.snapshot(city).node_count), baseline_nodes)
		assert_eq(
			district_facade_paths.size(),
			CityDistrictCatalog.VARIANTS_PER_DISTRICT,
			String(district.district_id)
		)
	assert_eq(live_facade_paths.size(), CityDistrictCatalog.BUILDING_VARIANT_COUNT)
	assert_eq(city.streamed_destructibles.active_building_count(), 6)
	assert_eq(city.streamed_destructibles.post_warm_creation_count, 0)
	for index: int in range(building_ids.size()):
		assert_eq(
			city.streamed_destructibles.buildings[index].get_instance_id(),
			building_ids[index]
		)


func test_stream_state_restores_only_to_the_matching_variant() -> void:
	var business: CityDistrictProfile = CityDistrictCatalog.districts()[0]
	var first: StructuralBuildingVariant = business.building_variants[0]
	var second: StructuralBuildingVariant = business.building_variants[1]
	var building: StructuralBuilding2D = StructuralBuilding2D.new()
	building.intact_texture = first.intact_texture
	building.display_size = first.display_size
	add_child_autofree(building)
	await get_tree().process_frame
	assert_true(building.apply_variant(first))
	var cell: Destructible2D = building.get_cell(0, 1)
	var event: DamageEvent = DamageEvent.new(
		92_001,
		null,
		20.0,
		&"jab_cross",
		cell.global_position,
		Vector2.RIGHT,
		250.0
	)
	assert_true(cell.receive_damage(event))
	var damaged_health: float = cell.current_health
	var pattern: BuildingDamagePattern2D = cell.get_node(^"DamagedVisual") as BuildingDamagePattern2D
	var signature: String = pattern.pattern_signature()
	var state: Dictionary = building.capture_stream_state()
	assert_eq(state.variant_id, first.variant_id)
	assert_true(building.apply_variant(first))
	building.restore_stream_state(state)
	assert_almost_eq(building.get_cell(0, 1).current_health, damaged_health, 0.01)
	var restored_pattern: BuildingDamagePattern2D = building.get_cell(0, 1).get_node(
		^"DamagedVisual"
	) as BuildingDamagePattern2D
	assert_eq(restored_pattern.pattern_signature(), signature)
	assert_true(building.apply_variant(second))
	building.restore_stream_state(state)
	assert_eq(
		building.get_cell(0, 1).current_health,
		building.get_cell(0, 1).max_health
	)
	assert_eq(building.destroyed_cell_count(), 0)


func test_forward_boundaries_emit_four_spatial_district_transitions() -> void:
	var city: CitySlice = await _spawn_city()
	var transitions: Array[Dictionary] = []
	city.world_stream.district_changed.connect(
		func(previous_id: StringName, district_id: StringName, chunk: int) -> void:
			transitions.append({
				"previous": previous_id,
				"district": district_id,
				"chunk": chunk,
			})
	)
	for logical_index: int in [7, 14, 21, 28]:
		_unlock_current_district(city.world_stream)
		await _move_to_logical_chunk(city, logical_index)
	assert_eq(transitions.size(), 4)
	assert_eq(transitions[0].previous, &"BUSINESS")
	assert_eq(transitions[0].district, &"RESIDENTIAL")
	assert_eq(transitions[0].chunk, 7)
	assert_eq(transitions[1].district, &"ENTERTAINMENT")
	assert_eq(transitions[2].district, &"MILITARY")
	assert_eq(transitions[3].district, &"ROYAL")
	assert_eq(transitions[3].chunk, 28)
	assert_eq(city.world_stream.current_district_id, &"ROYAL")
	assert_eq(city.world_stream.current_district().district_id, &"ROYAL")
	assert_eq(city.district_transition_banner.presentation_count, 4)
	assert_true(city.district_transition_banner.panel.visible)


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	return city


func _move_to_logical_chunk(city: CitySlice, logical_index: int) -> void:
	city.robot.global_position.x = (
		city.world_stream.runtime_x_for_logical_index(logical_index) + 700.0
	)
	city.world_stream.advance_stream()
	await get_tree().physics_frame
	city.world_stream.advance_stream()
	await get_tree().process_frame


func _unlock_current_district(stream: CityWorldStream) -> void:
	var district: CityDistrictProfile = stream.current_district()
	for encounter_index: int in range(
		CityDistrictCatalog.FACADE_ENCOUNTERS_PER_DISTRICT
	):
		var logical_chunk: int = district.start_chunk + encounter_index
		var variant: StructuralBuildingVariant = CityDistrictCatalog.variant_for_chunk(
			stream.run_seed,
			logical_chunk
		)
		var building: StructuralBuilding2D = StructuralBuilding2D.new()
		building.set_meta(&"district_id", district.district_id)
		building.set_meta(&"district_index", district.district_index)
		building.set_meta(&"building_variant_id", variant.variant_id)
		building.set_meta(&"logical_chunk", logical_chunk)
		stream.report_building_cleared(building)
		building.free()
	stream.begin_post_boss_corridor(district.district_index)
	stream.complete_district_handoff(district.district_index)
