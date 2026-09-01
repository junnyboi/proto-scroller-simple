extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const EXPECTED_TRIGGERS: Array[int] = [6, 15]
const ARENA_WALL_LAYER: int = BossArenaBarrier2D.COLLISION_LAYER


func test_authored_gates_trigger_once_before_each_district_transition() -> void:
	var city: CitySlice = await _spawn_city()
	var campaign: BossCampaignDirector = city.urban_siege.boss_campaign
	for trigger: int in EXPECTED_TRIGGERS:
		var definition: BossEncounterDefinition = BossCampaignCatalog.definition_for_trigger(trigger)
		await _prepare_gate_window(city, definition)
		var transition_count: int = city.world_stream.transition_count
		city.robot.global_position.x = _threshold_x(city, definition) + 1.0
		campaign.advance()
		var gate: BossGateMarker = campaign.gate_for_trigger(trigger)
		assert_eq(gate.trigger_count, 1)
		assert_true(gate.owned)
		assert_eq(city.world_stream.current_logical_chunk, trigger)
		assert_eq(city.world_stream.transition_count, transition_count)
		campaign.advance()
		assert_eq(gate.trigger_count, 1)
		campaign.stop()
		campaign._triggered_ids[definition.boss_id] = true
		campaign._completed_ids[definition.boss_id] = true


func test_boss_drop_preserves_ambient_state_while_hiding_only_arena_facade() -> void:
	var city: CitySlice = await _spawn_city()
	var campaign: BossCampaignDirector = city.urban_siege.boss_campaign
	var definition: BossEncounterDefinition = (
		BossCampaignCatalog.definition_for_trigger(
			BossCampaignCatalog.CANONICAL_TRIGGERS[0]
		)
	)
	assert_false(definition.summon_uses_arena_landmark)
	await _prepare_gate_window(city, definition)
	city.encounter_runtime.release_all()
	var preserved_enemies: Array[EnemyActor2D] = [
		city.encounter_runtime.acquire(&"soldier", Vector2(980.0, 590.0)),
		city.encounter_runtime.acquire(&"tank", Vector2(1180.0, 590.0)),
		city.encounter_runtime.acquire(&"helicopter", Vector2(1380.0, 190.0)),
	]
	var enemy_state: Array[Dictionary] = []
	for enemy: EnemyActor2D in preserved_enemies:
		assert_not_null(enemy)
		enemy_state.append({
			"instance_id": enemy.get_instance_id(),
			"position": enemy.global_position,
			"health": enemy.current_health,
			"attack_gate": enemy.attack_gate_enabled,
		})
	var building_state: Array[Dictionary] = []
	for building: StructuralBuilding2D in city.streamed_destructibles.buildings:
		building_state.append({
			"instance_id": building.get_instance_id(),
			"variant_id": building.current_variant_id(),
			"stream_state": building.capture_stream_state(),
			"visible": building.visible,
			"suppressed": building.encounter_suppressed,
		})
	var building_creations: int = city.streamed_destructibles.post_warm_creation_count
	var world_creations: int = city.world_stream.post_warm_creation_count
	var ambient_count: int = city.encounter_runtime.active_count()
	city.robot.global_position.x = _threshold_x(city, definition) + 1.0
	campaign.advance()
	assert_true(campaign.arena_lease.active)
	assert_eq(campaign.arena_lease.resident_count(), CityWorldStream.CHUNK_CAPACITY)
	assert_eq(city.world_stream.active_chunk_count(), CityWorldStream.CHUNK_CAPACITY)
	assert_eq(city.streamed_destructibles.active_building_count(), CityWorldStream.CHUNK_CAPACITY)
	assert_eq(campaign.arena_lease.landmark_instance_count(), 0)
	assert_null(city.urban_siege.boss_session.utility_pool.arena_adapter.building)
	var arena_building: StructuralBuilding2D = campaign.arena_lease.arena_building
	assert_true(arena_building.encounter_suppressed)
	assert_false(arena_building.visible)
	await get_tree().physics_frame
	for row: int in range(StructuralBuilding2D.ROWS):
		for column: int in range(StructuralBuilding2D.COLUMNS):
			var cell: Destructible2D = arena_building.get_cell(column, row)
			var collision: CollisionShape2D = cell.get_node_or_null(
				^"IntactBody/CollisionShape2D"
			) as CollisionShape2D
			assert_true(collision.disabled)
	assert_eq(city.encounter_runtime.active_count(), ambient_count + 1)
	assert_eq(city.world_stream.post_warm_creation_count, world_creations)
	assert_eq(city.streamed_destructibles.post_warm_creation_count, building_creations)
	assert_null(city.urban_siege.boss_session.utility_pool.arena_adapter.building)
	for index: int in range(preserved_enemies.size()):
		var enemy: EnemyActor2D = preserved_enemies[index]
		var baseline: Dictionary = enemy_state[index]
		assert_true(enemy.active)
		assert_false(enemy.dead)
		assert_eq(enemy.get_instance_id(), int(baseline.instance_id))
		assert_eq(enemy.global_position, baseline.position)
		assert_almost_eq(enemy.current_health, float(baseline.health), 0.001)
		assert_eq(enemy.attack_gate_enabled, bool(baseline.attack_gate))
	for index: int in range(building_state.size()):
		var building: StructuralBuilding2D = city.streamed_destructibles.buildings[index]
		var baseline: Dictionary = building_state[index]
		assert_eq(building.get_instance_id(), int(baseline.instance_id))
		assert_eq(building.current_variant_id(), baseline.variant_id)
		assert_eq(building.capture_stream_state(), baseline.stream_state)
		if building == arena_building:
			assert_false(building.visible)
			assert_true(building.encounter_suppressed)
		else:
			assert_eq(building.visible, bool(baseline.visible))
			assert_eq(building.encounter_suppressed, bool(baseline.suppressed))
	campaign.stop()
	assert_false(arena_building.encounter_suppressed)
	assert_true(arena_building.visible)


func test_origin_rebase_keeps_gate_and_arena_anchors_aligned() -> void:
	var city: CitySlice = await _spawn_city()
	var campaign: BossCampaignDirector = city.urban_siege.boss_campaign
	var definition: BossEncounterDefinition = (
		BossCampaignCatalog.definition_for_trigger(
			BossCampaignCatalog.CANONICAL_TRIGGERS[0]
		)
	)
	await _trigger(city, definition)
	var gate_before: Vector2 = campaign.active_gate.cached_world_anchor
	var anchor_before: Vector2 = campaign.arena_lease.cached_building_anchors[0]
	var barrier_before: Vector2 = campaign.arena_barrier.global_position
	var offset: Vector2 = Vector2(-CityWorldStream.CHUNK_WIDTH * 32.0, 0.0)
	city.world_stream.origin_shift_requested.emit(offset, 32)
	assert_eq(campaign.active_gate.cached_world_anchor, gate_before + offset)
	assert_eq(campaign.arena_lease.cached_building_anchors[0], anchor_before + offset)
	assert_eq(campaign.arena_barrier.global_position, barrier_before + offset)


func test_reserved_boss_shell_never_evicts_three_live_ambient_tanks() -> void:
	var city: CitySlice = await _spawn_city()
	city.encounter_runtime.release_all()
	var ambient_tanks: Array[EnemyActor2D] = []
	for index: int in range(EncounterRuntime.COMMAND_TANK_SLOT):
		var tank: EnemyActor2D = city.encounter_runtime.acquire(
			&"tank", Vector2(900.0 + float(index) * 180.0, 590.0)
		)
		assert_not_null(tank)
		ambient_tanks.append(tank)
	assert_null(city.encounter_runtime.acquire(&"tank", Vector2(1500.0, 590.0)))
	var definition: BossEncounterDefinition = (
		BossCampaignCatalog.definition_for_trigger(
			BossCampaignCatalog.CANONICAL_TRIGGERS[0]
		)
	)
	await _trigger(city, definition)
	assert_not_null(city.urban_siege.boss_session.boss)
	assert_eq(city.encounter_runtime.active_count(&"tank"), RuntimeBudget.TANKS)
	for tank: EnemyActor2D in ambient_tanks:
		assert_true(tank.active)
		assert_false(tank.dead)


func test_interlock_freezes_siege_and_leaves_robot_controls_live() -> void:
	var city: CitySlice = await _spawn_city()
	var siege: UrbanSiegeRuntime = city.urban_siege
	var campaign: BossCampaignDirector = siege.boss_campaign
	var director: DistrictResponseDirector = siege.director
	var definition: BossEncounterDefinition = (
		BossCampaignCatalog.definition_for_trigger(
			BossCampaignCatalog.CANONICAL_TRIGGERS[0]
		)
	)
	await _prepare_gate_window(city, definition)
	director.stop()
	city.encounter_runtime.release_all()
	director.start()
	director.advance(0.01)
	var pending_before: int = director.pending_count()
	var hazards_pending_before: int = director.hazard_pending_count()
	var reservations_before: int = director.ledger.pending_count()
	var attack_gate_before: bool = city.encounter_runtime.attack_gate_enabled
	var interval_before: Dictionary[int, float] = {}
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		if enemy.active and not enemy.dead:
			interval_before[enemy.get_instance_id()] = enemy.external_attack_interval_multiplier
	assert_true(campaign._begin_attempt(definition))
	var frozen_elapsed: float = director.elapsed
	var frozen_phase: int = director.phase_index
	var frozen_beat: int = director.beat_index
	for _step: int in range(20):
		director.advance(0.25)
	assert_almost_eq(director.elapsed, frozen_elapsed, 0.0001)
	assert_eq(director.phase_index, frozen_phase)
	assert_eq(director.beat_index, frozen_beat)
	assert_eq(director.pending_count(), pending_before)
	assert_eq(director.hazard_pending_count(), hazards_pending_before)
	assert_eq(director.ledger.pending_count(), reservations_before)
	assert_eq(city.encounter_runtime.attack_gate_enabled, attack_gate_before)
	assert_eq(siege.hazards.active_count(), 0)
	assert_eq(siege.catalysts.active_count(), 0)
	assert_false(siege.directives.is_active())
	assert_eq(siege.trait_runtime.command_source, siege.boss_session.boss)
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		if interval_before.has(enemy.get_instance_id()):
			assert_almost_eq(
				enemy.external_attack_interval_multiplier,
				interval_before[enemy.get_instance_id()],
				0.0001
			)
	assert_true(city.robot.can_request_attack())
	assert_false(siege.is_simulation_paused())
	assert_true(campaign.active_gate.blocker_collision.disabled)
	assert_true(city.world_stream._rear_barrier_collision.disabled)
	assert_eq(city.robot.collision_mask & CityWorldStream.REAR_BARRIER_LAYER, 0)
	assert_eq(city.robot.collision_mask & CitySlice.BUILDING_LAYER, 0)
	assert_not_null(campaign.arena_barrier)
	assert_true(campaign.arena_barrier.active)
	assert_false(campaign.arena_barrier.collision.disabled)
	assert_eq(city.robot.collision_mask & ARENA_WALL_LAYER, ARENA_WALL_LAYER)
	city.robot.set_physics_process(false)
	city.robot.collision_mask = 0
	city.robot.gravity = 0.0
	var gate_x: float = campaign.active_gate.global_position.x
	city.robot.global_position.x = gate_x - 60.0
	for _movement_step: int in range(120):
		city.robot.physics_step(1.0, 1.0 / 60.0)
	assert_gt(city.robot.global_position.x, gate_x + 60.0)


func test_active_boss_lease_allows_streaming_past_arena_and_back() -> void:
	var city: CitySlice = await _spawn_city()
	var campaign: BossCampaignDirector = city.urban_siege.boss_campaign
	var definition: BossEncounterDefinition = (
		BossCampaignCatalog.definition_for_trigger(
			BossCampaignCatalog.CANONICAL_TRIGGERS[0]
		)
	)
	await _trigger(city, definition)
	var boss_id: int = city.urban_siege.boss_session.boss.get_instance_id()
	var baseline_nodes: int = int(RuntimeBudget.snapshot(city).node_count)
	assert_true(campaign.arena_lease.active)
	assert_true(city.world_stream.resident_lease_active())
	city.robot.global_position.x = (
		city.world_stream.runtime_x_for_logical_index(definition.unlock_chunk)
		+ CityWorldStream.CHUNK_WIDTH * 0.5
	)
	city.world_stream.advance_stream()
	assert_eq(city.world_stream.current_logical_chunk, definition.unlock_chunk)
	assert_eq(city.urban_siege.boss_session.boss.get_instance_id(), boss_id)
	city.robot.global_position.x = (
		city.world_stream.runtime_x_for_logical_index(2)
		+ CityWorldStream.CHUNK_WIDTH * 0.5
	)
	city.world_stream.advance_stream()
	assert_eq(city.world_stream.current_logical_chunk, 2)
	assert_eq(city.urban_siege.boss_session.boss.get_instance_id(), boss_id)
	assert_eq(int(RuntimeBudget.snapshot(city).node_count), baseline_nodes)


func test_every_boss_uses_one_close_right_flank_wall_that_drops_on_body_defeat() -> void:
	var city: CitySlice = await _spawn_city()
	var campaign: BossCampaignDirector = city.urban_siege.boss_campaign
	var definition: BossEncounterDefinition = (
		BossCampaignCatalog.definition_for_trigger(
			BossCampaignCatalog.CANONICAL_TRIGGERS[0]
		)
	)
	await _trigger(city, definition)
	var boss: TankEnemy = city.urban_siege.boss_session.boss
	var barrier: BossArenaBarrier2D = campaign.arena_barrier
	assert_true(barrier.active)
	assert_false(barrier.collision.disabled)
	assert_almost_eq(
		barrier.global_position.x,
		boss.global_position.x + BossArenaBarrier2D.OFFSET_FROM_BOSS_X,
		0.001
	)
	assert_almost_eq(
		BossArenaBarrier2D.OFFSET_FROM_BOSS_X,
		BossRig2D.DEFAULT_DISPLAY_SIZE.x
		* BossRig2D.CAMPAIGN_PRESENTATION_SCALE
		* 0.5
		+ 130.0,
		0.001
	)
	for catalog_definition: BossEncounterDefinition in BossCampaignCatalog.definitions():
		assert_eq(
			BossRig2D.presentation_scale_for_preset(catalog_definition.rig_preset),
			BossRig2D.CAMPAIGN_PRESENTATION_SCALE,
			String(catalog_definition.boss_id)
		)
	assert_eq(city.robot.collision_mask & ARENA_WALL_LAYER, ARENA_WALL_LAYER)
	assert_true(boss.receive_damage(DamageEvent.new(
		83_001, city.robot, definition.armor, &"bullet"
	)))
	assert_true(boss.receive_damage(DamageEvent.new(
		83_002, city.robot, definition.health, &"impact"
	)))
	assert_false(barrier.active)
	assert_true(barrier.collision.disabled)
	assert_eq(city.robot.collision_mask & ARENA_WALL_LAYER, 0)


func test_success_enters_post_boss_corridor_after_fireworks() -> void:
	var city: CitySlice = await _spawn_city()
	var siege: UrbanSiegeRuntime = city.urban_siege
	var director: DistrictResponseDirector = siege.director
	var campaign: BossCampaignDirector = siege.boss_campaign
	director.stop()
	city.encounter_runtime.release_all()
	director.start()
	director.advance(0.01)
	var definition: BossEncounterDefinition = (
		BossCampaignCatalog.definition_for_trigger(
			BossCampaignCatalog.CANONICAL_TRIGGERS[0]
		)
	)
	await _trigger(city, definition)
	var boss: TankEnemy = siege.boss_session.boss
	assert_true(boss.receive_damage(DamageEvent.new(
		81_001, city.robot, definition.armor, &"bullet"
	)))
	assert_true(boss.receive_damage(DamageEvent.new(
		81_002, city.robot, definition.health, &"impact"
	)))
	assert_not_null(siege.boss_session.boss_wreck)
	city.camera_rig.set_physics_process(false)
	city.camera_rig.global_position.x = (
		city.robot.global_position.x + city.camera_rig.look_ahead
	)
	assert_eq(siege.boss_session.path_clear_camera_reveal_count, 1)
	assert_true(city.camera_rig.path_clear_reveal_active())
	assert_false(city.camera_rig.path_clear_reveal_returning())
	assert_almost_eq(
		city.camera_rig.path_clear_focus_world_x(),
		boss.global_position.x + BossArenaBarrier2D.OFFSET_FROM_BOSS_X,
		0.001
	)
	var reveal_start_x: float = city.camera_rig.global_position.x
	for _step: int in range(12):
		city.camera_rig._physics_process(0.1)
	assert_gt(city.camera_rig.global_position.x, reveal_start_x)
	city.robot.global_position.x += city.camera_rig.path_clear_movement_threshold + 1.0
	city.camera_rig._physics_process(0.1)
	assert_true(city.camera_rig.path_clear_reveal_returning())
	for _step: int in range(60):
		city.camera_rig._physics_process(0.1)
	assert_false(city.camera_rig.path_clear_reveal_active())
	assert_true(siege.boss_session.defeat_celebration_active())
	siege.boss_session.utility_pool.defeat_spectacle.advance(
		BossDefeatSpectacle2D.PRESENTATION_SECONDS - 0.01
	)
	assert_true(siege.boss_session.defeat_celebration_active())
	assert_eq(campaign.handoff_state, BossCampaignDirector.HANDOFF_NONE)
	var ambient: EnemyActor2D = city.encounter_runtime.acquire(
		&"soldier",
		boss.global_position + Vector2(-420.0, 0.0)
	)
	assert_not_null(ambient)
	assert_true(ambient.begin_telegraph(
		&"support",
		30.0,
		ambient.global_position,
		city.robot.global_position
	))
	assert_eq(city.telegraph_presenter.active_count(), 1)
	siege.boss_session.utility_pool.defeat_spectacle.advance(
		0.02
	)
	assert_false(siege.boss_session.defeat_celebration_active())
	assert_false(ambient.is_telegraphing())
	assert_eq(city.telegraph_presenter.active_count(), 0)
	var rubble: Node2D = siege.boss_session.utility_pool.boss_rubble_record
	var rubble_sprite: Sprite2D = rubble.get_child(0) as Sprite2D
	assert_true(rubble.visible)
	assert_almost_eq(rubble.global_position.y, CityStreetChunk.ROAD_DIVIDER_Y, 0.001)
	assert_almost_eq(
		rubble.global_position.y
		+ rubble_sprite.position.y
		+ BossUtilityPool.BOSS_RUBBLE_DISPLAY_SIZE.y * 0.5,
		CityStreetChunk.ROAD_DIVIDER_Y,
		0.001
	)
	assert_null(campaign.get_node_or_null("BossSalvageTrigger2D"))
	city.encounter_runtime.release(ambient)
	assert_eq(campaign.handoff_state, BossCampaignDirector.HANDOFF_NONE)
	assert_eq(director.state, DistrictResponseDirector.STATE_WAITING)
	assert_eq(director.beat_index, -1)
	assert_eq(director.phase_index, 1)
	assert_false(director.is_suspended_for_boss())
	assert_false(campaign.interlock.is_owned())
	assert_false(city.world_stream.resident_lease_active())
	assert_ne(city.robot.collision_mask & CitySlice.BUILDING_LAYER, 0)


func test_direct_handoff_unblocks_district_two_runtime() -> void:
	var city: CitySlice = await _spawn_city()
	var siege: UrbanSiegeRuntime = city.urban_siege
	var director: DistrictResponseDirector = siege.director
	var campaign: BossCampaignDirector = siege.boss_campaign
	director.stop()
	city.encounter_runtime.release_all()
	director.start()
	director.advance(0.01)
	var first_definition: BossEncounterDefinition = (
		BossCampaignCatalog.definition_for_trigger(
			BossCampaignCatalog.CANONICAL_TRIGGERS[0]
		)
	)
	await _trigger(city, first_definition)
	var boss: TankEnemy = siege.boss_session.boss
	assert_true(boss.receive_damage(DamageEvent.new(
		84_001, city.robot, first_definition.armor, &"bullet"
	)))
	assert_true(boss.receive_damage(DamageEvent.new(
		84_002, city.robot, first_definition.health, &"impact"
	)))
	siege.boss_session.utility_pool.defeat_spectacle.advance(
		BossDefeatSpectacle2D.PRESENTATION_SECONDS
	)
	assert_eq(campaign.handoff_state, BossCampaignDirector.HANDOFF_NONE)
	assert_null(campaign.active_definition)
	assert_false(campaign.interlock.is_owned())
	assert_false(director.is_suspended_for_boss())
	assert_eq(director.phase_index, 1)
	assert_eq(city.world_stream.unlocked_district_index, 1)
	assert_false(city.world_stream.resident_lease_active())
	assert_ne(city.robot.collision_mask & CitySlice.BUILDING_LAYER, 0)
	city.encounter_runtime.release_all()
	director.advance(0.01)
	assert_gt(director.pending_count(), 0)
	director.advance(30.0)
	assert_gt(city.encounter_runtime.active_count(), 0)
	var second_definition: BossEncounterDefinition = (
		BossCampaignCatalog.definition_for_trigger(
			BossCampaignCatalog.CANONICAL_TRIGGERS[1]
		)
	)
	await _trigger(city, second_definition)
	assert_eq(campaign.active_definition, second_definition)
	assert_eq(siege.boss_session.active_definition, second_definition)


func test_completion_write_failure_retains_gate_then_retries_idempotently() -> void:
	var city: CitySlice = await _spawn_city()
	var campaign: BossCampaignDirector = city.urban_siege.boss_campaign
	var definition: BossEncounterDefinition = (
		BossCampaignCatalog.definition_for_trigger(
			BossCampaignCatalog.CANONICAL_TRIGGERS[0]
		)
	)
	var gate: BossGateMarker = campaign.gate_for_trigger(definition.trigger_chunk)
	assert_true(gate.acquire(Vector2.ZERO))
	campaign.active_definition = definition
	campaign.active_gate = gate
	assert_true(city.urban_siege.boss_session.start_definition(definition))
	var store: CampaignProgressStore = city.project_choir_runtime.campaign_progress
	store.fault_injection = CampaignProgressStore.FAIL_BEFORE_WRITE
	var session: CommandBossSession = city.urban_siege.boss_session
	assert_true(session.boss.receive_damage(DamageEvent.new(
		82_001, city.robot, definition.armor, &"ground_smash"
	)))
	assert_true(session.boss.receive_damage(DamageEvent.new(
		82_002, city.robot, definition.health, &"impact"
	)))
	session.utility_pool.defeat_spectacle.advance(
		BossDefeatSpectacle2D.PRESENTATION_SECONDS
	)
	assert_true(campaign.completion_pending)
	assert_true(campaign.owns_combat())
	assert_true(campaign.active_gate.owned)
	assert_eq(session.state, CommandBossSession.STATE_COMPLETION_PENDING)
	store.fault_injection = &""
	campaign._process(BossCampaignDirector.COMPLETION_RETRY_SECONDS)
	assert_false(campaign.completion_pending)
	assert_false(campaign.owns_combat())
	assert_true(store.has_evidence(&"LEDGER"))
	assert_eq(store.pending_reward_grants().count("boss:SETTLEMENT_ENGINE_S04:reward"), 1)


func test_stop_and_reset_clear_campaign_and_siege_suspension() -> void:
	var city: CitySlice = await _spawn_city()
	var campaign: BossCampaignDirector = city.urban_siege.boss_campaign
	var definition: BossEncounterDefinition = (
		BossCampaignCatalog.definition_for_trigger(
			BossCampaignCatalog.CANONICAL_TRIGGERS[0]
		)
	)
	await _trigger(city, definition)
	campaign.stop()
	assert_false(campaign.owns_combat())
	assert_false(campaign.interlock.is_owned())
	assert_false(city.urban_siege.director.is_suspended_for_boss())
	assert_false(city.world_stream.resident_lease_active())
	assert_not_null(campaign.arena_barrier)
	assert_false(campaign.arena_barrier.active)
	assert_true(campaign.arena_barrier.collision.disabled)
	assert_eq(city.robot.collision_mask & ARENA_WALL_LAYER, 0)
	assert_false(city.world_stream._rear_barrier_collision.disabled)
	assert_ne(city.robot.collision_mask & CityWorldStream.REAR_BARRIER_LAYER, 0)
	assert_ne(city.robot.collision_mask & CitySlice.BUILDING_LAYER, 0)
	await _trigger(city, definition)
	campaign.reset_run()
	assert_false(campaign.owns_combat())
	assert_false(city.urban_siege.director.is_suspended_for_boss())
	assert_false(campaign.arena_barrier.active)
	assert_eq(
		campaign.gate_for_trigger(BossCampaignCatalog.CANONICAL_TRIGGERS[0]).trigger_count,
		0
	)


func test_campaign_hud_uses_only_localized_name_and_two_durability_bars() -> void:
	var city: CitySlice = await _spawn_city()
	var definition: BossEncounterDefinition = (
		BossCampaignCatalog.definition_for_trigger(
			BossCampaignCatalog.CANONICAL_TRIGGERS[0]
		)
	)
	await _trigger(city, definition)
	var text: String = city.gameplay_hud.boss_label.text
	assert_true(city.gameplay_hud.boss_panel.visible)
	assert_true(city.gameplay_hud.boss_label.visible)
	assert_eq(text, L10n.t(definition.display_name_key))
	assert_false(text.contains("//"))
	assert_false(text.contains("100%"))
	assert_eq(city.gameplay_hud.boss_armor_fill.color, Color("f4c542"))
	assert_eq(city.gameplay_hud.boss_health_fill.color, Color("e3313f"))
	assert_almost_eq(
		city.gameplay_hud.boss_armor_fill.size.x,
		city.gameplay_hud.boss_armor_track.size.x,
		0.001
	)
	assert_almost_eq(
		city.gameplay_hud.boss_health_fill.size.x,
		city.gameplay_hud.boss_health_track.size.x,
		0.001
	)


func test_boss_fight_herald_uses_generated_splash_and_plays_once_per_start() -> void:
	var city: CitySlice = await _spawn_city()
	var definition: BossEncounterDefinition = (
		BossCampaignCatalog.definition_for_trigger(
			BossCampaignCatalog.CANONICAL_TRIGGERS[0]
		)
	)
	await _trigger(city, definition)
	var herald: BossFightHerald = city.gameplay_hud.boss_fight_herald
	assert_true(herald.visible)
	assert_eq(herald.presentation_count, 1)
	assert_eq(herald.audio_play_count, 1)
	assert_eq(herald.splash.texture, BossFightHerald.SPLASH)
	assert_eq(herald.voice_player.stream, BossFightHerald.VOICE)
	await get_tree().create_timer(BossFightHerald.PRESENTATION_SECONDS + 0.1).timeout
	assert_false(herald.visible)


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.urban_siege.run_active = true
	return city


func _prepare_gate_window(city: CitySlice, definition: BossEncounterDefinition) -> void:
	city.world_stream.end_resident_lease(city.urban_siege.boss_campaign.arena_lease)
	city.robot.global_position.x = (
		float(definition.trigger_chunk) * CityWorldStream.CHUNK_WIDTH + 100.0
	)
	city.world_stream.reset_stream(city.world_stream.run_seed)
	await get_tree().process_frame
	city.urban_siege.pause_coordinator.release_all()
	var district: CityDistrictProfile = CityDistrictCatalog.districts()[
		CityDistrictCatalog.district_index_for_chunk(definition.trigger_chunk)
	]
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
		city.world_stream.report_building_cleared(building)
		building.free()


func _trigger(city: CitySlice, definition: BossEncounterDefinition) -> void:
	await _prepare_gate_window(city, definition)
	city.robot.global_position.x = _threshold_x(city, definition) + 1.0
	city.urban_siege.boss_campaign.advance()


func _threshold_x(city: CitySlice, definition: BossEncounterDefinition) -> float:
	return (
		(float(definition.trigger_chunk) + BossCampaignDirector.GATE_APPROACH_FRACTION)
		* CityWorldStream.CHUNK_WIDTH
		- float(city.world_stream.floating_origin.origin_chunk) * CityWorldStream.CHUNK_WIDTH
	)


func _full_charge(city: CitySlice, attack_id: int, amount: float) -> DamageEvent:
	return DamageEvent.new(
		attack_id,
		city.robot,
		amount,
		&"jab_cross",
		Vector2.ZERO,
		Vector2.RIGHT,
		0.0,
		0,
		0,
		DamageEvent.FLAG_FULL_CHARGE
	)
