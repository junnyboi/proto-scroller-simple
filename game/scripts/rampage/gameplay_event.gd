class_name GameplayEvent
extends RefCounted
# gdlint: disable=function-arguments-number


enum Kind {
	DAMAGE_APPLIED,
	PROP_DESTROYED,
	ENEMY_DEFEATED,
	WRECK_SCRAPPED,
	CELL_DESTROYED,
	CHAIN_COLLAPSE,
	AIRBORNE_DEBRIS_HIT,
	PLAYER_HEAVY_HIT,
	CATALYST_TRIGGERED,
	CAUSAL_CHAIN,
	BOSS_STATE,
	GROUND_SMASH_SHOCKWAVE,
	PLAYER_DAMAGE_TAKEN,
}

const PROP_BREAK: StringName = &"PROP_BREAK"
const SOLDIER_LAUNCH: StringName = &"SOLDIER_LAUNCH"
const TANK_SCRAP: StringName = &"TANK_SCRAP"
const AIR_DEBRIS_HIT: StringName = &"AIR_DEBRIS_HIT"
const CELL_BREACH: StringName = &"CELL_BREACH"
const CHAIN_COLLAPSE: StringName = &"CHAIN_COLLAPSE"
const CATALYST_TRIGGER: StringName = &"CATALYST_TRIGGER"
const POWER_BOX_SCRAP: StringName = &"POWER_BOX_SCRAP"
const SHOCKWAVE_CUE: StringName = &"GROUND_SMASH_SHOCKWAVE"
const ENEMY_KILL: StringName = &"ENEMY_KILL"

var event_id: int = 0
var dedupe_key: StringName = &""
var attack_id: int = 0
var kind: Kind = Kind.DAMAGE_APPLIED
var action_tag: StringName = &""
var base_points: int = 0
var score_points: int = -1
var momentum_delta: float = 0.0
var qualifies_for_combo: bool = false
var combo_progress_units: int = 1
var world_position: Vector2 = Vector2.ZERO
var material_id: StringName = &""
var source_id: int = 0
var target_id: int = 0
var cause: StringName = &""
var root_attack_id: int = 0
var causal_depth: int = 0
var debris_units: int = 0
var presentation_direction: Vector2 = Vector2.RIGHT
var presentation_speed: float = 0.0
var presentation_seed: int = 0
var enemy_archetype_id: StringName = &""
var enemy_family_id: StringName = &""
var weapon_id: StringName = &""


func _init(
	p_dedupe_key: StringName = &"",
	p_attack_id: int = 0,
	p_kind: Kind = Kind.DAMAGE_APPLIED,
	p_action_tag: StringName = &"",
	p_base_points: int = 0,
	p_momentum_delta: float = 0.0,
	p_qualifies_for_combo: bool = false,
	p_world_position: Vector2 = Vector2.ZERO,
	p_material_id: StringName = &"",
	p_source_id: int = 0,
	p_target_id: int = 0,
	p_cause: StringName = &""
) -> void:
	dedupe_key = p_dedupe_key
	attack_id = p_attack_id
	kind = p_kind
	action_tag = p_action_tag
	base_points = p_base_points
	momentum_delta = p_momentum_delta
	qualifies_for_combo = p_qualifies_for_combo
	world_position = p_world_position
	material_id = p_material_id
	source_id = p_source_id
	target_id = p_target_id
	cause = p_cause


func rampage_score_points() -> int:
	return base_points if score_points < 0 else score_points
