class_name ScrollerStageDefinition
extends Resource

@export var stage_id: StringName = &"BUSINESS_ACT_1"
@export var title_key: String = "stage.business.title"
@export var scene: PackedScene
@export var district: DistrictDefinition


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if stage_id.is_empty() or not L10n.keys_for_locale("en").has(title_key):
		errors.append("stage identity or localized title is missing")
	if scene == null or not scene.can_instantiate():
		errors.append("stage scene is missing")
	elif not _has_city_root():
		errors.append("stage root must extend CitySlice")
	if district == null or district.acts.is_empty():
		errors.append("stage has no authored acts")
		return errors
	for act: DistrictAct in district.acts:
		if act == null or act.beats.is_empty():
			errors.append("act has no beats")
			continue
		for beat: DistrictBeat in act.beats:
			if beat == null or beat.maximum_threat <= 0:
				errors.append("invalid encounter beat")
				continue
			for spawn: EnemySpawnEntry in beat.spawns:
				if spawn == null or not EnemyArchetypeCatalog.is_valid_kind(spawn.kind):
					errors.append("unknown encounter enemy")
	return errors


func _has_city_root() -> bool:
	var state: SceneState = scene.get_state()
	for index: int in range(state.get_node_property_count(0)):
		if state.get_node_property_name(0, index) != &"script":
			continue
		var script: Script = state.get_node_property_value(0, index) as Script
		while script != null:
			if script.get_global_name() == &"CitySlice":
				return true
			script = script.get_base_script()
	return false
