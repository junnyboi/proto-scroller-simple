extends GutTest

const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"
const TEST_PROFILE_PATH: String = "user://test_player_combat_profile.json"
const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func before_each() -> void:
	_clear_profile_files()


func after_each() -> void:
	_clear_profile_files()


func test_enemy_defeats_track_concrete_type_family_and_fatal_weapon() -> void:
	var session: RampageSession = _session()
	var adapter: RampageEventAdapter = RampageEventAdapter.new(session)
	var robot: GiantRobotController = GiantRobotController.new()
	var enemy: EnemyActor2D = EnemyActor2D.new()
	add_child_autofree(robot)
	add_child_autofree(enemy)
	enemy.set_meta(&"enemy_archetype", &"covenant_warden")
	enemy.set_meta(&"enemy_family", &"infantry")
	var damage_types: Array[StringName] = [
		&"ground_smash", &"jab_cross", &"machine_gun", &"missile",
		&"laser", &"flamethrower", &"chain_collapse", &"strange_ray",
	]
	var expected_weapons: Array[StringName] = [
		&"GROUND_SMASH", &"JAB_CROSS", &"MACHINE_GUN", &"MISSILE",
		&"LASER", &"FLAMETHROWER", &"ENVIRONMENT", &"UNKNOWN",
	]
	for index: int in range(damage_types.size()):
		enemy.activation_generation += 1
		assert_true(adapter.enemy_defeated(
			enemy,
			DamageEvent.new(9000 + index, robot, 100.0, damage_types[index]),
			100,
			robot
		))
	var telemetry: Dictionary = session.combat_telemetry.snapshot()
	assert_eq(telemetry.total_enemies_defeated, damage_types.size())
	assert_eq(telemetry.unique_enemy_types, 1)
	assert_eq(int(telemetry.enemy_kills[&"covenant_warden"]), damage_types.size())
	assert_eq(int(telemetry.enemy_family_kills[&"infantry"]), damage_types.size())
	for weapon_id: StringName in expected_weapons:
		assert_eq(int(telemetry.weapon_kills[weapon_id]), 1, String(weapon_id))
	assert_eq(telemetry.preferred_weapon, &"GROUND_SMASH")
	_record_test_execution()


func test_skill_flags_attribute_drill_and_crucible_kills_separately() -> void:
	var session: RampageSession = _session()
	var adapter: RampageEventAdapter = RampageEventAdapter.new(session)
	var robot: GiantRobotController = GiantRobotController.new()
	var enemy: EnemyActor2D = EnemyActor2D.new()
	add_child_autofree(robot)
	add_child_autofree(enemy)
	enemy.set_meta(&"enemy_archetype", &"covenant_warden")
	enemy.set_meta(&"enemy_family", &"infantry")
	var fatal_events: Array[DamageEvent] = [
		DamageEvent.new(
			9100,
			robot,
			100.0,
			&"jab_cross",
			Vector2.ZERO,
			Vector2.RIGHT,
			0.0,
			9100,
			0,
			DamageEvent.FLAG_SIEGE_DRILL
		),
		DamageEvent.new(
			9101,
			robot,
			100.0,
			&"debris_impact",
			Vector2.ZERO,
			Vector2.RIGHT,
			0.0,
			9101,
			1,
			DamageEvent.FLAG_GRAVITY_CRUCIBLE
		),
	]
	for fatal_event: DamageEvent in fatal_events:
		enemy.activation_generation += 1
		assert_true(adapter.enemy_defeated(enemy, fatal_event, 100, robot))
	var telemetry: Dictionary = session.combat_telemetry.snapshot()
	assert_eq(int(telemetry.weapon_kills.get(&"SIEGE_DRILL", 0)), 1)
	assert_eq(int(telemetry.weapon_kills.get(&"GRAVITY_CRUCIBLE", 0)), 1)
	assert_eq(int(telemetry.weapon_kills.get(&"JAB_CROSS", 0)), 0)
	assert_eq(int(telemetry.weapon_kills.get(&"ENVIRONMENT", 0)), 0)
	assert_eq(
		CombatRunTelemetry.weapon_id_for_damage_event(null),
		CombatRunTelemetry.UNKNOWN_WEAPON
	)
	_record_test_execution()


func test_highest_authored_combo_tier_survives_multiplier_cap_and_freezes() -> void:
	var session: RampageSession = _session()
	for index: int in range(23):
		var event: GameplayEvent = _kill_event(index, &"needle", &"air", &"MISSILE")
		event.combo_progress_units = 1
		assert_true(session.publish(event))
	assert_eq(session.current_multiplier(), RampageRewardTuning.MAX_MULTIPLIER)
	assert_eq(session.combat_telemetry.highest_combo_tier, 12)
	var summary: RunSummarySnapshot = session.freeze_summary(2, 2, {"completed": true})
	assert_eq(summary.highest_combo_tier, 12)
	assert_eq(summary.total_enemies_defeated, 23)
	assert_eq(summary.unique_enemy_types, 1)
	var exposed_counts: Dictionary = summary.enemy_kills
	exposed_counts[&"needle"] = 9999
	assert_eq(int(summary.enemy_kills[&"needle"]), 23)
	assert_true(session.publish(_kill_event(99, &"reclaimed_breacher", &"infantry", &"LASER")))
	assert_eq(summary.total_enemies_defeated, 23)
	assert_false(summary.enemy_kills.has(&"reclaimed_breacher"))
	_record_test_execution()


func test_ranked_entries_use_count_then_stable_id() -> void:
	var ranked: Array[Dictionary] = CombatRunTelemetry.ranked_entries({
		&"missile": 3,
		&"alpha": 5,
		&"zeta": 5,
		&"laser": 1,
	}, 3)
	assert_eq(ranked.size(), 3)
	assert_eq(ranked[0].id, &"alpha")
	assert_eq(ranked[1].id, &"zeta")
	assert_eq(ranked[2].id, &"missile")
	_record_test_execution()


func test_profile_persists_records_merges_totals_and_marks_personal_bests() -> void:
	var store: PlayerCombatProfileStore = PlayerCombatProfileStore.new()
	add_child_autofree(store)
	store.setup(TEST_PROFILE_PATH)
	var first: RunSummarySnapshot = _make_summary(7200, 10, true, {
		&"needle": 4,
		&"needle": 2,
	}, {
		&"MISSILE": 5,
		&"JAB_CROSS": 1,
	})
	var enriched_first: RunSummarySnapshot = store.enrich_and_submit(first)
	assert_true(enriched_first.new_score_record)
	assert_true(enriched_first.new_combo_record)
	assert_eq(int(enriched_first.career_snapshot.total_runs), 1)
	assert_eq(int(enriched_first.career_snapshot.victories), 1)
	assert_eq(int(enriched_first.career_snapshot.total_enemy_kills), 6)

	var reloaded: PlayerCombatProfileStore = PlayerCombatProfileStore.new()
	add_child_autofree(reloaded)
	reloaded.setup(TEST_PROFILE_PATH)
	var persisted: Dictionary = reloaded.snapshot()
	assert_eq(int(persisted.best_score), 7200)
	assert_eq(int(persisted.highest_combo_tier), 10)
	assert_eq(int(persisted.lifetime_enemy_kills.needle), 4)
	assert_eq(int(persisted.lifetime_weapon_kills.MISSILE), 5)
	var second: RunSummarySnapshot = _make_summary(3000, 4, false, {
		&"needle": 1,
	}, {
		&"JAB_CROSS": 1,
	})
	var enriched_second: RunSummarySnapshot = reloaded.enrich_and_submit(second)
	assert_false(enriched_second.new_score_record)
	assert_false(enriched_second.new_combo_record)
	assert_eq(int(enriched_second.career_snapshot.total_runs), 2)
	assert_eq(int(enriched_second.career_snapshot.victories), 1)
	assert_eq(int(enriched_second.career_snapshot.total_enemy_kills), 7)
	assert_eq(int(enriched_second.career_snapshot.lifetime_enemy_kills.needle), 5)
	assert_eq((enriched_second.career_snapshot.run_history as Array).size(), 2)
	assert_eq(String(enriched_second.career_snapshot.preferred_weapon), "MISSILE")
	_record_test_execution()


func test_schema_v1_profile_migrates_without_losing_records() -> void:
	var legacy_id: String = "0123456789abcdef0123456789abcdef"
	var file: FileAccess = FileAccess.open(TEST_PROFILE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"schema_version": 1,
		"anonymous_profile_id": legacy_id,
		"total_runs": 12,
		"victories": 3,
		"best_score": 44_000,
		"highest_combo_tier": 17,
		"total_enemy_kills": 901,
		"lifetime_enemy_kills": {"needle": 8},
		"lifetime_weapon_kills": {"LASER": 21},
		"updated_unix_time": 42,
	}))
	file.close()
	var store: PlayerCombatProfileStore = PlayerCombatProfileStore.new()
	add_child_autofree(store)
	store.setup(TEST_PROFILE_PATH)
	var migrated: Dictionary = store.snapshot()
	assert_eq(int(migrated.schema_version), 2)
	assert_eq(String(migrated.anonymous_profile_id), legacy_id)
	assert_eq(String(migrated.callsign), "OBELISK-CDEF")
	assert_eq(int(migrated.total_runs), 12)
	assert_eq(int(migrated.best_score), 44_000)
	assert_eq(int(migrated.highest_combo_tier), 17)
	assert_eq(int(migrated.lifetime_weapon_kills.LASER), 21)
	assert_eq((migrated.run_history as Array).size(), 0)
	_record_test_execution()


func test_callsign_history_and_local_ranking_are_bounded_and_deterministic() -> void:
	var store: PlayerCombatProfileStore = PlayerCombatProfileStore.new()
	add_child_autofree(store)
	store.setup(TEST_PROFILE_PATH)
	assert_eq(store.validate_callsign("  Echo   Seven  "), &"ok")
	assert_eq(store.set_callsign("  Echo   Seven  "), &"ok")
	assert_eq(store.callsign(), "Echo Seven")
	assert_eq(store.set_callsign("<script>"), &"invalid_characters")
	assert_eq(store.set_callsign("x"), &"too_short")
	assert_eq(store.set_callsign("N4Z1"), &"inappropriate")
	assert_eq(store.set_callsign("f_u_c_k"), &"inappropriate")
	assert_eq(store.callsign(), "Echo Seven")
	assert_eq(store.validate_callsign("Passage-7"), &"ok")
	for index: int in range(32):
		var tier: int = 25 if index == 4 else index % 11
		var score: int = 1000 + index * 100
		store.enrich_and_submit(_make_summary(
			score,
			tier,
			index % 3 == 0,
			{&"soldier": index + 1},
			{&"MISSILE": index + 1, &"LASER": 32 - index}
		))
	var history: Array[Dictionary] = store.history_snapshot()
	assert_eq(history.size(), PlayerCombatProfileStore.MAX_HISTORY_ENTRIES)
	assert_eq(int(history[0].run_number), 3)
	assert_eq(int(history[-1].run_number), 32)
	var board: Array[Dictionary] = store.local_leaderboard(5)
	assert_eq(board.size(), 5)
	assert_eq(int(board[0].highest_combo_tier), 25)
	assert_eq(int(board[0].rank), 1)
	assert_eq(String(board[0].callsign), "Echo Seven")
	assert_eq(store.chart_history(12).size(), 12)
	var reloaded: PlayerCombatProfileStore = PlayerCombatProfileStore.new()
	add_child_autofree(reloaded)
	reloaded.setup(TEST_PROFILE_PATH)
	assert_eq(reloaded.callsign(), "Echo Seven")
	assert_eq(reloaded.history_snapshot().size(), PlayerCombatProfileStore.MAX_HISTORY_ENTRIES)
	_record_test_execution()


func test_leaderboard_candidate_is_versioned_and_privacy_minimal() -> void:
	var store: PlayerCombatProfileStore = PlayerCombatProfileStore.new()
	add_child_autofree(store)
	store.setup(TEST_PROFILE_PATH)
	var summary: RunSummarySnapshot = store.enrich_and_submit(_make_summary(
		8100,
		7,
		true,
		{&"covenant_warden": 3},
		{&"GROUND_SMASH": 3}
	))
	var payload: Dictionary = store.leaderboard_candidate(summary, "revision-test")
	assert_eq(int(payload.schema_version), PlayerCombatProfileStore.SCHEMA_VERSION)
	assert_eq(String(payload.build_revision), "revision-test")
	assert_eq(String(payload.career.preferred_weapon), "GROUND_SMASH")
	assert_eq(int(payload.career.best_score), 8100)
	assert_eq(int(payload.career.highest_combo_tier), 7)
	assert_true(String(payload.anonymous_profile_id).length() >= 16)
	assert_false(payload.has("run"))
	assert_false((payload.career as Dictionary).has("enemy_kills"))
	assert_false((payload.career as Dictionary).has("weapon_kills"))
	var serialized: String = JSON.stringify(payload)
	for forbidden: String in [
		"dossier", "campaign", "input_binding", "audio_settings", "user://", "hardware",
		"run_history",
		]:
		assert_false(serialized.to_lower().contains(forbidden), forbidden)
	_record_test_execution()


func test_malformed_profile_falls_back_without_blocking_launch() -> void:
	var file: FileAccess = FileAccess.open(TEST_PROFILE_PATH, FileAccess.WRITE)
	file.store_string("{ not valid profile json")
	file.close()
	var store: PlayerCombatProfileStore = PlayerCombatProfileStore.new()
	add_child_autofree(store)
	store.setup(TEST_PROFILE_PATH)
	var profile: Dictionary = store.snapshot()
	assert_eq(int(profile.schema_version), PlayerCombatProfileStore.SCHEMA_VERSION)
	assert_eq(int(profile.total_runs), 0)
	assert_eq(int(profile.best_score), 0)
	assert_false(String(profile.anonymous_profile_id).is_empty())
	_record_test_execution()


func test_debrief_presents_bounded_rankings_and_both_responsive_layouts() -> void:
	L10n.set_locale("en")
	var panel: MatchDebriefPanel = MatchDebriefPanel.new()
	add_child_autofree(panel)
	await get_tree().process_frame
	var summary: RunSummarySnapshot = _make_summary(
		12_345,
		10,
		true,
		{
			&"needle": 8,
			&"reclaimed_breacher": 6,
			&"covenant_warden": 5,
			&"needle": 4,
			&"tank": 3,
		},
		{
			&"SIEGE_DRILL": 9,
			&"GRAVITY_CRUCIBLE": 8,
			&"MISSILE": 5,
			&"GROUND_SMASH": 4,
		}
	).with_career_result({
		"new_combo_record": true,
		"new_score_record": true,
		"career_snapshot": {
			"best_score": 12_345,
			"highest_combo_tier": 10,
			"total_enemy_kills": 99,
			"total_runs": 7,
			"victories": 4,
		},
	})
	panel.present(summary, "DISTRICT CLEARED", 25, 2)
	var state: Dictionary = panel.debug_snapshot()
	assert_true(state.visible)
	assert_true(String(state.combo).contains("EXTINCTION EVENT"))
	assert_true(state.personal_best)
	assert_eq(String(state.killed_by), "")
	assert_false(panel.killer_label.visible)
	assert_eq((state.weapon_rows as PackedStringArray).size(), 3)
	assert_true(panel.weapon_preferred_label.text.contains("SIEGE DRILL"))
	var weapon_rows_text: String = "\n".join(state.weapon_rows as PackedStringArray)
	assert_true(weapon_rows_text.contains("SIEGE DRILL"))
	assert_true(weapon_rows_text.contains("GRAVITY CRUCIBLE"))
	assert_eq((state.enemy_rows as PackedStringArray).size(), 4)
	assert_true(panel.crest.texture is Texture2D)

	panel.apply_responsive_layout(Vector2(1280.0, 720.0))
	var landscape_state: Dictionary = panel.debug_snapshot()
	_assert_rect_inside(landscape_state.panel_rect, Vector2(1280.0, 720.0))
	_assert_touch_rect(landscape_state.retry_rect)
	_assert_touch_rect(landscape_state.title_rect)
	_assert_action_group_margins(panel, landscape_state)
	_assert_after_action_header_bottom_padding(panel, 100.0, 58.0)
	panel.apply_responsive_layout(Vector2(720.0, 1280.0))
	var portrait_state: Dictionary = panel.debug_snapshot()
	_assert_rect_inside(portrait_state.panel_rect, Vector2(720.0, 1280.0))
	_assert_touch_rect(portrait_state.retry_rect)
	_assert_touch_rect(portrait_state.title_rect)
	_assert_action_group_margins(panel, portrait_state)
	_assert_after_action_header_bottom_padding(panel, 160.0, 70.0)
	var signal_counts: Dictionary = {"retry": 0, "title": 0}
	panel.retry_pressed.connect(func() -> void: signal_counts.retry += 1)
	panel.title_pressed.connect(func() -> void: signal_counts.title += 1)
	panel.retry_button.pressed.emit()
	panel.title_button.pressed.emit()
	assert_eq(int(signal_counts.retry), 1)
	assert_eq(int(signal_counts.title), 1)
	_record_test_execution()


func test_game_over_debrief_names_the_fatal_enemy_in_both_layouts() -> void:
	L10n.set_locale("en")
	var panel: MatchDebriefPanel = MatchDebriefPanel.new()
	add_child_autofree(panel)
	await get_tree().process_frame
	var summary: RunSummarySnapshot = _make_summary(
		35_700,
		3,
		false,
		{&"covenant_warden": 17},
		{&"ENVIRONMENT": 9},
		&"covenant_warden"
	)
	panel.present(summary, "GAME OVER", 2, 1)
	assert_eq(
		String(panel.debug_snapshot().killed_by),
		"KILLED BY 'COVENANT WARDEN'"
	)
	assert_true(panel.killer_label.visible)
	panel.apply_responsive_layout(Vector2(1280.0, 720.0))
	assert_almost_eq(
		panel.killer_label.position.y,
		panel.result_label.position.y,
		0.01
	)
	assert_gt(
		panel.killer_label.position.x,
		panel.result_label.position.x
	)
	assert_lte(
		panel.killer_label.position.x + panel.killer_label.size.x,
		panel.grade_label.position.x
	)
	assert_lte(
		panel.killer_label.position.y + panel.killer_label.size.y,
		panel.run_meta_label.position.y
	)
	panel.apply_responsive_layout(Vector2(720.0, 1280.0))
	assert_almost_eq(
		panel.killer_label.position.y,
		panel.result_label.position.y,
		0.01
	)
	assert_gt(
		panel.killer_label.position.x,
		panel.result_label.position.x
	)
	assert_lte(
		panel.killer_label.position.y + panel.killer_label.size.y,
		panel.run_meta_label.position.y
	)
	panel.set_page(MatchDebriefPanel.Page.CAREER)
	assert_false(panel.killer_label.visible)
	panel.set_page(MatchDebriefPanel.Page.AFTER_ACTION)
	assert_true(panel.killer_label.visible)
	_record_test_execution()


func test_fatal_damage_source_resolution_survives_summary_enrichment() -> void:
	var robot: GiantRobotController = GiantRobotController.new()
	var enemy: EnemyActor2D = EnemyActor2D.new()
	var attack_child: Node2D = Node2D.new()
	add_child_autofree(robot)
	add_child_autofree(enemy)
	enemy.add_child(attack_child)
	enemy.set_meta(&"enemy_archetype", &"covenant_warden")
	var fatal_event: DamageEvent = DamageEvent.new(
		18_001,
		attack_child,
		robot.max_health + 1.0
	)
	assert_true(robot.receive_damage(fatal_event))
	assert_eq(
		DefeatSourceResolver.resolve(fatal_event),
		&"covenant_warden"
	)
	assert_eq(
		DefeatSourceResolver.resolve(DamageEvent.new(
			18_002,
			null,
			1.0,
			&"hazard",
			Vector2.ZERO,
			Vector2.RIGHT,
			0.0,
			0,
			0,
			DamageEvent.FLAG_HAZARD
		)),
		DefeatSourceResolver.ENVIRONMENT
	)
	assert_eq(
		DefeatSourceResolver.resolve(DamageEvent.new(18_003, null, 1.0)),
		DefeatSourceResolver.UNKNOWN
	)
	var summary: RunSummarySnapshot = _make_summary(
		100,
		1,
		false,
		{},
		{},
		&"covenant_warden"
	)
	summary = summary.with_tuning_provenance({"status": &"BASELINE"})
	summary = summary.with_career_result({"career_snapshot": {"total_runs": 1}})
	assert_eq(summary.defeat_source_id, &"covenant_warden")
	_record_test_execution()


func test_career_profile_chart_and_global_tabs_are_interactive() -> void:
	L10n.set_locale("en")
	var store: PlayerCombatProfileStore = PlayerCombatProfileStore.new()
	add_child_autofree(store)
	store.setup(TEST_PROFILE_PATH)
	store.set_callsign("Echo Seven")
	var latest: RunSummarySnapshot
	for index: int in range(4):
		latest = store.enrich_and_submit(_make_summary(
			4000 + index * 1200,
			3 + index,
			index % 2 == 0,
			{&"soldier": 4 + index},
			{&"MISSILE": 2 + index, &"LASER": 5 - index, &"GROUND_SMASH": index + 1}
		))
	var panel: MatchDebriefPanel = MatchDebriefPanel.new()
	add_child_autofree(panel)
	await get_tree().process_frame
	panel.configure_profile(store)
	panel.present(latest, "DISTRICT CLEARED", 25, 2)
	panel.set_page(MatchDebriefPanel.Page.CAREER)
	var career_state: Dictionary = panel.debug_snapshot()
	assert_eq(String(career_state.page), "CAREER")
	assert_eq(String(career_state.callsign), "Echo Seven")
	assert_eq(int((career_state.chart as Dictionary).history_size), 4)
	assert_eq((career_state.local_rows as PackedStringArray).size(), 4)
	panel.chart_share_button.pressed.emit()
	assert_eq(String(panel.weapon_history_chart.debug_snapshot().mode), "SHARE")
	panel.weapon_history_chart.select_index(0)
	assert_eq(int(panel.weapon_history_chart.debug_snapshot().selected_index), 0)
	var signal_state: Dictionary = {"callsign": "", "count": 0}
	panel.callsign_saved.connect(func(value: String) -> void:
		signal_state.callsign = value
		signal_state.count += 1
	)
	panel.callsign_edit.text = "Rook-7"
	panel.callsign_save_button.pressed.emit()
	assert_eq(store.callsign(), "Rook-7")
	assert_eq(String(signal_state.callsign), "Rook-7")
	assert_eq(int(signal_state.count), 1)
	panel.set_global_state(&"online", [{
		"rank": 1,
		"callsign": "Rook-7",
		"highest_combo_tier": 19,
		"best_score": 88_000,
		"preferred_weapon": "MISSILE",
	}], {"rank": 1, "callsign": "Rook-7"})
	panel.set_page(MatchDebriefPanel.Page.GLOBAL)
	var global_state: Dictionary = panel.debug_snapshot()
	assert_eq(String(global_state.page), "GLOBAL")
	assert_eq(String(global_state.global_state), "online")
	assert_eq(String(global_state.global_callsign), "Rook-7")
	assert_eq((global_state.global_rows as PackedStringArray).size(), 1)
	assert_true(String((global_state.global_rows as PackedStringArray)[0]).contains("Rook-7"))
	assert_eq(global_state.highlighted_global_rows, PackedInt32Array([0]))
	panel.global_callsign_edit.text = "x"
	panel.global_callsign_save_button.pressed.emit()
	assert_eq(store.callsign(), "Rook-7")
	assert_eq(int(signal_state.count), 1)
	assert_eq(
		String(panel.debug_snapshot().global_callsign_status),
		L10n.t("debrief.callsign.too_short")
	)
	panel.global_callsign_edit.text = "f_u_c_k"
	panel.global_callsign_save_button.pressed.emit()
	assert_eq(store.callsign(), "Rook-7")
	assert_eq(int(signal_state.count), 1)
	assert_eq(
		String(panel.debug_snapshot().global_callsign_status),
		L10n.t("debrief.callsign.inappropriate")
	)
	panel.global_callsign_edit.text = "Nova Prime"
	panel.global_callsign_save_button.pressed.emit()
	global_state = panel.debug_snapshot()
	assert_eq(store.callsign(), "Nova Prime")
	assert_eq(String(signal_state.callsign), "Nova Prime")
	assert_eq(int(signal_state.count), 2)
	assert_eq(String(global_state.callsign), "Nova Prime")
	assert_eq(String(global_state.global_callsign), "Nova Prime")
	assert_eq(
		String(global_state.global_callsign_status),
		L10n.t("debrief.callsign.saved")
	)
	assert_true(String((global_state.global_rows as PackedStringArray)[0]).contains("Nova Prime"))
	assert_true(panel.personal_rank_label.text.contains("Nova Prime"))
	assert_eq(global_state.highlighted_global_rows, PackedInt32Array([0]))
	panel.apply_responsive_layout(Vector2(1280.0, 720.0))
	var global_landscape_state: Dictionary = panel.debug_snapshot()
	_assert_rect_inside(global_landscape_state.global_callsign_rect, Vector2(1280.0, 720.0))
	_assert_touch_rect(global_landscape_state.global_callsign_save_rect)
	_assert_global_layout(panel)
	panel.apply_responsive_layout(Vector2(720.0, 1280.0))
	var global_portrait_state: Dictionary = panel.debug_snapshot()
	_assert_rect_inside(global_portrait_state.panel_rect, Vector2(720.0, 1280.0))
	_assert_rect_inside(global_portrait_state.global_callsign_rect, Vector2(720.0, 1280.0))
	_assert_touch_rect(global_portrait_state.global_callsign_save_rect)
	_assert_touch_rect(global_portrait_state.refresh_rect)
	_assert_global_layout(panel)
	_record_test_execution()


func test_chinese_career_chart_draws_with_complete_cjk_font() -> void:
	L10n.set_locale("zh-CN")
	var panel: MatchDebriefPanel = MatchDebriefPanel.new()
	add_child_autofree(panel)
	await get_tree().process_frame
	var chart: CareerWeaponHistoryChart = panel.weapon_history_chart
	assert_true(chart.has_theme_font_override(&"font"))
	var drawing_font: Font = chart._drawing_font()
	assert_same(drawing_font, chart.get_theme_font(&"font"))
	var chart_copy: String = L10n.t("debrief.history.empty")
	chart_copy += L10n.t("debrief.history.tooltip", {
		"run": 12,
		"score": "00065269",
		"tier": 3,
		"weapon": L10n.t("debrief.weapon.missile"),
	})
	for weapon_id: String in [
		"ground_smash", "jab_cross", "siege_drill", "gravity_crucible",
		"machine_gun", "missile", "laser", "flamethrower", "tesla_tower",
		"environment", "unknown",
	]:
		chart_copy += L10n.t("debrief.weapon.%s" % weapon_id)
	var missing_codepoints: PackedInt32Array = []
	for index: int in range(chart_copy.length()):
		var codepoint: int = chart_copy.unicode_at(index)
		if codepoint > 127 and not drawing_font.has_char(codepoint):
			missing_codepoints.append(codepoint)
	assert_eq(missing_codepoints, PackedInt32Array())
	L10n.set_locale("en")
	_record_test_execution()


func test_async_global_rows_stay_hidden_on_after_action_page() -> void:
	L10n.set_locale("en")
	var panel: MatchDebriefPanel = MatchDebriefPanel.new()
	add_child_autofree(panel)
	await get_tree().process_frame
	var summary: RunSummarySnapshot = _make_summary(
		35_700,
		3,
		false,
		{&"covenant_warden": 17},
		{&"ENVIRONMENT": 9, &"FLAMETHROWER": 7, &"JAB_CROSS": 6}
	)
	panel.present(summary, "GAME OVER", 2, 1)
	panel.set_page(MatchDebriefPanel.Page.AFTER_ACTION)
	panel.set_global_state(&"online", [{
		"rank": 1,
		"callsign": "Jun",
		"highest_combo_tier": 3,
		"best_score": 35_700,
		"preferred_weapon": "ENVIRONMENT",
	}], {"rank": 1, "callsign": "Jun"})
	assert_eq(String(panel.debug_snapshot().page), "AFTER_ACTION")
	assert_eq((panel.debug_snapshot().global_rows as PackedStringArray).size(), 0)
	assert_false(panel.global_panel.visible)
	assert_true(panel.weapon_panel.visible)
	assert_eq(L10n.t("debrief.weapon.environment"), "COLLATERAL DAMAGE")
	assert_true(panel.weapon_preferred_label.text.contains("COLLATERAL DAMAGE"))
	_record_test_execution()


func test_leaderboard_bridge_is_native_safe_and_rejects_unsolicited_responses() -> void:
	L10n.set_locale("en")
	var store: PlayerCombatProfileStore = PlayerCombatProfileStore.new()
	add_child_autofree(store)
	store.setup(TEST_PROFILE_PATH)
	var panel: MatchDebriefPanel = MatchDebriefPanel.new()
	add_child_autofree(panel)
	await get_tree().process_frame
	panel.configure_profile(store)
	var bridge: LeaderboardBridge = LeaderboardBridge.new()
	add_child_autofree(bridge)
	bridge.setup(store, panel)
	assert_eq(String(bridge.debug_snapshot().state), "native_local")
	panel.set_page(MatchDebriefPanel.Page.GLOBAL)
	bridge._pending["request-1"] = {"type": &"list", "deadline": 999_999.0}
	bridge._handle_response({
		"channel": "wrong-channel",
		"version": LeaderboardBridge.PROTOCOL_VERSION,
		"requestId": "request-1",
		"ok": true,
	})
	assert_eq(int(bridge.debug_snapshot().pending_count), 1)
	bridge._handle_response({
		"channel": LeaderboardBridge.CHANNEL,
		"version": LeaderboardBridge.PROTOCOL_VERSION,
		"requestId": "request-1",
		"ok": true,
		"data": {
			"entries": [{
				"rank": 1,
				"callsign": "ECHO-7",
				"highestComboTier": 22,
				"bestScore": 1_500_000,
				"bestPhysicalChain": 38,
				"preferredWeapon": "LASER",
			}],
			"personalRank": {"rank": 1, "callsign": "ECHO-7"},
		},
	})
	assert_eq(String(bridge.debug_snapshot().state), "online")
	assert_eq(int(bridge.debug_snapshot().pending_count), 0)
	var snapshot: Dictionary = panel.debug_snapshot()
	assert_eq(String(snapshot.global_state), "online")
	assert_eq((snapshot.global_rows as PackedStringArray).size(), 1)
	assert_true(String((snapshot.global_rows as PackedStringArray)[0]).contains("ECHO-7"))
	assert_eq(snapshot.highlighted_global_rows, PackedInt32Array([0]))
	bridge._pending["callsign-success"] = {
		"type": &"update_callsign",
		"deadline": 999_999.0,
	}
	panel.set_callsign_uplink_state(&"pending")
	bridge._handle_response({
		"channel": LeaderboardBridge.CHANNEL,
		"version": LeaderboardBridge.PROTOCOL_VERSION,
		"requestId": "callsign-success",
		"ok": true,
		"data": {
			"entries": [{
				"rank": 1,
				"callsign": "VANGUARD",
				"highestComboTier": 30,
				"bestScore": 2_000_000,
				"preferredWeapon": "MISSILE",
			}, {
				"rank": 2,
				"callsign": "NOVA PRIME",
				"highestComboTier": 22,
				"bestScore": 1_500_000,
				"preferredWeapon": "LASER",
			}],
			"personalRank": {"rank": 2, "callsign": "NOVA PRIME"},
		},
	})
	snapshot = panel.debug_snapshot()
	assert_eq(String(snapshot.callsign_uplink_state), "success")
	assert_eq(
		String(snapshot.global_callsign_status),
		L10n.t("debrief.callsign.uplink.success")
	)
	assert_eq(snapshot.highlighted_global_rows, PackedInt32Array([1]))
	bridge._pending["callsign-rejected"] = {
		"type": &"update_callsign",
		"deadline": 999_999.0,
	}
	bridge._handle_response({
		"channel": LeaderboardBridge.CHANNEL,
		"version": LeaderboardBridge.PROTOCOL_VERSION,
		"requestId": "callsign-rejected",
		"ok": false,
		"error": "CALLSIGN_REJECTED",
	})
	assert_eq(String(panel.debug_snapshot().callsign_uplink_state), "rejected")
	assert_eq(String(bridge.debug_snapshot().state), "online")
	bridge._pending["callsign-failure"] = {
		"type": &"update_callsign",
		"deadline": 999_999.0,
	}
	bridge._handle_response({
		"channel": LeaderboardBridge.CHANNEL,
		"version": LeaderboardBridge.PROTOCOL_VERSION,
		"requestId": "callsign-failure",
		"ok": false,
		"error": "UPLINK_UNAVAILABLE",
	})
	assert_eq(String(panel.debug_snapshot().callsign_uplink_state), "failure")
	assert_eq(String(bridge.debug_snapshot().state), "online")
	_record_test_execution()


func test_run_lifecycle_submits_profile_once_and_presents_enriched_dossier() -> void:
	var store: PlayerCombatProfileStore = PlayerCombatProfileStore.new()
	add_child_autofree(store)
	store.setup(TEST_PROFILE_PATH)
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	city.mobile_detection_override = 1
	city.combat_profile = store
	add_child_autofree(city)
	await get_tree().process_frame
	var actors: Array[EnemyActor2D] = city.encounter_runtime.all_actors()
	for enemy: EnemyActor2D in actors:
		enemy.set_physics_process(false)
	assert_false(actors.is_empty())
	var fatal_enemy: EnemyActor2D = actors[0]
	fatal_enemy.set_meta(&"enemy_archetype", &"covenant_warden")
	var event: GameplayEvent = _kill_event(501, &"needle", &"air", &"LASER")
	assert_true(city.rampage_session.publish(event))
	assert_true(city.robot.receive_damage(DamageEvent.new(
		18_100,
		fatal_enemy,
		city.robot.current_health + 1.0,
		&"shell"
	)))
	var summary: RunSummarySnapshot = city.rampage_session.frozen_summary
	assert_not_null(summary)
	assert_eq(summary.defeat_source_id, &"covenant_warden")
	assert_eq(summary.total_enemies_defeated, 1)
	assert_eq(int(summary.career_snapshot.total_runs), 1)
	assert_true(city.gameplay_hud.match_debrief.visible)
	assert_eq(
		city.gameplay_hud.match_debrief.killer_label.text,
		"KILLED BY 'COVENANT WARDEN'"
	)
	assert_eq(int(store.snapshot().total_runs), 1)
	city.run_lifecycle._finish_run(false)
	assert_eq(int(store.snapshot().total_runs), 1)
	_record_test_execution()


func _session() -> RampageSession:
	var session: RampageSession = RampageSession.new()
	add_child_autofree(session)
	return session


func _kill_event(
	index: int,
	enemy_id: StringName,
	family_id: StringName,
	weapon_id: StringName
) -> GameplayEvent:
	var event: GameplayEvent = GameplayEvent.new(
		StringName("debrief_kill_%d" % index),
		index + 1,
		GameplayEvent.Kind.ENEMY_DEFEATED,
		GameplayEvent.ENEMY_KILL,
		100,
		8.0,
		true
	)
	event.enemy_archetype_id = enemy_id
	event.enemy_family_id = family_id
	event.weapon_id = weapon_id
	return event


func _make_summary(
	score: int,
	highest_combo_tier: int,
	completed: bool,
	enemy_kills: Dictionary,
	weapon_kills: Dictionary,
	defeat_source_id: StringName = DefeatSourceResolver.UNKNOWN
) -> RunSummarySnapshot:
	var total_kills: int = 0
	for value: Variant in enemy_kills.values():
		total_kills += int(value)
	var preferred_entries: Array[Dictionary] = CombatRunTelemetry.ranked_entries(weapon_kills, 1)
	var preferred_weapon: StringName = (
		preferred_entries[0].id as StringName if not preferred_entries.is_empty() else &"UNKNOWN"
	)
	var preferred_kills: int = (
		int(preferred_entries[0].count) if not preferred_entries.is_empty() else 0
	)
	return RunSummarySnapshot.new(
		score,
		mini(highest_combo_tier, RampageRewardTuning.MAX_MULTIPLIER),
		highest_combo_tier * EnemySpawnTuning.QUANTITY_MULTIPLIER,
		6 if completed else 2,
		1,
		{},
		{
			"completed": completed,
			"defeat_source_id": defeat_source_id,
			"grade": &"S" if completed else &"C",
			"highest_combo_tier": highest_combo_tier,
			"total_enemies_defeated": total_kills,
			"unique_enemy_types": enemy_kills.size(),
			"enemy_kills": enemy_kills,
			"weapon_kills": weapon_kills,
			"preferred_weapon": preferred_weapon,
			"preferred_weapon_kills": preferred_kills,
		}
	)


func _clear_profile_files() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path: String = TEST_PROFILE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _assert_rect_inside(rect: Rect2, viewport_size: Vector2) -> void:
	assert_gte(rect.position.x, 0.0)
	assert_gte(rect.position.y, 0.0)
	assert_lte(rect.end.x, viewport_size.x + 0.01)
	assert_lte(rect.end.y, viewport_size.y + 0.01)


func _assert_touch_rect(rect: Rect2) -> void:
	assert_gte(rect.size.x, 120.0)
	assert_gte(rect.size.y, 44.0)


func _assert_action_group_margins(panel: MatchDebriefPanel, state: Dictionary) -> void:
	var expected_margin: float = (
		MatchDebriefPanel.CONTROL_GROUP_MARGIN * panel.content_root.scale.x
	)
	var tabs_rect: Rect2 = state.tabs_rect as Rect2
	var page_content_rect: Rect2 = state.page_content_rect as Rect2
	var bottom_content_rect: Rect2 = state.bottom_content_rect as Rect2
	var retry_rect: Rect2 = state.retry_rect as Rect2
	assert_almost_eq(page_content_rect.position.y - tabs_rect.end.y, expected_margin, 0.01)
	assert_almost_eq(retry_rect.position.y - bottom_content_rect.end.y, expected_margin, 0.01)


func _assert_after_action_header_bottom_padding(
	panel: MatchDebriefPanel,
	meta_base_y: float,
	body_base_y: float
) -> void:
	var unpadded_meta_y: float = (
		meta_base_y
		+ panel._tabs_bottom()
		+ MatchDebriefPanel.CONTROL_GROUP_MARGIN
		- body_base_y
	)
	assert_almost_eq(
		panel.run_meta_label.position.y - unpadded_meta_y,
		MatchDebriefPanel.AFTER_ACTION_HEADER_BOTTOM_PADDING,
		0.01
	)


func _assert_global_layout(panel: MatchDebriefPanel) -> void:
	var editor_end: float = (
		panel.global_callsign_edit.position.y + panel.global_callsign_edit.size.y
	)
	var personal_rank_end: float = (
		panel.personal_rank_label.position.y + panel.personal_rank_label.size.y
	)
	assert_lte(editor_end, panel.personal_rank_label.position.y)
	assert_lte(personal_rank_end, panel.global_rows[0].position.y)


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
