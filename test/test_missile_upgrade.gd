extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_missile_rank_four_launches_one_shared_root_salvo_into_four_slots() -> void:
	var city: CitySlice = await _spawn_isolated_city()
	var missile_weapon: MissileWeapon = _missiles(city)
	missile_weapon.set_process(false)
	missile_weapon.apply_rank(4)
	assert_true(missile_weapon.mount.visible)
	assert_same(
		MissileProjectile2D.BODY_TEXTURE,
		load("res://assets/player/weapons/player_missile_body.png")
	)
	var target: EnemyActor2D = city.encounter_runtime.acquire(
		&"tank",
		city.robot.global_position + Vector2(520.0, 0.0)
	)
	target.set_physics_process(false)
	await get_tree().physics_frame
	var node_count: int = int(RuntimeBudget.snapshot(city).node_count)
	missile_weapon.advance(0.0)
	missile_weapon.advance(0.37)
	assert_eq(missile_weapon.salvos_started, 1)
	assert_eq(missile_weapon.missiles_launched, 4)
	assert_eq(missile_weapon.pool.active_count(), 4)
	assert_eq(missile_weapon.cooldown_remaining, 4.43)
	var roots: Dictionary[int, bool] = {}
	var attack_ids: Dictionary[int, bool] = {}
	for missile: MissileProjectile2D in missile_weapon.pool.missiles:
		if missile.active:
			roots[missile.root_attack_id] = true
			attack_ids[missile.attack_id] = true
	assert_eq(roots.size(), 1)
	assert_eq(attack_ids.size(), 4)
	assert_null(missile_weapon.pool.acquire(
		missile_weapon.emitter.global_position,
		target,
		target.activation_generation,
		target.global_position,
		9991,
		9990
	))
	assert_eq(missile_weapon.pool.denial_count, 1)
	assert_eq(int(RuntimeBudget.snapshot(city).node_count), node_count)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func test_missile_target_order_prefers_forward_ideal_then_stable_geometry() -> void:
	var city: CitySlice = await _spawn_isolated_city()
	var missile_weapon: MissileWeapon = _missiles(city)
	missile_weapon.set_process(false)
	missile_weapon.apply_rank(1)
	var forward_ideal: EnemyActor2D = city.encounter_runtime.acquire(
		&"soldier",
		city.robot.global_position + Vector2(520.0, 0.0)
	)
	var forward_near: EnemyActor2D = city.encounter_runtime.acquire(
		&"soldier",
		city.robot.global_position + Vector2(440.0, 0.0)
	)
	var rear_ideal: EnemyActor2D = city.encounter_runtime.acquire(
		&"soldier",
		city.robot.global_position + Vector2(-520.0, 0.0)
	)
	for enemy: EnemyActor2D in [forward_ideal, forward_near, rear_ideal]:
		enemy.set_physics_process(false)
	var ordered: Array[EnemyActor2D] = missile_weapon.ordered_targets()
	assert_same(ordered[0], forward_ideal)
	assert_same(ordered[1], forward_near)
	assert_same(ordered[2], rear_ideal)


func test_missile_stale_target_uses_last_known_and_explodes_once() -> void:
	var city: CitySlice = await _spawn_isolated_city()
	var missile_weapon: MissileWeapon = _missiles(city)
	missile_weapon.set_process(false)
	missile_weapon.apply_rank(1)
	var target: EnemyActor2D = city.encounter_runtime.acquire(
		&"helicopter",
		city.robot.global_position + Vector2(500.0, -120.0)
	)
	target.set_physics_process(false)
	await get_tree().physics_frame
	missile_weapon.advance(0.0)
	var missile: MissileProjectile2D = missile_weapon.pool.missiles[0]
	var last_point: Vector2 = missile.last_known_point
	city.encounter_runtime.release(target)
	var reused: EnemyActor2D = city.encounter_runtime.acquire(
		&"helicopter",
		city.robot.global_position + Vector2(600.0, -160.0)
	)
	reused.set_physics_process(false)
	assert_same(reused, target)
	missile.call(&"_update_target_point")
	assert_true(missile.using_last_known)
	assert_null(missile.target)
	assert_eq(missile.last_known_point, last_point)
	assert_true(missile.request_explosion())
	assert_false(missile.request_explosion())
	assert_eq(missile_weapon.pending_explosion_count(), 1)
	assert_eq(missile_weapon.pool.active_count(), 0)
	missile_weapon.flush_explosions()
	assert_eq(missile_weapon.blast_count, 1)
	assert_eq(missile_weapon.active_explosion_visual_count(), 1)
	assert_eq(missile_weapon.explosion_visuals[0].activation_count, 1)
	assert_eq(missile_weapon.pending_explosion_count(), 0)


func test_missile_queue_and_blast_acceptance_caps_are_bounded() -> void:
	var city: CitySlice = await _spawn_isolated_city()
	var missile_weapon: MissileWeapon = _missiles(city)
	missile_weapon.set_process(false)
	missile_weapon.apply_rank(1)
	var origin: Vector2 = city.robot.global_position + Vector2(500.0, -20.0)
	for index: int in range(6):
		var enemy: EnemyActor2D = city.encounter_runtime.acquire(
			&"soldier",
			origin + Vector2(
				float(index % 3) * 22.0,
				floorf(float(index) / 3.0) * 26.0
			)
		)
		enemy.set_physics_process(false)
	await get_tree().physics_frame
	for index: int in range(8):
		assert_true(missile_weapon.enqueue_explosion(origin, 5000 + index, 4000))
	assert_false(missile_weapon.enqueue_explosion(origin, 6000, 4000))
	assert_eq(missile_weapon.pending_explosion_count(), 8)
	assert_eq(missile_weapon.explosion_denial_count, 1)
	missile_weapon.flush_explosions()
	assert_eq(missile_weapon.blast_count, 2)
	assert_eq(missile_weapon.pending_explosion_count(), 6)
	missile_weapon.flush_explosions()
	assert_eq(missile_weapon.blast_count, 4)
	assert_eq(missile_weapon.pending_explosion_count(), 4)
	missile_weapon.flush_explosions()
	assert_eq(missile_weapon.blast_count, 6)
	assert_eq(missile_weapon.pending_explosion_count(), 2)
	missile_weapon.flush_explosions()
	assert_eq(missile_weapon.blast_count, 8)
	assert_eq(missile_weapon.pending_explosion_count(), 0)
	assert_lte(missile_weapon.last_blast_accepted, 6)
	assert_lte(missile_weapon.last_blast_structural, 2)
	assert_false(InputMap.has_action(&"missile"))


func test_missile_flush_resolves_two_fifo_blasts_per_frame() -> void:
	var city: CitySlice = await _spawn_isolated_city()
	var missile_weapon: MissileWeapon = _missiles(city)
	missile_weapon.set_process(false)
	missile_weapon.apply_rank(1)
	var targets: Array[EnemyActor2D] = []
	for index: int in range(3):
		var target: EnemyActor2D = city.encounter_runtime.acquire(
			&"soldier",
			city.robot.global_position + Vector2(280.0 + float(index) * 340.0, -20.0)
		)
		target.set_physics_process(false)
		targets.append(target)
	await get_tree().physics_frame
	for index: int in range(targets.size()):
		assert_true(missile_weapon.enqueue_explosion(
			targets[index].global_position,
			7000 + index,
			6999
		))
	missile_weapon.flush_explosions()
	assert_lt(targets[0].current_health, targets[0].max_health)
	assert_lt(targets[1].current_health, targets[1].max_health)
	assert_eq(targets[2].current_health, targets[2].max_health)
	assert_eq(missile_weapon.pending_explosion_count(), 1)
	missile_weapon.flush_explosions()
	assert_lt(targets[2].current_health, targets[2].max_health)
	assert_eq(missile_weapon.pending_explosion_count(), 0)


func test_damage_receiver_cache_revalidates_reparented_colliders() -> void:
	var city: CitySlice = await _spawn_isolated_city()
	var cell: Destructible2D = city.building.get_cell(0, 1)
	var hurtbox: Node = cell.get_node(^"Hurtbox")
	assert_same(DamageReceiverLookup.find(hurtbox), cell)
	assert_same(DamageReceiverLookup.find(hurtbox), cell)
	var detached_parent: Node2D = Node2D.new()
	city.add_child(detached_parent)
	hurtbox.reparent(detached_parent)
	assert_null(DamageReceiverLookup.find(hurtbox))


func _spawn_isolated_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	return city


func _missiles(city: CitySlice) -> MissileWeapon:
	return city.upgrade_assembler.runtimes[&"MISSILE"] as MissileWeapon
