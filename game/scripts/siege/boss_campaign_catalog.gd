class_name BossCampaignCatalog
extends RefCounted

const BOSS_DURABILITY_MULTIPLIER: float = 1.5
const BASE_ARMOR: float = 330.0
const BASE_HEALTH: float = 320.0
const BASE_ARMOR_MILESTONE_STEP: float = 110.0

const DEFINITION_COUNT: int = 2
const CANONICAL_TRIGGERS: Array[int] = [
	CityDistrictCatalog.FACADE_ENCOUNTERS_PER_DISTRICT - 1,
	CityDistrictCatalog.CHUNKS_PER_DISTRICT
	+ CityDistrictCatalog.FACADE_ENCOUNTERS_PER_DISTRICT - 1,
]
const CANONICAL_UNLOCKS: Array[int] = [
	CityDistrictCatalog.CHUNKS_PER_DISTRICT,
	CityDistrictCatalog.CHUNKS_PER_DISTRICT * 2,
	-1,
]
const CANONICAL_EVIDENCE: Array[StringName] = [
	&"LEDGER", &"NURSERY",
]

static var _definitions: Array[BossEncounterDefinition] = []
static var _definitions_by_id: Dictionary[StringName, BossEncounterDefinition] = {}
static var _definitions_by_trigger: Dictionary[int, BossEncounterDefinition] = {}


static func definitions() -> Array[BossEncounterDefinition]:
	_ensure_catalog()
	return _definitions.duplicate()


static func definition(boss_id: StringName) -> BossEncounterDefinition:
	_ensure_catalog()
	return _definitions_by_id.get(boss_id) as BossEncounterDefinition


static func definition_for_trigger(trigger_chunk: int) -> BossEncounterDefinition:
	_ensure_catalog()
	return _definitions_by_trigger.get(trigger_chunk) as BossEncounterDefinition


static func validation_errors(
	definitions_to_validate: Array[BossEncounterDefinition] = []
) -> PackedStringArray:
	_ensure_catalog()
	var definitions_value: Array[BossEncounterDefinition] = (
		_definitions if definitions_to_validate.is_empty() else definitions_to_validate
	)
	var errors: PackedStringArray = PackedStringArray()
	if definitions_value.size() != DEFINITION_COUNT:
		errors.append(
		"boss_definition_count=%d expected=%d"
		% [definitions_value.size(), DEFINITION_COUNT]
		)
	var boss_ids: Dictionary[StringName, bool] = {}
	var triggers: Dictionary[int, bool] = {}
	var dossiers: Dictionary[StringName, bool] = {}
	var evidence_flags: Dictionary[StringName, bool] = {}
	for definition_value: BossEncounterDefinition in definitions_value:
		if definition_value == null:
			errors.append("null boss definition")
			continue
		for error: String in definition_value.validation_errors():
			errors.append("%s: %s" % [definition_value.boss_id, error])
		if boss_ids.has(definition_value.boss_id):
			errors.append("duplicate boss_id %s" % definition_value.boss_id)
		boss_ids[definition_value.boss_id] = true
		if triggers.has(definition_value.trigger_chunk):
			errors.append("duplicate trigger_chunk %d" % definition_value.trigger_chunk)
		triggers[definition_value.trigger_chunk] = true
		if dossiers.has(definition_value.capstone_dossier_id):
			errors.append("duplicate capstone dossier %s" % definition_value.capstone_dossier_id)
		dossiers[definition_value.capstone_dossier_id] = true
		if evidence_flags.has(definition_value.evidence_flag_id):
			errors.append("duplicate evidence flag %s" % definition_value.evidence_flag_id)
		evidence_flags[definition_value.evidence_flag_id] = true
		_validate_district_and_arena(definition_value, errors)
		_validate_requirements(definition_value, errors)
	_validate_canonical_order(definitions_value, errors)
	return errors


static func _validate_district_and_arena(
	definition_value: BossEncounterDefinition,
	errors: PackedStringArray
) -> void:
	var district: CityDistrictProfile
	for candidate: CityDistrictProfile in CityDistrictCatalog.districts():
		if candidate.district_id == definition_value.district_id:
			district = candidate
			break
	if district == null:
		errors.append("unknown district_id %s" % definition_value.district_id)
		return
	if not district.contains_logical_chunk(definition_value.trigger_chunk):
		errors.append("trigger outside district for %s" % definition_value.boss_id)
	var arena_offset: int = (
		definition_value.arena_logical_chunk - definition_value.trigger_chunk
	)
	if (
		arena_offset < -CityWorldStream.BEHIND_CHUNKS
		or arena_offset > CityWorldStream.AHEAD_CHUNKS
	):
		errors.append("nonresident arena reference for %s" % definition_value.boss_id)
	var variant: StructuralBuildingVariant = CityDistrictCatalog.variant_by_id(
		definition_value.arena_landmark_variant_id
	)
	if variant == null or district.variant_by_id(variant.variant_id) == null:
		errors.append("unknown arena landmark for %s" % definition_value.boss_id)


static func _validate_requirements(
	definition_value: BossEncounterDefinition,
	errors: PackedStringArray
) -> void:
	var capacities: Dictionary[StringName, int] = BossUtilityPool.utility_capacities()
	for key_value: Variant in definition_value.utility_requirements:
		var key: StringName = StringName(key_value)
		var demand: int = int(definition_value.utility_requirements[key_value])
		var capacity: int = int(capacities.get(key, 0))
		if capacity == 0 or demand > capacity:
			errors.append(
				"utility demand %s=%d cap=%d for %s"
				% [key, demand, capacity, definition_value.boss_id]
			)
	var support_capacities: Dictionary[StringName, int] = {
		&"procedural_infantry": RuntimeBudget.PROCEDURAL_INFANTRY,
		&"procedural_light": RuntimeBudget.PROCEDURAL_LIGHT,
		&"procedural_heavy": RuntimeBudget.PROCEDURAL_HEAVY,
		&"procedural_air": RuntimeBudget.PROCEDURAL_AIR,
		&"procedural_siege": RuntimeBudget.PROCEDURAL_SIEGE,
	}
	for key_value: Variant in definition_value.support_reservations:
		var key: StringName = StringName(key_value)
		var demand: int = int(definition_value.support_reservations[key_value])
		var capacity: int = int(support_capacities.get(key, 0))
		if capacity == 0 or demand > capacity:
			errors.append(
				"support demand %s=%d cap=%d for %s"
				% [key, demand, capacity, definition_value.boss_id]
			)


static func _validate_canonical_order(
	definitions_value: Array[BossEncounterDefinition],
	errors: PackedStringArray
) -> void:
	if definitions_value.size() != DEFINITION_COUNT:
		return
	for index: int in range(DEFINITION_COUNT):
		var definition_value: BossEncounterDefinition = definitions_value[index]
		if definition_value == null:
			continue
		if definition_value.trigger_chunk != CANONICAL_TRIGGERS[index]:
			errors.append("unexpected trigger at boss index %d" % index)
		if definition_value.evidence_flag_id != CANONICAL_EVIDENCE[index]:
			errors.append("unexpected evidence flag at boss index %d" % index)


static func _ensure_catalog() -> void:
	if not _definitions.is_empty():
		return
	_definitions = [
			_make_definition(
					&"SETTLEMENT_ENGINE_S04",
					&"BUSINESS",
					CANONICAL_TRIGGERS[0],
					CANONICAL_UNLOCKS[0],
			"boss.settlement_engine_s04.name",
			"SETTLEMENT ENGINE S-04 — The Fiduciary Saint",
			&"business_crown_reserve_treasury",
			&"B05_EASTBOUND_CONSIDERATION",
			&"LEDGER",
			&"SETTLEMENT_ENGINE",
			{
				&"markers": 3,
				&"radial_shockwaves": 1,
				&"collapse_listeners": 1,
				&"wreck_receivers": 1,
			},
			{&"procedural_infantry": 8},
			[
				&"CORE_SHOCKWAVE",
			]
		),
				_make_definition(
						&"SAMARITAN_15",
						&"RESIDENTIAL",
						CANONICAL_TRIGGERS[1],
						CANONICAL_UNLOCKS[1],
			"boss.samaritan_15.name",
			"SAMARITAN-15 — The Last Evacuation",
			&"residential_nightglass_mutual_clinic",
			&"ASHWATER_INTAKE_MANIFEST",
			&"NURSERY",
			&"SAMARITAN",
			{
				&"markers": 3,
				&"lane_damage_areas": 3,
				&"collapse_listeners": 1,
				&"pod_visuals": 4,
				&"wreck_receivers": 1,
			},
			{&"procedural_infantry": 1, &"procedural_light": 1},
			[
				&"TRIAGE_SWEEP",
				&"PRESSURE_SENTENCE",
				&"EXTRACTION_CLAMP",
				&"BLACKOUT_HARVEST",
			]
		),
	]
	_definitions_by_id.clear()
	_definitions_by_trigger.clear()
	for definition_value: BossEncounterDefinition in _definitions:
		_definitions_by_id[definition_value.boss_id] = definition_value
		_definitions_by_trigger[definition_value.trigger_chunk] = definition_value


static func _make_definition(
	boss_id: StringName,
	district_id: StringName,
	trigger_chunk: int,
	unlock_chunk: int,
	display_name_key: String,
	display_name: String,
	arena_variant_id: StringName,
	capstone_dossier_id: StringName,
	evidence_flag_id: StringName,
	preset_id: StringName,
	utility_requirements: Dictionary,
	support_reservations: Dictionary,
	phase_ids: Array[StringName],
	outcomes: PackedInt32Array = PackedInt32Array([BossOutcome.PURGE]),
	receiver_offsets: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
) -> BossEncounterDefinition:
	var definition_value: BossEncounterDefinition = BossEncounterDefinition.new()
	definition_value.boss_id = boss_id
	definition_value.district_id = district_id
	definition_value.trigger_chunk = trigger_chunk
	definition_value.unlock_chunk = unlock_chunk
	definition_value.display_name_key = display_name_key
	definition_value.display_name = display_name
	definition_value.arena_landmark_variant_id = arena_variant_id
	definition_value.arena_logical_chunk = trigger_chunk
	definition_value.arena_building_slot = posmod(trigger_chunk, CityWorldStream.CHUNK_CAPACITY)
	definition_value.arena_cell_indices = PackedInt32Array([0, 1, 2, 3, 4, 5])
	definition_value.wreck_receiver_offsets = receiver_offsets
	definition_value.summon_uses_arena_landmark = false
	definition_value.armor = BASE_ARMOR * BOSS_DURABILITY_MULTIPLIER
	definition_value.health = BASE_HEALTH * BOSS_DURABILITY_MULTIPLIER
	definition_value.screen_seconds = 4.0
	definition_value.phase_thresholds = PackedFloat32Array([0.66, 0.33])
	definition_value.armor_milestone_step = (
		BASE_ARMOR_MILESTONE_STEP * BOSS_DURABILITY_MULTIPLIER
	)
	definition_value.direct_damage_route = true
	definition_value.exposed_damage_types = PackedStringArray(["all"])
	definition_value.phases = _make_phases(phase_ids, support_reservations)
	definition_value.rig_preset = preset_id
	definition_value.behavior_preset = preset_id
	definition_value.support_reservations = support_reservations
	definition_value.utility_requirements = utility_requirements
	definition_value.structural_hooks = PackedStringArray(["BOUND_FACADE"])
	definition_value.structural_fallback_policy = &"SAME_ANCHOR_DIRECT_DAMAGE"
	definition_value.capstone_dossier_id = capstone_dossier_id
	definition_value.evidence_flag_id = evidence_flag_id
	definition_value.evidence_recovery_eligible = true
	definition_value.evidence_recovery_rule = &"ELITE_DROP"
	definition_value.narrative_event_keys = PackedStringArray([
		"boss.%s.armor_break" % String(boss_id).to_lower(),
		"boss.%s.wreck" % String(boss_id).to_lower(),
	])
	definition_value.voice_caption_keys = {
		&"echo": "boss.%s.echo" % String(boss_id).to_lower(),
		&"veyr": "boss.%s.veyr" % String(boss_id).to_lower(),
	}
	definition_value.wreck_mode = &"FRESH_MELEE"
	definition_value.outcome_policy = &"STANDARD_PURGE"
	definition_value.outcomes = outcomes
	definition_value.portrait_socket_overrides = {
		&"presentation_scale": Vector2(0.82, 1.0),
	}
	return definition_value


static func _make_phases(
	phase_ids: Array[StringName],
	support_reservations: Dictionary
) -> Array[BossPhaseDefinition]:
	var phases: Array[BossPhaseDefinition] = []
	for index: int in range(phase_ids.size()):
		var phase: BossPhaseDefinition = BossPhaseDefinition.new()
		phase.phase_id = phase_ids[index]
		phase.health_threshold = (
			1.0 - float(index) / float(maxi(phase_ids.size(), 1))
		)
		phase.attack_choices = PackedStringArray([String(phase_ids[index]).to_lower()])
		phase.telegraph_profile = &"BOSS_STANDARD"
		phase.recovery_duration = 0.75
		phase.reservation_requirements = (
			support_reservations.duplicate() if index == 1 else {}
		)
		phase.cancel_policy = &"CANCEL_ON_GENERATION_CHANGE"
		phase.safe_gap_required = true
		phase.minimum_safe_gap = 192.0
		phase.structural_accelerants = {&"BOUND_FACADE": 80.0}
		phases.append(phase)
	return phases
