class_name RampageSession
extends Node

var event_hub: GameplayEventHub
var run_score: RunScore
var combo_tracker: ComboTracker
var momentum_meter: MomentumMeter
var rare_event_tracker: RareEventTracker
var causal_chain_tracker: CausalChainTracker = CausalChainTracker.new()
var combat_telemetry: CombatRunTelemetry = CombatRunTelemetry.new()
var frozen_summary: RunSummarySnapshot
var heavy_hit_count: int = 0
var _unique_action_tags: Dictionary[StringName, bool] = {}


func _init() -> void:
	event_hub = GameplayEventHub.new()
	event_hub.name = &"GameplayEventHub"
	add_child(event_hub)
	run_score = RunScore.new()
	run_score.name = &"RunScore"
	add_child(run_score)
	combo_tracker = ComboTracker.new()
	combo_tracker.name = &"ComboTracker"
	add_child(combo_tracker)
	momentum_meter = MomentumMeter.new()
	momentum_meter.name = &"MomentumMeter"
	add_child(momentum_meter)
	rare_event_tracker = RareEventTracker.new()
	rare_event_tracker.name = &"RareEventTracker"
	add_child(rare_event_tracker)


func publish(event: GameplayEvent) -> bool:
	if not event_hub.accept(event):
		return false
	var score_multiplier: int = 1
	if combo_tracker.register_event(event):
		score_multiplier = combo_tracker.current_multiplier
	combat_telemetry.register_accepted_event(
		event,
		CombatRunTelemetry.authored_tier_for_progress_units(
			combo_tracker.current_progress_units
		)
	)
	run_score.apply_event(event, score_multiplier)
	momentum_meter.apply_event(event)
	rare_event_tracker.register_event(event)
	causal_chain_tracker.register(event)
	if event.qualifies_for_combo and not event.action_tag.is_empty():
		_unique_action_tags[event.action_tag] = true
	if event.kind == GameplayEvent.Kind.PLAYER_HEAVY_HIT:
		heavy_hit_count += 1
		run_score.lose_half_pending()
	elif event.kind == GameplayEvent.Kind.PLAYER_DAMAGE_TAKEN:
		combo_tracker.break_on_damage()
	event_hub.broadcast(event)
	return true


func advance(speed_ratio: float, delta: float) -> void:
	combo_tracker.advance(delta)
	momentum_meter.advance_motion(speed_ratio, delta)
	run_score.advance(delta)
	causal_chain_tracker.advance(delta)


func reset_run() -> void:
	event_hub.reset_run()
	run_score.reset_run()
	combo_tracker.reset_run()
	momentum_meter.reset_run()
	rare_event_tracker.reset_run()
	causal_chain_tracker.reset()
	combat_telemetry.reset_run()
	heavy_hit_count = 0
	_unique_action_tags.clear()
	frozen_summary = null


func begin_new_game_plus_cycle() -> void:
	run_score.bank_all()
	event_hub.reset_run()
	combo_tracker.reset_run()
	momentum_meter.reset_run()
	causal_chain_tracker.reset()


func current_score() -> int:
	return run_score.score


func current_multiplier() -> int:
	return combo_tracker.current_multiplier


func momentum_value() -> float:
	return momentum_meter.value


func freeze_summary(
	waves_cleared: int,
	overdrive_activations: int,
	run_metrics: Dictionary = {}
) -> RunSummarySnapshot:
	if frozen_summary == null:
		run_score.bank_all()
		frozen_summary = snapshot_summary(
			waves_cleared,
			overdrive_activations,
			run_metrics
		)
	return frozen_summary


func snapshot_summary(
	waves_cleared: int,
	overdrive_activations: int,
	run_metrics: Dictionary = {}
) -> RunSummarySnapshot:
	var completed: bool = bool(run_metrics.get("completed", waves_cleared >= 6))
	var mastery: Dictionary = MasteryEvaluator.evaluate({
		"completed": completed,
		"highest_act": waves_cleared,
		"heavy_hits": heavy_hit_count,
		"unique_actions": _unique_action_tags.size(),
		"causal_depth": causal_chain_tracker.best_depth,
		"overdrives": overdrive_activations,
		"contract_succeeded": bool(run_metrics.get("contract_succeeded", false)),
	})
	var summary_metrics: Dictionary = run_metrics.duplicate()
	summary_metrics.merge(combat_telemetry.snapshot(), true)
	summary_metrics.merge({
		"grade": mastery.grade,
		"mastery_points": mastery.points,
		"strongest": mastery.strongest,
		"weakest": mastery.weakest,
		"objective": mastery.objective,
		"heavy_hits": heavy_hit_count,
		"unique_actions": _unique_action_tags.size(),
		"causal_depth": causal_chain_tracker.best_depth,
	}, true)
	return RunSummarySnapshot.new(
		run_score.score,
		combo_tracker.peak_multiplier,
		combo_tracker.best_chain_count,
		waves_cleared,
		overdrive_activations,
		rare_event_tracker.snapshot_counts(),
		summary_metrics
	)
