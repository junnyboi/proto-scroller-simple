extends GutTest


func test_every_airborne_archetype_spawns_as_a_physical_crash() -> void:
	var root: Node2D = Node2D.new()
	add_child_autofree(root)
	var wreck_root: Node2D = Node2D.new()
	root.add_child(wreck_root)
	var factory: EnemyRemainsFactory = EnemyRemainsFactory.new()
	factory.setup(wreck_root, null, null, null)
	root.add_child(factory)
	await get_tree().process_frame

	var airborne_archetypes: Array[StringName] = _airborne_archetypes()
	assert_eq(airborne_archetypes.size(), 4)
	for index: int in range(airborne_archetypes.size()):
		var archetype_id: StringName = airborne_archetypes[index]
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		assert_true(bool(profile.get("airborne", false)), String(archetype_id))
		var enemy: ProceduralEnemy = _airborne_enemy(archetype_id, profile)
		root.add_child(enemy)
		await get_tree().process_frame
		enemy.global_position = Vector2(300.0 + index * 260.0, 120.0)
		var event: DamageEvent = DamageEvent.new(
			9100 + index,
			null,
			999.0,
			&"impact",
			enemy.global_position,
			Vector2.LEFT,
			240.0
		)
		var wreck: EnemyWreck2D = factory.spawn_wreck(enemy, event)
		assert_not_null(wreck, String(archetype_id))
		assert_true(wreck is RigidBody2D, String(archetype_id))
		assert_true(wreck.is_crashing(), String(archetype_id))
		assert_true(wreck.is_settling_to_road(), String(archetype_id))
		assert_false(wreck.freeze, String(archetype_id))
		assert_gt(wreck.gravity_scale, 1.0, String(archetype_id))
		assert_gt(wreck.linear_velocity.y, 0.0, String(archetype_id))
		assert_gt(absf(wreck.angular_velocity), 1.0, String(archetype_id))
		assert_ne(wreck.collision_mask & EnemyWreck2D.ROBOT_LAYER, 0, String(archetype_id))
		assert_ne(wreck.collision_mask & EnemyWreck2D.ENEMY_LAYER, 0, String(archetype_id))
		assert_eq(
			wreck.collision_mask
			& (
				EnemyWreck2D.BUILDING_LAYER
				| EnemyWreck2D.PROP_LAYER
				| EnemyWreck2D.REMAINS_LAYER
			),
			0,
			String(archetype_id)
		)


func test_airborne_wreck_falls_and_lands_on_the_remains_ground_layer() -> void:
	var ground: StaticBody2D = StaticBody2D.new()
	ground.collision_layer = EnemyWreck2D.REMAINS_GROUND_LAYER
	ground.collision_mask = 0
	ground.position = Vector2(640.0, 540.0)
	var ground_shape: CollisionShape2D = CollisionShape2D.new()
	var ground_rectangle: RectangleShape2D = RectangleShape2D.new()
	ground_rectangle.size = Vector2(1600.0, 40.0)
	ground_shape.shape = ground_rectangle
	ground.add_child(ground_shape)
	add_child_autofree(ground)

	var wreck: EnemyWreck2D = EnemyWreck2D.new()
	add_child_autofree(wreck)
	await get_tree().process_frame
	var start_position: Vector2 = Vector2(640.0, 120.0)
	wreck.activate(
		&"helicopter",
		null,
		Vector2(235.0, 72.0),
		Vector2(210.0, 58.0),
		38.0,
		85.0,
		start_position,
		DamageEvent.new(
			9200,
			null,
			999.0,
			&"impact",
			start_position,
			Vector2.LEFT,
			240.0
		),
		true
	)

	for frame: int in range(90):
		await get_tree().physics_frame
		if not wreck.is_crashing():
			break

	assert_gt(wreck.global_position.y, start_position.y + 200.0)
	assert_false(wreck.is_crashing())
	assert_false(wreck.is_settling_to_road())
	assert_eq(wreck.crash_landing_count, 1)
	assert_almost_eq(wreck.visible_bottom_y(), 520.0, 2.0)
	assert_true(wreck.can_sleep)
	assert_eq(
		wreck.collision_mask
		& (
			EnemyWreck2D.ENEMY_LAYER
			| EnemyWreck2D.BUILDING_LAYER
			| EnemyWreck2D.PROP_LAYER
			| EnemyWreck2D.REMAINS_LAYER
		),
		0
	)
	assert_ne(wreck.collision_mask & EnemyWreck2D.ROBOT_LAYER, 0)
	assert_ne(wreck.collision_mask & EnemyWreck2D.REMAINS_GROUND_LAYER, 0)


func test_falling_wreck_damages_an_enemy_body_once() -> void:
	var enemy: EnemyActor2D = _damageable_enemy(Vector2(680.0, 390.0), 240.0)
	add_child_autofree(enemy)
	var wreck: EnemyWreck2D = EnemyWreck2D.new()
	add_child_autofree(wreck)
	await get_tree().process_frame
	_activate_crashing_wreck(wreck, Vector2(640.0, 100.0), 38.0)

	for frame: int in range(90):
		await get_tree().physics_frame
		if wreck.crash_impact_count > 0:
			break

	assert_eq(wreck.crash_impact_count, 1)
	assert_lt(enemy.current_health, enemy.max_health)
	var health_after_impact: float = enemy.current_health
	for frame: int in range(10):
		await get_tree().physics_frame
	assert_eq(wreck.crash_impact_count, 1)
	assert_eq(enemy.current_health, health_after_impact)


func test_falling_wreck_ignores_destructible_props_and_keeps_falling() -> void:
	var prop: DestructibleProp2D = _damageable_prop(Vector2(680.0, 390.0), 320.0)
	add_child_autofree(prop)
	var wreck: EnemyWreck2D = EnemyWreck2D.new()
	add_child_autofree(wreck)
	await get_tree().process_frame
	_activate_crashing_wreck(wreck, Vector2(640.0, 100.0), 38.0)

	var start_y: float = wreck.global_position.y
	for frame: int in range(45):
		await get_tree().physics_frame

	assert_eq(wreck.crash_impact_count, 0)
	assert_eq(prop.current_health, prop.max_health)
	assert_false(prop.is_fully_destroyed)
	assert_gt(wreck.global_position.y, start_y + 140.0)


func _airborne_enemy(archetype_id: StringName, profile: Dictionary) -> ProceduralEnemy:
	var enemy: ProceduralEnemy = ProceduralEnemy.new()
	var visual: Sprite2D = Sprite2D.new()
	visual.name = "Visual"
	enemy.add_child(visual)
	enemy.configure_archetype(archetype_id, profile)
	return enemy


func _airborne_archetypes() -> Array[StringName]:
	var result: Array[StringName] = []
	for archetype_id: StringName in EnemyArchetypeCatalog.ALL_SPAWNABLE_IDS:
		if EnemyArchetypeCatalog.is_airborne(archetype_id):
			result.append(archetype_id)
	return result


func _activate_crashing_wreck(
	wreck: EnemyWreck2D,
	spawn_position: Vector2,
	body_mass: float
) -> void:
	wreck.activate(
		&"helicopter",
		null,
		Vector2(100.0, 60.0),
		Vector2(90.0, 50.0),
		body_mass,
		85.0,
		spawn_position,
		DamageEvent.new(
			9300,
			null,
			999.0,
			&"impact",
			spawn_position,
			Vector2.RIGHT,
			240.0
		),
		true
	)


func _damageable_enemy(spawn_position: Vector2, health: float) -> EnemyActor2D:
	var enemy: EnemyActor2D = EnemyActor2D.new()
	enemy.max_health = health
	enemy.collision_layer = EnemyWreck2D.ENEMY_LAYER
	enemy.collision_mask = 0
	enemy.position = spawn_position
	var collision: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(120.0, 100.0)
	collision.shape = rectangle
	enemy.add_child(collision)
	return enemy


func _damageable_prop(spawn_position: Vector2, health: float) -> DestructibleProp2D:
	var prop: DestructibleProp2D = DestructibleProp2D.new()
	prop.max_health = health
	prop.wreck_health = health
	prop.collision_layer = EnemyWreck2D.PROP_LAYER
	prop.collision_mask = 0
	prop.position = spawn_position
	var visual: Sprite2D = Sprite2D.new()
	visual.name = "Visual"
	prop.add_child(visual)
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(120.0, 100.0)
	collision.shape = rectangle
	prop.add_child(collision)
	return prop
