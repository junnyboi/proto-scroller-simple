class_name KineticFieldRuntime
extends UpgradeRuntime

const MELEE_MULTIPLIERS: Array[float] = [1.0, 1.10, 1.20, 1.30]
const DEBRIS_BONUSES: Array[float] = [0.0, 2.0, 4.0, 6.0]

var _next_child_delivery_id: int = -1


func _init() -> void:
	setup(&"KINETIC_FIELD", 3)


func decorate_attack(spec: AttackSpec) -> AttackSpec:
	if spec == null or current_rank <= 0:
		return spec
	if (spec.effect_flags & DamageEvent.FLAG_KINETIC_FIELD) != 0:
		return spec
	var multiplier: float = MELEE_MULTIPLIERS[current_rank]
	return AttackSpec.new(
		spec.mode,
		spec.attack_id,
		spec.facing,
		spec.speed_ratio,
		spec.anticipation_seconds,
		spec.active_seconds,
		spec.recovery_seconds,
		spec.actor_damage * multiplier,
		spec.structural_damage * multiplier,
		spec.impulse_per_mass,
		spec.hit_size,
		spec.hit_offset,
		spec.opening_compression,
		spec.effect_flags | DamageEvent.FLAG_KINETIC_FIELD,
		DEBRIS_BONUSES[current_rank]
	)


func decorate_query_options(options: DamageQueryOptions, spec: AttackSpec) -> void:
	if options == null or spec == null:
		return
	options.effect_flags = options.effect_flags | spec.effect_flags
	options.kinetic_debris_bonus = spec.kinetic_debris_bonus


func arm_debris(body: DebrisBody2D, source_event: DamageEvent) -> bool:
	if body == null or source_event == null:
		return false
	if (source_event.effect_flags & DamageEvent.FLAG_KINETIC_FIELD) == 0:
		return false
	var delivery_id: int = _next_child_delivery_id
	_next_child_delivery_id -= 1
	body.arm_kinetic_impact(
		source_event.source,
		source_event.root_attack_id,
		delivery_id,
		source_event.kinetic_debris_bonus,
		source_event.effect_flags
	)
	return true


func apply_rank(total_rank: int, _context: Dictionary = {}) -> bool:
	var next_rank: int = clampi(total_rank, 0, runtime_max_rank)
	if current_rank == next_rank:
		return false
	current_rank = next_rank
	return true


func reset_run() -> void:
	super.reset_run()
	_next_child_delivery_id = -1
