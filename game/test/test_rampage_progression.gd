extends GutTest

const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"


func test_event_hub_deduplicates_and_keeps_scene_local_ids() -> void:
	var hub: GameplayEventHub = GameplayEventHub.new()
	add_child_autofree(hub)
	var first: GameplayEvent = _event(&"shared")
	var repeated: GameplayEvent = _event(&"shared")
	var unkeyed: GameplayEvent = _event()
	assert_true(hub.accept(first))
	assert_eq(first.event_id, 1)
	assert_false(hub.accept(repeated))
	assert_eq(repeated.event_id, 0)
	assert_true(hub.accept(unkeyed))
	assert_eq(unkeyed.event_id, 2)
	hub.reset_run()
	var next_run: GameplayEvent = _event(&"shared")
	assert_true(hub.accept(next_run))
	assert_eq(next_run.event_id, 3)
	_record_test_execution()


func test_consecutive_kills_apply_the_growing_multiplier_immediately() -> void:
	var session: RampageSession = _session()
	assert_true(session.publish(_kill(&"kill_1", 100)))
	assert_eq(session.current_score(), 100)
	assert_eq(session.current_multiplier(), 1)
	assert_true(session.publish(_kill(&"kill_2", 100)))
	assert_eq(session.current_score(), 300)
	assert_eq(session.current_multiplier(), 2)
	assert_true(session.publish(_kill(&"kill_3", 100)))
	assert_eq(session.current_score(), 600)
	assert_eq(session.current_multiplier(), 3)
	assert_true(session.publish(_kill(&"kill_4", 100)))
	assert_eq(session.current_score(), 1000)
	assert_eq(session.current_multiplier(), 4)
	_record_test_execution()


func test_combo_herald_milestones_emit_once_across_capped_progression() -> void:
	var combo: ComboTracker = ComboTracker.new()
	add_child_autofree(combo)
	var tiers: Array[int] = []
	var chains: Array[int] = []
	var multipliers: Array[int] = []
	combo.milestone_reached.connect(
		func(tier: int, chain_count: int, multiplier: int) -> void:
			tiers.append(tier)
			chains.append(chain_count)
			multipliers.append(multiplier)
	)
	for index: int in range(12):
		assert_true(combo.register_event(_kill(StringName("herald_%d" % index), 0)))
	assert_eq(tiers, [2, 3, 4, 5, 7, 10])
	assert_eq(chains, [2, 3, 4, 5, 7, 10])
	assert_eq(multipliers, [2, 3, 4, 5, 5, 5])
	assert_eq(tiers.count(10), 1)
	_record_test_execution()


func test_combo_herald_catalog_preloads_every_generated_tier() -> void:
	assert_eq(ComboHeraldCatalog.milestone_counts(), [2, 3, 4, 5, 7, 10])
	for tier: int in ComboHeraldCatalog.milestone_counts():
		var profile: Dictionary = ComboHeraldCatalog.profile_for(tier)
		assert_false(profile.is_empty())
		assert_true(profile[&"texture"] is Texture2D)
		assert_true(profile[&"voice"] is AudioStream)
		assert_true(String(profile[&"title_key"]).begins_with("hud.combo_herald."))
		assert_gt(float(profile[&"intensity"]), 0.0)
	assert_true(ComboHeraldCatalog.profile_for(6).is_empty())
	_record_test_execution()


func test_doubled_regular_enemy_pairs_preserve_authored_score_and_combo_curve() -> void:
	var session: RampageSession = _session()
	var adapter: RampageEventAdapter = RampageEventAdapter.new(session)
	var robot: GiantRobotController = GiantRobotController.new()
	var enemy: EnemyActor2D = EnemyActor2D.new()
	add_child_autofree(robot)
	add_child_autofree(enemy)
	var expected_scores: Array[int] = [100, 300, 600, 1000]
	for authored_slot: int in range(expected_scores.size()):
		for copy_index: int in range(EnemySpawnTuning.QUANTITY_MULTIPLIER):
			enemy.activation_generation += 1
			assert_true(adapter.enemy_defeated(
				enemy,
				DamageEvent.new(
					10_000 + enemy.activation_generation,
					robot,
					999.0,
					&"density_test"
				),
				100,
				robot
			))
		assert_eq(session.current_score(), expected_scores[authored_slot])
		assert_eq(session.current_multiplier(), authored_slot + 1)
	assert_eq(session.run_score.safe_score, 400)
	assert_eq(session.run_score.pending_bank.value, 600)
	assert_eq(session.combo_tracker.current_chain_count, 8)
	assert_eq(session.combo_tracker.current_progress_units, 8)
	_record_test_execution()


func test_singular_named_boss_triples_score_and_keeps_one_combo_step() -> void:
	var session: RampageSession = _session()
	var adapter: RampageEventAdapter = RampageEventAdapter.new(session)
	var robot: GiantRobotController = GiantRobotController.new()
	var boss: EnemyActor2D = EnemyActor2D.new()
	boss.boss_mode = true
	add_child_autofree(robot)
	add_child_autofree(boss)
	assert_true(adapter.enemy_defeated(
		boss,
		DamageEvent.new(20_001, robot, 999.0, &"boss_density_test"),
		1000,
		robot
	))
	assert_eq(session.current_score(), 3000)
	assert_eq(
		session.combo_tracker.current_progress_units,
		RampageRewardTuning.COMBO_PROGRESS_UNITS_PER_TIER
	)
	assert_eq(session.current_multiplier(), 1)
	_record_test_execution()


func test_nonkill_score_ignores_active_kill_multiplier() -> void:
	var session: RampageSession = _session()
	session.publish(_kill(&"kill_1", 10))
	session.publish(_kill(&"kill_2", 10))
	assert_eq(session.current_multiplier(), 2)
	assert_true(session.publish(_event(&"prop", &"PROP", 75, 0.0, true)))
	assert_eq(session.current_score(), 105)
	assert_eq(session.current_multiplier(), 2)
	assert_true(session.publish(_event(&"zero", &"", 0, 0.0, false)))
	assert_eq(session.current_score(), 105)
	_record_test_execution()


func test_combo_grace_scales_to_exactly_half_the_authored_window() -> void:
	var combo: ComboTracker = ComboTracker.new()
	add_child_autofree(combo)
	assert_true(combo.register_event(_kill(&"kill_1", 0)))
	assert_almost_eq(
		combo.grace_remaining,
		RampageRewardTuning.BASE_COMBO_GRACE_SECONDS
		* EnemySpawnTuning.INTERVAL_SCALE,
		0.0001
	)
	combo.advance(ComboTracker.GRACE_SECONDS - 0.001)
	assert_eq(combo.current_chain_count, 1)
	assert_gt(combo.grace_remaining, 0.0)
	combo.advance(0.001)
	assert_eq(combo.grace_remaining, 0.0)
	assert_eq(combo.current_chain_count, 0)
	assert_eq(combo.current_multiplier, 1)
	assert_eq(combo.best_chain_count, 1)
	_record_test_execution()


func test_kill_combo_caps_at_five_and_tracks_the_complete_streak() -> void:
	var combo: ComboTracker = ComboTracker.new()
	add_child_autofree(combo)
	for index: int in range(7):
		assert_true(combo.register_event(_kill(StringName("kill_%d" % index), 0)))
		assert_eq(combo.current_multiplier, mini(index + 1, 5))
	assert_eq(combo.peak_multiplier, 5)
	assert_eq(combo.best_chain_count, 7)
	_record_test_execution()


func test_any_damage_breaks_kill_combo_but_only_heavy_hits_penalize_score() -> void:
	var session: RampageSession = _session()
	for index: int in range(3):
		session.publish(_kill(StringName("kill_%d" % index), 100))
	var pending_before: int = session.run_score.pending_bank.value
	assert_eq(session.current_multiplier(), 3)
	assert_true(session.publish(GameplayEvent.new(
		&"damage",
		99,
		GameplayEvent.Kind.PLAYER_DAMAGE_TAKEN
	)))
	assert_eq(session.current_multiplier(), 1)
	assert_eq(session.combo_tracker.current_chain_count, 0)
	assert_eq(session.run_score.pending_bank.value, pending_before)
	assert_eq(session.heavy_hit_count, 0)
	assert_true(session.publish(GameplayEvent.new(
		&"heavy",
		100,
		GameplayEvent.Kind.PLAYER_HEAVY_HIT
	)))
	assert_lt(session.run_score.pending_bank.value, pending_before)
	assert_eq(session.heavy_hit_count, 1)
	_record_test_execution()


func test_momentum_motion_thresholds_and_idle_grace() -> void:
	var meter: MomentumMeter = MomentumMeter.new()
	add_child_autofree(meter)
	meter.apply_event(_event(&"seed", &"", 0, 50.0))
	meter.advance_motion(0.699, 1.0)
	assert_eq(meter.value, 50.0)
	meter.advance_motion(0.700, 1.0)
	assert_eq(meter.value, 62.0)
	meter.advance_motion(0.199, 0.999)
	assert_eq(meter.value, 62.0)
	meter.advance_motion(0.199, 0.001)
	assert_eq(meter.value, 62.0)
	meter.advance_motion(0.199, 0.1)
	assert_almost_eq(meter.value, 61.0, 0.0001)
	meter.advance_motion(0.200, 1.0)
	assert_almost_eq(meter.value, 61.0, 0.0001)
	meter.advance_motion(0.199, 1.0)
	assert_almost_eq(meter.value, 61.0, 0.0001)
	_record_test_execution()


func test_momentum_applies_generic_discrete_values() -> void:
	var session: RampageSession = _session()
	var deltas: Array[float] = [5.0, 10.0, 15.0, 20.0, -10.0, -5.0]
	var expected: float = 0.0
	for index: int in range(deltas.size()):
		var delta: float = deltas[index]
		expected = clampf(expected + delta, 0.0, 100.0)
		assert_true(session.publish(_event(StringName("m%d" % index), &"", 0, delta)))
		assert_almost_eq(session.momentum_value(), expected, 0.0001)
	assert_false(session.publish(_event(&"m0", &"", 0, 99.0)))
	assert_almost_eq(session.momentum_value(), expected, 0.0001)
	_record_test_execution()


func test_ready_momentum_locks_gain_decay_and_event_loss() -> void:
	var meter: MomentumMeter = MomentumMeter.new()
	add_child_autofree(meter)
	meter.apply_event(_event(&"ready", &"", 0, 100.0))
	assert_true(meter.is_ready())
	assert_eq(meter.band(), MomentumMeter.Band.READY)
	meter.apply_event(_event(&"loss", &"", 0, -100.0))
	meter.advance_motion(0.0, 5.0)
	meter.advance_motion(1.0, 5.0)
	assert_eq(meter.value, 100.0)
	assert_true(meter.is_ready())
	_record_test_execution()


func test_session_reset_clears_all_run_state() -> void:
	var session: RampageSession = _session()
	var event: GameplayEvent = _kill(&"run-key", 100, 40.0)
	assert_true(session.publish(event))
	assert_gt(session.current_score(), 0)
	assert_gt(session.momentum_value(), 0.0)
	assert_gt(session.combo_tracker.current_chain_count, 0)
	session.reset_run()
	assert_eq(session.current_score(), 0)
	assert_eq(session.current_multiplier(), 1)
	assert_eq(session.momentum_value(), 0.0)
	assert_eq(session.combo_tracker.current_chain_count, 0)
	assert_eq(session.combo_tracker.peak_multiplier, 1)
	assert_eq(session.combo_tracker.best_chain_count, 0)
	var next_event: GameplayEvent = _event(&"run-key")
	assert_true(session.publish(next_event))
	assert_eq(next_event.event_id, event.event_id + 1)
	_record_test_execution()


func _session() -> RampageSession:
	var session: RampageSession = RampageSession.new()
	add_child_autofree(session)
	return session


func _event(
	dedupe_key: StringName = &"",
	action_tag: StringName = &"",
	base_points: int = 0,
	momentum_delta: float = 0.0,
	qualifies_for_combo: bool = false
) -> GameplayEvent:
	return GameplayEvent.new(
		dedupe_key,
		0,
		GameplayEvent.Kind.DAMAGE_APPLIED,
		action_tag,
		base_points,
		momentum_delta,
		qualifies_for_combo
	)


func _kill(
	dedupe_key: StringName,
	base_points: int,
	momentum_delta: float = 0.0
) -> GameplayEvent:
	return GameplayEvent.new(
		dedupe_key,
		0,
		GameplayEvent.Kind.ENEMY_DEFEATED,
		GameplayEvent.ENEMY_KILL,
		base_points,
		momentum_delta,
		true
	)


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
