extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const TEST_PATH: String = "user://test_boss_escalation.json"

var city: CitySlice
var session: CommandBossSession
var escalation: BossEscalationController


func before_each() -> void:
	_remove_saves()
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	session = city.urban_siege.boss_session
	escalation = session.utility_pool.escalation


func after_each() -> void:
	_remove_saves()
	L10n.set_locale("en")


func test_entertainment_and_military_cover_all_masks_and_keep_direct_route() -> void:
	var adapter: BossStructuralAdapter = session.utility_pool.arena_adapter
	for boss_id: StringName in [
		&"MIMESIS_04", &"CANTOR_31_PALE_ENGINE",
	]:
		var definition: BossEncounterDefinition = BossCampaignCatalog.definition(boss_id)
		var rows: int = 0
		for mask: int in range(BossStructuralAdapter.MASK_COUNT):
			var binding: Dictionary = adapter.binding_for_mask(
				mask, definition.arena_cell_indices
			)
			assert_true(bool(binding.lower_passage), "%s mask=%d" % [boss_id, mask])
			assert_true(bool(binding.visible_weak_point), "%s mask=%d" % [boss_id, mask])
			assert_true(bool(binding.direct_damage_route), "%s mask=%d" % [boss_id, mask])
			assert_true(bool(binding.valid_finisher_receiver), "%s mask=%d" % [boss_id, mask])
			rows += 1
		assert_eq(rows, 64)
		_start(boss_id)
		assert_true(escalation.direct_route_valid_after_facade_predestruction())
		session.stop()


func test_mimesis_echo_history_and_magenta_selection_are_noncolliding() -> void:
	_start(&"MIMESIS_04")
	var recorder: MotionEchoRecorder = session.utility_pool.motion_echo_recorder
	for index: int in range(12):
		recorder.record_motion(
			session.boss.global_position + Vector2(float(index) * 64.0, 0.0),
			float(index) * 0.1
		)
	assert_eq(recorder.count, MotionEchoRecorder.CAPACITY)
	assert_eq(recorder.marker_positions().size(), 8)
	assert_false(recorder.history_can_damage())
	assert_true(recorder.arm_marker(6, &"ARMED_AFTERIMAGE"))
	assert_eq(
		session.utility_pool.lane_damage_areas[2].visual_state,
		BossAttackArea2D.VisualState.TELEGRAPH
	)
	assert_false(session.utility_pool.lane_damage_areas[2].contains_world_point(
		recorder.marker_positions()[6]
	))
	assert_true(recorder.activate_armed_presentation())
	assert_false(recorder.damage_footprint_matches_collision())
	assert_false(session.utility_pool.lane_damage_areas[2].monitoring)
	assert_false(session.utility_pool.lane_damage_areas[2].contains_world_point(
		recorder.marker_positions()[6]
	))


func test_siren_uses_needle_air_shell_and_leaves_direct_controls_live() -> void:
	_start(&"MIMESIS_04")
	var siren: EnemyActor2D = escalation.deploy_siren()
	assert_not_null(siren)
	assert_eq((siren as ProceduralEnemy).archetype_id, &"needle")
	assert_eq((siren as ProceduralEnemy).family, &"air")
	assert_eq((siren as ProceduralEnemy).boss_support_id, &"choir_siren")
	assert_eq(city.encounter_runtime.active_family_count(&"air"), 1)
	assert_null(escalation.deploy_siren())
	assert_true(escalation.begin_siren_ring())
	assert_true(escalation.player_direct_controls_live())
	assert_true(city.contextual_attacks != null)
	city.robot.global_position = escalation.center
	escalation.advance(0.01)
	city.robot.global_position = escalation.center + Vector2(240.0, 0.0)
	escalation.advance(0.01)
	escalation.end_siren_ring()
	assert_false(escalation.siren_ring_active)


func test_entertainment_counterplay_record_and_direct_clear_contract() -> void:
	_start(&"MIMESIS_04")
	for _connection: int in range(3):
		assert_true(escalation.register_armor_connection())
	assert_true(escalation.continuity_record_played)
	assert_eq(escalation.biological_termination_time, "04:17")
	assert_eq(escalation.continuity_boot_delay_seconds, 3.0)
	assert_eq(escalation.strike_show_control_cabinet(), 60.0)
	assert_eq(escalation.strike_show_control_cabinet(), 0.0)
	assert_true(escalation.ground_rubble_bed())
	assert_between(escalation.direct_clear_seconds, 45.0, 75.0)
	var payload: Dictionary = escalation.completion_payload()
	assert_true(bool(payload.stage_record_preserved))
	assert_eq(String(payload.biological_termination_time), "04:17")


func test_military_phases_four_attacks_safe_lane_three_anchors_and_no_seraph() -> void:
	_start(&"CANTOR_31_PALE_ENGINE")
	assert_eq(escalation.active_attack_choices(), [&"SUTURE_SALVO"])
	escalation.set_combat_state(CommandBossSession.STATE_EXPOSED, 0.8)
	assert_eq(escalation.active_attack_choices(), [&"SUTURE_SALVO", &"DISPATCH_HARNESS"])
	escalation.set_combat_state(CommandBossSession.STATE_EXPOSED, 0.2)
	assert_eq(
		escalation.active_attack_choices(),
		[&"PALE_RECLAMATION", &"COMPRESSION_PSALM", &"SUTURE_SALVO"]
	)
	assert_true(escalation.artillery_spine_visible)
	assert_eq(escalation.seraph_environment_count, 3)
	assert_eq(escalation.live_seraph_count(), 0)
	assert_eq(city.encounter_runtime.active_count(&"seraph_carrier"), 0)
	while escalation.active_attack != &"SUTURE_SALVO":
		escalation.advance(_attack_cycle_seconds())
	assert_true(escalation.safe_lane_exists())
	for index: int in range(4):
		var anchor_index: int = escalation.create_freight_anchor(
			session.boss.global_position + Vector2(float(index) * 80.0, 0.0)
		)
		assert_eq(anchor_index, index if index < 3 else -1)
	assert_eq(escalation.anchors_created, 3)
	assert_true(escalation.deny_reclamation_anchor(0))
	assert_eq(escalation.resolve_pale_reclamation(), 2)
	assert_eq(escalation.ablative_plates, 2)
	assert_eq(escalation.resolve_pale_reclamation(), 0)
	assert_true(escalation.reclamation_is_finite())


func test_military_dispatch_caps_one_runner_and_pool_denial_has_no_false_telegraph() -> void:
	_start(&"CANTOR_31_PALE_ENGINE")
	var runner: EnemyActor2D = escalation.request_dispatch()
	assert_not_null(runner)
	assert_eq((runner as ProceduralEnemy).archetype_id, &"jackal")
	assert_eq((runner as ProceduralEnemy).family, &"light")
	assert_eq((runner as ProceduralEnemy).boss_support_id, &"graft_runner")
	assert_gt(city.encounter_runtime.target_mark_remaining, 0.0)
	assert_eq(escalation.live_auxiliary_count(), 1)
	assert_null(escalation.request_dispatch())
	assert_eq(escalation.live_auxiliary_count(), 1)
	session.stop()
	city.encounter_runtime.release_all()
	_start(&"CANTOR_31_PALE_ENGINE")
	var blockers: Array[EnemyActor2D] = []
	for _index: int in range(RuntimeBudget.PROCEDURAL_LIGHT):
		var blocker: EnemyActor2D = city.encounter_runtime.acquire(
			&"jackal", Vector2.ZERO
		)
		assert_not_null(blocker)
		blockers.append(blocker)
	assert_null(escalation.request_dispatch())
	assert_true(escalation.dispatch_denied)
	assert_true(escalation.dispatch_dressing_only)
	assert_eq(escalation.live_auxiliary_count(), 0)
	for area: BossAttackArea2D in session.utility_pool.lane_damage_areas:
		assert_ne(area.attack_id, &"DISPATCH_HARNESS")
	for blocker: EnemyActor2D in blockers:
		city.encounter_runtime.release(blocker)


func test_retry_restores_mid_generation_history_ring_anchors_and_one_support() -> void:
	_start(&"MIMESIS_04")
	var recorder: MotionEchoRecorder = session.utility_pool.motion_echo_recorder
	for index: int in range(5):
		recorder.record_motion(session.boss.global_position + Vector2(index * 64.0, 0.0), index)
	var siren: EnemyActor2D = escalation.deploy_siren()
	assert_not_null(siren)
	assert_true(escalation.begin_siren_ring())
	var snapshot: Dictionary = session.capture_attempt_state()
	var before: Dictionary = snapshot.escalation
	var baseline_total: int = city.encounter_runtime.total_count()
	session.restore_attempt_state(snapshot)
	assert_true(session.start_definition(BossCampaignCatalog.definition(&"MIMESIS_04")))
	var restored: Dictionary = escalation.capture_state()
	for key: String in [
		"attack_index", "attack_stage", "active_attack", "armor_connections",
		"continuity_record_played", "siren_deployed", "siren_active",
		"siren_ring_active",
	]:
		assert_eq(restored[key], before[key], key)
	assert_eq(int(restored.recorder.count), int(before.recorder.count))
	assert_eq(city.encounter_runtime.active_family_count(&"air"), 1)
	assert_eq(city.encounter_runtime.total_count(), baseline_total)
	assert_eq(session.utility_pool.post_warm_creation_count, 0)


func test_mimesis_fires_scaled_marquee_shells_and_rotates_entertainment_support() -> void:
	_start(&"MIMESIS_04")
	assert_eq(session.utility_pool.rig.scale, Vector2.ONE * 1.5)
	assert_almost_eq(
		session.boss.global_position.y,
		BossRig2D.road_contact_y_for_preset(&"MIMESIS"),
		0.001
	)
	var planned: Dictionary = escalation.projectile_signature()
	assert_eq(planned.kind, &"shell")
	assert_eq(planned.visual_key, BossEscalationController.ENTERTAINMENT_PROJECTILE_VISUAL)
	assert_almost_eq(planned.presentation_scale, 1.5, 0.001)
	assert_eq(planned.telegraph_id, 0)
	assert_eq(city.telegraph_presenter.active_count(), 0)
	assert_eq((planned.origins as Array).size(), planned.planned)
	assert_eq((planned.targets as Array).size(), planned.planned)
	var projectile_origin: Vector2 = (planned.origins as Array)[0]
	escalation.advance(BossEscalationController.TELEGRAPH_SECONDS)
	var shell: Projectile2D = city.projectile_root.last_acquired
	assert_not_null(shell)
	assert_eq(shell.source, session.boss)
	assert_eq(shell.global_position, projectile_origin)
	assert_almost_eq(shell.presentation_scale, 1.5, 0.001)
	for area: BossAttackArea2D in (
		session.utility_pool.lane_damage_areas + session.utility_pool.line_areas
	):
		assert_false(area.monitoring)
	escalation.set_combat_state(CommandBossSession.STATE_BARRAGE, 1.0)
	for _index: int in range(BossEscalationController.ENTERTAINMENT_REINFORCEMENT_CAP):
		escalation.advance(BossEscalationController.ENTERTAINMENT_REINFORCEMENT_SECONDS)
	assert_eq(
		escalation.reinforcement_ids(),
		BossEscalationController.ENTERTAINMENT_REINFORCEMENTS
	)
	escalation.set_combat_state(CommandBossSession.STATE_EXPOSED, 0.0)
	assert_eq(escalation.reinforcement_count(), 0)


func test_cantor_reserves_atomic_three_shell_rosary_and_continuous_military_support() -> void:
	_start(&"CANTOR_31_PALE_ENGINE")
	assert_eq(session.utility_pool.rig.scale, Vector2.ONE * 1.5)
	assert_almost_eq(
		session.boss.global_position.y,
		BossRig2D.road_contact_y_for_preset(&"CANTOR_PALE_ENGINE"),
		0.001
	)
	var planned: Dictionary = escalation.projectile_signature()
	assert_eq(planned.planned, 3)
	assert_eq(planned.pending, 3)
	assert_eq(planned.telegraph_id, 0)
	assert_eq(city.telegraph_presenter.active_count(), 0)
	assert_eq((planned.origins as Array).size(), 3)
	assert_eq((planned.targets as Array).size(), 3)
	assert_eq(city.projectile_root.reservation_count(&"shell"), 3)
	escalation.advance(BossEscalationController.TELEGRAPH_SECONDS)
	assert_eq(city.projectile_root.active_count(&"shell"), 1)
	escalation.advance(0.21)
	assert_eq(city.projectile_root.active_count(&"shell"), 3)
	for projectile: Projectile2D in city.projectile_root._active_order:
		if projectile.damage_type == &"shell":
			assert_almost_eq(projectile.presentation_scale, 1.5, 0.001)
	escalation.set_combat_state(CommandBossSession.STATE_BARRAGE, 1.0)
	for _index: int in range(BossEscalationController.MILITARY_REINFORCEMENT_CAP):
		escalation.advance(BossEscalationController.MILITARY_REINFORCEMENT_SECONDS)
	assert_eq(
		escalation.reinforcement_ids(),
		BossEscalationController.MILITARY_REINFORCEMENTS
	)
	escalation.set_combat_state(CommandBossSession.STATE_EXPOSED, 0.0)
	assert_eq(escalation.reinforcement_count(), 0)


func test_cantor_pool_saturation_cancels_all_promised_rosary_shots() -> void:
	_start(&"CANTOR_31_PALE_ENGINE")
	escalation.boss_volley.cancel()
	city.projectile_root.release_all()
	for _index: int in range(RuntimeBudget.SHELLS):
		assert_not_null(city.projectile_root.acquire(
			Vector2.ZERO, Vector2.RIGHT, 10.0, 1.0, session.boss, 0, &"shell"
		))
	escalation._begin_next_attack()
	var denied: Dictionary = escalation.projectile_signature()
	assert_eq(denied.planned, 0)
	assert_eq(denied.telegraph_id, 0)
	assert_eq(city.projectile_root.reservation_count(&"shell"), 0)
	assert_gt(denied.denials, 0)


func test_stage_and_arsenal_transactions_are_idempotent_with_export_data() -> void:
	var store: CampaignProgressStore = CampaignProgressStore.new()
	store.setup(TEST_PATH)
	add_child_autofree(store)
	var director: NarrativeDirector = NarrativeDirector.new()
	director.setup(store)
	add_child_autofree(director)
	var stage: Dictionary = {
		"stage_record_preserved": true,
		"biological_termination_time": "04:17",
		"continuity_boot_delay_seconds": 3.0,
	}
	var arsenal: Dictionary = {
		"arsenal_record_preserved": true,
		"export_destinations": BossEscalationController.EXPORT_DESTINATIONS,
	}
	assert_true(director.handle_boss_completed(
		BossCampaignCatalog.definition(&"MIMESIS_04"), stage
	))
	assert_true(director.handle_boss_completed(
		BossCampaignCatalog.definition(&"MIMESIS_04"), stage
	))
	assert_true(director.handle_boss_completed(
		BossCampaignCatalog.definition(&"CANTOR_31_PALE_ENGINE"), arsenal
	))
	assert_true(director.handle_boss_completed(
		BossCampaignCatalog.definition(&"CANTOR_31_PALE_ENGINE"), arsenal
	))
	assert_true(store.has_evidence(&"STAGE"))
	assert_true(store.has_evidence(&"ARSENAL"))
	assert_true(store.has_dossier(&"AUDIENCE_OF_ONE_0417_CONTINUITY"))
	assert_true(store.has_dossier(&"EXPORT_LITANY_31"))
	assert_eq(
		Array(store.snapshot().boss_results.CANTOR_31_PALE_ENGINE.export_destinations),
		BossEscalationController.EXPORT_DESTINATIONS
	)
	assert_eq(
		int(store.snapshot().route_unlock_chunk),
		BossCampaignCatalog.CANONICAL_UNLOCKS[3]
	)
	assert_eq(store.pending_reward_grants().count("boss:MIMESIS_04:reward"), 1)
	assert_eq(store.pending_reward_grants().count("boss:CANTOR_31_PALE_ENGINE:reward"), 1)


func test_automatic_rubble_preserves_stage_and_arsenal_payloads() -> void:
	var cases: Array[Dictionary] = [
		{
			"boss_id": &"MIMESIS_04",
			"field": "stage_record_preserved",
		},
		{
			"boss_id": &"CANTOR_31_PALE_ENGINE",
			"field": "arsenal_record_preserved",
		},
	]
	var attack_id: int = 120_000
	for test_case: Dictionary in cases:
		_start(StringName(test_case.boss_id))
		var armor_steps: int = 0
		while session.boss.boss_armor > 0.0 and armor_steps < 12:
			assert_true(session.boss.receive_damage(_charged_event(
				attack_id,
				session.active_definition.armor_milestone_step
			)))
			attack_id += 1
			armor_steps += 1
		assert_eq(session.boss.boss_armor, 0.0)
		assert_true(session.boss.receive_damage(_charged_event(attack_id)))
		attack_id += 1
		var payload_before: Dictionary = session.completion_payload()
		assert_true(bool(payload_before.get(String(test_case.field), false)))
		assert_false(session.utility_pool.default_wreck_receiver.active)
		session.utility_pool.defeat_spectacle.advance(
			BossDefeatSpectacle2D.PRESENTATION_SECONDS
		)
		assert_eq(session.state, CommandBossSession.STATE_COMPLETE)
		assert_true(bool(session.completion_payload().get(String(test_case.field), false)))
		assert_eq(
			StringName(session.completion_payload().get("boss_id", &"")),
			StringName(test_case.boss_id)
		)


func test_landscape_portrait_mechanics_and_25_restarts_are_stable() -> void:
	var baseline_nodes: int = RuntimeBudget.snapshot(city).node_count
	var baseline_actors: int = city.encounter_runtime.total_count()
	for boss_id: StringName in [
		&"MIMESIS_04", &"CANTOR_31_PALE_ENGINE",
	]:
		_start(boss_id)
		var landscape: Dictionary = escalation.mechanical_signature()
		var definition: BossEncounterDefinition = session.active_definition
		var token: int = session.utility_pool.begin_generation()
		assert_true(session.utility_pool.rig.configure(
			definition,
			session.boss,
			true
		))
		assert_true(escalation.start(definition, token, session.boss.global_position, true))
		assert_eq(escalation.mechanical_signature(), landscape)
		session.stop()
	for index: int in range(25):
		_start(
			&"MIMESIS_04" if index % 2 == 0 else &"CANTOR_31_PALE_ENGINE"
		)
		session.stop()
	assert_eq(RuntimeBudget.snapshot(city).node_count, baseline_nodes)
	assert_eq(city.encounter_runtime.total_count(), baseline_actors)
	assert_eq(session.utility_pool.post_warm_creation_count, 0)
	assert_eq(city.encounter_runtime.post_warm_creation_count, 0)


func _attack_cycle_seconds() -> float:
	return (
		BossEscalationController.TELEGRAPH_SECONDS
		+ BossEscalationController.ACTIVE_SECONDS
		+ BossEscalationController.RECOVERY_SECONDS
	)


func _charged_event(attack_id: int, amount: float = 999.0) -> DamageEvent:
	return DamageEvent.new(
		attack_id,
		city.robot,
		amount,
		&"jab_cross",
		Vector2.ZERO,
		Vector2.RIGHT,
		0.0,
		attack_id,
		0,
		DamageEvent.FLAG_FULL_CHARGE
	)


func _smash_event(attack_id: int) -> DamageEvent:
	return DamageEvent.new(
		attack_id,
		city.robot,
		999.0,
		&"ground_smash",
		Vector2.ZERO,
		Vector2.RIGHT,
		0.0,
		attack_id + 1_000_000
	)


func _start(boss_id: StringName, release_all: bool = true) -> void:
	if release_all:
		city.encounter_runtime.release_all()
	assert_true(session.start_definition(BossCampaignCatalog.definition(boss_id)))
	assert_true(escalation.active())


func _remove_saves() -> void:
	for path: String in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
