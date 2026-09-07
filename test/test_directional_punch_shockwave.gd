extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_jab_cross_emits_two_fast_directional_waves_only_after_upgrade() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: DirectionalPunchShockwaveRuntime = (
		city.upgrade_assembler.runtimes[&"PUNCH_SHOCKWAVE"]
		as DirectionalPunchShockwaveRuntime
	)
	assert_not_null(runtime)
	assert_eq(runtime.waves.size(), DirectionalPunchShockwaveRuntime.CAPACITY)
	var jab: AttackSpec = _attack(AttackSpec.Mode.JAB_CROSS, 91_001, 1)
	runtime.call(&"_on_attack_active", jab)
	assert_eq(runtime.active_count(), 0)
	assert_true(runtime.apply_rank(1))
	runtime.call(&"_on_attack_active", _attack(AttackSpec.Mode.GROUND_SMASH, 91_002, 1))
	assert_eq(runtime.active_count(), 0)
	runtime.call(&"_on_attack_active", jab)
	assert_eq(runtime.active_count(), 2)
	assert_eq(runtime.spawn_count, 2)
	assert_eq(runtime.waves[0].root_attack_id, jab.attack_id)
	assert_eq(runtime.waves[0].delivery_id, jab.attack_id * 10 + 1)
	assert_eq(runtime.waves[1].delivery_id, jab.attack_id * 10 + 2)
	assert_eq(runtime.waves[0].facing, 1)
	assert_eq(DirectionalShockwave2D.FIST_TEXTURE.get_size(), Vector2(512.0, 288.0))
	assert_eq(DirectionalShockwave2D.FIST_DISPLAY_SIZE, Vector2(168.0, 94.5))
	var visual_root: Node2D = city.robot.get_node(^"VisualRoot") as Node2D
	var base_origin: Vector2 = visual_root.global_position + Vector2(
		DirectionalPunchShockwaveRuntime.FORWARD_OFFSET,
		DirectionalPunchShockwaveRuntime.ORIGIN_Y_OFFSET
	)
	assert_eq(
		runtime.waves[0].global_position,
		base_origin + Vector2(
			0.0,
			-DirectionalPunchShockwaveRuntime.PUNCH_LANE_OFFSET_Y
		)
	)
	assert_eq(
		runtime.waves[1].global_position,
		base_origin + Vector2(
			0.0,
			DirectionalPunchShockwaveRuntime.PUNCH_LANE_OFFSET_Y
		)
	)
	assert_almost_eq(runtime.waves[1].delay_seconds, 0.085, 0.001)
	var first_x: float = runtime.waves[0].global_position.x
	runtime.set_paused(true)
	runtime.waves[0].call(&"_process", 0.1)
	assert_eq(runtime.waves[0].global_position.x, first_x)
	runtime.set_paused(false)
	runtime.waves[0].call(&"_process", 0.1)
	assert_gt(runtime.waves[0].global_position.x, first_x + 100.0)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func test_paired_waves_hit_forward_targets_once_each_and_ignore_rear_targets() -> void:
	var city: CitySlice = await _spawn_city()
	city.robot.global_position = Vector2(520.0, 460.0)
	city.robot.facing = 1
	city.tank.activate(city.robot.global_position + Vector2(330.0, 18.0), city.robot)
	city.tank.max_health = 1000.0
	city.tank.current_health = 1000.0
	city.tank.set_physics_process(false)
	city.soldier.activate(city.robot.global_position + Vector2(-180.0, 18.0), city.robot)
	city.soldier.max_health = 1000.0
	city.soldier.current_health = 1000.0
	city.soldier.set_physics_process(false)
	await get_tree().physics_frame
	var runtime: DirectionalPunchShockwaveRuntime = (
		city.upgrade_assembler.runtimes[&"PUNCH_SHOCKWAVE"]
		as DirectionalPunchShockwaveRuntime
	)
	assert_true(runtime.apply_rank(1))
	var forward_health: float = city.tank.current_health
	var rear_health: float = city.soldier.current_health
	runtime.call(&"_on_attack_active", _attack(AttackSpec.Mode.JAB_CROSS, 92_001, 1))
	for step: int in range(24):
		for wave: DirectionalShockwave2D in runtime.waves:
			if wave.active:
				wave.call(&"_process", 1.0 / 60.0)
	assert_almost_eq(city.tank.current_health, forward_health - 20.0, 0.001)
	assert_eq(city.soldier.current_health, rear_health)
	var accepted_hits: int = 0
	for wave: DirectionalShockwave2D in runtime.waves:
		accepted_hits += wave.accepted_hit_count
	assert_gte(accepted_hits, 2)


func test_directional_wave_pool_strictly_denies_over_capacity_without_growth() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: DirectionalPunchShockwaveRuntime = (
		city.upgrade_assembler.runtimes[&"PUNCH_SHOCKWAVE"]
		as DirectionalPunchShockwaveRuntime
	)
	assert_true(runtime.apply_rank(3))
	var node_count: int = int(RuntimeBudget.snapshot(city).node_count)
	for attack_index: int in range(6):
		runtime.call(
			&"_on_attack_active",
			_attack(AttackSpec.Mode.JAB_CROSS, 93_000 + attack_index, -1)
		)
	assert_eq(runtime.active_count(), DirectionalPunchShockwaveRuntime.CAPACITY)
	assert_eq(runtime.spawn_count, DirectionalPunchShockwaveRuntime.CAPACITY)
	assert_eq(runtime.denial_count, 2)
	assert_eq(int(RuntimeBudget.snapshot(city).node_count), node_count)
	runtime.reset_run()
	assert_eq(runtime.active_count(), 0)
	assert_eq(runtime.current_rank, 0)


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.robot.set_physics_process(false)
	city.encounter_runtime.release_all()
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	return city


func _attack(mode: int, attack_id: int, facing: int) -> AttackSpec:
	return AttackSpec.new(
		mode,
		attack_id,
		facing,
		0.8,
		0.05,
		0.1,
		0.2,
		145.0,
		125.0,
		1080.0,
		Vector2(190.0, 150.0),
		Vector2(105.0, 62.0)
	)
