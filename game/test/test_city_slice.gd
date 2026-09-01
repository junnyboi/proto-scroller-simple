extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"
const LAND_VISUAL_BASELINE_Y: float = 655.0
const LAND_VEHICLE_VISUAL_BASELINE_Y: float = 684.0


func test_main_transitions_from_title_to_city_slice() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	assert_not_null(main.title_screen)
	main.start_game()
	await get_tree().process_frame
	assert_not_null(main.city_slice)
	assert_true(main.city_slice.robot is GiantRobotController)
	_record_test_execution()


func test_city_slice_builds_parallax_structural_cells_and_enemies() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	assert_eq(city.get_node("ParallaxCity").get_child_count(), 5)
	assert_not_null(city.get_node_or_null(^"ParallaxCity/DistrictSkyLife"))
	assert_null(city.get_node_or_null(^"Street"))
	assert_not_null(city.building)
	assert_eq(city.building.get_child_count(), StructuralBuilding2D.CELL_COUNT)
	assert_null(city.project_choir_runtime.get_node_or_null(^"FacadeRevealRuntime"))
	assert_null(city.building.get_node_or_null(^"ChoirLabReveal"))
	for row: int in range(StructuralBuilding2D.ROWS):
		for column: int in range(StructuralBuilding2D.COLUMNS):
			assert_not_null(city.building.get_cell(column, row))
	assert_not_null(city.streetlamp)
	assert_not_null(city.car)
	assert_true(city.soldier is SoldierEnemy)
	assert_true(city.tank is TankEnemy)
	assert_true(city.helicopter is HelicopterEnemy)
	assert_eq(city.debris_pool.available_count(), 24)
	for child: Node in city.debris_pool.get_children():
		var inactive_debris: DebrisBody2D = child as DebrisBody2D
		assert_not_null(inactive_debris)
		assert_eq(inactive_debris.collision_layer, 0)
		assert_eq(inactive_debris.collision_mask, 0)
		assert_false(inactive_debris.contact_monitor)
		assert_eq(inactive_debris.max_contacts_reported, 0)
		var inactive_shape: CollisionShape2D = inactive_debris.get_child(0) as CollisionShape2D
		assert_true(inactive_shape.disabled)
	var reused_debris: DebrisBody2D = city.debris_pool.acquire(
		Transform2D(0.0, Vector2(840.0, 420.0)),
		Vector2(180.0, -320.0)
	)
	assert_eq(reused_debris.collision_layer, DebrisBody2D.ACTIVE_COLLISION_LAYER)
	assert_eq(reused_debris.collision_mask, DebrisBody2D.ACTIVE_COLLISION_MASK)
	assert_true(reused_debris.contact_monitor)
	assert_eq(reused_debris.max_contacts_reported, DebrisBody2D.ACTIVE_CONTACT_LIMIT)
	var reused_shape: CollisionShape2D = reused_debris.get_child(0) as CollisionShape2D
	assert_false(reused_shape.disabled)
	city.debris_pool.release(reused_debris)
	assert_eq(reused_debris.collision_layer, 0)
	assert_eq(reused_debris.collision_mask, 0)
	assert_false(reused_debris.contact_monitor)
	assert_eq(reused_debris.max_contacts_reported, 0)
	assert_true(reused_shape.disabled)
	assert_eq(city.debris_pool.available_count(), 24)
	assert_eq(city.debris_pool.active_count(), 0)
	assert_eq(city.enemy_scrap_pool.available_count(), 32)
	assert_eq(city.soldier_defeat_pool.available_count(), 8)
	assert_eq(city.soldier_defeat_pool.total_count(), 8)
	assert_eq(city.projectile_root.available_count(), 32)
	assert_eq(city.projectile_root.available_count(&"player_bullet"), 8)
	assert_eq(city.impact_audio_root.get_child_count(), 8)
	assert_not_null(city.rampage_session)
	assert_not_null(city.enemy_remains_root)
	assert_eq(city.robot.z_index, 100)
	assert_gt(city.robot.z_index, city.projectile_root.z_index)
	assert_gt(city.robot.z_index, city.debris_pool.z_index)
	assert_gt(city.robot.z_index, city.soldier.z_index)
	assert_gt(city.robot.z_index, city.tank.z_index)
	assert_gt(city.robot.z_index, city.helicopter.z_index)
	assert_gt(city.robot.z_index, city.enemy_remains_root.z_index)
	_record_test_execution()


func test_structural_cells_have_distinct_material_profiles() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var expected_ids: Array[Array] = [
		[&"concrete", &"steel", &"concrete"],
		[&"glass", &"concrete", &"steel"],
	]
	var expected_health: Dictionary[StringName, float] = {
		&"glass": 33.75,
		&"concrete": 71.25,
		&"steel": 116.25,
	}
	var expected_chunks: Dictionary[StringName, int] = {
		&"glass": 5,
		&"concrete": 3,
		&"steel": 2,
	}
	for row: int in range(StructuralBuilding2D.ROWS):
		for column: int in range(StructuralBuilding2D.COLUMNS):
			var profile: StructuralMaterialProfile = (
				city.building.get_material_profile(column, row)
			)
			var expected_id: StringName = expected_ids[row][column]
			assert_eq(profile.material_id, expected_id)
			assert_eq(profile.max_health, expected_health[expected_id])
			assert_eq(profile.chunk_count, expected_chunks[expected_id])
	assert_lt(
		city.building.get_material_profile(0, 1).chunk_mass_max,
		city.building.get_material_profile(0, 0).chunk_mass_max
	)
	assert_gt(
		city.building.get_material_profile(2, 1).chunk_mass_min,
		city.building.get_material_profile(1, 1).chunk_mass_min
	)
	_record_test_execution()


func test_materials_change_resistance_debris_and_particles() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	for column: int in range(StructuralBuilding2D.COLUMNS):
		var cell: Destructible2D = city.building.get_cell(column, 1)
		cell.receive_damage(DamageEvent.new(
			6000 + column,
			city.robot,
			64.8,
			&"jab_cross",
			cell.global_position,
			Vector2.RIGHT,
			207.0
		))
	assert_true(city.building.is_cell_destroyed(0, 1))
	assert_false(city.building.is_cell_destroyed(1, 1))
	assert_false(city.building.is_cell_destroyed(2, 1))
	assert_eq(city.debris_pool.active_count(), 7)
	for child: Node in city.debris_pool.get_children():
		var debris: DebrisBody2D = child as DebrisBody2D
		if debris == null or not debris.visible:
			continue
		assert_eq(debris.material_id(), &"glass")
		assert_lte(debris.mass, 1.3)
	var particle_materials: Array[StringName] = []
	for child: Node in city.get_children():
		if child is CPUParticles2D and child.has_meta(&"structural_material"):
			particle_materials.append(child.get_meta(&"structural_material"))
			assert_gt(city.robot.z_index, (child as CPUParticles2D).z_index)
	assert_has(particle_materials, &"glass")
	assert_has(particle_materials, &"concrete")
	assert_has(particle_materials, &"steel")
	_record_test_execution()


func test_stomp_breaks_props_and_damages_nearby_building_cells() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	assert_eq(city.car.current_health, city.car.max_health)
	assert_eq(city.streetlamp.current_health, city.streetlamp.max_health)
	for enemy: EnemyActor2D in [city.soldier, city.tank, city.helicopter]:
		enemy.global_position.x = 2500.0
	city.robot.position = Vector2(1150.0, 460.0)
	city.robot.stomp_radius = 500.0
	city.robot.stomp_damage = 200.0
	var original_health: float = city.robot.current_health
	city.trigger_test_stomp()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(city.car.is_broken)
	assert_true(city.streetlamp.is_broken)
	assert_true(city.building.is_cell_destroyed(0, 1))
	assert_false(city.building.is_cell_destroyed(1, 1))
	assert_gt(city.score, 450)
	assert_eq(city.robot.current_health, original_health)
	_record_test_execution()


func test_robot_is_immune_to_self_and_player_team_damage() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var original_health: float = city.robot.current_health
	var self_event: DamageEvent = DamageEvent.new(
		6101,
		city.robot,
		200.0,
		&"explosive"
	)
	assert_false(city.robot.receive_damage(self_event))
	assert_eq(city.robot.current_health, original_health)
	var friendly_source: Node2D = Node2D.new()
	friendly_source.set_meta(&"combat_team", &"player")
	city.add_child(friendly_source)
	var friendly_event: DamageEvent = DamageEvent.new(
		6102,
		friendly_source,
		200.0,
		&"projectile"
	)
	assert_false(city.robot.receive_damage(friendly_event))
	assert_eq(city.robot.current_health, original_health)
	var hostile_event: DamageEvent = DamageEvent.new(
		6103,
		city.soldier,
		25.0,
		&"projectile"
	)
	assert_true(city.robot.receive_damage(hostile_event))
	assert_eq(city.robot.current_health, original_health - 25.0)
	_record_test_execution()


func test_jab_cross_destroys_lower_bay_and_cracks_upper_support() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.robot.set_physics_process(false)
	for enemy: EnemyActor2D in [city.soldier, city.tank, city.helicopter]:
		enemy.set_physics_process(false)
	city.car.global_position.x = 600.0
	city.streetlamp.global_position.x = 600.0
	city.robot.position = Vector2(1100.0, 460.0)
	city.robot.facing = 1
	city.robot.velocity.x = city.robot.max_speed * 0.8
	var attack_id: int = city.robot.request_attack()
	var spec: AttackSpec = city.contextual_attacks.current_spec
	await get_tree().create_timer(spec.anticipation_seconds + 0.03).timeout
	await get_tree().physics_frame
	assert_gt(attack_id, 0)
	assert_true(city.building.is_cell_destroyed(0, 1))
	assert_false(city.building.is_cell_destroyed(1, 1))
	assert_false(city.building.is_cell_destroyed(2, 1))
	for column: int in range(StructuralBuilding2D.COLUMNS):
		assert_false(city.building.is_cell_destroyed(column, 0))
	var upper_cell: Destructible2D = city.building.get_cell(0, 0)
	var upper_pattern: BuildingDamagePattern2D = upper_cell.get_node(
		^"DamagedVisual"
	) as BuildingDamagePattern2D
	assert_almost_eq(upper_cell.current_health, upper_cell.max_health * 0.5, 0.01)
	assert_true(upper_pattern.visible)
	assert_gt(upper_pattern.crack_count(), 0)
	assert_eq(city.building.destroyed_cell_count(), 1)
	assert_false(city.building.is_destroyed())
	assert_eq(city.score, 994)
	assert_eq(city.last_material_audio, &"concrete")
	assert_eq(city.material_audio_play_count, 2)
	var glass_audio: AudioStreamPlayer2D = city.impact_audio_root.get_child(0)
	assert_eq(glass_audio.stream, city.GLASS_IMPACT_SFX)
	assert_eq(glass_audio.get_meta(&"structural_material"), &"glass")
	var collision: CollisionShape2D = city.building.get_cell(0, 1).get_node(
		^"IntactBody/CollisionShape2D"
	) as CollisionShape2D
	assert_true(collision.disabled)
	var particles: CPUParticles2D = city.get_node_or_null(
		^"ImpactFragments"
	) as CPUParticles2D
	assert_not_null(particles)
	assert_eq(particles.get_meta(&"structural_material"), &"glass")
	var high_forward_shrapnel: int = 0
	for child: Node in city.debris_pool.get_children():
		var debris: DebrisBody2D = child as DebrisBody2D
		if debris == null or not debris.visible:
			continue
		if debris.linear_velocity.x > 400.0 and debris.linear_velocity.y < -400.0:
			high_forward_shrapnel += 1
	assert_gte(high_forward_shrapnel, 4)
	var score_label: Label = city.get_node(^"HUD/ScoreLabel") as Label
	assert_eq(score_label.text, "00000994")
	_record_test_execution()


func test_destroyed_floor_triggers_staggered_chain_collapse() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	for column: int in [0, 1]:
		var cell: Destructible2D = city.building.get_cell(column, 1)
		cell.receive_damage(_fatal_cell_event(city, cell, 8100 + column))
		await get_tree().process_frame
	assert_eq(city.building.destroyed_cell_count(), 2)
	for column: int in range(StructuralBuilding2D.COLUMNS):
		assert_false(city.building.is_cell_destroyed(column, 0))
	var final_support: Destructible2D = city.building.get_cell(2, 1)
	final_support.receive_damage(_fatal_cell_event(city, final_support, 8102))
	await _wait_for_chain_reaction(city.building)
	assert_eq(city.building.destroyed_cell_count(), 6)
	assert_true(city.building.is_destroyed())
	assert_eq(city.building.last_chain_reaction_kind, &"floor_chain")
	assert_eq(city.building.chain_reaction_count, 1)
	for column: int in range(StructuralBuilding2D.COLUMNS):
		assert_true(city.building.is_cell_destroyed(column, 0))
	_record_test_execution()


func test_all_steel_supports_trigger_building_wide_chain_reaction() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var upper_steel: Destructible2D = city.building.get_cell(1, 0)
	var lower_steel: Destructible2D = city.building.get_cell(2, 1)
	upper_steel.receive_damage(_fatal_cell_event(city, upper_steel, 8201))
	await get_tree().process_frame
	assert_eq(city.building.destroyed_cell_count(), 1)
	lower_steel.receive_damage(_fatal_cell_event(city, lower_steel, 8202))
	await _wait_for_chain_reaction(city.building)
	assert_true(city.building.is_destroyed())
	assert_eq(city.building.last_chain_reaction_kind, &"steel_support_chain")
	assert_eq(city.building.chain_reaction_count, 1)
	assert_gte(city.material_audio_play_count, 4)
	_record_test_execution()


func test_walking_stops_at_building_until_jab_cross_opens_one_bay() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.robot.set_physics_process(false)
	for enemy: EnemyActor2D in [city.soldier, city.tank, city.helicopter]:
		enemy.set_physics_process(false)
	city.robot.position = Vector2(1050.0, 460.0)
	var glass_cell: Destructible2D = city.building.get_cell(0, 1)
	for step_index: int in range(120):
		city.robot.physics_step(1.0, 1.0 / 60.0)
		await get_tree().physics_frame
	assert_lt(city.robot.position.x, 1170.0)
	assert_false(glass_cell.is_destroyed())
	assert_eq(glass_cell.current_health, glass_cell.max_health)
	city.robot.facing = 1
	city.robot.velocity.x = city.robot.max_speed * 0.8
	var attack_id: int = city.robot.request_attack()
	var spec: AttackSpec = city.contextual_attacks.current_spec
	assert_true(spec.is_jab_cross())
	await get_tree().create_timer(spec.anticipation_seconds + 0.03).timeout
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_gt(attack_id, 0)
	assert_true(glass_cell.is_destroyed())
	await get_tree().process_frame
	assert_false(city.urban_siege.pause_coordinator.is_paused())
	for step_index: int in range(90):
		city.robot.physics_step(1.0, 1.0 / 60.0)
		await get_tree().physics_frame
	assert_gt(city.robot.position.x, 1200.0)
	assert_lt(city.robot.position.x, 1340.0)
	assert_false(city.building.is_cell_destroyed(1, 1))
	assert_false(city.building.is_destroyed())
	assert_gt(city.debris_pool.active_count(), 0)
	_record_test_execution()


func test_enemy_defeat_adds_score_once() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var fatal_event: DamageEvent = DamageEvent.new(7001, city.robot, 999.0)
	assert_true(city.soldier.receive_damage(fatal_event))
	assert_eq(city.score, 250)
	assert_false(city.soldier.receive_damage(fatal_event))
	assert_eq(city.score, 250)
	_record_test_execution()


func test_defeated_soldier_flies_as_one_sprite_then_fades_and_culls() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.soldier.set_physics_process(false)
	var fatal_event: DamageEvent = DamageEvent.new(
		7101,
		city.robot,
		999.0,
		&"impact",
		city.soldier.global_position,
		Vector2(1.0, -0.28),
		360.0
	)
	assert_true(city.soldier.receive_damage(fatal_event))
	await get_tree().process_frame
	assert_false(city.soldier.visual.visible)
	assert_not_null(city.soldier_defeat_body)
	assert_eq(city.soldier_defeat_body.get_child_count(), 2)
	var body_visual: Sprite2D = city.soldier_defeat_body.get_node(
		^"Visual"
	) as Sprite2D
	assert_eq(
		body_visual.texture,
		load("res://art/city/enemies/soldier.png")
	)
	await get_tree().physics_frame
	assert_gt(city.soldier_defeat_body.linear_velocity.length(), 1.0)
	assert_gt(absf(city.soldier_defeat_body.angular_velocity), 1.0)
	city.soldier_defeat_body.fade_delay = 0.05
	city.soldier_defeat_body.fade_duration = 0.08
	await get_tree().create_timer(0.08).timeout
	assert_lt(city.soldier_defeat_body.fade_alpha(), 1.0)
	await get_tree().create_timer(0.12).timeout
	assert_false(city.soldier_defeat_body.is_active())
	assert_eq(city.soldier_defeat_pool.active_count(), 0)
	assert_eq(city.soldier_defeat_pool.available_count(), 8)
	_record_test_execution()


func test_defeated_machinery_becomes_wreck_then_stomp_scrap() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var tank_event: DamageEvent = DamageEvent.new(
		7201,
		city.robot,
		999.0,
		&"impact",
		city.tank.global_position,
		Vector2(1.0, -0.18),
		280.0
	)
	assert_true(city.tank.receive_damage(tank_event))
	await get_tree().process_frame
	assert_eq(city.score, 750)
	assert_eq(city.rampage_session.current_multiplier(), 1)
	assert_eq(city.rampage_session.momentum_value(), 16.0)
	assert_false(city.tank.visual.visible)
	assert_not_null(city.tank_wreck)
	assert_eq(city.tank_wreck.wreck_kind, &"tank")
	await get_tree().physics_frame
	assert_gt(city.tank_wreck.linear_velocity.length(), 1.0)
	city.tank_wreck.freeze = true
	city.tank_wreck.global_position = city.robot.global_position + Vector2(120.0, 150.0)
	city.tank_wreck.force_update_transform()
	PhysicsServer2D.body_set_state(
		city.tank_wreck.get_rid(),
		PhysicsServer2D.BODY_STATE_TRANSFORM,
		city.tank_wreck.global_transform
	)
	city.tank_wreck.linear_velocity = Vector2.ZERO
	city.tank_wreck.angular_velocity = 0.0
	city.tank_wreck.current_scrap_health = 1.0
	city.car.global_position = Vector2(3000.0, 600.0)
	city.streetlamp.global_position = Vector2(3200.0, 600.0)
	city.robot.stomp_radius = 500.0
	await get_tree().physics_frame
	city.trigger_test_stomp()
	for resolution_tick: int in range(6):
		await get_tree().physics_frame
		if city.tank_wreck.is_scrapped():
			break
	assert_true(city.tank_wreck.is_scrapped())
	assert_eq(city.score, 1150)
	assert_eq(city.rampage_session.current_multiplier(), 1)
	assert_eq(city.rampage_session.momentum_value(), 16.0)
	assert_eq(city.enemy_scrap_pool.active_count(), 8)
	for child: Node in city.enemy_scrap_pool.get_children():
		var scrap: DebrisBody2D = child as DebrisBody2D
		if scrap == null or not scrap.visible:
			continue
		assert_eq(scrap.material_id(), &"steel")
		assert_eq(scrap.get_meta(&"enemy_remains"), &"scrap")
		assert_eq(scrap.collision_layer, CitySlice.REMAINS_LAYER)
	var helicopter_event: DamageEvent = DamageEvent.new(
		7202,
		city.robot,
		999.0,
		&"impact",
		city.helicopter.global_position,
		Vector2.LEFT,
		240.0
	)
	assert_true(city.helicopter.receive_damage(helicopter_event))
	await get_tree().process_frame
	assert_eq(city.score, 1750)
	assert_eq(city.rampage_session.current_multiplier(), 1)
	assert_eq(city.rampage_session.momentum_value(), 16.0)
	assert_not_null(city.helicopter_wreck)
	assert_eq(city.helicopter_wreck.wreck_kind, &"helicopter")
	assert_true(city.helicopter_wreck.is_crashing())
	assert_gt(city.helicopter_wreck.linear_velocity.y, 0.0)
	assert_gt(absf(city.helicopter_wreck.angular_velocity), 1.0)
	var crash_start_y: float = city.helicopter_wreck.global_position.y
	for crash_frame: int in range(70):
		await get_tree().physics_frame
	assert_gt(city.helicopter_wreck.global_position.y, crash_start_y + 200.0)
	assert_false(city.helicopter_wreck.is_crashing())
	assert_eq(city.helicopter_wreck.crash_landing_count, 1)
	_record_test_execution()


func test_horde_remains_pools_recycle_oldest_without_growing() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	for corpse_index: int in range(12):
		city.soldier_defeat_pool.acquire(
			Vector2(900.0 + corpse_index * 12.0, 640.0),
			-1,
			DamageEvent.new(7300 + corpse_index, city.robot, 999.0)
		)
	assert_eq(city.soldier_defeat_pool.active_count(), 8)
	assert_eq(city.soldier_defeat_pool.total_count(), 8)
	assert_eq(city.soldier_defeat_pool.recycle_count, 4)
	for scrap_index: int in range(40):
		city.enemy_scrap_pool.acquire(
			Transform2D(0.0, Vector2(900.0 + scrap_index, 600.0)),
			Vector2.RIGHT * 20.0,
			0.0,
			4.0,
			Vector2(30.0, 14.0),
			&"steel"
		)
	assert_eq(city.enemy_scrap_pool.active_count(), 32)
	assert_eq(city.enemy_scrap_pool.get_child_count(), 32)
	assert_eq(city.enemy_scrap_pool.recycle_count, 8)
	for debris_index: int in range(30):
		city.debris_pool.acquire(
			Transform2D(0.0, Vector2(900.0 + debris_index, 600.0)),
			Vector2.RIGHT * 20.0
		)
	assert_eq(city.debris_pool.active_count(), 24)
	assert_eq(city.debris_pool.get_child_count(), 24)
	assert_eq(city.debris_pool.recycle_count, 6)
	_record_test_execution()


func test_robot_passes_through_destroyed_car_wreck_and_scrap() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	for enemy: EnemyActor2D in [city.soldier, city.tank, city.helicopter]:
		enemy.set_physics_process(false)
	city.car.current_health = 1.0
	city.car.receive_damage(DamageEvent.new(7401, city.robot, 999.0))
	await get_tree().physics_frame
	city.car.freeze = true
	city.car.global_position = Vector2(940.0, 610.0)
	var car_start: Vector2 = city.car.global_position
	var scrap: DebrisBody2D = city.enemy_scrap_pool.acquire(
		Transform2D(0.0, Vector2(1040.0, 625.0)),
		Vector2.ZERO,
		0.0,
		8.0,
		Vector2(60.0, 24.0),
		&"steel"
	)
	scrap.collision_layer = CitySlice.REMAINS_LAYER
	scrap.collision_mask = CitySlice.REMAINS_GROUND_LAYER
	scrap.freeze = true
	var scrap_start: Vector2 = scrap.global_position
	city.robot.set_physics_process(false)
	for frame_index: int in range(180):
		city.robot.physics_step(1.0, 1.0 / 60.0)
		await get_tree().physics_frame
	assert_gt(city.robot.position.x, 1120.0)
	assert_eq(city.car.global_position, car_start)
	assert_eq(scrap.global_position, scrap_start)
	assert_eq(city.robot.collision_mask & CitySlice.REMAINS_LAYER, 0)
	_record_test_execution()


func test_robot_attack_scatters_defeated_soldier_scrap_and_debris() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var attack_origin: Vector2 = city.robot.global_position + Vector2(100.0, 140.0)
	var defeated_soldier: SoldierDefeatBody2D = city.soldier_defeat_pool.acquire(
		attack_origin,
		-1,
		DamageEvent.new(7501, city.robot, 999.0)
	)
	defeated_soldier.linear_velocity = Vector2.ZERO
	defeated_soldier.angular_velocity = 0.0
	var scrap: DebrisBody2D = city.enemy_scrap_pool.acquire(
		Transform2D(0.0, attack_origin + Vector2(35.0, 0.0)),
		Vector2.ZERO,
		0.0,
		8.0,
		Vector2(55.0, 22.0),
		&"steel"
	)
	scrap.collision_layer = CitySlice.REMAINS_LAYER
	scrap.collision_mask = CitySlice.REMAINS_GROUND_LAYER
	var debris: DebrisBody2D = city.debris_pool.acquire(
		Transform2D(0.0, attack_origin + Vector2(-35.0, 0.0)),
		Vector2.ZERO
	)
	await get_tree().physics_frame
	defeated_soldier.linear_velocity = Vector2.ZERO
	scrap.linear_velocity = Vector2.ZERO
	debris.linear_velocity = Vector2.ZERO
	city.robot.stomp_radius = 500.0
	assert_eq(city.robot.stomp_impulse_per_mass, 1020.0)
	city.trigger_test_stomp()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_gt(defeated_soldier.linear_velocity.length(), 100.0)
	assert_gt(scrap.linear_velocity.length(), 100.0)
	assert_gt(debris.linear_velocity.length(), 100.0)
	_record_test_execution()


func test_smash_concentrates_shrapnel_on_closest_overhead_enemy() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	var origin: Vector2 = (
		city.robot.get_node(^"GroundImpactOrigin") as Node2D
	).global_position
	var farther_overhead: EnemyActor2D = city.encounter_runtime.acquire(
		&"needle",
		origin + Vector2(70.0, -600.0)
	)
	var closest_overhead: EnemyActor2D = city.encounter_runtime.acquire(
		&"helicopter",
		origin + Vector2(35.0, -440.0)
	)
	var closer_side_target: EnemyActor2D = city.encounter_runtime.acquire(
		&"hound",
		origin + Vector2(330.0, -120.0)
	)
	for enemy: EnemyActor2D in [farther_overhead, closest_overhead, closer_side_target]:
		assert_not_null(enemy)
		enemy.set_physics_process(false)
	await get_tree().physics_frame
	assert_true(AerialDebrisLauncher._is_in_overhead_cone(farther_overhead, origin))
	assert_true(AerialDebrisLauncher._is_in_overhead_cone(closest_overhead, origin))
	assert_false(AerialDebrisLauncher._is_in_overhead_cone(closer_side_target, origin))
	assert_same(AerialDebrisLauncher._nearest_target(get_tree(), origin), closest_overhead)
	farther_overhead.active = false
	closest_overhead.active = false
	assert_same(AerialDebrisLauncher._nearest_target(get_tree(), origin), closer_side_target)
	farther_overhead.active = true
	closest_overhead.active = true
	var acquired_stream: AudioStreamWAV = (
		AirTargetLockRuntime.TARGET_ACQUIRED_SFX as AudioStreamWAV
	)
	var lost_stream: AudioStreamWAV = AirTargetLockRuntime.TARGET_LOST_SFX as AudioStreamWAV
	var destroyed_stream: AudioStreamWAV = (
		AirTargetLockRuntime.TARGET_DESTROYED_SFX as AudioStreamWAV
	)
	assert_eq(acquired_stream.format, AudioStreamWAV.FORMAT_QOA)
	assert_eq(lost_stream.format, AudioStreamWAV.FORMAT_QOA)
	assert_eq(destroyed_stream.format, AudioStreamWAV.FORMAT_QOA)
	assert_eq(acquired_stream.mix_rate, 48000)
	assert_eq(lost_stream.mix_rate, 48000)
	assert_eq(destroyed_stream.mix_rate, 48000)
	assert_false(acquired_stream.stereo)
	assert_false(lost_stream.stereo)
	assert_false(destroyed_stream.stereo)
	assert_between(acquired_stream.get_length(), 1.75, 1.86)
	assert_between(lost_stream.get_length(), 1.25, 1.36)
	assert_between(destroyed_stream.get_length(), 1.34, 1.45)
	assert_eq(city.air_target_lock_runtime.voice_player_count(), 1)
	assert_eq(
		(city.air_target_lock_runtime.get_node(^"AirTargetVoice") as AudioStreamPlayer).bus,
		GameAudioBus.VOICE
	)
	assert_eq(city.air_target_lock_runtime.reticle_count(), 1)
	assert_false(city.air_target_lock_runtime.reticle_visible())
	var lock_reticle: AirTargetReticle2D = city.air_target_lock_runtime.get_node(
		^"AirTargetReticle"
	) as AirTargetReticle2D
	assert_false(lock_reticle.is_processing())
	var attack_id: int = city.robot.request_attack()
	var spec: AttackSpec = city.contextual_attacks.current_spec
	assert_gt(attack_id, 0)
	assert_true(spec.is_ground_smash())
	assert_same(city.air_target_lock_runtime.current_target(), closest_overhead)
	assert_true(city.air_target_lock_runtime.reticle_visible())
	assert_same(city.air_target_lock_runtime.reticle_target(), closest_overhead)
	assert_eq(lock_reticle.global_position, closest_overhead.global_position)
	assert_true(lock_reticle.is_processing())
	assert_false(lock_reticle.is_release_imminent())
	assert_eq(lock_reticle.pulse_strength(), 0.0)
	city.air_target_lock_runtime._process(
		spec.anticipation_seconds
		* (AirTargetReticle2D.IMMINENT_START_PROGRESS - 0.05)
	)
	assert_false(lock_reticle.is_release_imminent())
	assert_eq(lock_reticle.pulse_strength(), 0.0)
	city.air_target_lock_runtime._process(spec.anticipation_seconds * 0.06)
	assert_true(lock_reticle.is_release_imminent())
	assert_gt(lock_reticle.telegraph_progress(), AirTargetReticle2D.IMMINENT_START_PROGRESS)
	lock_reticle._process(0.05)
	assert_gt(lock_reticle.pulse_strength(), 0.0)
	assert_eq(city.air_target_lock_runtime.target_acquired_play_count, 1)
	assert_eq(city.air_target_lock_runtime.last_voice_cue, &"air_target_acquired")
	closest_overhead.global_position = origin + Vector2(520.0, -120.0)
	city.air_target_lock_runtime._process(0.0)
	assert_null(city.air_target_lock_runtime.current_target())
	assert_false(city.air_target_lock_runtime.reticle_visible())
	assert_null(city.air_target_lock_runtime.reticle_target())
	assert_false(lock_reticle.is_processing())
	assert_false(lock_reticle.is_release_imminent())
	assert_eq(city.air_target_lock_runtime.target_lost_play_count, 1)
	assert_eq(city.air_target_lock_runtime.last_voice_cue, &"target_lost")
	closest_overhead.global_position = origin + Vector2(35.0, -440.0)
	city.air_target_lock_runtime._process(0.0)
	assert_same(city.air_target_lock_runtime.current_target(), closest_overhead)
	assert_true(city.air_target_lock_runtime.reticle_visible())
	assert_same(city.air_target_lock_runtime.reticle_target(), closest_overhead)
	assert_true(lock_reticle.is_processing())
	assert_true(lock_reticle.is_release_imminent())
	assert_eq(city.air_target_lock_runtime.target_acquired_play_count, 2)
	closest_overhead.dead = true
	city.air_target_lock_runtime._process(0.0)
	assert_null(city.air_target_lock_runtime.current_target())
	assert_eq(city.air_target_lock_runtime.target_destroyed_play_count, 1)
	assert_eq(city.air_target_lock_runtime.last_voice_cue, &"target_destroyed")
	closest_overhead.dead = false
	closest_overhead.active = true
	closest_overhead.current_health = closest_overhead.max_health
	city.air_target_lock_runtime._process(0.0)
	assert_same(city.air_target_lock_runtime.current_target(), closest_overhead)
	assert_eq(city.air_target_lock_runtime.target_acquired_play_count, 3)
	var target_health_before: float = closest_overhead.current_health
	var side_health_before: float = closer_side_target.current_health
	await get_tree().create_timer(spec.anticipation_seconds + 0.03).timeout
	var volley_debris: Array[DebrisBody2D] = []
	for debris: DebrisBody2D in city.debris_pool.active_bodies():
		if debris.aerial_impact_armed:
			volley_debris.append(debris)
	assert_eq(volley_debris.size(), 3)
	assert_null(city.air_target_lock_runtime.current_target())
	assert_false(city.air_target_lock_runtime.reticle_visible())
	assert_null(city.air_target_lock_runtime.reticle_target())
	assert_false(lock_reticle.is_processing())
	assert_false(lock_reticle.is_release_imminent())
	for launch_tick: int in range(2):
		await get_tree().physics_frame
		if volley_debris.any(
			func(debris: DebrisBody2D) -> bool:
				return debris.linear_velocity.length() > 100.0
		):
			break
	var minimum_angle: float = INF
	var maximum_angle: float = -INF
	for debris: DebrisBody2D in volley_debris:
		assert_true(debris.aerial_impact_armed)
		assert_gt(debris.linear_velocity.length(), 100.0)
		var launch_angle: float = debris.linear_velocity.angle()
		minimum_angle = minf(minimum_angle, launch_angle)
		maximum_angle = maxf(maximum_angle, launch_angle)
	assert_lte(rad_to_deg(maximum_angle - minimum_angle), 8.0)
	var hit_registered: bool = false
	for physics_tick: int in range(90):
		await get_tree().physics_frame
		if closest_overhead.current_health < target_health_before:
			hit_registered = true
			break
	assert_true(hit_registered)
	assert_gt(closest_overhead.current_health, target_health_before - 13.0)
	assert_false(closest_overhead.dead)
	assert_eq(closer_side_target.current_health, side_health_before)
	assert_gte(city.rampage_session.momentum_value(), 20.0)
	assert_gte(city.score, 250)
	_record_test_execution()


func test_land_visuals_use_curb_and_vehicle_centerline_baselines() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	city.soldier.set_physics_process(false)
	city.tank.set_physics_process(false)
	await get_tree().process_frame
	var street_chunk: CityStreetChunk = city.world_stream.chunk_for_logical(0)
	var road_surface: Polygon2D = street_chunk.road_surface
	var lower_asphalt: Polygon2D = street_chunk.lower_asphalt
	assert_eq(lower_asphalt.color, road_surface.color)
	var lower_cell: Destructible2D = city.building.get_cell(0, 1)
	var lower_visual: Sprite2D = lower_cell.get_node(^"IntactVisual") as Sprite2D
	var curb_side_visuals: Array[Sprite2D] = [
		lower_visual,
		city.streetlamp.get_node(^"Visual") as Sprite2D,
		city.car.get_node(^"Visual") as Sprite2D,
		city.soldier.get_node(^"Visual") as Sprite2D,
	]
	for visual: Sprite2D in curb_side_visuals:
		assert_almost_eq(_visual_bottom(visual), LAND_VISUAL_BASELINE_Y, 1.0)
	assert_almost_eq(
		_visual_bottom(city.tank.get_node(^"Visual") as Sprite2D),
		LAND_VEHICLE_VISUAL_BASELINE_Y,
		1.0
	)
	var jackal: EnemyActor2D = city.encounter_runtime.acquire(
		&"jackal",
		Vector2(1080.0, 554.0)
	)
	assert_not_null(jackal)
	if jackal != null:
		jackal.set_physics_process(false)
		assert_almost_eq(
			_visual_bottom(jackal.visual),
			LAND_VEHICLE_VISUAL_BASELINE_Y,
			1.0
		)
	_record_test_execution()


func test_ground_enemies_bounce_only_while_moving() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	city.soldier.set_physics_process(false)
	city.tank.set_physics_process(false)
	city.soldier.velocity.x = 0.0
	city.tank.velocity.x = 0.0
	for settle_step: int in range(12):
		city.soldier.update_movement_bounce(0.1)
		city.tank.update_movement_bounce(0.1)
	var soldier_rest_y: float = city.soldier.visual.position.y
	var tank_rest_y: float = city.tank.visual.position.y
	city.soldier.velocity.x = city.soldier.move_speed
	city.tank.velocity.x = city.tank.move_speed
	city.soldier.update_movement_bounce(0.06)
	city.tank.update_movement_bounce(0.08)
	assert_lt(city.soldier.visual.position.y, soldier_rest_y)
	assert_lt(city.tank.visual.position.y, tank_rest_y)
	assert_false(city.helicopter.movement_bounce_enabled)
	_record_test_execution()


func test_game_over_retry_restarts_current_district_with_zero_rampage_credit() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	main.start_game()
	await get_tree().process_frame
	main.title_transition_duration_scale = 0.18
	var first_city: CitySlice = main.city_slice
	var retry_district: CityDistrictProfile = CityDistrictCatalog.districts()[2]
	first_city.robot.global_position.x = (
		first_city.world_stream.runtime_x_for_logical_index(retry_district.start_chunk)
		+ CityWorldBuilder.ROBOT_START_POSITION.x
	)
	first_city.world_stream.advance_stream()
	first_city.world_stream.unlocked_district_index = retry_district.district_index
	assert_eq(first_city.world_stream.current_district_id, retry_district.district_id)
	first_city._add_score(500)
	first_city.rampage_session.publish(GameplayEvent.new(
		&"retry_seed",
		0,
		GameplayEvent.Kind.DAMAGE_APPLIED,
		&"seed",
		0,
		25.0,
		true
	))
	var fatal_event: DamageEvent = DamageEvent.new(9001, null, 9999.0)
	assert_true(first_city.robot.receive_damage(fatal_event))
	for _frame: int in range(240):
		if not main.title_transition_active:
			break
		await get_tree().process_frame
	assert_true(first_city.game_over_active)
	var overlay: Control = first_city.get_node(^"HUD/GameOverOverlay") as Control
	var retry_button: Button = overlay.get_node(^"RetryButton") as Button
	assert_true(overlay.visible)
	retry_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_ne(main.city_slice, first_city)
	assert_false(main.city_slice.game_over_active)
	assert_eq(main.city_slice.world_stream.current_district_id, retry_district.district_id)
	assert_eq(main.city_slice.world_stream.current_logical_chunk, retry_district.start_chunk)
	assert_eq(
		main.city_slice.world_stream.floating_origin.origin_chunk,
		retry_district.start_chunk
	)
	assert_lt(main.city_slice.robot.global_position.x, CityWorldStream.CHUNK_WIDTH)
	assert_eq(main.city_slice.robot.current_health, main.city_slice.robot.max_health)
	assert_eq(main.city_slice.score, 0)
	assert_eq(main.city_slice.rampage_session.current_multiplier(), 1)
	assert_eq(main.city_slice.rampage_session.momentum_value(), 0.0)
	_record_test_execution()


func _fatal_cell_event(
	city: CitySlice,
	cell: Destructible2D,
	attack_id: int
) -> DamageEvent:
	return DamageEvent.new(
		attack_id,
		city.robot,
		cell.max_health + 1.0,
		&"structural",
		cell.global_position,
		Vector2.RIGHT,
		260.0
	)


func _visual_bottom(visual: Sprite2D) -> float:
	var rendered_height: float = visual.region_rect.size.y * absf(visual.global_scale.y)
	if not visual.region_enabled:
		rendered_height = visual.texture.get_size().y * absf(visual.global_scale.y)
	return visual.global_position.y + rendered_height * 0.5


func _wait_for_chain_reaction(building: StructuralBuilding2D) -> void:
	for frame_index: int in range(120):
		await get_tree().process_frame
		if building.is_destroyed() and not building.is_chain_reaction_active():
			return
	fail_test("Structural chain reaction did not finish within 120 frames")


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
