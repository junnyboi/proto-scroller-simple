extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_rank_zero_and_tap_charge_capture_nothing() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: GravityCrucibleRuntime = _runtime(city)
	var debris: DebrisBody2D = _spawn_debris(city, Vector2(80.0, 0.0))
	var spec: AttackSpec = _attack(41_001)
	runtime.call(&"_on_charge_started", spec)
	runtime.call(&"_on_charge_updated", spec, 0.8, 0.4, 1.4)
	assert_eq(runtime.captured_count(), 0)
	assert_true(runtime.apply_rank(1))
	runtime.call(&"_on_charge_started", spec)
	runtime.call(&"_on_charge_updated", spec, 0.34, 0.17, 1.17)
	assert_eq(runtime.captured_count(), 0)
	runtime.call(&"_on_charge_released", spec, 0.34, 1.17)
	assert_false(debris.is_crucible_captured())
	assert_eq(debris_pool_layer(debris), DebrisBody2D.ACTIVE_COLLISION_LAYER)


func test_all_debris_in_1000px_are_captured_nearest_first_at_every_rank() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: GravityCrucibleRuntime = _runtime(city)
	var far: DebrisBody2D = _spawn_debris(city, Vector2(1000.0, 0.0))
	var nearest: DebrisBody2D = _spawn_debris(city, Vector2(70.0, 0.0))
	var middle: DebrisBody2D = _spawn_debris(city, Vector2(520.0, 0.0))
	var fourth: DebrisBody2D = _spawn_debris(city, Vector2(740.0, 0.0))
	var scrap: DebrisBody2D = _spawn_scrap(city, Vector2(860.0, 0.0))
	var outside: DebrisBody2D = _spawn_debris(city, Vector2(1001.0, 0.0))
	assert_eq(GravityCrucibleRuntime.CAPACITY, 60)
	assert_eq(GravityCrucibleRuntime.CAPTURE_CAPS, [0, 60, 60, 60])
	assert_eq(GravityCrucibleRuntime.CAPTURE_RADII, [0.0, 1000.0, 1000.0, 1000.0])
	assert_eq(GravityCrucibleRuntime.THROW_SPEEDS, [0.0, 1450.0, 1750.0, 2050.0])
	assert_eq(GravityCrucibleRuntime.IMPACT_DAMAGE, [0.0, 30.0, 42.0, 56.0])
	assert_eq(GravityCrucibleRuntime.MAX_CHARGE_ATTACK_MULTIPLIER, 2.0)
	assert_eq(GravityCrucibleRuntime.EXPLOSION_VISUAL_CAPACITY, 12)
	assert_true(runtime.apply_rank(1))
	var spec: AttackSpec = _attack(41_002)
	_start_capture(runtime, spec)
	assert_eq(runtime.captured_count(), 5)
	assert_same(runtime.captured[0], nearest)
	assert_same(runtime.captured[1], middle)
	assert_same(runtime.captured[2], fourth)
	assert_same(runtime.captured[3], scrap)
	assert_same(runtime.captured[4], far)
	for debris: DebrisBody2D in [nearest, middle, fourth, scrap, far]:
		assert_true(debris.is_crucible_captured())
		assert_eq(debris.collision_layer, 0)
		assert_eq(debris.collision_mask, 0)
		assert_true(debris.freeze)
	assert_false(outside.is_crucible_captured())


func test_captured_debris_is_visibly_pulled_into_a_revolving_orbit() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: GravityCrucibleRuntime = _runtime(city)
	assert_true(runtime.apply_rank(1))
	var debris: DebrisBody2D = _spawn_debris(city, Vector2(900.0, 0.0))
	var initial_position: Vector2 = debris.global_position
	var initial_distance: float = debris.global_position.distance_to(
		city.robot.global_position
	)
	_start_capture(runtime, _attack(41_020))
	runtime.call(&"_process", 0.20)
	assert_lt(debris.global_position.distance_to(city.robot.global_position), initial_distance)
	assert_ne(debris.global_position, initial_position)
	var first_orbit_position: Vector2 = debris.global_position
	var first_rotation: float = debris.rotation
	runtime.call(&"_process", 0.50)
	assert_lt(debris.global_position.distance_to(city.robot.global_position), 180.0)
	assert_ne(debris.global_position, first_orbit_position)
	assert_ne(debris.rotation, first_rotation)


func test_debris_entering_the_radius_during_charge_joins_the_orbit() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: GravityCrucibleRuntime = _runtime(city)
	assert_true(runtime.apply_rank(1))
	var first: DebrisBody2D = _spawn_debris(city, Vector2(120.0, 0.0))
	_start_capture(runtime, _attack(41_023))
	assert_true(first.is_crucible_captured())
	var late_debris: DebrisBody2D = _spawn_debris(city, Vector2(800.0, 0.0))
	assert_false(late_debris.is_crucible_captured())
	runtime.call(&"_process", 0.05)
	assert_true(late_debris.is_crucible_captured())
	assert_eq(runtime.captured_count(), 2)


func test_release_aims_each_debris_body_towards_nearby_enemies() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: GravityCrucibleRuntime = _runtime(city)
	assert_true(runtime.apply_rank(3))
	var first: DebrisBody2D = _spawn_debris(city, Vector2(-120.0, 0.0))
	var second: DebrisBody2D = _spawn_debris(city, Vector2(120.0, 0.0))
	var target: EnemyActor2D = city.encounter_runtime.acquire(
		&"tank",
		city.robot.global_position + Vector2(520.0, 0.0)
	)
	assert_not_null(target)
	target.set_physics_process(false)
	target.velocity = Vector2.ZERO
	target.global_position = city.robot.global_position + Vector2(520.0, 0.0)
	var spec: AttackSpec = _attack(41_021)
	_start_capture(runtime, spec)
	var first_direction: Vector2 = first.global_position.direction_to(target.global_position)
	var second_direction: Vector2 = second.global_position.direction_to(target.global_position)
	runtime.call(&"_on_charge_released", spec, 2.0, 2.0)
	assert_gt(first.linear_velocity.normalized().dot(first_direction), 0.99)
	assert_gt(second.linear_velocity.normalized().dot(second_direction), 0.99)
	assert_almost_eq(first.linear_velocity.length(), 2050.0, 0.01)
	assert_almost_eq(second.linear_velocity.length(), 2050.0, 0.01)
	assert_gte(first.max_linear_speed, 2050.0)
	assert_gte(second.max_linear_speed, 2050.0)
	assert_eq(first.gravity_scale, 0.0)
	assert_eq(second.gravity_scale, 0.0)


func test_charge_amount_scales_force_accuracy_and_trajectory() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: GravityCrucibleRuntime = _runtime(city)
	assert_true(runtime.apply_rank(3))
	var target: EnemyActor2D = city.encounter_runtime.acquire(
		&"tank",
		city.robot.global_position + Vector2(620.0, 0.0)
	)
	assert_not_null(target)
	target.set_physics_process(false)
	target.velocity = Vector2.ZERO
	var weak: DebrisBody2D = _spawn_debris(city, Vector2(80.0, 0.0))
	var weak_spec: AttackSpec = _attack(41_025)
	_start_capture(runtime, weak_spec)
	var weak_direct: Vector2 = weak.global_position.direction_to(target.global_position)
	runtime.call(&"_on_charge_released", weak_spec, 0.5, 1.25)
	assert_almost_eq(weak.linear_velocity.length(), 512.5, 0.01)
	assert_almost_eq(float(weak.get("_crucible_damage")), 17.5, 0.001)
	assert_almost_eq(
		GravityCrucibleRuntime.attack_multiplier_for_charge(0.25),
		1.25,
		0.001
	)
	assert_almost_eq(weak.angular_velocity, 2.5, 0.001)
	assert_almost_eq(weak.gravity_scale, 1.0125, 0.0001)
	assert_between(weak.linear_velocity.normalized().dot(weak_direct), 0.96, 0.98)
	var weak_flight_time: float = (
		(target.global_position.x - weak.global_position.x) / weak.linear_velocity.x
	)
	var weak_arrival_y: float = (
		weak.global_position.y
		+ weak.linear_velocity.y * weak_flight_time
		+ 0.5 * 980.0 * weak.gravity_scale * weak_flight_time * weak_flight_time
	)
	assert_gt(weak_arrival_y, target.global_position.y + 100.0)
	city.debris_pool.release(weak)
	var full: DebrisBody2D = _spawn_debris(city, Vector2(80.0, 0.0))
	var full_spec: AttackSpec = _attack(41_026)
	_start_capture(runtime, full_spec)
	var full_direct: Vector2 = full.global_position.direction_to(target.global_position)
	runtime.call(&"_on_charge_released", full_spec, 2.0, 2.0)
	assert_almost_eq(full.linear_velocity.length(), 2050.0, 0.01)
	assert_almost_eq(float(full.get("_crucible_damage")), 112.0, 0.001)
	assert_almost_eq(
		GravityCrucibleRuntime.attack_multiplier_for_charge(1.0),
		2.0,
		0.001
	)
	assert_gt(full.linear_velocity.normalized().dot(full_direct), 0.9999)
	assert_eq(full.gravity_scale, 0.0)
	assert_almost_eq(
		float(full.get("_crucible_gravity_restore_delay")),
		GravityCrucibleRuntime.FULL_CHARGE_STRAIGHT_SECONDS,
		0.001
	)
	full.call(&"_physics_process", 0.84)
	assert_eq(full.gravity_scale, 0.0)
	full.call(&"_physics_process", 0.02)
	assert_eq(full.gravity_scale, 1.0)


func test_locked_air_target_receives_every_debris_ahead_of_ground_targets() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: GravityCrucibleRuntime = _runtime(city)
	assert_true(runtime.apply_rank(3))
	var debris_bodies: Array[DebrisBody2D] = [
		_spawn_debris(city, Vector2(-120.0, 0.0)),
		_spawn_debris(city, Vector2.ZERO),
		_spawn_debris(city, Vector2(120.0, 0.0)),
	]
	var ground_target: EnemyActor2D = city.encounter_runtime.acquire(
		&"tank",
		city.robot.global_position + Vector2(300.0, 0.0)
	)
	var air_target: EnemyActor2D = city.encounter_runtime.acquire(
		&"helicopter",
		city.robot.global_position + Vector2(-80.0, -420.0)
	)
	assert_not_null(ground_target)
	assert_not_null(air_target)
	ground_target.set_physics_process(false)
	air_target.set_physics_process(false)
	ground_target.velocity = Vector2.ZERO
	air_target.velocity = Vector2.ZERO
	city.air_target_lock_runtime.set("_locked_target", air_target)
	var spec: AttackSpec = _attack(41_024)
	_start_capture(runtime, spec)
	var expected_directions: Array[Vector2] = []
	for debris: DebrisBody2D in debris_bodies:
		expected_directions.append(
			debris.global_position.direction_to(air_target.global_position)
		)
	runtime.call(&"_on_charge_released", spec, 2.0, 2.0)
	for index: int in range(debris_bodies.size()):
		var launched: DebrisBody2D = debris_bodies[index]
		assert_gt(
			launched.linear_velocity.normalized().dot(expected_directions[index]),
			0.99
		)
		assert_lt(
			launched.linear_velocity.normalized().dot(
				launched.global_position.direction_to(ground_target.global_position)
			),
			0.80
		)


func test_release_without_nearby_enemies_uses_an_even_radial_burst() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: GravityCrucibleRuntime = _runtime(city)
	assert_true(runtime.apply_rank(2))
	var debris_bodies: Array[DebrisBody2D] = [
		_spawn_debris(city, Vector2(80.0, 0.0)),
		_spawn_debris(city, Vector2(100.0, 0.0)),
		_spawn_debris(city, Vector2(120.0, 0.0)),
		_spawn_debris(city, Vector2(140.0, 0.0)),
	]
	var spec: AttackSpec = _attack(41_022)
	_start_capture(runtime, spec)
	runtime.call(&"_on_charge_released", spec, 2.0, 2.0)
	var direction_sum: Vector2 = Vector2.ZERO
	for debris: DebrisBody2D in debris_bodies:
		direction_sum += debris.linear_velocity.normalized()
		assert_almost_eq(debris.linear_velocity.length(), 1750.0, 0.01)
	assert_lt(direction_sum.length(), 0.001)
	assert_gt(debris_bodies[0].linear_velocity.x, 1700.0)
	assert_gt(debris_bodies[1].linear_velocity.y, 1700.0)
	assert_lt(debris_bodies[2].linear_velocity.x, -1700.0)
	assert_lt(debris_bodies[3].linear_velocity.y, -1700.0)


func test_release_restores_physics_and_delivers_one_tagged_hit_per_body() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: GravityCrucibleRuntime = _runtime(city)
	assert_true(runtime.apply_rank(3))
	var debris: DebrisBody2D = _spawn_debris(city, Vector2(80.0, 0.0))
	var spec: AttackSpec = _attack(
		41_003,
		DamageEvent.FLAG_KINETIC_FIELD,
		6.0
	)
	_start_capture(runtime, spec)
	assert_true(debris.is_crucible_captured())
	runtime.call(&"_on_charge_released", spec, 2.0, 2.0)
	assert_false(debris.is_crucible_captured())
	assert_false(debris.freeze)
	assert_eq(debris.collision_layer, DebrisBody2D.ACTIVE_COLLISION_LAYER)
	assert_gt(debris.linear_velocity.x, 2000.0)
	assert_ne(
		int(debris.get("_crucible_effect_flags"))
		& DamageEvent.FLAG_GRAVITY_CRUCIBLE,
		0
	)
	assert_ne(
		int(debris.get("_crucible_effect_flags"))
		& DamageEvent.FLAG_KINETIC_FIELD,
		0
	)
	var target: EnemyActor2D = city.encounter_runtime.acquire(
		&"tank",
		debris.global_position + Vector2(40.0, 0.0)
	)
	assert_not_null(target)
	target.set_physics_process(false)
	target.max_health = 1000.0
	target.current_health = 1000.0
	debris.linear_velocity = Vector2(2050.0, 0.0)
	debris.call(&"_resolve_crucible_impact", target)
	assert_almost_eq(target.current_health, 882.0, 0.001)
	assert_eq(city.debris_pool.active_count(), 0)
	assert_eq(runtime.explosion_count_total, 1)
	assert_true(runtime.explosion_visuals[0].active)
	assert_almost_eq(runtime.explosion_visuals[0].scale.x, 1.35, 0.001)
	debris.call(&"_resolve_crucible_impact", target)
	assert_almost_eq(target.current_health, 882.0, 0.001)
	assert_eq(runtime.explosion_count_total, 1)
	assert_eq(runtime.release_count_total, 1)


func test_cancel_pause_pool_pressure_and_reset_restore_every_body() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: GravityCrucibleRuntime = _runtime(city)
	assert_true(runtime.apply_rank(2))
	var first: DebrisBody2D = _spawn_debris(city, Vector2(70.0, 0.0))
	var second: DebrisBody2D = _spawn_debris(city, Vector2(110.0, 0.0))
	var first_layer: int = first.collision_layer
	var first_mask: int = first.collision_mask
	var spec: AttackSpec = _attack(41_004)
	_start_capture(runtime, spec)
	assert_eq(runtime.captured_count(), 2)
	var held_position: Vector2 = first.global_position
	runtime.set_paused(true)
	runtime.call(&"_process", 0.25)
	assert_eq(first.global_position, held_position)
	runtime.set_paused(false)
	runtime.call(&"_process", 0.25)
	assert_ne(first.global_position, held_position)
	runtime.call(&"_on_attack_cancelled", spec)
	assert_eq(runtime.captured_count(), 0)
	for debris: DebrisBody2D in [first, second]:
		assert_false(debris.is_crucible_captured())
		assert_eq(debris.collision_layer, first_layer)
		assert_eq(debris.collision_mask, first_mask)
		assert_false(debris.freeze)
	assert_eq(city.debris_pool.active_count(), 2)
	var node_count: int = int(RuntimeBudget.snapshot(city).node_count)
	_start_capture(runtime, _attack(41_005))
	runtime.reset_run()
	assert_eq(runtime.current_rank, 0)
	assert_eq(runtime.captured_count(), 0)
	assert_eq(int(RuntimeBudget.snapshot(city).node_count), node_count)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func test_ordinary_wrecks_are_captured_but_boss_owned_wrecks_are_outside_registry() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: GravityCrucibleRuntime = _runtime(city)
	assert_true(runtime.apply_rank(1))
	city.tank.activate(city.robot.global_position + Vector2(90.0, 0.0), city.robot)
	var fatal_event: DamageEvent = DamageEvent.new(
		41_006,
		city.robot,
		100.0,
		&"ground_smash",
		city.tank.global_position,
		Vector2.RIGHT,
		400.0
	)
	var wreck: EnemyWreck2D = city.enemy_remains_factory.spawn_wreck(
		city.tank,
		fatal_event
	)
	assert_not_null(wreck)
	var spec: AttackSpec = _attack(41_007)
	_start_capture(runtime, spec)
	assert_eq(runtime.captured_count(), 1)
	assert_same(runtime.captured[0], wreck)
	assert_true(wreck.is_crucible_captured())
	runtime.call(&"_on_charge_released", spec, 2.0, 2.0)
	assert_false(wreck.is_crucible_captured())
	assert_ne(wreck.collision_mask & EnemyWreck2D.ENEMY_LAYER, 0)
	assert_eq(city.enemy_remains_factory.active_count(), 1)
	wreck.linear_velocity = Vector2(2050.0, 0.0)
	var impact_surface: Node = Node.new()
	add_child_autofree(impact_surface)
	wreck.call(&"_resolve_crucible_impact", impact_surface)
	assert_eq(city.enemy_remains_factory.active_count(), 0)
	assert_eq(city.enemy_scrap_pool.active_count(), 8)
	assert_true(wreck.is_scrapped())
	assert_eq(runtime.explosion_count_total, 1)


func test_captured_body_is_not_recycled_when_a_fixed_pool_is_saturated() -> void:
	var pool: DebrisPool = DebrisPool.new()
	pool.capacity = 1
	add_child_autofree(pool)
	await get_tree().process_frame
	var held: DebrisBody2D = pool.acquire(
		Transform2D(0.0, Vector2.ZERO),
		Vector2.ZERO
	)
	assert_not_null(held)
	assert_true(held.begin_crucible_capture())
	var denied: DebrisBody2D = pool.acquire(
		Transform2D(0.0, Vector2(20.0, 0.0)),
		Vector2.ZERO
	)
	assert_null(denied)
	assert_eq(pool.active_count(), 1)
	assert_true(held.is_crucible_captured())
	held.cancel_crucible_capture()
	assert_false(held.is_crucible_captured())


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.robot.set_physics_process(false)
	city.robot.global_position = Vector2(520.0, 460.0)
	city.encounter_runtime.release_all()
	city.debris_pool.release_all()
	city.enemy_remains_factory.release_all()
	return city


func _runtime(city: CitySlice) -> GravityCrucibleRuntime:
	return (
		city.upgrade_assembler.runtimes[&"GRAVITY_CRUCIBLE"]
		as GravityCrucibleRuntime
	)


func _spawn_debris(city: CitySlice, offset: Vector2) -> DebrisBody2D:
	var debris: DebrisBody2D = city.debris_pool.acquire(
		Transform2D(0.0, city.robot.global_position + offset),
		Vector2.ZERO,
		0.0,
		4.0,
		Vector2(36.0, 22.0),
		&"steel"
	)
	assert_not_null(debris)
	return debris


func _spawn_scrap(city: CitySlice, offset: Vector2) -> DebrisBody2D:
	var debris: DebrisBody2D = city.enemy_scrap_pool.acquire(
		Transform2D(0.0, city.robot.global_position + offset),
		Vector2.ZERO,
		0.0,
		4.0,
		Vector2(36.0, 22.0),
		&"steel"
	)
	assert_not_null(debris)
	return debris


func _start_capture(runtime: GravityCrucibleRuntime, spec: AttackSpec) -> void:
	runtime.call(&"_on_charge_started", spec)
	runtime.call(&"_on_charge_updated", spec, 0.35, 0.175, 1.175)


func _attack(
	attack_id: int,
	effect_flags: int = DamageEvent.FLAG_NONE,
	kinetic_bonus: float = 0.0
) -> AttackSpec:
	return AttackSpec.new(
		AttackSpec.Mode.GROUND_SMASH,
		attack_id,
		1,
		0.0,
		0.12,
		0.08,
		0.26,
		100.0,
		100.0,
		1020.0,
		Vector2(192.0, 192.0),
		Vector2.ZERO,
		false,
		effect_flags,
		kinetic_bonus
	)


func debris_pool_layer(debris: DebrisBody2D) -> int:
	return debris.collision_layer
