extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const DISTRICT: DistrictDefinition = preload("res://resources/siege/district_contact.tres")
const TRANSFORMER: CatalystProfile = preload("res://resources/catalysts/transformer.tres")

var city: CitySlice


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame


func test_contact_resource_has_bounded_pressure_and_recovery() -> void:
	assert_eq(DISTRICT.acts.size(), 2)
	assert_eq(DISTRICT.acts[0].beats.size(), 4)
	for act: DistrictAct in DISTRICT.acts:
		for beat: DistrictBeat in act.beats:
			assert_between(beat.pressure_seconds, 8.0, 15.0)
			assert_between(beat.recovery_seconds, 1.0, 4.0)


func test_reservation_is_atomic_and_cancels_without_growth() -> void:
	city.encounter_runtime.release_all()
	var ledger: CapacityReservationLedger = CapacityReservationLedger.new()
	var beat: DistrictBeat = DISTRICT.acts[0].beats[0]
	var reservation_id: int = ledger.reserve_beat(beat, city.encounter_runtime)
	assert_gt(reservation_id, 0)
	assert_eq(ledger.pending_count(&"needle"), EnemySpawnTuning.QUANTITY_MULTIPLIER)
	assert_eq(city.encounter_runtime.total_count(), RuntimeBudget.ROLE_BADGES)
	ledger.cancel(reservation_id)
	assert_eq(ledger.pending_count(), 0)
	assert_eq(city.encounter_runtime.total_count(), RuntimeBudget.ROLE_BADGES)


func test_timed_director_reinforces_then_opens_recovery_gate() -> void:
	city.encounter_runtime.release_all()
	var director: DistrictResponseDirector = city.urban_siege.director
	director.start()
	director.advance(0.01)
	assert_eq(director.current_beat_id(), &"SCOUT_PROBE")
	director.advance(0.01)
	assert_eq(city.encounter_runtime.active_count(&"needle"), 1)
	director.advance(9.1)
	assert_eq(director.state, DistrictResponseDirector.STATE_RECOVERY)
	assert_false(city.encounter_runtime.attack_gate_enabled)
	director.advance(3.1)
	assert_true(city.encounter_runtime.attack_gate_enabled)


func test_damage_event_lineage_survives_scaled_derivative() -> void:
	var source_event: DamageEvent = DamageEvent.new(
		81,
		city.robot,
		90.0,
		&"ground_smash",
		Vector2.ZERO,
		Vector2.RIGHT,
		200.0,
		17,
		1,
		DamageEvent.FLAG_CATALYST
	)
	var derived: DamageEvent = source_event.scaled(0.5)
	assert_eq(derived.root_attack_id, 17)
	assert_eq(derived.causal_depth, 1)
	assert_eq(derived.effect_flags, DamageEvent.FLAG_CATALYST)


func test_transformer_is_prewarmed_once_and_triggers_from_damage() -> void:
	var catalysts: CatalystRuntime = city.urban_siege.catalysts
	var detonation_stream: AudioStreamWAV = (
		AudioCueRegistry.POWER_BOX_DETONATION_SFX as AudioStreamWAV
	)
	assert_eq(detonation_stream.mix_rate, 48000)
	assert_eq(detonation_stream.format, AudioStreamWAV.FORMAT_QOA)
	assert_false(detonation_stream.stereo)
	assert_between(detonation_stream.get_length(), 1.45, 1.55)
	assert_eq(
		int(AudioCueRegistry.profile(AudioCueRegistry.Cue.POWER_BOX_DETONATION).priority),
		AudioVoicePriority.SIGNATURE
	)
	assert_eq(catalysts.total_count(), 2)
	assert_eq(catalysts.repair_pickup_count(), RuntimeBudget.REPAIR_PICKUP_SLOTS)
	var transformer: Catalyst2D = catalysts.activate(
		0,
		TRANSFORMER,
		Vector2(1100.0, 590.0),
		&"RESIDENTIAL"
	)
	assert_eq(catalysts.active_count(), 1)
	var event: DamageEvent = DamageEvent.new(
		901,
		city.robot,
		100.0,
		&"ground_smash",
		transformer.global_position,
		Vector2.RIGHT,
		400.0
	)
	assert_true(transformer.receive_damage(event))
	assert_true(transformer.spent)
	assert_eq(transformer.trigger_count, 1)
	assert_false(transformer.receive_damage(event))
	var self_pulse: DamageEvent = DamageEvent.new(
		904,
		transformer,
		120.0,
		&"catalyst_pulse",
		transformer.global_position,
		Vector2.UP,
		720.0
	)
	assert_false(transformer.receive_damage(self_pulse))
	assert_false(transformer.discharging)
	assert_eq(catalysts.active_repair_pickup_count(), 1)
	var pickup: ChassisRepairPickup2D = catalysts.repair_pickups[0]
	assert_true(pickup.active)
	assert_eq(pickup.global_position, transformer.global_position + Vector2(0.0, -96.0))
	var score_before_finish: int = city.rampage_session.current_score()
	var debris_before_finish: int = city.debris_pool.active_count()
	var cue_count_before_finish: int = city.impact_feedback_pool.cue_play_count
	var dust_before_finish: int = city.building_section_burst_pool.rubble_dust_spawn_count
	var finishing_event: DamageEvent = DamageEvent.new(
		903,
		city.robot,
		1.0,
		&"ground_smash",
		transformer.global_position,
		Vector2.RIGHT,
		400.0
	)
	assert_true(transformer.receive_damage(finishing_event))
	assert_true(transformer.discharging)
	assert_false(transformer.is_fully_destroyed)
	assert_true(transformer.visual.visible)
	assert_false(transformer.terminal_rubble_active())
	assert_eq(transformer.discharge_count, 1)
	await get_tree().create_timer(Catalyst2D.OBLITERATION_DELAY_SECONDS + 0.02).timeout
	assert_true(transformer.is_fully_destroyed)
	assert_false(transformer.armed)
	assert_false(transformer.visual.visible)
	assert_true(transformer.terminal_rubble_active())
	assert_eq(
		transformer.terminal_rubble_piece_count(),
		DestructibleProp2D.TERMINAL_RUBBLE_PIECE_COUNT
	)
	assert_true(transformer.terminal_rubble.uses_only_rubble_fragments())
	assert_eq(transformer.terminal_rubble.district_id(), &"RESIDENTIAL")
	assert_eq(
		transformer.terminal_rubble.district_tint(),
		PersistentRubbleBed2D.tint_for_district(&"RESIDENTIAL")
	)
	assert_eq(
		city.building_section_burst_pool.rubble_dust_spawn_count,
		dust_before_finish + 1
	)
	assert_eq(city.building_section_burst_pool.last_district_id, &"RESIDENTIAL")
	assert_true(city.building_section_burst_pool.active_slots()[-1].dust_only)
	assert_eq(transformer.collision_layer, 0)
	assert_eq(transformer.trigger_count, 1)
	assert_eq(catalysts.power_box_scrap_burst_count, 1)
	assert_eq(catalysts.power_box_scrap_piece_count, CatalystRuntime.POWER_BOX_SCRAP_PIECES)
	assert_eq(catalysts.power_box_detonation_sfx_count, 1)
	assert_eq(city.impact_feedback_pool.cue_play_count, cue_count_before_finish + 1)
	assert_eq(
		city.impact_feedback_pool.last_cue,
		AudioCueRegistry.Cue.POWER_BOX_DETONATION
	)
	assert_eq(
		city.debris_pool.active_count(),
		debris_before_finish + CatalystRuntime.POWER_BOX_SCRAP_PIECES
	)
	assert_eq(catalysts.power_box_finish_score_count, CatalystRuntime.POWER_BOX_FINISH_POINTS)
	assert_eq(
		city.rampage_session.current_score() - score_before_finish,
		CatalystRuntime.POWER_BOX_FINISH_POINTS
	)
	assert_eq(city.rampage_session.current_multiplier(), 1)
	assert_eq(catalysts.active_repair_pickup_count(), 1)
	city.robot.current_health = city.robot.max_health - 100.0
	assert_true(pickup.try_collect(city.robot))
	assert_almost_eq(city.robot.current_health, city.robot.max_health - 50.0, 0.001)
	assert_false(pickup.active)
	assert_eq(catalysts.active_repair_pickup_count(), 0)
	await get_tree().create_timer(0.5).timeout
	assert_eq(catalysts.pulse_count, 1)
	assert_eq(catalysts.total_count(), 2)
	assert_eq(catalysts.repair_pickup_count(), RuntimeBudget.REPAIR_PICKUP_SLOTS)


func test_full_health_does_not_waste_the_transformer_repair_pickup() -> void:
	var catalysts: CatalystRuntime = city.urban_siege.catalysts
	var transformer: Catalyst2D = catalysts.activate(0, TRANSFORMER, Vector2(900.0, 590.0))
	var event: DamageEvent = DamageEvent.new(
		902,
		city.robot,
		100.0,
		&"ground_smash",
		transformer.global_position,
		Vector2.RIGHT,
		400.0
	)
	assert_true(transformer.receive_damage(event))
	var pickup: ChassisRepairPickup2D = catalysts.repair_pickups[0]
	assert_false(pickup.try_collect(city.robot))
	assert_true(pickup.active)
	catalysts.deactivate_all()
	assert_eq(catalysts.active_repair_pickup_count(), 0)


func test_runtime_budget_includes_fixed_catalyst_and_beat_caps() -> void:
	var snapshot: Dictionary = RuntimeBudget.snapshot(city)
	assert_eq(snapshot.catalyst_total, RuntimeBudget.CATALYST_SLOTS)
	assert_eq(snapshot.repair_pickup_slots, RuntimeBudget.REPAIR_PICKUP_SLOTS)
	assert_lte(snapshot.catalyst_active, RuntimeBudget.ACTIVE_CATALYSTS)
	assert_eq(RuntimeBudget.validation_errors(city).size(), 0)
