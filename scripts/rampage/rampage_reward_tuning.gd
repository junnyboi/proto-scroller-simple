class_name RampageRewardTuning
extends RefCounted

const BASE_COMBO_GRACE_SECONDS: float = 3.0
const BASE_PENDING_BANK_SECONDS: float = 1.0
const COMBO_PROGRESS_UNITS_PER_TIER: int = EnemySpawnTuning.QUANTITY_MULTIPLIER
const MAX_MULTIPLIER: int = 5
const NAMED_BOSS_REWARD_MULTIPLIER: int = 3
const COMBO_GRACE_SECONDS: float = (
	BASE_COMBO_GRACE_SECONDS * EnemySpawnTuning.INTERVAL_SCALE
)
const PENDING_BANK_SECONDS: float = (
	BASE_PENDING_BANK_SECONDS * EnemySpawnTuning.INTERVAL_SCALE
)


static func enemy_score_points(base_points: int, named_boss: bool = false) -> int:
	var sanitized_points: int = maxi(base_points, 0)
	if sanitized_points == 0 or named_boss:
		return sanitized_points
	return maxi(
		roundi(float(sanitized_points) / float(EnemySpawnTuning.quantity_multiplier())),
		1
	)


static func enemy_reward_points(base_points: int, named_boss: bool = false) -> int:
	var sanitized_points: int = maxi(base_points, 0)
	return (
		sanitized_points * int(RuntimeTweakAccess.run_value(
			&"progression.rewards.named_boss_multiplier",
			NAMED_BOSS_REWARD_MULTIPLIER
		))
		if named_boss
		else sanitized_points
	)


static func enemy_combo_progress_units(named_boss: bool = false) -> int:
	return combo_progress_units_per_tier() if named_boss else 1


static func multiplier_for_progress_units(progress_units: int) -> int:
	if progress_units <= 0:
		return 1
	return clampi(
		ceili(float(progress_units) / float(combo_progress_units_per_tier())),
		1,
		int(RuntimeTweakAccess.run_value(
			&"progression.combo.max_multiplier", MAX_MULTIPLIER
		))
	)


static func combo_grace_seconds() -> float:
	return float(RuntimeTweakAccess.run_value(
		&"progression.combo.base_grace_seconds", BASE_COMBO_GRACE_SECONDS
	)) * EnemySpawnTuning.interval_scale()


static func pending_bank_seconds() -> float:
	return float(RuntimeTweakAccess.run_value(
		&"progression.score.bank_base_seconds", BASE_PENDING_BANK_SECONDS
	)) * EnemySpawnTuning.interval_scale()


static func combo_progress_units_per_tier() -> int:
	return EnemySpawnTuning.quantity_multiplier()
