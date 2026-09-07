extends GutTest

const EXPECTED_SPECS: Dictionary = {
	&"enemy_bullet": {
		"source_size": Vector2i(96, 32),
		"display_size": Vector2(36.0, 12.0),
		"radius": 5.0,
		"impact_key": &"enemy_bullet_impact",
		"impact_atlas_size": Vector2i(240, 64),
		"impact_cell_size": Vector2i(48, 32),
		"reference_damage": 7.0,
		"audio_cue": AudioCueRegistry.Cue.ENEMY_BULLET_IMPACT,
	},
	&"enemy_shell": {
		"source_size": Vector2i(256, 128),
		"display_size": Vector2(36.0, 18.0),
		"radius": 9.0,
		"impact_key": &"enemy_shell_impact",
		"impact_atlas_size": Vector2i(320, 96),
		"impact_cell_size": Vector2i(64, 48),
		"reference_damage": 24.0,
		"audio_cue": AudioCueRegistry.Cue.ENEMY_SHELL_IMPACT,
	},
	&"enemy_rocket_direct": {
		"source_size": Vector2i(256, 96),
		"display_size": Vector2(42.0, 16.0),
		"radius": 7.0,
		"impact_key": &"enemy_rocket_direct_impact",
		"impact_atlas_size": Vector2i(480, 128),
		"impact_cell_size": Vector2i(96, 64),
		"reference_damage": 22.0,
		"audio_cue": AudioCueRegistry.Cue.ENEMY_ROCKET_DIRECT_IMPACT,
	},
	&"enemy_rocket_salvo": {
		"source_size": Vector2i(192, 72),
		"display_size": Vector2(36.0, 14.0),
		"radius": 7.0,
		"impact_key": &"enemy_rocket_salvo_impact",
		"impact_atlas_size": Vector2i(360, 112),
		"impact_cell_size": Vector2i(72, 56),
		"reference_damage": 24.0,
		"audio_cue": AudioCueRegistry.Cue.ENEMY_ROCKET_SALVO_IMPACT,
	},
}


func test_catalog_specs_load_and_validate_declared_contracts() -> void:
	assert_true(ProjectileVisualCatalog.debug_validate())
	assert_eq(ProjectileVisualCatalog.SPECS.size(), 4)
	for visual_key: StringName in EXPECTED_SPECS:
		assert_true(ProjectileVisualCatalog.has(visual_key))
		var item: Dictionary = ProjectileVisualCatalog.spec(visual_key)
		var expected: Dictionary = EXPECTED_SPECS[visual_key]
		var texture: Texture2D = item.get("texture") as Texture2D
		assert_not_null(texture)
		assert_eq(Vector2i(texture.get_size()), expected.source_size)
		assert_eq(item.get("source_size"), expected.source_size)
		assert_eq(item.get("display_size"), expected.display_size)
		assert_eq(float(item.get("collision_radius_contract")), expected.radius)
		assert_eq(item.get("trail_mode"), ProjectileVisualCatalog.TrailMode.NONE)
		assert_eq(item.get("impact_key"), expected.impact_key)
		var impact_spec: Dictionary = EnemyAttackVfxCatalog.impact_spec_for_key(
			expected.impact_key
		)
		var impact_texture: Texture2D = impact_spec.get("texture") as Texture2D
		assert_not_null(impact_texture)
		assert_eq(Vector2i(impact_texture.get_size()), expected.impact_atlas_size)
		assert_eq(impact_spec.get("frame_cell_size"), expected.impact_cell_size)
		assert_eq(int(impact_spec.get("frame_count")), 10)
		assert_gt(float(impact_spec.get("playback_fps")), 0.0)
		assert_gt((impact_spec.get("display_size") as Vector2).x, 0.0)
		assert_eq(float(impact_spec.get("reference_damage")), expected.reference_damage)
		assert_eq(int(impact_spec.get("audio_cue")), expected.audio_cue)
	assert_false(ProjectileVisualCatalog.has(&"missing"))
	assert_true(ProjectileVisualCatalog.spec(&"missing").is_empty())


func test_projectile_defaults_keep_radius_and_rotate_authored_visual_to_velocity() -> void:
	var projectile: Projectile2D = await _spawn_projectile()
	var cases: Array[Dictionary] = [
		{"kind": &"bullet", "key": &"enemy_bullet", "radius": 5.0},
		{"kind": &"shell", "key": &"enemy_shell", "radius": 9.0},
		{"kind": &"rocket", "key": &"enemy_rocket_direct", "radius": 7.0},
	]
	var directions: Array[Vector2] = [
		Vector2.RIGHT,
		Vector2.LEFT,
		Vector2.UP,
		Vector2.DOWN,
		Vector2(1.0, 1.0).normalized(),
	]
	for item: Dictionary in cases:
		for direction: Vector2 in directions:
			projectile.activate(
				Vector2.ZERO,
				direction,
				400.0,
				10.0,
				null,
				1,
				item.kind
			)
			assert_eq(projectile.visual_key, item.key)
			assert_false(projectile.impact_key.is_empty())
			assert_almost_eq(projectile.visual_angle(), direction.angle(), 0.0001)
			assert_eq(projectile.projectile_radius, item.radius)
			var collision: CircleShape2D = (
				projectile.get_node(^"CollisionShape2D").shape as CircleShape2D
			)
			assert_eq(collision.radius, item.radius)


func test_boss_projectile_scale_expands_visual_and_hitbox_then_resets_on_reuse() -> void:
	var pool: ProjectilePool = ProjectilePool.new()
	add_child_autofree(pool)
	await get_tree().process_frame
	var boss_shell: Projectile2D = pool.acquire(
		Vector2.ZERO,
		Vector2.LEFT,
		900.0,
		32.0,
		null,
		1,
		&"shell",
		ProjectileVisualCatalog.ENEMY_SHELL,
		1.5
	)
	assert_not_null(boss_shell)
	assert_almost_eq(boss_shell.presentation_scale, 1.5, 0.0001)
	assert_eq(boss_shell.rendered_display_size(), Vector2(54.0, 27.0))
	var collision: CircleShape2D = (
		boss_shell.get_node(^"CollisionShape2D").shape as CircleShape2D
	)
	assert_almost_eq(collision.radius, 13.5, 0.0001)
	pool.release(boss_shell)
	assert_almost_eq(boss_shell.presentation_scale, 1.0, 0.0001)
	assert_almost_eq(collision.radius, 5.0, 0.0001)
	var ordinary_shell: Projectile2D = pool.acquire(
		Vector2.ZERO, Vector2.RIGHT, 400.0, 8.0, null, 1, &"shell"
	)
	assert_same(ordinary_shell, boss_shell)
	assert_almost_eq(ordinary_shell.presentation_scale, 1.0, 0.0001)
	assert_eq(ordinary_shell.rendered_display_size(), Vector2(36.0, 18.0))
	assert_almost_eq(collision.radius, 9.0, 0.0001)


func test_reserved_partition_mismatch_cancels_capacity_atomically() -> void:
	var pool: ProjectilePool = ProjectilePool.new()
	add_child_autofree(pool)
	var reservation_id: int = pool.reserve(&"shell")
	assert_gt(reservation_id, 0)
	assert_null(pool.acquire_reserved(
		reservation_id,
		Vector2.ZERO,
		Vector2.RIGHT,
		400.0,
		8.0,
		null,
		1,
		&"rocket"
	))
	assert_eq(pool.reservation_count(&"shell"), 0)
	assert_eq(pool.available_count(&"shell"), RuntimeBudget.SHELLS)


func test_explicit_salvo_key_resets_cleanly_and_machine_gun_path_is_preserved() -> void:
	var projectile: Projectile2D = await _spawn_projectile()
	projectile.activate(
		Vector2(10.0, 20.0),
		Vector2.UP,
		520.0,
		12.0,
		null,
		3,
		&"rocket",
		ProjectileVisualCatalog.ENEMY_ROCKET_SALVO
	)
	assert_eq(projectile.visual_key, ProjectileVisualCatalog.ENEMY_ROCKET_SALVO)
	assert_eq(projectile.impact_key, &"enemy_rocket_salvo_impact")
	assert_eq(projectile.projectile_radius, 7.0)
	projectile.modulate = Color.RED
	projectile.deactivate()
	assert_false(projectile.active)
	assert_eq(projectile.visual_key, &"")
	assert_eq(projectile.impact_key, &"")
	assert_eq(projectile.velocity, Vector2.ZERO)
	assert_eq(projectile.collision_mask, 0)
	assert_null(projectile.source)
	assert_eq(projectile.lifetime, 2.5)
	assert_eq(projectile.modulate, Color.WHITE)
	projectile.activate(
		Vector2.ZERO, Vector2.RIGHT, 900.0, 5.0, null, 1, &"machine_gun"
	)
	assert_eq(projectile.visual_key, &"")
	assert_eq(projectile.projectile_radius, 4.0)
	assert_same(
		Projectile2D.MACHINE_GUN_ROUND_TEXTURE,
		load("res://assets/player/weapons/machine_gun_round.png")
	)


func test_pool_carries_optional_visual_key_without_changing_capacity_or_reservations() -> void:
	var pool: ProjectilePool = ProjectilePool.new()
	add_child_autofree(pool)
	await get_tree().process_frame
	assert_eq(pool.total_count(), 32)
	var child_count: int = pool.get_child_count()
	var direct: Projectile2D = pool.acquire(
		Vector2.ZERO, Vector2.RIGHT, 440.0, 8.0, null, 1, &"rocket"
	)
	assert_not_null(direct)
	assert_eq(direct.visual_key, ProjectileVisualCatalog.ENEMY_ROCKET_DIRECT)
	var reservation_id: int = pool.reserve(&"rocket")
	assert_gt(reservation_id, 0)
	var salvo: Projectile2D = pool.acquire_reserved(
		reservation_id,
		Vector2.ZERO,
		Vector2.LEFT,
		430.0,
		6.0,
		null,
		1,
		&"rocket",
		ProjectileVisualCatalog.ENEMY_ROCKET_SALVO
	)
	assert_not_null(salvo)
	assert_eq(salvo.visual_key, ProjectileVisualCatalog.ENEMY_ROCKET_SALVO)
	assert_eq(pool.reservation_count(&"rocket"), 0)
	assert_eq(pool.get_child_count(), child_count)
	assert_eq(pool.total_count(), 32)
	pool.release_all()
	assert_eq(pool.active_count(), 0)
	assert_eq(salvo.visual_key, &"")
	assert_eq(pool.hostile_impact_slot_count(), ProjectilePool.HOSTILE_IMPACT_CAPACITY)


func test_four_generated_impact_families_animate_in_fixed_pool() -> void:
	var pool: ProjectilePool = ProjectilePool.new()
	add_child_autofree(pool)
	var audio_root: Node2D = Node2D.new()
	add_child_autofree(audio_root)
	var feedback_pool: ImpactFeedbackPool = ImpactFeedbackPool.new()
	feedback_pool.setup(audio_root, audio_root)
	add_child_autofree(feedback_pool)
	await get_tree().process_frame
	pool.set_impact_feedback_pool(feedback_pool)
	var child_count: int = pool.get_child_count()
	var family_index: int = 0
	for visual_key: StringName in EXPECTED_SPECS:
		var expected: Dictionary = EXPECTED_SPECS[visual_key]
		var damage_ratio: float = [0.5, 1.0, 2.25, 4.0][family_index]
		var impact_damage: float = expected.reference_damage * damage_ratio
		var projectile: Projectile2D = pool.acquire(
			Vector2.ZERO,
			Vector2(1.0, 1.0).normalized(),
			440.0,
			impact_damage,
			null,
			1,
			_kind_for_visual_key(visual_key),
			visual_key
		)
		assert_not_null(projectile, visual_key)
		pool._on_impact_requested(
			projectile,
			Vector2(400.0, 300.0),
			projectile.velocity.normalized(),
			projectile.damage_type,
			expected.impact_key,
			projectile.damage
		)
		var impact: WeaponImpactEffect2D = _active_impact_for_key(
			pool, expected.impact_key
		)
		assert_not_null(impact, visual_key)
		assert_eq(impact.current_frame, 0, visual_key)
		assert_almost_eq(impact.rotation, PI * 0.25, 0.0001, visual_key)
		var expected_scale: float = ProjectilePool.damage_impact_scale(
			impact_damage,
			expected.reference_damage
		)
		assert_almost_eq(impact.presentation_scale, expected_scale, 0.0001, visual_key)
		assert_almost_eq(pool.last_hostile_impact_scale, expected_scale, 0.0001, visual_key)
		assert_almost_eq(pool.last_hostile_impact_damage, impact_damage, 0.0001, visual_key)
		assert_eq(pool.last_hostile_impact_cue, expected.audio_cue, visual_key)
		assert_eq(feedback_pool.last_cue, expected.audio_cue, visual_key)
		assert_between(
			feedback_pool.last_cue_pitch,
			1.0 - ProjectilePool.HOSTILE_IMPACT_PITCH_VARIATION,
			1.0 + ProjectilePool.HOSTILE_IMPACT_PITCH_VARIATION,
			visual_key
		)
		var authored_volume_db: float = float(
			AudioCueRegistry.profile(expected.audio_cue).volume_db
		)
		assert_between(
			feedback_pool.last_cue_volume_db,
			authored_volume_db - ProjectilePool.HOSTILE_IMPACT_VOLUME_VARIATION_DB,
			authored_volume_db + ProjectilePool.HOSTILE_IMPACT_VOLUME_VARIATION_DB,
			visual_key
		)
		assert_false(impact.particles.visible, visual_key)
		var impact_spec: Dictionary = EnemyAttackVfxCatalog.impact_spec_for_key(
			expected.impact_key
		)
		var playback_fps: float = float(impact_spec.playback_fps)
		impact._process(3.2 / playback_fps)
		assert_eq(impact.current_frame, 3, visual_key)
		impact._process(7.0 / playback_fps)
		assert_false(impact.active, visual_key)
		assert_eq(impact.current_frame, 0, visual_key)
		pool.release(projectile)
		assert_eq(pool.get_child_count(), child_count, visual_key)
		family_index += 1
	assert_not_same(
		EnemyAttackVfxCatalog.impact_spec_for_key(
			&"enemy_rocket_direct_impact"
		).texture,
		EnemyAttackVfxCatalog.impact_spec_for_key(
			&"enemy_rocket_salvo_impact"
		).texture
	)
	assert_eq(pool.total_count(), 32)
	assert_eq(pool.denial_count, 0)
	assert_eq(feedback_pool.cue_play_count, 4)
	assert_eq(feedback_pool.audio_child_count(), 8)
	pool.release_all()
	assert_eq(pool.active_hostile_impact_count(), 0)


func test_generated_impact_audio_assets_are_unique_mono_qoa_and_bounded() -> void:
	var cues: Array[AudioCueRegistry.Cue] = [
		AudioCueRegistry.Cue.ENEMY_BULLET_IMPACT,
		AudioCueRegistry.Cue.ENEMY_SHELL_IMPACT,
		AudioCueRegistry.Cue.ENEMY_ROCKET_DIRECT_IMPACT,
		AudioCueRegistry.Cue.ENEMY_ROCKET_SALVO_IMPACT,
	]
	var unique_payloads: Dictionary[PackedByteArray, bool] = {}
	for cue: AudioCueRegistry.Cue in cues:
		var profile: Dictionary = AudioCueRegistry.profile(cue)
		var stream: AudioStreamWAV = profile.stream as AudioStreamWAV
		var cue_label: String = str(cue)
		assert_not_null(stream, cue_label)
		assert_eq(stream.mix_rate, 24000, cue_label)
		assert_eq(stream.format, AudioStreamWAV.FORMAT_QOA, cue_label)
		assert_false(stream.stereo, cue_label)
		assert_between(stream.get_length(), 1.0, 1.4, cue_label)
		assert_false(unique_payloads.has(stream.data), cue_label)
		unique_payloads[stream.data] = true
	assert_eq(unique_payloads.size(), 4)
	assert_almost_eq(
		ImpactFeedbackPool.cue_pitch_for_sample(
			0.0, ProjectilePool.HOSTILE_IMPACT_PITCH_VARIATION
		),
		0.965,
		0.0001
	)
	assert_almost_eq(
		ImpactFeedbackPool.cue_pitch_for_sample(
			0.5, ProjectilePool.HOSTILE_IMPACT_PITCH_VARIATION
		),
		1.0,
		0.0001
	)
	assert_almost_eq(
		ImpactFeedbackPool.cue_pitch_for_sample(
			1.0, ProjectilePool.HOSTILE_IMPACT_PITCH_VARIATION
		),
		1.035,
		0.0001
	)
	assert_almost_eq(
		ImpactFeedbackPool.cue_pitch_for_sample(1.0, 1.0),
		1.0 + ImpactFeedbackPool.MAX_CUE_PITCH_VARIATION,
		0.0001
	)
	assert_almost_eq(
		ImpactFeedbackPool.cue_volume_delta_for_sample(
			0.0, ProjectilePool.HOSTILE_IMPACT_VOLUME_VARIATION_DB
		),
		-0.45,
		0.0001
	)
	assert_almost_eq(
		ImpactFeedbackPool.cue_volume_delta_for_sample(
			0.5, ProjectilePool.HOSTILE_IMPACT_VOLUME_VARIATION_DB
		),
		0.0,
		0.0001
	)
	assert_almost_eq(
		ImpactFeedbackPool.cue_volume_delta_for_sample(
			1.0, ProjectilePool.HOSTILE_IMPACT_VOLUME_VARIATION_DB
		),
		0.45,
		0.0001
	)
	assert_almost_eq(
		ImpactFeedbackPool.cue_volume_delta_for_sample(1.0, 20.0),
		ImpactFeedbackPool.MAX_CUE_VOLUME_VARIATION_DB,
		0.0001
	)
	assert_almost_eq(
		ProjectilePool.damage_impact_scale(1.0, 100.0),
		ProjectilePool.MIN_DAMAGE_IMPACT_SCALE,
		0.0001
	)
	assert_almost_eq(
		ProjectilePool.damage_impact_scale(1000.0, 10.0),
		ProjectilePool.MAX_DAMAGE_IMPACT_SCALE,
		0.0001
	)


func _spawn_projectile() -> Projectile2D:
	var projectile: Projectile2D = Projectile2D.new()
	add_child_autofree(projectile)
	await get_tree().process_frame
	projectile.set_physics_process(false)
	return projectile


func _active_impact_for_key(
	pool: ProjectilePool,
	impact_key: StringName
) -> WeaponImpactEffect2D:
	for impact: WeaponImpactEffect2D in pool.hostile_impacts:
		if impact.active and impact.visual_key == impact_key:
			return impact
	return null


func _kind_for_visual_key(visual_key: StringName) -> StringName:
	if visual_key == ProjectileVisualCatalog.ENEMY_SHELL:
		return &"shell"
	if visual_key in [
		ProjectileVisualCatalog.ENEMY_ROCKET_DIRECT,
		ProjectileVisualCatalog.ENEMY_ROCKET_SALVO,
	]:
		return &"rocket"
	return &"bullet"
