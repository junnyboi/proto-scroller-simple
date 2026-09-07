extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_fast_unarmed_debris_damages_ground_enemy_once_via_physics() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	var target: EnemyActor2D = city.encounter_runtime.acquire(
		&"soldier",
		Vector2(900.0, 605.0)
	)
	assert_not_null(target)
	target.set_physics_process(false)
	target.velocity = Vector2.ZERO
	var health_before: float = target.current_health
	var debris: DebrisBody2D = city.debris_pool.acquire(
		Transform2D(0.0, target.global_position + Vector2(-230.0, 0.0)),
		Vector2(4200.0, 0.0),
		0.0,
		4.0,
		Vector2(34.0, 24.0),
		&"concrete"
	)
	debris.gravity_scale = 0.0
	var hit_registered: bool = false
	for physics_tick: int in range(60):
		await get_tree().physics_frame
		if target.current_health < health_before:
			hit_registered = true
			break
	assert_true(hit_registered)
	var damage_dealt: float = health_before - target.current_health
	assert_between(damage_dealt, 5.0, DebrisBody2D.MAX_GROUND_IMPACT_DAMAGE)
	assert_eq(debris.ground_hit_count, 1)
	assert_eq(city.impact_feedback_pool.debris_audio_play_count, 1)
	assert_eq(city.impact_feedback_pool.debris_spark_play_count, 1)
	assert_almost_eq(city.impact_feedback_pool.last_debris_mass, 4.0, 0.001)
	assert_between(city.impact_feedback_pool.last_debris_pitch, 0.90, 1.10)
	var health_after_first_hit: float = target.current_health
	debris.linear_velocity = Vector2(900.0, 0.0)
	debris._on_body_entered(target)
	assert_eq(target.current_health, health_after_first_hit)
	assert_eq(debris.ground_hit_count, 1)
	assert_eq(city.impact_feedback_pool.debris_audio_play_count, 1)
	assert_eq(city.impact_feedback_pool.debris_spark_play_count, 1)


func test_debris_thud_is_24k_qoa_and_scales_with_weight_inside_fixed_pool() -> void:
	var stream: AudioStreamWAV = (
		ImpactFeedbackPool.DEBRIS_ENEMY_THUD_SFX as AudioStreamWAV
	)
	assert_not_null(stream)
	assert_eq(stream.mix_rate, 24000)
	assert_eq(stream.format, AudioStreamWAV.FORMAT_QOA)
	assert_false(stream.stereo)
	assert_between(stream.get_length(), 0.75, 0.90)
	var root: Node2D = Node2D.new()
	add_child_autofree(root)
	var audio_root: Node2D = Node2D.new()
	root.add_child(audio_root)
	var pool: ImpactFeedbackPool = ImpactFeedbackPool.new()
	pool.setup(root, audio_root)
	root.add_child(pool)
	await get_tree().process_frame
	var light: AudioStreamPlayer2D = pool.play_debris_enemy_impact(
		Vector2.ZERO,
		Vector2.RIGHT,
		700.0,
		1.0
	)
	assert_not_null(light)
	var light_pitch: float = light.pitch_scale
	var light_volume_db: float = light.volume_db
	var heavy: AudioStreamPlayer2D = pool.play_debris_enemy_impact(
		Vector2(20.0, 0.0),
		Vector2.RIGHT,
		700.0,
		24.0
	)
	assert_not_null(heavy)
	assert_same(light.stream, stream)
	assert_same(heavy.stream, stream)
	assert_same(heavy, light)
	assert_lt(heavy.pitch_scale, light_pitch)
	assert_gt(heavy.volume_db, light_volume_db)
	assert_null(pool.play_debris_enemy_impact(
		Vector2(40.0, 0.0),
		Vector2.RIGHT,
		700.0,
		1.0
	))
	assert_eq(pool.debris_audio_play_count, 2)
	assert_eq(pool.debris_spark_play_count, 3)
	assert_eq(pool.audio_child_count(), RuntimeBudget.AUDIO_VOICES)
	assert_eq(pool.particle_child_count(), RuntimeBudget.PARTICLE_SLOTS)


func test_slow_debris_and_airborne_enemies_are_excluded() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	var ground_target: EnemyActor2D = city.encounter_runtime.acquire(
		&"soldier",
		Vector2(880.0, 605.0)
	)
	var air_target: EnemyActor2D = city.encounter_runtime.acquire(
		&"helicopter",
		Vector2(880.0, 260.0)
	)
	var procedural_ground: EnemyActor2D = city.encounter_runtime.acquire(
		&"jackal",
		Vector2(1050.0, 605.0)
	)
	assert_ne(ground_target.collision_mask & EncounterRuntime.DEBRIS_LAYER, 0)
	assert_ne(procedural_ground.collision_mask & EncounterRuntime.DEBRIS_LAYER, 0)
	assert_eq(air_target.collision_mask & EncounterRuntime.DEBRIS_LAYER, 0)
	assert_false(procedural_ground.is_in_group(AerialDebrisLauncher.AIRBORNE_GROUP))
	var debris: DebrisBody2D = city.debris_pool.acquire(
		Transform2D(0.0, Vector2(780.0, 500.0)),
		Vector2.ZERO
	)
	var ground_health: float = ground_target.current_health
	debris.linear_velocity = Vector2(120.0, 0.0)
	debris._on_body_entered(ground_target)
	assert_eq(ground_target.current_health, ground_health)
	var air_health: float = air_target.current_health
	debris.linear_velocity = Vector2(900.0, 0.0)
	debris._on_body_entered(air_target)
	assert_eq(air_target.current_health, air_health)
	assert_eq(debris.ground_hit_count, 0)


func test_damaged_cells_use_seeded_hit_centered_organic_patterns() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var cells: Array[Destructible2D] = [
		city.building.get_cell(0, 0),
		city.building.get_cell(1, 0),
		city.building.get_cell(0, 1),
	]
	var signatures: Dictionary[String, bool] = {}
	for index: int in range(cells.size()):
		var cell: Destructible2D = cells[index]
		var offset: Vector2 = Vector2(26.0 - 12.0 * float(index), -18.0 + 9.0 * float(index))
		var event: DamageEvent = DamageEvent.new(
			9100 + index,
			city.robot,
			cell.max_health * 0.45,
			&"jab_cross",
			cell.global_position + offset,
			Vector2.RIGHT,
			420.0
		)
		assert_true(cell.receive_damage(event))
		var pattern: BuildingDamagePattern2D = cell.get_node(
			^"DamagedVisual"
		) as BuildingDamagePattern2D
		assert_not_null(pattern)
		assert_true(pattern.visible)
		assert_true((cell.get_node(^"IntactVisual") as Sprite2D).visible)
		assert_eq(pattern.contour().size(), BuildingDamagePattern2D.CONTOUR_POINTS)
		assert_gte(pattern.crack_count(), 1)
		assert_lte(pattern.crack_count(), BuildingDamagePattern2D.BASE_CRACK_COUNT + 3)
		var local_hit: Vector2 = pattern.to_local(event.hit_position)
		var contour_center: Vector2 = Vector2.ZERO
		var minimum: Vector2 = Vector2(INF, INF)
		var maximum: Vector2 = Vector2(-INF, -INF)
		for point: Vector2 in pattern.contour():
			contour_center += point
			minimum.x = minf(minimum.x, point.x)
			minimum.y = minf(minimum.y, point.y)
			maximum.x = maxf(maximum.x, point.x)
			maximum.y = maxf(maximum.y, point.y)
		contour_center /= float(pattern.contour().size())
		assert_lt(contour_center.distance_to(local_hit), 24.0)
		assert_gt(maximum.x - minimum.x, 50.0)
		assert_gt(maximum.y - minimum.y, 40.0)
		var signature: String = pattern.pattern_signature()
		assert_false(signatures.has(signature))
		signatures[signature] = true
		pattern.record_damage(event, cell.current_health / cell.max_health)
		assert_eq(pattern.pattern_signature(), signature)
