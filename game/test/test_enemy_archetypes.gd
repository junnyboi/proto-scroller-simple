# gdlint: disable=max-public-methods
extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const DISTRICT: DistrictDefinition = preload("res://resources/siege/district_contact.tres")
const SHIELDED: EnemyTraitProfile = preload("res://resources/traits/shielded.tres")
const EXPECTED_FIRST_ACT: Dictionary = {
	&"needle": 0, &"bulwark": 0, &"jackal": 0,
	&"lobber": 1, &"sapper": 1, &"hound": 1,
}
const EXPECTED_BASELINE_PUNCHES: Dictionary = {
	&"needle": 1, &"bulwark": 3, &"jackal": 2, &"lobber": 1, &"sapper": 1,
	&"hound": 2, &"reclaimed_breacher": 8, &"graft_runner": 4,
}
const EXPECTED_FACES_RIGHT: Dictionary[StringName, bool] = {
	&"needle": false,
	&"bulwark": true,
	&"jackal": false,
	&"lobber": true,
	&"sapper": true,
	&"hound": true,
	&"reclaimed_breacher": false,
	&"graft_runner": false,
}
const GROUND_VEHICLE_IDS: Array[StringName] = [
	&"jackal", &"graft_runner",
]

var city: CitySlice
var runtime: EncounterRuntime


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	runtime = city.encounter_runtime
	runtime.release_all()


func test_catalog_contains_eight_valid_visual_and_gameplay_profiles() -> void:
	assert_eq(EnemyArchetypeCatalog.PROCEDURAL_IDS.size(), 8)
	var signatures: Dictionary[String, bool] = {}
	for archetype_id: StringName in EnemyArchetypeCatalog.PROCEDURAL_IDS:
		assert_true(EnemyArchetypeCatalog.has(archetype_id), archetype_id)
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		assert_not_null(load(String(profile.texture)), archetype_id)
		assert_gt(float(profile.health), 0.0, archetype_id)
		assert_gt(float(profile.speed), 0.0, archetype_id)
		assert_gt(int(profile.xp), 0, archetype_id)
		assert_between(int(profile.threat), 1, 12, archetype_id)
		var signature: String = "%s/%s" % [profile.movement_style, profile.attack_style]
		assert_false(signatures.has(signature), signature)
		signatures[signature] = true
	assert_eq(signatures.size(), 8)


func test_global_enemy_damage_multiplier_reduces_hostile_output_by_quarter() -> void:
	assert_eq(EnemyActor2D.ENEMY_DAMAGE_MULTIPLIER, 0.75)
	var soldier: EnemyActor2D = runtime.acquire(&"soldier", Vector2(920.0, 542.5))
	assert_not_null(soldier)
	assert_almost_eq(soldier._scale_outgoing_damage(40.0), 30.0, 0.001)
	runtime.release(soldier)


func test_catalog_adds_exactly_eight_district_variants_without_replacing_bases() -> void:
	assert_eq(EnemyArchetypeCatalog.PROCEDURAL_IDS.size(), 8)
	assert_eq(EnemyArchetypeCatalog.DISTRICT_VARIANT_IDS.size(), 8)
	assert_eq(EnemyArchetypeCatalog.ALL_SPAWNABLE_IDS.size(), 16)
	assert_eq(EnemyArchetypeCatalog.validation_errors(), PackedStringArray())
	var seen: Dictionary[StringName, bool] = {}
	for archetype_id: StringName in EnemyArchetypeCatalog.ALL_SPAWNABLE_IDS:
		assert_false(seen.has(archetype_id), archetype_id)
		seen[archetype_id] = true
		assert_true(EnemyArchetypeCatalog.has(archetype_id), archetype_id)
		assert_true(EnemyArchetypeCatalog.is_valid_kind(archetype_id), archetype_id)
	assert_eq(seen.size(), 16)
	for district_id: StringName in [
		&"BUSINESS", &"RESIDENTIAL",
	]:
		var variants: Array[StringName] = EnemyArchetypeCatalog.variants_for_district(
			district_id
		)
		assert_eq(variants.size(), 4, district_id)
		for archetype_id: StringName in variants:
			assert_eq(EnemyArchetypeCatalog.district_for_variant(archetype_id), district_id)


func test_district_variant_profiles_flatten_valid_base_contracts_and_compact_art() -> void:
	for archetype_id: StringName in EnemyArchetypeCatalog.DISTRICT_VARIANT_IDS:
		var canonical_id: StringName = EnemyArchetypeCatalog.canonical_id(archetype_id)
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var canonical_profile: Dictionary = EnemyArchetypeCatalog.profile(canonical_id)
		assert_true(EnemyArchetypeCatalog.PROCEDURAL_IDS.has(canonical_id), archetype_id)
		assert_eq(StringName(profile.base_archetype_id), canonical_id, archetype_id)
		assert_eq(StringName(profile.concrete_archetype_id), archetype_id, archetype_id)
		assert_eq(StringName(profile.family), StringName(canonical_profile.family), archetype_id)
		assert_eq(
			EnemyArchetypeCatalog.reservation_key(archetype_id),
			EnemyArchetypeCatalog.reservation_key(canonical_id),
			archetype_id
		)
		assert_eq(
			EnemyArchetypeCatalog.spawn_multiplier(archetype_id),
			EnemyArchetypeCatalog.spawn_multiplier(canonical_id),
			archetype_id
		)
		assert_eq(
			EnemyArchetypeCatalog.is_ground_vehicle(archetype_id),
			EnemyArchetypeCatalog.is_ground_vehicle(canonical_id),
			archetype_id
		)
		assert_eq(
			EnemyArchetypeCatalog.vehicle_weight_class(archetype_id),
			EnemyArchetypeCatalog.vehicle_weight_class(canonical_id),
			archetype_id
		)
		assert_eq(
			EnemyArchetypeCatalog.is_airborne(archetype_id),
			EnemyArchetypeCatalog.is_airborne(canonical_id),
			archetype_id
		)
		assert_gt(float(profile.health), 0.0, archetype_id)
		assert_between(int(profile.threat), 1, 5, archetype_id)
		assert_gt(int(profile.district_weight), 0, archetype_id)
		var texture: Texture2D = load(String(profile.texture)) as Texture2D
		assert_not_null(texture, archetype_id)
		assert_lte(texture.get_width(), 448, archetype_id)
		assert_lte(texture.get_height(), 448, archetype_id)


func test_all_ground_vehicles_render_and_collide_at_exactly_double_size() -> void:
	assert_true(EnemyArchetypeCatalog.is_ground_vehicle(&"tank"))
	assert_false(EnemyArchetypeCatalog.is_ground_vehicle(&"soldier"))
	assert_false(EnemyArchetypeCatalog.is_ground_vehicle(&"helicopter"))
	var tank: TankEnemy = runtime.acquire(&"tank", Vector2(1080.0, 542.5)) as TankEnemy
	assert_not_null(tank)
	assert_eq(tank.max_health, 340.0)
	runtime.release(tank)
	for spawnable_id: StringName in EnemyArchetypeCatalog.ALL_SPAWNABLE_IDS:
		var expected_health_multiplier: float = (
			EnemyArchetypeCatalog.GROUND_VEHICLE_HEALTH_MULTIPLIER
			if EnemyArchetypeCatalog.is_ground_vehicle(spawnable_id)
			else 1.0
		)
		assert_eq(
			EnemyArchetypeCatalog.health_multiplier(spawnable_id),
			expected_health_multiplier,
			spawnable_id
		)
	for archetype_id: StringName in EnemyArchetypeCatalog.PROCEDURAL_IDS:
		var is_ground_vehicle: bool = archetype_id in GROUND_VEHICLE_IDS
		assert_eq(
			EnemyArchetypeCatalog.is_ground_vehicle(archetype_id),
			is_ground_vehicle,
			archetype_id
		)
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var expected_weight: StringName = EnemyArchetypeCatalog.VEHICLE_WEIGHT_NONE
		if is_ground_vehicle:
			expected_weight = (
				EnemyArchetypeCatalog.VEHICLE_WEIGHT_LIGHT
				if StringName(profile.family) == &"light"
				else EnemyArchetypeCatalog.VEHICLE_WEIGHT_HEAVY
			)
		assert_eq(
			EnemyArchetypeCatalog.vehicle_weight_class(archetype_id),
			expected_weight,
			archetype_id
		)
		var actor: ProceduralEnemy = runtime.acquire(
			archetype_id,
			Vector2(1080.0, float(profile.spawn_y))
		) as ProceduralEnemy
		assert_not_null(actor, archetype_id)
		var expected_scale: float = (
			EnemyArchetypeCatalog.GROUND_VEHICLE_SCALE if is_ground_vehicle else 1.0
		)
		assert_almost_eq(
			actor.max_health,
			float(profile.health) * EnemyArchetypeCatalog.health_multiplier(archetype_id),
			0.01,
			archetype_id
		)
		var rendered_size: Vector2 = actor.visual.texture.get_size() * actor.visual.scale.abs()
		var display_bounds: Vector2 = profile.display as Vector2
		if EnemyArchetypeCatalog.is_human_enemy(archetype_id):
			display_bounds = Vector2(
				actor.visual.texture.get_size().x
				* EnemyArchetypeCatalog.HUMAN_RENDER_HEIGHT_PIXELS
				/ actor.visual.texture.get_size().y,
				EnemyArchetypeCatalog.HUMAN_RENDER_HEIGHT_PIXELS
			)
		display_bounds *= expected_scale
		var texture_size: Vector2 = actor.visual.texture.get_size()
		var expected_fit: float = minf(
			display_bounds.x / texture_size.x,
			display_bounds.y / texture_size.y
		)
		var expected_rendered_size: Vector2 = texture_size * expected_fit
		assert_almost_eq(rendered_size.x, expected_rendered_size.x, 0.01, archetype_id)
		assert_almost_eq(rendered_size.y, expected_rendered_size.y, 0.01, archetype_id)
		var body: RectangleShape2D = (
			actor.get_node(^"CollisionShape2D").shape as RectangleShape2D
		)
		assert_eq(body.size, (profile.collision as Vector2) * expected_scale, archetype_id)
		if is_ground_vehicle:
			var wreck: EnemyWreck2D = city.enemy_remains_factory.spawn_wreck(
				actor,
				DamageEvent.new(71_000, city.robot, 10.0)
			)
			assert_eq(wreck.display_size, display_bounds, archetype_id)
			assert_eq(wreck.collision_size, (profile.collision as Vector2) * expected_scale)
			city.enemy_remains_factory.release_wreck(wreck)
		runtime.release(actor)


func test_every_land_enemy_uses_one_road_center_lane_in_every_district() -> void:
	assert_eq(
		EncounterRuntime.LAND_ENEMY_VISUAL_BASELINE_Y,
		CityStreetChunk.ROAD_DIVIDER_Y - 10.0
	)
	var kinds: Array[StringName] = [&"soldier", &"tank", &"helicopter"]
	kinds.append_array(EnemyArchetypeCatalog.ALL_SPAWNABLE_IDS)
	var land_count: int = 0
	var air_count: int = 0
	for kind: StringName in kinds:
		var requested_position: Vector2 = Vector2(1080.0, 120.0)
		var actor: EnemyActor2D = runtime.acquire(kind, requested_position)
		assert_not_null(actor, kind)
		if EnemyArchetypeCatalog.is_airborne(kind):
			assert_eq(actor.global_position.y, requested_position.y, kind)
			air_count += 1
		else:
			var body: RectangleShape2D = (
				actor.get_node(^"CollisionShape2D").shape as RectangleShape2D
			)
			var expected_origin_y: float = (
				CityStreetChunk.ROAD_COLLISION_SURFACE_Y - body.size.y * 0.5
			)
			assert_almost_eq(actor.global_position.y, expected_origin_y, 0.01, kind)
			var content_rect: Rect2 = actor.visual.get_meta(
				EnemyActor2D.VISUAL_CONTENT_RECT_META
			)
			var visible_bottom_y: float = actor.visual.to_global(
				Vector2(content_rect.get_center().x, content_rect.end.y)
			).y
			assert_almost_eq(
				visible_bottom_y,
				EncounterRuntime.LAND_ENEMY_VISUAL_BASELINE_Y,
				0.01,
				kind
			)
			await get_tree().physics_frame
			assert_almost_eq(
				actor.global_position.y,
				expected_origin_y,
				0.5,
				"%s remains grounded" % kind
			)
			land_count += 1
		runtime.release(actor)
	assert_gt(land_count, 0)
	assert_gt(air_count, 0)


func test_defeated_vehicle_remains_ground_matches_road_center_lane() -> void:
	var chunk := CityStreetChunk.new()
	add_child_autofree(chunk)
	await get_tree().process_frame
	var collision: CollisionShape2D = chunk.remains_ground.get_child(0) as CollisionShape2D
	var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
	var remains_surface_y: float = (
		chunk.remains_ground.position.y - rectangle.size.y * 0.5
	)
	assert_almost_eq(
		remains_surface_y,
		EncounterRuntime.LAND_ENEMY_VISUAL_BASELINE_Y,
		0.01
	)
	assert_almost_eq(
		remains_surface_y,
		CityStreetChunk.ROAD_DIVIDER_Y - 10.0,
		0.01
	)


func test_every_machine_wreck_inherits_opaque_bounds_and_grounded_road_baseline() -> void:
	var machine_kinds: Array[StringName] = [&"tank", &"helicopter"]
	for archetype_id: StringName in EnemyArchetypeCatalog.ALL_SPAWNABLE_IDS:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		if StringName(profile.get("remains", &"")) != &"infantry":
			machine_kinds.append(archetype_id)
	assert_gt(machine_kinds.size(), 2)
	for index: int in range(machine_kinds.size()):
		var kind: StringName = machine_kinds[index]
		var actor: EnemyActor2D = runtime.acquire(
			kind,
			Vector2(980.0 + float(index) * 24.0, 120.0)
		)
		assert_not_null(actor, kind)
		var expected_content_rect: Rect2 = actor.visual.get_meta(
			EnemyActor2D.VISUAL_CONTENT_RECT_META
		)
		var wreck: EnemyWreck2D = city.enemy_remains_factory.spawn_wreck(
			actor,
			DamageEvent.new(
				81_000 + index,
				city.robot,
				actor.current_health,
				&"impact",
				actor.global_position,
				Vector2.RIGHT,
				180.0
			)
		)
		assert_not_null(wreck, kind)
		assert_eq(wreck.visual_content_rect, expected_content_rect, kind)
		assert_true(wreck.is_settling_to_road(), kind)
		if not EnemyArchetypeCatalog.is_airborne(kind):
			assert_almost_eq(
				wreck.visible_bottom_y(),
				CityStreetChunk.LAND_ENEMY_VISUAL_BASELINE_Y,
				0.01,
				kind
			)
		wreck._physics_process(EnemyWreck2D.ROAD_SETTLE_TIMEOUT_SECONDS + 0.01)
		assert_false(wreck.is_settling_to_road(), kind)
		assert_almost_eq(wreck.rotation, 0.0, 0.001, kind)
		assert_almost_eq(
			wreck.visible_bottom_y(),
			CityStreetChunk.LAND_ENEMY_VISUAL_BASELINE_Y,
			EnemyWreck2D.ROAD_SETTLE_TOLERANCE,
			kind
		)
		city.enemy_remains_factory.release_wreck(wreck)
		runtime.release(actor)


func test_all_machine_wrecks_overlapping_player_eject_up_and_out() -> void:
	city.robot.set_physics_process(false)
	city.robot.global_position = Vector2(1280.0, 520.0)
	var machine_kinds: Array[StringName] = [&"tank", &"helicopter"]
	for archetype_id: StringName in EnemyArchetypeCatalog.ALL_SPAWNABLE_IDS:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		if StringName(profile.get("remains", &"")) != &"infantry":
			machine_kinds.append(archetype_id)
	assert_gt(machine_kinds.size(), 2)
	for index: int in range(machine_kinds.size()):
		var kind: StringName = machine_kinds[index]
		var actor: EnemyActor2D = runtime.acquire(kind, city.robot.global_position)
		assert_not_null(actor, kind)
		var expected_direction: float = -1.0 if index % 2 == 0 else 1.0
		var event: DamageEvent = DamageEvent.new(
			82_000 + index,
			city.robot,
			actor.current_health,
			&"impact",
			actor.global_position,
			Vector2(expected_direction, -0.1),
			240.0
		)
		var wreck: EnemyWreck2D = city.enemy_remains_factory.spawn_wreck(actor, event)
		assert_not_null(wreck, kind)
		assert_eq(wreck.player_overlap_ejection_count, 1, kind)
		assert_true(wreck.is_player_overlap_ejecting(), kind)
		assert_lte(
			wreck.linear_velocity.y,
			-EnemyWreck2D.PLAYER_OVERLAP_EJECTION_UPWARD_SPEED,
			kind
		)
		assert_gte(
			absf(wreck.linear_velocity.x),
			EnemyWreck2D.PLAYER_OVERLAP_EJECTION_OUTWARD_SPEED,
			kind
		)
		assert_eq(signf(wreck.linear_velocity.x), expected_direction, kind)
		assert_gte(
			absf(wreck.angular_velocity),
			EnemyWreck2D.PLAYER_OVERLAP_EJECTION_ANGULAR_SPEED,
			kind
		)
		assert_eq(wreck.collision_mask & EnemyWreck2D.ROBOT_LAYER, 0, kind)
		city.enemy_remains_factory.release_wreck(wreck)
		runtime.release(actor)
	var safe_actor: EnemyActor2D = runtime.acquire(
		&"tank",
		city.robot.global_position + Vector2(900.0, 0.0)
	)
	var safe_event: DamageEvent = DamageEvent.new(
		82_100,
		city.robot,
		safe_actor.current_health,
		&"impact",
		safe_actor.global_position,
		Vector2.RIGHT,
		240.0
	)
	var safe_wreck: EnemyWreck2D = city.enemy_remains_factory.spawn_wreck(
		safe_actor,
		safe_event
	)
	assert_not_null(safe_wreck)
	assert_eq(safe_wreck.player_overlap_ejection_count, 0)
	assert_false(safe_wreck.is_player_overlap_ejecting())
	assert_ne(safe_wreck.collision_mask & EnemyWreck2D.ROBOT_LAYER, 0)
	city.enemy_remains_factory.release_wreck(safe_wreck)
	runtime.release(safe_actor)


func test_overlap_ejected_vehicle_clears_player_then_lands_elsewhere() -> void:
	city.urban_siege.stop_run()
	runtime.release_all()
	city.robot.set_physics_process(false)
	city.robot.global_position = Vector2(1280.0, 520.0)
	var actor: EnemyActor2D = runtime.acquire(&"tank", city.robot.global_position)
	var event: DamageEvent = DamageEvent.new(
		82_200,
		city.robot,
		actor.current_health,
		&"impact",
		actor.global_position,
		Vector2.RIGHT,
		240.0
	)
	var wreck: EnemyWreck2D = city.enemy_remains_factory.spawn_wreck(actor, event)
	assert_not_null(wreck)
	assert_true(wreck.is_player_overlap_ejecting())
	for frame: int in range(180):
		await get_tree().physics_frame
		if not wreck.is_settling_to_road():
			break
	assert_false(wreck.is_player_overlap_ejecting())
	assert_ne(wreck.collision_mask & EnemyWreck2D.ROBOT_LAYER, 0)
	assert_false(wreck.is_settling_to_road())
	assert_gt(
		absf(wreck.global_position.x - city.robot.global_position.x),
		wreck.collision_size.x * 0.5 + 46.0
	)
	assert_almost_eq(
		wreck.visible_bottom_y(),
		CityStreetChunk.LAND_ENEMY_VISUAL_BASELINE_Y,
		EnemyWreck2D.ROAD_SETTLE_TOLERANCE
	)


func test_crucible_capture_preserves_pending_ejection_collision_restore() -> void:
	city.robot.set_physics_process(false)
	city.robot.global_position = Vector2(1280.0, 520.0)
	var actor: EnemyActor2D = runtime.acquire(&"tank", city.robot.global_position)
	var event: DamageEvent = DamageEvent.new(
		82_300,
		city.robot,
		actor.current_health,
		&"impact",
		actor.global_position,
		Vector2.RIGHT,
		240.0
	)
	var wreck: EnemyWreck2D = city.enemy_remains_factory.spawn_wreck(actor, event)
	assert_true(wreck.is_player_overlap_ejecting())
	assert_true(wreck.begin_crucible_capture())
	wreck.update_crucible_capture(city.robot.global_position + Vector2(900.0, -200.0), 0.0)
	wreck._physics_process(0.0)
	assert_false(wreck.is_player_overlap_ejecting())
	wreck.cancel_crucible_capture()
	assert_ne(wreck.collision_mask & EnemyWreck2D.ROBOT_LAYER, 0)


func test_vehicle_weight_tiers_resist_live_hits_but_wrecks_launch() -> void:
	var heavy_vehicle: EnemyActor2D = runtime.acquire(&"tank", Vector2(1080.0, 542.5))
	var light_vehicle: EnemyActor2D = runtime.acquire(&"jackal", Vector2(1240.0, 554.0))
	var soldier: EnemyActor2D = runtime.acquire(&"soldier", Vector2(920.0, 542.5))
	assert_not_null(heavy_vehicle)
	assert_not_null(light_vehicle)
	assert_not_null(soldier)
	heavy_vehicle.set_physics_process(false)
	light_vehicle.set_physics_process(false)
	soldier.set_physics_process(false)
	var impulse_per_mass: float = 100.0
	assert_true(heavy_vehicle.receive_damage(DamageEvent.new(
		73_001, city.robot, 1.0, &"jab_cross", heavy_vehicle.global_position,
		Vector2.RIGHT, impulse_per_mass
	)))
	assert_true(light_vehicle.receive_damage(DamageEvent.new(
		73_002, city.robot, 1.0, &"jab_cross", light_vehicle.global_position,
		Vector2.RIGHT, impulse_per_mass
	)))
	assert_true(soldier.receive_damage(DamageEvent.new(
		73_003, city.robot, 1.0, &"jab_cross", soldier.global_position,
		Vector2.RIGHT, impulse_per_mass
	)))
	assert_almost_eq(heavy_vehicle.velocity.x, 16.8, 0.01)
	assert_almost_eq(light_vehicle.velocity.x, 63.0, 0.01)
	assert_almost_eq(soldier.velocity.x, 140.0, 0.01)
	assert_almost_eq(
		light_vehicle.velocity.x / soldier.velocity.x,
		EnemyActor2D.SURVIVING_PLAYER_LIGHT_VEHICLE_KNOCKBACK_MULTIPLIER,
		0.001
	)
	assert_almost_eq(
		heavy_vehicle.velocity.x / soldier.velocity.x,
		EnemyActor2D.SURVIVING_PLAYER_HEAVY_VEHICLE_KNOCKBACK_MULTIPLIER,
		0.001
	)
	var light_live_melee_velocity: float = light_vehicle.velocity.x
	var heavy_live_melee_velocity: float = heavy_vehicle.velocity.x
	heavy_vehicle.velocity = Vector2.ZERO
	light_vehicle.velocity = Vector2.ZERO
	soldier.velocity = Vector2.ZERO
	assert_true(heavy_vehicle.receive_damage(DamageEvent.new(
		73_004, city.robot, 1.0, &"missile", heavy_vehicle.global_position,
		Vector2.RIGHT, impulse_per_mass
	)))
	assert_true(light_vehicle.receive_damage(DamageEvent.new(
		73_005, city.robot, 1.0, &"missile", light_vehicle.global_position,
		Vector2.RIGHT, impulse_per_mass
	)))
	assert_true(soldier.receive_damage(DamageEvent.new(
		73_006, city.robot, 1.0, &"missile", soldier.global_position,
		Vector2.RIGHT, impulse_per_mass
	)))
	assert_almost_eq(heavy_vehicle.velocity.x, 2.16, 0.01)
	assert_almost_eq(light_vehicle.velocity.x, 8.1, 0.01)
	assert_almost_eq(soldier.velocity.x, 18.0, 0.01)
	heavy_vehicle.velocity = Vector2.ZERO
	assert_true(heavy_vehicle.receive_damage(DamageEvent.new(
		73_007, soldier, 1.0, &"impact", heavy_vehicle.global_position,
		Vector2.RIGHT, impulse_per_mass
	)))
	assert_almost_eq(heavy_vehicle.velocity.x, 18.0, 0.01)
	var lethal_event: DamageEvent = DamageEvent.new(
		73_008, city.robot, heavy_vehicle.current_health, &"jab_cross",
		heavy_vehicle.global_position, Vector2.RIGHT, impulse_per_mass
	)
	assert_true(heavy_vehicle.receive_damage(lethal_event))
	assert_true(heavy_vehicle.dead)
	assert_eq(heavy_vehicle.velocity, Vector2.ZERO)
	assert_eq(heavy_vehicle.last_player_knockback_attack_id, lethal_event.attack_id)
	await get_tree().process_frame
	var wreck: EnemyWreck2D = city.tank_wreck
	assert_not_null(wreck)
	await get_tree().physics_frame
	wreck.linear_velocity = Vector2.ZERO
	wreck.angular_velocity = 0.0
	wreck.sleeping = false
	assert_true(wreck.receive_damage(DamageEvent.new(
		73_009, city.robot, 1.0, &"missile", wreck.global_position,
		Vector2.RIGHT, impulse_per_mass
	)))
	await get_tree().physics_frame
	assert_between(wreck.linear_velocity.x, 100.0, 110.0)
	assert_gt(wreck.linear_velocity.x, light_live_melee_velocity)
	assert_gt(wreck.linear_velocity.x, heavy_live_melee_velocity * 6.0)
	wreck.linear_velocity = Vector2.ZERO
	wreck.angular_velocity = 0.0
	assert_true(wreck.receive_damage(DamageEvent.new(
		73_010, soldier, 1.0, &"impact", wreck.global_position,
		Vector2.RIGHT, impulse_per_mass
	)))
	await get_tree().physics_frame
	assert_between(wreck.linear_velocity.x, 28.0, 32.0)


func test_project_choir_hybrids_reuse_existing_families_and_production_art() -> void:
	var expected_families: Dictionary[StringName, StringName] = {
		&"reclaimed_breacher": &"infantry",
		&"graft_runner": &"light",
	}
	for archetype_id: StringName in expected_families:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		assert_eq(StringName(profile.family), expected_families[archetype_id])
		var texture: Texture2D = load(String(profile.texture)) as Texture2D
		assert_not_null(texture, archetype_id)
		assert_lte(texture.get_width(), 768, archetype_id)
		assert_lte(texture.get_height(), 768, archetype_id)


func test_every_archetype_acquires_animates_telegraphs_and_releases_cleanly() -> void:
	for archetype_id: StringName in EnemyArchetypeCatalog.PROCEDURAL_IDS:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var actor: ProceduralEnemy = runtime.acquire(
			archetype_id,
			Vector2(1080.0, float(profile.spawn_y))
		) as ProceduralEnemy
		assert_not_null(actor, archetype_id)
		actor.set_physics_process(false)
		assert_eq(actor.archetype_id, archetype_id)
		assert_eq(actor.family, EnemyArchetypeCatalog.family_for(archetype_id))
		assert_almost_eq(
			actor.max_health,
			float(profile.health) * EnemyArchetypeCatalog.health_multiplier(archetype_id),
			0.01
		)
		assert_not_null(actor.visual.texture)
		var rest_position: Vector2 = actor.visual.position
		var rest_rotation: float = actor.visual.rotation
		var rest_scale: Vector2 = actor.visual.scale
		actor.velocity = Vector2(actor.move_speed, 0.0)
		actor._begin_attack()
		assert_true(actor.is_telegraphing(), archetype_id)
		actor._animate_visual(0.17)
		var changed: bool = (
			actor.visual.position != rest_position
			or not is_equal_approx(actor.visual.rotation, rest_rotation)
			or actor.visual.scale != rest_scale
		)
		assert_true(changed, "%s procedural motion" % archetype_id)
		actor.cancel_telegraph()
		assert_eq(city.projectile_root.reservation_count(), 0)
		runtime.release(actor)
		assert_false(actor.active)


func test_specialist_humans_match_108_pixel_height_through_attack_animation() -> void:
	for archetype_id: StringName in [&"bulwark", &"lobber", &"sapper"]:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var actor: ProceduralEnemy = runtime.acquire(
			archetype_id,
			Vector2(1100.0, float(profile.spawn_y))
		) as ProceduralEnemy
		assert_not_null(actor)
		actor.set_physics_process(false)
		actor._attack_kick = 1.0
		actor._animate_visual(0.12)
		var rendered_height: float = (
			actor.visual.texture.get_size().y * absf(actor.visual.scale.y)
		)
		assert_almost_eq(
			rendered_height,
			EnemyArchetypeCatalog.HUMAN_RENDER_HEIGHT_PIXELS,
			0.01,
			archetype_id
		)
		runtime.release(actor)


func test_shielded_bulwark_faces_player_from_both_sides() -> void:
	city.robot.global_position.x = 1300.0
	var bulwark: ProceduralEnemy = runtime.acquire(
		&"bulwark",
		Vector2(1000.0, 540.0),
		&"",
		SHIELDED.trait_id
	) as ProceduralEnemy
	assert_not_null(bulwark)
	assert_true(bulwark.visual_faces_right_by_default)
	assert_eq(bulwark.facing, 1)
	assert_false(bulwark.visual.flip_h)
	city.robot.global_position.x = 700.0
	bulwark._update_facing()
	assert_eq(bulwark.facing, -1)
	assert_true(bulwark.visual.flip_h)


func test_every_procedural_sprite_faces_player_from_both_sides() -> void:
	for archetype_id: StringName in EnemyArchetypeCatalog.PROCEDURAL_IDS:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var authored_right: bool = EXPECTED_FACES_RIGHT[archetype_id]
		city.robot.global_position.x = 1300.0
		var actor: ProceduralEnemy = runtime.acquire(
			archetype_id,
			Vector2(1000.0, float(profile.spawn_y))
		) as ProceduralEnemy
		assert_not_null(actor, archetype_id)
		actor.set_physics_process(false)
		assert_eq(
			actor.visual_faces_right_by_default,
			authored_right,
			"%s authored direction" % archetype_id
		)
		assert_eq(actor.facing, 1, "%s target east" % archetype_id)
		assert_eq(
			actor.visual.flip_h,
			not authored_right,
			"%s visual east" % archetype_id
		)
		city.robot.global_position.x = 700.0
		actor._update_facing()
		assert_eq(actor.facing, -1, "%s target west" % archetype_id)
		assert_eq(
			actor.visual.flip_h,
			authored_right,
			"%s visual west" % archetype_id
		)
		runtime.release(actor)


func test_base_enemy_sprites_face_player_from_both_sides() -> void:
	for kind: StringName in EnemyArchetypeCatalog.BASE_KINDS:
		city.robot.global_position.x = 1300.0
		var actor: EnemyActor2D = runtime.acquire(kind, Vector2(1000.0, 542.5))
		assert_not_null(actor, kind)
		actor.set_physics_process(false)
		assert_false(actor.visual_faces_right_by_default, "%s authored west" % kind)
		assert_eq(actor.facing, 1, "%s target east" % kind)
		assert_true(actor.visual.flip_h, "%s visual east" % kind)
		city.robot.global_position.x = 700.0
		actor._update_facing()
		assert_eq(actor.facing, -1, "%s target west" % kind)
		assert_false(actor.visual.flip_h, "%s visual west" % kind)
		runtime.release(actor)


func test_random_affix_spawns_play_bounded_colored_impact_effects() -> void:
	var effects: EliteSpawnEffectPool = runtime.elite_spawn_effect_pool
	assert_eq(effects.slot_count(), RuntimeBudget.ELITE_SPAWN_EFFECT_SLOTS)
	for trait_id: StringName in EnemyArchetypeCatalog.RANDOM_AFFIXES:
		var actor: ProceduralEnemy = runtime.acquire(
			&"hound",
			Vector2(980.0 + float(effects.play_count) * 80.0, 230.0),
			&"",
			trait_id
		) as ProceduralEnemy
		assert_not_null(actor)
	assert_eq(effects.play_count, 3)
	assert_eq(effects.active_count(), 3)
	assert_eq(effects.last_trait_id, &"PHASED")
	var latest: Node2D = effects.get_child(2) as Node2D
	assert_true((latest.get_node(^"Particles") as CPUParticles2D).emitting)
	assert_eq(latest.get_meta(&"trait_id"), &"PHASED")
	await get_tree().create_timer(0.75).timeout
	assert_eq(effects.active_count(), 0)


func test_baseline_melee_ttk_matches_rebalanced_vehicle_health() -> void:
	var resolver: AttackResolver = AttackResolver.new()
	add_child_autofree(resolver)
	var punch_damage: float = resolver.jab_cross_actor_damage
	for archetype_id: StringName in EnemyArchetypeCatalog.PROCEDURAL_IDS:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var actor: ProceduralEnemy = runtime.acquire(
			archetype_id,
			Vector2(1080.0, float(profile.spawn_y))
		) as ProceduralEnemy
		assert_not_null(actor, archetype_id)
		actor.facing = -1
		var expected_hits: int = EXPECTED_BASELINE_PUNCHES[archetype_id]
		for hit_index: int in range(expected_hits):
			var accepted: bool = actor.receive_damage(DamageEvent.new(
				20_000 + hit_index,
				city.robot,
				punch_damage,
				&"jab_cross",
				actor.global_position,
				Vector2.RIGHT,
				0.0
			))
			assert_true(accepted, "%s hit %d" % [archetype_id, hit_index + 1])
			assert_eq(actor.dead, hit_index == expected_hits - 1, archetype_id)
		runtime.release(actor)


func test_retained_acts_use_monotonic_threat_peaks_within_caps() -> void:
	var previous_peak: int = 0
	for act_index: int in range(DISTRICT.acts.size()):
		var act: DistrictAct = DISTRICT.acts[act_index]
		var peak_threat: int = 0
		for beat: DistrictBeat in act.beats:
			var beat_threat: int = 0
			for entry: EnemySpawnEntry in beat.spawns:
				var kind: StringName = StringName(entry.kind)
				beat_threat += (
					EnemyArchetypeCatalog.threat_cost(kind)
					* EnemyArchetypeCatalog.spawn_multiplier(kind)
				)
			peak_threat = maxi(peak_threat, beat_threat)
			assert_lte(beat_threat, beat.maximum_threat, beat.beat_id)
		if act_index > 0:
			assert_gte(peak_threat, previous_peak, act.act_id)
		previous_peak = peak_threat


func test_retained_six_archetypes_enter_in_monotonic_act_order_within_caps() -> void:
	var first_act: Dictionary[StringName, int] = {}
	for act_index: int in range(DISTRICT.acts.size()):
		for beat: DistrictBeat in DISTRICT.acts[act_index].beats:
			var threat: int = 0
			for entry: EnemySpawnEntry in beat.spawns:
				var kind: StringName = StringName(entry.kind)
				threat += (
					EnemyArchetypeCatalog.threat_cost(kind)
					* EnemyArchetypeCatalog.spawn_multiplier(kind)
				)
				if EnemyArchetypeCatalog.has(kind) and not first_act.has(kind):
					first_act[kind] = act_index
			assert_lte(threat, beat.maximum_threat, beat.beat_id)
	assert_eq(first_act.size(), 6)
	for archetype_id: StringName in EXPECTED_FIRST_ACT:
		assert_eq(first_act.get(archetype_id, -1), EXPECTED_FIRST_ACT[archetype_id])
	assert_eq(DistrictRecipeValidator.validate(DISTRICT), PackedStringArray())
