extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_ready_consumes_once_and_active_blocks_meter_changes() -> void:
	var meter: MomentumMeter = MomentumMeter.new()
	add_child_autofree(meter)
	meter.apply_event(_momentum_event(&"ready", 100.0))
	assert_true(meter.is_ready())
	assert_true(meter.consume_ready())
	assert_false(meter.is_ready())
	assert_eq(meter.value, 0.0)
	assert_false(meter.consume_ready())
	meter.set_overdrive_active(true)
	meter.apply_event(_momentum_event(&"blocked", 30.0))
	meter.advance_motion(1.0, 1.0)
	assert_eq(meter.value, 0.0)
	meter.set_overdrive_active(false)
	meter.advance_motion(1.0, 1.0)
	assert_eq(meter.value, 12.0)


func test_next_smash_activates_four_seconds_with_immutable_modifiers() -> void:
	var city: CitySlice = await _spawn_city()
	city.rampage_session.momentum_meter.apply_event(_momentum_event(&"city_ready", 100.0))
	city.robot.velocity.x = city.robot.max_speed * 0.8
	var base_force: float = city.contextual_attacks.resolver.jab_cross_impulse_per_mass
	var base_structure: float = city.contextual_attacks.resolver.jab_cross_structural_damage
	var attack_id: int = city.contextual_attacks.request_attack()
	assert_gt(attack_id, 0)
	assert_true(city.overdrive_session.active)
	assert_eq(city.overdrive_session.activation_count, 1)
	assert_eq(city.overdrive_session.remaining, 4.0)
	assert_false(city.overdrive_session.has_method("_draw"))
	assert_false(ResourceLoader.exists("res://art/presentation/overdrive_ring.png"))
	assert_true(city.contextual_attacks.current_spec.opening_compression)
	assert_almost_eq(
		city.contextual_attacks.current_spec.impulse_per_mass,
		base_force * 1.25,
		0.001
	)
	assert_almost_eq(
		city.contextual_attacks.current_spec.structural_damage,
		base_structure * 1.25,
		0.001
	)
	assert_almost_eq(city.robot.acceleration_multiplier, 1.15, 0.001)
	assert_false(city.overdrive_session.consume_ready_for_attack(attack_id + 1))
	city.contextual_attacks.cancel_attack()


func test_overdrive_does_not_grant_invulnerability_and_restores_modifiers() -> void:
	var city: CitySlice = await _spawn_city()
	city.rampage_session.momentum_meter.apply_event(_momentum_event(&"ready_damage", 100.0))
	assert_true(city.overdrive_session.consume_ready_for_attack(501))
	var health_before: float = city.robot.current_health
	assert_true(city.robot.receive_damage(DamageEvent.new(
		502,
		city.tank,
		18.0,
		&"shell",
		city.robot.global_position
	)))
	assert_eq(city.robot.current_health, health_before - 18.0)
	city.overdrive_session._process(4.0)
	assert_false(city.overdrive_session.active)
	assert_eq(city.overdrive_session.remaining, 0.0)
	assert_almost_eq(city.robot.acceleration_multiplier, 1.0, 0.001)


func test_rare_event_rows_cap_at_three_and_counts_accumulate() -> void:
	var tracker: RareEventTracker = RareEventTracker.new()
	add_child_autofree(tracker)
	assert_true(tracker.register_event(_tagged_event(&"air1", GameplayEvent.AIR_DEBRIS_HIT)))
	assert_true(tracker.register_event(_tagged_event(&"chain", GameplayEvent.CHAIN_COLLAPSE)))
	assert_true(tracker.register_event(_tagged_event(&"tank", GameplayEvent.TANK_SCRAP)))
	assert_true(tracker.register_event(_tagged_event(&"air2", GameplayEvent.AIR_DEBRIS_HIT)))
	var tags: PackedStringArray = tracker.visible_text()
	assert_eq(tags.size(), 3)
	assert_true(tags[0].begins_with("SKYBREAKER"))
	assert_eq(tracker.counts[&"SKYBREAKER"], 2)


func test_summary_freezes_once_and_late_events_cannot_mutate_it() -> void:
	var session: RampageSession = RampageSession.new()
	add_child_autofree(session)
	assert_true(session.publish(GameplayEvent.new(
		&"score_before",
		10,
		GameplayEvent.Kind.PROP_DESTROYED,
		GameplayEvent.PROP_BREAK,
		100,
		6.0,
		true
	)))
	var summary: RunSummarySnapshot = session.freeze_summary(4, 1)
	assert_eq(summary.score, 100)
	assert_true(session.publish(GameplayEvent.new(
		&"score_after",
		11,
		GameplayEvent.Kind.PROP_DESTROYED,
		GameplayEvent.PROP_BREAK,
		500,
		6.0,
		true
	)))
	assert_eq(session.freeze_summary(1, 9), summary)
	assert_eq(summary.score, 100)
	assert_eq(summary.waves_cleared, 4)
	assert_eq(summary.overdrive_activations, 1)


func test_game_over_summary_omits_strongest_and_weakest_metrics() -> void:
	var city: CitySlice = await _spawn_city()
	var summary: RunSummarySnapshot = city.rampage_session.freeze_summary(2, 0)
	city.gameplay_hud.show_game_over(summary)
	assert_eq(city.gameplay_hud.overlay_title.text, "GAME OVER")
	assert_false(city.gameplay_hud.overlay_summary.text.contains("STRONGEST"))
	assert_false(city.gameplay_hud.overlay_summary.text.contains("WEAKEST"))
	city.gameplay_hud.show_district_complete(summary)
	assert_true(city.gameplay_hud.overlay_summary.text.contains("STRONGEST"))
	assert_true(city.gameplay_hud.overlay_summary.text.contains("WEAKEST"))


func test_district_completion_shows_frozen_summary_and_disables_play() -> void:
	var city: CitySlice = await _spawn_city()
	city.run_lifecycle._on_district_completed()
	assert_false(city.weapon_shop_assembler.session.active)
	assert_false(city.game_over_active)
	assert_true(city.gameplay_hud.game_over_overlay.visible)
	assert_eq(city.gameplay_hud.overlay_title.text, "NEW GAME + READY")
	assert_true(city.gameplay_hud.continue_button.visible)
	city.run_lifecycle._on_extract_pressed()
	assert_true(city.game_over_active)
	assert_eq(city.gameplay_hud.overlay_title.text, "DISTRICT CLEARED")
	assert_true(city.gameplay_hud.overlay_summary.text.contains("ACTS 2/2"))
	assert_true(city.gameplay_hud.overlay_summary.text.contains("GRADE"))
	assert_false(city.mobile_controls.joystick_active)
	assert_eq(city.projectile_root.active_count(), 0)
	assert_eq(city.telegraph_presenter.active_count(), 0)


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	city.mobile_detection_override = 1
	add_child_autofree(city)
	await get_tree().process_frame
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	return city


func _momentum_event(key: StringName, delta: float) -> GameplayEvent:
	return GameplayEvent.new(
		key,
		0,
		GameplayEvent.Kind.DAMAGE_APPLIED,
		&"",
		0,
		delta
	)


func _tagged_event(key: StringName, tag: StringName) -> GameplayEvent:
	return GameplayEvent.new(
		key,
		0,
		GameplayEvent.Kind.DAMAGE_APPLIED,
		tag
	)
