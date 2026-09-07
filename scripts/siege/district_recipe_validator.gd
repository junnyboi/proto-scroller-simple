class_name DistrictRecipeValidator
extends RefCounted


static func validate(district: DistrictDefinition) -> PackedStringArray:
	var errors: PackedStringArray = []
	for act_index: int in range(district.acts.size()):
		var act: DistrictAct = district.acts[act_index]
		if act.hazard_pressure_budget > RuntimeBudget.HAZARD_PRESSURE:
			errors.append("%s hazard pressure exceeds cap" % act.act_id)
		if act.hazard_events_per_beat > RuntimeBudget.PENDING_HAZARDS:
			errors.append("%s hazard events exceed pending cap" % act.act_id)
		if act.hazard_events_per_beat > act.hazard_pressure_budget:
			errors.append("%s cannot fund authored hazard events" % act.act_id)
		if act_index < 3 and act.hazard_events_per_beat > 0:
			errors.append("%s introduces hazards before late game" % act.act_id)
		for beat: DistrictBeat in act.beats:
			var counts: Dictionary[StringName, int] = {}
			var elites: int = 0
			var threat: int = 0
			var actor_count: int = 0
			for entry: EnemySpawnEntry in beat.spawns:
				var kind: StringName = StringName(entry.kind)
				if not EnemyArchetypeCatalog.is_valid_kind(kind):
					errors.append("%s has invalid enemy kind %s" % [beat.beat_id, kind])
					continue
				var key: StringName = EnemyArchetypeCatalog.reservation_key(kind)
				var multiplier: int = EnemyArchetypeCatalog.spawn_multiplier(kind)
				counts[key] = int(counts.get(key, 0)) + multiplier
				actor_count += multiplier
				threat += EnemyArchetypeCatalog.threat_cost(kind) * multiplier
				elites += 1 if not entry.trait_id.is_empty() else 0
			for key: StringName in counts:
				if int(counts[key]) > _capacity_for_key(key):
					errors.append("%s exceeds %s pool cap" % [beat.beat_id, key])
			if actor_count > RuntimeBudget.PENDING_BEAT_RECORDS:
				errors.append("%s actors exceed pending-record cap" % beat.beat_id)
			if threat > beat.maximum_threat:
				errors.append(
					"%s threat=%d exceeds maximum=%d"
					% [beat.beat_id, threat, beat.maximum_threat]
				)
			if elites > 1:
				errors.append("%s has multiple elites" % beat.beat_id)
	return errors


static func _capacity_for_key(key: StringName) -> int:
	match key:
		&"soldier":
			return RuntimeBudget.SOLDIERS
		&"tank":
			return RuntimeBudget.TANKS
		&"helicopter":
			return RuntimeBudget.HELICOPTERS
		&"procedural_infantry":
			return RuntimeBudget.PROCEDURAL_INFANTRY
		&"procedural_light":
			return RuntimeBudget.PROCEDURAL_LIGHT
		&"procedural_heavy":
			return RuntimeBudget.PROCEDURAL_HEAVY
		&"procedural_air":
			return RuntimeBudget.PROCEDURAL_AIR
		&"procedural_siege":
			return RuntimeBudget.PROCEDURAL_SIEGE
		_:
			return 0
