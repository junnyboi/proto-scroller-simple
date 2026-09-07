class_name DirectiveProfile
extends Resource

enum EffectKind {
	NONE,
	BREACH,
	AFTERSHOCK,
	SKYBREAKER,
}

@export var directive_id: StringName = &""
@export var district_id: StringName = &""
@export var display_name: String = "directive.default.name"
@export var instruction: String = ""
@export_range(1.0, 30.0, 0.5) var duration_seconds: float = 12.0
@export_range(1, 20, 1) var target_count: int = 1
@export var objective_kind: int = -1
@export var objective_action_tag: StringName = &""
@export var objective_cause: StringName = &""
@export var objective_material_id: StringName = &""
@export var objective_requires_combo: bool = false
@export_range(0, DamageEvent.MAX_CAUSAL_DEPTH, 1) var objective_min_causal_depth: int = 0
@export var effect_kind: EffectKind = EffectKind.NONE
@export_range(1.0, 1.5, 0.05) var structural_multiplier: float = 1.0
@export_range(0.0, 0.5, 0.05) var pending_bank_fraction: float = 0.25
@export_range(0.0, 0.5, 0.05) var failure_penalty_fraction: float = 0.20
@export var effect_flag: int = DamageEvent.FLAG_NONE
@export var icon: Texture2D


func matches_event(event: GameplayEvent) -> bool:
	return (
		event != null
		and (objective_kind < 0 or event.kind == objective_kind)
		and (objective_action_tag.is_empty() or event.action_tag == objective_action_tag)
		and (objective_cause.is_empty() or event.cause == objective_cause)
		and (objective_material_id.is_empty() or event.material_id == objective_material_id)
		and (not objective_requires_combo or event.qualifies_for_combo)
		and event.causal_depth >= objective_min_causal_depth
	)


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if directive_id.is_empty():
		errors.append("mission directive_id is empty")
	if district_id.is_empty():
		errors.append("mission %s district_id is empty" % directive_id)
	if display_name.is_empty() or instruction.is_empty():
		errors.append("mission %s localization key is empty" % directive_id)
	if objective_kind < 0 and objective_action_tag.is_empty() and objective_cause.is_empty():
		errors.append("mission %s has no event predicate" % directive_id)
	if icon == null:
		errors.append("mission %s icon is null" % directive_id)
	return errors


func resolved_effect_kind() -> EffectKind:
	if effect_kind != EffectKind.NONE:
		return effect_kind
	match directive_id:
		&"DEMOLITION_BREACH":
			return EffectKind.BREACH
	return EffectKind.NONE
