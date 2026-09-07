extends GutTest

const TEST_PATH: String = "user://test_campaign_transaction_recovery.json"
const TRANSACTION_ID: StringName = &"boss:SETTLEMENT_ENGINE_S04:complete"
const REWARD_ID: StringName = &"boss:SETTLEMENT_ENGINE_S04:reward"


func before_each() -> void:
	_remove_saves()


func after_each() -> void:
	_remove_saves()


func test_duplicate_transaction_id_commits_once() -> void:
	var store: CampaignProgressStore = _store()
	assert_true(store.commit_boss_transaction(_payload()))
	assert_false(store.commit_boss_transaction(_payload()))
	assert_eq(store.dossier_count(), 1)
	assert_eq(store.evidence_count(), 1)
	assert_eq(store.completed_boss_ids().size(), 1)
	assert_eq(store.pending_reward_grants(), PackedStringArray([String(REWARD_ID)]))


func test_crash_before_write_commits_nothing() -> void:
	var store: CampaignProgressStore = _store()
	store.fault_injection = CampaignProgressStore.FAIL_BEFORE_WRITE
	assert_false(store.commit_boss_transaction(_payload()))
	var restored: CampaignProgressStore = _store()
	_assert_transaction_absent(restored)


func test_crash_after_temp_flush_recovers_complete_snapshot() -> void:
	var store: CampaignProgressStore = _store()
	store.fault_injection = CampaignProgressStore.FAIL_AFTER_TEMP_FLUSH
	assert_false(store.commit_boss_transaction(_payload()))
	assert_true(FileAccess.file_exists(TEST_PATH + ".tmp"))
	var restored: CampaignProgressStore = _store()
	_assert_transaction_present(restored)


func test_crash_before_rename_recovers_complete_snapshot() -> void:
	var store: CampaignProgressStore = _store()
	store.fault_injection = CampaignProgressStore.FAIL_BEFORE_RENAME
	assert_false(store.commit_boss_transaction(_payload()))
	var restored: CampaignProgressStore = _store()
	_assert_transaction_present(restored)


func test_crash_after_rename_recovers_without_duplicate() -> void:
	var store: CampaignProgressStore = _store()
	store.fault_injection = CampaignProgressStore.FAIL_AFTER_RENAME
	assert_false(store.commit_boss_transaction(_payload()))
	var restored: CampaignProgressStore = _store()
	_assert_transaction_present(restored)
	assert_false(restored.commit_boss_transaction(_payload()))


func test_crash_before_reward_consumption_preserves_one_pending_grant() -> void:
	var store: CampaignProgressStore = _store()
	assert_true(store.commit_boss_transaction(_payload()))
	var restored: CampaignProgressStore = _store()
	assert_false(restored.reward_grant_applied(REWARD_ID))
	assert_eq(restored.pending_reward_grants(), PackedStringArray([String(REWARD_ID)]))
	assert_true(restored.consume_reward_grant(REWARD_ID))


func test_crash_after_reward_consumption_cannot_apply_twice() -> void:
	var store: CampaignProgressStore = _store()
	assert_true(store.commit_boss_transaction(_payload()))
	assert_true(store.consume_reward_grant(REWARD_ID))
	var restored: CampaignProgressStore = _store()
	assert_true(restored.reward_grant_applied(REWARD_ID))
	assert_true(restored.pending_reward_grants().is_empty())
	assert_false(restored.consume_reward_grant(REWARD_ID))


func test_corrupt_primary_falls_back_to_last_valid_backup() -> void:
	var store: CampaignProgressStore = _store()
	assert_true(store.collect_dossier(&"dossier_business_mercy_exchange_annex"))
	assert_true(store.increment_continuity() == 1)
	assert_true(FileAccess.file_exists(TEST_PATH + ".bak"))
	var corrupt: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	corrupt.store_string("{corrupt")
	corrupt.close()
	var restored: CampaignProgressStore = _store()
	assert_true(restored.has_dossier(&"dossier_business_mercy_exchange_annex"))
	assert_eq(restored.continuity_generation(), 0)


func test_legacy_schema_migrates_capstone_aliases_and_preserves_unknown_fields() -> void:
	var legacy: ConfigFile = ConfigFile.new()
	legacy.set_value("meta", "schema_version", 1)
	legacy.set_value("meta", "future_note", "preserve")
	legacy.set_value("progress", "collected_dossiers", PackedStringArray([
		"dossier_business_crown_reserve_treasury",
	]))
	legacy.set_value("progress", "preserved_evidence", PackedStringArray(["LEDGER"]))
	legacy.set_value(
		"progress",
		"unlocked_reveals",
		PackedStringArray(["reveal_business_crown_reserve_treasury"])
	)
	legacy.set_value("progress", "continuity_generation", 3)
	assert_eq(legacy.save(TEST_PATH), OK)
	var restored: CampaignProgressStore = _store()
	assert_true(restored.has_dossier(&"B05_EASTBOUND_CONSIDERATION"))
	assert_true(restored.has_evidence(&"LEDGER"))
	assert_false(restored.snapshot().has("reveals"))
	assert_eq(restored.continuity_generation(), 3)
	assert_true(restored.save_progress())
	var migrated: CampaignProgressStore = _store()
	assert_eq(int(migrated.snapshot().schema_version), CampaignProgressStore.SCHEMA_VERSION)


func _payload() -> Dictionary:
	return {
		"transaction_id": TRANSACTION_ID,
		"boss_id": &"SETTLEMENT_ENGINE_S04",
		"dossier_ids": [&"B05_EASTBOUND_CONSIDERATION"],
		"evidence_ids": [&"LEDGER"],
		"unlock_chunk": 8,
		"reward_grant_id": REWARD_ID,
	}


func _assert_transaction_absent(store: CampaignProgressStore) -> void:
	assert_false(store.has_transaction(TRANSACTION_ID))
	assert_eq(store.dossier_count(), 0)
	assert_eq(store.evidence_count(), 0)


func _assert_transaction_present(store: CampaignProgressStore) -> void:
	assert_true(store.has_transaction(TRANSACTION_ID))
	assert_true(store.has_dossier(&"B05_EASTBOUND_CONSIDERATION"))
	assert_true(store.has_evidence(&"LEDGER"))
	assert_eq(store.pending_reward_grants(), PackedStringArray([String(REWARD_ID)]))


func _store() -> CampaignProgressStore:
	var store: CampaignProgressStore = CampaignProgressStore.new()
	store.setup(TEST_PATH)
	add_child_autofree(store)
	return store


func _remove_saves() -> void:
	for path: String in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
