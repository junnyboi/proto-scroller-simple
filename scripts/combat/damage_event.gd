class_name DamageEvent
extends RefCounted
# gdlint: disable=function-arguments-number

const FLAG_NONE: int = 0
const FLAG_CATALYST: int = 1 << 0
const FLAG_DIRECTIVE_BREACH: int = 1 << 1
const FLAG_DIRECTIVE_AFTERSHOCK: int = 1 << 2
const FLAG_DIRECTIVE_SKYBREAKER: int = 1 << 3
const FLAG_VOLATILE: int = 1 << 4
const FLAG_KINETIC_FIELD: int = 1 << 5
const FLAG_HAZARD: int = 1 << 6
const FLAG_FULL_CHARGE: int = 1 << 7
const FLAG_UNBLOCKABLE: int = 1 << 8
const FLAG_GRAVITY_CRUCIBLE: int = 1 << 9
const FLAG_TESLA_TOWER: int = 1 << 10
const FLAG_SIEGE_DRILL: int = 1 << 11
const MAX_CAUSAL_DEPTH: int = 3

var attack_id: int
var source: Node
var amount: float
var damage_type: StringName
var hit_position: Vector2
var direction: Vector2
var impulse_per_mass: float
var root_attack_id: int
var causal_depth: int
var effect_flags: int
var kinetic_debris_bonus: float


func _init(
	p_attack_id: int = 0,
	p_source: Node = null,
	p_amount: float = 0.0,
	p_damage_type: StringName = &"impact",
	p_hit_position: Vector2 = Vector2.ZERO,
	p_direction: Vector2 = Vector2.RIGHT,
	p_impulse_per_mass: float = 0.0,
	p_root_attack_id: int = 0,
	p_causal_depth: int = 0,
	p_effect_flags: int = FLAG_NONE,
	p_kinetic_debris_bonus: float = 0.0
) -> void:
	attack_id = p_attack_id
	source = p_source
	amount = maxf(p_amount, 0.0)
	damage_type = p_damage_type
	hit_position = p_hit_position
	direction = p_direction.normalized() if not p_direction.is_zero_approx() else Vector2.RIGHT
	impulse_per_mass = maxf(p_impulse_per_mass, 0.0)
	root_attack_id = p_root_attack_id if p_root_attack_id != 0 else p_attack_id
	causal_depth = maxi(p_causal_depth, 0)
	effect_flags = p_effect_flags
	kinetic_debris_bonus = maxf(p_kinetic_debris_bonus, 0.0)


func scaled(factor: float) -> DamageEvent:
	return DamageEvent.new(
		attack_id,
		source,
		amount * factor,
		damage_type,
		hit_position,
		direction,
		impulse_per_mass * factor,
		root_attack_id,
		causal_depth,
		effect_flags,
		kinetic_debris_bonus
	)
