class_name PlayerCombatProfileStore
extends Node

signal profile_changed(profile: Dictionary)

const SCHEMA_VERSION: int = 2
const LEGACY_SCHEMA_VERSION: int = 1
const SAVE_PATH: String = "user://player_combat_profile.json"
const MAX_STAT_KEYS: int = 128
const MAX_COUNTER: int = 2_147_483_647
const MAX_HISTORY_ENTRIES: int = 30
const MAX_HISTORY_WEAPONS: int = 16
const MIN_CALLSIGN_LENGTH: int = 3
const MAX_CALLSIGN_LENGTH: int = 20

var save_path: String = SAVE_PATH
var _profile: Dictionary = {}


func setup(path: String = SAVE_PATH) -> void:
	save_path = path
	_profile = _load_profile()


func snapshot() -> Dictionary:
	return _profile.duplicate(true)


func callsign() -> String:
	return String(_profile.get("callsign", _default_callsign()))


func validate_callsign(candidate: String) -> StringName:
	var normalized: String = _normalize_callsign(candidate)
	if normalized.length() < MIN_CALLSIGN_LENGTH:
		return &"too_short"
	if normalized.length() > MAX_CALLSIGN_LENGTH:
		return &"too_long"
	for index: int in range(normalized.length()):
		var codepoint: int = normalized.unicode_at(index)
		var allowed: bool = (
			(codepoint >= 48 and codepoint <= 57)
			or (codepoint >= 65 and codepoint <= 90)
			or (codepoint >= 97 and codepoint <= 122)
			or codepoint in [32, 45, 95]
		)
		if not allowed:
			return &"invalid_characters"
	var moderation: StringName = CallsignModeration.validate(normalized)
	if moderation != &"ok":
		return moderation
	return &"ok"


func set_callsign(candidate: String) -> StringName:
	var normalized: String = _normalize_callsign(candidate)
	var validation: StringName = validate_callsign(normalized)
	if validation != &"ok":
		return validation
	if normalized == callsign():
		return &"ok"
	_profile["callsign"] = normalized
	_profile["updated_unix_time"] = int(Time.get_unix_time_from_system())
	_save_profile()
	profile_changed.emit(snapshot())
	return &"ok"


func history_snapshot(limit: int = MAX_HISTORY_ENTRIES) -> Array[Dictionary]:
	var history: Array[Dictionary] = []
	var stored: Array = _profile.get("run_history", []) as Array
	var first_index: int = maxi(stored.size() - clampi(limit, 0, MAX_HISTORY_ENTRIES), 0)
	for index: int in range(first_index, stored.size()):
		history.append((stored[index] as Dictionary).duplicate(true))
	return history


func local_leaderboard(limit: int = 10) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = history_snapshot()
	ranked.sort_custom(_history_precedes)
	if ranked.size() > limit:
		ranked.resize(clampi(limit, 0, MAX_HISTORY_ENTRIES))
	for index: int in range(ranked.size()):
		ranked[index]["rank"] = index + 1
		ranked[index]["callsign"] = callsign()
		ranked[index]["source"] = "local"
	return ranked


func enrich_and_submit(summary: RunSummarySnapshot) -> RunSummarySnapshot:
	if summary == null:
		return summary
	if not summary.tuning_ranked_eligible:
		return summary.with_career_result({
			"new_combo_record": false,
			"new_score_record": false,
			"career_snapshot": snapshot(),
		})
	var previous_best_score: int = int(_profile.get("best_score", 0))
	var previous_combo_tier: int = int(_profile.get("highest_combo_tier", 0))
	_profile["total_runs"] = _bounded_sum(int(_profile.get("total_runs", 0)), 1)
	if summary.completed:
		_profile["victories"] = _bounded_sum(int(_profile.get("victories", 0)), 1)
	_profile["best_score"] = maxi(previous_best_score, summary.score)
	_profile["highest_combo_tier"] = maxi(previous_combo_tier, summary.highest_combo_tier)
	_profile["best_physical_chain"] = maxi(
		int(_profile.get("best_physical_chain", 0)),
		summary.best_chain
	)
	_profile["peak_multiplier"] = maxi(
		int(_profile.get("peak_multiplier", 1)),
		summary.peak_combo
	)
	_profile["total_enemy_kills"] = _bounded_sum(
		int(_profile.get("total_enemy_kills", 0)),
		summary.total_enemies_defeated
	)
	_profile["lifetime_enemy_kills"] = _merge_counts(
		_profile.get("lifetime_enemy_kills", {}) as Dictionary,
		summary.enemy_kills
	)
	_profile["lifetime_weapon_kills"] = _merge_counts(
		_profile.get("lifetime_weapon_kills", {}) as Dictionary,
		summary.weapon_kills
	)
	_profile["preferred_weapon"] = _preferred_weapon(
		_profile.get("lifetime_weapon_kills", {}) as Dictionary
	)
	_profile["updated_unix_time"] = int(Time.get_unix_time_from_system())
	_append_history(summary)
	_save_profile()
	profile_changed.emit(snapshot())
	return summary.with_career_result({
		"new_combo_record": (
			summary.highest_combo_tier > 0
			and summary.highest_combo_tier > previous_combo_tier
		),
		"new_score_record": summary.score > previous_best_score,
		"career_snapshot": snapshot(),
	})


func leaderboard_candidate(
	summary: RunSummarySnapshot,
	build_revision: String = "development"
) -> Dictionary:
	if summary == null or not summary.tuning_ranked_eligible:
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"build_revision": build_revision.left(64),
		"anonymous_profile_id": String(_profile.get("anonymous_profile_id", "")),
		"callsign": callsign(),
		"career": {
			"total_runs": int(_profile.get("total_runs", 0)),
			"victories": int(_profile.get("victories", 0)),
			"best_score": int(_profile.get("best_score", 0)),
			"highest_combo_tier": int(_profile.get("highest_combo_tier", 0)),
			"best_physical_chain": int(_profile.get("best_physical_chain", 0)),
			"peak_multiplier": int(_profile.get("peak_multiplier", 1)),
			"total_enemy_kills": int(_profile.get("total_enemy_kills", 0)),
			"preferred_weapon": String(_profile.get("preferred_weapon", "UNKNOWN")),
		},
	}


func _load_profile() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return _default_profile()
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return _default_profile()
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return _default_profile()
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return _default_profile()
	return _sanitize_profile(parsed as Dictionary)


func _save_profile() -> bool:
	var save_directory: String = ProjectSettings.globalize_path(save_path.get_base_dir())
	if (
		not DirAccess.dir_exists_absolute(save_directory)
		and DirAccess.make_dir_recursive_absolute(save_directory) != OK
	):
		return false
	var temporary_path: String = save_path + ".tmp"
	var backup_path: String = save_path + ".bak"
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_profile, "", true, true))
	file.close()
	var save_global: String = ProjectSettings.globalize_path(save_path)
	var temporary_global: String = ProjectSettings.globalize_path(temporary_path)
	var backup_global: String = ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_global)
	if FileAccess.file_exists(save_path):
		if DirAccess.rename_absolute(save_global, backup_global) != OK:
			DirAccess.remove_absolute(temporary_global)
			return false
	if DirAccess.rename_absolute(temporary_global, save_global) != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_global, save_global)
		return false
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_global)
	return true


func _sanitize_profile(raw: Dictionary) -> Dictionary:
	var raw_version: int = int(raw.get("schema_version", 0))
	if raw_version not in [LEGACY_SCHEMA_VERSION, SCHEMA_VERSION]:
		return _default_profile()
	var anonymous_id: String = String(raw.get("anonymous_profile_id", "")).strip_edges()
	if anonymous_id.is_empty() or anonymous_id.length() > 64:
		anonymous_id = _new_anonymous_profile_id()
	var sanitized: Dictionary = _default_profile(anonymous_id)
	for key: String in [
		"total_runs", "victories", "best_score", "highest_combo_tier",
		"best_physical_chain", "peak_multiplier", "total_enemy_kills", "updated_unix_time",
	]:
		sanitized[key] = clampi(int(raw.get(key, sanitized[key])), 0, MAX_COUNTER)
	sanitized["peak_multiplier"] = maxi(int(sanitized.peak_multiplier), 1)
	sanitized["lifetime_enemy_kills"] = _sanitize_counts(
		raw.get("lifetime_enemy_kills", {}) as Dictionary
	)
	sanitized["lifetime_weapon_kills"] = _sanitize_counts(
		raw.get("lifetime_weapon_kills", {}) as Dictionary
	)
	var raw_callsign: String = String(raw.get("callsign", ""))
	sanitized["callsign"] = (
		_normalize_callsign(raw_callsign)
		if validate_callsign(raw_callsign) == &"ok"
		else _default_callsign(anonymous_id)
	)
	sanitized["preferred_weapon"] = _preferred_weapon(
		sanitized.lifetime_weapon_kills as Dictionary
	)
	var raw_history: Variant = raw.get("run_history", [])
	if raw_version == SCHEMA_VERSION and raw_history is Array:
		sanitized["run_history"] = _sanitize_history(raw_history as Array)
	return sanitized


func _default_profile(anonymous_id: String = "") -> Dictionary:
	var identity: String = anonymous_id if not anonymous_id.is_empty() else _new_anonymous_profile_id()
	return {
		"schema_version": SCHEMA_VERSION,
		"anonymous_profile_id": identity,
		"callsign": _default_callsign(identity),
		"total_runs": 0,
		"victories": 0,
		"best_score": 0,
		"highest_combo_tier": 0,
		"best_physical_chain": 0,
		"peak_multiplier": 1,
		"total_enemy_kills": 0,
		"lifetime_enemy_kills": {},
		"lifetime_weapon_kills": {},
		"preferred_weapon": "UNKNOWN",
		"run_history": [],
		"updated_unix_time": 0,
	}


func _default_callsign(anonymous_id: String = "") -> String:
	var identity: String = anonymous_id
	if identity.is_empty():
		identity = String(_profile.get("anonymous_profile_id", "0000"))
	var suffix: String = identity.right(4).to_upper()
	return "OBELISK-%s" % suffix.lpad(4, "0")


func _new_anonymous_profile_id() -> String:
	var random_bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	return random_bytes.hex_encode()


func _normalize_callsign(candidate: String) -> String:
	var normalized: String = candidate.strip_edges()
	while normalized.contains("  "):
		normalized = normalized.replace("  ", " ")
	return normalized


func _append_history(summary: RunSummarySnapshot) -> void:
	var history: Array = _profile.get("run_history", []) as Array
	var run_number: int = int(_profile.get("total_runs", 1))
	var finished_time: int = int(Time.get_unix_time_from_system())
	history.append({
		"run_id": "%s-%d-%d" % [
			String(_profile.get("anonymous_profile_id", "")).left(8),
			finished_time,
			run_number,
		],
		"run_number": run_number,
		"finished_unix_time": finished_time,
		"score": maxi(summary.score, 0),
		"highest_combo_tier": maxi(summary.highest_combo_tier, 0),
		"best_physical_chain": maxi(summary.best_chain, 0),
		"peak_multiplier": maxi(summary.peak_combo, 1),
		"completed": summary.completed,
		"preferred_weapon": String(summary.preferred_weapon).left(32),
		"total_enemy_kills": maxi(summary.total_enemies_defeated, 0),
		"weapon_kills": _bounded_history_weapons(summary.weapon_kills),
	})
	while history.size() > MAX_HISTORY_ENTRIES:
		history.pop_front()
	_profile["run_history"] = history


func _sanitize_history(raw: Array) -> Array[Dictionary]:
	var sanitized: Array[Dictionary] = []
	var first_index: int = maxi(raw.size() - MAX_HISTORY_ENTRIES, 0)
	for index: int in range(first_index, raw.size()):
		if not raw[index] is Dictionary:
			continue
		var entry: Dictionary = raw[index] as Dictionary
		var run_id: String = String(entry.get("run_id", "")).left(96)
		if run_id.is_empty():
			continue
		sanitized.append({
			"run_id": run_id,
			"run_number": clampi(int(entry.get("run_number", index + 1)), 1, MAX_COUNTER),
			"finished_unix_time": clampi(
				int(entry.get("finished_unix_time", 0)), 0, MAX_COUNTER
			),
			"score": clampi(int(entry.get("score", 0)), 0, MAX_COUNTER),
			"highest_combo_tier": clampi(
				int(entry.get("highest_combo_tier", 0)), 0, MAX_COUNTER
			),
			"best_physical_chain": clampi(
				int(entry.get("best_physical_chain", 0)), 0, MAX_COUNTER
			),
			"peak_multiplier": clampi(int(entry.get("peak_multiplier", 1)), 1, 255),
			"completed": bool(entry.get("completed", false)),
			"preferred_weapon": String(entry.get("preferred_weapon", "UNKNOWN")).left(32),
			"total_enemy_kills": clampi(
				int(entry.get("total_enemy_kills", 0)), 0, MAX_COUNTER
			),
			"weapon_kills": _bounded_history_weapons(
				entry.get("weapon_kills", {}) as Dictionary
			),
		})
	return sanitized


func _bounded_history_weapons(counts: Dictionary) -> Dictionary:
	var bounded: Dictionary = {}
	for entry: Dictionary in CombatRunTelemetry.ranked_entries(counts, MAX_HISTORY_WEAPONS):
		bounded[String(entry.id)] = clampi(int(entry.count), 0, MAX_COUNTER)
	return bounded


func _preferred_weapon(counts: Dictionary) -> String:
	var ranked: Array[Dictionary] = CombatRunTelemetry.ranked_entries(counts, 1)
	return "UNKNOWN" if ranked.is_empty() else String(ranked[0].id)


func _history_precedes(first: Dictionary, second: Dictionary) -> bool:
	var first_tier: int = int(first.get("highest_combo_tier", 0))
	var second_tier: int = int(second.get("highest_combo_tier", 0))
	if first_tier != second_tier:
		return first_tier > second_tier
	var first_score: int = int(first.get("score", 0))
	var second_score: int = int(second.get("score", 0))
	if first_score != second_score:
		return first_score > second_score
	var first_chain: int = int(first.get("best_physical_chain", 0))
	var second_chain: int = int(second.get("best_physical_chain", 0))
	if first_chain != second_chain:
		return first_chain > second_chain
	var first_time: int = int(first.get("finished_unix_time", 0))
	var second_time: int = int(second.get("finished_unix_time", 0))
	if first_time != second_time:
		return first_time < second_time
	return String(first.get("run_id", "")) < String(second.get("run_id", ""))


func _merge_counts(existing: Dictionary, additions: Dictionary) -> Dictionary:
	var merged: Dictionary = _sanitize_counts(existing)
	for value: Variant in additions:
		var identifier: String = String(value).strip_edges()
		if identifier.is_empty() or (not merged.has(identifier) and merged.size() >= MAX_STAT_KEYS):
			continue
		merged[identifier] = _bounded_sum(
			int(merged.get(identifier, 0)),
			maxi(int(additions[value]), 0)
		)
	return merged


func _sanitize_counts(raw: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	var keys: Array = raw.keys()
	keys.sort_custom(func(first: Variant, second: Variant) -> bool:
		return String(first) < String(second)
	)
	for value: Variant in keys:
		if sanitized.size() >= MAX_STAT_KEYS:
			break
		var identifier: String = String(value).strip_edges()
		var count: int = clampi(int(raw[value]), 0, MAX_COUNTER)
		if identifier.is_empty() or identifier.length() > 64 or count <= 0:
			continue
		sanitized[identifier] = count
	return sanitized


func _string_keyed_counts(counts: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for value: Variant in counts:
		result[String(value)] = maxi(int(counts[value]), 0)
	return result


func _bounded_sum(first: int, second: int) -> int:
	return clampi(first + second, 0, MAX_COUNTER)
