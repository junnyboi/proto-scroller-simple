extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_flamethrower_requires_target_and_latches_direction_for_unique_ticks() -> void:
	var city: CitySlice = await _spawn_isolated_city()
	var flame: FlamethrowerRuntime = _flame(city)
	flame.set_process(false)
	flame.apply_rank(1)
	flame.advance(1.0)
	assert_false(flame.burst_active)
	assert_eq(flame.bursts_started, 0)
	assert_eq(flame.cooldown_remaining, 0.0)
	var target: EnemyActor2D = city.encounter_runtime.acquire(
		&"soldier",
		flame.emitter.global_position + Vector2(160.0, 0.0)
	)
	target.set_physics_process(false)
	target.global_position = flame.drones[0].muzzle.global_position + Vector2(160.0, 0.0)
	target.current_health = 45.0
	var fatal_events: Array[DamageEvent] = []
	target.died.connect(
		func(_actor: EnemyActor2D, event: DamageEvent) -> void:
			fatal_events.append(event)
	)
	await get_tree().physics_frame
	flame.advance(0.0)
	var latched_root: int = flame.burst_root_attack_id
	assert_true(flame.burst_active)
	assert_eq(target.current_health, 33.0)
	city.robot.facing = -1
	flame.advance(0.61)
	assert_false(flame.burst_active)
	assert_eq(flame.ticks_delivered, 4)
	assert_eq(fatal_events.size(), 1)
	if fatal_events.size() == 1:
		assert_eq(fatal_events[0].root_attack_id, latched_root)
		assert_ne(fatal_events[0].attack_id, latched_root)
		assert_eq(fatal_events[0].causal_depth, 0)
	assert_eq(flame.cooldown_remaining, 1.20)


func test_flamethrower_aims_at_target_elevation_instead_of_cardinal_axis() -> void:
	var city: CitySlice = await _spawn_isolated_city()
	var flame: FlamethrowerRuntime = _flame(city)
	flame.set_process(false)
	flame.apply_rank(2)
	flame._drone_cursor = 1
	var firing_drone: WeaponDroneVisual2D = flame.drones[1]
	var origin: Vector2 = firing_drone.muzzle.global_position
	var target_offset: Vector2 = Vector2(160.0, -80.0)
	var target: EnemyActor2D = city.encounter_runtime.acquire(
		&"soldier",
		origin + target_offset
	)
	target.set_physics_process(false)
	target.current_health = 12.0
	var fatal_events: Array[DamageEvent] = []
	target.died.connect(
		func(_actor: EnemyActor2D, event: DamageEvent) -> void:
			fatal_events.append(event)
	)
	await get_tree().physics_frame
	var expected_direction: Vector2 = (
		target.global_position - firing_drone.muzzle.global_position
	).normalized()
	flame.advance(0.0)
	assert_true(flame.burst_active)
	assert_same(flame.active_drone, firing_drone)
	assert_almost_eq(flame.burst_direction.x, expected_direction.x, 0.001)
	assert_almost_eq(flame.burst_direction.y, expected_direction.y, 0.001)
	assert_almost_eq(
		flame.active_drone.weapon_pivot.rotation,
		expected_direction.angle(),
		0.001
	)
	assert_almost_eq(flame.flames[0].rotation, expected_direction.angle(), 0.001)
	assert_eq(fatal_events.size(), 1)
	if fatal_events.size() == 1:
		assert_almost_eq(fatal_events[0].direction.x, expected_direction.x, 0.001)
		assert_almost_eq(fatal_events[0].direction.y, expected_direction.y, 0.001)


func test_flamethrower_rank_five_tuning_and_visual_caps_are_exact() -> void:
	var city: CitySlice = await _spawn_isolated_city()
	var flame: FlamethrowerRuntime = _flame(city)
	flame.set_process(false)
	flame.apply_rank(5)
	assert_true(flame.mount.visible)
	assert_same(
		FlameVisualSlot2D.PLUME_TEXTURE,
		load("res://assets/presentation/flame_plume.png")
	)
	assert_same(
		FlameVisualSlot2D.IGNITION_TEXTURE,
		load("res://assets/presentation/flame_ignition.png")
	)
	assert_same(
		ScorchVisualSlot2D.CONTACT_TEXTURE,
		load("res://assets/presentation/flame_contact.png")
	)
	assert_same(
		ScorchVisualSlot2D.SCORCH_TEXTURE,
		load("res://assets/presentation/scorch_decal.png")
	)
	assert_eq(flame.flame_range(), 255.0)
	assert_almost_eq(rad_to_deg(flame.half_angle()), 40.0, 0.001)
	assert_eq(flame.damage_per_tick(), 18.0)
	assert_eq(flame.tick_count(), 5)
	assert_eq(flame.tick_interval(), 0.18)
	assert_eq(flame.maximum_targets(), 6)
	assert_eq(flame.cooldown_duration(), 1.0)
	var target: EnemyActor2D = city.encounter_runtime.acquire(
		&"tank",
		flame.emitter.global_position + Vector2(180.0, 0.0)
	)
	target.set_physics_process(false)
	await get_tree().physics_frame
	var node_count: int = int(RuntimeBudget.snapshot(city).node_count)
	flame.advance(0.0)
	flame.advance(0.73)
	assert_eq(flame.ticks_delivered, 5)
	assert_eq(target.current_health, target.max_health - 90.0)
	assert_eq(flame.cooldown_remaining, 1.0)
	assert_eq(flame.active_flame_count(), 5)
	assert_eq(flame.active_scorch_count(), 5)
	flame.cooldown_remaining = 0.0
	flame.advance(0.0)
	flame.advance(0.73)
	assert_eq(flame.ticks_delivered, 10)
	assert_eq(flame.active_flame_count(), 6)
	assert_eq(flame.active_scorch_count(), 8)
	assert_eq(flame.flames.size(), 6)
	assert_eq(flame.scorches.size(), 8)
	assert_eq(int(RuntimeBudget.snapshot(city).node_count), node_count)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func test_flamethrower_pause_freezes_burst_and_loop_audio_policy() -> void:
	var city: CitySlice = await _spawn_isolated_city()
	var flame: FlamethrowerRuntime = _flame(city)
	assert_eq(flame.loop_audio.bus, GameAudioBus.SFX)
	flame.set_process(false)
	flame.apply_rank(4)
	var target: EnemyActor2D = city.encounter_runtime.acquire(
		&"tank",
		flame.emitter.global_position + Vector2(170.0, 0.0)
	)
	target.set_physics_process(false)
	await get_tree().physics_frame
	flame.advance(0.0)
	assert_true(flame.loop_audio_active)
	assert_eq(flame.loop_audio.global_position, flame.emitter.global_position)
	var ticks_before_pause: int = flame.ticks_delivered
	var remaining_before_pause: float = flame.tick_remaining
	flame.set_paused(true)
	assert_false(flame.loop_audio_active)
	flame.advance(1.0)
	assert_eq(flame.ticks_delivered, ticks_before_pause)
	assert_eq(flame.tick_remaining, remaining_before_pause)
	flame.emitter.global_position += Vector2(1800.0, 0.0)
	flame.set_paused(false)
	assert_true(flame.loop_audio_active)
	assert_eq(flame.loop_audio.global_position, flame.emitter.global_position)
	flame.advance(0.20)
	assert_eq(flame.ticks_delivered, ticks_before_pause + 1)
	assert_false(InputMap.has_action(&"flamethrower"))


func _spawn_isolated_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	return city


func _flame(city: CitySlice) -> FlamethrowerRuntime:
	return city.upgrade_assembler.runtimes[&"FLAMETHROWER"] as FlamethrowerRuntime
