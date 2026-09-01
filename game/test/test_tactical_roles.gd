extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const TRANSFORMER: CatalystProfile = preload("res://resources/catalysts/transformer.tres")

var city: CitySlice
var runtime: EncounterRuntime


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	runtime = city.encounter_runtime
	runtime.release_all()


func test_role_and_trait_restore_exactly_on_pool_reuse() -> void:
	var soldier: SoldierEnemy = runtime.acquire(
		&"soldier",
		Vector2(1200.0, 542.5),
		&"SUPPRESSOR",
		&"COMMAND"
	) as SoldierEnemy
	assert_eq(soldier.role_id, &"SUPPRESSOR")
	assert_eq(soldier.trait_id, &"COMMAND")
	assert_almost_eq(soldier.max_health, 67.5, 0.01)
	assert_true(soldier.role_badge.visible)
	runtime.release(soldier)
	var reused: SoldierEnemy = runtime.acquire(&"soldier", Vector2(1250.0, 542.5)) as SoldierEnemy
	assert_eq(reused, soldier)
	assert_eq(reused.role_id, &"BASE")
	assert_eq(reused.trait_id, &"")
	assert_almost_eq(reused.max_health, 60.0, 0.01)
	assert_almost_eq(reused.movement_multiplier, 1.0, 0.001)
	assert_false(reused.role_badge.visible)


func test_only_one_command_trait_can_be_active() -> void:
	var first: EnemyActor2D = runtime.acquire(
		&"soldier", Vector2(1200.0, 542.5), &"SUPPRESSOR", &"COMMAND"
	)
	var second: EnemyActor2D = runtime.acquire(
		&"soldier", Vector2(1300.0, 542.5), &"SUPPRESSOR", &"COMMAND"
	)
	assert_eq(first.trait_id, &"COMMAND")
	assert_eq(second.trait_id, &"")


func test_support_breaker_and_marker_show_honest_snapshot_targets() -> void:
	var tank: TankEnemy = runtime.acquire(
		&"tank", Vector2(1300.0, 551.0), &"SUPPORT_BREAKER"
	) as TankEnemy
	tank._begin_shell()
	assert_true(tank.is_telegraphing())
	assert_eq(tank.telegraph_direction(), tank.telegraph_origin().direction_to(
		city.building.get_cell(1, 1).global_position
	))
	tank.cancel_telegraph()
	var gas: Catalyst2D = city.urban_siege.catalysts.activate(
		1, TRANSFORMER, Vector2(1420.0, 610.0)
	)
	runtime.set_catalyst_target(gas)
	var marker: SoldierEnemy = runtime.acquire(
		&"soldier", Vector2(1200.0, 542.5), &"CATALYST_MARKER"
	) as SoldierEnemy
	marker._begin_fire()
	assert_true(marker.is_telegraphing())
	assert_eq(marker.telegraph_direction(), marker.telegraph_origin().direction_to(
		gas.global_position
	))


func test_command_aura_ends_when_command_actor_dies() -> void:
	var command: EnemyActor2D = runtime.acquire(
		&"soldier", Vector2(1200.0, 542.5), &"SUPPRESSOR", &"COMMAND"
	)
	var wing: EnemyActor2D = runtime.acquire(
		&"soldier", Vector2(1300.0, 542.5), &"ADVANCING_SOLDIER"
	)
	assert_almost_eq(
		wing.external_attack_interval_multiplier,
		EnemyTraitRuntime.COMMAND_INTERVAL_MULTIPLIER,
		0.001
	)
	command.receive_damage(DamageEvent.new(700, city.robot, 999.0))
	assert_almost_eq(wing.external_attack_interval_multiplier, 1.0, 0.001)
	assert_eq(city.urban_siege.trait_runtime.command_break_count, 1)


func test_volatile_pulse_is_single_and_causal_depth_bounded() -> void:
	var volatile: EnemyActor2D = runtime.acquire(
		&"soldier", Vector2(1280.0, 542.5), &"ADVANCING_SOLDIER", &"VOLATILE"
	)
	volatile.receive_damage(DamageEvent.new(800, city.robot, 999.0))
	assert_eq(city.urban_siege.trait_runtime.volatile_pulse_count, 1)
	await get_tree().physics_frame
	runtime.release_all()
	var bounded: EnemyActor2D = runtime.acquire(
		&"soldier", Vector2(1280.0, 542.5), &"ADVANCING_SOLDIER", &"VOLATILE"
	)
	bounded.receive_damage(DamageEvent.new(
		801, city.robot, 999.0, &"impact", Vector2.ZERO, Vector2.RIGHT, 0.0,
		801, DamageEvent.MAX_CAUSAL_DEPTH
	))
	assert_eq(city.urban_siege.trait_runtime.volatile_pulse_count, 1)
