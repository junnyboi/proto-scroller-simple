class_name CombatRunTelemetry
extends RefCounted

const UNKNOWN_ENEMY: StringName = &"unknown"
const UNKNOWN_FAMILY: StringName = &"unknown"
const UNKNOWN_WEAPON: StringName = &"UNKNOWN"
const WEAPON_PRIORITY: Array[StringName] = [
	&"GROUND_SMASH",
	&"JAB_CROSS",
	&"SIEGE_DRILL",
	&"GRAVITY_CRUCIBLE",
	&"MACHINE_GUN",
	&"MISSILE",
	&"LASER",
	&"FLAMETHROWER",
	&"TESLA_TOWER",
	&"ENVIRONMENT",
	UNKNOWN_WEAPON,
]

var highest_combo_tier: int = 0
var total_enemies_defeated: int = 0
var enemy_kills: Dictionary[StringName, int] = {}
var enemy_family_kills: Dictionary[StringName, int] = {}
var weapon_kills: Dictionary[StringName, int] = {}


func register_accepted_event(event: GameplayEvent, authored_combo_tier: int) -> void:
	if event == null or event.kind != GameplayEvent.Kind.ENEMY_DEFEATED:
		return
	highest_combo_tier = maxi(highest_combo_tier, authored_combo_tier)
	total_enemies_defeated += 1
	_increment(enemy_kills, _normalized_id(event.enemy_archetype_id, UNKNOWN_ENEMY))
	_increment(enemy_family_kills, _normalized_id(event.enemy_family_id, UNKNOWN_FAMILY))
	_increment(weapon_kills, _normalized_id(event.weapon_id, UNKNOWN_WEAPON))


func reset_run() -> void:
	highest_combo_tier = 0
	total_enemies_defeated = 0
	enemy_kills.clear()
	enemy_family_kills.clear()
	weapon_kills.clear()


func snapshot() -> Dictionary:
	var preferred: StringName = preferred_weapon_id()
	return {
		"highest_combo_tier": highest_combo_tier,
		"total_enemies_defeated": total_enemies_defeated,
		"unique_enemy_types": enemy_kills.size(),
		"enemy_kills": enemy_kills.duplicate(),
		"enemy_family_kills": enemy_family_kills.duplicate(),
		"weapon_kills": weapon_kills.duplicate(),
		"preferred_weapon": preferred,
		"preferred_weapon_kills": int(weapon_kills.get(preferred, 0)),
	}


func preferred_weapon_id() -> StringName:
	var winner: StringName = UNKNOWN_WEAPON
	var winner_count: int = -1
	for weapon_id: StringName in WEAPON_PRIORITY:
		var count: int = int(weapon_kills.get(weapon_id, 0))
		if count > winner_count:
			winner = weapon_id
			winner_count = count
	for value: Variant in weapon_kills:
		var weapon_id: StringName = StringName(value)
		if weapon_id in WEAPON_PRIORITY:
			continue
		var count: int = int(weapon_kills.get(weapon_id, 0))
		if count > winner_count or (count == winner_count and String(weapon_id) < String(winner)):
			winner = weapon_id
			winner_count = count
	return winner


static func authored_tier_for_progress_units(progress_units: int) -> int:
	if progress_units <= 0:
		return 0
	return ceili(
		float(progress_units) / float(RampageRewardTuning.COMBO_PROGRESS_UNITS_PER_TIER)
	)


static func weapon_id_for_damage_type(damage_type: StringName) -> StringName:
	match damage_type:
		&"ground_smash":
			return &"GROUND_SMASH"
		&"jab_cross", &"punch_shockwave":
			return &"JAB_CROSS"
		&"machine_gun":
			return &"MACHINE_GUN"
		&"missile":
			return &"MISSILE"
		&"laser":
			return &"LASER"
		&"flamethrower":
			return &"FLAMETHROWER"
		&"tesla_tower":
			return &"TESLA_TOWER"
		&"chain_collapse", &"catalyst", &"catalyst_blast", &"crash_impact", \
		&"debris", &"debris_impact", &"explosion", &"volatile":
			return &"ENVIRONMENT"
	return UNKNOWN_WEAPON


static func weapon_id_for_damage_event(event: DamageEvent) -> StringName:
	if event == null:
		return UNKNOWN_WEAPON
	if (event.effect_flags & DamageEvent.FLAG_SIEGE_DRILL) != 0:
		return &"SIEGE_DRILL"
	if (event.effect_flags & DamageEvent.FLAG_GRAVITY_CRUCIBLE) != 0:
		return &"GRAVITY_CRUCIBLE"
	return weapon_id_for_damage_type(event.damage_type)


static func ranked_entries(counts: Dictionary, limit: int = 0) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for value: Variant in counts:
		var identifier: StringName = StringName(value)
		var count: int = maxi(int(counts[value]), 0)
		if count <= 0:
			continue
		entries.append({"id": identifier, "count": count})
	entries.sort_custom(_entry_precedes)
	if limit > 0 and entries.size() > limit:
		entries.resize(limit)
	return entries


static func _entry_precedes(first: Dictionary, second: Dictionary) -> bool:
	var first_count: int = int(first.get("count", 0))
	var second_count: int = int(second.get("count", 0))
	if first_count != second_count:
		return first_count > second_count
	return String(first.get("id", &"")) < String(second.get("id", &""))


static func _normalized_id(identifier: StringName, fallback: StringName) -> StringName:
	return fallback if identifier.is_empty() else identifier


static func _increment(counts: Dictionary[StringName, int], identifier: StringName) -> void:
	counts[identifier] = int(counts.get(identifier, 0)) + 1
