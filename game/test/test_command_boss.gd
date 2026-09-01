extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const PLAYER_ATTACK_DAMAGE_TYPES: Array[StringName] = [
	&"jab_cross",
	&"ground_smash",
	&"punch_shockwave",
	&"machine_gun",
	&"missile",
	&"laser",
	&"flamethrower",
	&"tesla_tower",
	&"debris_impact",
]

var city: CitySlice
var session: CommandBossSession


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	session = city.urban_siege.boss_session


func test_boss_reuses_one_tank_and_enters_reserved_barrage() -> void:
	var tank_total: int = city.encounter_runtime.total_count(&"tank")
	assert_true(session.start())
	assert_eq(city.encounter_runtime.total_count(&"tank"), tank_total)
	assert_eq(session.state, CommandBossSession.STATE_SCREEN)
	assert_true(session.boss.boss_mode)
	assert_eq(session.boss.trait_id, &"COMMAND")
	session.advance(CommandBossSession.SCREEN_DURATION)
	assert_eq(session.state, CommandBossSession.STATE_BARRAGE)
	session.boss._begin_shell()
	assert_true(session.boss.is_telegraphing())
	assert_eq(city.telegraph_presenter.active_count(), 0)
	assert_eq(city.projectile_root.reservation_count(&"shell"), 1)


func test_every_player_attack_type_damages_default_boss_armor() -> void:
	assert_true(session.start())
	var boss: TankEnemy = session.boss
	for index: int in range(PLAYER_ATTACK_DAMAGE_TYPES.size()):
		var armor_before: float = boss.boss_armor
		assert_true(boss.receive_damage(DamageEvent.new(
			1001 + index,
			city.robot,
			10.0,
			PLAYER_ATTACK_DAMAGE_TYPES[index]
		)))
		assert_almost_eq(boss.boss_armor, armor_before - 10.0, 0.001)
	assert_true(boss.receive_damage(DamageEvent.new(
		1020, city.robot, boss.boss_armor, &"unregistered_future_player_attack"
	)))
	assert_eq(session.state, CommandBossSession.STATE_EXPOSED)
	assert_almost_eq(boss.boss_armor, 0.0, 0.001)
	assert_true(boss.receive_damage(DamageEvent.new(
		1021, city.robot, 80.0, &"ground_smash"
	)))
	assert_almost_eq(boss.current_health, CommandBossSession.HEALTH - 80.0, 0.001)


func test_every_player_attack_type_damages_every_campaign_boss_armor() -> void:
	var attack_id: int = 1050
	for definition: BossEncounterDefinition in BossCampaignCatalog.definitions():
		assert_true(session.start_definition(definition), String(definition.boss_id))
		assert_eq(
			city.telegraph_presenter.active_count(),
			0,
			String(definition.boss_id)
		)
		var boss: TankEnemy = session.boss
		var rig: BossRig2D = session.utility_pool.rig
		var flash_count_before: int = rig.damage_flash_count
		for damage_type: StringName in PLAYER_ATTACK_DAMAGE_TYPES:
			var armor_before: float = boss.boss_armor
			assert_true(rig.receive_damage(DamageEvent.new(
				attack_id, city.robot, 1.0, damage_type
			)), "%s %s" % [definition.boss_id, damage_type])
			assert_almost_eq(
				boss.boss_armor,
				armor_before - 1.0,
				0.001,
				"%s %s" % [definition.boss_id, damage_type]
			)
			attack_id += 1
		assert_eq(
			rig.damage_flash_count,
			flash_count_before + PLAYER_ATTACK_DAMAGE_TYPES.size()
		)
		session.stop()


func test_jab_cross_event_propagates_full_charge_flag() -> void:
	var resolver: AttackResolver = AttackResolver.new()
	add_child_autofree(resolver)
	var spec: AttackSpec = resolver.resolve_jab_cross(1080, 1, 1.0).with_damage_multiplier(2.0)
	var impact: JabCrossImpact = JabCrossImpact.new()
	add_child_autofree(impact)
	var collider: Node2D = Node2D.new()
	add_child_autofree(collider)
	var event: DamageEvent = impact._make_event(spec, city.robot, collider, session.boss)
	assert_ne(event.effect_flags & DamageEvent.FLAG_FULL_CHARGE, 0)


func test_repeated_default_and_campaign_start_stop_loops_do_not_grow_runtime() -> void:
	var baseline: Dictionary = RuntimeBudget.snapshot(city)
	for loop_index: int in range(25):
		assert_true(
			session.start()
			if loop_index % 2 == 0
			else session.start_definition(BossCampaignCatalog.definitions()[loop_index % 5])
		)
		session.stop()
	var after: Dictionary = RuntimeBudget.snapshot(city)
	assert_eq(after.node_count, baseline.node_count)
	assert_eq(after.enemy_total, baseline.enemy_total)
	assert_eq(after.wreck_total, baseline.wreck_total)
	assert_eq(after.boss_rigs, 1)
	assert_eq(after.boss_controllers, 1)
	assert_eq(after.boss_arena_adapters, 1)
	assert_eq(after.boss_pylon_presentations, 5)
	assert_eq(after.boss_projection_slots, 4)
	assert_eq(after.boss_post_warm_creations, 0)
	assert_eq(after.boss_reservations, 0)


func test_defeated_boss_freezes_then_spectacle_automatically_makes_rubble_and_drops() -> void:
	var definition: BossEncounterDefinition = BossCampaignCatalog.definitions()[0]
	assert_true(session.start_definition(definition))
	session.advance(50.0)
	var boss: TankEnemy = session.boss
	boss.receive_damage(DamageEvent.new(
		1100, city.robot, definition.armor, &"jab_cross"
	))
	boss.receive_damage(DamageEvent.new(
		1101, city.robot, definition.health, &"impact"
	))
	assert_eq(session.state, CommandBossSession.STATE_WRECK)
	assert_not_null(session.boss_wreck)
	assert_eq(city.enemy_remains_factory.active_count(), 1)
	var defeated_pose: Dictionary = session.utility_pool.rig.animation_signature()
	assert_true(defeated_pose.defeated)
	assert_eq(defeated_pose.frame, BossAnimationCatalog.FRAME_COUNT - 1)
	assert_eq(defeated_pose.modulate, BossRig2D.DEFEATED_MODULATE)
	assert_false(session.boss_wreck.get_node(^"WreckVisual").visible)
	assert_false(session.boss_wreck.receive_damage(DamageEvent.new(
		1102, city.robot, 999.0, &"jab_cross"
	)))
	session.utility_pool.defeat_spectacle.advance(
		BossDefeatSpectacle2D.PRESENTATION_SECONDS
	)
	assert_eq(session.state, CommandBossSession.STATE_COMPLETE)
	assert_eq(session.automatic_rubble_commit_count, 1)
	assert_between(session.elapsed_seconds, 45.0, 75.0)
	assert_eq(city.enemy_remains_factory.total_count(), RuntimeBudget.WRECKS)
	assert_true(session.utility_pool.boss_rubble_record.visible)
	assert_eq(
		int(session.utility_pool.boss_rubble_record.get_meta(&"presentation_role")),
		BossUtilityPool.UtilityPresentationRole.RUBBLE_BED
	)
	assert_eq(session.last_repair_drop_count, 2)
	assert_eq(city.urban_siege.catalysts.active_repair_pickup_count(), 2)
	city.robot.current_health = city.robot.max_health - 200.0
	assert_eq(city.urban_siege.catalysts.repair_pickups[0].repair_amount, 150.0)
	assert_true(city.urban_siege.catalysts.repair_pickups[0].try_collect(city.robot))
	assert_almost_eq(city.robot.current_health, city.robot.max_health - 50.0, 0.001)


func test_late_boss_rubble_has_three_fixed_one_fifty_hp_drops() -> void:
	assert_eq(ChassisRepairPickup2D.REPAIR_AMOUNT, 50.0)
	assert_eq(
		city.urban_siege.catalysts.repair_pickup_count(),
		CatalystRuntime.REPAIR_PICKUP_CAPACITY
	)
	assert_true(session.start_definition(BossCampaignCatalog.definitions()[2]))
	assert_eq(session._boss_repair_drop_count(), 3)
	assert_eq(session._spawn_boss_repair_pickups(Vector2(1200.0, 610.0), 3), 3)
	assert_eq(city.urban_siege.catalysts.active_repair_pickup_count(), 3)
	for pickup: ChassisRepairPickup2D in city.urban_siege.catalysts.repair_pickups:
		if pickup.active:
			assert_eq(pickup.repair_amount, 150.0)
