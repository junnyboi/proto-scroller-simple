class_name DamageQueryOptions
extends RefCounted

var root_attack_id: int = 0
var causal_depth: int = 0
var effect_flags: int = DamageEvent.FLAG_NONE
var kinetic_debris_bonus: float = 0.0
var result_limit: int = 0
var structural_limit: int = 0
var debris_limit: int = 0
var damage_type: StringName = &"explosive"
var player_damage_scale: float = 1.0
var enemy_damage_scale: float = 1.0
var structural_damage_scale: float = 1.0
