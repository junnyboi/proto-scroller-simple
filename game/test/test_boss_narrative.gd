extends GutTest

const TEST_PATH: String = "user://test_boss_narrative.json"


func before_each() -> void:
	_remove_saves()
	L10n.set_locale("en")


func after_each() -> void:
	_remove_saves()
	L10n.set_locale("en")


func test_boss_lines_are_localized_observations_and_never_pause_control() -> void:
	var store: CampaignProgressStore = _store()
	var director: NarrativeDirector = NarrativeDirector.new()
	director.setup(store)
	add_child_autofree(director)
	watch_signals(director)
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition(
		&"SETTLEMENT_ENGINE_S04"
	)
	director.handle_boss_attempt_started(definition)
	director.handle_boss_state_changed(CommandBossSession.STATE_EXPOSED)
	assert_signal_emit_count(director, "transmission_requested", 2)
	assert_false(get_tree().paused)
	assert_eq(director.echo7_status_key(), "narrative.echo7.ambiguous")
	assert_ne(L10n.t(String(definition.voice_caption_keys[&"echo"])), "")
	assert_ne(L10n.t(String(definition.voice_caption_keys[&"veyr"])), "")


func test_boss_completion_commits_capstone_evidence_result_and_reward_once() -> void:
	var store: CampaignProgressStore = _store()
	var director: NarrativeDirector = NarrativeDirector.new()
	director.setup(store)
	add_child_autofree(director)
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition(&"SAMARITAN_15")
	var canonical_event: Dictionary = {
		"central_cradle_preserved": true,
		"pod_loss_count": 1,
		"rescue_tally": 3,
	}
	assert_true(director.handle_boss_completed(definition, canonical_event))
	assert_true(director.handle_boss_completed(definition, canonical_event))
	assert_true(store.has_dossier(&"ASHWATER_INTAKE_MANIFEST"))
	assert_true(store.has_evidence(&"NURSERY"))
	assert_true(store.completed_boss_ids().has("SAMARITAN_15"))
	assert_true(store.pending_reward_grants().has("boss:SAMARITAN_15:reward"))
	assert_eq(int(store.snapshot().route_unlock_chunk), -1)
	assert_eq(int(store.snapshot().boss_results.SAMARITAN_15.pod_loss_count), 1)


func test_optional_archive_loss_preserves_capstone_and_route_but_not_ledger() -> void:
	var store: CampaignProgressStore = _store()
	var director: NarrativeDirector = NarrativeDirector.new()
	director.setup(store)
	add_child_autofree(director)
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition(
		&"SETTLEMENT_ENGINE_S04"
	)
	assert_true(director.handle_boss_completed(definition, {
		"archive_preserved": false,
	}))
	assert_true(store.has_dossier(&"B05_EASTBOUND_CONSIDERATION"))
	assert_false(store.has_evidence(&"LEDGER"))
	assert_true(store.lost_evidence_ids().has("LEDGER"))
	assert_true(store.completed_boss_ids().has("SETTLEMENT_ENGINE_S04"))
	assert_eq(int(store.snapshot().route_unlock_chunk), 9)
	assert_false(bool(
		store.snapshot().boss_results.SETTLEMENT_ENGINE_S04.archive_preserved
	))


func test_missing_optional_event_cannot_silently_preserve_evidence() -> void:
	var store: CampaignProgressStore = _store()
	var director: NarrativeDirector = NarrativeDirector.new()
	director.setup(store)
	add_child_autofree(director)
	assert_true(director.handle_boss_completed(
		BossCampaignCatalog.definition(&"SETTLEMENT_ENGINE_S04")
	))
	assert_false(store.has_evidence(&"LEDGER"))
	assert_true(store.has_dossier(&"B05_EASTBOUND_CONSIDERATION"))


func test_vertical_slice_keys_exist_in_both_locales() -> void:
	var keys: PackedStringArray = PackedStringArray([
		"boss.objective.business.connect", "boss.objective.business.finish",
		"boss.objective.residential.connect", "boss.objective.residential.rescue",
		"boss.archive.preserved", "boss.archive.lost", "boss.rescue.tally",
		"boss.attack.core_shockwave",
		"boss.attack.settlement_sweep", "boss.attack.double_entry_barrage",
		"boss.attack.foreclosure_stamp", "boss.attack.audit_beam",
		"boss.attack.foundation_cascade", "boss.attack.triage_sweep",
		"boss.attack.pressure_sentence", "boss.attack.extraction_clamp",
		"boss.attack.blackout_harvest",
	])
	for locale: String in L10n.available_locales():
		assert_true(L10n.set_locale(locale))
		for key: String in keys:
			assert_ne(L10n.t(key), key)
		for definition: BossEncounterDefinition in BossCampaignCatalog.definitions():
			assert_ne(
				L10n.t(String(definition.voice_caption_keys[&"echo"])),
				String(definition.voice_caption_keys[&"echo"])
			)
			var capstone: DossierDefinition = DossierCatalog.capstone_for_boss(
				definition.boss_id
			)
			assert_ne(L10n.t(capstone.title_key), capstone.title_key)
			assert_ne(L10n.t(capstone.body_primary_key), capstone.body_primary_key)
			assert_ne(L10n.t(capstone.body_secondary_key), capstone.body_secondary_key)


func _store() -> CampaignProgressStore:
	var store: CampaignProgressStore = CampaignProgressStore.new()
	store.setup(TEST_PATH)
	add_child_autofree(store)
	return store


func _remove_saves() -> void:
	for path: String in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
