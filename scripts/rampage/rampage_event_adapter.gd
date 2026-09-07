class_name RampageEventAdapter
extends RefCounted

var _session: RampageSession


func _init(session: RampageSession) -> void:
	_session = session


func building_damage(
	amount: float,
	event: DamageEvent,
	building: StructuralBuilding2D,
	robot: GiantRobotController
) -> bool:
	var gameplay_event: GameplayEvent = GameplayEvent.new(
		&"",
		0,
		GameplayEvent.Kind.DAMAGE_APPLIED,
		&"",
		roundi(amount * 10.0),
		0.0,
		false,
		event.hit_position
	)
	return _publish_damage(gameplay_event, event, building, robot)


func cell_destroyed(
	column: int,
	row: int,
	event: DamageEvent,
	building: StructuralBuilding2D,
	robot: GiantRobotController
) -> bool:
	var cell: Destructible2D = building.get_cell(column, row)
	var profile: StructuralMaterialProfile = building.get_material_profile(column, row)
	var gameplay_event: GameplayEvent = GameplayEvent.new(
		StringName("%s:cell:%d:%d" % [_persistent_id(building), column, row]),
		0,
		GameplayEvent.Kind.CELL_DESTROYED,
		GameplayEvent.CELL_BREACH,
		300,
		12.0,
		true,
		cell.global_position,
		profile.material_id
	)
	return _publish_damage(gameplay_event, event, cell, robot)


func chain_started(
	kind: StringName,
	event: DamageEvent,
	building: StructuralBuilding2D,
	robot: GiantRobotController
) -> bool:
	var gameplay_event: GameplayEvent = GameplayEvent.new(
		StringName(
			"%s:chain:%s:%d"
			% [_persistent_id(building), kind, building.chain_reaction_count]
		),
		0,
		GameplayEvent.Kind.CHAIN_COLLAPSE,
		GameplayEvent.CHAIN_COLLAPSE,
		600,
		24.0,
		true,
		building.global_position
	)
	return _publish_damage(gameplay_event, event, building, robot, kind)


func building_destroyed(
	event: DamageEvent,
	building: StructuralBuilding2D,
	robot: GiantRobotController
) -> bool:
	var gameplay_event: GameplayEvent = GameplayEvent.new(
		StringName("%s:destroyed" % _persistent_id(building)),
		0,
		GameplayEvent.Kind.DAMAGE_APPLIED,
		&"",
		1000,
		0.0,
		false,
		building.global_position
	)
	return _publish_damage(gameplay_event, event, building, robot)


func prop_destroyed(
	prop: DestructibleProp2D,
	event: DamageEvent,
	points: int,
	robot: GiantRobotController,
	_is_car: bool
) -> bool:
	var gameplay_event: GameplayEvent = GameplayEvent.new(
		StringName("%s:broken" % _persistent_id(prop)),
		0,
		GameplayEvent.Kind.PROP_DESTROYED,
		GameplayEvent.PROP_BREAK,
		points,
		6.0,
		true,
		prop.global_position
	)
	return _publish_damage(gameplay_event, event, prop, robot)


func enemy_defeated(
	enemy: EnemyActor2D,
	event: DamageEvent,
	points: int,
	robot: GiantRobotController
) -> bool:
	var is_soldier: bool = enemy is SoldierEnemy
	var named_boss: bool = enemy.boss_mode
	var reward_points: int = RampageRewardTuning.enemy_reward_points(points, named_boss)
	var gameplay_event: GameplayEvent = GameplayEvent.new(
		StringName(
			"enemy:%d:%d" % [enemy.get_instance_id(), enemy.activation_generation]
		),
		0,
		GameplayEvent.Kind.ENEMY_DEFEATED,
		GameplayEvent.SOLDIER_LAUNCH if is_soldier else GameplayEvent.ENEMY_KILL,
		reward_points,
		_enemy_momentum_delta(enemy),
		true,
		enemy.global_position
	)
	gameplay_event.score_points = RampageRewardTuning.enemy_score_points(
		reward_points,
		named_boss
	)
	gameplay_event.combo_progress_units = (
		RampageRewardTuning.enemy_combo_progress_units(named_boss)
	)
	gameplay_event.enemy_archetype_id = _enemy_archetype_id(enemy)
	gameplay_event.enemy_family_id = _enemy_family_id(enemy, gameplay_event.enemy_archetype_id)
	gameplay_event.weapon_id = CombatRunTelemetry.weapon_id_for_damage_event(event)
	return _publish_damage(gameplay_event, event, enemy, robot)


func wreck_scrapped(
	wreck: EnemyWreck2D,
	event: DamageEvent,
	points: int,
	robot: GiantRobotController
) -> bool:
	var is_tank: bool = wreck.wreck_kind == &"tank"
	var gameplay_event: GameplayEvent = GameplayEvent.new(
		StringName("wreck:%d:%d" % [wreck.get_instance_id(), event.attack_id]),
		0,
		GameplayEvent.Kind.WRECK_SCRAPPED,
		GameplayEvent.TANK_SCRAP if is_tank else &"",
		points,
		0.0,
		is_tank,
		wreck.global_position,
		&"steel"
	)
	return _publish_damage(gameplay_event, event, wreck, robot)


func aerial_hit(
	body: DebrisBody2D,
	event: DamageEvent,
	target: EnemyActor2D,
	robot: GiantRobotController
) -> bool:
	var gameplay_event: GameplayEvent = GameplayEvent.new(
		StringName(
			"air:%d:%d:%d" % [
				event.root_attack_id,
				target.get_instance_id(),
				target.activation_generation,
			]
		),
		0,
		GameplayEvent.Kind.AIRBORNE_DEBRIS_HIT,
		GameplayEvent.AIR_DEBRIS_HIT,
		250,
		20.0,
		true,
		event.hit_position,
		body.material_id()
	)
	return _publish_damage(gameplay_event, event, target, robot)


func player_damage_received(
	event: DamageEvent,
	accepted_damage: float,
	robot: GiantRobotController
) -> bool:
	if accepted_damage <= 0.0:
		return false
	var damage_key: StringName = (
		StringName("player_damage:%d" % event.attack_id)
		if event.attack_id != 0
		else &""
	)
	var damage_published: bool = _publish_damage(GameplayEvent.new(
		damage_key,
		0,
		GameplayEvent.Kind.PLAYER_DAMAGE_TAKEN,
		&"",
		0,
		0.0,
		false,
		event.hit_position
	), event, robot)
	if accepted_damage < 30.0:
		return damage_published
	var dedupe_key: StringName = (
		StringName("heavy_hit:%d" % event.attack_id)
		if event.attack_id != 0
		else &""
	)
	var gameplay_event: GameplayEvent = GameplayEvent.new(
		dedupe_key,
		0,
		GameplayEvent.Kind.PLAYER_HEAVY_HIT,
		&"",
		0,
		-12.0,
		false,
		event.hit_position
	)
	var heavy_published: bool = _publish_damage(gameplay_event, event, robot)
	return damage_published or heavy_published


func legacy_score(points: int) -> bool:
	if points <= 0:
		return false
	return _session.publish(GameplayEvent.new(
		&"",
		0,
		GameplayEvent.Kind.DAMAGE_APPLIED,
		&"",
		points
	))


func _publish_damage(
	gameplay_event: GameplayEvent,
	damage_event: DamageEvent,
	target: Node = null,
	source_fallback: Node = null,
	cause_override: StringName = &""
) -> bool:
	if gameplay_event == null or damage_event == null:
		return false
	gameplay_event.attack_id = damage_event.attack_id
	gameplay_event.root_attack_id = damage_event.root_attack_id
	gameplay_event.causal_depth = damage_event.causal_depth
	var source: Node = damage_event.source if damage_event.source != null else source_fallback
	gameplay_event.source_id = source.get_instance_id() if source != null else 0
	gameplay_event.target_id = target.get_instance_id() if target != null else 0
	gameplay_event.cause = (
		cause_override if not cause_override.is_empty() else damage_event.damage_type
	)
	gameplay_event.presentation_direction = damage_event.direction
	gameplay_event.presentation_speed = damage_event.impulse_per_mass
	gameplay_event.debris_units = _presentation_debris_units(gameplay_event.kind, target)
	return _session.publish(gameplay_event)


func _presentation_debris_units(kind: GameplayEvent.Kind, target: Node) -> int:
	match kind:
		GameplayEvent.Kind.CELL_DESTROYED:
			var cell: Destructible2D = target as Destructible2D
			return cell.gameplay_chunk_count if cell != null else 0
		GameplayEvent.Kind.PROP_DESTROYED:
			return 2
		GameplayEvent.Kind.WRECK_SCRAPPED:
			return 3
		GameplayEvent.Kind.ENEMY_DEFEATED:
			return 1 if target is TankEnemy or target is HelicopterEnemy else 0
	return 0


func _enemy_momentum_delta(enemy: EnemyActor2D) -> float:
	if enemy is TankEnemy:
		return 16.0
	if enemy is HelicopterEnemy:
		return 0.0
	return 8.0


func _enemy_archetype_id(enemy: EnemyActor2D) -> StringName:
	var identifier: StringName = CombatRunTelemetry.UNKNOWN_ENEMY
	var boss_id: StringName = StringName(enemy.get_meta(&"enemy_boss_id", &""))
	if not boss_id.is_empty():
		identifier = StringName("boss:%s" % String(boss_id).to_lower())
	elif enemy is ProceduralEnemy and not (enemy as ProceduralEnemy).boss_support_id.is_empty():
		identifier = (enemy as ProceduralEnemy).boss_support_id
	else:
		var metadata_id: StringName = StringName(enemy.get_meta(&"enemy_archetype", &""))
		if not metadata_id.is_empty():
			identifier = metadata_id
		elif enemy is SoldierEnemy:
			identifier = &"soldier"
		elif enemy is TankEnemy:
			identifier = &"tank"
		elif enemy is HelicopterEnemy:
			identifier = &"helicopter"
	return identifier


func _enemy_family_id(enemy: EnemyActor2D, archetype_id: StringName) -> StringName:
	var metadata_family: StringName = StringName(enemy.get_meta(&"enemy_family", &""))
	if not metadata_family.is_empty():
		return metadata_family
	if String(archetype_id).begins_with("boss:"):
		return &"boss"
	var family: StringName = EnemyArchetypeCatalog.family_for(archetype_id)
	return family if not family.is_empty() else CombatRunTelemetry.UNKNOWN_FAMILY


func _persistent_id(target: Node) -> String:
	if target != null and target.has_meta(&"stream_object_id"):
		return String(target.get_meta(&"stream_object_id"))
	return "instance:%d" % (target.get_instance_id() if target != null else 0)
