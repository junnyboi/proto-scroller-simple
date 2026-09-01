extends GutTest


func test_every_boss_has_text_objectives_safe_gaps_and_noncolor_telegraphs() -> void:
	for definition: BossEncounterDefinition in BossCampaignCatalog.definitions():
		assert_false(definition.display_name_key.is_empty(), definition.boss_id)
		assert_false(L10n.t(definition.display_name_key).is_empty(), definition.boss_id)
		assert_false(definition.narrative_event_keys.is_empty(), definition.boss_id)
		for phase: BossPhaseDefinition in definition.phases:
			assert_false(phase.telegraph_profile.is_empty(), phase.phase_id)
			assert_false(phase.attack_choices.is_empty(), phase.phase_id)
			if phase.safe_gap_required:
				assert_gt(phase.minimum_safe_gap, 0.0, phase.phase_id)


func test_grayscale_presentation_does_not_change_damage_geometry() -> void:
	var rig: BossRig2D = BossRig2D.new()
	var host: TankEnemy = TankEnemy.new()
	add_child_autofree(host)
	add_child_autofree(rig)
	for definition: BossEncounterDefinition in BossCampaignCatalog.definitions():
		assert_true(rig.configure(definition, host))
		var geometry: Dictionary = rig.mechanical_signature()
		for part: Sprite2D in rig.parts:
			part.modulate = Color(0.42, 0.42, 0.42, part.modulate.a)
		assert_eq(rig.mechanical_signature(), geometry, definition.boss_id)
		assert_gt(rig.active_part_count, 0, definition.boss_id)
		assert_gt(rig.active_hurt_region_count, 0, definition.boss_id)
