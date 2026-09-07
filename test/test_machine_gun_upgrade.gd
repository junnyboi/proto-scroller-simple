extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_machine_gun_targets_nearest_stably_and_uses_player_partition() -> void:
	var city: CitySlice = await _spawn_isolated_city()
	var soldier: EnemyActor2D = city.encounter_runtime.acquire(
		&"soldier",
		Vector2(980.0, 542.5)
	)
	var tank: EnemyActor2D = city.encounter_runtime.acquire(
		&"tank",
		Vector2(980.0, 551.0)
	)
	soldier.set_physics_process(false)
	tank.set_physics_process(false)
	soldier.global_position = Vector2(980.0, 540.0)
	tank.global_position = soldier.global_position
	var machine: MachineGunRuntime = _machine(city)
	machine.set_process(false)
	assert_true(machine.apply_rank(1))
	assert_true(machine.mount.visible)
	var hostile_before: int = (
		city.projectile_root.active_count(&"bullet")
		+ city.projectile_root.active_count(&"shell")
		+ city.projectile_root.active_count(&"rocket")
	)
	machine.advance(0.10)
	var expected: EnemyActor2D = (
		soldier if soldier.get_instance_id() < tank.get_instance_id() else tank
	)
	assert_same(machine.target, expected)
	assert_eq(machine.target_activation_generation, expected.activation_generation)
	assert_eq(machine.shots_fired, 1)
	assert_eq(city.projectile_root.active_count(&"player_bullet"), 1)
	assert_eq(
		city.projectile_root.last_acquired.get_meta(&"partition"),
		&"player_bullet"
	)
	assert_eq(city.projectile_root.last_acquired.source, city.robot)
	assert_same(
		Projectile2D.MACHINE_GUN_ROUND_TEXTURE,
		load("res://assets/player/weapons/machine_gun_round.png")
	)
	assert_eq(machine.mount.flash_count, 1)
	assert_eq(
		city.projectile_root.last_acquired.attack_id(),
		city.projectile_root.last_acquired.root_attack_id()
	)
	var hostile_after: int = (
		city.projectile_root.active_count(&"bullet")
		+ city.projectile_root.active_count(&"shell")
		+ city.projectile_root.active_count(&"rocket")
	)
	assert_eq(hostile_after, hostile_before)
	var bullet: Projectile2D = city.projectile_root.last_acquired
	bullet.impact_requested.emit(
		bullet,
		tank.global_position,
		Vector2.RIGHT,
		&"machine_gun",
		&"",
		bullet.damage
	)
	assert_eq(city.projectile_root.active_machine_gun_impact_count(), 1)
	assert_eq(city.projectile_root.last_machine_gun_impact_position, tank.global_position)
	city.projectile_root.release_partition(&"player_bullet")
	assert_eq(city.projectile_root.active_machine_gun_impact_count(), 0)


func test_machine_gun_rank_five_tuning_and_pool_saturation_are_exact() -> void:
	var city: CitySlice = await _spawn_isolated_city()
	var target: EnemyActor2D = city.encounter_runtime.acquire(
		&"tank",
		Vector2(1000.0, 551.0)
	)
	target.set_physics_process(false)
	var machine: MachineGunRuntime = _machine(city)
	machine.set_process(false)
	assert_true(machine.apply_rank(5))
	assert_almost_eq(machine.damage_per_shot(), 19.2, 0.001)
	assert_almost_eq(machine.fire_interval(), 0.20, 0.001)
	var node_count: int = int(RuntimeBudget.snapshot(city).node_count)
	for shot_index: int in range(9):
		machine.fire_remaining = 0.0
		machine.advance(0.10)
	assert_eq(machine.shots_fired, 9)
	assert_eq(city.projectile_root.active_count(&"player_bullet"), 8)
	assert_eq(city.projectile_root.recycle_count, 1)
	assert_eq(int(RuntimeBudget.snapshot(city).node_count), node_count)
	assert_eq(city.projectile_root.total_count(), 32)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func test_machine_gun_rechecks_activation_generation_and_honors_pause() -> void:
	var city: CitySlice = await _spawn_isolated_city()
	var target: EnemyActor2D = city.encounter_runtime.acquire(
		&"soldier",
		Vector2(1000.0, 542.5)
	)
	target.set_physics_process(false)
	var machine: MachineGunRuntime = _machine(city)
	machine.set_process(false)
	machine.apply_rank(1)
	machine.advance(0.10)
	var first_generation: int = machine.target_activation_generation
	city.encounter_runtime.release(target)
	var reused: EnemyActor2D = city.encounter_runtime.acquire(
		&"soldier",
		Vector2(1010.0, 542.5)
	)
	reused.set_physics_process(false)
	assert_same(reused, target)
	assert_gt(reused.activation_generation, first_generation)
	machine.fire_remaining = 0.0
	machine.scan_remaining = 0.0
	machine.advance(0.10)
	assert_same(machine.target, reused)
	assert_eq(machine.target_activation_generation, reused.activation_generation)
	var shots_before_pause: int = machine.shots_fired
	machine.set_paused(true)
	machine.fire_remaining = 0.0
	machine.advance(1.0)
	assert_eq(machine.shots_fired, shots_before_pause)
	assert_false(InputMap.has_action(&"machine_gun"))
	assert_false(InputMap.has_action(&"fire_weapon"))


func _spawn_isolated_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	return city


func _machine(city: CitySlice) -> MachineGunRuntime:
	return city.upgrade_assembler.runtimes[&"MACHINE_GUN"] as MachineGunRuntime
