extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_fixed_pool_activates_one_drone_per_offensive_rank() -> void:
	var city: CitySlice = await _spawn_city()
	var orbit: WeaponDroneOrbit2D = city.upgrade_assembler.drone_orbit
	assert_not_null(orbit)
	assert_almost_eq(
		orbit.position.y,
		CityWorldBuilder.ROBOT_ROAD_CENTER_VISUAL_OFFSET_Y,
		0.001
	)
	assert_eq(orbit.drones.size(), RuntimeBudget.WEAPON_DRONES)
	assert_eq(orbit.active_count(), 0)
	var machine: MachineGunRuntime = _machine(city)
	var missiles: MissileWeapon = _missiles(city)
	assert_true(machine.apply_rank(3))
	assert_true(missiles.apply_rank(2))
	assert_eq(orbit.active_count(), 5)
	assert_eq(orbit.active_drones_for(&"MACHINE_GUN").size(), 3)
	assert_eq(orbit.active_drones_for(&"MISSILE").size(), 2)
	assert_eq(machine.drones.size(), 5)
	assert_eq(missiles.drones.size(), 4)
	assert_same(
		machine.drones[0].chassis_sprite.texture,
		missiles.drones[0].chassis_sprite.texture
	)
	assert_ne(machine.drones[0].weapon_sprite.texture, missiles.drones[0].weapon_sprite.texture)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func test_chassis_flips_with_orbit_travel_while_weapon_aims_independently() -> void:
	var city: CitySlice = await _spawn_city()
	var orbit: WeaponDroneOrbit2D = city.upgrade_assembler.drone_orbit
	var machine: MachineGunRuntime = _machine(city)
	machine.apply_rank(1)
	var drone: WeaponDroneVisual2D = machine.drones[0]
	orbit.set_process(false)
	orbit.orbit_angle = PI * 0.5
	orbit._process(0.0)
	assert_eq(drone.chassis_facing, -1)
	assert_true(drone.chassis_sprite.flip_h)
	var chassis_position: Vector2 = drone.position
	drone.aim_at(Vector2.UP)
	assert_almost_eq(drone.weapon_pivot.rotation, -PI * 0.5, 0.001)
	assert_eq(drone.chassis_facing, -1)
	assert_eq(drone.position, chassis_position)
	assert_false(drone.weapon_sprite.flip_v)
	drone.aim_at(Vector2.LEFT)
	assert_almost_eq(absf(drone.weapon_pivot.rotation), PI, 0.001)
	assert_true(drone.weapon_sprite.flip_v)
	assert_eq(drone.chassis_facing, -1)


func test_rear_arc_drones_render_behind_robot_and_front_arc_above() -> void:
	var city: CitySlice = await _spawn_city()
	var orbit: WeaponDroneOrbit2D = city.upgrade_assembler.drone_orbit
	var machine: MachineGunRuntime = _machine(city)
	machine.apply_rank(1)
	var drone: WeaponDroneVisual2D = machine.drones[0]
	orbit.set_process(false)
	orbit.orbit_angle = -PI * 0.5
	orbit._process(0.0)
	assert_true(drone.behind_robot)
	assert_eq(
		drone.z_index,
		drone.base_z_index + WeaponDroneVisual2D.REAR_ORBIT_Z_OFFSET
	)
	assert_lt(orbit.z_index + drone.z_index, 0)
	orbit.orbit_angle = PI * 0.5
	orbit._process(0.0)
	assert_false(drone.behind_robot)
	assert_eq(drone.z_index, drone.base_z_index)
	assert_gt(orbit.z_index + drone.z_index, 0)


func test_orbit_slots_are_deterministic_and_separated() -> void:
	var city: CitySlice = await _spawn_city()
	var orbit: WeaponDroneOrbit2D = city.upgrade_assembler.drone_orbit
	var machine: MachineGunRuntime = _machine(city)
	machine.apply_rank(5)
	orbit.set_process(false)
	orbit.orbit_angle = 0.0
	orbit._process(0.0)
	var first_positions: Array[Vector2] = []
	for drone: WeaponDroneVisual2D in orbit.active_drones_for(&"MACHINE_GUN"):
		first_positions.append(drone.position)
	assert_eq(first_positions.size(), 5)
	for first_index: int in range(first_positions.size()):
		for second_index: int in range(first_index + 1, first_positions.size()):
			assert_gt(first_positions[first_index].distance_to(first_positions[second_index]), 40.0)
	orbit._process(0.0)
	for index: int in range(first_positions.size()):
		assert_eq(machine.drones[index].position, first_positions[index])


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	return city


func _machine(city: CitySlice) -> MachineGunRuntime:
	return city.upgrade_assembler.runtimes[&"MACHINE_GUN"] as MachineGunRuntime


func _missiles(city: CitySlice) -> MissileWeapon:
	return city.upgrade_assembler.runtimes[&"MISSILE"] as MissileWeapon
