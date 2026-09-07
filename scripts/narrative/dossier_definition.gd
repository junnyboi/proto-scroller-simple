class_name DossierDefinition
extends Resource

@export var dossier_id: StringName
@export var building_variant_id: StringName
@export var district_id: StringName
@export var trigger_column: int
@export var trigger_row: int
@export var title_key: String
@export var body_primary_key: String
@export var body_secondary_key: String
@export var image: Texture2D
@export var is_boss_capstone: bool = false
@export var boss_id: StringName = &""
@export var evidence_flag_id: StringName = &""


static func create(
	p_building_variant_id: StringName,
	p_district_id: StringName,
	p_trigger_column: int,
	p_trigger_row: int,
	p_image: Texture2D,
	p_dossier_id: StringName = &""
) -> DossierDefinition:
	var definition: DossierDefinition = DossierDefinition.new()
	definition.building_variant_id = p_building_variant_id
	definition.district_id = p_district_id
	definition.dossier_id = (
		p_dossier_id
		if not p_dossier_id.is_empty()
		else StringName("dossier_%s" % p_building_variant_id)
	)
	definition.trigger_column = p_trigger_column
	definition.trigger_row = p_trigger_row
	definition.title_key = "narrative.dossier.%s.title" % p_building_variant_id
	definition.body_primary_key = "narrative.dossier.%s.body_primary" % p_building_variant_id
	definition.body_secondary_key = "narrative.dossier.%s.body_secondary" % p_building_variant_id
	definition.image = p_image
	return definition


func trigger_matches(column: int, row: int) -> bool:
	return column == trigger_column and row == trigger_row


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if dossier_id.is_empty() or building_variant_id.is_empty() or district_id.is_empty():
		errors.append("dossier identity is incomplete")
	if title_key.is_empty() or body_primary_key.is_empty() or body_secondary_key.is_empty():
		errors.append("dossier localization is incomplete")
	if image == null:
		errors.append("dossier image is missing")
	if is_boss_capstone and (boss_id.is_empty() or evidence_flag_id.is_empty()):
		errors.append("capstone mapping is incomplete")
	if not is_boss_capstone and (not boss_id.is_empty() or not evidence_flag_id.is_empty()):
		errors.append("facade dossier has partial capstone metadata")
	return errors
