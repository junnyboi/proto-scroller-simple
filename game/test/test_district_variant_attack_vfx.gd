# gdlint: disable=max-public-methods
extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_catalog_exactly_covers_eight_variants_and_twenty_four_regions() -> void:
	assert_eq(EnemyAttackVfxCatalog.validation_errors(), PackedStringArray())
	assert_eq(EnemyAttackVfxCatalog.SPECS.size(), 8)
	assert_eq(EnemyAttackVfxCatalog.RANGED_IDS.size(), 3)
	var projectile_deliveries: int = 0
	var actor_deliveries: int = 0
	for archetype_id: StringName in EnemyArchetypeCatalog.DISTRICT_VARIANT_IDS:
		assert_true(EnemyAttackVfxCatalog.has(archetype_id), archetype_id)
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		assert_eq(profile.get("attack_vfx_id"), archetype_id, archetype_id)
		for phase: StringName in [&"projectile", &"impact", &"attack"]:
			var phase_spec: Dictionary = EnemyAttackVfxCatalog.phase_spec(
				archetype_id,
				phase
			)
			assert_not_null(phase_spec.get("texture"), "%s %s" % [archetype_id, phase])
			assert_eq(
				Vector2i((phase_spec.texture as Texture2D).get_size()),
				EnemyAttackVfxCatalog.ATLAS_SIZE,
				"%s %s" % [archetype_id, phase]
			)
			assert_eq(
				(phase_spec.region as Rect2i).size,
				EnemyAttackVfxCatalog.CELL_SIZE,
				"%s %s" % [archetype_id, phase]
			)
			assert_gt((phase_spec.display_size as Vector2).x, 0.0, archetype_id)
			assert_eq(
				phase_spec.visible_center_offset,
				_visible_region_center_offset(
					phase_spec.texture as Texture2D,
					phase_spec.region as Rect2i
				),
				"%s %s visible center" % [archetype_id, phase]
			)
		if EnemyAttackVfxCatalog.is_projectile_delivery(archetype_id):
			projectile_deliveries += 1
		else:
			actor_deliveries += 1
	assert_eq(projectile_deliveries, 3)
	assert_eq(actor_deliveries, 5)


func test_ranged_projectile_specs_preserve_kind_radius_and_unique_impacts() -> void:
	assert_true(ProjectileVisualCatalog.debug_validate())
	var projectile_keys: Dictionary[StringName, bool] = {}
	var impact_keys: Dictionary[StringName, bool] = {}
	for archetype_id: StringName in EnemyAttackVfxCatalog.RANGED_IDS:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var projectile_key: StringName = EnemyAttackVfxCatalog.projectile_key(archetype_id)
		var impact_key: StringName = EnemyAttackVfxCatalog.impact_key(archetype_id)
		assert_false(projectile_key.is_empty(), archetype_id)
		assert_false(impact_key.is_empty(), archetype_id)
		assert_false(projectile_keys.has(projectile_key), archetype_id)
		assert_false(impact_keys.has(impact_key), archetype_id)
		projectile_keys[projectile_key] = true
		impact_keys[impact_key] = true
		var projectile_spec: Dictionary = ProjectileVisualCatalog.spec(projectile_key)
		assert_eq(
			projectile_spec.get("damage_kind"),
			profile.get("projectile_kind"),
			archetype_id
		)
		assert_eq(
			float(projectile_spec.get("collision_radius_contract")),
			_expected_radius(StringName(profile.projectile_kind)),
			archetype_id
		)
		assert_eq(projectile_spec.get("impact_key"), impact_key, archetype_id)
		assert_false(
			EnemyAttackVfxCatalog.impact_spec_for_key(impact_key).is_empty(),
			archetype_id
		)


func test_projectile_pool_carries_custom_visual_and_dispatches_bounded_impact() -> void:
	var pool: ProjectilePool = ProjectilePool.new()
	add_child_autofree(pool)
	await get_tree().process_frame
	assert_eq(pool.total_count(), 32)
	assert_eq(pool.hostile_impacts.size(), ProjectilePool.HOSTILE_IMPACT_CAPACITY)
	var child_count: int = pool.get_child_count()
	for archetype_id: StringName in EnemyAttackVfxCatalog.RANGED_IDS:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var projectile_key: StringName = EnemyAttackVfxCatalog.projectile_key(archetype_id)
		var impact_key: StringName = EnemyAttackVfxCatalog.impact_key(archetype_id)
		var projectile: Projectile2D = pool.acquire(
			Vector2(50.0, 60.0),
			Vector2.RIGHT,
			float(profile.projectile_speed),
			float(profile.damage),
			null,
			1,
			StringName(profile.projectile_kind),
			projectile_key
		)
		assert_not_null(projectile, archetype_id)
		assert_eq(projectile.visual_key, projectile_key, archetype_id)
		assert_eq(projectile.impact_key, impact_key, archetype_id)
		assert_almost_eq(
			projectile.velocity.length(),
			float(profile.projectile_speed),
			0.001,
			archetype_id
		)
		assert_eq(projectile.damage, float(profile.damage), archetype_id)
		assert_eq(
			projectile.projectile_radius,
			_expected_radius(StringName(profile.projectile_kind)),
			archetype_id
		)
		pool._on_impact_requested(
			projectile,
			Vector2(400.0, 300.0),
			Vector2.RIGHT,
			StringName(profile.projectile_kind),
			impact_key,
			projectile.damage
		)
		assert_gt(pool.active_hostile_impact_count(), 0, archetype_id)
		assert_almost_eq(pool.last_hostile_impact_scale, 1.0, 0.0001, archetype_id)
		pool.release(projectile)
		assert_eq(projectile.visual_key, &"", archetype_id)
		assert_eq(projectile.impact_key, &"", archetype_id)
		pool.release_all()
		assert_eq(pool.active_hostile_impact_count(), 0, archetype_id)
		assert_eq(pool.get_child_count(), child_count, archetype_id)
	assert_eq(pool.total_count(), 32)


func test_procedural_ranged_variants_fire_their_custom_projectile_keys() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	city.projectile_root.release_all()
	for archetype_id: StringName in EnemyAttackVfxCatalog.RANGED_IDS:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var enemy: ProceduralEnemy = city.encounter_runtime.acquire(
			archetype_id,
			Vector2(1120.0, float(profile.spawn_y))
		) as ProceduralEnemy
		assert_not_null(enemy, archetype_id)
		enemy.set_physics_process(false)
		enemy._begin_attack()
		assert_true(enemy.is_telegraphing(), archetype_id)
		assert_eq(
			city.projectile_root.reservation_count(
				StringName(profile.projectile_kind)
			),
			1,
			archetype_id
		)
		enemy._complete_attack()
		var projectile: Projectile2D = city.projectile_root.last_acquired
		assert_not_null(projectile, archetype_id)
		assert_eq(
			projectile.visual_key,
			EnemyAttackVfxCatalog.projectile_key(archetype_id),
			archetype_id
		)
		assert_eq(projectile.damage_type, profile.projectile_kind, archetype_id)
		assert_eq(projectile.damage, float(profile.damage), archetype_id)
		assert_eq(city.projectile_root.reservation_count(), 0, archetype_id)
		city.projectile_root.release_all()
		city.encounter_runtime.release(enemy)


func test_hostile_impact_cursor_wraps_without_node_growth_or_gameplay_denial() -> void:
	var pool: ProjectilePool = ProjectilePool.new()
	add_child_autofree(pool)
	await get_tree().process_frame
	var child_count: int = pool.get_child_count()
	var impact_key: StringName = EnemyAttackVfxCatalog.impact_key(&"rainvault_pressure_ward")
	for impact_index: int in range(ProjectilePool.HOSTILE_IMPACT_CAPACITY * 3):
		pool._on_impact_requested(
			null,
			Vector2(float(impact_index) * 10.0, 200.0),
			Vector2.RIGHT,
			&"shell",
			impact_key,
			30.0
		)
	assert_eq(pool.active_hostile_impact_count(), ProjectilePool.HOSTILE_IMPACT_CAPACITY)
	assert_eq(pool.get_child_count(), child_count)
	assert_eq(pool.total_count(), 32)
	assert_eq(pool.denial_count, 0)
	pool.release_all()
	assert_eq(pool.active_hostile_impact_count(), 0)
	assert_eq(pool.get_child_count(), child_count)


func test_all_eight_variants_show_unique_fixed_sprite_anticipation() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	for archetype_id: StringName in EnemyArchetypeCatalog.DISTRICT_VARIANT_IDS:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var enemy: ProceduralEnemy = city.encounter_runtime.acquire(
			archetype_id,
			Vector2(1100.0, float(profile.spawn_y))
		) as ProceduralEnemy
		assert_not_null(enemy, archetype_id)
		enemy.set_physics_process(false)
		var child_count: int = enemy.get_child_count()
		enemy._begin_attack()
		assert_true(enemy.is_telegraphing(), archetype_id)
		assert_eq(
			_visible_presentation_count(enemy),
			1 if EnemyAttackVfxCatalog.is_projectile_delivery(archetype_id) else 2,
			archetype_id
		)
		assert_eq(enemy.get_child_count(), child_count, archetype_id)
		var snapshot: Dictionary = city.telegraph_presenter.snapshot(enemy._telegraph_id)
		assert_eq(snapshot.get("visual_key"), archetype_id, archetype_id)
		assert_eq(
			(snapshot.get("style_data", {}) as Dictionary).get("attack_vfx_id"),
			archetype_id,
			archetype_id
		)
		assert_false(
			city.telegraph_presenter.uses_procedural_rendering(enemy._telegraph_id),
			archetype_id
		)
		var attack_phase: Dictionary = EnemyAttackVfxCatalog.phase_spec(
			archetype_id,
			&"attack"
		)
		assert_almost_eq(
			enemy._presentation_visible_center_world(
				enemy._presentation_sprites[0],
				attack_phase
			).distance_to(enemy.telegraph_origin()),
			0.0,
			0.01,
			archetype_id
		)
		if not EnemyAttackVfxCatalog.is_projectile_delivery(archetype_id):
			var payload_phase: Dictionary = EnemyAttackVfxCatalog.phase_spec(
				archetype_id,
				&"projectile"
			)
			var payload_anchor: Vector2 = enemy.telegraph_origin() + Vector2(
				float(enemy.facing) * 36.0,
				0.0
			)
			assert_almost_eq(
				enemy._presentation_visible_center_world(
					enemy._presentation_sprites[1],
					payload_phase
				).distance_to(payload_anchor),
				0.0,
				0.01,
				"%s payload" % archetype_id
			)
		enemy.cancel_telegraph()
		assert_eq(_visible_presentation_count(enemy), 0, archetype_id)
		assert_eq(city.projectile_root.reservation_count(), 0, archetype_id)
		city.encounter_runtime.release(enemy)


func test_missing_authored_attack_sprite_keeps_procedural_fallback() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	var lobber: ProceduralEnemy = city.encounter_runtime.acquire(
		&"lobber",
		Vector2(1100.0, 542.0)
	) as ProceduralEnemy
	assert_not_null(lobber)
	lobber.set_physics_process(false)
	lobber._attack_vfx_id = &"missing_attack_sprite"
	lobber._begin_attack()
	assert_true(lobber.is_telegraphing())
	assert_eq(_visible_presentation_count(lobber), 0)
	assert_true(city.telegraph_presenter.uses_procedural_rendering(lobber._telegraph_id))
	var snapshot: Dictionary = city.telegraph_presenter.snapshot(lobber._telegraph_id)
	assert_false(
		bool((snapshot.get("style_data", {}) as Dictionary).get(
			TelegraphPresenter2D.AUTHORED_TELEGRAPH_STYLE_KEY,
			false
		))
	)
	lobber.cancel_telegraph()


func test_actor_only_variants_complete_without_projectiles_or_mechanical_drift() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.robot.global_position = Vector2(760.0, 542.0)
	var actor_ids: Array[StringName] = []
	for archetype_id: StringName in EnemyArchetypeCatalog.DISTRICT_VARIANT_IDS:
		if not EnemyAttackVfxCatalog.is_projectile_delivery(archetype_id):
			actor_ids.append(archetype_id)
	assert_eq(actor_ids.size(), 5)
	for archetype_id: StringName in actor_ids:
		city.encounter_runtime.release_all()
		city.projectile_root.release_all()
		city.encounter_runtime.target_mark_remaining = 0.0
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var enemy: ProceduralEnemy = city.encounter_runtime.acquire(
			archetype_id,
			Vector2(910.0, float(profile.spawn_y))
		) as ProceduralEnemy
		assert_not_null(enemy, archetype_id)
		enemy.set_physics_process(false)
		var ally: ProceduralEnemy
		if StringName(profile.attack_style) == &"repair":
			ally = city.encounter_runtime.acquire(
				&"bulwark",
				Vector2(850.0, 540.0)
			) as ProceduralEnemy
			assert_not_null(ally, archetype_id)
			ally.current_health = ally.max_health - 40.0
		enemy._begin_attack()
		assert_eq(city.projectile_root.reservation_count(), 0, archetype_id)
		enemy._complete_attack()
		assert_eq(city.projectile_root.active_count(), 0, archetype_id)
		assert_eq(city.projectile_root.reservation_count(), 0, archetype_id)
		assert_eq(_visible_presentation_count(enemy), 1, archetype_id)
		match StringName(profile.attack_style):
			&"repair":
				assert_eq(ally.current_health, ally.max_health - 18.0, archetype_id)
			&"scan":
				assert_eq(
					city.encounter_runtime.target_mark_remaining,
					ProceduralEnemy.MARK_DURATION,
					archetype_id
				)
			&"choir_ring":
				assert_eq(
					city.encounter_runtime.target_mark_remaining,
					ProceduralEnemy.MARK_DURATION + 1.0,
					archetype_id
				)
		city.encounter_runtime.release(enemy)
		if ally != null and ally.active:
			city.encounter_runtime.release(ally)


func test_variant_to_legacy_reuse_clears_attack_vfx_identity_and_regions() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	var variant: ProceduralEnemy = city.encounter_runtime.acquire(
		&"intake_shepherd",
		Vector2(1050.0, 541.0)
	) as ProceduralEnemy
	variant.set_physics_process(false)
	variant._begin_attack()
	assert_eq(_visible_presentation_count(variant), 2)
	city.encounter_runtime.release(variant)
	var legacy: ProceduralEnemy = city.encounter_runtime.acquire(
		&"sapper",
		Vector2(1050.0, 541.0)
	) as ProceduralEnemy
	assert_same(legacy, variant)
	assert_eq(legacy.reset_debug_snapshot().get("attack_vfx_id"), &"")
	for sprite: Sprite2D in legacy._presentation_sprites:
		assert_false(sprite.visible)
		assert_null(sprite.texture)
		assert_false(sprite.region_enabled)
		assert_eq(sprite.region_rect, Rect2())
	assert_eq(city.projectile_root.reservation_count(), 0)


func _expected_radius(kind: StringName) -> float:
	match kind:
		&"shell":
			return 9.0
		&"rocket":
			return 7.0
		_:
			return 5.0


func _visible_region_center_offset(texture: Texture2D, region: Rect2i) -> Vector2:
	var image: Image = texture.get_image()
	var minimum: Vector2i = region.end
	var maximum: Vector2i = region.position - Vector2i.ONE
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			if image.get_pixel(x, y).a <= 0.03:
				continue
			minimum = minimum.min(Vector2i(x, y))
			maximum = maximum.max(Vector2i(x, y))
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Vector2.ZERO
	return (
		Vector2(minimum + maximum + Vector2i.ONE) * 0.5
		- Vector2(region.position)
		- Vector2(region.size) * 0.5
	)


func _visible_presentation_count(enemy: ProceduralEnemy) -> int:
	var count: int = 0
	for sprite: Sprite2D in enemy._presentation_sprites:
		if sprite.visible:
			count += 1
	return count
