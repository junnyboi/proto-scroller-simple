extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const PROFILE_CASES: Array[Dictionary] = [
	{
		"boss_id": &"SAMARITAN_15",
		"district_index": 1,
		"signature": &"TRIAGE_LIFT_MOTES",
		"attacks": [
			&"TRIAGE_SWEEP", &"PRESSURE_SENTENCE",
			&"EXTRACTION_CLAMP", &"BLACKOUT_HARVEST",
		],
	},
]


func test_residential_boss_has_a_complete_particle_profile() -> void:
	assert_true(BossAttackParticleCatalog.profile_for_boss(
		&"SETTLEMENT_ENGINE_S04"
	).is_empty())
	assert_true(BossAttackParticleCatalog.profile_for_attack(
		&"CORE_SHOCKWAVE"
	).is_empty())
	var signatures: Dictionary[StringName, bool] = {}
	for test_case: Dictionary in PROFILE_CASES:
		var boss_id: StringName = StringName(test_case.boss_id)
		var profile: Dictionary = BossAttackParticleCatalog.profile_for_boss(boss_id)
		var signature: StringName = StringName(test_case.signature)
		assert_false(profile.is_empty(), boss_id)
		assert_eq(int(profile.district_index), int(test_case.district_index), boss_id)
		assert_eq(StringName(profile.signature), signature, boss_id)
		assert_not_null(profile.get("texture") as Texture2D, boss_id)
		assert_false(signatures.has(signature), signature)
		signatures[signature] = true
		for attack_value: Variant in test_case.attacks:
			var attack_id: StringName = StringName(attack_value)
			assert_eq(
				BossAttackParticleCatalog.boss_id_for_attack(attack_id),
				boss_id,
				attack_id
			)
			assert_eq(
				StringName(BossAttackParticleCatalog.profile_for_attack(
					attack_id
				).signature),
				signature,
				attack_id
			)
	assert_eq(signatures.size(), 1)


func test_attack_areas_emit_profiled_warnings_and_stop_for_safe_or_hidden_states() -> void:
	var pool: BossUtilityPool = BossUtilityPool.new()
	add_child_autofree(pool)
	var area: BossAttackArea2D = pool.lane_damage_areas[0]
	var initial: Dictionary = area.attack_particle_snapshot()
	assert_eq(int(initial.bounded_emitter_count), 2)
	assert_false(bool(initial.warning_emitting))
	area.configure_footprint(
		Vector2(128.0, 64.0),
		Vector2(320.0, 112.0),
		BossAttackArea2D.VisualState.TELEGRAPH,
		&"TRIAGE_SWEEP"
	)
	var triage: Dictionary = area.attack_particle_snapshot()
	assert_eq(StringName(triage.boss_id), &"SAMARITAN_15")
	assert_eq(StringName(triage.signature), &"TRIAGE_LIFT_MOTES")
	assert_true(bool(triage.warning_emitting))
	assert_false(bool(triage.release_emitting))
	assert_eq(int(triage.warning_amount), 34)
	area.configure_footprint(
		area.global_position,
		area.footprint_size,
		BossAttackArea2D.VisualState.ARMED,
		&"TRIAGE_SWEEP"
	)
	assert_true(bool(area.attack_particle_snapshot().release_emitting))
	area.configure_footprint(
		area.global_position,
		area.footprint_size,
		BossAttackArea2D.VisualState.DRY,
		&"BLACKOUT_HARVEST"
	)
	assert_false(bool(area.attack_particle_snapshot().warning_emitting))
	area.deactivate()
	assert_true(StringName(area.attack_particle_snapshot().signature).is_empty())
	assert_false(bool(area.attack_particle_snapshot().warning_emitting))


func test_projectile_attack_particle_pool_is_fixed_and_reuses_unique_signatures() -> void:
	var pool: BossAttackParticlePool2D = BossAttackParticlePool2D.new()
	add_child_autofree(pool)
	pool.setup()
	assert_eq(pool.slot_count(), BossAttackParticlePool2D.SLOT_CAPACITY)
	for index: int in range(PROFILE_CASES.size()):
		var test_case: Dictionary = PROFILE_CASES[index]
		var particles: CPUParticles2D = pool.play_telegraph(
			StringName(test_case.boss_id),
			Vector2(float(index) * 32.0, 0.0),
			Vector2.DOWN,
			1.5
		)
		assert_not_null(particles)
		assert_true(particles.emitting)
		assert_same(
			particles.texture,
			BossAttackParticleCatalog.profile_for_boss(
				StringName(test_case.boss_id)
			).texture
		)
	var release: CPUParticles2D = pool.play_release(
		&"SAMARITAN_15", Vector2.ZERO, Vector2.LEFT, 1.5
	)
	assert_not_null(release)
	var snapshot: Dictionary = pool.signature_snapshot()
	assert_eq(int(snapshot.slots), BossAttackParticlePool2D.SLOT_CAPACITY)
	assert_eq(int(snapshot.telegraphs), 1)
	assert_eq(int(snapshot.releases), 1)
	assert_eq(StringName(snapshot.boss_id), &"SAMARITAN_15")
	assert_eq(StringName(snapshot.signature), &"TRIAGE_LIFT_MOTES")
	assert_eq(StringName(snapshot.cue), &"RELEASE")
	pool.stop_all()
	assert_eq(pool.active_slot_count(), 0)


func test_live_boss_controllers_prime_their_own_warning_signature() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	var session: CommandBossSession = city.urban_siege.boss_session
	for test_case: Dictionary in PROFILE_CASES:
		var boss_id: StringName = StringName(test_case.boss_id)
		assert_true(session.start_definition(BossCampaignCatalog.definition(boss_id)))
		var expected_signature: StringName = StringName(test_case.signature)
		var projectile_signature: Dictionary
		projectile_signature = session.utility_pool.vertical_slice.projectile_signature()
		assert_eq(
			StringName(projectile_signature.particle_signature),
			expected_signature,
			boss_id
		)
		var pool_snapshot: Dictionary = (
			session.utility_pool.attack_particle_pool.signature_snapshot()
		)
		assert_gt(int(pool_snapshot.telegraphs), 0, boss_id)
		assert_eq(StringName(pool_snapshot.boss_id), boss_id, boss_id)
		assert_eq(
			StringName(pool_snapshot.signature), expected_signature, boss_id
		)
		session.stop()
		city.encounter_runtime.release_all()
