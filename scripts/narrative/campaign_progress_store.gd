# gdlint: disable=max-public-methods
class_name CampaignProgressStore
extends Node

signal dossier_changed(dossier_id: StringName, total: int)
signal evidence_changed(evidence_id: StringName, total: int)
signal evidence_lost(evidence_id: StringName)
signal continuity_changed(generation: int)
signal ending_changed(ending_id: StringName)
signal transaction_committed(transaction_id: StringName, reward_grant_id: StringName)

const SCHEMA_VERSION: int = 2
const DEFAULT_PATH: String = "user://choir_campaign.json"
const ECHO_RESOLUTION_THRESHOLD: int = 20
const FAIL_NONE: StringName = &""
const FAIL_BEFORE_WRITE: StringName = &"BEFORE_WRITE"
const FAIL_AFTER_TEMP_FLUSH: StringName = &"AFTER_TEMP_FLUSH"
const FAIL_BEFORE_RENAME: StringName = &"BEFORE_RENAME"
const FAIL_AFTER_RENAME: StringName = &"AFTER_RENAME"
const FINALE_SNAPSHOT_TRANSACTION_ID: StringName = &"finale:CHOIR_PRIME:eligibility"

var save_path: String = DEFAULT_PATH
var last_error: Error = OK
var save_count: int = 0
var fault_injection: StringName = FAIL_NONE
var _document: Dictionary = {
	"schema_version": SCHEMA_VERSION,
	"sequence": 0,
	"progress": {
		"dossiers": [], "evidence": [], "lost_evidence": [],
		"completed_bosses": [], "seen_endings": [],
		"selected_ending": "", "route_unlock_chunk": 0, "transaction_ids": [],
		"pending_reward_grants": [], "applied_reward_transactions": [],
		"boss_results": {}, "continuity_generation": 0,
	},
}


func setup(path: String = DEFAULT_PATH) -> void:
	save_path = path
	load_progress()


func load_progress() -> bool:
	last_error = OK
	var candidates: Array[Dictionary] = []
	for candidate_path: String in [save_path, temp_path(), backup_path()]:
		var candidate: Dictionary = _load_candidate(candidate_path)
		if not candidate.is_empty():
			candidate["__source_path"] = candidate_path
			candidates.append(candidate)
	if candidates.is_empty():
		if not _any_save_exists():
			_document = _empty_document()
			return true
		_document = _empty_document()
		last_error = ERR_INVALID_DATA
		return false
	candidates.sort_custom(_newer_snapshot)
	var selected: Dictionary = candidates.back()
	var source_path: String = String(selected.get("__source_path", save_path))
	selected.erase("__source_path")
	_document = selected
	if source_path != save_path:
		_recover_selected_candidate(source_path)
	return true


func save_progress() -> bool:
	var next_document: Dictionary = _document.duplicate(true)
	next_document["sequence"] = int(next_document.get("sequence", 0)) + 1
	return _commit_document(next_document)


func commit_boss_transaction(payload: Dictionary) -> bool:
	var transaction_id: StringName = StringName(payload.get("transaction_id", &""))
	if transaction_id.is_empty() or has_transaction(transaction_id):
		return false
	var next_document: Dictionary = _document.duplicate(true)
	var progress: Dictionary = next_document["progress"] as Dictionary
	var completed_bosses: Array = progress.get("completed_bosses", []) as Array
	_append_unique(completed_bosses, String(payload.get("boss_id", "")))
	progress["completed_bosses"] = completed_bosses
	for dossier_id: Variant in payload.get("dossier_ids", []):
		_append_valid_dossier(progress, StringName(dossier_id))
	for evidence_id: Variant in payload.get("evidence_ids", []):
		_append_valid_evidence(progress, StringName(evidence_id))
	for evidence_id: Variant in payload.get("lost_evidence_ids", []):
		_append_valid_evidence_loss(progress, StringName(evidence_id))
	var boss_result: Dictionary = payload.get("boss_result", {})
	var boss_id: String = String(payload.get("boss_id", ""))
	if not boss_id.is_empty() and not boss_result.is_empty():
		var results: Dictionary = progress.get("boss_results", {}) as Dictionary
		results[boss_id] = boss_result.duplicate(true)
		progress["boss_results"] = results
	var ending_id: String = String(payload.get("ending_id", ""))
	if not ending_id.is_empty():
		progress["selected_ending"] = ending_id
		var seen_endings: Array = progress.get("seen_endings", []) as Array
		_append_unique(seen_endings, ending_id)
		progress["seen_endings"] = seen_endings
	var unlock_chunk: int = int(payload.get("unlock_chunk", -1))
	if unlock_chunk >= 0:
		progress["route_unlock_chunk"] = maxi(
			int(progress.get("route_unlock_chunk", 0)),
			unlock_chunk
		)
	var transactions: Array = progress.get("transaction_ids", []) as Array
	transactions.append(String(transaction_id))
	progress["transaction_ids"] = transactions
	var reward_grant_id: StringName = StringName(payload.get("reward_grant_id", &""))
	if not reward_grant_id.is_empty():
		var pending: Array = progress.get("pending_reward_grants", []) as Array
		_append_unique(pending, String(reward_grant_id))
		progress["pending_reward_grants"] = pending
	next_document["progress"] = progress
	next_document["sequence"] = int(next_document.get("sequence", 0)) + 1
	if not _commit_document(next_document):
		return false
	_emit_transaction_changes(payload)
	transaction_committed.emit(transaction_id, reward_grant_id)
	return true


func commit_finale_snapshot(
	snapshot: FinaleEligibilitySnapshot,
	crown_transaction_id: StringName
) -> bool:
	if snapshot == null or crown_transaction_id.is_empty():
		return false
	if not has_transaction(crown_transaction_id):
		return false
	if has_transaction(FINALE_SNAPSHOT_TRANSACTION_ID):
		return true
	var next_document: Dictionary = _document.duplicate(true)
	var progress: Dictionary = next_document["progress"] as Dictionary
	progress["finale_snapshot"] = snapshot.as_dictionary()
	progress["finale_crown_transaction_id"] = String(crown_transaction_id)
	var transactions: Array = progress.get("transaction_ids", []) as Array
	transactions.append(String(FINALE_SNAPSHOT_TRANSACTION_ID))
	progress["transaction_ids"] = transactions
	next_document["progress"] = progress
	next_document["sequence"] = int(next_document.get("sequence", 0)) + 1
	return _commit_document(next_document)


func finale_snapshot() -> FinaleEligibilitySnapshot:
	var progress: Dictionary = _document.get("progress", {}) as Dictionary
	var data: Dictionary = progress.get("finale_snapshot", {})
	return FinaleEligibilitySnapshot.from_dictionary(data) if not data.is_empty() else null


func commit_finale_ending_transaction(
	outcome: int,
	boss_result: Dictionary,
	crown_transaction_id: StringName
) -> bool:
	if not BossOutcome.is_valid(outcome) or not has_transaction(crown_transaction_id):
		return false
	if not has_transaction(FINALE_SNAPSHOT_TRANSACTION_ID):
		return false
	var ending_id: StringName = BossOutcome.id_for(outcome)
	var transaction_id: StringName = StringName("finale:CHOIR_PRIME:%s" % ending_id)
	if has_transaction(transaction_id):
		return true
	var result: Dictionary = boss_result.duplicate(true)
	result["ending_id"] = ending_id
	result["crown_transaction_id"] = crown_transaction_id
	result["finale_snapshot_transaction_id"] = FINALE_SNAPSHOT_TRANSACTION_ID
	return commit_boss_transaction({
		"transaction_id": transaction_id,
		"boss_id": &"CHOIR_PRIME",
		"ending_id": ending_id,
		"boss_result": result,
		"reward_grant_id": &"boss:CHOIR_PRIME:ending_reward",
	})


func consume_reward_grant(reward_grant_id: StringName) -> bool:
	if reward_grant_id.is_empty() or reward_grant_applied(reward_grant_id):
		return false
	var progress: Dictionary = _document["progress"] as Dictionary
	var pending: Array = progress.get("pending_reward_grants", []) as Array
	if not pending.has(String(reward_grant_id)):
		return false
	var next_document: Dictionary = _document.duplicate(true)
	var next_progress: Dictionary = next_document["progress"] as Dictionary
	var applied: Array = next_progress.get("applied_reward_transactions", []) as Array
	applied.append(String(reward_grant_id))
	next_progress["applied_reward_transactions"] = applied
	var next_pending: Array = next_progress.get("pending_reward_grants", []) as Array
	next_pending.erase(String(reward_grant_id))
	next_progress["pending_reward_grants"] = next_pending
	next_document["progress"] = next_progress
	next_document["sequence"] = int(next_document.get("sequence", 0)) + 1
	return _commit_document(next_document)


func collect_dossier(dossier_id: StringName) -> bool:
	var normalized: StringName = DossierCatalog.normalize_dossier_id(dossier_id)
	if not DossierCatalog.has_dossier(normalized) or has_dossier(normalized):
		return false
	var transaction_id: StringName = StringName("dossier:%s" % normalized)
	var next_document: Dictionary = _document.duplicate(true)
	var progress: Dictionary = next_document["progress"] as Dictionary
	_append_valid_dossier(progress, normalized)
	var transactions: Array = progress.get("transaction_ids", []) as Array
	transactions.append(String(transaction_id))
	progress["transaction_ids"] = transactions
	next_document["progress"] = progress
	next_document["sequence"] = int(next_document.get("sequence", 0)) + 1
	if not _commit_document(next_document):
		return false
	dossier_changed.emit(normalized, dossier_count())
	return true


func preserve_evidence(evidence_id: StringName) -> bool:
	if evidence_id.is_empty() or has_evidence(evidence_id):
		return false
	var result: bool = commit_boss_transaction({
		"transaction_id": StringName("evidence:%s" % evidence_id),
		"evidence_ids": [evidence_id],
	})
	return result


func record_evidence_loss(evidence_id: StringName) -> bool:
	if not DossierCatalog.is_evidence_flag(evidence_id) or has_evidence(evidence_id):
		return false
	var progress: Dictionary = _document["progress"] as Dictionary
	var losses: Array = progress.get("lost_evidence", []) as Array
	if losses.has(String(evidence_id)):
		return false
	var next_document: Dictionary = _document.duplicate(true)
	var next_progress: Dictionary = next_document["progress"] as Dictionary
	var next_losses: Array = next_progress.get("lost_evidence", []) as Array
	next_losses.append(String(evidence_id))
	next_progress["lost_evidence"] = next_losses
	next_document["progress"] = next_progress
	next_document["sequence"] = int(next_document.get("sequence", 0)) + 1
	if not _commit_document(next_document):
		return false
	evidence_lost.emit(evidence_id)
	return true


func recover_evidence_from_elite(evidence_id: StringName, drop_id: StringName) -> bool:
	if (
		not DossierCatalog.is_evidence_flag(evidence_id)
		or evidence_id == &"CROWN"
		or has_evidence(evidence_id)
		or not lost_evidence_ids().has(String(evidence_id))
	):
		return false
	return commit_boss_transaction({
		"transaction_id": StringName("elite_drop:%s" % drop_id),
		"evidence_ids": [evidence_id],
	})


func next_recoverable_evidence(elite_sequence: int) -> StringName:
	var recoverable: PackedStringArray = PackedStringArray()
	for evidence_id: StringName in DossierCatalog.EVIDENCE_FLAGS:
		if (
			evidence_id != &"CROWN"
			and not has_evidence(evidence_id)
			and lost_evidence_ids().has(String(evidence_id))
		):
			recoverable.append(String(evidence_id))
	if recoverable.is_empty():
		return &""
	recoverable.sort()
	return StringName(recoverable[posmod(elite_sequence, recoverable.size())])


func increment_continuity() -> int:
	var next_document: Dictionary = _document.duplicate(true)
	var progress: Dictionary = next_document["progress"] as Dictionary
	progress["continuity_generation"] = int(progress.get("continuity_generation", 0)) + 1
	next_document["progress"] = progress
	next_document["sequence"] = int(next_document.get("sequence", 0)) + 1
	if not _commit_document(next_document):
		return continuity_generation()
	continuity_changed.emit(continuity_generation())
	return continuity_generation()


func mark_ending_seen(ending_id: StringName) -> bool:
	if ending_id.is_empty() or has_ending(ending_id):
		return false
	var result: bool = commit_boss_transaction({
		"transaction_id": StringName("ending:%s" % ending_id),
		"ending_id": ending_id,
	})
	return result


func has_dossier(dossier_id: StringName) -> bool:
	return collected_dossier_ids().has(String(DossierCatalog.normalize_dossier_id(dossier_id)))


func has_evidence(evidence_id: StringName) -> bool:
	return evidence_ids().has(String(evidence_id))


func has_ending(ending_id: StringName) -> bool:
	return _progress_ids("seen_endings").has(String(ending_id))


func has_transaction(transaction_id: StringName) -> bool:
	return _progress_ids("transaction_ids").has(String(transaction_id))


func reward_grant_applied(reward_grant_id: StringName) -> bool:
	return _progress_ids("applied_reward_transactions").has(String(reward_grant_id))


func pending_reward_grants() -> PackedStringArray:
	return _progress_ids("pending_reward_grants")


func dossier_count() -> int:
	return collected_dossier_ids().size()


func district_dossier_count(district_id: StringName) -> int:
	var count: int = 0
	for definition: DossierDefinition in DossierCatalog.district_definitions(district_id):
		if has_dossier(definition.dossier_id):
			count += 1
	return count


func evidence_count() -> int:
	return evidence_ids().size()


func continuity_generation() -> int:
	return int((_document.get("progress", {}) as Dictionary).get("continuity_generation", 0))


func collected_dossier_ids() -> PackedStringArray:
	return _progress_ids("dossiers")


func evidence_ids() -> PackedStringArray:
	return _progress_ids("evidence")


func lost_evidence_ids() -> PackedStringArray:
	return _progress_ids("lost_evidence")


func completed_boss_ids() -> PackedStringArray:
	return _progress_ids("completed_bosses")


func echo7_resolved() -> bool:
	return dossier_count() >= ECHO_RESOLUTION_THRESHOLD and has_evidence(&"CROWN")


func finale_eligible() -> bool:
	return dossier_count() >= ECHO_RESOLUTION_THRESHOLD and evidence_count() == 5


func snapshot() -> Dictionary:
	var progress: Dictionary = _document.get("progress", {}) as Dictionary
	return {
		"schema_version": SCHEMA_VERSION,
		"sequence": int(_document.get("sequence", 0)),
		"dossiers": collected_dossier_ids(),
		"dossier_count": dossier_count(),
		"evidence": evidence_ids(),
		"evidence_count": evidence_count(),
		"lost_evidence": lost_evidence_ids(),
		"continuity_generation": continuity_generation(),
		"seen_endings": _progress_ids("seen_endings"),
		"completed_bosses": completed_boss_ids(),
		"selected_ending": String(progress.get("selected_ending", "")),
		"route_unlock_chunk": int(progress.get("route_unlock_chunk", 0)),
		"transaction_ids": _progress_ids("transaction_ids"),
		"pending_reward_grants": pending_reward_grants(),
		"applied_reward_transactions": _progress_ids("applied_reward_transactions"),
		"boss_results": progress.get("boss_results", {}).duplicate(true),
		"finale_snapshot": progress.get("finale_snapshot", {}).duplicate(true),
		"finale_crown_transaction_id": String(
			progress.get("finale_crown_transaction_id", "")
		),
		"echo7_resolved": echo7_resolved(),
		"finale_eligible": finale_eligible(),
	}


func reset_memory() -> void:
	_document = _empty_document()


func temp_path() -> String:
	return save_path + ".tmp"


func backup_path() -> String:
	return save_path + ".bak"


# gdlint: disable=max-returns
func _commit_document(next_document: Dictionary) -> bool:
	last_error = OK
	if fault_injection == FAIL_BEFORE_WRITE:
		last_error = ERR_CANT_CREATE
		return false
	var serialized: String = _serialize_document(next_document)
	var file: FileAccess = FileAccess.open(temp_path(), FileAccess.WRITE)
	if file == null:
		last_error = FileAccess.get_open_error()
		return false
	file.store_string(serialized)
	file.flush()
	file.close()
	if fault_injection == FAIL_AFTER_TEMP_FLUSH:
		last_error = ERR_BUSY
		return false
	if _load_candidate(temp_path()).is_empty():
		last_error = ERR_INVALID_DATA
		return false
	if fault_injection == FAIL_BEFORE_RENAME:
		last_error = ERR_BUSY
		return false
	var global_path: String = ProjectSettings.globalize_path(save_path)
	var global_temp: String = ProjectSettings.globalize_path(temp_path())
	var global_backup: String = ProjectSettings.globalize_path(backup_path())
	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(backup_path()):
			DirAccess.remove_absolute(global_backup)
		last_error = DirAccess.rename_absolute(global_path, global_backup)
		if last_error != OK:
			return false
	last_error = DirAccess.rename_absolute(global_temp, global_path)
	if last_error != OK:
		if FileAccess.file_exists(backup_path()) and not FileAccess.file_exists(save_path):
			DirAccess.rename_absolute(global_backup, global_path)
		return false
	_document = next_document
	save_count += 1
	if fault_injection == FAIL_AFTER_RENAME:
		last_error = ERR_BUSY
		return false
	return true


func _load_candidate(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	if not text.strip_edges().begins_with("{"):
		return _load_legacy_config(path)
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return {}
	var envelope: Dictionary = parsed as Dictionary
	if not envelope.has("snapshot_json") or not envelope.has("checksum"):
		return {}
	var snapshot_json: String = String(envelope["snapshot_json"])
	if _checksum(snapshot_json) != String(envelope["checksum"]):
		return {}
	var snapshot_parser: JSON = JSON.new()
	if snapshot_parser.parse(snapshot_json) != OK:
		return {}
	var snapshot_value: Variant = snapshot_parser.data
	if not snapshot_value is Dictionary:
		return {}
	var candidate: Dictionary = snapshot_value as Dictionary
	return _migrate_document(candidate)


func _load_legacy_config(path: String) -> Dictionary:
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		return {}
	if not config.has_section("progress") and not config.has_section("ending"):
		return {}
	var schema: int = int(config.get_value("meta", "schema_version", 0))
	if schema < 0 or schema > 1:
		return {}
	var document: Dictionary = _empty_document()
	var progress: Dictionary = document["progress"] as Dictionary
	for dossier_id: String in _coerce_ids(
		config.get_value("progress", "collected_dossiers", PackedStringArray())
	):
		_append_valid_dossier(progress, StringName(dossier_id))
	for evidence_id: String in _coerce_ids(
		config.get_value("progress", "preserved_evidence", PackedStringArray())
	):
		_append_valid_evidence(progress, StringName(evidence_id))
	progress["continuity_generation"] = maxi(
		int(config.get_value("progress", "continuity_generation", 0)),
		0
	)
	progress["seen_endings"] = Array(_coerce_ids(
		config.get_value("ending", "seen_endings", PackedStringArray())
	))
	document["progress"] = progress
	return document


func _migrate_document(candidate: Dictionary) -> Dictionary:
	var schema: int = int(candidate.get("schema_version", 0))
	if schema < 0 or schema > SCHEMA_VERSION:
		return {}
	var migrated: Dictionary = candidate.duplicate(true)
	if schema <= 1:
		var legacy_progress: Dictionary = migrated.get("progress", {}) as Dictionary
		legacy_progress["dossiers"] = legacy_progress.get(
			"dossiers", legacy_progress.get("collected_dossiers", [])
		)
		legacy_progress["evidence"] = legacy_progress.get(
			"evidence", legacy_progress.get("preserved_evidence", [])
		)
		migrated["progress"] = legacy_progress
	migrated["schema_version"] = SCHEMA_VERSION
	migrated["sequence"] = maxi(int(migrated.get("sequence", 0)), 0)
	var normalized: Dictionary = _empty_progress()
	var source: Dictionary = migrated.get("progress", {}) as Dictionary
	for key: Variant in source:
		if String(key) == "unlocked_reveals":
			continue
		normalized[key] = source[key]
	var valid_dossiers: Array = []
	for dossier_id: String in _coerce_ids(normalized.get("dossiers", [])):
		var normalized_id: StringName = DossierCatalog.normalize_dossier_id(dossier_id)
		if DossierCatalog.has_dossier(normalized_id):
			_append_unique(valid_dossiers, String(normalized_id))
	normalized["dossiers"] = valid_dossiers
	var valid_evidence: Array = []
	for evidence_id: String in _coerce_ids(normalized.get("evidence", [])):
		if DossierCatalog.is_evidence_flag(evidence_id):
			_append_unique(valid_evidence, evidence_id)
	normalized["evidence"] = valid_evidence
	migrated["progress"] = normalized
	return migrated


func _serialize_document(document: Dictionary) -> String:
	var snapshot_json: String = _canonical_json(document)
	return JSON.stringify({
		"checksum": _checksum(snapshot_json),
		"snapshot_json": snapshot_json,
	})


func _canonical_json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _checksum(value: String) -> String:
	return value.sha256_text()


func _empty_document() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"sequence": 0,
		"progress": _empty_progress(),
	}


func _empty_progress() -> Dictionary:
	return {
		"dossiers": [],
		"evidence": [],
		"lost_evidence": [],
		"completed_bosses": [],
		"seen_endings": [],
		"selected_ending": "",
		"route_unlock_chunk": 0,
		"transaction_ids": [],
		"pending_reward_grants": [],
		"applied_reward_transactions": [],
		"boss_results": {},
		"continuity_generation": 0,
		"finale_snapshot": {},
		"finale_crown_transaction_id": "",
	}


func _append_valid_dossier(progress: Dictionary, dossier_id: StringName) -> void:
	var normalized: StringName = DossierCatalog.normalize_dossier_id(dossier_id)
	if not DossierCatalog.has_dossier(normalized):
		return
	var dossiers: Array = progress.get("dossiers", []) as Array
	_append_unique(dossiers, String(normalized))
	progress["dossiers"] = dossiers


func _append_valid_evidence_loss(progress: Dictionary, evidence_id: StringName) -> void:
	if not DossierCatalog.is_evidence_flag(evidence_id):
		return
	var evidence: Array = progress.get("evidence", []) as Array
	if evidence.has(String(evidence_id)):
		return
	var lost: Array = progress.get("lost_evidence", []) as Array
	_append_unique(lost, String(evidence_id))
	progress["lost_evidence"] = lost


func _append_valid_evidence(progress: Dictionary, evidence_id: StringName) -> void:
	if not DossierCatalog.is_evidence_flag(evidence_id):
		return
	var evidence: Array = progress.get("evidence", []) as Array
	_append_unique(evidence, String(evidence_id))
	progress["evidence"] = evidence
	var lost: Array = progress.get("lost_evidence", []) as Array
	lost.erase(String(evidence_id))
	progress["lost_evidence"] = lost


func _append_unique(target: Array, value: String) -> void:
	if not value.is_empty() and not target.has(value):
		target.append(value)
		target.sort()


func _progress_ids(key: String) -> PackedStringArray:
	var progress: Dictionary = _document.get("progress", {}) as Dictionary
	return _coerce_ids(progress.get(key, []))


func _coerce_ids(value: Variant) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		ids = value as PackedStringArray
	elif value is Array:
		for raw_id: Variant in value as Array:
			if raw_id is String or raw_id is StringName:
				ids.append(String(raw_id))
	ids.sort()
	return ids


func _emit_transaction_changes(payload: Dictionary) -> void:
	for dossier_id: Variant in payload.get("dossier_ids", []):
		var normalized: StringName = DossierCatalog.normalize_dossier_id(dossier_id)
		dossier_changed.emit(normalized, dossier_count())
	for evidence_id: Variant in payload.get("evidence_ids", []):
		evidence_changed.emit(StringName(evidence_id), evidence_count())
	var ending_id: StringName = StringName(payload.get("ending_id", &""))
	if not ending_id.is_empty():
		ending_changed.emit(ending_id)


func _any_save_exists() -> bool:
	return (
		FileAccess.file_exists(save_path)
		or FileAccess.file_exists(temp_path())
		or FileAccess.file_exists(backup_path())
	)


func _recover_selected_candidate(source_path: String) -> void:
	var source_global: String = ProjectSettings.globalize_path(source_path)
	var save_global: String = ProjectSettings.globalize_path(save_path)
	if source_path == temp_path():
		if FileAccess.file_exists(save_path):
			var backup_global: String = ProjectSettings.globalize_path(backup_path())
			if FileAccess.file_exists(backup_path()):
				DirAccess.remove_absolute(backup_global)
			DirAccess.rename_absolute(save_global, backup_global)
		DirAccess.rename_absolute(source_global, save_global)
	elif source_path == backup_path():
		DirAccess.copy_absolute(source_global, save_global)


static func _newer_snapshot(first: Dictionary, second: Dictionary) -> bool:
	return int(first.get("sequence", 0)) < int(second.get("sequence", 0))
