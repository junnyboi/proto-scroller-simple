extends GutTest


func test_foreground_cancels_vertical_camera_motion_and_preserves_rebase_phase() -> void:
	RuntimeTweakAccess.unbind_service()
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child_autofree(viewport)
	var foreground: BottomForeground = BottomForeground.new()
	viewport.add_child(foreground)
	await get_tree().process_frame
	viewport.canvas_transform = Transform2D(0.0, Vector2(-320.0, -40.0))
	foreground._update_presentation()
	var phase: float = foreground._phase
	assert_almost_eq(phase, 320.0 * 1.18, 0.001)
	assert_almost_eq(foreground.get_global_transform_with_canvas().origin.y, 0.0, 0.001)
	foreground.compensate_origin(Vector2(-2048.0, 0.0))
	viewport.canvas_transform = Transform2D(0.0, Vector2(1728.0, -140.0))
	foreground._update_presentation()
	assert_almost_eq(foreground._phase, phase, 0.001)
	assert_almost_eq(foreground.get_global_transform_with_canvas().origin.y, 0.0, 0.001)
	viewport.size = Vector2i(720, 1280)
	foreground._update_presentation()
	assert_eq(foreground._viewport_size, Vector2(720.0, 1280.0))
	assert_false(foreground.z_as_relative)
	assert_gt(foreground.z_index, 100)
	foreground.reset_origin()
	assert_eq(foreground._origin_x, 0.0)


func test_only_original_business_content_is_registered() -> void:
	assert_eq(CityDistrictCatalog.DISTRICT_COUNT, 1)
	assert_eq(CityDistrictCatalog.BUILDING_VARIANT_COUNT, 5)
	assert_eq(BossCampaignCatalog.definitions().size(), 1)
	assert_eq(BossCampaignCatalog.definitions()[0].boss_id, &"SETTLEMENT_ENGINE_S04")
	assert_eq(DossierCatalog.definitions().size(), 5)
	assert_eq(EnemyArchetypeCatalog.ALL_SPAWNABLE_IDS.size(), 8)
	assert_eq(DistrictMissionCatalog.pools().size(), 1)
	assert_eq(WeaponShopCatalog.products_for(&"BUSINESS").size(), 3)


func test_section_fragments_stay_below_actors_after_pool_reuse() -> void:
	var pool: BuildingSectionBurstPool = BuildingSectionBurstPool.new()
	pool.capacity = 1
	add_child_autofree(pool)
	for profile: StructuralMaterialProfile in [
		StructuralMaterialProfile.concrete(),
		StructuralMaterialProfile.glass(),
		StructuralMaterialProfile.steel(),
	]:
		var burst: BuildingSectionBurst2D = pool.spawn(
			Vector2(300.0, 300.0), Vector2.UP, 420.0, profile
		)
		assert_false(burst.z_as_relative)
		for particles: CPUParticles2D in [
			burst.fragments, burst.falling_debris, burst.dust, burst.ruin_smoke,
		]:
			assert_true(particles.z_as_relative)
			assert_lt(burst.z_index + particles.z_index, 30, "Below the enemy actor layer")
		assert_false(burst.flash.z_as_relative)
		assert_eq(burst.flash.z_index, 43, "Keep the impact flash readable above enemies")
	assert_eq(pool.slot_count(), 1)
	assert_eq(pool.recycle_count, 2)
