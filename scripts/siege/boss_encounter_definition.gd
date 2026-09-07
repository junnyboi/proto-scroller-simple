class_name BossEncounterDefinition
extends Resource

const DEFAULT_GROUND_SMASH_RADIUS: float = 96.0
const OUTGOING_DAMAGE_MULTIPLIER: float = 0.5

@export_group("Identity")
@export var boss_id: StringName = &""
@export var district_id: StringName = &""
@export var trigger_chunk: int = -1
@export var unlock_chunk: int = -1
@export var display_name_key: String = ""
@export var display_name: String = ""

@export_group("Arena Binding")
@export var arena_landmark_variant_id: StringName = &""
@export var arena_logical_chunk: int = -1
@export var arena_building_slot: int = -1
@export var arena_cell_indices: PackedInt32Array = PackedInt32Array()
@export var wreck_receiver_offsets: PackedVector2Array = PackedVector2Array()
@export var summon_uses_arena_landmark: bool = true

@export_group("Durability")
@export_range(1.0, 5000.0, 1.0) var armor: float = 330.0
@export_range(1.0, 5000.0, 1.0) var health: float = 320.0
@export_range(0.0, 20.0, 0.05) var screen_seconds: float = 4.0
@export var phase_thresholds: PackedFloat32Array = PackedFloat32Array()
@export_range(1.0, 1000.0, 1.0) var armor_milestone_step: float = 110.0
@export var direct_damage_route: bool = true
@export var exposed_damage_types: PackedStringArray = PackedStringArray()
@export var phases: Array[BossPhaseDefinition] = []

@export_group("Runtime Presets")
@export var rig_preset: StringName = &""
@export var behavior_preset: StringName = &""
@export var support_reservations: Dictionary = {}
@export var utility_requirements: Dictionary = {}
@export var structural_hooks: PackedStringArray = PackedStringArray()
@export var structural_fallback_policy: StringName = &"DIRECT_DAMAGE"

@export_group("Narrative")
@export var capstone_dossier_id: StringName = &""
@export var evidence_flag_id: StringName = &""
@export var evidence_recovery_eligible: bool = false
@export var evidence_recovery_rule: StringName = &""
@export var narrative_event_keys: PackedStringArray = PackedStringArray()
@export var voice_caption_keys: Dictionary = {}

@export_group("Completion")
@export var wreck_mode: StringName = &"FRESH_MELEE"
@export var outcome_policy: StringName = &"STANDARD"
@export var outcomes: PackedInt32Array = PackedInt32Array()
@export var portrait_socket_overrides: Dictionary = {}


static func scale_outgoing_damage(damage: float) -> float:
	return maxf(damage, 0.0) * OUTGOING_DAMAGE_MULTIPLIER


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	_validate_identity(errors)
	_validate_arena(errors)
	_validate_damage(errors)
	_validate_runtime(errors)
	_validate_narrative(errors)
	_validate_completion(errors)
	return errors


func _validate_identity(errors: PackedStringArray) -> void:
	if boss_id.is_empty():
		errors.append("boss_id is empty")
	if district_id.is_empty():
		errors.append("district_id is empty for %s" % boss_id)
	if trigger_chunk < 0:
		errors.append("trigger_chunk is negative for %s" % boss_id)
	if unlock_chunk < -1:
		errors.append("unlock_chunk is invalid for %s" % boss_id)
	if display_name_key.is_empty() or display_name.is_empty():
		errors.append("display name missing for %s" % boss_id)


func _validate_arena(errors: PackedStringArray) -> void:
	if arena_landmark_variant_id.is_empty():
		errors.append("arena landmark missing for %s" % boss_id)
	if arena_logical_chunk < 0 or arena_building_slot < 0:
		errors.append("arena binding missing for %s" % boss_id)
	if arena_cell_indices.is_empty():
		errors.append("arena cell binding missing for %s" % boss_id)
	var seen_cells: Dictionary[int, bool] = {}
	for cell_index: int in arena_cell_indices:
		if cell_index < 0 or cell_index >= StructuralBuilding2D.CELL_COUNT:
			errors.append("invalid arena cell %d for %s" % [cell_index, boss_id])
		if seen_cells.has(cell_index):
			errors.append("duplicate arena cell %d for %s" % [cell_index, boss_id])
		seen_cells[cell_index] = true
	if wreck_receiver_offsets.is_empty():
		errors.append("wreck receiver missing for %s" % boss_id)
	for first_index: int in range(wreck_receiver_offsets.size()):
		for second_index: int in range(first_index + 1, wreck_receiver_offsets.size()):
			var spacing: float = wreck_receiver_offsets[first_index].distance_to(
				wreck_receiver_offsets[second_index]
			)
			if spacing < DEFAULT_GROUND_SMASH_RADIUS:
				errors.append("wreck receiver spacing below smash radius for %s" % boss_id)


func _validate_damage(errors: PackedStringArray) -> void:
	if armor <= 0.0 or health <= 0.0 or screen_seconds < 0.0:
		errors.append("invalid durability for %s" % boss_id)
	if not direct_damage_route or exposed_damage_types.is_empty():
		errors.append("direct damage route missing for %s" % boss_id)
	if armor_milestone_step <= 0.0:
		errors.append("armor milestone step missing for %s" % boss_id)
	var previous_threshold: float = 1.01
	for threshold: float in phase_thresholds:
		if threshold <= 0.0 or threshold >= previous_threshold:
			errors.append("invalid phase thresholds for %s" % boss_id)
		previous_threshold = threshold
	var phase_ids: Dictionary[StringName, bool] = {}
	for phase: BossPhaseDefinition in phases:
		if phase == null:
			errors.append("null phase for %s" % boss_id)
			continue
		if phase_ids.has(phase.phase_id):
			errors.append("duplicate phase %s for %s" % [phase.phase_id, boss_id])
		phase_ids[phase.phase_id] = true
		for error: String in phase.validation_errors():
			errors.append("%s: %s" % [boss_id, error])
	if phases.is_empty():
		errors.append("no phases for %s" % boss_id)


func _validate_runtime(errors: PackedStringArray) -> void:
	if rig_preset.is_empty() or behavior_preset.is_empty():
		errors.append("runtime preset missing for %s" % boss_id)
	if structural_fallback_policy.is_empty():
		errors.append("structural fallback missing for %s" % boss_id)
	for requirements: Dictionary in [support_reservations, utility_requirements]:
		for key: Variant in requirements:
			if StringName(key).is_empty() or int(requirements[key]) <= 0:
				errors.append("invalid runtime requirement for %s" % boss_id)


func _validate_narrative(errors: PackedStringArray) -> void:
	if capstone_dossier_id.is_empty() or evidence_flag_id.is_empty():
		errors.append("campaign result missing for %s" % boss_id)
	if evidence_recovery_eligible and evidence_recovery_rule.is_empty():
		errors.append("evidence recovery rule missing for %s" % boss_id)
	if narrative_event_keys.is_empty() or voice_caption_keys.is_empty():
		errors.append("narrative keys missing for %s" % boss_id)


func _validate_completion(errors: PackedStringArray) -> void:
	if wreck_mode.is_empty() or outcome_policy.is_empty():
		errors.append("completion policy missing for %s" % boss_id)
	var seen: Dictionary[int, bool] = {}
	for outcome: int in outcomes:
		if not BossOutcome.is_valid(outcome):
			errors.append("invalid outcome %d for %s" % [outcome, boss_id])
		if seen.has(outcome):
			errors.append("duplicate outcome %d for %s" % [outcome, boss_id])
		seen[outcome] = true
