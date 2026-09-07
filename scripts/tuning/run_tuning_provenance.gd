class_name RunTuningProvenance
extends RefCounted

const BASELINE: StringName = &"BASELINE"
const TUNED: StringName = &"TUNED"
const SANDBOX: StringName = &"SANDBOX"

var status: StringName = BASELINE
var run_seed: int = 0
var configuration_hash: String = ""
var catalog_revision: String = ""
var reasons: PackedStringArray = []


func start_run(seed: int, hash_value: String, revision: String) -> void:
	status = BASELINE
	run_seed = seed
	configuration_hash = hash_value
	catalog_revision = revision
	reasons.clear()


func mark_tuned(reason: StringName) -> void:
	if status == SANDBOX:
		_append_reason(reason)
		return
	status = TUNED
	_append_reason(reason)


func mark_sandbox(reason: StringName) -> void:
	status = SANDBOX
	_append_reason(reason)


func ranked_eligible() -> bool:
	return status == BASELINE


func snapshot() -> Dictionary:
	return {
		"status": status,
		"ranked_eligible": ranked_eligible(),
		"run_seed": run_seed,
		"configuration_hash": configuration_hash,
		"catalog_revision": catalog_revision,
		"reasons": reasons.duplicate(),
	}


func _append_reason(reason: StringName) -> void:
	var text: String = String(reason)
	if not text.is_empty() and text not in reasons:
		reasons.append(text)
