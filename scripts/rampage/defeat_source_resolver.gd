class_name DefeatSourceResolver
extends RefCounted

const UNKNOWN: StringName = &"unknown"
const ENVIRONMENT: StringName = &"environment"


static func resolve(event: DamageEvent, city: CitySlice = null) -> StringName:
	if event == null:
		return UNKNOWN
	var enemy_id: StringName = _source_enemy_id(event.source)
	if not enemy_id.is_empty():
		return enemy_id
	if event.source is BossAttackArea2D:
		var boss_id: StringName = _active_boss_id(city)
		return StringName("boss:%s" % String(boss_id).to_lower())
	if (
		event.effect_flags & DamageEvent.FLAG_HAZARD != 0
		or event.damage_type in [&"environment", &"hazard", &"debris", &"collapse"]
	):
		return ENVIRONMENT
	return UNKNOWN


static func _source_enemy_id(source: Node) -> StringName:
	var cursor: Node = source
	while cursor != null:
		if cursor is EnemyActor2D:
			return _enemy_id(cursor as EnemyActor2D)
		cursor = cursor.get_parent()
	return &""


static func _enemy_id(enemy: EnemyActor2D) -> StringName:
	var boss_id: StringName = StringName(enemy.get_meta(&"enemy_boss_id", &""))
	if not boss_id.is_empty():
		return StringName("boss:%s" % String(boss_id).to_lower())
	var support_id: StringName = StringName(enemy.get_meta(&"boss_support_id", &""))
	if not support_id.is_empty():
		return support_id
	var archetype_id: StringName = StringName(enemy.get_meta(&"enemy_archetype", &""))
	if not archetype_id.is_empty():
		return archetype_id
	if enemy is SoldierEnemy:
		return &"soldier"
	if enemy is TankEnemy:
		return &"tank"
	if enemy is HelicopterEnemy:
		return &"helicopter"
	return UNKNOWN


static func _active_boss_id(city: CitySlice) -> StringName:
	if (
		city != null
		and city.urban_siege != null
		and city.urban_siege.boss_session != null
		and city.urban_siege.boss_session.active_definition != null
	):
		return city.urban_siege.boss_session.active_definition.boss_id
	return &"COMMAND_UNIT"
