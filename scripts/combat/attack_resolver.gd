class_name AttackResolver
extends Node

const ATTACK_FRAME_COUNT: int = 25
const ATTACK_EVENT_FRAME: int = 11
const ATTACK_ACTIVE_END_FRAME: int = 14
const ATTACK_FPS: float = 12.0
const ATTACK_END_HOLD_SECONDS: float = 0.05
const FULL_ANTICIPATION_SECONDS: float = float(ATTACK_EVENT_FRAME) / ATTACK_FPS
const FULL_ACTIVE_SECONDS: float = (
	float(ATTACK_ACTIVE_END_FRAME - ATTACK_EVENT_FRAME) / ATTACK_FPS
)
const FULL_RECOVERY_SECONDS: float = (
	float(ATTACK_FRAME_COUNT - ATTACK_ACTIVE_END_FRAME) / ATTACK_FPS
	+ ATTACK_END_HOLD_SECONDS
)
const FULL_ATTACK_SECONDS: float = (
	FULL_ANTICIPATION_SECONDS + FULL_ACTIVE_SECONDS + FULL_RECOVERY_SECONDS
)
const GROUND_SMASH_DAMAGE_MULTIPLIER: float = 2.0

@export_range(0.0, 1.0, 0.01) var jab_cross_speed_threshold: float = 0.70
@export var ground_anticipation_seconds: float = FULL_ANTICIPATION_SECONDS
@export var ground_active_seconds: float = FULL_ACTIVE_SECONDS
@export var ground_recovery_seconds: float = FULL_RECOVERY_SECONDS
@export var jab_cross_anticipation_seconds: float = FULL_ANTICIPATION_SECONDS
@export var jab_cross_active_seconds: float = FULL_ACTIVE_SECONDS
@export var jab_cross_recovery_seconds: float = FULL_RECOVERY_SECONDS
@export var jab_cross_actor_damage: float = 145.0
@export var jab_cross_structural_damage: float = 125.0
@export var jab_cross_impulse_per_mass: float = 1080.0
@export var jab_cross_hit_size: Vector2 = Vector2(190.0, 150.0)
@export var jab_cross_hit_offset: Vector2 = Vector2(105.0, 62.0)


func resolve(
	attack_id: int,
	facing: int,
	actual_speed_ratio: float,
	ground_damage: float,
	ground_impulse_per_mass: float,
	ground_radius: float,
	force_multiplier: float = 1.0,
	structure_multiplier: float = 1.0,
	opening_compression: bool = false
) -> AttackSpec:
	if actual_speed_ratio >= jab_cross_speed_threshold:
		return resolve_jab_cross(
			attack_id,
			facing,
			actual_speed_ratio,
			force_multiplier,
			structure_multiplier,
			opening_compression
		)
	return AttackSpec.new(
		AttackSpec.Mode.GROUND_SMASH,
		attack_id,
		facing,
		actual_speed_ratio,
		ground_anticipation_seconds,
		ground_active_seconds,
		ground_recovery_seconds,
		ground_damage * GROUND_SMASH_DAMAGE_MULTIPLIER,
		ground_damage * structure_multiplier * GROUND_SMASH_DAMAGE_MULTIPLIER,
		ground_impulse_per_mass * force_multiplier,
		Vector2.ONE * ground_radius * 2.0,
		Vector2.ZERO
	)


func resolve_jab_cross(
	attack_id: int,
	facing: int,
	momentum_ratio: float,
	force_multiplier: float = 1.0,
	structure_multiplier: float = 1.0,
	opening_compression: bool = false,
	output_ratio: float = 1.0
) -> AttackSpec:
	var clamped_output_ratio: float = clampf(output_ratio, 0.0, 4.0)
	return AttackSpec.new(
		AttackSpec.Mode.JAB_CROSS,
		attack_id,
		facing,
		momentum_ratio,
		jab_cross_anticipation_seconds,
		jab_cross_active_seconds,
		jab_cross_recovery_seconds,
		jab_cross_actor_damage * clamped_output_ratio,
		jab_cross_structural_damage * structure_multiplier * clamped_output_ratio,
		jab_cross_impulse_per_mass * force_multiplier * clamped_output_ratio,
		jab_cross_hit_size,
		jab_cross_hit_offset,
		opening_compression
	)
