class_name EnemySpawnTuning
extends RefCounted

const QUANTITY_MULTIPLIER: int = 2
const INTERVAL_SCALE: float = 0.5


static func scaled_count(base_count: int) -> int:
	return maxi(base_count, 0) * quantity_multiplier()


static func scaled_interval(seconds: float) -> float:
	return maxf(seconds, 0.0) * interval_scale()


static func scaled_threat(base_threat: int) -> int:
	return maxi(base_threat, 0) * quantity_multiplier()


static func offset_for_copy(copy_index: int, spacing: float, direction: float = 1.0) -> Vector2:
	var centered_index: float = float(copy_index) - float(quantity_multiplier() - 1) * 0.5
	return Vector2(centered_index * spacing * direction, 0.0)


static func quantity_multiplier() -> int:
	return int(RuntimeTweakAccess.run_value(
		&"spawn.quantity_multiplier", QUANTITY_MULTIPLIER
	))


static func interval_scale() -> float:
	return float(RuntimeTweakAccess.run_value(
		&"spawn.interval_scale", INTERVAL_SCALE
	))
