# gdlint: disable=max-returns
class_name CommandBossSession
extends Node

signal state_changed(state: StringName)
signal armor_changed(current: float, maximum: float)
signal body_changed(current: float, maximum: float)
signal completed(elapsed_seconds: float)
signal defeated_wreck_committed(definition: BossEncounterDefinition, world_position: Vector2)
signal feedback_changed

const STATE_IDLE: StringName = &"IDLE"
const STATE_SCREEN: StringName = &"SCREEN"
const STATE_BARRAGE: StringName = &"BARRAGE"
const STATE_EXPOSED: StringName = &"EXPOSED"
const STATE_WRECK: StringName = &"WRECK_FINISHER"
const STATE_COMPLETION_PENDING: StringName = &"COMPLETION_PENDING"
const STATE_COMPLETE: StringName = &"COMPLETE"
const ARMOR: float = (
	BossCampaignCatalog.BASE_ARMOR * BossCampaignCatalog.BOSS_DURABILITY_MULTIPLIER
)
const HEALTH: float = (
	BossCampaignCatalog.BASE_HEALTH * BossCampaignCatalog.BOSS_DURABILITY_MULTIPLIER
)
const SCREEN_DURATION: float = 4.0
const TARGET_DURATION: float = 60.0
const CORE_SHOCKWAVE_CAMERA_IMPULSE: float = 10.0
const AUTOMATIC_RUBBLE_ATTACK_ID_BASE: int = 9_100_000
const BOSS_REPAIR_DROP_OFFSETS: Array[Vector2] = [
	Vector2(-82.0, -96.0),
	Vector2(0.0, -126.0),
	Vector2(82.0, -96.0),
]
var dependencies: UrbanSiegeDependencies
var state: StringName = STATE_IDLE
var boss: TankEnemy
var boss_wreck: EnemyWreck2D
var utility_pool: BossUtilityPool
var royal_finale: BossRoyalFinaleController
var active_definition: BossEncounterDefinition
var elapsed_seconds: float = 0.0
var generation_token: int = 0
var last_completed_wreck_position: Vector2 = Vector2.ZERO
var last_repair_drop_count: int = 0
var core_shockwave_camera_impulse_count: int = 0
var automatic_rubble_commit_count: int = 0
var path_clear_camera_reveal_count: int = 0
var _state_elapsed: float = 0.0
var _screen_duration: float = SCREEN_DURATION
var _pending_attempt_restore: Dictionary = {}
var _completion_payload: Dictionary = {}
var _royal_finisher_attacks: Dictionary[int, bool] = {}
var _royal_finisher_roots: Dictionary[int, bool] = {}


func setup(p_dependencies: UrbanSiegeDependencies) -> void:
	dependencies = p_dependencies
	dependencies.encounter_runtime.enemy_died.connect(_on_enemy_died)
	dependencies.remains_factory.wreck_spawned.connect(_on_wreck_spawned)
	dependencies.remains_factory.wreck_scrapped.connect(_on_wreck_scrapped)
	utility_pool = BossUtilityPool.new()
	utility_pool.name = "BossUtilityPool"
	add_child(utility_pool)
	utility_pool.configure_runtime(
		dependencies.encounter_runtime,
		dependencies.projectile_pool
	)
	utility_pool.defeat_spectacle.completed.connect(
		_on_defeat_spectacle_completed
	)
	utility_pool.vertical_slice.attack_changed.connect(_on_boss_attack_changed)
	utility_pool.escalation.attack_changed.connect(_on_boss_attack_changed)
	utility_pool.radial_shockwave.core_shockwave_released.connect(
		_on_core_shockwave_released
	)
	royal_finale = BossRoyalFinaleController.new()
	royal_finale.name = "BossRoyalFinaleController"
	royal_finale.setup(utility_pool, dependencies.encounter_runtime)
	royal_finale.severance_receiver_moved.connect(_on_severance_receiver_moved)
	royal_finale.attack_changed.connect(_on_royal_boss_attack_changed)
	add_child(royal_finale)


func start() -> bool:
	return _start_encounter(null)


func start_definition(definition: BossEncounterDefinition) -> bool:
	if definition == null or not definition.validation_errors().is_empty():
		return false
	return _start_encounter(definition)


func _start_encounter(definition: BossEncounterDefinition) -> bool:
	if state != STATE_IDLE and state != STATE_COMPLETE:
		return false
	if utility_pool.defeat_spectacle != null:
		utility_pool.defeat_spectacle.deactivate()
	generation_token = utility_pool.begin_generation()
	active_definition = definition
	var spawn_position: Vector2 = dependencies.encounter_runtime.resolve_spawn_position(
		Vector2(0.0, 551.0),
		&"AHEAD"
	)
	var resident_bounds: Vector2 = dependencies.city.world_stream.resident_bounds()
	spawn_position.x = clampf(
		maxf(spawn_position.x, dependencies.robot.global_position.x + 900.0),
		resident_bounds.x + 200.0,
		resident_bounds.y - 200.0
	)
	boss = dependencies.encounter_runtime.acquire(
		&"tank",
		spawn_position,
		&"ANCHOR_TANK",
		&"COMMAND"
	) as TankEnemy
	if boss == null:
		utility_pool.cleanup_generation(generation_token)
		active_definition = null
		return false
	var exposed_health_multiplier: float = float(RuntimeTweakAccess.next_spawn_value(
		&"boss.exposed_health_multiplier", 1.0
	))
	_screen_duration = float(RuntimeTweakAccess.next_spawn_value(
		&"boss.intro_screen_seconds",
		SCREEN_DURATION if active_definition == null else active_definition.screen_seconds
	))
	boss.set_meta(
		&"tuning_reinforcement_interval_multiplier",
		float(RuntimeTweakAccess.next_spawn_value(
			&"boss.reinforcement_interval_multiplier", 1.0
		))
	)
	if definition != null:
		boss.global_position.y = BossRig2D.road_contact_y_for_preset(
			definition.rig_preset
		)
	if active_definition == null:
		boss.set_meta(&"enemy_boss_id", &"COMMAND_UNIT")
		boss.configure_boss(ARMOR, HEALTH * exposed_health_multiplier)
	else:
		boss.set_meta(&"enemy_boss_id", active_definition.boss_id)
		boss.configure_boss(
			active_definition.armor,
			active_definition.health * exposed_health_multiplier
		)
		_configure_campaign_runtime()
	if not boss.boss_armor_changed.is_connected(_on_boss_armor_changed):
		boss.boss_armor_changed.connect(_on_boss_armor_changed)
	if not boss.boss_armor_broken.is_connected(_on_boss_armor_broken):
		boss.boss_armor_broken.connect(_on_boss_armor_broken)
	if not boss.health_changed.is_connected(_on_boss_health_changed):
		boss.health_changed.connect(_on_boss_health_changed)
	elapsed_seconds = 0.0
	_state_elapsed = 0.0
	_completion_payload.clear()
	last_completed_wreck_position = Vector2.ZERO
	last_repair_drop_count = 0
	automatic_rubble_commit_count = 0
	path_clear_camera_reveal_count = 0
	_royal_finisher_attacks.clear()
	_royal_finisher_roots.clear()
	_apply_pending_attempt_restore()
	_set_state(STATE_SCREEN)
	boss.set_attack_gate(false)
	armor_changed.emit(boss.boss_armor, boss.boss_max_armor)
	return true


func advance(delta: float) -> void:
	if state == STATE_IDLE or state == STATE_COMPLETE:
		return
	elapsed_seconds += delta
	_state_elapsed += delta
	if utility_pool != null and state != STATE_SCREEN:
		utility_pool.vertical_slice.advance(delta)
		utility_pool.escalation.advance(delta)
		royal_finale.advance(delta)
	_sync_rig_facing()
	if utility_pool != null and utility_pool.rig != null:
		utility_pool.rig.advance_animation(delta)
	if state == STATE_SCREEN and _state_elapsed >= _screen_duration:
		if boss != null:
			boss.set_attack_gate(true)
		_set_state(STATE_BARRAGE)


func stop() -> void:
	_next_generation()
	if utility_pool != null and utility_pool.defeat_spectacle != null:
		utility_pool.defeat_spectacle.deactivate()
	if boss != null and boss.active:
		dependencies.encounter_runtime.release(boss)
	if boss_wreck != null:
		dependencies.remains_factory.release_wreck(boss_wreck)
	boss = null
	boss_wreck = null
	active_definition = null
	last_completed_wreck_position = Vector2.ZERO
	if state != STATE_COMPLETE:
		_set_state(STATE_IDLE)


func reset_state() -> void:
	stop()
	_set_state(STATE_IDLE)


func active() -> bool:
	return state != STATE_IDLE and state != STATE_COMPLETE


func defeat_celebration_active() -> bool:
	return (
		utility_pool != null
		and utility_pool.defeat_spectacle != null
		and utility_pool.defeat_spectacle.active
	)


func capture_attempt_state() -> Dictionary:
	return {
		"state": STATE_SCREEN,
		"elapsed_seconds": elapsed_seconds,
		"state_elapsed": _state_elapsed,
		"definition_id": (
			active_definition.boss_id if active_definition != null else &""
		),
		"armor": boss.boss_armor if boss != null else ARMOR,
		"health": boss.current_health if boss != null else HEALTH,
		"vertical_slice": (
			utility_pool.vertical_slice.capture_state()
			if utility_pool.vertical_slice.active()
			else {}
		),
		"escalation": (
			utility_pool.escalation.capture_state()
			if utility_pool.escalation.active()
			else {}
		),
		"royal_finale": (
			royal_finale.capture_state() if royal_finale.active() else {}
		),
	}


func restore_attempt_state(snapshot: Dictionary) -> void:
	stop()
	_pending_attempt_restore = snapshot.duplicate(true)


func completion_payload() -> Dictionary:
	return _completion_payload.duplicate(true)


func mark_completion_pending() -> void:
	_set_state(STATE_COMPLETION_PENDING)


func mark_completion_committed() -> void:
	_set_state(STATE_COMPLETE)


func live_boss_feedback() -> Dictionary:
	if utility_pool == null:
		return {}
	if state == STATE_COMPLETION_PENDING:
		return {
			"objective": L10n.t("boss.objective.completion_pending"),
			"attack": L10n.t("boss.attack.none"),
		}
	if state == STATE_WRECK:
		return {
			"objective": L10n.t("boss.objective.completion_pending"),
			"attack": L10n.t("boss.attack.none"),
		}
	var feedback: Dictionary = {}
	if utility_pool.vertical_slice.active():
		feedback = utility_pool.vertical_slice.hud_feedback()
	elif utility_pool.escalation.active():
		feedback = utility_pool.escalation.hud_feedback()
	elif royal_finale.active():
		feedback = royal_finale.hud_feedback()
	return feedback


func _apply_pending_attempt_restore() -> void:
	if _pending_attempt_restore.is_empty() or boss == null:
		return
	var definition_id: StringName = StringName(_pending_attempt_restore.get("definition_id", &""))
	if active_definition == null or definition_id != active_definition.boss_id:
		_pending_attempt_restore.clear()
		return
	elapsed_seconds = float(_pending_attempt_restore.get("elapsed_seconds", 0.0))
	_state_elapsed = 0.0
	boss.boss_armor = clampf(
		float(_pending_attempt_restore.get("armor", active_definition.armor)),
		0.0,
		boss.boss_max_armor
	)
	boss.current_health = clampf(
		float(_pending_attempt_restore.get("health", active_definition.health)),
		0.0,
		boss.max_health
	)
	var slice_state: Dictionary = _pending_attempt_restore.get("vertical_slice", {})
	if not slice_state.is_empty() and utility_pool.vertical_slice.active():
		utility_pool.vertical_slice.restore_state(slice_state)
	var escalation_state: Dictionary = _pending_attempt_restore.get("escalation", {})
	if not escalation_state.is_empty() and utility_pool.escalation.active():
		utility_pool.escalation.restore_state(escalation_state)
	var royal_state: Dictionary = _pending_attempt_restore.get("royal_finale", {})
	if not royal_state.is_empty() and royal_finale.active():
		royal_finale.restore_state(royal_state)
	_pending_attempt_restore.clear()


func _on_boss_health_changed(current: float, maximum: float) -> void:
	_sync_controller_phase()
	body_changed.emit(current, maximum)


func _on_boss_armor_changed(current: float, maximum: float) -> void:
	if _is_choir_prime():
		var connection_count: int = floori(
			(maximum - current) / maxf(active_definition.armor_milestone_step, 1.0)
		)
		while royal_finale.armor_connections < connection_count:
			royal_finale.register_armor_connection()
		if connection_count >= BossRoyalFinaleController.CONNECTION_COUNT:
			_commit_crown_pylon_transaction()
	elif utility_pool.vertical_slice.active():
		var connection_count: int = floori(
			(maximum - current) / maxf(active_definition.armor_milestone_step, 1.0)
		)
		while utility_pool.vertical_slice.armor_connections < connection_count:
			utility_pool.vertical_slice.register_armor_connection()
	elif utility_pool.escalation.active():
		var connection_count: int = floori(
			(maximum - current) / maxf(active_definition.armor_milestone_step, 1.0)
		)
		while utility_pool.escalation.armor_connections < connection_count:
			utility_pool.escalation.register_armor_connection()
	armor_changed.emit(current, maximum)


func _on_boss_armor_broken() -> void:
	utility_pool.rig.set_armor_target_active(false)
	var slice_state: Dictionary = (
		utility_pool.vertical_slice.capture_state()
		if utility_pool.vertical_slice.active()
		else {}
	)
	var escalation_state: Dictionary = (
		utility_pool.escalation.capture_state()
		if utility_pool.escalation.active()
		else {}
	)
	var royal_state: Dictionary = (
		royal_finale.capture_state() if royal_finale.active() else {}
	)
	_next_generation()
	if active_definition != null:
		_configure_campaign_runtime()
		if not slice_state.is_empty() and utility_pool.vertical_slice.active():
			utility_pool.vertical_slice.restore_state(slice_state)
		if not escalation_state.is_empty() and utility_pool.escalation.active():
			utility_pool.escalation.restore_state(escalation_state)
		if not royal_state.is_empty() and royal_finale.active():
			royal_finale.restore_state(royal_state)
		if active_definition.phases.size() > 1:
			utility_pool.controller.begin_phase(
				active_definition.phases[1],
				generation_token
			)
	_set_state(STATE_EXPOSED)


func _configure_campaign_runtime() -> void:
	var portrait: bool = (
		dependencies.city != null
		and dependencies.city.get_viewport_rect().size.y
		> dependencies.city.get_viewport_rect().size.x
	)
	utility_pool.rig.configure(active_definition, boss, portrait)
	boss.set_hidden_authority(true)
	var campaign: BossCampaignDirector = (
		dependencies.city.urban_siege.boss_campaign
		if dependencies.city != null and dependencies.city.urban_siege != null
		else null
	)
	if (
		campaign != null
		and campaign.arena_lease.active
		and active_definition.summon_uses_arena_landmark
	):
		utility_pool.arena_adapter.bind(
			campaign.arena_lease.arena_building,
			active_definition
		)
	else:
		utility_pool.arena_adapter.unbind()
	if not active_definition.phases.is_empty():
		utility_pool.controller.begin_phase(
			active_definition.phases[0],
			generation_token
		)
	if active_definition.boss_id in [
		&"SETTLEMENT_ENGINE_S04", &"SAMARITAN_15",
	]:
		utility_pool.vertical_slice.start(
			active_definition,
			generation_token,
			boss.global_position,
			portrait
		)
	elif active_definition.boss_id in [
		&"MIMESIS_04", &"CANTOR_31_PALE_ENGINE",
	]:
		utility_pool.escalation.start(
			active_definition,
			generation_token,
			boss.global_position,
			portrait
		)
	elif active_definition.boss_id == &"CHOIR_PRIME":
		royal_finale.start(
			active_definition,
			generation_token,
			boss.global_position,
			portrait
		)


func _is_choir_prime() -> bool:
	return active_definition != null and active_definition.boss_id == &"CHOIR_PRIME"


func _on_enemy_died(enemy: EnemyActor2D, _event: DamageEvent, _points: int) -> void:
	if enemy == boss:
		_capture_completion_payload()
		boss.set_attack_gate(false)
		utility_pool.defeat_spectacle.activate(
			enemy.global_position + Vector2(0.0, -96.0),
			dependencies.city.camera_rig
		)


func _capture_completion_payload() -> void:
	if utility_pool.vertical_slice.active():
		utility_pool.vertical_slice.reveal_archive()
		utility_pool.vertical_slice.rescue_remaining_pods()
		_completion_payload = utility_pool.vertical_slice.completion_payload()
		utility_pool.vertical_slice.preserve_completion_state()
	elif utility_pool.escalation.active():
		if active_definition.boss_id == &"MIMESIS_04":
			utility_pool.escalation.play_continuity_record()
		else:
			utility_pool.escalation.export_record_visible = true
		_completion_payload = utility_pool.escalation.completion_payload()
		utility_pool.escalation.preserve_completion_state()


func _on_wreck_spawned(enemy: EnemyActor2D, wreck: EnemyWreck2D) -> void:
	if enemy != boss:
		return
	if _completion_payload.is_empty():
		_capture_completion_payload()
	var royal_state: Dictionary = (
		royal_finale.capture_state() if royal_finale.active() else {}
	)
	var defeated_position: Vector2 = boss.global_position
	var defeated_direction: StringName = _rig_facing()
	generation_token = utility_pool.begin_wreck_generation()
	boss_wreck = wreck
	boss_wreck.configure_automatic_scrap()
	boss_wreck.set_wreck_visual_visible(false)
	utility_pool.rig.freeze_defeated(defeated_position, defeated_direction)
	if (
		dependencies != null
		and dependencies.city != null
		and dependencies.city.camera_rig != null
		and dependencies.city.camera_rig.begin_path_clear_reveal(
			defeated_position.x + BossArenaBarrier2D.OFFSET_FROM_BOSS_X
		)
	):
		path_clear_camera_reveal_count += 1
	if active_definition != null:
		if _is_choir_prime():
			_start_royal_wreck_runtime(defeated_position)
			if not royal_state.is_empty():
				royal_finale.restore_state(royal_state)
			var snapshot: FinaleEligibilitySnapshot = _snapshot_royal_eligibility()
			royal_finale.begin_wreck(snapshot)
		utility_pool.configure_wreck_receivers(null, null)
	_set_state(STATE_WRECK)
	if not utility_pool.defeat_spectacle.active:
		call_deferred("_on_defeat_spectacle_completed")


func _on_defeat_spectacle_completed() -> void:
	if state != STATE_WRECK or boss_wreck == null or boss_wreck.scrapped_state:
		return
	if _is_choir_prime():
		_resolve_automatic_royal_outcome()
	var attack_id: int = AUTOMATIC_RUBBLE_ATTACK_ID_BASE + generation_token
	var auto_event: DamageEvent = DamageEvent.new(
		attack_id,
		dependencies.robot,
		maxf(boss_wreck.scrap_health, 1.0),
		&"boss_auto_rubble",
		boss_wreck.global_position,
		Vector2.RIGHT,
		220.0,
		attack_id
	)
	if boss_wreck.scrap_automatically(auto_event):
		automatic_rubble_commit_count += 1


func _resolve_automatic_royal_outcome() -> void:
	var snapshot: FinaleEligibilitySnapshot = royal_finale.finale_snapshot
	var outcome: int = BossOutcome.PURGE
	if snapshot != null and snapshot.disentangle_eligible:
		if royal_finale.complete_severance_immediately():
			outcome = BossOutcome.DISENTANGLE
	else:
		royal_finale.cancel_pressure()
	_completion_payload = royal_finale.completion_payload(outcome)
	royal_finale.preserve_completion_state()


func _start_royal_wreck_runtime(world_position: Vector2) -> void:
	var portrait: bool = (
		dependencies.city != null
		and dependencies.city.get_viewport_rect().size.y
		> dependencies.city.get_viewport_rect().size.x
	)
	royal_finale.start(
		active_definition,
		generation_token,
		world_position,
		portrait
	)


func _on_wreck_scrapped(wreck: EnemyWreck2D, _event: DamageEvent, _points: int) -> void:
	if wreck != boss_wreck:
		return
	last_completed_wreck_position = wreck.global_position
	var repair_drop_count: int = _boss_repair_drop_count()
	defeated_wreck_committed.emit(active_definition, last_completed_wreck_position)
	_next_generation()
	utility_pool.present_boss_rubble(last_completed_wreck_position)
	last_repair_drop_count = _spawn_boss_repair_pickups(
		last_completed_wreck_position,
		repair_drop_count
	)
	boss_wreck = null
	_set_state(STATE_COMPLETE)
	completed.emit(elapsed_seconds)


func _boss_repair_drop_count() -> int:
	if active_definition == null:
		return 2
	return 2 if active_definition.boss_id in [
		&"SETTLEMENT_ENGINE_S04", &"SAMARITAN_15",
	] else 3


func _spawn_boss_repair_pickups(origin: Vector2, requested_count: int) -> int:
	if (
		dependencies == null
		or dependencies.city == null
		or dependencies.city.urban_siege == null
		or dependencies.city.urban_siege.catalysts == null
	):
		return 0
	var spawned: int = 0
	for index: int in range(mini(requested_count, BOSS_REPAIR_DROP_OFFSETS.size())):
		var pickup: ChassisRepairPickup2D = (
			dependencies.city.urban_siege.catalysts.spawn_repair_pickup(
				origin + BOSS_REPAIR_DROP_OFFSETS[index],
				ChassisRepairPickup2D.REPAIR_AMOUNT
				* RampageRewardTuning.NAMED_BOSS_REWARD_MULTIPLIER
			)
		)
		if pickup != null:
			spawned += 1
	return spawned


func _commit_crown_pylon_transaction() -> bool:
	if not _is_choir_prime() or dependencies.city == null:
		return false
	var choir: ProjectChoirRuntime = dependencies.city.project_choir_runtime
	return choir != null and choir.commit_crown_pylon_transaction()


func _snapshot_royal_eligibility() -> FinaleEligibilitySnapshot:
	var choir: ProjectChoirRuntime = dependencies.city.project_choir_runtime
	if choir == null:
		return FinaleEligibilitySnapshot.new()
	return choir.snapshot_finale_eligibility()


func _on_wreck_receiver_damage(
	receiver: BossWreckReceiver2D,
	event: DamageEvent
) -> bool:
	if (
		receiver == null
		or event == null
		or boss_wreck == null
		or boss_wreck.scrapped_state
		or event.damage_type not in [&"jab_cross", &"ground_smash"]
	):
		return false
	if not _is_choir_prime():
		return boss_wreck.receive_damage(event)
	if receiver.outcome_id == BossOutcome.PURGE:
		royal_finale.cancel_pressure()
		_completion_payload = royal_finale.completion_payload(BossOutcome.PURGE)
		royal_finale.preserve_completion_state()
		return boss_wreck.receive_damage(event)
	var snapshot: FinaleEligibilitySnapshot = royal_finale.finale_snapshot
	if not _accept_fresh_royal_finisher_step(event):
		return false
	if snapshot == null or not snapshot.disentangle_eligible:
		royal_finale.cancel_pressure()
		_completion_payload = royal_finale.completion_payload(
			BossOutcome.ASCENSION_FAILURE
		)
		royal_finale.preserve_completion_state()
		return boss_wreck.receive_damage(event)
	if not royal_finale.complete_severance_immediately():
		return false
	_completion_payload = royal_finale.completion_payload(BossOutcome.DISENTANGLE)
	royal_finale.preserve_completion_state()
	return boss_wreck.receive_damage(event)


func _accept_fresh_royal_finisher_step(event: DamageEvent) -> bool:
	if event == null or event.attack_id == 0 or event.root_attack_id == 0:
		return false
	if _royal_finisher_attacks.has(event.attack_id) or _royal_finisher_roots.has(event.root_attack_id):
		return false
	if boss_wreck != null and boss_wreck.fatal_event != null:
		if (
			event.attack_id == boss_wreck.fatal_event.attack_id
			or event.root_attack_id == boss_wreck.fatal_event.root_attack_id
		):
			return false
	_royal_finisher_attacks[event.attack_id] = true
	_royal_finisher_roots[event.root_attack_id] = true
	return true


func _on_severance_receiver_moved(offset: Vector2) -> void:
	if boss_wreck == null or utility_pool.royal_outcome_receiver == null:
		return
	utility_pool.royal_outcome_receiver.global_position = boss_wreck.global_position + offset


func _set_state(next_state: StringName) -> void:
	state = next_state
	_state_elapsed = 0.0
	_sync_controller_phase()
	_sync_rig_animation_state()
	state_changed.emit(state)


func _sync_controller_phase() -> void:
	var health_ratio: float = (
		boss.current_health / maxf(boss.max_health, 1.0)
		if boss != null
		else 0.0
	)
	if utility_pool != null and utility_pool.vertical_slice.active():
		utility_pool.vertical_slice.set_combat_state(state, health_ratio)
	if utility_pool != null and utility_pool.escalation.active():
		utility_pool.escalation.set_combat_state(state, health_ratio)
	if royal_finale != null and royal_finale.active():
		royal_finale.set_combat_state(state, health_ratio)


func _on_boss_attack_changed(_attack_id: StringName, stage: StringName) -> void:
	if utility_pool == null or utility_pool.rig == null:
		return
	utility_pool.rig.play_attacking(stage, _rig_facing())


func _on_core_shockwave_released() -> void:
	if (
		active_definition == null
		or active_definition.boss_id != BossVerticalSliceController.BUSINESS_ID
		or dependencies == null
		or dependencies.city == null
		or dependencies.city.camera_rig == null
	):
		return
	dependencies.city.camera_rig.add_impact_impulse(
		Vector2(0.0, -utility_pool.vertical_slice.business_release_camera_impulse)
	)
	core_shockwave_camera_impulse_count += 1


func _on_royal_boss_attack_changed(
	_mechanic_id: StringName,
	_echo_id: StringName,
	stage: StringName
) -> void:
	_on_boss_attack_changed(_mechanic_id, stage)


func _sync_rig_animation_state() -> void:
	if utility_pool == null or utility_pool.rig == null:
		return
	var direction: StringName = _rig_facing()
	if state in [STATE_BARRAGE, STATE_EXPOSED]:
		var stage: StringName = &"TELEGRAPH"
		if utility_pool.vertical_slice.active():
			stage = utility_pool.vertical_slice.attack_stage
		elif utility_pool.escalation.active():
			stage = utility_pool.escalation.attack_stage
		elif royal_finale != null and royal_finale.active():
			stage = royal_finale.attack_stage
		utility_pool.rig.play_attacking(stage, direction)
	else:
		utility_pool.rig.play_moving(direction)


func _sync_rig_facing() -> void:
	if utility_pool == null or utility_pool.rig == null:
		return
	utility_pool.rig.set_facing(_rig_facing())


func _rig_facing() -> StringName:
	if boss == null or dependencies == null or dependencies.robot == null:
		return BossRig2D.DIRECTION_EAST
	return (
		BossRig2D.DIRECTION_WEST
		if dependencies.robot.global_position.x < boss.global_position.x
		else BossRig2D.DIRECTION_EAST
	)


func _next_generation() -> void:
	if utility_pool != null:
		generation_token = utility_pool.begin_generation()
