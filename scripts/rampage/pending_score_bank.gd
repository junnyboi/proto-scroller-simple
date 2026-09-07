class_name PendingScoreBank
extends RefCounted

const BANK_DELAY: float = RampageRewardTuning.PENDING_BANK_SECONDS

var value: int = 0
var bank_remaining: float = 0.0


func add(points: int) -> int:
	var accepted: int = maxi(points, 0)
	if accepted <= 0:
		return 0
	value += accepted
	bank_remaining = RampageRewardTuning.pending_bank_seconds()
	return accepted


func advance(delta: float) -> int:
	if value <= 0 or delta <= 0.0:
		return 0
	bank_remaining = maxf(bank_remaining - delta, 0.0)
	if not is_zero_approx(bank_remaining):
		return 0
	return bank_all()


func bank_all() -> int:
	var banked: int = value
	value = 0
	bank_remaining = 0.0
	return banked


func discard_half() -> int:
	var discarded: int = value / 2
	value -= discarded
	return discarded


func reset() -> void:
	value = 0
	bank_remaining = 0.0
