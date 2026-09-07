class_name RunScore
extends Node

signal score_changed(score: int, awarded: int)
signal pending_changed(value: int)

const MAX_SCORE: int = 2_000_000_000

var safe_score: int = 0
var pending_bank: PendingScoreBank = PendingScoreBank.new()
var score: int:
	get:
		return clampi(safe_score + pending_bank.value, 0, MAX_SCORE)


func apply_event(event: GameplayEvent, active_multiplier: int) -> int:
	if event == null or event.rampage_score_points() <= 0 or score >= MAX_SCORE:
		return 0
	var base_points: int = mini(event.rampage_score_points(), MAX_SCORE - score)
	var multiplier: int = clampi(active_multiplier, 1, 5) if event.qualifies_for_combo else 1
	var premium: int = mini(base_points * (multiplier - 1), MAX_SCORE - score - base_points)
	safe_score += base_points
	pending_bank.add(premium)
	var awarded: int = base_points + premium
	score_changed.emit(score, awarded)
	pending_changed.emit(pending_bank.value)
	return awarded


func advance(delta: float) -> int:
	var banked: int = pending_bank.advance(delta)
	if banked <= 0:
		return 0
	safe_score = mini(safe_score + banked, MAX_SCORE)
	pending_changed.emit(0)
	return banked


func bank_all() -> int:
	var banked: int = pending_bank.bank_all()
	safe_score = mini(safe_score + banked, MAX_SCORE)
	pending_changed.emit(0)
	return banked


func lose_half_pending() -> int:
	var discarded: int = pending_bank.discard_half()
	if discarded > 0:
		score_changed.emit(score, -discarded)
		pending_changed.emit(pending_bank.value)
	return discarded


func reset_run() -> void:
	safe_score = 0
	pending_bank.reset()
	pending_changed.emit(0)


func capture_attempt_state() -> Dictionary:
	return {
		"safe_score": safe_score,
		"pending_value": pending_bank.value,
		"pending_remaining": pending_bank.bank_remaining,
	}


func restore_attempt_state(state: Dictionary) -> void:
	safe_score = clampi(int(_safe_number(state.get("safe_score", safe_score))), 0, MAX_SCORE)
	pending_bank.value = clampi(int(_safe_number(state.get("pending_value", pending_bank.value))), 0, MAX_SCORE - safe_score)
	pending_bank.bank_remaining = maxf(_safe_number(state.get("pending_remaining", pending_bank.bank_remaining)), 0.0)
	score_changed.emit(score, 0)
	pending_changed.emit(pending_bank.value)


func deduct(points: int) -> int:
	var deduction: int = mini(maxi(points, 0), score)
	if deduction <= 0:
		return 0
	var from_pending: int = mini(deduction, pending_bank.value)
	pending_bank.value -= from_pending
	safe_score -= deduction - from_pending
	score_changed.emit(score, -deduction)
	pending_changed.emit(pending_bank.value)
	return deduction


func _safe_number(value: Variant) -> float:
	return clampf(float(value), 0.0, MAX_SCORE) if (value is int or value is float) and is_finite(float(value)) else 0.0
