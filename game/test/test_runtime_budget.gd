extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")


func test_runtime_snapshot_matches_every_approved_cap() -> void:
	var city: CitySlice = await _spawn_city()
	var snapshot: Dictionary = RuntimeBudget.snapshot(city)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())
	assert_eq(
		snapshot.enemy_total,
		RuntimeBudget.SOLDIERS
		+ RuntimeBudget.TANKS
		+ RuntimeBudget.HELICOPTERS
		+ RuntimeBudget.PROCEDURAL_ENEMIES
	)
	assert_eq(snapshot.projectile_total, 32)
	assert_eq(snapshot.hostile_projectile_total, 24)
	assert_eq(snapshot.player_bullet_total, 8)
	assert_eq(snapshot.structural_debris_total, 24)
	assert_eq(snapshot.building_damage_patterns, RuntimeBudget.BUILDING_DAMAGE_PATTERNS)
	assert_eq(snapshot.structural_rubble_sprites, RuntimeBudget.STRUCTURAL_RUBBLE_SPRITES)
	assert_eq(snapshot.prop_rubble_sprites, RuntimeBudget.PROP_RUBBLE_SPRITES)
	assert_eq(snapshot.catalyst_rubble_sprites, RuntimeBudget.CATALYST_RUBBLE_SPRITES)
	assert_eq(snapshot.enemy_scrap_total, 32)
	assert_eq(snapshot.soldier_defeat_total, 8)
	assert_eq(snapshot.wreck_total, 4)
	assert_eq(snapshot.particle_slots, 8)
	assert_eq(snapshot.audio_voices, 8)
	assert_eq(snapshot.robot_audio_voices, RuntimeBudget.ROBOT_AUDIO_VOICES)
	assert_eq(snapshot.air_target_voices, 1)
	assert_eq(snapshot.air_target_reticles, 1)
	assert_eq(snapshot.dodge_afterimage_slots, 8)
	assert_eq(snapshot.dodge_dust_slots, 6)
	assert_eq(snapshot.critical_smoke_emitters, 1)
	assert_eq(snapshot.melee_charge_emitters, RuntimeBudget.MELEE_CHARGE_EMITTERS)
	assert_eq(snapshot.melee_charge_particles, RuntimeBudget.MELEE_CHARGE_PARTICLES)
	assert_eq(snapshot.melee_charge_visuals, RuntimeBudget.MELEE_CHARGE_VISUALS)
	assert_eq(snapshot.melee_charge_visuals, 4)
	assert_eq(snapshot.elite_spawn_effect_slots, 6)
	assert_eq(snapshot.hazard_total, RuntimeBudget.HAZARD_ACTORS)
	assert_eq(snapshot.hazard_vfx_slots, RuntimeBudget.HAZARD_VFX_SLOTS)
	assert_eq(snapshot.hazard_audio_voices, RuntimeBudget.HAZARD_AUDIO_VOICES)
	assert_eq(snapshot.hazard_active, 0)
	assert_eq(snapshot.hazard_post_warm_creations, 0)
	assert_eq(snapshot.hazard_activation_denials, 0)
	assert_lte(
		snapshot.district_pressure_peak_tier,
		CityWorldStream.MAX_PROGRESSION_TIER
	)
	assert_lte(
		snapshot.district_pressure_peak_threat,
		EnemySpawnTuning.scaled_threat(DistrictPressureCatalog.MAX_LIVE_THREAT)
	)
	assert_gte(snapshot.district_copy_degradations, 0)
	assert_eq(snapshot.street_chunks, RuntimeBudget.STREET_CHUNKS)
	assert_eq(snapshot.street_post_warm_creations, 0)
	assert_eq(snapshot.floating_origin_runtimes, 1)
	assert_eq(snapshot.weather_runtimes, RuntimeBudget.WEATHER_RUNTIMES)
	assert_eq(snapshot.weather_surfaces, RuntimeBudget.WEATHER_SURFACES)
	assert_eq(
		snapshot.weather_particle_capacity,
		RuntimeBudget.WEATHER_PARTICLE_CAPACITY
	)
	assert_eq(snapshot.weather_post_warm_creations, 0)
	assert_eq(snapshot.sky_life_runtimes, RuntimeBudget.SKY_LIFE_RUNTIMES)
	assert_eq(snapshot.sky_life_bands, RuntimeBudget.SKY_LIFE_BANDS)
	assert_eq(snapshot.sky_life_sprites, RuntimeBudget.SKY_LIFE_SPRITES)
	assert_eq(snapshot.sky_life_post_warm_creations, 0)
	assert_eq(snapshot.narrative_directors, RuntimeBudget.NARRATIVE_DIRECTORS)
	assert_eq(snapshot.transmission_toasts, RuntimeBudget.TRANSMISSION_TOASTS)
	assert_eq(
		snapshot.rear_barrier_warning_overlays,
		RuntimeBudget.REAR_BARRIER_WARNING_OVERLAYS
	)
	assert_eq(
		snapshot.rear_barrier_warning_voices,
		RuntimeBudget.REAR_BARRIER_WARNING_VOICES
	)
	assert_eq(snapshot.streamed_buildings, RuntimeBudget.STREAMED_BUILDINGS)
	assert_eq(snapshot.streamed_props, RuntimeBudget.STREAMED_PROPS)
	assert_eq(snapshot.repair_pickup_slots, RuntimeBudget.REPAIR_PICKUP_SLOTS)
	assert_eq(snapshot.streamed_post_warm_creations, 0)
	assert_eq(snapshot.world_mutation_ledgers, 1)
	assert_eq(snapshot.rare_rows, 3)
	assert_eq(snapshot.cosmetic_debris_instances, 64)
	assert_eq(snapshot.machine_gun_impact_slots, 4)
	assert_eq(snapshot.hostile_impact_slots, RuntimeBudget.HOSTILE_IMPACT_SLOTS)
	assert_eq(snapshot.hostile_impact_slots, 8)
	assert_eq(snapshot.boss_sessions, 1)
	assert_eq(snapshot.boss_rigs, 1)
	assert_eq(snapshot.boss_arena_barriers, RuntimeBudget.BOSS_ARENA_BARRIERS)
	assert_eq(snapshot.boss_defeat_spectacles, RuntimeBudget.BOSS_DEFEAT_SPECTACLES)
	assert_eq(snapshot.boss_defeat_visual_slots, 22)
	assert_eq(snapshot.boss_defeat_particle_emitters, 14)
	assert_eq(snapshot.boss_defeat_particle_capacity, 548)
	assert_eq(snapshot.boss_defeat_audio_players, 1)
	assert_eq(snapshot.boss_controllers, 1)
	assert_eq(snapshot.boss_arena_adapters, 1)
	assert_eq(snapshot.boss_pylon_presentations, 5)
	assert_eq(snapshot.boss_projection_slots, 4)
	assert_eq(snapshot.boss_markers, 8)
	assert_eq(snapshot.boss_lane_damage_areas, 3)
	assert_eq(snapshot.boss_line_areas, 2)
	assert_eq(snapshot.boss_radial_shockwaves, RuntimeBudget.BOSS_RADIAL_SHOCKWAVES)
	assert_eq(snapshot.boss_collapse_listeners, 2)
	assert_eq(snapshot.boss_pod_visuals, 4)
	assert_eq(snapshot.boss_reclamation_anchors, 3)
	assert_eq(snapshot.boss_wreck_receivers, 2)
	assert_eq(snapshot.boss_rubble_presentations, 1)
	assert_eq(snapshot.boss_post_warm_creations, 0)
	assert_eq(snapshot.boss_reservations, 0)
	assert_false(snapshot.has("player_strike_flashes"))
	assert_eq(snapshot.player_attack_reaction_runtimes, 1)


func test_pool_saturation_recycles_without_node_or_capacity_growth() -> void:
	var city: CitySlice = await _spawn_city()
	var baseline: Dictionary = RuntimeBudget.snapshot(city)
	var profile: StructuralMaterialProfile = StructuralMaterialProfile.concrete()
	for request_index: int in range(96):
		city.debris_pool.acquire(
			Transform2D(0.0, Vector2(500.0, 300.0)),
			Vector2.RIGHT * 800.0,
			0.0,
			4.0
		)
		city.enemy_scrap_pool.acquire(
			Transform2D(0.0, Vector2(600.0, 300.0)),
			Vector2.LEFT * 700.0,
			0.0,
			5.0
		)
		city.impact_feedback_pool.spawn_particles(
			Vector2.ZERO,
			Vector2.RIGHT,
			300.0,
			profile,
			5
		)
	var after: Dictionary = RuntimeBudget.snapshot(city)
	assert_eq(after.node_count, baseline.node_count)
	assert_eq(after.structural_debris_total, RuntimeBudget.STRUCTURAL_DEBRIS)
	assert_eq(after.enemy_scrap_total, RuntimeBudget.ENEMY_SCRAP)
	assert_eq(after.particle_slots, RuntimeBudget.PARTICLE_SLOTS)
	assert_eq(after.structural_debris_peak, RuntimeBudget.STRUCTURAL_DEBRIS)
	assert_eq(after.enemy_scrap_peak, RuntimeBudget.ENEMY_SCRAP)
	assert_gt(city.debris_pool.recycle_count, 0)
	assert_gt(city.enemy_scrap_pool.recycle_count, 0)


func test_three_retry_generations_have_identical_clean_runtime_shape() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	main.start_game()
	await get_tree().process_frame
	var expected_nodes: int = int(RuntimeBudget.snapshot(main.city_slice).node_count)
	for retry_index: int in range(3):
		main.city_slice.rampage_events.legacy_score(100 + retry_index)
		main.city_slice.rampage_session.momentum_meter.apply_event(GameplayEvent.new(
			StringName("retry_momentum_%d" % retry_index),
			0,
			GameplayEvent.Kind.DAMAGE_APPLIED,
			&"",
			0,
			45.0
		))
		main.retry_game()
		await get_tree().process_frame
		await get_tree().process_frame
		var snapshot: Dictionary = RuntimeBudget.snapshot(main.city_slice)
		assert_eq(snapshot.node_count, expected_nodes)
		assert_eq(main.city_slice.score, 0)
		assert_eq(main.city_slice.rampage_session.momentum_value(), 0.0)
		assert_eq(snapshot.enemy_post_warm_creations, 0)
		assert_eq(snapshot.hazard_active, 0)
		assert_eq(snapshot.hazard_post_warm_creations, 0)
		assert_eq(snapshot.street_chunks, RuntimeBudget.STREET_CHUNKS)
		assert_eq(snapshot.street_post_warm_creations, 0)
		assert_eq(snapshot.player_bullet_active, 0)
		assert_eq(RuntimeBudget.validation_errors(main.city_slice), PackedStringArray())


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	return city
