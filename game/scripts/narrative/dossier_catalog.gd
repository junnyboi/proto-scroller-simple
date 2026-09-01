class_name DossierCatalog
extends RefCounted

const DOSSIER_DIRECTORY: String = "res://resources/narrative/dossiers"
const EVIDENCE_FLAGS: Array[StringName] = [
	&"LEDGER", &"NURSERY",
]
const LEGACY_CAPSTONE_ALIASES: Dictionary = {
	&"dossier_business_crown_reserve_treasury": &"B05_EASTBOUND_CONSIDERATION",
	&"dossier_residential_nightglass_mutual_clinic": &"ASHWATER_INTAKE_MANIFEST",
}

static var _definitions: Array[DossierDefinition] = []
static var _by_dossier_id: Dictionary[StringName, DossierDefinition] = {}
static var _by_variant_id: Dictionary[StringName, DossierDefinition] = {}
static var _capstones_by_boss: Dictionary[StringName, DossierDefinition] = {}


static func definitions() -> Array[DossierDefinition]:
	_ensure_catalog()
	return _definitions.duplicate()


static func definition_for_variant(variant_id: StringName) -> DossierDefinition:
	_ensure_catalog()
	return _by_variant_id.get(variant_id) as DossierDefinition


static func definition_for_dossier(dossier_id: StringName) -> DossierDefinition:
	_ensure_catalog()
	return _by_dossier_id.get(normalize_dossier_id(dossier_id)) as DossierDefinition


static func capstone_for_boss(boss_id: StringName) -> DossierDefinition:
	_ensure_catalog()
	return _capstones_by_boss.get(boss_id) as DossierDefinition


static func capstone_definitions() -> Array[DossierDefinition]:
	_ensure_catalog()
	var result: Array[DossierDefinition] = []
	for definition: DossierDefinition in _definitions:
		if definition.is_boss_capstone:
			result.append(definition)
	return result


static func normalize_dossier_id(dossier_id: StringName) -> StringName:
	return StringName(LEGACY_CAPSTONE_ALIASES.get(dossier_id, dossier_id))


static func has_dossier(dossier_id: StringName) -> bool:
	_ensure_catalog()
	return _by_dossier_id.has(normalize_dossier_id(dossier_id))


static func is_evidence_flag(evidence_id: StringName) -> bool:
	return evidence_id in EVIDENCE_FLAGS


static func district_definitions(district_id: StringName) -> Array[DossierDefinition]:
	_ensure_catalog()
	var result: Array[DossierDefinition] = []
	for definition: DossierDefinition in _definitions:
		if definition.district_id == district_id:
			result.append(definition)
	return result


static func validation_errors() -> PackedStringArray:
	_ensure_catalog()
	var errors: PackedStringArray = PackedStringArray()
	if _definitions.size() != CityDistrictCatalog.BUILDING_VARIANT_COUNT:
		errors.append(
			"dossier_count=%d expected=%d"
			% [_definitions.size(), CityDistrictCatalog.BUILDING_VARIANT_COUNT]
		)
	if _capstones_by_boss.size() != BossCampaignCatalog.DEFINITION_COUNT:
		errors.append(
			"capstone_count=%d expected=%d"
			% [_capstones_by_boss.size(), BossCampaignCatalog.DEFINITION_COUNT]
		)
	if EVIDENCE_FLAGS.size() != BossCampaignCatalog.DEFINITION_COUNT:
		errors.append(
			"evidence_count=%d expected=%d"
			% [EVIDENCE_FLAGS.size(), BossCampaignCatalog.DEFINITION_COUNT]
		)
	var district_counts: Dictionary[StringName, int] = {}
	var dossier_ids: Dictionary[StringName, bool] = {}
	var variant_ids: Dictionary[StringName, bool] = {}
	for definition: DossierDefinition in _definitions:
		for error: String in definition.validation_errors():
			errors.append("%s: %s" % [definition.dossier_id, error])
		if dossier_ids.has(definition.dossier_id):
			errors.append("duplicate dossier_id %s" % definition.dossier_id)
		dossier_ids[definition.dossier_id] = true
		if variant_ids.has(definition.building_variant_id):
			errors.append("duplicate dossier variant %s" % definition.building_variant_id)
		variant_ids[definition.building_variant_id] = true
		if CityDistrictCatalog.variant_by_id(definition.building_variant_id) == null:
			errors.append("unknown dossier variant %s" % definition.building_variant_id)
		if not definition.trigger_column in range(StructuralBuilding2D.COLUMNS):
			errors.append("invalid dossier column %s" % definition.dossier_id)
		if not definition.trigger_row in range(StructuralBuilding2D.ROWS):
			errors.append("invalid dossier row %s" % definition.dossier_id)
		district_counts[definition.district_id] = int(
			district_counts.get(definition.district_id, 0)
		) + 1
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		if int(district_counts.get(district.district_id, 0)) != 5:
			errors.append("district dossier count mismatch %s" % district.district_id)
	_validate_capstones(errors)
	return errors


static func _validate_capstones(errors: PackedStringArray) -> void:
	for boss: BossEncounterDefinition in BossCampaignCatalog.definitions():
		var capstone: DossierDefinition = capstone_for_boss(boss.boss_id)
		if capstone == null:
			errors.append("missing capstone for %s" % boss.boss_id)
			continue
		if capstone.dossier_id != boss.capstone_dossier_id:
			errors.append("capstone dossier mismatch for %s" % boss.boss_id)
		if capstone.evidence_flag_id != boss.evidence_flag_id:
			errors.append("capstone evidence mismatch for %s" % boss.boss_id)
		if capstone.building_variant_id != boss.arena_landmark_variant_id:
			errors.append("capstone facade mismatch for %s" % boss.boss_id)


static func _ensure_catalog() -> void:
	if not _definitions.is_empty():
		return
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		for variant: StructuralBuildingVariant in district.building_variants:
			var path: String = "%s/%s.tres" % [DOSSIER_DIRECTORY, variant.variant_id]
			var definition: DossierDefinition = load(path) as DossierDefinition
			if definition == null:
				continue
			_definitions.append(definition)
			_by_dossier_id[definition.dossier_id] = definition
			_by_variant_id[definition.building_variant_id] = definition
			if definition.is_boss_capstone:
				_capstones_by_boss[definition.boss_id] = definition
