extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")

var city: CitySlice
var session: CommandBossSession


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	session = city.urban_siege.boss_session


func test_campaign_host_is_hidden_stationary_authority_and_rig_forwards_damage() -> void:
	var definition: BossEncounterDefinition = BossCampaignCatalog.definitions()[0]
	assert_true(session.start_definition(definition))
	var rig: BossRig2D = session.utility_pool.rig
	var host: TankEnemy = session.boss
	assert_true(host.hidden_authority)
	assert_false(host.is_physics_processing())
	assert_false(host.visual.visible)
	assert_eq(host.collision_layer, 0)
	assert_eq(host.collision_mask, 0)
	assert_true(rig.visible)
	assert_eq(rig.host, host)
	assert_eq(rig.active_part_count, 2)
	assert_eq(rig.active_hurt_region_count, BossRig2D.HURT_REGION_CAPACITY)
	var armor_before: float = host.boss_armor
	assert_true(rig.receive_damage(DamageEvent.new(
		3001, city.robot, 40.0, &"bullet"
	)))
	assert_almost_eq(host.boss_armor, armor_before - 40.0, 0.001)
	assert_eq(rig.damage_flash_count, 1)
	assert_eq(rig._presentation_root.modulate, Color(4.0, 4.0, 4.0, 1.0))
	await get_tree().create_timer(0.15).timeout
	assert_eq(rig._presentation_root.modulate, Color.WHITE)
	host.velocity = Vector2(800.0, 200.0)
	await get_tree().physics_frame
	assert_eq(host.velocity, Vector2(800.0, 200.0))


func test_body_defeat_launches_full_pooled_explosion_and_firework_barrage() -> void:
	var definition: BossEncounterDefinition = BossCampaignCatalog.definitions()[0]
	var spectacle: BossDefeatSpectacle2D = session.utility_pool.defeat_spectacle
	var baseline_nodes: int = get_tree().get_node_count()
	assert_eq(spectacle.visual_slot_count(), 22)
	assert_eq(spectacle.particle_emitter_count(), 14)
	assert_eq(spectacle.particle_capacity(), 548)
	assert_eq(spectacle.audio_player_count(), 1)
	assert_true(session.start_definition(definition))
	var host: TankEnemy = session.boss
	assert_true(host.receive_damage(DamageEvent.new(
		30_101, city.robot, definition.armor, &"bullet"
	)))
	assert_true(host.receive_damage(DamageEvent.new(
		30_102, city.robot, definition.health, &"impact"
	)))
	assert_true(spectacle.active)
	assert_eq(spectacle.activation_count, 1)
	assert_eq(spectacle.audio_play_count, 1)
	assert_eq(spectacle.audio_player.bus, GameAudioBus.SFX)
	assert_eq(spectacle.audio_player.global_position, spectacle.global_position)
	assert_gt(city.camera_rig.impact_velocity.length(), 0.0)
	assert_gte(spectacle.explosion_trigger_count, 1)
	assert_true(spectacle.explosion_emitters.any(
		func(particles: GPUParticles2D) -> bool: return particles.emitting
	))
	assert_almost_eq(
		BossDefeatSpectacle2D.PRESENTATION_SECONDS,
		BossDefeatSpectacle2D.FIREWORK_TIMES[-1]
		+ BossDefeatSpectacle2D.FIREWORK_PARTICLE_LIFETIME
		+ BossDefeatSpectacle2D.COMPLETION_SETTLE_SECONDS,
		0.001
	)
	spectacle.advance(2.05)
	assert_eq(spectacle.explosion_trigger_count, 12)
	assert_eq(spectacle.firework_trigger_count, 10)
	assert_eq(spectacle.post_warm_creation_count, 0)
	assert_eq(get_tree().get_node_count(), baseline_nodes)
	spectacle.advance(
		BossDefeatSpectacle2D.PRESENTATION_SECONDS - spectacle.elapsed - 0.01
	)
	assert_true(spectacle.active)
	assert_eq(session.state, CommandBossSession.STATE_WRECK)
	assert_not_null(session.boss_wreck)
	spectacle.advance(0.02)
	assert_false(spectacle.active)
	assert_eq(session.state, CommandBossSession.STATE_COMPLETE)
	assert_eq(session.automatic_rubble_commit_count, 1)
	assert_null(session.boss_wreck)
	assert_true(session.utility_pool.boss_rubble_record.visible)
	assert_eq(session.last_repair_drop_count, 2)


func test_every_rig_preset_reuses_parts_sockets_and_hurt_regions_in_place() -> void:
	var rig: BossRig2D = session.utility_pool.rig
	var part_ids: PackedInt64Array = _node_ids(rig.parts)
	var socket_ids: PackedInt64Array = _node_ids(rig.sockets)
	var region_ids: PackedInt64Array = _node_ids(rig.hurt_regions)
	for definition: BossEncounterDefinition in BossCampaignCatalog.definitions():
		assert_true(session.start_definition(definition), String(definition.boss_id))
		assert_eq(_node_ids(rig.parts), part_ids)
		assert_eq(_node_ids(rig.sockets), socket_ids)
		assert_eq(_node_ids(rig.hurt_regions), region_ids)
		assert_not_null(rig.socket(&"WEAK_POINT"))
		assert_not_null(rig.parts[0].texture)
		assert_eq(rig.mechanical_signature().active_hurt_regions, 3)
		session.stop()


func test_hidden_authority_restores_when_tank_pool_slot_is_reused() -> void:
	assert_true(session.start_definition(BossCampaignCatalog.definitions()[0]))
	var hidden_host: TankEnemy = session.boss
	assert_true(hidden_host.hidden_authority)
	session.stop()
	assert_false(hidden_host.hidden_authority)
	var reused: TankEnemy = city.encounter_runtime.acquire(
		&"tank",
		Vector2(900.0, 551.0),
		&"ANCHOR_TANK",
		&"COMMAND"
	) as TankEnemy
	assert_eq(reused, hidden_host)
	assert_false(reused.hidden_authority)
	assert_true(reused.is_physics_processing())
	assert_true(reused.visual.visible)
	assert_false((reused.get_node(^"CollisionShape2D") as CollisionShape2D).disabled)
	assert_false((
		reused.get_node(^"Hurtbox/CollisionShape2D") as CollisionShape2D
	).disabled)


func test_portrait_changes_presentation_only_not_mechanics_or_phase_timing() -> void:
	var definition: BossEncounterDefinition = BossCampaignCatalog.definitions()[1]
	assert_true(session.start_definition(definition))
	var rig: BossRig2D = session.utility_pool.rig
	rig.configure_orientation(false)
	var landscape_mechanics: Dictionary = rig.mechanical_signature()
	var landscape_presentation: Dictionary = rig.presentation_signature()
	rig.configure_orientation(true)
	var portrait_mechanics: Dictionary = rig.mechanical_signature()
	var portrait_presentation: Dictionary = rig.presentation_signature()
	assert_eq(portrait_mechanics, landscape_mechanics)
	assert_ne(portrait_presentation.scale, landscape_presentation.scale)
	for phase: BossPhaseDefinition in definition.phases:
		assert_eq(phase.recovery_duration, 0.75)
		assert_eq(phase.minimum_safe_gap, 192.0)


func test_both_bound_facades_cover_all_64_masks_with_required_routes() -> void:
	var adapter: BossStructuralAdapter = session.utility_pool.arena_adapter
	var row_count: int = 0
	for definition: BossEncounterDefinition in BossCampaignCatalog.definitions():
		assert_true(adapter.all_masks_valid(definition.arena_cell_indices))
		for mask: int in range(BossStructuralAdapter.MASK_COUNT):
			var binding: Dictionary = adapter.binding_for_mask(
				mask,
				definition.arena_cell_indices
			)
			assert_true(binding.lower_passage, "%s mask=%d" % [definition.boss_id, mask])
			assert_true(binding.visible_weak_point, "%s mask=%d" % [definition.boss_id, mask])
			assert_true(binding.direct_damage_route, "%s mask=%d" % [definition.boss_id, mask])
			assert_true(binding.valid_finisher_receiver, "%s mask=%d" % [definition.boss_id, mask])
			if mask == BossStructuralAdapter.MASK_COUNT - 1:
				assert_true(binding.fallback_conductor)
			row_count += 1
	assert_eq(row_count, 128)


func test_phase_helpers_cleanup_support_projectiles_and_utility_reservations() -> void:
	var pool: BossUtilityPool = session.utility_pool
	var runtime: BossPhaseRuntime = pool.controller
	var phase: BossPhaseDefinition = BossPhaseDefinition.new()
	phase.phase_id = &"WP3_PHASE"
	phase.attack_choices = PackedStringArray(["test"])
	phase.telegraph_profile = &"BOSS_STANDARD"
	phase.reservation_requirements = {&"procedural_light": 1}
	var baseline_projectile_reservations: int = city.projectile_root.reservation_count()
	for loop_index: int in range(25):
		var token: int = pool.begin_generation()
		assert_true(runtime.begin_phase(phase, token))
		var support: EnemyActor2D = runtime.acquire_support(
			&"jackal",
			Vector2(900.0, 551.0)
		)
		assert_not_null(support)
		assert_gt(runtime.reserve_projectile(&"shell"), 0)
		assert_gt(runtime.reservation_count(), 0)
		pool.begin_generation()
		assert_eq(runtime.reservation_count(), 0)
		assert_eq(pool.reservation_count(), 0)
		assert_eq(city.projectile_root.reservation_count(), baseline_projectile_reservations)
		assert_false(support.active)


func test_safe_gap_validation_is_order_independent_and_exact_at_threshold() -> void:
	var intervals: Array[Vector2] = [
		Vector2(300.0, 500.0),
		Vector2(0.0, 120.0),
		Vector2(700.0, 1000.0),
	]
	assert_eq(BossPhaseRuntime.safe_gap_width(intervals, Vector2(0.0, 1000.0)), 200.0)
	assert_true(BossPhaseRuntime.has_safe_gap(intervals, Vector2(0.0, 1000.0), 200.0))
	assert_false(BossPhaseRuntime.has_safe_gap(intervals, Vector2(0.0, 1000.0), 201.0))


func test_boss_attack_area_damages_once_only_while_armed() -> void:
	assert_true(session.start_definition(BossCampaignCatalog.definitions()[0]))
	var area: BossAttackArea2D = session.utility_pool.lane_damage_areas[0]
	var health_before: float = city.robot.current_health
	area.configure_footprint(
		city.robot.global_position,
		Vector2(300.0, 120.0),
		BossAttackArea2D.VisualState.TELEGRAPH,
		&"TEST_BOSS_HAZARD"
	)
	assert_false(area.try_damage_body(city.robot))
	assert_almost_eq(city.robot.current_health, health_before, 0.001)
	area.configure_footprint(
		city.robot.global_position,
		Vector2(300.0, 120.0),
		BossAttackArea2D.VisualState.ARMED,
		&"TEST_BOSS_HAZARD"
	)
	assert_true(area.try_damage_body(city.robot))
	assert_almost_eq(
		city.robot.current_health,
		health_before
		- BossAttackArea2D.DEFAULT_DAMAGE
			* EnemyActor2D.ENEMY_DAMAGE_MULTIPLIER
			* BossEncounterDefinition.OUTGOING_DAMAGE_MULTIPLIER,
		0.001
	)
	assert_false(area.try_damage_body(city.robot))
	area.deactivate()
	assert_false(area.try_damage_body(city.robot))


func test_campaign_hazards_do_not_advance_or_arm_during_screen() -> void:
	assert_true(session.start_definition(BossCampaignCatalog.definitions()[0]))
	var slice: BossVerticalSliceController = session.utility_pool.vertical_slice
	var initial_attack: StringName = slice.active_attack
	session.advance(session.active_definition.screen_seconds)
	assert_eq(session.state, CommandBossSession.STATE_BARRAGE)
	assert_eq(slice.active_attack, initial_attack)
	assert_eq(slice.attack_stage, &"TELEGRAPH")
	session.advance(BossVerticalSliceController.BUSINESS_SHOCKWAVE_TELEGRAPH_SECONDS)
	assert_eq(slice.attack_stage, &"ACTIVE")


func test_wreck_rejects_all_player_damage_then_auto_scraps_after_spectacle() -> void:
	assert_true(session.start_definition(BossCampaignCatalog.definitions()[0]))
	var host: TankEnemy = session.boss
	assert_true(host.receive_damage(DamageEvent.new(
		3100, city.robot, session.active_definition.armor, &"rocket"
	)))
	var fatal: DamageEvent = DamageEvent.new(
		3200,
		city.robot,
		session.active_definition.health,
		&"impact",
		host.global_position,
		Vector2.RIGHT,
		0.0,
		3199
	)
	assert_true(host.receive_damage(fatal))
	var wreck: EnemyWreck2D = session.boss_wreck
	assert_not_null(wreck)
	assert_false(wreck.finisher_requires_ground_smash)
	assert_true(wreck.finisher_damage_types.is_empty())
	assert_false(wreck.receive_damage(DamageEvent.new(
		3200, city.robot, 999.0, &"ground_smash", Vector2.ZERO, Vector2.RIGHT, 0.0, 4000
	)))
	assert_false(wreck.receive_damage(DamageEvent.new(
		3201, city.robot, 999.0, &"ground_smash", Vector2.ZERO, Vector2.RIGHT, 0.0, 3199
	)))
	for kind: StringName in [&"bullet", &"shell", &"rocket", &"impact"]:
		assert_false(wreck.receive_damage(DamageEvent.new(
			3300 + kind.hash() % 100,
			city.robot,
			999.0,
			kind,
			Vector2.ZERO,
			Vector2.RIGHT,
			0.0,
			4300 + kind.hash() % 100
		)))
	assert_false(wreck.receive_damage(DamageEvent.new(
		3400, city.robot, 1.0, &"jab_cross", Vector2.ZERO, Vector2.RIGHT, 0.0, 4400
	)))
	session.utility_pool.defeat_spectacle.advance(
		BossDefeatSpectacle2D.PRESENTATION_SECONDS
	)
	assert_eq(session.state, CommandBossSession.STATE_COMPLETE)
	assert_eq(session.automatic_rubble_commit_count, 1)


func _node_ids(values: Array) -> PackedInt64Array:
	var ids: PackedInt64Array = PackedInt64Array()
	for value: Variant in values:
		ids.append((value as Node).get_instance_id())
	return ids
