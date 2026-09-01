extends GutTest

const SAVE_ROOT: String = "user://runtime_tweak_tests"

var _services: Array[RuntimeTweakService] = []


func before_each() -> void:
	_cleanup_root()


func after_each() -> void:
	for service: RuntimeTweakService in _services:
		if is_instance_valid(service):
			service.queue_free()
	_services.clear()
	RuntimeTweakAccess.unbind_service()
	_cleanup_root()


func test_res_baseline_loads_before_valid_user_delta_and_ignores_unknown_ids() -> void:
	var path: String = SAVE_ROOT + "/precedence.json"
	var catalog: RuntimeTweakCatalog = RuntimeTweakCatalog.load_catalog()
	var writer: RuntimeTweakPersistence = RuntimeTweakPersistence.new(path)
	assert_true(writer.save_delta({
		&"player.move.max_speed": 300.0,
		&"unknown.future.parameter": 999,
	}, catalog.catalog_revision))
	var service: RuntimeTweakService = _new_service(path)
	assert_eq(service.requested_value(&"player.move.max_speed"), 300.0)
	assert_eq(service.requested_value(&"player.melee.ground_smash_damage"), 180.0)
	assert_eq(service.requested_values.size(), 52)


func test_memory_updates_immediately_and_five_edits_debounce_to_one_write() -> void:
	var service: RuntimeTweakService = _new_service(SAVE_ROOT + "/debounce.json")
	for value: float in [270.0, 280.0, 290.0, 300.0, 310.0]:
		assert_true(bool(service.set_value(&"player.move.max_speed", value).ok))
	assert_eq(service.requested_value(&"player.move.max_speed"), 310.0)
	assert_eq(service.persistence.write_count, 0)
	assert_eq(service.persistence_state, &"SAVING")
	await get_tree().create_timer(0.46).timeout
	assert_eq(service.persistence.write_count, 1)
	assert_eq(service.persistence_state, &"SAVED")


func test_only_nondefault_deltas_persist_and_reset_removes_key() -> void:
	var path: String = SAVE_ROOT + "/delta.json"
	var service: RuntimeTweakService = _new_service(path)
	service.set_value(&"player.move.max_speed", 300.0)
	service.set_value(&"world.weather.opacity_multiplier", 0.8)
	assert_true(service.flush_now())
	var saved: Dictionary = _read_json(path)
	assert_eq((saved.values as Dictionary).size(), 2)
	assert_true((saved.values as Dictionary).has("player.move.max_speed"))
	assert_true(service.reset_value(&"player.move.max_speed"))
	assert_true(service.flush_now())
	saved = _read_json(path)
	assert_eq((saved.values as Dictionary).size(), 1)
	assert_false((saved.values as Dictionary).has("player.move.max_speed"))


func test_hash_is_stable_and_changes_only_with_canonical_values() -> void:
	var service: RuntimeTweakService = _new_service(SAVE_ROOT + "/hash.json")
	var baseline_hash: String = service.requested_configuration_hash()
	var forward: Dictionary = service.requested_values.duplicate(true)
	var reverse: Dictionary = {}
	var keys: Array = forward.keys()
	keys.reverse()
	for key: Variant in keys:
		reverse[key] = forward[key]
	assert_eq(service.configuration_hash(forward), service.configuration_hash(reverse))
	service.set_value(&"player.move.max_speed", 300.0)
	assert_ne(service.requested_configuration_hash(), baseline_hash)
	service.reset_value(&"player.move.max_speed")
	assert_eq(service.requested_configuration_hash(), baseline_hash)


func test_color_values_canonicalize_persist_and_reset_as_deltas() -> void:
	var path: String = SAVE_ROOT + "/colors.json"
	var service: RuntimeTweakService = _new_service(path)
	assert_true(bool(service.set_value(&"player.visual.tint", "62F5DF").ok))
	assert_eq(service.requested_value(&"player.visual.tint"), "#62f5df")
	assert_true(service.flush_now())
	var saved: Dictionary = _read_json(path)
	assert_eq((saved.values as Dictionary).get("player.visual.tint"), "#62f5df")
	var restored: RuntimeTweakService = _new_service(path)
	assert_eq(restored.requested_value(&"player.visual.tint"), "#62f5df")
	assert_true(restored.reset_value(&"player.visual.tint"))
	assert_true(restored.flush_now())
	saved = _read_json(path)
	assert_false((saved.values as Dictionary).has("player.visual.tint"))


func test_deferred_values_taint_only_when_their_boundary_applies_and_remain_sticky() -> void:
	var service: RuntimeTweakService = _new_service(SAVE_ROOT + "/boundary.json")
	service.freeze_run(77)
	service.set_value(&"player.melee.ground_smash_damage", 240.0)
	assert_eq(service.provenance.status, RunTuningProvenance.BASELINE)
	assert_eq(service.active_value(&"player.melee.ground_smash_damage"), 180.0)
	assert_eq(service.next_attack_value(&"player.melee.ground_smash_damage"), 240.0)
	assert_eq(service.provenance.status, RunTuningProvenance.TUNED)
	service.reset_value(&"player.melee.ground_smash_damage")
	assert_eq(service.provenance.status, RunTuningProvenance.TUNED)
	assert_false(service.provenance.ranked_eligible())


func test_pending_next_run_change_does_not_taint_current_run_but_applies_to_next() -> void:
	var service: RuntimeTweakService = _new_service(SAVE_ROOT + "/next-run.json")
	service.freeze_run(1)
	service.set_value(&"spawn.quantity_multiplier", 1)
	assert_eq(service.run_value(&"spawn.quantity_multiplier"), 2)
	assert_eq(service.provenance.status, RunTuningProvenance.BASELINE)
	service.freeze_run(2)
	assert_eq(service.run_value(&"spawn.quantity_multiplier"), 1)
	assert_eq(service.provenance.status, RunTuningProvenance.TUNED)


func test_cosmetic_only_run_remains_ranked_and_sandbox_is_irreversible() -> void:
	var service: RuntimeTweakService = _new_service(SAVE_ROOT + "/integrity.json")
	service.set_value(&"world.weather.opacity_multiplier", 0.8)
	service.freeze_run(5)
	assert_true(service.provenance.ranked_eligible())
	service.mark_sandbox(&"spawn_enemy")
	assert_eq(service.provenance.status, RunTuningProvenance.SANDBOX)
	assert_false(service.provenance.ranked_eligible())
	service.reset_all()
	assert_eq(service.provenance.status, RunTuningProvenance.SANDBOX)


func test_corrupt_primary_recovers_valid_backup_without_partial_overlay() -> void:
	var path: String = SAVE_ROOT + "/recovery.json"
	var catalog: RuntimeTweakCatalog = RuntimeTweakCatalog.load_catalog()
	var writer: RuntimeTweakPersistence = RuntimeTweakPersistence.new(path + ".bak")
	assert_true(writer.save_delta({&"player.move.max_speed": 300.0}, catalog.catalog_revision))
	_write_text(path, "{ definitely not json")
	var service: RuntimeTweakService = _new_service(path)
	assert_eq(service.requested_value(&"player.move.max_speed"), 300.0)
	assert_eq(service.requested_value(&"spawn.quantity_multiplier"), 2)
	assert_eq(service.persistence.recovery_count, 1)


func test_cross_field_validation_rejects_atomically_and_accepts_valid_transaction() -> void:
	var service: RuntimeTweakService = _new_service(SAVE_ROOT + "/cross-fields.json")
	assert_true(bool(service.set_value(
		&"progression.combo.base_grace_seconds", 2.0
	).ok))
	var rejected_bank: Dictionary = service.set_value(
		&"progression.score.bank_base_seconds", 3.0
	)
	assert_false(bool(rejected_bank.ok))
	assert_eq(service.requested_value(&"progression.score.bank_base_seconds"), 1.0)
	var valid_combo: Dictionary = service.set_values({
		&"progression.combo.base_grace_seconds": 5.0,
		&"progression.score.bank_base_seconds": 3.0,
	})
	assert_true(bool(valid_combo.ok))
	assert_eq(service.requested_value(&"progression.score.bank_base_seconds"), 3.0)
	var rejected_facade: Dictionary = service.set_value(
		&"world.facade.damaged_stage_ratio", 0.45
	)
	assert_false(bool(rejected_facade.ok))
	assert_eq(service.requested_value(&"world.facade.damaged_stage_ratio"), 0.65)
	var valid_facade: Dictionary = service.set_values({
		&"world.facade.damaged_stage_ratio": 0.45,
		&"world.facade.support_transfer_ratio": 0.25,
	})
	assert_true(bool(valid_facade.ok))


func _new_service(path: String) -> RuntimeTweakService:
	var service: RuntimeTweakService = RuntimeTweakService.new()
	add_child(service)
	_services.append(service)
	var errors: PackedStringArray = service.setup(RuntimeTweakCatalog.DEFAULT_PATH, path)
	assert_eq(errors, PackedStringArray())
	return service


func _read_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file)
	return JSON.parse_string(file.get_as_text()) as Dictionary


func _write_text(path: String, content: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(content)
	file.close()


func _cleanup_root() -> void:
	var global: String = ProjectSettings.globalize_path(SAVE_ROOT)
	if DirAccess.dir_exists_absolute(global):
		OS.move_to_trash(global)
