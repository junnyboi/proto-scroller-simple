class_name ComboTracker
extends Node

signal combo_changed(multiplier: int, grace_remaining: float)
signal combo_broken
signal milestone_reached(tier: int, chain_count: int, multiplier: int)

const GRACE_SECONDS: float = RampageRewardTuning.COMBO_GRACE_SECONDS
const MAX_MULTIPLIER: int = RampageRewardTuning.MAX_MULTIPLIER
const HERALD_MILESTONE_TIERS: Array = [2, 3, 4, 5, 7, 10]

var current_multiplier: int = 1
var grace_remaining: float = 0.0
var peak_multiplier: int = 1
var best_chain_count: int = 0
var current_chain_count: int = 0
var current_progress_units: int = 0


func register_event(event: GameplayEvent) -> bool:
	if (
		event == null
		or event.kind != GameplayEvent.Kind.ENEMY_DEFEATED
		or not event.qualifies_for_combo
	):
		return false
	var previous_progress_units: int = current_progress_units
	current_chain_count += 1
	current_progress_units += maxi(event.combo_progress_units, 0)
	current_multiplier = RampageRewardTuning.multiplier_for_progress_units(
		current_progress_units
	)
	grace_remaining = RampageRewardTuning.combo_grace_seconds()
	peak_multiplier = maxi(peak_multiplier, current_multiplier)
	best_chain_count = maxi(best_chain_count, current_chain_count)
	combo_changed.emit(current_multiplier, grace_remaining)
	var reached_tier: int = _highest_crossed_milestone(
		previous_progress_units,
		current_progress_units
	)
	if reached_tier > 0:
		milestone_reached.emit(reached_tier, current_chain_count, current_multiplier)
	return true


func advance(delta: float) -> void:
	if current_chain_count == 0 or delta <= 0.0:
		return
	if delta >= grace_remaining:
		grace_remaining = 0.0
		_break_combo()
		return
	grace_remaining -= delta
	combo_changed.emit(current_multiplier, grace_remaining)


func break_on_damage() -> bool:
	if current_chain_count == 0:
		return false
	grace_remaining = 0.0
	_break_combo()
	return true


func reset_run() -> void:
	current_multiplier = 1
	grace_remaining = 0.0
	peak_multiplier = 1
	best_chain_count = 0
	current_chain_count = 0
	current_progress_units = 0


func _break_combo() -> void:
	current_multiplier = 1
	current_chain_count = 0
	current_progress_units = 0
	combo_changed.emit(current_multiplier, grace_remaining)
	combo_broken.emit()


func _highest_crossed_milestone(previous_units: int, current_units: int) -> int:
	var reached_tier: int = 0
	for tier: int in HERALD_MILESTONE_TIERS:
		var threshold: int = (
			(tier - 1) * RampageRewardTuning.combo_progress_units_per_tier() + 1
		)
		if previous_units < threshold and current_units >= threshold:
			reached_tier = tier
	return reached_tier
