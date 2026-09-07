extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_armor_preserves_missing_health_and_never_revives() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var armor: ArmorPlatingRuntime = (
		city.upgrade_assembler.runtimes[&"ARMOR_PLATING"] as ArmorPlatingRuntime
	)
	city.robot.current_health = 640.0
	var health_emissions: Array[int] = [0]
	city.robot.health_changed.connect(
		func(_current: float, _maximum: float) -> void:
			health_emissions[0] += 1
	)
	assert_true(armor.apply_rank(1))
	assert_eq(city.robot.max_health, 880.0)
	assert_eq(city.robot.current_health, 720.0)
	assert_eq(health_emissions[0], 1)
	assert_false(armor.apply_rank(1))
	assert_eq(health_emissions[0], 1)
	assert_true(armor.apply_rank(5))
	assert_eq(city.robot.max_health, 1200.0)
	assert_eq(city.robot.current_health, 1040.0)
	assert_eq(health_emissions[0], 2)
	city.robot.current_health = 0.0
	assert_true(city.robot.set_durability_bonus(320.0))
	assert_eq(city.robot.max_health, 1120.0)
	assert_eq(city.robot.current_health, 0.0)


func test_engine_uses_immutable_baselines_and_preserves_signed_ratio() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var engine: EngineUpgradeRuntime = (
		city.upgrade_assembler.runtimes[&"ENGINE"] as EngineUpgradeRuntime
	)
	city.robot.velocity.x = -130.0
	assert_true(engine.apply_rank(1))
	assert_almost_eq(city.robot.max_speed, 280.8, 0.001)
	assert_almost_eq(city.robot.velocity.x, -140.4, 0.001)
	assert_almost_eq(city.robot.ground_acceleration, 2016.0, 0.001)
	assert_almost_eq(city.robot.air_acceleration, 1008.0, 0.001)
	assert_almost_eq(city.robot.ground_deceleration, 2376.0, 0.001)
	assert_true(engine.apply_rank(3))
	assert_almost_eq(city.robot.max_speed, 322.4, 0.001)
	assert_almost_eq(city.robot.velocity.x, -161.2, 0.001)
	assert_almost_eq(city.robot.ground_acceleration, 2448.0, 0.001)
	assert_almost_eq(city.robot.air_acceleration, 1224.0, 0.001)
	assert_almost_eq(city.robot.ground_deceleration, 2728.0, 0.001)
	city.robot.velocity.x = 400.0
	assert_true(city.robot.set_engine_multipliers(1.16, 1.24, 1.16))
	assert_eq(city.robot.velocity.x, 400.0)
	assert_false(city.robot.set_engine_multipliers(1.16, 1.24, 1.16))


func test_dash_amplifier_extends_range_and_duration_from_immutable_baselines() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.robot.set_physics_process(false)
	city.robot.collision_mask = 0
	city.robot.gravity = 0.0
	city.robot.global_position = Vector2(200.0, 460.0)
	var dash: DashAmplifierRuntime = (
		city.upgrade_assembler.runtimes[&"DASH_AMPLIFIER"] as DashAmplifierRuntime
	)
	var presenter: RobotAnimationPresenter = (
		city.robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	assert_true(dash.apply_rank(1))
	assert_almost_eq(city.robot.dodge_speed, 1123.2, 0.001)
	assert_almost_eq(city.robot.dodge_duration, 0.207, 0.001)
	assert_almost_eq(presenter.dust_intensity_scale, 1.2, 0.001)
	assert_true(dash.apply_rank(3))
	assert_almost_eq(city.robot.dodge_speed, 1289.6, 0.001)
	assert_almost_eq(city.robot.dodge_duration, 0.261, 0.001)
	assert_almost_eq(presenter.dust_intensity_scale, 1.8, 0.001)
	presenter._spawn_dodge_dust(1.20)
	assert_almost_eq(presenter._dust_pool.last_intensity, 2.16, 0.001)
	assert_almost_eq(
		city.robot.dodge_speed * city.robot.dodge_duration,
		336.5856,
		0.001
	)
	assert_false(dash.apply_rank(3))
	assert_true(city.robot._start_dodge())
	assert_almost_eq(city.robot.velocity.x, city.robot.dodge_speed, 0.001)
	city.robot.physics_step(0.0, city.robot.dodge_duration)
	assert_true(city.robot.dodge_invulnerable)
	assert_almost_eq(city.robot.dodge_invulnerability_remaining, 0.039, 0.002)
	assert_almost_eq(city.robot.dodge_recovery_remaining, 0.12, 0.002)
	assert_false(city.robot._start_dodge())
	city.robot.physics_step(0.0, 0.04)
	assert_false(city.robot.dodge_invulnerable)
	assert_true(city.robot.receive_damage(DamageEvent.new(55_001, null, 20.0)))
	city.robot.physics_step(0.0, 0.08)
	assert_false(city.robot._start_dodge())
	city.robot.physics_step(0.0, 0.82)
	assert_true(city.robot.dodge_ready)
	assert_true(city.robot._start_dodge())
	dash.reset_run()
	assert_eq(dash.current_rank, 0)
	assert_almost_eq(city.robot.dodge_speed, 1040.0, 0.001)
	assert_almost_eq(city.robot.dodge_duration, 0.18, 0.001)
	assert_almost_eq(presenter.dust_intensity_scale, 1.0, 0.001)


func test_kinetic_decorates_once_and_directive_flags_are_ored() -> void:
	var runtime: KineticFieldRuntime = KineticFieldRuntime.new()
	add_child_autofree(runtime)
	assert_true(runtime.apply_rank(3))
	var base: AttackSpec = AttackSpec.new(
		AttackSpec.Mode.JAB_CROSS,
		77,
		1,
		0.8,
		0.05,
		0.1,
		0.2,
		145.0,
		125.0,
		1080.0,
		Vector2(190.0, 150.0),
		Vector2(105.0, 62.0),
		false,
		DamageEvent.FLAG_CATALYST
	)
	var decorated: AttackSpec = runtime.decorate_attack(base)
	assert_almost_eq(decorated.actor_damage, 188.5, 0.001)
	assert_almost_eq(decorated.structural_damage, 162.5, 0.001)
	assert_eq(decorated.kinetic_debris_bonus, 6.0)
	assert_eq(
		decorated.effect_flags & DamageEvent.FLAG_KINETIC_FIELD,
		DamageEvent.FLAG_KINETIC_FIELD
	)
	assert_eq(
		decorated.effect_flags & DamageEvent.FLAG_CATALYST,
		DamageEvent.FLAG_CATALYST
	)
	assert_same(runtime.decorate_attack(decorated), decorated)
	var directive: DirectiveSession = DirectiveSession.new()
	add_child_autofree(directive)
	var profile: DirectiveProfile = DirectiveProfile.new()
	profile.directive_id = &"DEMOLITION_BREACH"
	profile.duration_seconds = 10.0
	profile.target_count = 2
	profile.structural_multiplier = 1.35
	profile.effect_flag = DamageEvent.FLAG_DIRECTIVE_BREACH
	assert_true(directive.select(profile))
	var combined: AttackSpec = directive.decorate_attack(decorated)
	assert_almost_eq(combined.structural_damage, 219.375, 0.001)
	assert_eq(combined.kinetic_debris_bonus, 6.0)
	assert_eq(
		combined.effect_flags & DamageEvent.FLAG_DIRECTIVE_BREACH,
		DamageEvent.FLAG_DIRECTIVE_BREACH
	)
	var smash: AttackSpec = AttackSpec.new(
		AttackSpec.Mode.GROUND_SMASH,
		78,
		1,
		0.0,
		0.1,
		0.01,
		0.2,
		180.0,
		180.0,
		1020.0,
		Vector2(640.0, 640.0),
		Vector2.ZERO
	)
	assert_almost_eq(runtime.decorate_attack(smash).actor_damage, 234.0, 0.001)


func test_kinetic_ground_smash_launches_debris_without_an_air_target() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.deactivate()
	var options: DamageQueryOptions = DamageQueryOptions.new()
	options.root_attack_id = 78
	options.effect_flags = DamageEvent.FLAG_KINETIC_FIELD
	options.kinetic_debris_bonus = 6.0
	var launched: int = AerialDebrisLauncher.launch(
		get_tree(),
		city.debris_pool,
		city.robot,
		city.robot.global_position,
		1020.0,
		78,
		options
	)
	assert_eq(launched, AerialDebrisLauncher.LAUNCH_COUNT)
	assert_eq(city.debris_pool.active_count(), AerialDebrisLauncher.LAUNCH_COUNT)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for debris: DebrisBody2D in city.debris_pool.active_bodies():
		assert_false(debris.aerial_impact_armed)
		assert_lt(debris.kinetic_delivery_id(), 0)
		assert_lt(debris.linear_velocity.y, -200.0)
		assert_gt(debris.linear_velocity.length(), 400.0)


func test_kinetic_debris_uses_unique_negative_children_and_shared_root() -> void:
	var runtime: KineticFieldRuntime = KineticFieldRuntime.new()
	add_child_autofree(runtime)
	runtime.apply_rank(3)
	var source: Node = Node.new()
	add_child_autofree(source)
	var source_event: DamageEvent = DamageEvent.new(
		77,
		source,
		100.0,
		&"ground_smash",
		Vector2.ZERO,
		Vector2.UP,
		1000.0,
		77,
		0,
		DamageEvent.FLAG_CATALYST | DamageEvent.FLAG_KINETIC_FIELD,
		6.0
	)
	var first: DebrisBody2D = DebrisBody2D.new()
	var second: DebrisBody2D = DebrisBody2D.new()
	add_child_autofree(first)
	add_child_autofree(second)
	assert_true(runtime.arm_debris(first, source_event))
	assert_true(runtime.arm_debris(second, source_event))
	assert_lt(first.kinetic_delivery_id(), 0)
	assert_lt(second.kinetic_delivery_id(), first.kinetic_delivery_id())
	var enemy: EnemyActor2D = EnemyActor2D.new()
	add_child_autofree(enemy)
	await get_tree().process_frame
	enemy.current_health = 5.0
	var fatal_events: Array[DamageEvent] = []
	enemy.died.connect(
		func(_actor: EnemyActor2D, event: DamageEvent) -> void:
			fatal_events.append(event)
	)
	first.call(&"_on_body_entered", enemy)
	assert_eq(fatal_events.size(), 1)
	assert_eq(fatal_events[0].amount, 10.0)
	assert_eq(fatal_events[0].attack_id, first.kinetic_delivery_id())
	assert_eq(fatal_events[0].root_attack_id, 77)
	assert_eq(fatal_events[0].causal_depth, 1)
	assert_eq(
		fatal_events[0].effect_flags & DamageEvent.FLAG_CATALYST,
		DamageEvent.FLAG_CATALYST
	)
	first.call(&"_on_body_entered", enemy)
	assert_eq(fatal_events.size(), 1)
