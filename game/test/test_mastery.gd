extends GutTest


func test_pending_premium_banks_after_density_scaled_delay() -> void:
	var score: RunScore = RunScore.new()
	add_child_autofree(score)
	var event: GameplayEvent = GameplayEvent.new(
		&"premium", 1, GameplayEvent.Kind.PROP_DESTROYED, &"PROP", 100, 0.0, true
	)
	assert_eq(score.apply_event(event, 4), 400)
	assert_eq(score.safe_score, 100)
	assert_eq(score.pending_bank.value, 300)
	assert_eq(score.score, 400)
	assert_eq(score.advance(PendingScoreBank.BANK_DELAY - 0.01), 0)
	assert_eq(score.advance(0.01), 300)
	assert_eq(score.safe_score, 400)
	assert_eq(score.pending_bank.value, 0)


func test_damage_breaks_kill_combo_and_heavy_hit_discards_half_pending() -> void:
	var session: RampageSession = RampageSession.new()
	add_child_autofree(session)
	for index: int in range(4):
		session.publish(GameplayEvent.new(
			StringName("action_%d" % index),
			10 + index,
			GameplayEvent.Kind.ENEMY_DEFEATED,
			StringName("TAG_%d" % index),
			100,
			0.0,
			true
		))
	var pending_before: int = session.run_score.pending_bank.value
	assert_eq(session.current_multiplier(), 4)
	session.publish(GameplayEvent.new(
		&"damage", 98, GameplayEvent.Kind.PLAYER_DAMAGE_TAKEN
	))
	assert_eq(session.current_multiplier(), 1)
	assert_eq(session.combo_tracker.current_chain_count, 0)
	assert_eq(session.run_score.pending_bank.value, pending_before)
	session.publish(GameplayEvent.new(
		&"heavy", 99, GameplayEvent.Kind.PLAYER_HEAVY_HIT, &"PLAYER_HIT"
	))
	assert_eq(session.run_score.safe_score, 400)
	assert_eq(
		session.run_score.pending_bank.value,
		pending_before - floori(float(pending_before) / 2.0)
	)
	assert_eq(session.current_multiplier(), 1)
	assert_eq(session.combo_tracker.current_chain_count, 0)
	assert_eq(session.heavy_hit_count, 1)


func test_causal_tracker_rejects_duplicates_and_out_of_order_links() -> void:
	var tracker: CausalChainTracker = CausalChainTracker.new()
	var root: GameplayEvent = GameplayEvent.new(&"root", 500)
	root.root_attack_id = 500
	assert_true(tracker.register(root))
	var out_of_order: GameplayEvent = GameplayEvent.new(&"depth2", 501)
	out_of_order.root_attack_id = 500
	out_of_order.causal_depth = 2
	assert_false(tracker.register(out_of_order))
	var link: GameplayEvent = GameplayEvent.new(&"depth1", 502)
	link.root_attack_id = 500
	link.causal_depth = 1
	assert_true(tracker.register(link))
	assert_false(tracker.register(link))
	assert_eq(tracker.best_depth, 1)
	assert_eq(tracker.rejected_count, 2)
	tracker.advance(CausalChainTracker.RECORD_LIFETIME)
	assert_eq(tracker.active_count(), 0)


func test_causal_tracker_never_exceeds_fixed_record_budget() -> void:
	var tracker: CausalChainTracker = CausalChainTracker.new()
	for index: int in range(CausalChainTracker.MAX_RECORDS + 8):
		var event: GameplayEvent = GameplayEvent.new(StringName("root_%d" % index), index + 1)
		event.root_attack_id = index + 1
		tracker.register(event)
	assert_eq(tracker.active_count(), CausalChainTracker.MAX_RECORDS)


func test_mastery_grade_boundaries_and_failed_cap() -> void:
	assert_eq(MasteryEvaluator.grade_for(90, true), &"S")
	assert_eq(MasteryEvaluator.grade_for(89, true), &"A")
	assert_eq(MasteryEvaluator.grade_for(75, true), &"A")
	assert_eq(MasteryEvaluator.grade_for(60, true), &"B")
	assert_eq(MasteryEvaluator.grade_for(40, true), &"C")
	assert_eq(MasteryEvaluator.grade_for(39, true), &"D")
	assert_eq(MasteryEvaluator.grade_for(100, false), &"C")


func test_summary_freezes_expanded_metrics_against_late_events() -> void:
	var session: RampageSession = RampageSession.new()
	add_child_autofree(session)
	for index: int in range(5):
		session.publish(GameplayEvent.new(
			StringName("variety_%d" % index), index + 1,
			GameplayEvent.Kind.PROP_DESTROYED, StringName("TAG_%d" % index),
			100, 0.0, true
		))
	var summary: RunSummarySnapshot = session.freeze_summary(2, 2, {
		"completed": true,
		"contract_succeeded": true,
		"directive_path": &"SKYBREAKER",
		"boss_result": &"WRECK_RESOLVED",
		"contract_result": &"COMPLETE",
		"run_seed": 77,
		"cycle_count": 1,
	})
	var frozen_score: int = summary.score
	session.publish(GameplayEvent.new(
		&"late", 88, GameplayEvent.Kind.ENEMY_DEFEATED, &"LATE", 9999, 0.0, true
	))
	assert_eq(summary.score, frozen_score)
	assert_eq(summary.grade, &"A")
	assert_eq(summary.directive_path, &"SKYBREAKER")
	assert_eq(summary.boss_result, &"WRECK_RESOLVED")
	assert_eq(summary.run_seed, 77)
	assert_eq(summary.cycle_count, 1)
