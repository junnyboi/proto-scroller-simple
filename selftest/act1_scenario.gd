extends SceneTree

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[ACT1-FAIL] " + label)


func _run() -> void:
	_check(CityDistrictCatalog.districts().size() == 1, "one district")
	_check(CityDistrictCatalog.validation_errors().is_empty(), "district catalog")
	_check(BossCampaignCatalog.validation_errors().is_empty(), "boss catalog")
	_check(DossierCatalog.validation_errors().is_empty(), "five Act 1 dossiers")
	_check(EnemyArchetypeCatalog.validation_errors().is_empty(), "Act 1 enemy roster")
	_check(DistrictMissionCatalog.validation_errors().is_empty(), "Business directives")
	_check(DistrictPressureCatalog.validation_errors().is_empty(), "Business pressure")
	_check(WeaponShopCatalog.validation_errors().is_empty(), "Business shop")
	_check(WeaponShopVisualCatalog.validation_errors().is_empty(), "Business shop media")
	var district: DistrictDefinition = load("res://resources/siege/district_contact.tres")
	_check(district.acts.size() == 1 and district.acts[0].beats.size() == 4,
		"original Contact act and four authored beats")
	var main: Main = load("res://scenes/main/main.tscn").instantiate() as Main
	root.add_child(main)
	await process_frame
	_check(main.title_screen != null, "original title")
	main.start_game()
	await process_frame
	await physics_frame
	var city: CitySlice = main.city_slice
	_check(city != null and city.robot != null, "original city and giant robot")
	var foreground: BottomForeground = city.get_node("ParallaxCity/BottomForeground") as BottomForeground
	_check(foreground.z_index > city.robot.z_index, "foreground above player")
	for actor: EnemyActor2D in city.encounter_runtime.all_actors():
		_check(foreground.z_index > actor.z_index, "foreground above enemy")
	_check(city.debris_pool.z_index < 30, "debris below enemies")
	_check(foreground.tile_width() > 0.0, "repeatable foreground")
	city.urban_siege.pause_coordinator.release_all()
	city.upgrade_assembler.session.set_presentation_blocked(false)
	city.encounter_runtime.release_all()
	city.robot.set_physics_process(false)
	var enemy: EnemyActor2D = city.encounter_runtime.acquire(&"bulwark", Vector2(1200, 540))
	_check(enemy != null and enemy.visual.texture != null, "original enemy spawns with art")
	_check(enemy.receive_damage(DamageEvent.new(81000, city.robot, 100000.0)), "enemy combat")
	var definition: BossEncounterDefinition = BossCampaignCatalog.definitions()[0]
	city.robot.global_position.x = definition.trigger_chunk * CityWorldStream.CHUNK_WIDTH + 100.0
	city.world_stream.reset_stream(city.world_stream.run_seed)
	await process_frame
	city.urban_siege.pause_coordinator.release_all()
	for encounter_index: int in range(CityDistrictCatalog.FACADE_ENCOUNTERS_PER_DISTRICT):
		var building: StructuralBuilding2D = StructuralBuilding2D.new()
		building.set_meta(&"district_id", &"BUSINESS")
		building.set_meta(&"district_index", 0)
		building.set_meta(&"logical_chunk", encounter_index)
		building.set_meta(&"building_variant_id", CityDistrictCatalog.variant_for_chunk(
			city.world_stream.run_seed, encounter_index).variant_id)
		city.world_stream.report_building_cleared(building)
		building.free()
	city.robot.global_position.x = (
		(definition.trigger_chunk + BossCampaignDirector.GATE_APPROACH_FRACTION)
		* CityWorldStream.CHUNK_WIDTH
		- city.world_stream.floating_origin.origin_chunk * CityWorldStream.CHUNK_WIDTH + 1.0
	)
	city.urban_siege.boss_campaign.advance()
	await process_frame
	await process_frame
	var boss: TankEnemy = city.urban_siege.boss_session.boss
	_check(boss != null and city.urban_siege.boss_session.active(), "first boss gate")
	if boss != null:
		_check(boss.receive_damage(DamageEvent.new(81001, city.robot, definition.armor, &"bullet")), "boss armor")
		_check(boss.receive_damage(DamageEvent.new(81002, city.robot, definition.health, &"impact")), "boss body")
		city.urban_siege.boss_session.utility_pool.defeat_spectacle.advance(
			BossDefeatSpectacle2D.PRESENTATION_SECONDS + 0.1)
		_check(city.weapon_shop_assembler.session.active, "original salvage checkout")
		_check(city.weapon_shop_assembler.session.close_shop(), "checkout closes")
		await process_frame
		await process_frame
		_check(city.game_over_active, "Act 1 victory after checkout")
		_check(city.world_stream.unlocked_district_index == 0, "no Act 2 unlock")
	main.retry_game()
	await process_frame
	_check(main.city_slice != city and not main.city_slice.game_over_active, "retry resets run")
	var retry_city: CitySlice = main.city_slice
	var summaries: Array[RunSummarySnapshot] = []
	retry_city.run_lifecycle.run_finished.connect(func(_won: bool, summary: RunSummarySnapshot) -> void: summaries.append(summary))
	retry_city.run_lifecycle.robot_defeated()
	retry_city.run_lifecycle._finish_run(true)
	_check(summaries.size() == 1, "terminal finalization is idempotent")
	_check(retry_city.game_over_active and not summaries[0].completed, "defeat route")
	_check(summaries[0].run_id == retry_city.run_id and not summaries[0].run_id.is_empty(), "stable run identity")
	_check(summaries[0].stage_id == &"BUSINESS_ACT_1", "stage metadata")
	_check(summaries[0].duration_seconds >= 0.0, "nonnegative duration")
	_check(retry_city.leaderboard_bridge.last_submission_blocked, "debug runs cannot submit globally")
	main._return_to_title()
	await process_frame
	_check(main.city_slice == null and main.title_screen != null, "defeat returns to title")
	main.queue_free()
	await process_frame
	# Let outstanding scene-tree attack/collapse timers release their suspended
	# calls after the owner is freed; also expose any stale callbacks before exit.
	await create_timer(1.5).timeout
	await process_frame
	print("[ACT1] checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
