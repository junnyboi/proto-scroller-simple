class_name HybridEncounterResolver
extends RefCounted

const BUSINESS: StringName = &"BUSINESS"
const RESIDENTIAL: StringName = &"RESIDENTIAL"
const VARIANT_SALT: int = 0x0C40112
const VARIANT_ROLL_MODULUS: int = 100


static func resolve_beat(
	base_beat: DistrictBeat,
	district_id: StringName,
	act_index: int,
	beat_index: int,
	run_seed: int
) -> DistrictBeat:
	return resolve_with_trace(
		base_beat,
		district_id,
		act_index,
		beat_index,
		run_seed
	).get("beat") as DistrictBeat


static func resolve_with_trace(
	base_beat: DistrictBeat,
	district_id: StringName,
	act_index: int,
	beat_index: int,
	run_seed: int
) -> Dictionary:
	if base_beat == null:
		return {"beat": null, "substitutions": []}
	var resolved: DistrictBeat = base_beat.duplicate(true) as DistrictBeat
	if district_id != BUSINESS:
		_apply_hybrid_substitutions(resolved, district_id, act_index, beat_index, run_seed)
	var hybrid_kinds: Array[StringName] = _kinds(resolved)
	_apply_district_variant_substitutions(
		resolved,
		district_id,
		act_index,
		beat_index,
		run_seed
	)
	return {
		"beat": resolved,
		"substitutions": _staged_substitutions(base_beat, hybrid_kinds, resolved),
	}


static func substitutions(
	base_beat: DistrictBeat,
	resolved_beat: DistrictBeat
) -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	if base_beat == null or resolved_beat == null:
		return changes
	for index: int in range(mini(base_beat.spawns.size(), resolved_beat.spawns.size())):
		var before: StringName = StringName(base_beat.spawns[index].kind)
		var after: StringName = StringName(resolved_beat.spawns[index].kind)
		if before != after:
			changes.append({"entry_index": index, "before": before, "after": after})
	return changes


static func eligible_hybrids(district_id: StringName) -> Array[StringName]:
	match district_id:
		RESIDENTIAL:
			return [&"reclaimed_breacher", &"graft_runner"]
	return []


static func _apply_hybrid_substitutions(
	resolved: DistrictBeat,
	district_id: StringName,
	act_index: int,
	beat_index: int,
	run_seed: int
) -> void:
	var rotation: int = posmod(run_seed + act_index * 7 + beat_index * 3, 6)
	var preferred: Array[StringName] = _preferred_hybrids(district_id, rotation)
	var used_families: Dictionary[StringName, bool] = {}
	var resolved_threat: int = _resolved_threat(resolved)
	for hybrid_id: StringName in preferred:
		var required_family: StringName = EnemyArchetypeCatalog.family_for(hybrid_id)
		if used_families.has(required_family):
			continue
		for entry: EnemySpawnEntry in resolved.spawns:
			if EnemyArchetypeCatalog.family_for(StringName(entry.kind)) != required_family:
				continue
			var original_kind: StringName = StringName(entry.kind)
			var projected_threat: int = (
				resolved_threat
				- _entry_threat(original_kind)
				+ _entry_threat(hybrid_id)
			)
			if projected_threat > resolved.maximum_threat:
				continue
			entry.kind = String(hybrid_id)
			resolved_threat = projected_threat
			used_families[required_family] = true
			break


static func _apply_district_variant_substitutions(
	resolved: DistrictBeat,
	district_id: StringName,
	act_index: int,
	beat_index: int,
	run_seed: int
) -> void:
	var candidates: Array[StringName] = EnemyArchetypeCatalog.variants_for_district(
		district_id
	)
	if candidates.is_empty() or resolved.spawns.is_empty():
		return
	var rotation: int = posmod(
		run_seed ^ VARIANT_SALT ^ act_index * 97 ^ beat_index * 53,
		candidates.size()
	)
	var resolved_threat: int = _resolved_threat(resolved)
	var used_variants: Dictionary[StringName, bool] = {}
	for offset: int in range(candidates.size()):
		var candidate: StringName = candidates[wrapi(rotation + offset, 0, candidates.size())]
		if used_variants.has(candidate):
			continue
		var required_family: StringName = EnemyArchetypeCatalog.family_for(candidate)
		var start_index: int = posmod(
			run_seed
			+ act_index * 101
			+ beat_index * 59
			+ offset * 37,
			resolved.spawns.size()
		)
		for entry_offset: int in range(resolved.spawns.size()):
			var entry_index: int = wrapi(
				start_index + entry_offset,
				0,
				resolved.spawns.size()
			)
			var entry: EnemySpawnEntry = resolved.spawns[entry_index]
			var original_kind: StringName = StringName(entry.kind)
			if EnemyArchetypeCatalog.family_for(original_kind) != required_family:
				continue
			if _candidate_conflicts_with_composition(candidate, resolved, entry_index):
				continue
			var projected_threat: int = (
				resolved_threat
				- _entry_threat(original_kind)
				+ _entry_threat(candidate)
			)
			if projected_threat > resolved.maximum_threat:
				continue
			if not _variant_roll_passes(
				run_seed,
				district_id,
				act_index,
				beat_index,
				entry_index,
				candidate
			):
				continue
			entry.kind = String(candidate)
			resolved_threat = projected_threat
			used_variants[candidate] = true
			break


static func _variant_roll_passes(
	run_seed: int,
	district_id: StringName,
	act_index: int,
	beat_index: int,
	entry_index: int,
	candidate: StringName
) -> bool:
	var profile: Dictionary = EnemyArchetypeCatalog.profile(candidate)
	var weight: int = clampi(int(profile.get("district_weight", 0)), 0, 20)
	var district_bias: int = 0
	for character_index: int in range(String(district_id).length()):
		district_bias += String(district_id).unicode_at(character_index)
	var candidate_bias: int = 0
	for character_index: int in range(String(candidate).length()):
		candidate_bias += String(candidate).unicode_at(character_index)
	var roll: int = posmod(
		run_seed
		+ district_bias * 13
		+ candidate_bias * 7
		+ act_index * 29
		+ beat_index * 31
		+ entry_index * 43
		+ VARIANT_SALT,
		VARIANT_ROLL_MODULUS
	)
	return roll < mini(95, 28 + weight * 5)


static func _candidate_conflicts_with_composition(
	candidate: StringName,
	beat: DistrictBeat,
	ignored_entry_index: int
) -> bool:
	for tag: StringName in [&"marker", &"healer", &"artillery", &"bomber"]:
		if not _kind_has_tag(candidate, tag):
			continue
		for entry_index: int in range(beat.spawns.size()):
			if entry_index == ignored_entry_index:
				continue
			if _kind_has_tag(StringName(beat.spawns[entry_index].kind), tag):
				return true
	return false


static func _kind_has_tag(kind: StringName, tag: StringName) -> bool:
	if EnemyArchetypeCatalog.has_variant_tag(kind, tag):
		return true
	var profile: Dictionary = EnemyArchetypeCatalog.profile(kind)
	var attack_style: StringName = StringName(profile.get("attack_style", &""))
	match tag:
		&"marker":
			return attack_style in [&"scan", &"choir_ring"]
		&"healer":
			return attack_style == &"repair"
		&"artillery":
			return attack_style in [&"mortar_recoil", &"pod_salvo", &"rail_recoil"]
		&"bomber":
			return attack_style == &"bomb_drop"
	return false


static func _preferred_hybrids(district_id: StringName, rotation: int) -> Array[StringName]:
	var eligible: Array[StringName] = eligible_hybrids(district_id)
	if eligible.is_empty():
		return eligible
	var rotated: Array[StringName] = []
	for offset: int in range(eligible.size()):
		rotated.append(eligible[wrapi(rotation + offset, 0, eligible.size())])
	return rotated


static func _staged_substitutions(
	base_beat: DistrictBeat,
	hybrid_kinds: Array[StringName],
	resolved_beat: DistrictBeat
) -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	for index: int in range(mini(base_beat.spawns.size(), resolved_beat.spawns.size())):
		var before: StringName = StringName(base_beat.spawns[index].kind)
		var hybrid_after: StringName = hybrid_kinds[index]
		var after: StringName = StringName(resolved_beat.spawns[index].kind)
		if before == hybrid_after and hybrid_after == after:
			continue
		changes.append({
			"entry_index": index,
			"before": before,
			"hybrid_after": hybrid_after,
			"after": after,
			"hybrid_applied": before != hybrid_after,
			"variant_applied": hybrid_after != after,
		})
	return changes


static func _kinds(beat: DistrictBeat) -> Array[StringName]:
	var kinds: Array[StringName] = []
	for entry: EnemySpawnEntry in beat.spawns:
		kinds.append(StringName(entry.kind))
	return kinds


static func _resolved_threat(beat: DistrictBeat) -> int:
	var threat: int = 0
	for entry: EnemySpawnEntry in beat.spawns:
		threat += _entry_threat(StringName(entry.kind))
	return threat


static func _entry_threat(kind: StringName) -> int:
	return (
		EnemyArchetypeCatalog.threat_cost(kind)
		* EnemyArchetypeCatalog.spawn_multiplier(kind)
	)
