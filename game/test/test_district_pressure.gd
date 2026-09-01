extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const DISTRICT: DistrictDefinition = preload("res://resources/siege/district_contact.tres")

var city: CitySlice
var director: DistrictResponseDirector
var hazards: HazardRuntime
var pressure: HazardPressureController


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	director = city.urban_siege.director
	director.stop()
	hazards = city.urban_siege.hazards
	hazards.release_all()
	pressure = city.urban_siege.hazard_pressure


func test_catalog_matches_exact_monotonic_five_district_curve() -> void:
	assert_eq(DistrictPressureCatalog.validation_errors(), PackedStringArray())
	var profiles: Array[DistrictPressureProfile] = DistrictPressureCatalog.profiles()
	assert_eq(profiles.size(), 5)
	var expected: Array[Array] = [
		[&"BUSINESS", 0, 8, 1.00, 1.00, 0, 0, 0],
		[&"RESIDENTIAL", 1, 11, 0.96, 1.00, 0, 1, 0],
		[&"ENTERTAINMENT", 2, 14, 0.92, 0.96, 1, 2, 1],
		[&"MILITARY", 3, 17, 0.88, 0.92, 1, 3, 1],
		[&"ROYAL", 4, 20, 0.84, 0.88, 2, 4, 2],
	]
	for index: int in range(profiles.size()):
		var profile: DistrictPressureProfile = profiles[index]
		var row: Array = expected[index]
		assert_eq(profile.district_id, row[0])
		assert_eq(profile.threat_allowance, row[1])
		assert_eq(profile.live_threat_ceiling, row[2])
		assert_almost_eq(profile.cadence_scale, row[3], 0.0001)
		assert_almost_eq(profile.recovery_scale, row[4], 0.0001)
		assert_eq(profile.elite_bonus, row[5])
		assert_eq(profile.hazard_pressure_bonus, row[6])
		assert_eq(profile.hazard_event_bonus, row[7])


func test_five_district_by_six_act_matrix_is_deterministic_and_bounded() -> void:
	for profile: DistrictPressureProfile in DistrictPressureCatalog.profiles():
		city.world_stream.current_district_id = profile.district_id
		city.world_stream.current_logical_chunk = (
			profile.district_index * CityDistrictCatalog.CHUNKS_PER_DISTRICT
		)
		for act_index: int in range(DISTRICT.acts.size()):
			var act: DistrictAct = DISTRICT.acts[act_index]
			for beat_index: int in range(act.beats.size()):
				var beat: DistrictBeat = act.beats[beat_index]
				director.beat_index = beat_index - 1
				var first: Dictionary[int, int] = director._progression_copy_plan(
					beat,
					profile
				)
				var replay: Dictionary[int, int] = director._progression_copy_plan(
					beat,
					profile
				)
				assert_eq(first, replay, "%s act=%d beat=%d" % [
					profile.district_id, act_index, beat_index,
				])
				var authored_threat: int = _beat_threat(beat)
				var extra_threat: int = _extra_threat(beat, first)
				assert_lte(extra_threat, profile.threat_allowance)
				assert_lte(authored_threat + extra_threat, DistrictPressureCatalog.MAX_LIVE_THREAT)
				if authored_threat < profile.live_threat_ceiling:
					assert_lte(authored_threat + extra_threat, profile.live_threat_ceiling)
				else:
					assert_true(first.is_empty())
				pressure.configure(7100 + act_index * 100 + beat_index, 1)
				var first_hazards: Array[Dictionary] = pressure.plan_for_beat(
					act_index,
					beat_index,
					act,
					beat,
					760.0,
					profile
				)
				var first_budget: int = pressure.last_used_budget
				pressure.configure(7100 + act_index * 100 + beat_index, 1)
				var replay_hazards: Array[Dictionary] = pressure.plan_for_beat(
					act_index,
					beat_index,
					act,
					beat,
					760.0,
					profile
				)
				assert_eq(first_hazards, replay_hazards)
				assert_lte(first_budget, mini(
					RuntimeBudget.HAZARD_PRESSURE,
					act.hazard_pressure_budget + profile.hazard_pressure_bonus
				))
				assert_lte(replay_hazards.size(), RuntimeBudget.PENDING_HAZARDS)
				_assert_hazard_windows_spaced(replay_hazards)


func test_enemy_copy_planner_prefers_cheap_units_and_respects_live_saturation() -> void:
	var beat: DistrictBeat = DistrictBeat.new()
	beat.beat_id = &"PRESSURE_TEST"
	beat.spawns = [
		_spawn_entry("goliath"),
		_spawn_entry("soldier"),
		_spawn_entry("needle"),
	]
	city.world_stream.current_logical_chunk = 48
	var royal: DistrictPressureProfile = DistrictPressureCatalog.profile_by_index(4)
	var plan: Dictionary[int, int] = director._progression_copy_plan(beat, royal)
	assert_false(plan.has(0))
	assert_true(plan.has(1))
	assert_true(plan.has(2))
	assert_lte(_extra_threat(beat, plan), royal.threat_allowance)
	assert_not_null(city.encounter_runtime.acquire(&"leviathan", Vector2(1200.0, 505.0)))
	assert_not_null(city.encounter_runtime.acquire(&"goliath", Vector2(1320.0, 485.0)))
	assert_eq(director._threat_weight(), 19)
	assert_true(director._progression_copy_plan(beat, royal).is_empty())


func test_pressure_profile_uses_authored_district_for_started_beat() -> void:
	city.world_stream.current_district_id = &"ROYAL"
	city.world_stream.current_logical_chunk = 48
	director.running = true
	director.completed = false
	director.phase_index = 0
	director.beat_index = -1
	director.state = DistrictResponseDirector.STATE_WAITING
	director._try_start_next_beat()
	assert_eq(director.current_pressure_profile.district_id, &"ROYAL")
	director._beat_pending.clear()
	director.ledger.cancel_all()


func test_business_variant_trace_is_final_before_reservation_and_pending_spawns() -> void:
	city.world_stream.current_district_id = &"BUSINESS"
	city.world_stream.current_logical_chunk = 0
	director.running = true
	director.completed = false
	director.phase_index = 0
	director.beat_index = -1
	director.state = DistrictResponseDirector.STATE_WAITING
	director._elite_seed = 913
	director.hybrid_substitution_trace.clear()
	director.district_variant_substitution_trace.clear()
	director._try_start_next_beat()
	assert_true(director.hybrid_substitution_trace.is_empty())
	assert_gt(director.district_variant_substitution_trace.size(), 0)
	var traced_ids: Dictionary[StringName, bool] = {}
	for change: Dictionary in director.district_variant_substitution_trace:
		assert_eq(StringName(change.district_id), &"BUSINESS")
		assert_true(EnemyArchetypeCatalog.is_district_variant(change.after))
		traced_ids[StringName(change.after)] = true
	var pending_variant_count: int = 0
	for record: Dictionary in director._beat_pending:
		var entry: EnemySpawnEntry = record.entry as EnemySpawnEntry
		var kind: StringName = StringName(entry.kind)
		if EnemyArchetypeCatalog.is_district_variant(kind):
			pending_variant_count += 1
			assert_true(traced_ids.has(kind), kind)
	assert_gt(pending_variant_count, 0)
	assert_gt(director._beat_reservation_id, 0)
	director._beat_pending.clear()
	director.ledger.cancel_all()


func test_absolute_threat_saturation_delays_and_then_releases_the_next_beat() -> void:
	city.world_stream.current_district_id = &"ROYAL"
	city.world_stream.current_logical_chunk = 48
	director.running = true
	director.completed = false
	director.phase_index = 5
	director.beat_index = 1
	director.state = DistrictResponseDirector.STATE_WAITING
	assert_not_null(city.encounter_runtime.acquire(&"soldier", Vector2(1180.0, 542.5)))
	director._try_start_next_beat()
	assert_eq(director.beat_index, 1)
	assert_eq(director.pending_count(), 0)
	city.encounter_runtime.release_all()
	director._try_start_next_beat()
	assert_eq(director.current_beat_id(), &"COMMAND_TEST")
	assert_lte(
		director.progression_peak_threat,
		EnemySpawnTuning.scaled_threat(DistrictPressureCatalog.MAX_LIVE_THREAT)
	)
	director._beat_pending.clear()
	director.ledger.cancel_all()


func test_hazard_runtime_refuses_duplicate_and_seventh_live_hazard_without_recycle() -> void:
	for index: int in range(RuntimeBudget.ACTIVE_HAZARDS):
		assert_not_null(hazards.activate(
			EnvironmentalHazardCatalog.ACTIVE_IDS[index],
			Vector2(760.0 + float(index) * 40.0, CitySlice.LAND_VISUAL_BASELINE_Y),
			1,
			false
		))
	assert_eq(hazards.active_count(), RuntimeBudget.ACTIVE_HAZARDS)
	assert_null(hazards.activate(
		EnvironmentalHazardCatalog.ACTIVE_IDS[RuntimeBudget.ACTIVE_HAZARDS],
		Vector2(1100.0, CitySlice.LAND_VISUAL_BASELINE_Y),
		1,
		false
	))
	assert_null(hazards.activate(
		EnvironmentalHazardCatalog.ACTIVE_IDS[0],
		Vector2(1140.0, CitySlice.LAND_VISUAL_BASELINE_Y),
		1,
		false
	))
	assert_eq(hazards.active_count(), RuntimeBudget.ACTIVE_HAZARDS)
	assert_eq(hazards.activation_denial_count, 2)
	assert_eq(hazards.recycle_count, 0)
	assert_eq(hazards.post_warm_creation_count, 0)


func _spawn_entry(kind: String) -> EnemySpawnEntry:
	var entry: EnemySpawnEntry = EnemySpawnEntry.new()
	entry.kind = kind
	entry.spawn_anchor = "AHEAD"
	return entry


func _beat_threat(beat: DistrictBeat) -> int:
	var total: int = 0
	for entry: EnemySpawnEntry in beat.spawns:
		var kind: StringName = StringName(entry.kind)
		total += (
			EnemyArchetypeCatalog.threat_cost(kind)
			* EnemyArchetypeCatalog.spawn_multiplier(kind)
		)
	return total


func _extra_threat(beat: DistrictBeat, plan: Dictionary[int, int]) -> int:
	var total: int = 0
	for entry_index: int in plan:
		total += (
			EnemyArchetypeCatalog.threat_cost(
				StringName(beat.spawns[entry_index].kind)
			)
			* int(plan[entry_index])
		)
	return total


func _assert_hazard_windows_spaced(plan: Array[Dictionary]) -> void:
	var windows: Array[float] = []
	for record: Dictionary in plan:
		var delay: float = float(record.remaining)
		if not windows.has(delay):
			windows.append(delay)
	windows.sort()
	for index: int in range(1, windows.size()):
		assert_gte(
			windows[index] - windows[index - 1],
			HazardPressureController.MINIMUM_EVENT_SPACING - 0.0001
		)
