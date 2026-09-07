extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")

var _last_damage_event: DamageEvent


func before_each() -> void:
	_last_damage_event = null


func test_only_full_charge_release_plants_on_whiff_at_robot_ground() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: TeslaTowerRuntime = _runtime(city)
	assert_true(runtime.apply_rank(1))
	var partial: AttackSpec = _attack(51_001, 1.99)
	runtime.call(&"_on_charge_released", partial, 1.98, 1.99)
	assert_false(runtime.tower.active)
	var full: AttackSpec = _attack(51_002, 2.0)
	var ground: Node2D = city.robot.get_node(^"VisualRoot/VisualGroundOrigin") as Node2D
	var expected_origin: Vector2 = (
		ground.global_position + TeslaTowerRuntime.DEPLOYMENT_OFFSET
	)
	assert_eq(TeslaTowerRuntime.DEPLOYMENT_OFFSET, Vector2(0.0, 40.0))
	runtime.call(&"_on_charge_released", full, 2.0, 2.0)
	assert_true(runtime.tower.active)
	assert_eq(runtime.tower.global_position, expected_origin)
	assert_eq(runtime.tower.deployment_attack_id, 51_002)
	assert_eq(runtime.deployment_count, 1)
	city.robot.global_position.x += 220.0
	assert_eq(runtime.tower.global_position, expected_origin)
	assert_eq(city.encounter_runtime.active_count(), 0)


func test_second_full_charge_replaces_the_single_preallocated_tower() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: TeslaTowerRuntime = _runtime(city)
	assert_true(runtime.apply_rank(2))
	var tower_id: int = runtime.tower.get_instance_id()
	runtime.call(&"_on_charge_released", _attack(51_003, 2.0), 2.0, 2.0)
	var first_position: Vector2 = runtime.tower.global_position
	city.robot.global_position.x += 180.0
	runtime.call(&"_on_charge_released", _attack(51_004, 2.0), 2.0, 2.0)
	assert_eq(runtime.tower.get_instance_id(), tower_id)
	assert_ne(runtime.tower.global_position, first_position)
	assert_eq(runtime.tower.deployment_attack_id, 51_004)
	assert_eq(runtime.deployment_count, 2)
	assert_eq(runtime.tower.arcs.size(), 3)


func test_rank_three_pulse_hits_three_nearest_living_targets_in_fixed_registry() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: TeslaTowerRuntime = _runtime(city)
	assert_true(runtime.apply_rank(3))
	runtime.call(&"_on_charge_released", _attack(51_005, 2.0), 2.0, 2.0)
	var origin: Vector2 = runtime.tower.global_position
	var targets: Array[EnemyActor2D] = [
		city.encounter_runtime.soldiers[0],
		city.encounter_runtime.tanks[0],
		city.encounter_runtime.helicopters[0],
		city.encounter_runtime.actor_at_registry_index(
			city.encounter_runtime.soldiers.size()
			+ city.encounter_runtime.tanks.size()
			+ city.encounter_runtime.helicopters.size()
		),
	]
	for index: int in range(targets.size()):
		var target: EnemyActor2D = targets[index]
		target.activate(origin + Vector2(90.0 + float(index) * 70.0, 0.0), city.robot)
		target.set_physics_process(false)
		target.max_health = 1000.0
		target.current_health = 1000.0
	runtime.tower.call(&"_pulse")
	assert_almost_eq(targets[0].current_health, 934.0, 0.001)
	assert_almost_eq(targets[1].current_health, 934.0, 0.001)
	assert_almost_eq(targets[2].current_health, 934.0, 0.001)
	assert_almost_eq(targets[3].current_health, 1000.0, 0.001)
	assert_eq(runtime.tower.active_arc_count(), 3)
	assert_eq(runtime.tower.pulse_count, 1)
	assert_eq(runtime.tower.accepted_hit_count, 3)
	for index: int in range(3):
		var target: EnemyActor2D = targets[index]
		var content_rect: Rect2 = target.visual.get_meta(
			EnemyActor2D.VISUAL_CONTENT_RECT_META,
			Rect2(
				-target.visual.texture.get_size() * 0.5,
				target.visual.texture.get_size()
			)
		)
		var local_center: Vector2 = content_rect.get_center()
		if target.visual.flip_h:
			local_center.x = -local_center.x
		if target.visual.flip_v:
			local_center.y = -local_center.y
		var rendered_center: Vector2 = target.visual.to_global(local_center)
		assert_eq(runtime.tower.arcs[index].endpoint, rendered_center)
		assert_eq(target.center_of_mass_world_position(), rendered_center)
	assert_ne(runtime.tower.arcs[0].endpoint, targets[0].global_position)


func test_tesla_damage_preserves_root_attribution_and_never_redeploys() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: TeslaTowerRuntime = _runtime(city)
	assert_true(runtime.apply_rank(1))
	runtime.call(&"_on_charge_released", _attack(51_006, 2.0), 2.0, 2.0)
	var target: EnemyActor2D = city.encounter_runtime.soldiers[0]
	target.activate(runtime.tower.global_position + Vector2(100.0, 0.0), city.robot)
	target.set_physics_process(false)
	target.max_health = 18.0
	target.current_health = 18.0
	target.died.connect(_capture_damage_event)
	var deployment_count: int = runtime.deployment_count
	runtime.tower.call(&"_pulse")
	assert_true(target.dead)
	assert_not_null(_last_damage_event)
	assert_eq(_last_damage_event.damage_type, &"tesla_tower")
	assert_eq(_last_damage_event.root_attack_id, 51_006)
	assert_eq(_last_damage_event.source, city.robot)
	assert_eq(_last_damage_event.causal_depth, 1)
	assert_eq(_last_damage_event.impulse_per_mass, 0.0)
	assert_ne(_last_damage_event.effect_flags & DamageEvent.FLAG_TESLA_TOWER, 0)
	assert_eq(runtime.deployment_count, deployment_count)
	assert_eq(CombatRunTelemetry.weapon_id_for_damage_type(&"tesla_tower"), &"TESLA_TOWER")


func test_rank_one_range_includes_the_additive_500_pixel_radius() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: TeslaTowerRuntime = _runtime(city)
	assert_true(runtime.apply_rank(1))
	runtime.call(&"_on_charge_released", _attack(51_007, 2.0), 2.0, 2.0)
	var origin: Vector2 = runtime.tower.global_position
	var inside: EnemyActor2D = city.encounter_runtime.soldiers[0]
	var outside: EnemyActor2D = city.encounter_runtime.soldiers[1]
	inside.activate(origin + Vector2(TeslaTower2D.RANGES[1], 0.0), city.robot)
	outside.activate(origin + Vector2(TeslaTower2D.RANGES[1] + 1.0, 0.0), city.robot)
	for target: EnemyActor2D in [inside, outside]:
		target.set_physics_process(false)
		target.max_health = 1000.0
		target.current_health = 1000.0
	runtime.tower.call(&"_pulse")
	assert_almost_eq(inside.current_health, 946.0, 0.001)
	assert_almost_eq(outside.current_health, 1000.0, 0.001)


func test_arming_pause_lifetime_reset_and_node_count_remain_bounded() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: TeslaTowerRuntime = _runtime(city)
	assert_true(runtime.apply_rank(2))
	var initial_node_count: int = int(RuntimeBudget.snapshot(city).node_count)
	for attack_index: int in range(4):
		runtime.call(
			&"_on_charge_released",
			_attack(51_010 + attack_index, 2.0),
			2.0,
			2.0
		)
	assert_eq(runtime.deployment_count, 4)
	assert_eq(int(RuntimeBudget.snapshot(city).node_count), initial_node_count)
	var before_pause: float = runtime.tower.lifetime_remaining
	runtime.set_paused(true)
	runtime.tower.call(&"_process", 3.0)
	assert_eq(runtime.tower.lifetime_remaining, before_pause)
	runtime.set_paused(false)
	runtime.tower.call(&"_process", 0.24)
	assert_eq(runtime.tower.pulse_count, 0)
	runtime.tower.call(&"_process", 0.02)
	runtime.tower.call(&"_process", 0.99)
	assert_eq(runtime.tower.pulse_count, 0)
	runtime.tower.call(&"_process", 0.02)
	assert_eq(runtime.tower.pulse_count, 1)
	assert_almost_eq(
		before_pause,
		TeslaTower2D.LIFETIME_SECONDS,
		0.001
	)
	var remaining_before_expiry: float = runtime.tower.lifetime_remaining
	runtime.tower.call(&"_process", remaining_before_expiry - 0.01)
	assert_true(runtime.tower.active)
	runtime.tower.call(&"_process", 0.02)
	assert_false(runtime.tower.active)
	runtime.reset_run()
	assert_false(runtime.tower.active)
	assert_eq(runtime.current_rank, 0)
	assert_eq(runtime.deployment_count, 0)
	assert_eq(int(RuntimeBudget.snapshot(city).node_count), initial_node_count)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func test_rank_tables_match_the_approved_tesla_tuning() -> void:
	assert_eq(TeslaTower2D.LIFETIME_SECONDS, 30.0)
	assert_eq(TeslaTower2D.RANGE_RADIUS_BONUS, 500.0)
	assert_eq(TeslaTower2D.LIFETIMES, [0.0, 30.0, 30.0, 30.0])
	assert_eq(TeslaTower2D.PULSE_INTERVALS, [0.0, 1.2, 1.0, 0.9])
	assert_eq(TeslaTower2D.RANGES, [0.0, 930.0, 1000.0, 1070.0])
	assert_eq(TeslaTower2D.TARGET_CAPS, [0, 1, 2, 3])
	assert_eq(TeslaTower2D.DAMAGE_MULTIPLIER, 3.0)
	assert_eq(TeslaTower2D.DAMAGE, [0.0, 54.0, 60.0, 66.0])
	assert_eq(TeslaTower2D.ARMING_SECONDS, 0.25)


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.robot.set_physics_process(false)
	city.robot.global_position = Vector2(520.0, 460.0)
	city.encounter_runtime.release_all()
	return city


func _runtime(city: CitySlice) -> TeslaTowerRuntime:
	return city.upgrade_assembler.runtimes[&"TESLA_TOWER"] as TeslaTowerRuntime


func _attack(attack_id: int, multiplier: float) -> AttackSpec:
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
		Vector2.ZERO
	).with_damage_multiplier(multiplier)


func _capture_damage_event(_actor: EnemyActor2D, event: DamageEvent) -> void:
	_last_damage_event = event
