extends GutTest

const PROFILE_PATH: String = "user://runtime_tweak_tests/integrity-profile.json"


func before_each() -> void:
	_cleanup_profile()


func after_each() -> void:
	_cleanup_profile()


func test_tuning_provenance_survives_career_enrichment() -> void:
	var summary: RunSummarySnapshot = _make_summary().with_tuning_provenance({
		"status": &"TUNED",
		"ranked_eligible": false,
		"configuration_hash": "abcdef0123456789",
		"catalog_revision": "test-catalog",
		"reasons": PackedStringArray(["spawn.quantity_multiplier"]),
	})
	var enriched: RunSummarySnapshot = summary.with_career_result({
		"new_combo_record": false,
		"new_score_record": false,
		"career_snapshot": {"total_runs": 9},
	})
	assert_eq(enriched.tuning_status, &"TUNED")
	assert_false(enriched.tuning_ranked_eligible)
	assert_eq(enriched.tuning_configuration_hash, "abcdef0123456789")
	assert_eq(enriched.tuning_catalog_revision, "test-catalog")
	assert_eq(enriched.tuning_reasons, PackedStringArray(["spawn.quantity_multiplier"]))


func test_tuned_summary_cannot_mutate_career_profile_or_make_candidate() -> void:
	var store: PlayerCombatProfileStore = PlayerCombatProfileStore.new()
	add_child_autofree(store)
	store.setup(PROFILE_PATH)
	var before: Dictionary = store.snapshot()
	var tuned: RunSummarySnapshot = _make_summary().with_tuning_provenance({
		"status": &"TUNED",
		"ranked_eligible": false,
		"configuration_hash": "tuned-hash",
		"catalog_revision": "test-catalog",
	})
	var result: RunSummarySnapshot = store.enrich_and_submit(tuned)
	assert_eq(store.snapshot(), before)
	assert_eq(result.career_snapshot, before)
	assert_false(result.new_combo_record)
	assert_false(result.new_score_record)
	assert_eq(store.leaderboard_candidate(result, "test"), {})
	assert_false(FileAccess.file_exists(PROFILE_PATH))


func test_baseline_summary_retains_existing_profile_and_candidate_behavior() -> void:
	var store: PlayerCombatProfileStore = PlayerCombatProfileStore.new()
	add_child_autofree(store)
	store.setup(PROFILE_PATH)
	var result: RunSummarySnapshot = store.enrich_and_submit(_make_summary())
	assert_eq(int(store.snapshot().total_runs), 1)
	assert_eq(int(store.snapshot().best_score), result.score)
	assert_false(store.leaderboard_candidate(result, "test").is_empty())
	assert_true(FileAccess.file_exists(PROFILE_PATH))


func test_leaderboard_bridge_blocks_unranked_summary_before_environment_branch() -> void:
	var store: PlayerCombatProfileStore = PlayerCombatProfileStore.new()
	add_child_autofree(store)
	store.setup(PROFILE_PATH)
	var bridge: LeaderboardBridge = LeaderboardBridge.new()
	add_child_autofree(bridge)
	bridge.setup(store, null)
	var tuned: RunSummarySnapshot = _make_summary().with_tuning_provenance({
		"status": &"SANDBOX",
		"ranked_eligible": false,
		"configuration_hash": "sandbox-hash",
	})
	bridge.submit_summary(tuned)
	assert_eq(bridge.state, &"unranked")
	assert_true(bridge.last_submission_blocked)
	assert_eq(int(bridge.debug_snapshot().request_counter), 0)


func test_debrief_omits_tuning_provenance_annotation() -> void:
	var panel: MatchDebriefPanel = MatchDebriefPanel.new()
	add_child_autofree(panel)
	await get_tree().process_frame
	var tuned: RunSummarySnapshot = _make_summary().with_tuning_provenance({
		"status": &"TUNED",
		"ranked_eligible": false,
		"configuration_hash": "0123456789abcdef",
		"catalog_revision": "test-catalog",
		"reasons": PackedStringArray(["enemy.outgoing_damage_multiplier"]),
	})
	panel.present(tuned, "MISSION COMPLETE")
	assert_null(panel.content_root.get_node_or_null("RunMeta"))


func _make_summary() -> RunSummarySnapshot:
	return RunSummarySnapshot.new(
		4200,
		4,
		8,
		3,
		1,
		{},
		{
			"grade": &"A",
			"mastery_points": 10,
			"completed": true,
			"highest_combo_tier": 3,
			"total_enemies_defeated": 12,
			"enemy_kills": {&"soldier": 12},
			"weapon_kills": {&"GROUND_SMASH": 12},
			"preferred_weapon": &"GROUND_SMASH",
			"preferred_weapon_kills": 12,
		}
	)


func _cleanup_profile() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path: String = PROFILE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
