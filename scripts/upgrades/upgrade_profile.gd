class_name UpgradeProfile
extends Resource

@export var upgrade_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var category: StringName
@export var icon: Texture2D
@export_range(1, 5, 1) var max_rank: int = 1
@export var runtime_key: StringName
@export_range(1, 1000, 1) var offer_weight: int = 100
@export var enabled: bool = true
@export var tags: PackedStringArray
@export var incompatible_tags: PackedStringArray
@export var acquisition_audio_key: StringName
@export var sort_order: int = 0


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if upgrade_id.is_empty():
		errors.append("upgrade_id is empty")
	if display_name.is_empty():
		errors.append("%s display_name is empty" % upgrade_id)
	if description.is_empty():
		errors.append("%s description is empty" % upgrade_id)
	if runtime_key.is_empty():
		errors.append("%s runtime_key is empty" % upgrade_id)
	if max_rank < 1 or max_rank > 5:
		errors.append("%s max_rank=%d" % [upgrade_id, max_rank])
	if offer_weight <= 0:
		errors.append("%s offer_weight=%d" % [upgrade_id, offer_weight])
	for tag: String in tags:
		if incompatible_tags.has(tag):
			errors.append("%s conflicts with own tag %s" % [upgrade_id, tag])
	return errors
