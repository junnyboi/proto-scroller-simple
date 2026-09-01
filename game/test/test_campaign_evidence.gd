extends GutTest

const TEST_PATH: String = "user://test_campaign_evidence.json"


func before_each() -> void:
	_remove_saves()


func after_each() -> void:
	_remove_saves()


func test_exactly_ten_facade_dossiers_and_two_capstones_validate() -> void:
	assert_eq(DossierCatalog.validation_errors(), PackedStringArray())
	assert_eq(DossierCatalog.definitions().size(), 10)
	assert_eq(DossierCatalog.capstone_definitions().size(), 2)
	assert_eq(DossierCatalog.EVIDENCE_FLAGS.size(), 2)
	for boss: BossEncounterDefinition in BossCampaignCatalog.definitions():
		var capstone: DossierDefinition = DossierCatalog.capstone_for_boss(boss.boss_id)
		assert_not_null(capstone)
		assert_eq(capstone.dossier_id, boss.capstone_dossier_id)
		assert_eq(capstone.evidence_flag_id, boss.evidence_flag_id)
		assert_eq(capstone.building_variant_id, boss.arena_landmark_variant_id)


func test_optional_evidence_loss_never_blocks_progress_and_recovers_deterministically() -> void:
	var store: CampaignProgressStore = _store()
	assert_true(store.record_evidence_loss(&"LEDGER"))
	assert_true(store.record_evidence_loss(&"NURSERY"))
	assert_eq(store.next_recoverable_evidence(0), &"LEDGER")
	assert_eq(store.next_recoverable_evidence(1), &"NURSERY")
	assert_true(store.recover_evidence_from_elite(&"LEDGER", &"seed:0:elite:0"))
	assert_false(store.recover_evidence_from_elite(&"LEDGER", &"seed:0:elite:0"))
	assert_true(store.has_evidence(&"LEDGER"))
	assert_false(store.has_evidence(&"NURSERY"))
	assert_eq(store.next_recoverable_evidence(0), &"NURSERY")
	for boss: BossEncounterDefinition in BossCampaignCatalog.definitions():
		assert_true(boss.unlock_chunk == -1 or boss.unlock_chunk > boss.trigger_chunk)


func _store() -> CampaignProgressStore:
	var store: CampaignProgressStore = CampaignProgressStore.new()
	store.setup(TEST_PATH)
	add_child_autofree(store)
	return store


func _remove_saves() -> void:
	for path: String in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
