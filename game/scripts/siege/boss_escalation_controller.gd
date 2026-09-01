# gdlint: disable=max-public-methods,max-file-lines
class_name BossEscalationController
extends Node

signal attack_changed(attack_id: StringName, stage: StringName)
signal record_changed(record_id: StringName)
signal support_changed(support_id: StringName, active: bool)

const ENTERTAINMENT_ID: StringName = &"MIMESIS_04"
const MILITARY_ID: StringName = &"CANTOR_31_PALE_ENGINE"
const ENTERTAINMENT_ATTACKS: Array[StringName] = [
	&"DEAD_AIR_SWEEP",
	&"MEMORY_BLOCKING",
	&"ARMED_AFTERIMAGE",
	&"ENCORE_IMPACT",
]
const ENTERTAINMENT_ARMORED_ATTACKS: Array[StringName] = [
	&"DEAD_AIR_SWEEP", &"MEMORY_BLOCKING",
]
const ENTERTAINMENT_EXPOSED_ATTACKS: Array[StringName] = [
	&"DEAD_AIR_SWEEP", &"ARMED_AFTERIMAGE", &"MEMORY_BLOCKING",
]
const ENTERTAINMENT_FINAL_ATTACKS: Array[StringName] = [
	&"ARMED_AFTERIMAGE", &"ENCORE_IMPACT",
]
const MILITARY_ATTACKS: Array[StringName] = [
	&"SUTURE_SALVO",
	&"DISPATCH_HARNESS",
	&"PALE_RECLAMATION",
	&"COMPRESSION_PSALM",
]
const MILITARY_ARMORED_ATTACKS: Array[StringName] = [&"SUTURE_SALVO"]
const MILITARY_EXPOSED_ATTACKS: Array[StringName] = [
	&"SUTURE_SALVO", &"DISPATCH_HARNESS",
]
const MILITARY_FINAL_ATTACKS: Array[StringName] = [
	&"PALE_RECLAMATION", &"COMPRESSION_PSALM", &"SUTURE_SALVO",
]
const DIRECT_CLEAR_SECONDS: float = 60.0
const TELEGRAPH_SECONDS: float = 0.85
const ACTIVE_SECONDS: float = 0.55
const RECOVERY_SECONDS: float = 0.75
const PIN_COUNT: int = 3
const LANE_COUNT: int = 3
const ANCHOR_CAPACITY: int = 3
const SIREN_RING_SECONDS: float = 1.25
const RECLAMATION_PLATE_CAP: int = 2
const ARENA_INTERVAL: Vector2 = Vector2(-576.0, 576.0)
const LANE_CENTERS: Array[float] = [-360.0, 0.0, 360.0]
const PIN_OFFSETS: Array[Vector2] = [
	Vector2(-164.0, -152.0), Vector2(0.0, -206.0), Vector2(164.0, -152.0),
]
const EXPORT_DESTINATIONS: Array[String] = [
	"KHEPRI ORBITAL YARD", "SABLE COAST THEATRE", "VEYR OUTER COLONIES",
]
const BOSS_PROJECTILE_SCALE: float = 1.5
const ENTERTAINMENT_PROJECTILE_SPEED: float = 940.0
const ENTERTAINMENT_PROJECTILE_DAMAGE: float = 38.0
const ENTERTAINMENT_PROJECTILE_VISUAL: StringName = &"choir_marquee_anesthetist_shot"
const ENTERTAINMENT_REINFORCEMENT_CAP: int = 3
const ENTERTAINMENT_REINFORCEMENT_SECONDS: float = 1.35
const ENTERTAINMENT_REINFORCEMENTS: Array[StringName] = [
	&"memorial_usher", &"glassback_double", &"marquee_anesthetist",
]
const MILITARY_PROJECTILE_SPEED: float = 1040.0
const MILITARY_PROJECTILE_DAMAGE: float = 46.0
const MILITARY_PROJECTILE_VISUAL: StringName = &"choir_revetment_ward_shot"
const MILITARY_REINFORCEMENT_CAP: int = 4
const MILITARY_REINFORCEMENT_SECONDS: float = 1.20
const MILITARY_REINFORCEMENTS: Array[StringName] = [
	&"suture_marshal", &"mercy_raker", &"revetment_ward", &"triage_kite",
]
const ROSARY_SOCKETS: Array[StringName] = [&"LEFT_EMITTER", &"UPPER", &"RIGHT_EMITTER"]
const ROSARY_OFFSETS: Array[float] = [-120.0, 0.0, 120.0]

var utility_pool: BossUtilityPool
var encounter_runtime: EncounterRuntime
var active_definition: BossEncounterDefinition
var generation_token: int = 0
var center: Vector2 = Vector2.ZERO
var orientation_portrait: bool = false
var elapsed_seconds: float = 0.0
var attack_elapsed: float = 0.0
var attack_index: int = -1
var attack_stage: StringName = &"IDLE"
var _active_telegraph_seconds: float = TELEGRAPH_SECONDS
var active_attack: StringName = &""
var armor_connections: int = 0
var direct_clear_seconds: float = DIRECT_CLEAR_SECONDS
var combat_state: StringName = CommandBossSession.STATE_SCREEN
var body_health_ratio: float = 1.0
var recorder: MotionEchoRecorder
var boss_volley: BossProjectileVolley = BossProjectileVolley.new()

var show_control_cabinet_available: bool = true
var show_control_cabinet_used: bool = false
var rubble_counterplay_available: bool = true
var rubble_grounded: bool = false
var continuity_record_played: bool = false
var biological_termination_time: String = "04:17"
var continuity_boot_delay_seconds: float = 3.0
var siren_deployed: bool = false
var siren_ring_active: bool = false
var siren_ring_remaining: float = 0.0

var artillery_spine_visible: bool = false
var seraph_environment_count: int = 0
var dispatch_requested: bool = false
var dispatch_denied: bool = false
var dispatch_dressing_only: bool = false
var anchors_created: int = 0
var anchor_denied: PackedByteArray = PackedByteArray()
var reclamation_consumed: PackedByteArray = PackedByteArray()
var ablative_plates: int = 0
var export_record_visible: bool = false
var _reinforcement_actors: Array[EnemyActor2D] = []
var _reinforcement_elapsed: float = 0.0
var _reinforcement_cursor: int = 0
var _reinforcement_interval_multiplier: float = 1.0
var _active_siren: EnemyActor2D
var _active_runner: EnemyActor2D
var _preserve_state_on_cleanup: bool = false


func _init() -> void:
	anchor_denied.resize(ANCHOR_CAPACITY)
	reclamation_consumed.resize(ANCHOR_CAPACITY)


func setup(pool: BossUtilityPool, runtime: EncounterRuntime) -> void:
	utility_pool = pool
	encounter_runtime = runtime


func attach_recorder(value: MotionEchoRecorder) -> void:
	recorder = value


func start(
	definition: BossEncounterDefinition,
	token: int,
	world_center: Vector2,
	portrait: bool
) -> bool:
	deactivate()
	_preserve_state_on_cleanup = false
	if (
		definition == null
		or not definition.boss_id in [ENTERTAINMENT_ID, MILITARY_ID]
		or utility_pool == null
		or not utility_pool.is_current_generation(token)
	):
		return false
	active_definition = definition
	generation_token = token
	center = world_center
	orientation_portrait = portrait
	boss_volley.setup(
		encounter_runtime,
		utility_pool.rig,
		utility_pool.rig.host,
		utility_pool.attack_particle_pool,
		definition.boss_id
	)
	_reinforcement_interval_multiplier = float(utility_pool.rig.host.get_meta(
		&"tuning_reinforcement_interval_multiplier", 1.0
	))
	direct_clear_seconds = DIRECT_CLEAR_SECONDS
	combat_state = CommandBossSession.STATE_SCREEN
	body_health_ratio = 1.0
	_configure_common_targets()
	if definition.boss_id == ENTERTAINMENT_ID:
		_configure_entertainment()
	else:
		_configure_military()
	utility_pool.register_generation_cleanup(_cleanup_generation.bind(token), token)
	_begin_next_attack()
	return true


func deactivate() -> void:
	boss_volley.cancel()
	_release_support(_active_siren)
	_release_support(_active_runner)
	_release_reinforcements()
	_active_siren = null
	_active_runner = null
	active_definition = null
	generation_token = 0
	elapsed_seconds = 0.0
	attack_elapsed = 0.0
	attack_index = -1
	attack_stage = &"IDLE"
	active_attack = &""
	armor_connections = 0
	combat_state = CommandBossSession.STATE_SCREEN
	body_health_ratio = 1.0
	show_control_cabinet_available = true
	show_control_cabinet_used = false
	rubble_counterplay_available = true
	rubble_grounded = false
	continuity_record_played = false
	siren_deployed = false
	siren_ring_active = false
	siren_ring_remaining = 0.0
	artillery_spine_visible = false
	seraph_environment_count = 0
	dispatch_requested = false
	dispatch_denied = false
	dispatch_dressing_only = false
	anchors_created = 0
	anchor_denied.fill(0)
	reclamation_consumed.fill(0)
	ablative_plates = 0
	export_record_visible = false
	_reinforcement_elapsed = 0.0
	_reinforcement_cursor = 0
	if recorder != null:
		recorder.deactivate()
	if utility_pool != null:
		for marker: Marker2D in utility_pool.markers:
			marker.visible = false
		for area: BossAttackArea2D in utility_pool.lane_damage_areas:
			area.deactivate()
		for area: BossAttackArea2D in utility_pool.line_areas:
			area.deactivate()
		for anchor: Node2D in utility_pool.reclamation_anchor_records:
			anchor.visible = false
		for projection: Node2D in utility_pool.projection_slots:
			projection.visible = false


func advance(delta: float) -> void:
	if not active() or delta <= 0.0:
		return
	elapsed_seconds += delta
	attack_elapsed += delta
	boss_volley.advance(delta)
	_advance_reinforcements(delta)
	if recorder != null and active_definition.boss_id == ENTERTAINMENT_ID:
		var robot: GiantRobotController = encounter_runtime.robot if encounter_runtime != null else null
		if robot != null:
			recorder.record_motion(robot.global_position, elapsed_seconds)
	if siren_ring_active:
		siren_ring_remaining = maxf(siren_ring_remaining - delta, 0.0)
		if is_zero_approx(siren_ring_remaining):
			end_siren_ring()
	if attack_stage == &"TELEGRAPH" and attack_elapsed >= _active_telegraph_seconds:
		attack_elapsed -= _active_telegraph_seconds
		attack_stage = &"ACTIVE"
		_activate_attack()
		boss_volley.commit()
		attack_changed.emit(active_attack, attack_stage)
	elif attack_stage == &"ACTIVE" and attack_elapsed >= ACTIVE_SECONDS:
		attack_elapsed -= ACTIVE_SECONDS
		attack_stage = &"RECOVERY"
		boss_volley.cancel()
		_hide_attack_damage()
		attack_changed.emit(active_attack, attack_stage)
		_on_recovery_started()
	elif attack_stage == &"RECOVERY" and attack_elapsed >= RECOVERY_SECONDS:
		_begin_next_attack()


func active() -> bool:
	return (
		active_definition != null
		and utility_pool != null
		and utility_pool.is_current_generation(generation_token)
	)


func active_attack_choices() -> Array[StringName]:
	if active_definition == null:
		return []
	if active_definition.boss_id == ENTERTAINMENT_ID:
		if combat_state != CommandBossSession.STATE_EXPOSED:
			return ENTERTAINMENT_ARMORED_ATTACKS.duplicate()
		return (
			ENTERTAINMENT_EXPOSED_ATTACKS.duplicate()
			if body_health_ratio > 0.33
			else ENTERTAINMENT_FINAL_ATTACKS.duplicate()
		)
	if combat_state != CommandBossSession.STATE_EXPOSED:
		return MILITARY_ARMORED_ATTACKS.duplicate()
	return (
		MILITARY_EXPOSED_ATTACKS.duplicate()
		if body_health_ratio > 0.33
		else MILITARY_FINAL_ATTACKS.duplicate()
	)


func set_combat_state(state_value: StringName, health_ratio: float) -> void:
	var previous_choices: Array[StringName] = active_attack_choices()
	combat_state = state_value
	body_health_ratio = clampf(health_ratio, 0.0, 1.0)
	if body_health_ratio <= 0.0:
		boss_volley.cancel()
		_release_reinforcements()
	var next_choices: Array[StringName] = active_attack_choices()
	if active() and next_choices != previous_choices and not active_attack in next_choices:
		_begin_next_attack()


func register_armor_connection() -> bool:
	if not active() or armor_connections >= PIN_COUNT:
		return false
	utility_pool.markers[armor_connections].visible = false
	armor_connections += 1
	if armor_connections == PIN_COUNT:
		if active_definition.boss_id == ENTERTAINMENT_ID:
			play_continuity_record()
		else:
			export_record_visible = true
			record_changed.emit(&"EXPORT_LITANY_31")
	return true


func play_continuity_record() -> bool:
	if not active() or active_definition.boss_id != ENTERTAINMENT_ID or continuity_record_played:
		return false
	continuity_record_played = true
	record_changed.emit(&"BIOLOGICAL_TERMINATION_0417")
	record_changed.emit(&"CONTINUITY_BOOT_PLUS_3_SECONDS")
	return true


func strike_show_control_cabinet() -> float:
	if (
		not active()
		or active_definition.boss_id != ENTERTAINMENT_ID
		or not show_control_cabinet_available
		or show_control_cabinet_used
	):
		return 0.0
	show_control_cabinet_used = true
	show_control_cabinet_available = false
	return 60.0


func ground_rubble_bed() -> bool:
	if (
		not active()
		or active_definition.boss_id != ENTERTAINMENT_ID
		or not rubble_counterplay_available
		or rubble_grounded
	):
		return false
	rubble_grounded = true
	return true


func deploy_siren() -> EnemyActor2D:
	if (
		not active()
		or active_definition.boss_id != ENTERTAINMENT_ID
		or siren_deployed
		or _active_siren != null
		or encounter_runtime == null
	):
		return null
	# The pool is checked before any dispatch telegraph or support record is shown.
	_active_siren = encounter_runtime.acquire(
		&"needle", center + Vector2(430.0, -260.0), &"STRAFE"
	)
	if _active_siren == null:
		return null
	if not (_active_siren as ProceduralEnemy).configure_boss_support(&"choir_siren"):
		encounter_runtime.release(_active_siren)
		_active_siren = null
		return null
	siren_deployed = true
	utility_pool.controller.track_support(_active_siren)
	support_changed.emit(&"CHOIR_SIREN", true)
	return _active_siren


func begin_siren_ring(_preferred_weapon: StringName = &"") -> bool:
	if _active_siren == null or not _active_siren.active or siren_ring_active:
		return false
	siren_ring_active = true
	siren_ring_remaining = SIREN_RING_SECONDS
	return true


func end_siren_ring() -> void:
	siren_ring_active = false
	siren_ring_remaining = 0.0


func release_siren() -> void:
	end_siren_ring()
	_release_support(_active_siren)
	_active_siren = null
	support_changed.emit(&"CHOIR_SIREN", false)


func player_direct_controls_live() -> bool:
	var robot: GiantRobotController = encounter_runtime.robot if encounter_runtime != null else null
	return robot != null and robot.can_request_attack()


func request_dispatch() -> EnemyActor2D:
	if (
		not active()
		or active_definition.boss_id != MILITARY_ID
		or (_active_runner != null and _active_runner.active)
		or encounter_runtime == null
	):
		return null
	dispatch_requested = true
	dispatch_denied = false
	dispatch_dressing_only = false
	# Acquisition precedes crossing-cradle presentation. Denial produces dressing only.
	_active_runner = encounter_runtime.acquire(
		&"jackal", center + Vector2(470.0, 0.0), &"ADVANCING"
	)
	if _active_runner == null:
		dispatch_denied = true
		dispatch_dressing_only = true
		return null
	if not (_active_runner as ProceduralEnemy).configure_boss_support(&"graft_runner"):
		encounter_runtime.release(_active_runner)
		_active_runner = null
		dispatch_denied = true
		dispatch_dressing_only = true
		return null
	utility_pool.controller.track_support(_active_runner)
	encounter_runtime.apply_target_mark(4.0)
	support_changed.emit(&"GRAFT_RUNNER", true)
	return _active_runner


func release_runner() -> void:
	_release_support(_active_runner)
	_active_runner = null
	support_changed.emit(&"GRAFT_RUNNER", false)


func create_freight_anchor(world_position: Vector2 = Vector2.INF) -> int:
	if not active() or active_definition.boss_id != MILITARY_ID:
		return -1
	if anchors_created >= ANCHOR_CAPACITY:
		return -1
	var index: int = anchors_created
	var anchor: Node2D = utility_pool.reclamation_anchor_records[index]
	utility_pool.configure_utility_presentation(
		anchor, BossUtilityPool.UtilityPresentationRole.FREIGHT_RECLAMATION_ANCHOR
	)
	anchor.global_position = (
		center + Vector2(LANE_CENTERS[index], -12.0)
		if not world_position.is_finite()
		else world_position
	)
	anchor.visible = true
	anchors_created += 1
	return index


func deny_reclamation_anchor(index: int) -> bool:
	if (
		index < 0
		or index >= anchors_created
		or reclamation_consumed[index] != 0
		or anchor_denied[index] != 0
	):
		return false
	anchor_denied[index] = 1
	return true


func resolve_pale_reclamation() -> int:
	if not active() or active_definition.boss_id != MILITARY_ID:
		return 0
	var plates_added: int = 0
	for index: int in range(anchors_created):
		if reclamation_consumed[index] != 0:
			continue
		reclamation_consumed[index] = 1
		if anchor_denied[index] == 0 and ablative_plates < RECLAMATION_PLATE_CAP:
			ablative_plates += 1
			plates_added += 1
		utility_pool.reclamation_anchor_records[index].visible = false
	return plates_added


func reclamation_is_finite() -> bool:
	var total: int = 0
	for value: int in reclamation_consumed:
		total += value
	return total <= anchors_created and anchors_created <= ANCHOR_CAPACITY


func safe_lane_exists() -> bool:
	for area: BossAttackArea2D in utility_pool.lane_damage_areas:
		if area.visual_state == BossAttackArea2D.VisualState.DRY:
			return true
	return false


func live_auxiliary_count() -> int:
	return int(_active_runner != null and _active_runner.active)


func live_seraph_count() -> int:
	return encounter_runtime.active_count(&"seraph_carrier") if encounter_runtime != null else 0


func reinforcement_count() -> int:
	_prune_reinforcements()
	return _reinforcement_actors.size()


func reinforcement_ids() -> Array[StringName]:
	_prune_reinforcements()
	var ids: Array[StringName] = []
	for support: EnemyActor2D in _reinforcement_actors:
		if support is ProceduralEnemy:
			ids.append((support as ProceduralEnemy).archetype_id)
	return ids


func projectile_signature() -> Dictionary:
	return boss_volley.signature()


func direct_route_valid_after_facade_predestruction() -> bool:
	return active_definition != null and active_definition.direct_damage_route


func mechanical_signature() -> Dictionary:
	var lanes: Array[Dictionary] = []
	for area: BossAttackArea2D in utility_pool.lane_damage_areas:
		lanes.append({"position": area.position, "size": area.footprint_size})
	return {
		"boss_id": active_definition.boss_id if active_definition != null else &"",
		"attacks": active_attack_choices(),
		"lanes": lanes,
		"direct_clear_seconds": direct_clear_seconds,
		"marker_capacity": MotionEchoRecorder.CAPACITY,
		"anchor_capacity": ANCHOR_CAPACITY,
		"seraph_environment_count": seraph_environment_count,
	}


func completion_payload() -> Dictionary:
	if active_definition == null:
		return {}
	if active_definition.boss_id == ENTERTAINMENT_ID:
		return {
			"boss_id": active_definition.boss_id,
			"stage_record_preserved": continuity_record_played,
			"biological_termination_time": biological_termination_time,
			"continuity_boot_delay_seconds": continuity_boot_delay_seconds,
			"show_control_cabinet_used": show_control_cabinet_used,
			"rubble_grounded": rubble_grounded,
			"direct_clear_seconds": direct_clear_seconds,
		}
	return {
		"boss_id": active_definition.boss_id,
		"arsenal_record_preserved": export_record_visible,
		"export_destinations": EXPORT_DESTINATIONS,
		"anchors_created": anchors_created,
		"ablative_plates": ablative_plates,
		"direct_clear_seconds": direct_clear_seconds,
	}


func hud_feedback() -> Dictionary:
	if active_definition == null:
		return {}
	var entertainment: bool = active_definition.boss_id == ENTERTAINMENT_ID
	var objective_key: String = (
		"boss.objective.entertainment.connect"
		if entertainment and armor_connections < PIN_COUNT
		else "boss.objective.entertainment.live"
		if entertainment
		else "boss.objective.military.connect"
		if armor_connections < PIN_COUNT
		else "boss.objective.military.spine"
	)
	var consequence_key: String = (
		"boss.record.continuity"
		if entertainment and continuity_record_played
		else "boss.record.stage"
		if entertainment
		else "boss.record.export"
		if export_record_visible
		else "boss.record.arsenal"
	)
	return {
		"objective": L10n.t(objective_key, {
			"current": armor_connections,
			"total": PIN_COUNT,
		}),
		"attack": L10n.t("boss.attack.%s" % String(active_attack).to_lower()),
		"consequence": L10n.t(consequence_key),
	}


func preserve_completion_state() -> void:
	_preserve_state_on_cleanup = active_definition != null


func capture_state() -> Dictionary:
	return {
		"boss_id": active_definition.boss_id if active_definition != null else &"",
		"elapsed": elapsed_seconds,
		"attack_elapsed": attack_elapsed,
		"attack_index": attack_index,
		"attack_stage": attack_stage,
		"active_attack": active_attack,
		"armor_connections": armor_connections,
		"combat_state": combat_state,
		"body_health_ratio": body_health_ratio,
		"show_control_cabinet_available": show_control_cabinet_available,
		"show_control_cabinet_used": show_control_cabinet_used,
		"rubble_counterplay_available": rubble_counterplay_available,
		"rubble_grounded": rubble_grounded,
		"continuity_record_played": continuity_record_played,
		"siren_deployed": siren_deployed,
		"siren_active": _active_siren != null and _active_siren.active,
		"siren_ring_active": siren_ring_active,
		"siren_ring_remaining": siren_ring_remaining,
		"recorder": recorder.capture_state() if recorder != null else {},
		"artillery_spine_visible": artillery_spine_visible,
		"seraph_environment_count": seraph_environment_count,
		"dispatch_requested": dispatch_requested,
		"dispatch_denied": dispatch_denied,
		"dispatch_dressing_only": dispatch_dressing_only,
		"runner_active": _active_runner != null and _active_runner.active,
		"anchors_created": anchors_created,
		"anchor_denied": anchor_denied,
		"reclamation_consumed": reclamation_consumed,
		"ablative_plates": ablative_plates,
		"export_record_visible": export_record_visible,
		"reinforcement_ids": reinforcement_ids(),
		"reinforcement_elapsed": _reinforcement_elapsed,
		"reinforcement_cursor": _reinforcement_cursor,
	}


func restore_state(state: Dictionary) -> void:
	if not active() or StringName(state.get("boss_id", &"")) != active_definition.boss_id:
		return
	elapsed_seconds = float(state.get("elapsed", 0.0))
	attack_elapsed = float(state.get("attack_elapsed", 0.0))
	attack_index = int(state.get("attack_index", -1))
	attack_stage = StringName(state.get("attack_stage", &"TELEGRAPH"))
	active_attack = StringName(state.get("active_attack", &""))
	armor_connections = int(state.get("armor_connections", 0))
	combat_state = StringName(state.get("combat_state", CommandBossSession.STATE_SCREEN))
	body_health_ratio = float(state.get("body_health_ratio", 1.0))
	show_control_cabinet_available = bool(state.get("show_control_cabinet_available", true))
	show_control_cabinet_used = bool(state.get("show_control_cabinet_used", false))
	rubble_counterplay_available = bool(state.get("rubble_counterplay_available", true))
	rubble_grounded = bool(state.get("rubble_grounded", false))
	continuity_record_played = bool(state.get("continuity_record_played", false))
	siren_deployed = bool(state.get("siren_deployed", false))
	siren_ring_active = bool(state.get("siren_ring_active", false))
	siren_ring_remaining = float(state.get("siren_ring_remaining", 0.0))
	artillery_spine_visible = bool(state.get("artillery_spine_visible", false))
	seraph_environment_count = int(state.get("seraph_environment_count", 0))
	dispatch_requested = bool(state.get("dispatch_requested", false))
	dispatch_denied = bool(state.get("dispatch_denied", false))
	dispatch_dressing_only = bool(state.get("dispatch_dressing_only", false))
	anchors_created = clampi(int(state.get("anchors_created", 0)), 0, ANCHOR_CAPACITY)
	anchor_denied = state.get("anchor_denied", PackedByteArray()).duplicate()
	anchor_denied.resize(ANCHOR_CAPACITY)
	reclamation_consumed = state.get("reclamation_consumed", PackedByteArray()).duplicate()
	reclamation_consumed.resize(ANCHOR_CAPACITY)
	ablative_plates = int(state.get("ablative_plates", 0))
	export_record_visible = bool(state.get("export_record_visible", false))
	_reinforcement_elapsed = float(state.get("reinforcement_elapsed", 0.0))
	_reinforcement_cursor = int(state.get("reinforcement_cursor", 0))
	_configure_attack(active_attack)
	_set_attack_visual_state(
		BossAttackArea2D.VisualState.ARMED
		if attack_stage == &"ACTIVE"
		else BossAttackArea2D.VisualState.TELEGRAPH
	)
	if recorder != null and active_definition.boss_id == ENTERTAINMENT_ID:
		recorder.restore_state(state.get("recorder", {}))
	_restore_anchor_records()
	if bool(state.get("siren_active", false)):
		siren_deployed = false
		deploy_siren()
		siren_deployed = true
		if siren_ring_active:
			begin_siren_ring()
			siren_ring_remaining = float(state.get("siren_ring_remaining", 0.0))
	if bool(state.get("runner_active", false)):
		request_dispatch()
	_restore_reinforcements(state.get("reinforcement_ids", []) as Array)
	if attack_stage == &"TELEGRAPH":
		_prepare_projectile_attack()


func _configure_common_targets() -> void:
	for index: int in range(PIN_COUNT):
		var marker: Marker2D = utility_pool.markers[index]
		marker.global_position = center + PIN_OFFSETS[index]
		marker.visible = true
	for index: int in range(PIN_COUNT, utility_pool.markers.size()):
		utility_pool.markers[index].visible = false


func _configure_entertainment() -> void:
	show_control_cabinet_available = true
	var cabinet: Node2D = utility_pool.reclamation_anchor_records[0]
	utility_pool.configure_utility_presentation(
		cabinet, BossUtilityPool.UtilityPresentationRole.SHOW_CONTROL_CABINET
	)
	cabinet.global_position = center + Vector2(316.0, -196.0)
	cabinet.visible = true
	var rubble: Node2D = utility_pool.reclamation_anchor_records[1]
	utility_pool.configure_utility_presentation(
		rubble, BossUtilityPool.UtilityPresentationRole.RUBBLE_BED
	)
	rubble.global_position = center + Vector2(-312.0, -10.0)
	rubble.visible = true
	if recorder != null:
		recorder.global_position = Vector2.ZERO
		recorder.activate()


func _configure_military() -> void:
	artillery_spine_visible = true
	seraph_environment_count = 3
	for index: int in range(mini(seraph_environment_count, utility_pool.projection_slots.size())):
		var projection: Node2D = utility_pool.projection_slots[index]
		utility_pool.configure_utility_presentation(
			projection, BossUtilityPool.UtilityPresentationRole.SERAPH_PROJECTION
		)
		projection.global_position = center + Vector2(-440.0 + float(index) * 440.0, -330.0)
		projection.visible = true


func _begin_next_attack() -> void:
	boss_volley.cancel()
	attack_elapsed = 0.0
	attack_stage = &"TELEGRAPH"
	_active_telegraph_seconds = TELEGRAPH_SECONDS * float(
		RuntimeTweakAccess.next_attack_value(&"boss.telegraph.duration_multiplier", 1.0)
	)
	var choices: Array[StringName] = active_attack_choices()
	attack_index = posmod(attack_index + 1, choices.size())
	active_attack = choices[attack_index]
	_configure_attack(active_attack)
	_set_attack_visual_state(BossAttackArea2D.VisualState.TELEGRAPH)
	if not _prepare_projectile_attack():
		_hide_attack_damage()
	attack_changed.emit(active_attack, attack_stage)


func _configure_attack(attack: StringName) -> void:
	for area: BossAttackArea2D in utility_pool.lane_damage_areas:
		area.deactivate()
	for area: BossAttackArea2D in utility_pool.line_areas:
		area.deactivate()
	if active_definition.boss_id == ENTERTAINMENT_ID:
		_configure_entertainment_attack(attack)
	else:
		_configure_military_attack(attack)


func _configure_entertainment_attack(attack: StringName) -> void:
	match attack:
		&"DEAD_AIR_SWEEP":
			utility_pool.line_areas[0].configure_footprint(
				center + Vector2(-220.0, -80.0), Vector2(430.0, 48.0),
				BossAttackArea2D.VisualState.TELEGRAPH, attack
			)
		&"MEMORY_BLOCKING":
			utility_pool.lane_damage_areas[0].configure_footprint(
				center + Vector2(-320.0, 0.0), Vector2(240.0, 104.0),
				BossAttackArea2D.VisualState.TELEGRAPH, attack
			)
			utility_pool.lane_damage_areas[1].configure_footprint(
				center + Vector2(320.0, 0.0), Vector2(240.0, 104.0),
				BossAttackArea2D.VisualState.TELEGRAPH, attack
			)
		&"ARMED_AFTERIMAGE":
			if recorder != null and recorder.count > 0:
				recorder.arm_marker((attack_index + recorder.count - 1) % recorder.count, attack)
		&"ENCORE_IMPACT":
			utility_pool.line_areas[0].configure_footprint(
				center + Vector2(0.0, -74.0), Vector2(720.0, 54.0),
				BossAttackArea2D.VisualState.TELEGRAPH, attack
			)


func _configure_military_attack(attack: StringName) -> void:
	match attack:
		&"SUTURE_SALVO":
			var safe_lane: int = posmod(attack_index + anchors_created, LANE_COUNT)
			for lane_index: int in range(LANE_COUNT):
				utility_pool.lane_damage_areas[lane_index].configure_footprint(
					center + Vector2(LANE_CENTERS[lane_index], 4.0),
					Vector2(272.0, 112.0),
					BossAttackArea2D.VisualState.DRY
					if lane_index == safe_lane
					else BossAttackArea2D.VisualState.TELEGRAPH,
					attack
				)
		&"DISPATCH_HARNESS":
			# No damage/dispatch telegraph exists until support acquisition succeeds.
			pass
		&"PALE_RECLAMATION":
			for index: int in range(anchors_created):
				if reclamation_consumed[index] == 0:
					utility_pool.reclamation_anchor_records[index].visible = true
		&"COMPRESSION_PSALM":
			utility_pool.line_areas[0].configure_footprint(
				center + Vector2(0.0, -96.0), Vector2(780.0, 52.0),
				BossAttackArea2D.VisualState.TELEGRAPH, attack
			)
			utility_pool.lane_damage_areas[0].configure_footprint(
				center + Vector2(-310.0, 0.0), Vector2(260.0, 112.0),
				BossAttackArea2D.VisualState.TELEGRAPH, attack
			)


func _activate_attack() -> void:
	if active_attack == &"ARMED_AFTERIMAGE" and recorder != null:
		recorder.activate_armed_presentation()
	else:
		_set_attack_visual_state(BossAttackArea2D.VisualState.TELEGRAPH)


func _hide_attack_damage() -> void:
	if active_attack == &"ARMED_AFTERIMAGE" and recorder != null:
		recorder.disarm()
	for area: BossAttackArea2D in utility_pool.lane_damage_areas + utility_pool.line_areas:
		if area.visible and area.visual_state != BossAttackArea2D.VisualState.DRY:
			area.deactivate()


func _set_attack_visual_state(state_value: BossAttackArea2D.VisualState) -> void:
	if state_value == BossAttackArea2D.VisualState.ARMED:
		state_value = BossAttackArea2D.VisualState.TELEGRAPH
	for area: BossAttackArea2D in utility_pool.lane_damage_areas + utility_pool.line_areas:
		if area.visible:
			if area.visual_state == BossAttackArea2D.VisualState.DRY:
				continue
			area.configure_footprint(
				area.global_position, area.footprint_size, state_value, active_attack
			)


func _prepare_projectile_attack() -> bool:
	if encounter_runtime == null or encounter_runtime.robot == null or active_definition == null:
		return false
	var player_snapshot: Vector2 = encounter_runtime.robot.global_position
	if active_definition.boss_id == ENTERTAINMENT_ID:
		return _prepare_entertainment_projectiles(player_snapshot)
	return _prepare_military_projectiles(player_snapshot)


func _prepare_entertainment_projectiles(player_snapshot: Vector2) -> bool:
	var sockets: Array[StringName] = [&"LEFT_EMITTER"]
	var origins: Array[Vector2] = []
	var targets: Array[Vector2] = [player_snapshot]
	var delays: Array[float] = [0.0]
	match active_attack:
		&"MEMORY_BLOCKING":
			sockets = [&"LEFT_EMITTER", &"RIGHT_EMITTER"]
			targets = [
				player_snapshot + Vector2(-120.0, 0.0),
				player_snapshot + Vector2(120.0, 0.0),
			]
			delays = [0.0, 0.14]
		&"ARMED_AFTERIMAGE":
			if recorder != null and recorder.armed_index >= 0:
				var positions: PackedVector2Array = recorder.marker_positions()
				if recorder.armed_index < positions.size():
					origins = [positions[recorder.armed_index]]
		&"ENCORE_IMPACT":
			sockets = [&"LEFT_EMITTER", &"UPPER", &"RIGHT_EMITTER"]
			targets = [
				player_snapshot + Vector2(-150.0, 0.0),
				player_snapshot,
				player_snapshot + Vector2(150.0, 0.0),
			]
			delays = [0.0, 0.16, 0.32]
	if not origins.is_empty():
		return boss_volley.begin_from_origins(
			&"shell", ENTERTAINMENT_PROJECTILE_VISUAL, origins, targets, delays,
			ENTERTAINMENT_PROJECTILE_SPEED, ENTERTAINMENT_PROJECTILE_DAMAGE,
			BOSS_PROJECTILE_SCALE, _active_telegraph_seconds
		)
	return boss_volley.begin(
		&"shell", ENTERTAINMENT_PROJECTILE_VISUAL, sockets, targets, delays,
		ENTERTAINMENT_PROJECTILE_SPEED, ENTERTAINMENT_PROJECTILE_DAMAGE,
		BOSS_PROJECTILE_SCALE, _active_telegraph_seconds
	)


func _prepare_military_projectiles(player_snapshot: Vector2) -> bool:
	var sockets: Array[StringName] = [&"CORE"]
	var targets: Array[Vector2] = [player_snapshot]
	var delays: Array[float] = [0.0]
	var speed: float = MILITARY_PROJECTILE_SPEED
	if active_attack == &"SUTURE_SALVO":
		sockets = ROSARY_SOCKETS.duplicate()
		targets = []
		for offset: float in ROSARY_OFFSETS:
			targets.append(player_snapshot + Vector2(offset, 0.0))
		delays = [0.0, 0.10, 0.20]
	elif active_attack == &"COMPRESSION_PSALM":
		sockets = [&"UPPER"]
		speed *= 0.74
	elif active_attack == &"PALE_RECLAMATION":
		sockets = [&"UPPER"]
		speed *= 0.82
	return boss_volley.begin(
		&"shell", MILITARY_PROJECTILE_VISUAL, sockets, targets, delays,
		speed, MILITARY_PROJECTILE_DAMAGE, BOSS_PROJECTILE_SCALE,
		_active_telegraph_seconds
	)


func _on_recovery_started() -> void:
	if active_definition.boss_id == ENTERTAINMENT_ID:
		if active_attack == &"MEMORY_BLOCKING":
			deploy_siren()
		elif active_attack == &"ARMED_AFTERIMAGE" and _active_siren != null:
			begin_siren_ring()
	elif active_attack == &"DISPATCH_HARNESS":
		var runner: EnemyActor2D = request_dispatch()
		if runner != null:
			create_freight_anchor()
	elif active_attack == &"PALE_RECLAMATION":
		resolve_pale_reclamation()


func _restore_anchor_records() -> void:
	if active_definition == null or active_definition.boss_id != MILITARY_ID:
		return
	for index: int in range(utility_pool.reclamation_anchor_records.size()):
		var anchor: Node2D = utility_pool.reclamation_anchor_records[index]
		utility_pool.configure_utility_presentation(
			anchor, BossUtilityPool.UtilityPresentationRole.FREIGHT_RECLAMATION_ANCHOR
		)
		anchor.global_position = center + Vector2(LANE_CENTERS[index], -12.0)
		anchor.visible = index < anchors_created and reclamation_consumed[index] == 0


func _release_support(support: EnemyActor2D) -> void:
	if encounter_runtime != null and support != null and is_instance_valid(support):
		encounter_runtime.release(support)


func _advance_reinforcements(delta: float) -> void:
	_prune_reinforcements()
	if (
		active_definition == null
		or body_health_ratio <= 0.0
		or combat_state not in [
			CommandBossSession.STATE_BARRAGE,
			CommandBossSession.STATE_EXPOSED,
		]
	):
		return
	var roster: Array[StringName] = _reinforcement_roster()
	var cap: int = _reinforcement_cap()
	if roster.is_empty() or _reinforcement_actors.size() >= cap:
		return
	_reinforcement_elapsed += delta
	if _reinforcement_elapsed < _reinforcement_interval():
		return
	_reinforcement_elapsed = 0.0
	var archetype_id: StringName = roster[posmod(_reinforcement_cursor, roster.size())]
	if _spawn_reinforcement(archetype_id) != null:
		_reinforcement_cursor += 1


func _reinforcement_roster() -> Array[StringName]:
	if active_definition == null:
		return []
	return (
		ENTERTAINMENT_REINFORCEMENTS
		if active_definition.boss_id == ENTERTAINMENT_ID
		else MILITARY_REINFORCEMENTS
	)


func _reinforcement_cap() -> int:
	return (
		ENTERTAINMENT_REINFORCEMENT_CAP
		if active_definition != null and active_definition.boss_id == ENTERTAINMENT_ID
		else MILITARY_REINFORCEMENT_CAP
	)


func _reinforcement_interval() -> float:
	return (
		ENTERTAINMENT_REINFORCEMENT_SECONDS
		if active_definition != null and active_definition.boss_id == ENTERTAINMENT_ID
		else MILITARY_REINFORCEMENT_SECONDS
	) * _reinforcement_interval_multiplier


func _spawn_reinforcement(archetype_id: StringName) -> EnemyActor2D:
	if encounter_runtime == null:
		return null
	var ordinal: int = _reinforcement_cursor + _reinforcement_actors.size()
	var side: float = -1.0 if ordinal % 2 == 0 else 1.0
	var spawn_position: Vector2 = center + Vector2(side * (500.0 + float(ordinal % 3) * 55.0), 0.0)
	if EnemyArchetypeCatalog.is_airborne(archetype_id):
		spawn_position.y = float(
			EnemyArchetypeCatalog.profile(archetype_id).get("spawn_y", 190.0)
		)
	var support: EnemyActor2D = encounter_runtime.acquire(archetype_id, spawn_position)
	if support != null:
		_reinforcement_actors.append(support)
	return support


func _prune_reinforcements() -> void:
	for index: int in range(_reinforcement_actors.size() - 1, -1, -1):
		var support: EnemyActor2D = _reinforcement_actors[index]
		if support == null or not is_instance_valid(support) or not support.active or support.dead:
			_reinforcement_actors.remove_at(index)


func _restore_reinforcements(saved_ids: Array) -> void:
	_release_reinforcements()
	for id_value: Variant in saved_ids:
		if _reinforcement_actors.size() >= _reinforcement_cap():
			break
		_spawn_reinforcement(StringName(id_value))


func _release_reinforcements() -> void:
	for support: EnemyActor2D in _reinforcement_actors:
		_release_support(support)
	_reinforcement_actors.clear()


func _cleanup_generation(token: int) -> void:
	if generation_token != token:
		return
	if _preserve_state_on_cleanup:
		boss_volley.cancel()
		_release_support(_active_siren)
		_release_support(_active_runner)
		_release_reinforcements()
		_active_siren = null
		_active_runner = null
		generation_token = 0
		_preserve_state_on_cleanup = false
		return
	deactivate()
