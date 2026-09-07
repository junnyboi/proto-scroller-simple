class_name RunSummarySnapshot
extends RefCounted

var run_id: String:
	get:
		return _run_id
var stage_id: StringName:
	get:
		return _stage_id
var duration_seconds: float:
	get:
		return _duration_seconds
var finished_unix_time: int:
	get:
		return _finished_unix_time
var tutorial_run: bool:
	get:
		return _tutorial_run
var debug_run: bool:
	get:
		return _debug_run

var score: int:
	get:
		return _score
var peak_combo: int:
	get:
		return _peak_combo
var best_chain: int:
	get:
		return _best_chain
var waves_cleared: int:
	get:
		return _waves_cleared
var overdrive_activations: int:
	get:
		return _overdrive_activations
var rare_events: Dictionary[StringName, int]:
	get:
		return _rare_events.duplicate()
var grade: StringName:
	get:
		return _grade
var mastery_points: int:
	get:
		return _mastery_points
var strongest_metric: StringName:
	get:
		return _strongest_metric
var weakest_metric: StringName:
	get:
		return _weakest_metric
var retry_objective: String:
	get:
		return _retry_objective
var heavy_hits: int:
	get:
		return _heavy_hits
var unique_actions: int:
	get:
		return _unique_actions
var causal_depth: int:
	get:
		return _causal_depth
var directive_path: StringName:
	get:
		return _directive_path
var boss_result: StringName:
	get:
		return _boss_result
var contract_result: StringName:
	get:
		return _contract_result
var run_seed: int:
	get:
		return _run_seed
var cycle_count: int:
	get:
		return _cycle_count
var ending_id: StringName:
	get:
		return _ending_id
var completed: bool:
	get:
		return _completed
var defeat_source_id: StringName:
	get:
		return _defeat_source_id
var highest_combo_tier: int:
	get:
		return _highest_combo_tier
var total_enemies_defeated: int:
	get:
		return _total_enemies_defeated
var unique_enemy_types: int:
	get:
		return _unique_enemy_types
var enemy_kills: Dictionary:
	get:
		return _enemy_kills.duplicate()
var enemy_family_kills: Dictionary:
	get:
		return _enemy_family_kills.duplicate()
var weapon_kills: Dictionary:
	get:
		return _weapon_kills.duplicate()
var preferred_weapon: StringName:
	get:
		return _preferred_weapon
var preferred_weapon_kills: int:
	get:
		return _preferred_weapon_kills
var new_combo_record: bool:
	get:
		return _new_combo_record
var new_score_record: bool:
	get:
		return _new_score_record
var career_snapshot: Dictionary:
	get:
		return _career_snapshot.duplicate(true)
var tuning_status: StringName:
	get:
		return &"PRACTICE" if _tuning_status == &"BASELINE" and (_debug_run or _tutorial_run) else _tuning_status
var tuning_ranked_eligible: bool:
	get:
		return _tuning_ranked_eligible and not _debug_run and not _tutorial_run
var tuning_configuration_hash: String:
	get:
		return _tuning_configuration_hash
var tuning_catalog_revision: String:
	get:
		return _tuning_catalog_revision
var tuning_reasons: PackedStringArray:
	get:
		return _tuning_reasons.duplicate()

var _run_id: String
var _stage_id: StringName
var _duration_seconds: float
var _finished_unix_time: int
var _tutorial_run: bool
var _debug_run: bool

var _score: int
var _peak_combo: int
var _best_chain: int
var _waves_cleared: int
var _overdrive_activations: int
var _rare_events: Dictionary[StringName, int]
var _grade: StringName
var _mastery_points: int
var _strongest_metric: StringName
var _weakest_metric: StringName
var _retry_objective: String
var _heavy_hits: int
var _unique_actions: int
var _causal_depth: int
var _directive_path: StringName
var _boss_result: StringName
var _contract_result: StringName
var _run_seed: int
var _cycle_count: int
var _ending_id: StringName
var _completed: bool
var _defeat_source_id: StringName
var _highest_combo_tier: int
var _total_enemies_defeated: int
var _unique_enemy_types: int
var _enemy_kills: Dictionary
var _enemy_family_kills: Dictionary
var _weapon_kills: Dictionary
var _preferred_weapon: StringName
var _preferred_weapon_kills: int
var _new_combo_record: bool
var _new_score_record: bool
var _career_snapshot: Dictionary
var _tuning_status: StringName
var _tuning_ranked_eligible: bool
var _tuning_configuration_hash: String
var _tuning_catalog_revision: String
var _tuning_reasons: PackedStringArray


func _init(
	p_score: int,
	p_peak_combo: int,
	p_best_chain: int,
	p_waves_cleared: int,
	p_overdrive_activations: int,
	p_rare_events: Dictionary[StringName, int],
	metrics: Dictionary = {}
) -> void:
	_score = clampi(p_score, 0, RunScore.MAX_SCORE)
	_run_id = String(metrics.get("run_id", ""))
	_stage_id = StringName(metrics.get("stage_id", &"BUSINESS_ACT_1"))
	_duration_seconds = float(metrics.get("duration_seconds", 0.0))
	_finished_unix_time = int(metrics.get("finished_unix_time", 0))
	_tutorial_run = bool(metrics.get("tutorial_run", false))
	_debug_run = bool(metrics.get("debug_run", false))

	_peak_combo = p_peak_combo
	_best_chain = p_best_chain
	_waves_cleared = p_waves_cleared
	_overdrive_activations = p_overdrive_activations
	_rare_events = p_rare_events.duplicate()
	_grade = metrics.get("grade", &"D") as StringName
	_mastery_points = int(metrics.get("mastery_points", 0))
	_strongest_metric = metrics.get("strongest", &"DISTRICT") as StringName
	_weakest_metric = metrics.get("weakest", &"DISTRICT") as StringName
	_retry_objective = String(metrics.get("objective", "summary.retry.reach_next_act"))
	_heavy_hits = int(metrics.get("heavy_hits", 0))
	_unique_actions = int(metrics.get("unique_actions", 0))
	_causal_depth = int(metrics.get("causal_depth", 0))
	_directive_path = metrics.get("directive_path", &"NONE") as StringName
	_boss_result = metrics.get("boss_result", &"UNRESOLVED") as StringName
	_contract_result = metrics.get("contract_result", &"NONE") as StringName
	_run_seed = int(metrics.get("run_seed", 0))
	_cycle_count = int(metrics.get("cycle_count", 1))
	_ending_id = metrics.get("ending_id", &"NONE") as StringName
	_completed = bool(metrics.get("completed", false))
	_defeat_source_id = metrics.get("defeat_source_id", DefeatSourceResolver.UNKNOWN) as StringName
	_highest_combo_tier = maxi(int(metrics.get("highest_combo_tier", 0)), 0)
	_total_enemies_defeated = maxi(int(metrics.get("total_enemies_defeated", 0)), 0)
	_enemy_kills = _copy_counts(metrics.get("enemy_kills", {}) as Dictionary)
	_enemy_family_kills = _copy_counts(metrics.get("enemy_family_kills", {}) as Dictionary)
	_weapon_kills = _copy_counts(metrics.get("weapon_kills", {}) as Dictionary)
	_unique_enemy_types = int(metrics.get("unique_enemy_types", _enemy_kills.size()))
	_preferred_weapon = metrics.get("preferred_weapon", &"UNKNOWN") as StringName
	_preferred_weapon_kills = maxi(int(metrics.get("preferred_weapon_kills", 0)), 0)
	_new_combo_record = bool(metrics.get("new_combo_record", false))
	_new_score_record = bool(metrics.get("new_score_record", false))
	_career_snapshot = (metrics.get("career_snapshot", {}) as Dictionary).duplicate(true)
	_tuning_status = metrics.get("tuning_status", &"BASELINE") as StringName
	_tuning_ranked_eligible = bool(metrics.get("tuning_ranked_eligible", true))
	_tuning_configuration_hash = String(metrics.get("tuning_configuration_hash", ""))
	_tuning_catalog_revision = String(metrics.get("tuning_catalog_revision", ""))
	_tuning_reasons = PackedStringArray(metrics.get("tuning_reasons", PackedStringArray()))


func with_career_result(result: Dictionary) -> RunSummarySnapshot:
	var metrics: Dictionary = _metric_snapshot()
	metrics["new_combo_record"] = bool(result.get("new_combo_record", false))
	metrics["new_score_record"] = bool(result.get("new_score_record", false))
	metrics["career_snapshot"] = (
		result.get("career_snapshot", {}) as Dictionary
	).duplicate(true)
	return RunSummarySnapshot.new(
		_score,
		_peak_combo,
		_best_chain,
		_waves_cleared,
		_overdrive_activations,
		_rare_events,
		metrics
	)


func with_tuning_provenance(provenance: Dictionary) -> RunSummarySnapshot:
	var metrics: Dictionary = _metric_snapshot()
	metrics["tuning_status"] = provenance.get("status", &"BASELINE")
	metrics["tuning_ranked_eligible"] = bool(provenance.get("ranked_eligible", true))
	metrics["tuning_configuration_hash"] = String(provenance.get("configuration_hash", ""))
	metrics["tuning_catalog_revision"] = String(provenance.get("catalog_revision", ""))
	metrics["tuning_reasons"] = PackedStringArray(provenance.get("reasons", PackedStringArray()))
	return RunSummarySnapshot.new(
		_score,
		_peak_combo,
		_best_chain,
		_waves_cleared,
		_overdrive_activations,
		_rare_events,
		metrics
	)


func _metric_snapshot() -> Dictionary:
	return {
		"run_id": _run_id,
		"stage_id": _stage_id,
		"duration_seconds": _duration_seconds,
		"finished_unix_time": _finished_unix_time,
		"tutorial_run": _tutorial_run,
		"debug_run": _debug_run,

		"grade": _grade,
		"mastery_points": _mastery_points,
		"strongest": _strongest_metric,
		"weakest": _weakest_metric,
		"objective": _retry_objective,
		"heavy_hits": _heavy_hits,
		"unique_actions": _unique_actions,
		"causal_depth": _causal_depth,
		"directive_path": _directive_path,
		"boss_result": _boss_result,
		"contract_result": _contract_result,
		"run_seed": _run_seed,
		"cycle_count": _cycle_count,
		"ending_id": _ending_id,
		"completed": _completed,
		"defeat_source_id": _defeat_source_id,
		"highest_combo_tier": _highest_combo_tier,
		"total_enemies_defeated": _total_enemies_defeated,
		"unique_enemy_types": _unique_enemy_types,
		"enemy_kills": _enemy_kills.duplicate(),
		"enemy_family_kills": _enemy_family_kills.duplicate(),
		"weapon_kills": _weapon_kills.duplicate(),
		"preferred_weapon": _preferred_weapon,
		"preferred_weapon_kills": _preferred_weapon_kills,
		"new_combo_record": _new_combo_record,
		"new_score_record": _new_score_record,
		"career_snapshot": _career_snapshot.duplicate(true),
		"tuning_status": _tuning_status,
		"tuning_ranked_eligible": _tuning_ranked_eligible,
		"tuning_configuration_hash": _tuning_configuration_hash,
		"tuning_catalog_revision": _tuning_catalog_revision,
		"tuning_reasons": _tuning_reasons.duplicate(),
	}


static func _copy_counts(source: Dictionary) -> Dictionary:
	var copy: Dictionary = {}
	for value: Variant in source:
		var identifier: StringName = StringName(value)
		var count: int = maxi(int(source[value]), 0)
		if not identifier.is_empty() and count > 0:
			copy[identifier] = count
	return copy
