extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const DISTRICT: DistrictDefinition = preload("res://resources/siege/district_contact.tres")

var city: CitySlice
var runtime: EncounterRuntime
var transmission_ids: Array[StringName] = []


func before_each() -> void:
	transmission_ids.clear()
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	runtime = city.encounter_runtime
	city.urban_siege.stop_run()
	runtime.release_all()


func test_hybrid_profiles_reconfigure_existing_family_shells() -> void:
	var pairs: Array[Array] = [
		[&"bulwark", &"reclaimed_breacher"],
		[&"jackal", &"graft_runner"],
	]
	for pair: Array in pairs:
		var baseline: ProceduralEnemy = runtime.acquire(
			pair[0] as StringName,
			Vector2(1200.0, 400.0)
		) as ProceduralEnemy
		assert_not_null(baseline)
		var shell_id: int = baseline.get_instance_id()
		runtime.release(baseline)
		var hybrid: ProceduralEnemy = runtime.acquire(
			pair[1] as StringName,
			Vector2(1200.0, 400.0)
		) as ProceduralEnemy
		assert_not_null(hybrid)
		assert_eq(hybrid.get_instance_id(), shell_id, pair[1])
		runtime.release(hybrid)
	assert_eq(runtime.post_warm_creation_count, 0)


func test_spatial_resolver_is_deterministic_and_never_mutates_authored_entries() -> void:
	var base: DistrictBeat = _family_beat()
	var original: Array[StringName] = _kinds(base)
	var districts: Array[StringName] = [
		&"BUSINESS", &"RESIDENTIAL",
	]
	var expected_eligible: Array[Array] = [
		[],
		[&"reclaimed_breacher", &"graft_runner"],
	]
	for index: int in range(districts.size()):
		var first: DistrictBeat = HybridEncounterResolver.resolve_beat(
			base, districts[index], 2, 1, 913
		)
		var replay: DistrictBeat = HybridEncounterResolver.resolve_beat(
			base, districts[index], 2, 1, 913
		)
		assert_eq(_kinds(first), _kinds(replay), districts[index])
		assert_eq(
			HybridEncounterResolver.eligible_hybrids(districts[index]),
			expected_eligible[index]
		)
		if districts[index] == &"BUSINESS":
			assert_ne(first, base)
			for change: Dictionary in HybridEncounterResolver.substitutions(base, first):
				assert_false(bool(change.get("hybrid_applied", false)))
		else:
			assert_gt(HybridEncounterResolver.substitutions(base, first).size(), 0)
	assert_eq(_kinds(base), original)


func test_two_act_campaign_exposes_residential_hybrid_roster() -> void:
	for district_id: StringName in [&"RESIDENTIAL"]:
		var seen: Dictionary[StringName, bool] = {}
		for act_index: int in range(DISTRICT.acts.size()):
			var act: DistrictAct = DISTRICT.acts[act_index]
			for beat_index: int in range(act.beats.size()):
				var base: DistrictBeat = act.beats[beat_index]
				var resolution: Dictionary = HybridEncounterResolver.resolve_with_trace(
					base, district_id, act_index, beat_index, 913
				)
				for change: Dictionary in resolution.substitutions:
					if bool(change.hybrid_applied):
						seen[StringName(change.hybrid_after)] = true
		for hybrid_id: StringName in HybridEncounterResolver.eligible_hybrids(district_id):
			assert_true(seen.has(hybrid_id), "%s/%s" % [district_id, hybrid_id])


func test_two_act_campaign_exposes_retained_district_variant_rosters() -> void:
	for district_id: StringName in [&"BUSINESS", &"RESIDENTIAL"]:
		var seen: Dictionary[StringName, bool] = {}
		for run_seed: int in range(900, 940):
			for act_index: int in range(DISTRICT.acts.size()):
				var act: DistrictAct = DISTRICT.acts[act_index]
				for beat_index: int in range(act.beats.size()):
					var resolution: Dictionary = HybridEncounterResolver.resolve_with_trace(
						act.beats[beat_index], district_id, act_index, beat_index, run_seed
					)
					for change: Dictionary in resolution.substitutions:
						if bool(change.variant_applied):
							seen[StringName(change.after)] = true
		assert_gt(seen.size(), 0, district_id)
		var available: Array[StringName] = EnemyArchetypeCatalog.variants_for_district(
			district_id
		)
		for variant_id: StringName in seen:
			assert_true(available.has(variant_id), "%s/%s" % [district_id, variant_id])


func test_final_variant_resolution_preserves_family_threat_and_staged_trace() -> void:
	var base: DistrictBeat = _family_beat()
	for district_id: StringName in [
		&"BUSINESS", &"RESIDENTIAL",
	]:
		var resolution: Dictionary = HybridEncounterResolver.resolve_with_trace(
			base, district_id, 3, 2, 2026
		)
		var resolved: DistrictBeat = resolution.beat as DistrictBeat
		assert_ne(resolved, base)
		assert_eq(resolved.spawns.size(), base.spawns.size(), district_id)
		var total_threat: int = 0
		for entry_index: int in range(resolved.spawns.size()):
			var before: StringName = StringName(base.spawns[entry_index].kind)
			var after: StringName = StringName(resolved.spawns[entry_index].kind)
			assert_eq(
				EnemyArchetypeCatalog.family_for(after),
				EnemyArchetypeCatalog.family_for(before),
				district_id
			)
			total_threat += (
				EnemyArchetypeCatalog.threat_cost(after)
				* EnemyArchetypeCatalog.spawn_multiplier(after)
			)
		assert_lte(total_threat, base.maximum_threat, district_id)
		for change: Dictionary in resolution.substitutions:
			assert_true(bool(change.hybrid_applied) or bool(change.variant_applied))
			if bool(change.variant_applied):
				assert_true(EnemyArchetypeCatalog.is_district_variant(change.after))
				assert_eq(
					EnemyArchetypeCatalog.district_for_variant(change.after),
					district_id
				)


func test_breacher_frontal_brace_reduces_frontal_jab_damage() -> void:
	city.robot.global_position = Vector2(800.0, 600.0)
	var breacher: ProceduralEnemy = runtime.acquire(
		&"reclaimed_breacher", Vector2(1100.0, 540.0)
	) as ProceduralEnemy
	assert_eq(breacher.facing, -1)
	assert_true(breacher.receive_damage(DamageEvent.new(
		90_001, city.robot, 100.0, &"jab_cross", breacher.global_position, Vector2.RIGHT
	)))
	assert_almost_eq(breacher.current_health, 380.0, 0.01)
	assert_true(breacher.receive_damage(DamageEvent.new(
		90_002, city.robot, 100.0, &"ground_smash", breacher.global_position, Vector2.RIGHT
	)))
	assert_almost_eq(breacher.current_health, 280.0, 0.01)
	runtime.release(breacher)


func test_hybrid_first_contact_transmission_fires_once_per_run() -> void:
	city.project_choir_runtime.director.transmission_requested.connect(
		_capture_transmission
	)
	var first: ProceduralEnemy = runtime.acquire(
		&"reclaimed_breacher", Vector2(1100.0, 540.0)
	) as ProceduralEnemy
	runtime.release(first)
	var second: ProceduralEnemy = runtime.acquire(
		&"reclaimed_breacher", Vector2(1100.0, 540.0)
	) as ProceduralEnemy
	runtime.release(second)
	assert_eq(transmission_ids.count(&"hybrid_reclaimed_breacher_contact"), 1)


func test_variant_support_reuses_exact_repair_and_mark_values() -> void:
	var repair_target: ProceduralEnemy = runtime.acquire(
		&"jackal", Vector2(1080.0, 554.0)
	) as ProceduralEnemy
	repair_target.current_health = repair_target.max_health - 40.0
	var shepherd: ProceduralEnemy = runtime.acquire(
		&"intake_shepherd", Vector2(1040.0, 541.0)
	) as ProceduralEnemy
	shepherd._repair_nearest_ally()
	assert_almost_eq(
		repair_target.current_health,
		repair_target.max_health - 18.0,
		0.01
	)
	runtime.release_all()
	var testament: ProceduralEnemy = runtime.acquire(
		&"testament_kite", Vector2(1100.0, 175.0)
	) as ProceduralEnemy
	assert_true(testament._complete_support_attack())
	assert_almost_eq(runtime.target_mark_remaining, ProceduralEnemy.MARK_DURATION, 0.01)
	runtime.release_all()


func _capture_transmission(
	event_id: StringName,
	_speaker: String,
	_line: String,
	_duration: float,
	_priority: int
) -> void:
	transmission_ids.append(event_id)


func _family_beat() -> DistrictBeat:
	var beat: DistrictBeat = DistrictBeat.new()
	beat.beat_id = &"HYBRID_TEST"
	beat.maximum_threat = 20
	for kind: StringName in [&"bulwark", &"jackal", &"needle", &"lobber"]:
		var entry: EnemySpawnEntry = EnemySpawnEntry.new()
		entry.kind = String(kind)
		beat.spawns.append(entry)
	return beat


func _kinds(beat: DistrictBeat) -> Array[StringName]:
	var result: Array[StringName] = []
	for entry: EnemySpawnEntry in beat.spawns:
		result.append(StringName(entry.kind))
	return result
