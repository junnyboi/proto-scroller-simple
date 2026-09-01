extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")

var city: CitySlice
var campaign: BossCampaignDirector
var definition: BossEncounterDefinition


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.urban_siege.run_active = true
	campaign = city.urban_siege.boss_campaign
	definition = BossCampaignCatalog.definitions()[0]
	await _trigger_gate()


func test_retry_preserves_destroyed_structure_and_restores_run_state() -> void:
	var entry_snapshot: BossAttemptSnapshot = campaign.attempt_snapshot
	var entry_score: Dictionary = entry_snapshot.score_state.duplicate(true)
	var entry_gate: Dictionary = entry_snapshot.gate_state.duplicate(true)
	var entry_reservations: Dictionary = entry_snapshot.reservation_state.duplicate(true)
	var arena_building: StructuralBuilding2D = campaign.arena_lease.arena_building
	var cell: Destructible2D = arena_building.get_cell(0, 0)
	cell.receive_damage(_damage(82_001, 10_000.0, &"ground_smash", cell.global_position))
	city.rampage_session.run_score.safe_score += 777
	city.rampage_session.run_score.pending_bank.add(333)
	var gameplay_event: GameplayEvent = GameplayEvent.new(
		&"boss_retry_mutation",
		82_002,
		GameplayEvent.Kind.ENEMY_DEFEATED,
		&"TEST",
		10,
		1.0,
		true,
		Vector2.ZERO
	)
	assert_true(city.rampage_session.event_hub.accept(gameplay_event))
	city.rampage_session.causal_chain_tracker.register(gameplay_event)
	campaign.active_gate.trigger_count += 2
	assert_gt(campaign.active_gate.trigger_count, int(entry_gate.trigger_count))
	var reservation: int = city.urban_siege.boss_session.utility_pool.reserve_requirements({
		&"markers": 1,
	})
	assert_gt(reservation, 0)
	city.robot.current_health = 0.0
	assert_true(campaign.fail_attempt())
	assert_true(campaign.retry_attempt())
	assert_eq(city.urban_siege.boss_session.state, CommandBossSession.STATE_SCREEN)
	assert_almost_eq(city.urban_siege.boss_session.elapsed_seconds, 0.0, 0.0001)
	assert_almost_eq(city.urban_siege.boss_session.boss.boss_armor, definition.armor, 0.0001)
	assert_almost_eq(city.urban_siege.boss_session.boss.current_health, definition.health, 0.0001)
	assert_true(arena_building.get_cell(0, 0).is_destroyed())
	assert_eq(city.rampage_session.run_score.capture_attempt_state(), entry_score)
	assert_eq(campaign.active_gate.capture_state(), entry_gate)
	var restored_reservations: Dictionary = (
		city.urban_siege.boss_session.utility_pool.capture_reservation_state()
	)
	assert_eq(restored_reservations.next_id, entry_reservations.next_id)
	assert_eq(restored_reservations.reservations, entry_reservations.reservations)
	assert_eq(restored_reservations.generation, int(entry_reservations.generation) + 1)
	assert_eq(
		city.rampage_session.event_hub.capture_attempt_state(),
		entry_snapshot.event_history_state
	)
	assert_eq(
		city.rampage_session.causal_chain_tracker.capture_attempt_state(),
		entry_snapshot.recorder_state
	)


func test_retry_stays_suspended_with_controls_live_and_no_competing_state() -> void:
	var director: DistrictResponseDirector = city.urban_siege.director
	var frozen_elapsed: float = director.elapsed
	var frozen_beat: int = director.beat_index
	city.robot.current_health = 0.0
	assert_true(campaign.fail_attempt())
	assert_true(director.is_suspended_for_boss())
	assert_true(campaign.interlock.is_owned())
	assert_true(campaign.retry_attempt())
	for _step: int in range(20):
		director.advance(0.25)
	assert_almost_eq(director.elapsed, frozen_elapsed, 0.0001)
	assert_eq(director.beat_index, frozen_beat)
	assert_eq(director.pending_count(), 0)
	assert_eq(director.hazard_pending_count(), 0)
	assert_eq(director.ledger.pending_count(), 0)
	assert_eq(city.urban_siege.hazards.active_count(), 0)
	assert_eq(city.urban_siege.catalysts.active_count(), 0)
	assert_false(city.urban_siege.directives.is_active())
	assert_true(city.robot.can_request_attack())
	assert_false(city.urban_siege.is_simulation_paused())
	assert_false(city.game_over_active)


func test_boss_defeat_presents_dossier_and_retry_requests_fresh_city() -> void:
	var kill: GameplayEvent = GameplayEvent.new(
		&"boss_attempt_dossier_kill",
		82_300,
		GameplayEvent.Kind.ENEMY_DEFEATED,
		GameplayEvent.ENEMY_KILL,
		250,
		1.0,
		true,
		Vector2.ZERO
	)
	kill.enemy_archetype_id = &"covenant_warden"
	kill.enemy_family_id = &"infantry"
	kill.weapon_id = &"JAB_CROSS"
	assert_true(city.rampage_session.publish(kill))
	city.robot.current_health = 0.0
	city.run_lifecycle.robot_defeated()
	assert_true(city.game_over_active)
	assert_true(campaign.attempt_failed)
	assert_true(city.gameplay_hud.game_over_overlay.visible)
	assert_true(city.gameplay_hud.match_debrief.visible)
	assert_eq(city.gameplay_hud.match_debrief.presented_summary.total_enemies_defeated, 1)
	assert_null(city.rampage_session.frozen_summary)
	var retry_request_count: Array[int] = [0]
	city.retry_requested.connect(func() -> void: retry_request_count[0] += 1)
	city.gameplay_hud.retry_pressed.emit()
	assert_eq(retry_request_count[0], 1)
	assert_true(city.game_over_active)
	assert_true(campaign.attempt_failed)


func test_repeated_failure_retry_keeps_runtime_counts_and_one_gate_lease() -> void:
	var baseline: Dictionary = RuntimeBudget.snapshot(city)
	for _attempt: int in range(5):
		city.robot.current_health = 0.0
		assert_true(campaign.fail_attempt())
		assert_true(campaign.retry_attempt())
		assert_true(campaign.arena_lease.active)
		assert_true(city.world_stream.resident_lease_active())
		assert_eq(campaign.active_gate.trigger_count, 1)
	var after: Dictionary = RuntimeBudget.snapshot(city)
	assert_eq(after.node_count, baseline.node_count)
	assert_eq(after.enemy_total, baseline.enemy_total)
	assert_eq(after.wreck_total, baseline.wreck_total)
	assert_eq(after.boss_post_warm_creations, 0)


func _trigger_gate() -> void:
	city.robot.global_position.x = (
		city.world_stream.runtime_x_for_logical_index(definition.trigger_chunk) + 100.0
	)
	city.world_stream.advance_stream()
	var district: CityDistrictProfile = CityDistrictCatalog.district_for_chunk(
		definition.trigger_chunk
	)
	for encounter_index: int in range(
		CityDistrictCatalog.FACADE_ENCOUNTERS_PER_DISTRICT
	):
		var logical_chunk: int = district.start_chunk + encounter_index
		var variant: StructuralBuildingVariant = CityDistrictCatalog.variant_for_chunk(
			city.world_stream.run_seed,
			logical_chunk
		)
		var building: StructuralBuilding2D = StructuralBuilding2D.new()
		building.set_meta(&"district_id", district.district_id)
		building.set_meta(&"district_index", district.district_index)
		building.set_meta(&"building_variant_id", variant.variant_id)
		building.set_meta(&"logical_chunk", logical_chunk)
		assert_true(city.world_stream.report_building_cleared(building))
		building.free()
	city.robot.global_position.x = (
		(float(definition.trigger_chunk) + BossCampaignDirector.GATE_APPROACH_FRACTION)
		* CityWorldStream.CHUNK_WIDTH
		- float(city.world_stream.floating_origin.origin_chunk) * CityWorldStream.CHUNK_WIDTH
		+ 1.0
	)
	campaign.advance()
	assert_true(campaign.owns_combat())


func _damage(
	attack_id: int,
	amount: float,
	kind: StringName,
	position: Vector2 = Vector2.ZERO
) -> DamageEvent:
	return DamageEvent.new(
		attack_id,
		city.robot,
		amount,
		kind,
		position,
		Vector2.RIGHT,
		900.0
	)
