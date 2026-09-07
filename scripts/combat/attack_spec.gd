class_name AttackSpec
extends RefCounted
# gdlint: disable=function-arguments-number


enum Mode {
	GROUND_SMASH,
	JAB_CROSS,
}

var mode: Mode:
	get:
		return _mode
var attack_id: int:
	get:
		return _attack_id
var facing: int:
	get:
		return _facing
var speed_ratio: float:
	get:
		return _speed_ratio
var anticipation_seconds: float:
	get:
		return _anticipation_seconds
var active_seconds: float:
	get:
		return _active_seconds
var recovery_seconds: float:
	get:
		return _recovery_seconds
var actor_damage: float:
	get:
		return _actor_damage
var structural_damage: float:
	get:
		return _structural_damage
var impulse_per_mass: float:
	get:
		return _impulse_per_mass
var hit_size: Vector2:
	get:
		return _hit_size
var hit_offset: Vector2:
	get:
		return _hit_offset
var opening_compression: bool:
	get:
		return _opening_compression
var effect_flags: int:
	get:
		return _effect_flags
var kinetic_debris_bonus: float:
	get:
		return _kinetic_debris_bonus
var charge_multiplier: float:
	get:
		return _charge_multiplier

var _mode: Mode
var _attack_id: int
var _facing: int
var _speed_ratio: float
var _anticipation_seconds: float
var _active_seconds: float
var _recovery_seconds: float
var _actor_damage: float
var _structural_damage: float
var _impulse_per_mass: float
var _hit_size: Vector2
var _hit_offset: Vector2
var _opening_compression: bool
var _effect_flags: int
var _kinetic_debris_bonus: float
var _charge_multiplier: float


func _init(
	p_mode: Mode,
	p_attack_id: int,
	p_facing: int,
	p_speed_ratio: float,
	p_anticipation_seconds: float,
	p_active_seconds: float,
	p_recovery_seconds: float,
	p_actor_damage: float,
	p_structural_damage: float,
	p_impulse_per_mass: float,
	p_hit_size: Vector2,
	p_hit_offset: Vector2,
	p_opening_compression: bool = false,
	p_effect_flags: int = DamageEvent.FLAG_NONE,
	p_kinetic_debris_bonus: float = 0.0,
	p_charge_multiplier: float = 1.0
) -> void:
	_mode = p_mode
	_attack_id = p_attack_id
	_facing = 1 if p_facing >= 0 else -1
	_speed_ratio = clampf(p_speed_ratio, 0.0, 4.0)
	_anticipation_seconds = maxf(p_anticipation_seconds, 0.0)
	_active_seconds = maxf(p_active_seconds, 0.0)
	_recovery_seconds = maxf(p_recovery_seconds, 0.0)
	_actor_damage = maxf(p_actor_damage, 0.0)
	_structural_damage = maxf(p_structural_damage, 0.0)
	_impulse_per_mass = maxf(p_impulse_per_mass, 0.0)
	_hit_size = p_hit_size.max(Vector2.ONE)
	_hit_offset = p_hit_offset
	_opening_compression = p_opening_compression
	_effect_flags = p_effect_flags
	_kinetic_debris_bonus = maxf(p_kinetic_debris_bonus, 0.0)
	_charge_multiplier = clampf(p_charge_multiplier, 1.0, 2.0)


func is_ground_smash() -> bool:
	return _mode == Mode.GROUND_SMASH


func is_jab_cross() -> bool:
	return _mode == Mode.JAB_CROSS


func is_fully_charged() -> bool:
	return is_equal_approx(_charge_multiplier, 2.0)


func with_damage_multiplier(multiplier: float) -> AttackSpec:
	var clamped_multiplier: float = clampf(multiplier, 1.0, 2.0)
	return AttackSpec.new(
		_mode,
		_attack_id,
		_facing,
		_speed_ratio,
		_anticipation_seconds,
		_active_seconds,
		_recovery_seconds,
		_actor_damage * clamped_multiplier,
		_structural_damage * clamped_multiplier,
		_impulse_per_mass,
		_hit_size,
		_hit_offset,
		_opening_compression,
		_effect_flags,
		_kinetic_debris_bonus,
		clamped_multiplier
	)


func with_shop_modifiers(
	damage_multiplier: float,
	structure_multiplier: float,
	radius_multiplier: float,
	debris_bonus: float
) -> AttackSpec:
	return AttackSpec.new(
		_mode,
		_attack_id,
		_facing,
		_speed_ratio,
		_anticipation_seconds,
		_active_seconds,
		_recovery_seconds,
		_actor_damage * maxf(damage_multiplier, 1.0),
		_structural_damage * maxf(damage_multiplier, 1.0) * maxf(structure_multiplier, 1.0),
		_impulse_per_mass,
		_hit_size * maxf(radius_multiplier, 1.0),
		_hit_offset,
		_opening_compression,
		_effect_flags,
		_kinetic_debris_bonus + maxf(debris_bonus, 0.0),
		_charge_multiplier
	)
