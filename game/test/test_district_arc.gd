extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const DISTRICT: DistrictDefinition = preload("res://resources/siege/district_contact.tres")

var city: CitySlice


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()


func test_six_act_resource_matches_target_arc_and_duration() -> void:
	assert_eq(DISTRICT.acts.size(), 6)
	var beat_counts: Array[int] = []
	var target_duration: float = 0.0
	for act: DistrictAct in DISTRICT.acts:
		beat_counts.append(act.beats.size())
		target_duration += act.target_duration
	assert_eq(beat_counts, [4, 4, 5, 5, 5, 5])
	assert_between(target_duration, 360.0, 480.0)


func test_accelerated_arc_visits_every_act_and_completes() -> void:
	var director: DistrictResponseDirector = city.urban_siege.director
	var visited: Array[String] = []
	director.phase_changed.connect(
		func(_index: int, display_name: String) -> void: visited.append(display_name)
	)
	director.start()
	var guard: int = 0
	while not director.completed and guard < 600:
		director.advance(1.0)
		_resolve_directive_if_active()
		city.encounter_runtime.release_all()
		guard += 1
	assert_true(director.completed)
	assert_eq(visited, [
		"encounter.contact",
		"encounter.containment",
		"encounter.escalation",
		"encounter.command_response",
		"encounter.retaliation",
		"encounter.command_test",
	])
	assert_lte(director.elapsed, 600.0)


func test_hud_progress_strip_has_six_fixed_segments() -> void:
	var strip: SiegeProgressStrip = city.gameplay_hud.siege_progress
	assert_not_null(strip)
	assert_eq(strip.segments.size(), 6)
	city.gameplay_hud.set_siege_progress(3, 6, "encounter.command_response", true)
	assert_eq(strip.current_index, 3)
	assert_true(strip.recovery_active)
	assert_string_contains(strip.label.text, L10n.t("objective.act", {
		"current": 4,
		"total": 6,
		"name": "",
	}).strip_edges())
	assert_string_contains(strip.label.text, L10n.t("siege.recovery"))


func test_bounded_overrun_advances_with_surviving_low_threat() -> void:
	var director: DistrictResponseDirector = city.urban_siege.director
	director.start()
	director.beat_index = DISTRICT.acts[0].beats.size() - 1
	director.state = DistrictResponseDirector.STATE_WAITING
	director.act_elapsed = DISTRICT.acts[0].target_duration
	city.encounter_runtime.acquire(&"soldier", Vector2(1200.0, 542.5))
	director.advance(0.1)
	assert_eq(director.phase_index, 1)
	assert_eq(city.encounter_runtime.active_count(&"soldier"), 1)


func test_retaliation_triggers_every_wave_25_percent_sooner() -> void:
	var director: DistrictResponseDirector = city.urban_siege.director
	var retaliation: DistrictAct = DISTRICT.acts[4]
	var expected_beats: Array[StringName] = [
		&"RETALIATION_FRONT",
		&"RETALIATION_REAR",
		&"RETALIATION_AIR",
		&"RETALIATION_SQUEEZE",
		&"RETALIATION_PEAK",
	]
	var baseline_pressure: Array[float] = [12.0, 13.0, 13.0, 14.0, 15.0]
	assert_almost_eq(
		DistrictResponseDirector.RETALIATION_TRIGGER_SCALE,
		0.75,
		0.0001
	)
	assert_almost_eq(
		director._scaled_target_duration(retaliation),
		retaliation.target_duration * 0.75 * EnemySpawnTuning.INTERVAL_SCALE,
		0.0001
	)
	director.stop()
	director.running = true
	director.completed = false
	director.phase_index = 4
	director.beat_index = -1
	director.state = DistrictResponseDirector.STATE_WAITING
	director.act_elapsed = 0.0
	for beat_index: int in range(retaliation.beats.size()):
		director._try_start_next_beat()
		assert_eq(director.current_beat_id(), expected_beats[beat_index])
		assert_almost_eq(
			director.pressure_remaining,
			baseline_pressure[beat_index] * 0.75 * EnemySpawnTuning.INTERVAL_SCALE,
			0.0001
		)
		assert_almost_eq(
			director.recovery_remaining,
			retaliation.beats[beat_index].recovery_seconds
			* 0.75
			* EnemySpawnTuning.INTERVAL_SCALE,
			0.0001
		)
		assert_gt(director.pending_count(), 0)
		director._beat_pending.clear()
		director.ledger.cancel(director._beat_reservation_id)
		director._beat_reservation_id = 0
		director.state = DistrictResponseDirector.STATE_WAITING


func test_act_five_releases_overrun_survivors_and_starts_max_tier_retaliation() -> void:
	var director: DistrictResponseDirector = city.urban_siege.director
	city.world_stream.current_logical_chunk = 48
	city.world_stream.current_district_id = &"ROYAL"
	city.world_stream.maximum_visited_chunk = 48
	director.stop()
	director.running = true
	director.completed = false
	director.phase_index = 3
	director.beat_index = DISTRICT.acts[3].beats.size() - 1
	director.state = DistrictResponseDirector.STATE_WAITING
	director.act_elapsed = (
		DISTRICT.acts[3].target_duration
		+ DistrictResponseDirector.MAXIMUM_ACT_OVERRUN
	)
	assert_not_null(city.encounter_runtime.acquire(&"goliath", Vector2(1200.0, 485.0)))
	assert_gt(director._threat_weight(), DistrictResponseDirector.LOW_THREAT_WEIGHT)
	director.advance(0.1)
	assert_eq(director.phase_index, 4)
	assert_eq(city.encounter_runtime.active_count(), 0)
	director.advance(0.1)
	assert_eq(director.current_beat_id(), &"RETALIATION_FRONT")
	assert_eq(director.current_pressure_profile.district_id, &"ROYAL")
	assert_gt(director.pending_count(), 0)
	assert_eq(director.pending_count(), director.ledger.pending_count())
	assert_eq(director.ledger.denial_count, 0)


func test_late_elite_affixes_are_seeded_replayable_and_never_mutate_authored_entries() -> void:
	var first_trace: Array[Dictionary] = _elite_trace(73)
	var replay_trace: Array[Dictionary] = _elite_trace(73)
	var alternate_trace: Array[Dictionary] = _elite_trace(74)
	assert_eq(first_trace, replay_trace)
	assert_ne(first_trace, alternate_trace)
	assert_eq(first_trace.size(), 20)
	for assignment: Dictionary in first_trace:
		assert_gte(int(assignment.act_index), 3)
		assert_true(
			StringName(assignment.trait_id) in DistrictResponseDirector.ELITE_AFFIXES
		)
		if int(assignment.act_index) == 3:
			assert_ne(StringName(assignment.trait_id), &"PHASED")
	var authored_elites: int = 0
	for act: DistrictAct in DISTRICT.acts:
		for beat: DistrictBeat in act.beats:
			for entry: EnemySpawnEntry in beat.spawns:
				authored_elites += 1 if not entry.trait_id.is_empty() else 0
	assert_eq(authored_elites, 3)
	assert_true(DISTRICT.acts[3].chaos_enabled)
	assert_gt(DISTRICT.acts[4].mirrored_flank_chance, DISTRICT.acts[3].mirrored_flank_chance)
	assert_eq(DISTRICT.acts[5].elite_units_per_beat, 2)


func test_final_chaos_gauntlet_doubles_humans_and_staggers_the_swarm() -> void:
	var director: DistrictResponseDirector = city.urban_siege.director
	director.stop()
	director.configure_elite_affixes(913, 1)
	director.running = true
	director.completed = false
	director.phase_index = 5
	director.beat_index = 2
	director.state = DistrictResponseDirector.STATE_WAITING
	director.act_elapsed = 0.0
	director._try_start_next_beat()
	assert_eq(director.current_beat_id(), &"COMMAND_GAUNTLET")
	assert_eq(director.pending_count(), 12)
	assert_eq(director.ledger.pending_count(&"lobber"), 8)
	var delays: Dictionary[float, bool] = {}
	var infantry_offsets: int = 0
	for record: Dictionary in director._beat_pending:
		delays[float(record.remaining)] = true
		if EnemyArchetypeCatalog.is_human_enemy(StringName(record.entry.kind)):
			infantry_offsets += 1 if (record.offset as Vector2).x != 0.0 else 0
	assert_gt(delays.size(), 1)
	assert_eq(infantry_offsets, 6)


func _elite_trace(p_seed: int) -> Array[Dictionary]:
	var director: DistrictResponseDirector = city.urban_siege.director
	director.stop()
	city.encounter_runtime.release_all()
	director.configure_elite_affixes(p_seed, 1)
	director.start()
	var guard: int = 0
	while not director.completed and guard < 600:
		director.advance(1.0)
		_resolve_directive_if_active()
		city.encounter_runtime.release_all()
		guard += 1
	assert_true(director.completed)
	return director.elite_assignments.duplicate(true)


func _resolve_directive_if_active() -> void:
	if (
		city.urban_siege.pause_coordinator.is_paused()
		and not city.urban_siege.directives.is_active()
	):
		var choices: Array[DirectiveProfile] = DistrictMissionCatalog.choices_for(
			&"BUSINESS",
			city.urban_siege.run_seed,
			city.urban_siege.cycle_count
		)
		if not choices.is_empty():
			city.urban_siege.directives.select(choices[0])
