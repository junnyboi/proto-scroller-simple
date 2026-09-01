extends GutTest

const PRESETS: Array[StringName] = [
	&"SETTLEMENT_ENGINE",
	&"SAMARITAN",
]


func test_animation_catalog_covers_both_bosses() -> void:
	assert_eq(BossAnimationCatalog.validation_errors(), [])
	for preset: StringName in PRESETS:
		var texture: Texture2D = BossAnimationCatalog.texture_for_preset(preset)
		assert_not_null(texture, "%s has an animation atlas" % preset)
		assert_eq(int(texture.get_size().x) % BossAnimationCatalog.COLUMN_COUNT, 0)
		assert_eq(int(texture.get_size().y) % BossAnimationCatalog.ROW_COUNT, 0)
		var cell_size := Vector2i(
			int(texture.get_size().x) / BossAnimationCatalog.COLUMN_COUNT,
			int(texture.get_size().y) / BossAnimationCatalog.ROW_COUNT
		)
		assert_eq(
			cell_size,
			BossAnimationCatalog.EXPECTED_CELL_SIZES[preset],
			"%s uses an exact 2x source cell" % preset
		)
	assert_eq(BossAnimationCatalog.SOURCE_DENSITY_SCALE, 2)


func test_all_direction_and_state_sequences_have_stable_rows() -> void:
	assert_eq(BossAnimationCatalog.sequence_row(&"E", BossRig2D.STATE_MOVING), 0)
	assert_eq(BossAnimationCatalog.sequence_row(&"W", BossRig2D.STATE_MOVING), 1)
	assert_eq(BossAnimationCatalog.sequence_row(&"E", BossRig2D.STATE_ATTACKING), 2)
	assert_eq(BossAnimationCatalog.sequence_row(&"W", BossRig2D.STATE_ATTACKING), 3)
	assert_eq(BossAnimationCatalog.FRAME_COUNT, 8)


func test_attack_frames_partition_without_gaps_or_overlap() -> void:
	assert_eq(BossAnimationCatalog.TELEGRAPH_FRAME_RANGE, Vector2i(0, 3))
	assert_eq(BossAnimationCatalog.ACTIVE_FRAME_RANGE, Vector2i(3, 5))
	assert_eq(BossAnimationCatalog.RECOVERY_FRAME_RANGE, Vector2i(5, 8))
	assert_eq(BossAnimationCatalog.TELEGRAPH_SECONDS, BossVerticalSliceController.TELEGRAPH_SECONDS)
	assert_eq(BossAnimationCatalog.TELEGRAPH_SECONDS, BossEscalationController.TELEGRAPH_SECONDS)
	assert_eq(BossAnimationCatalog.TELEGRAPH_SECONDS, BossRoyalFinaleController.TELEGRAPH_SECONDS)
	assert_eq(BossAnimationCatalog.ACTIVE_SECONDS, BossVerticalSliceController.ACTIVE_SECONDS)
	assert_eq(BossAnimationCatalog.RECOVERY_SECONDS, BossRoyalFinaleController.RECOVERY_SECONDS)
	assert_eq(BossAnimationCatalog.frame_range_for_stage(&"TELEGRAPH").x, 0)
	assert_eq(BossAnimationCatalog.frame_range_for_stage(&"RECOVERY").y, 8)


func test_rig_animation_never_moves_mechanical_regions_or_sockets() -> void:
	var rig := BossRig2D.new()
	add_child_autofree(rig)
	var definition := BossEncounterDefinition.new()
	definition.rig_preset = &"SETTLEMENT_ENGINE"
	var host := TankEnemy.new()
	add_child_autofree(host)
	assert_true(rig.configure(definition, host))
	var before_mechanics: Dictionary = rig.mechanical_signature()
	var before_sockets: Dictionary = rig.presentation_signature().sockets
	rig.play_attacking(&"TELEGRAPH", &"E")
	rig.advance_animation(0.42)
	rig.play_attacking(&"ACTIVE", &"W")
	rig.advance_animation(0.31)
	assert_eq(rig.mechanical_signature(), before_mechanics)
	assert_eq(rig.presentation_signature().sockets, before_sockets)
	assert_eq(rig.animation_signature().direction, &"W")
	assert_eq(rig.animation_signature().sequence_row, 3)


func test_both_campaign_bosses_are_50_percent_larger_and_touch_road() -> void:
	for definition: BossEncounterDefinition in BossCampaignCatalog.definitions():
		var rig := BossRig2D.new()
		add_child_autofree(rig)
		var host := TankEnemy.new()
		add_child_autofree(host)
		host.global_position = Vector2(
			940.0,
			BossRig2D.road_contact_y_for_preset(definition.rig_preset)
		)
		assert_true(rig.configure(definition, host))
		assert_eq(rig.scale, Vector2.ONE * 1.5, definition.boss_id)
		var visible_bottom: float = (
			rig.global_position.y
			+ BossRig2D.visible_bottom_local_y(definition.rig_preset) * rig.scale.y
		)
		assert_almost_eq(
			visible_bottom,
			CityStreetChunk.ROAD_DIVIDER_Y,
			0.02,
			definition.boss_id
		)


func test_moving_loop_and_attack_stage_reset_are_deterministic() -> void:
	var rig := BossRig2D.new()
	add_child_autofree(rig)
	var definition := BossEncounterDefinition.new()
	definition.rig_preset = &"SAMARITAN"
	var host := TankEnemy.new()
	add_child_autofree(host)
	assert_true(rig.configure(definition, host))
	rig.advance_animation(0.5)
	assert_eq(rig.animation_signature().frame, 3)
	rig.play_attacking(&"ACTIVE", &"E")
	assert_eq(rig.animation_signature().frame, 3)
	rig.advance_animation(BossAnimationCatalog.stage_duration(&"ACTIVE"))
	assert_eq(rig.animation_signature().frame, 4)
	rig.play_attacking(&"RECOVERY", &"E")
	assert_eq(rig.animation_signature().frame, 5)


func test_defeated_pose_freezes_final_attack_frame_and_darkens_rig() -> void:
	var rig := BossRig2D.new()
	add_child_autofree(rig)
	var definition := BossEncounterDefinition.new()
	definition.rig_preset = &"SAMARITAN"
	var host := TankEnemy.new()
	add_child_autofree(host)
	assert_true(rig.configure(definition, host))
	rig.freeze_defeated(Vector2(940.0, 580.0), &"W")
	var signature: Dictionary = rig.animation_signature()
	assert_true(signature.defeated)
	assert_eq(signature.state, BossRig2D.STATE_ATTACKING)
	assert_eq(signature.stage, &"RECOVERY")
	assert_eq(signature.direction, &"W")
	assert_eq(signature.frame, BossAnimationCatalog.FRAME_COUNT - 1)
	assert_eq(signature.modulate, BossRig2D.DEFEATED_MODULATE)
	rig.advance_animation(10.0)
	rig.play_moving(&"E")
	assert_eq(rig.animation_signature(), signature)
