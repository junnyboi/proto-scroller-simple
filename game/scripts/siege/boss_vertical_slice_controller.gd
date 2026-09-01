# gdlint: disable=max-public-methods,max-file-lines
class_name BossVerticalSliceController
extends Node

signal attack_changed(attack_id: StringName, stage: StringName)
signal archive_revealed(boss_id: StringName)
signal rescue_tally_changed(rescued: int, lost: int)

const BUSINESS_ID: StringName = &"SETTLEMENT_ENGINE_S04"
const RESIDENTIAL_ID: StringName = &"SAMARITAN_15"
const BUSINESS_CORE_SHOCKWAVE_ATTACK: StringName = &"CORE_SHOCKWAVE"
const BUSINESS_ATTACKS: Array[StringName] = [
	BUSINESS_CORE_SHOCKWAVE_ATTACK,
]
const RESIDENTIAL_ATTACKS: Array[StringName] = [
	&"TRIAGE_SWEEP",
	&"PRESSURE_SENTENCE",
	&"EXTRACTION_CLAMP",
	&"BLACKOUT_HARVEST",
]
const RESIDENTIAL_ARMORED_ATTACKS: Array[StringName] = [
	&"TRIAGE_SWEEP", &"PRESSURE_SENTENCE",
]
const RESIDENTIAL_EXPOSED_ATTACKS: Array[StringName] = [
	&"TRIAGE_SWEEP", &"EXTRACTION_CLAMP",
]
const RESIDENTIAL_FINAL_ATTACKS: Array[StringName] = [
	&"BLACKOUT_HARVEST", &"PRESSURE_SENTENCE", &"EXTRACTION_CLAMP",
]
const PIN_COUNT: int = 3
const POD_COUNT: int = 4
const LANE_COUNT: int = 3
const BUSINESS_SUPPORT_BATCH: int = 4
const BUSINESS_SUPPORT_CAP: int = 8
const RESIDENTIAL_PROJECTILE_SCALE: float = 1.5
const RESIDENTIAL_PROJECTILE_SPEED: float = 980.0
const RESIDENTIAL_PROJECTILE_DAMAGE: float = 42.0
const RESIDENTIAL_PROJECTILE_VISUAL: StringName = &"choir_rainvault_pressure_ward_shot"
const RESIDENTIAL_REINFORCEMENT_CAP: int = 4
const RESIDENTIAL_REINFORCEMENT_SECONDS: float = 1.25
const RESIDENTIAL_REINFORCEMENTS: Array[StringName] = [
	&"intake_shepherd",
	&"evacuation_litter",
	&"rainvault_pressure_ward",
	&"balcony_recall_beacon",
]
const RESIDENTIAL_PROJECTILE_SOCKETS: Array[StringName] = [
	&"LEFT_EMITTER", &"UPPER", &"RIGHT_EMITTER", &"CORE",
]
const RESIDENTIAL_AIM_OFFSETS: Array[float] = [-150.0, 0.0, 150.0, 0.0]
const BUSINESS_SHOCKWAVE_DIAMETER: float = 1800.0
const BUSINESS_SHOCKWAVE_DAMAGE: float = 66.0
const BUSINESS_SHOCKWAVE_TELEGRAPH_SECONDS: float = 1.45
const BUSINESS_SHOCKWAVE_ACTIVE_SECONDS: float = 1.05
const BUSINESS_SHOCKWAVE_TRAVEL_SECONDS: float = 1.00
const SHOCKWAVE_BAND_THICKNESS: float = 92.0
const BUSINESS_SUPPORT_OFFSETS: Array[Vector2] = [
	Vector2(-540.0, 0.0), Vector2(540.0, 0.0),
	Vector2(-460.0, 0.0), Vector2(460.0, 0.0),
	Vector2(-620.0, 0.0), Vector2(620.0, 0.0),
	Vector2(-380.0, 0.0), Vector2(380.0, 0.0),
]
const DIRECT_CLEAR_SECONDS: float = 60.0
const TELEGRAPH_SECONDS: float = 0.85
const ACTIVE_SECONDS: float = 0.55
const RECOVERY_SECONDS: float = 0.75
const EXTRACTION_SECONDS: float = 2.6
const ARENA_INTERVAL: Vector2 = Vector2(-576.0, 576.0)
const LANE_CENTERS: Array[float] = [-360.0, 0.0, 360.0]
const POD_OFFSETS: Array[Vector2] = [
	Vector2(-228.0, -178.0),
	Vector2(-126.0, -204.0),
	Vector2(126.0, -204.0),
	Vector2(228.0, -178.0),
]
const PIN_OFFSETS: Array[Vector2] = [
	Vector2(-164.0, -152.0), Vector2(0.0, -198.0), Vector2(164.0, -152.0),
]

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
var active_attack: StringName = &""
var armor_connections: int = 0
var treasury_slab_available: bool = true
var treasury_slab_used: bool = false
var foundation_cascade_used: bool = false
var archive_preserved: bool = true
var archive_visible: bool = false
var breacher_deployed: bool = false
var runners_deployed: int = 0
var active_runner_slot: EnemyActor2D
var extraction_pod: int = -1
var extraction_remaining: float = 0.0
var dry_lane_index: int = 0
var rescue_tally: int = POD_COUNT
var pod_loss_count: int = 0
var central_cradle_preserved: bool = true
var direct_clear_seconds: float = DIRECT_CLEAR_SECONDS
var combat_state: StringName = CommandBossSession.STATE_SCREEN
var body_health_ratio: float = 1.0
var blackout_cycle_count: int = 0
var boss_volley: BossProjectileVolley = BossProjectileVolley.new()
var _business_support_wave_count: int = 0
var _business_support_actors: Array[EnemyActor2D] = []
var _residential_support_actors: Array[EnemyActor2D] = []
var _residential_reinforcement_elapsed: float = 0.0
var _residential_reinforcement_cursor: int = 0
var _reinforcement_interval_multiplier: float = 1.0
var business_release_camera_impulse: float = CommandBossSession.CORE_SHOCKWAVE_CAMERA_IMPULSE
var _active_breacher: EnemyActor2D
var _preserve_state_on_cleanup: bool = false


func setup(
	pool: BossUtilityPool,
	runtime: EncounterRuntime
) -> void:
	utility_pool = pool
	encounter_runtime = runtime


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
		or not definition.boss_id in [BUSINESS_ID, RESIDENTIAL_ID]
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
	if definition.boss_id == BUSINESS_ID:
		_configure_business()
	else:
		_configure_residential()
	utility_pool.register_generation_cleanup(_cleanup_generation.bind(token), token)
	_begin_next_attack()
	return true


func deactivate() -> void:
	boss_volley.cancel()
	for support: EnemyActor2D in _business_support_actors:
		_release_support(support)
	_business_support_actors.clear()
	for support: EnemyActor2D in _residential_support_actors:
		_release_support(support)
	_residential_support_actors.clear()
	_release_support(_active_breacher)
	_release_support(active_runner_slot)
	_active_breacher = null
	active_runner_slot = null
	active_definition = null
	generation_token = 0
	elapsed_seconds = 0.0
	attack_elapsed = 0.0
	attack_index = -1
	attack_stage = &"IDLE"
	active_attack = &""
	armor_connections = 0
	treasury_slab_available = true
	treasury_slab_used = false
	foundation_cascade_used = false
	archive_preserved = true
	archive_visible = false
	breacher_deployed = false
	runners_deployed = 0
	extraction_pod = -1
	extraction_remaining = 0.0
	dry_lane_index = 0
	rescue_tally = POD_COUNT
	pod_loss_count = 0
	central_cradle_preserved = true
	combat_state = CommandBossSession.STATE_SCREEN
	body_health_ratio = 1.0
	blackout_cycle_count = 0
	_business_support_wave_count = 0
	_residential_reinforcement_elapsed = 0.0
	_residential_reinforcement_cursor = 0
	if utility_pool != null:
		for marker: Marker2D in utility_pool.markers:
			marker.visible = false
		for area: BossAttackArea2D in utility_pool.lane_damage_areas:
			area.deactivate()
		for area: BossAttackArea2D in utility_pool.line_areas:
			area.deactivate()
		if utility_pool.radial_shockwave != null:
			utility_pool.radial_shockwave.deactivate()
		for pod: BossPodVisual2D in utility_pool.pod_visuals:
			pod.visible = false
		for record: Node2D in utility_pool.reclamation_anchor_records:
			record.visible = false


func advance(delta: float) -> void:
	if not active() or delta <= 0.0:
		return
	elapsed_seconds += delta
	attack_elapsed += delta
	boss_volley.advance(delta)
	_advance_residential_reinforcements(delta)
	if extraction_pod >= 0:
		extraction_remaining = maxf(extraction_remaining - delta, 0.0)
		if is_zero_approx(extraction_remaining):
			lose_targeted_pod()
	if attack_stage == &"TELEGRAPH" and attack_elapsed >= _telegraph_seconds_for(active_attack):
		attack_elapsed -= _telegraph_seconds_for(active_attack)
		attack_stage = &"ACTIVE"
		_set_attack_visual_state(BossAttackArea2D.VisualState.ARMED)
		if active_definition.boss_id == RESIDENTIAL_ID:
			boss_volley.commit()
		attack_changed.emit(active_attack, attack_stage)
	elif attack_stage == &"ACTIVE" and attack_elapsed >= _active_seconds_for(active_attack):
		attack_elapsed -= _active_seconds_for(active_attack)
		attack_stage = &"RECOVERY"
		boss_volley.cancel()
		_set_attack_visual_state(BossAttackArea2D.VisualState.HIDDEN)
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
	if active_definition.boss_id == BUSINESS_ID:
		return BUSINESS_ATTACKS.duplicate()
	if combat_state != CommandBossSession.STATE_EXPOSED:
		return RESIDENTIAL_ARMORED_ATTACKS.duplicate()
	return (
		RESIDENTIAL_EXPOSED_ATTACKS.duplicate()
		if body_health_ratio > 0.33
		else RESIDENTIAL_FINAL_ATTACKS.duplicate()
	)


func set_combat_state(state_value: StringName, health_ratio: float) -> void:
	var previous_choices: Array[StringName] = active_attack_choices()
	combat_state = state_value
	body_health_ratio = clampf(health_ratio, 0.0, 1.0)
	if body_health_ratio <= 0.0:
		boss_volley.cancel()
		_release_residential_reinforcements()
	var next_choices: Array[StringName] = active_attack_choices()
	if active() and next_choices != previous_choices and not active_attack in next_choices:
		_begin_next_attack()


func register_armor_connection() -> bool:
	if not active() or armor_connections >= PIN_COUNT:
		return false
	utility_pool.markers[armor_connections].visible = false
	utility_pool.marker_presentations[armor_connections].visible = false
	armor_connections += 1
	if armor_connections == PIN_COUNT:
		reveal_archive()
		if active_definition.boss_id == RESIDENTIAL_ID:
			for pod: BossPodVisual2D in utility_pool.pod_visuals:
				if pod.state == BossPodVisual2D.PodState.SEALED:
					pod.set_state(BossPodVisual2D.PodState.OCCUPIED)
	return true


func set_treasury_slab_available(available: bool) -> void:
	treasury_slab_available = available
	var bracket: Node2D = utility_pool.reclamation_anchor_records[0]
	bracket.visible = not available and active_definition != null and (
		active_definition.boss_id == BUSINESS_ID
	)


func trigger_treasury_slab() -> float:
	if (
		not active()
		or active_definition.boss_id != BUSINESS_ID
		or treasury_slab_used
		or active_attack != BUSINESS_CORE_SHOCKWAVE_ATTACK
	):
		return 0.0
	treasury_slab_used = true
	return 80.0


func trigger_foundation_cascade() -> float:
	if not active() or active_definition.boss_id != BUSINESS_ID or foundation_cascade_used:
		return 0.0
	foundation_cascade_used = true
	return 60.0


func destroy_archive() -> bool:
	if not active() or not archive_preserved:
		return false
	archive_preserved = false
	return true


func reveal_archive() -> bool:
	if not active() or archive_visible:
		return false
	archive_visible = true
	archive_revealed.emit(active_definition.boss_id)
	return true


func begin_extraction(pod_index: int) -> bool:
	if (
		not active()
		or active_definition.boss_id != RESIDENTIAL_ID
		or extraction_pod >= 0
		or (_active_breacher != null and _active_breacher.active)
		or (active_runner_slot != null and active_runner_slot.active)
		or pod_index < 0
		or pod_index >= POD_COUNT
	):
		return false
	var pod: BossPodVisual2D = utility_pool.pod_visuals[pod_index]
	if pod.state in [BossPodVisual2D.PodState.LOST, BossPodVisual2D.PodState.RESCUED]:
		return false
	extraction_pod = pod_index
	extraction_remaining = EXTRACTION_SECONDS
	pod.set_state(BossPodVisual2D.PodState.TARGETED)
	_configure_extraction_clamp(pod_index)
	return true


func interrupt_extraction() -> bool:
	if extraction_pod < 0:
		return false
	var pod: BossPodVisual2D = utility_pool.pod_visuals[extraction_pod]
	pod.set_state(BossPodVisual2D.PodState.OCCUPIED)
	extraction_pod = -1
	extraction_remaining = 0.0
	utility_pool.reclamation_anchor_records[1].visible = false
	return true


func lose_targeted_pod() -> bool:
	if extraction_pod < 0:
		return false
	var pod: BossPodVisual2D = utility_pool.pod_visuals[extraction_pod]
	pod.set_state(BossPodVisual2D.PodState.LOST)
	extraction_pod = -1
	extraction_remaining = 0.0
	pod_loss_count += 1
	rescue_tally = maxi(POD_COUNT - pod_loss_count, 0)
	central_cradle_preserved = true
	utility_pool.reclamation_anchor_records[1].visible = false
	rescue_tally_changed.emit(rescue_tally, pod_loss_count)
	return true


func rescue_remaining_pods() -> void:
	if active_definition == null or active_definition.boss_id != RESIDENTIAL_ID:
		return
	for pod: BossPodVisual2D in utility_pool.pod_visuals:
		if pod.state != BossPodVisual2D.PodState.LOST:
			pod.set_state(BossPodVisual2D.PodState.RESCUED)
	central_cradle_preserved = true


func deploy_business_support() -> Array[EnemyActor2D]:
	var result: Array[EnemyActor2D] = []
	if (
		not active()
		or active_definition.boss_id != BUSINESS_ID
		or encounter_runtime == null
	):
		return result
	_prune_business_support_actors()
	var active_count: int = business_support_count()
	var requested: int = mini(BUSINESS_SUPPORT_BATCH, BUSINESS_SUPPORT_CAP - active_count)
	for offset_index: int in range(requested):
		var support_index: int = active_count + offset_index
		var spawn_position: Vector2 = center + BUSINESS_SUPPORT_OFFSETS[support_index]
		spawn_position.y = EncounterRuntime.LAND_ENEMY_VISUAL_BASELINE_Y
		var support: EnemyActor2D = encounter_runtime.acquire(
			&"soldier",
			spawn_position
		)
		if support != null:
			_business_support_actors.append(support)
			result.append(support)
	if not result.is_empty():
		_business_support_wave_count += 1
	return result


func business_support_count() -> int:
	var count: int = 0
	for support: EnemyActor2D in _business_support_actors:
		if support != null and is_instance_valid(support) and support.active:
			count += 1
	return count


func residential_support_count() -> int:
	_prune_residential_support_actors()
	return _residential_support_actors.size()


func residential_support_ids() -> Array[StringName]:
	_prune_residential_support_actors()
	var ids: Array[StringName] = []
	for support: EnemyActor2D in _residential_support_actors:
		if support is ProceduralEnemy:
			ids.append((support as ProceduralEnemy).archetype_id)
	return ids


func projectile_signature() -> Dictionary:
	return boss_volley.signature()


func deploy_breacher() -> EnemyActor2D:
	if (
		not active()
		or active_definition.boss_id != RESIDENTIAL_ID
		or breacher_deployed
		or _active_breacher != null
		or extraction_pod >= 0
		or encounter_runtime == null
	):
		return null
	_active_breacher = encounter_runtime.acquire(
		&"reclaimed_breacher", center + Vector2(-470.0, 0.0), &"BREAKER"
	)
	if _active_breacher != null:
		(_active_breacher as ProceduralEnemy).configure_boss_support(&"reclaimed_breacher")
		utility_pool.controller.track_support(_active_breacher)
		breacher_deployed = true
	return _active_breacher


func deploy_next_runner() -> EnemyActor2D:
	if (
		not active()
		or active_definition.boss_id != RESIDENTIAL_ID
		or runners_deployed >= 2
		or extraction_pod >= 0
		or blackout_discharge_active()
		or (active_runner_slot != null and active_runner_slot.active)
		or encounter_runtime == null
	):
		return null
	active_runner_slot = encounter_runtime.acquire(
		&"jackal", center + Vector2(470.0, 0.0), &"ADVANCING"
	)
	if active_runner_slot != null:
		(active_runner_slot as ProceduralEnemy).configure_boss_support(&"graft_runner")
		utility_pool.controller.track_support(active_runner_slot)
		runners_deployed += 1
	return active_runner_slot


func release_active_runner() -> void:
	_release_support(active_runner_slot)
	active_runner_slot = null


func blackout_discharge_active() -> bool:
	return active_attack == &"BLACKOUT_HARVEST" and attack_stage == &"ACTIVE"


func dry_lane_exists() -> bool:
	if active_definition == null or active_definition.boss_id != RESIDENTIAL_ID:
		return true
	return dry_lane_index >= 0 and dry_lane_index < LANE_COUNT and (
		utility_pool.lane_damage_areas[dry_lane_index].visual_state
		== BossAttackArea2D.VisualState.DRY
	)


func mechanical_targets_clear_of_glass() -> bool:
	if active_definition == null or active_definition.boss_id != RESIDENTIAL_ID:
		return true
	for marker_index: int in range(3):
		var point: Vector2 = utility_pool.markers[marker_index].global_position
		for pod: BossPodVisual2D in utility_pool.pod_visuals:
			if pod.glass_rect().has_point(point):
				return false
	for area: Area2D in utility_pool.rig.hurt_regions:
		var collision: CollisionShape2D = area.get_node(^"Collision") as CollisionShape2D
		var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
		var hurt_rect: Rect2 = Rect2(area.global_position - rectangle.size * 0.5, rectangle.size)
		for pod: BossPodVisual2D in utility_pool.pod_visuals:
			if hurt_rect.intersects(pod.glass_rect()):
				return false
	return true


func mechanical_signature() -> Dictionary:
	var lanes: Array[Dictionary] = []
	for area: BossAttackArea2D in utility_pool.lane_damage_areas:
		lanes.append({
			"position": area.position,
			"size": area.footprint_size,
		})
	var pins: Array[Vector2] = []
	for index: int in range(PIN_COUNT):
		pins.append(utility_pool.markers[index].position)
	return {
		"boss_id": active_definition.boss_id if active_definition != null else &"",
		"pins": pins,
		"lanes": lanes,
		"direct_clear_seconds": direct_clear_seconds,
		"central_cradle_preserved": central_cradle_preserved,
	}


func completion_payload() -> Dictionary:
	if active_definition == null:
		return {}
	return {
		"boss_id": active_definition.boss_id,
		"archive_preserved": archive_preserved,
		"archive_visible": archive_visible,
		"rescue_tally": rescue_tally,
		"pod_loss_count": pod_loss_count,
		"central_cradle_preserved": central_cradle_preserved,
		"direct_clear_seconds": direct_clear_seconds,
	}


func hud_feedback() -> Dictionary:
	if active_definition == null:
		return {}
	var objective_key: String = (
		"boss.objective.business.connect"
		if active_definition.boss_id == BUSINESS_ID and armor_connections < PIN_COUNT
		else "boss.objective.business.finish"
		if active_definition.boss_id == BUSINESS_ID
		else "boss.objective.residential.connect"
		if armor_connections < PIN_COUNT
		else "boss.objective.residential.rescue"
	)
	var consequence_key: String = "boss.rescue.tally"
	if active_definition.boss_id == BUSINESS_ID:
		consequence_key = (
			"boss.archive.preserved" if archive_preserved else "boss.archive.lost"
		)
	var consequence: String = L10n.t(consequence_key, {
		"rescued": rescue_tally,
		"total": POD_COUNT,
	})
	var attack_key: String = "boss.attack.%s" % String(active_attack).to_lower()
	return {
		"objective": L10n.t(objective_key, {
			"current": armor_connections,
			"total": PIN_COUNT,
		}),
		"attack": L10n.t(attack_key),
		"consequence": consequence,
	}


func preserve_completion_state() -> void:
	_preserve_state_on_cleanup = active_definition != null


func capture_state() -> Dictionary:
	var pod_states: PackedInt32Array = PackedInt32Array()
	for pod: BossPodVisual2D in utility_pool.pod_visuals:
		pod_states.append(pod.state)
	return {
		"boss_id": active_definition.boss_id if active_definition != null else &"",
		"elapsed": elapsed_seconds,
		"attack_elapsed": attack_elapsed,
		"attack_index": attack_index,
		"attack_stage": attack_stage,
		"active_attack": active_attack,
		"armor_connections": armor_connections,
		"treasury_slab_available": treasury_slab_available,
		"treasury_slab_used": treasury_slab_used,
		"foundation_cascade_used": foundation_cascade_used,
		"archive_preserved": archive_preserved,
		"archive_visible": archive_visible,
		"breacher_deployed": breacher_deployed,
		"runners_deployed": runners_deployed,
		"extraction_pod": extraction_pod,
		"extraction_remaining": extraction_remaining,
		"dry_lane_index": dry_lane_index,
		"rescue_tally": rescue_tally,
		"pod_loss_count": pod_loss_count,
		"central_cradle_preserved": central_cradle_preserved,
		"combat_state": combat_state,
		"body_health_ratio": body_health_ratio,
		"blackout_cycle_count": blackout_cycle_count,
		"business_support_wave_count": _business_support_wave_count,
		"business_support_active": business_support_count(),
		"residential_support_ids": residential_support_ids(),
		"residential_reinforcement_elapsed": _residential_reinforcement_elapsed,
		"residential_reinforcement_cursor": _residential_reinforcement_cursor,
		"breacher_active": _active_breacher != null and _active_breacher.active,
		"runner_active": active_runner_slot != null and active_runner_slot.active,
		"pod_states": pod_states,
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
	treasury_slab_available = bool(state.get("treasury_slab_available", true))
	treasury_slab_used = bool(state.get("treasury_slab_used", false))
	foundation_cascade_used = bool(state.get("foundation_cascade_used", false))
	archive_preserved = bool(state.get("archive_preserved", true))
	archive_visible = bool(state.get("archive_visible", false))
	breacher_deployed = bool(state.get("breacher_deployed", false))
	runners_deployed = int(state.get("runners_deployed", 0))
	extraction_pod = int(state.get("extraction_pod", -1))
	extraction_remaining = float(state.get("extraction_remaining", 0.0))
	dry_lane_index = int(state.get("dry_lane_index", 0))
	rescue_tally = int(state.get("rescue_tally", POD_COUNT))
	pod_loss_count = int(state.get("pod_loss_count", 0))
	central_cradle_preserved = bool(state.get("central_cradle_preserved", true))
	combat_state = StringName(state.get("combat_state", CommandBossSession.STATE_SCREEN))
	body_health_ratio = float(state.get("body_health_ratio", 1.0))
	blackout_cycle_count = int(state.get("blackout_cycle_count", 0))
	_business_support_wave_count = int(state.get("business_support_wave_count", 0))
	_residential_reinforcement_elapsed = float(
		state.get("residential_reinforcement_elapsed", 0.0)
	)
	_residential_reinforcement_cursor = int(
		state.get("residential_reinforcement_cursor", 0)
	)
	var business_support_active: int = int(state.get("business_support_active", 0))
	var breacher_active: bool = bool(state.get("breacher_active", false))
	var runner_active: bool = bool(state.get("runner_active", false))
	var pod_states: PackedInt32Array = state.get("pod_states", PackedInt32Array())
	for index: int in range(mini(pod_states.size(), utility_pool.pod_visuals.size())):
		utility_pool.pod_visuals[index].set_state(pod_states[index])
	_configure_attack(active_attack)
	_set_attack_visual_state(
		BossAttackArea2D.VisualState.ARMED
		if attack_stage == &"ACTIVE"
		else BossAttackArea2D.VisualState.TELEGRAPH
	)
	if extraction_pod >= 0:
		_configure_extraction_clamp(extraction_pod)
	_restore_support_actors(business_support_active, breacher_active, runner_active)
	_restore_residential_reinforcements(
		state.get("residential_support_ids", []) as Array
	)
	if active_definition.boss_id == RESIDENTIAL_ID and attack_stage == &"TELEGRAPH":
		_prepare_residential_projectile()


func _prune_business_support_actors() -> void:
	for index: int in range(_business_support_actors.size() - 1, -1, -1):
		var support: EnemyActor2D = _business_support_actors[index]
		if support == null or not is_instance_valid(support) or not support.active:
			_business_support_actors.remove_at(index)


func _prune_residential_support_actors() -> void:
	for index: int in range(_residential_support_actors.size() - 1, -1, -1):
		var support: EnemyActor2D = _residential_support_actors[index]
		if support == null or not is_instance_valid(support) or not support.active or support.dead:
			_residential_support_actors.remove_at(index)


func _configure_common_targets() -> void:
	for index: int in range(PIN_COUNT):
		var marker: Marker2D = utility_pool.markers[index]
		marker.global_position = center + PIN_OFFSETS[index]
		marker.visible = true
		var presentation: Sprite2D = utility_pool.marker_presentations[index]
		presentation.texture = BossRig2D.WEAK_POINT_TEXTURE
		presentation.position = Vector2.ZERO
		var texture_size: Vector2 = presentation.texture.get_size()
		presentation.scale = Vector2(54.0 / texture_size.x, 54.0 / texture_size.y)
		presentation.modulate = Color(1.0, 0.78, 0.18, 0.96)
		presentation.visible = true
	for index: int in range(PIN_COUNT, utility_pool.markers.size()):
		utility_pool.markers[index].visible = false


func _configure_business() -> void:
	var archive: Node2D = utility_pool.reclamation_anchor_records[0]
	utility_pool.configure_utility_presentation(
		archive, BossUtilityPool.UtilityPresentationRole.ARCHIVE_TREASURY
	)
	archive.global_position = center + Vector2(294.0, -244.0)
	archive.visible = true
	for pod: BossPodVisual2D in utility_pool.pod_visuals:
		pod.visible = false


func _configure_residential() -> void:
	for index: int in range(POD_COUNT):
		utility_pool.pod_visuals[index].configure(
			index,
			BossPodVisual2D.PodState.SEALED,
			POD_OFFSETS[index]
		)
	var cradle: Node2D = utility_pool.reclamation_anchor_records[0]
	utility_pool.configure_utility_presentation(
		cradle, BossUtilityPool.UtilityPresentationRole.EVACUATION_CRADLE
	)
	cradle.global_position = center + Vector2(0.0, -126.0)
	cradle.visible = true
	for lane_index: int in range(LANE_COUNT):
		var area: BossAttackArea2D = utility_pool.lane_damage_areas[lane_index]
		area.configure_footprint(
			center + Vector2(LANE_CENTERS[lane_index], 4.0),
			Vector2(272.0, 112.0),
			BossAttackArea2D.VisualState.DRY,
			&"BLACKOUT_HARVEST"
		)


func _begin_next_attack() -> void:
	boss_volley.cancel()
	attack_elapsed = 0.0
	attack_stage = &"TELEGRAPH"
	var choices: Array[StringName] = active_attack_choices()
	attack_index = posmod(attack_index + 1, choices.size())
	active_attack = choices[attack_index]
	_configure_attack(active_attack)
	_set_attack_visual_state(BossAttackArea2D.VisualState.TELEGRAPH)
	if active_definition.boss_id == RESIDENTIAL_ID:
		_prepare_residential_projectile()
	attack_changed.emit(active_attack, attack_stage)


func _configure_attack(attack: StringName) -> void:
	for area: BossAttackArea2D in utility_pool.lane_damage_areas:
		area.deactivate()
	for area: BossAttackArea2D in utility_pool.line_areas:
		area.deactivate()
	if utility_pool.radial_shockwave != null:
		utility_pool.radial_shockwave.deactivate()
	if active_definition.boss_id == BUSINESS_ID:
		_configure_business_attack(attack)
	else:
		_configure_residential_attack(attack)


func _configure_business_attack(attack: StringName) -> void:
	if attack != BUSINESS_CORE_SHOCKWAVE_ATTACK:
		return
	business_release_camera_impulse = float(RuntimeTweakAccess.next_attack_value(
		&"boss.s04_release_camera_impulse",
		CommandBossSession.CORE_SHOCKWAVE_CAMERA_IMPULSE
	))
	utility_pool.radial_shockwave.damage_amount = (
		BUSINESS_SHOCKWAVE_DAMAGE * encounter_runtime.cycle_attack_multiplier
	)
	utility_pool.radial_shockwave.configure_core_shockwave(
		BUSINESS_SHOCKWAVE_TRAVEL_SECONDS,
		SHOCKWAVE_BAND_THICKNESS,
		BUSINESS_SHOCKWAVE_TELEGRAPH_SECONDS
	)
	utility_pool.radial_shockwave.configure_footprint(
		_business_core_world_position(),
		Vector2.ONE * BUSINESS_SHOCKWAVE_DIAMETER,
		BossAttackArea2D.VisualState.TELEGRAPH,
		attack
	)


func _telegraph_seconds_for(attack: StringName) -> float:
	match attack:
		BUSINESS_CORE_SHOCKWAVE_ATTACK:
			return BUSINESS_SHOCKWAVE_TELEGRAPH_SECONDS
	return TELEGRAPH_SECONDS


func _active_seconds_for(attack: StringName) -> float:
	match attack:
		BUSINESS_CORE_SHOCKWAVE_ATTACK:
			return BUSINESS_SHOCKWAVE_ACTIVE_SECONDS
	return ACTIVE_SECONDS


func _business_core_world_position() -> Vector2:
	var core_socket: Marker2D = utility_pool.rig.socket(&"CORE")
	return core_socket.global_position if core_socket != null else center + Vector2(0.0, -174.0)


func _configure_residential_attack(attack: StringName) -> void:
	match attack:
		&"TRIAGE_SWEEP":
			utility_pool.lane_damage_areas[0].configure_footprint(
				center + Vector2(-310.0, 0.0), Vector2(280.0, 112.0),
				BossAttackArea2D.VisualState.TELEGRAPH, attack
			)
			utility_pool.lane_damage_areas[2].configure_footprint(
				center + Vector2(310.0, 0.0), Vector2(280.0, 112.0),
				BossAttackArea2D.VisualState.TELEGRAPH, attack
			)
		&"PRESSURE_SENTENCE":
			utility_pool.line_areas[0].configure_footprint(
				center + Vector2(0.0, -70.0), Vector2(760.0, 48.0),
				BossAttackArea2D.VisualState.TELEGRAPH, attack
			)
		&"EXTRACTION_CLAMP":
			if extraction_pod < 0:
				begin_extraction((attack_index + pod_loss_count) % POD_COUNT)
		&"BLACKOUT_HARVEST":
			dry_lane_index = posmod(blackout_cycle_count + pod_loss_count, LANE_COUNT)
			blackout_cycle_count += 1
			for lane_index: int in range(LANE_COUNT):
				utility_pool.lane_damage_areas[lane_index].configure_footprint(
					center + Vector2(LANE_CENTERS[lane_index], 4.0),
					Vector2(272.0, 112.0),
					BossAttackArea2D.VisualState.DRY
					if lane_index == dry_lane_index
					else BossAttackArea2D.VisualState.TELEGRAPH,
					attack
				)


func _configure_extraction_clamp(pod_index: int) -> void:
	var pod: BossPodVisual2D = utility_pool.pod_visuals[pod_index]
	var clamp_record: Node2D = utility_pool.reclamation_anchor_records[1]
	utility_pool.configure_utility_presentation(
		clamp_record, BossUtilityPool.UtilityPresentationRole.EXTRACTION_CLAMP
	)
	clamp_record.global_position = Vector2(pod.global_position.x, center.y + 6.0)
	clamp_record.visible = true


func _set_attack_visual_state(state_value: BossAttackArea2D.VisualState) -> void:
	if active_definition != null and active_definition.boss_id == RESIDENTIAL_ID:
		state_value = BossAttackArea2D.VisualState.TELEGRAPH
	var attack_areas: Array[BossAttackArea2D] = (
		utility_pool.lane_damage_areas + utility_pool.line_areas
	)
	if utility_pool.radial_shockwave != null:
		attack_areas.append(utility_pool.radial_shockwave)
	for area: BossAttackArea2D in attack_areas:
		if area.visible:
			if area.visual_state == BossAttackArea2D.VisualState.DRY:
				continue
			area.configure_footprint(
				area.global_position, area.footprint_size, state_value, active_attack
			)


func _on_recovery_started() -> void:
	if active_definition.boss_id == BUSINESS_ID:
		deploy_business_support()
	elif active_definition.boss_id == RESIDENTIAL_ID:
		if active_attack == &"PRESSURE_SENTENCE":
			deploy_breacher()
		elif active_attack == &"BLACKOUT_HARVEST":
			deploy_next_runner()
		_advance_residential_reinforcements(
			RESIDENTIAL_REINFORCEMENT_SECONDS * _reinforcement_interval_multiplier
		)


func _prepare_residential_projectile() -> bool:
	if (
		active_definition == null
		or active_definition.boss_id != RESIDENTIAL_ID
		or encounter_runtime == null
		or encounter_runtime.robot == null
	):
		return false
	var pattern_index: int = posmod(attack_index, RESIDENTIAL_PROJECTILE_SOCKETS.size())
	var targets: Array[Vector2] = [
		encounter_runtime.robot.global_position
		+ Vector2(RESIDENTIAL_AIM_OFFSETS[pattern_index], 0.0),
	]
	return boss_volley.begin(
		&"shell",
		RESIDENTIAL_PROJECTILE_VISUAL,
		[RESIDENTIAL_PROJECTILE_SOCKETS[pattern_index]],
		targets,
		[0.0],
		RESIDENTIAL_PROJECTILE_SPEED,
		RESIDENTIAL_PROJECTILE_DAMAGE,
		RESIDENTIAL_PROJECTILE_SCALE,
		TELEGRAPH_SECONDS
	)


func _advance_residential_reinforcements(delta: float) -> void:
	if active_definition == null or active_definition.boss_id != RESIDENTIAL_ID:
		return
	_prune_residential_support_actors()
	if (
		body_health_ratio <= 0.0
		or combat_state not in [
			CommandBossSession.STATE_BARRAGE,
			CommandBossSession.STATE_EXPOSED,
		]
		or extraction_pod >= 0
	):
		return
	_residential_reinforcement_elapsed += delta
	if (
		_residential_support_actors.size() >= RESIDENTIAL_REINFORCEMENT_CAP
		or _residential_reinforcement_elapsed
			< RESIDENTIAL_REINFORCEMENT_SECONDS * _reinforcement_interval_multiplier
	):
		return
	_residential_reinforcement_elapsed = 0.0
	_spawn_residential_reinforcement(
		RESIDENTIAL_REINFORCEMENTS[
			posmod(_residential_reinforcement_cursor, RESIDENTIAL_REINFORCEMENTS.size())
		]
	)
	_residential_reinforcement_cursor += 1


func _spawn_residential_reinforcement(archetype_id: StringName) -> EnemyActor2D:
	if encounter_runtime == null:
		return null
	var side: float = -1.0 if _residential_reinforcement_cursor % 2 == 0 else 1.0
	var spawn_position: Vector2 = center + Vector2(side * 520.0, 0.0)
	if EnemyArchetypeCatalog.is_airborne(archetype_id):
		spawn_position.y = float(
			EnemyArchetypeCatalog.profile(archetype_id).get("spawn_y", 190.0)
		)
	var support: EnemyActor2D = encounter_runtime.acquire(archetype_id, spawn_position)
	if support != null:
		_residential_support_actors.append(support)
	return support


func _restore_residential_reinforcements(saved_ids: Array) -> void:
	_release_residential_reinforcements()
	for id_value: Variant in saved_ids:
		if _residential_support_actors.size() >= RESIDENTIAL_REINFORCEMENT_CAP:
			break
		_spawn_residential_reinforcement(StringName(id_value))


func _release_residential_reinforcements() -> void:
	for support: EnemyActor2D in _residential_support_actors:
		_release_support(support)
	_residential_support_actors.clear()


func _restore_support_actors(
	business_support_active: int,
	breacher_active: bool,
	runner_active: bool
) -> void:
	if active_definition == null or encounter_runtime == null:
		return
	if active_definition.boss_id == BUSINESS_ID:
		var expected_wave_count: int = _business_support_wave_count
		_business_support_wave_count = 0
		while business_support_count() < business_support_active:
			if deploy_business_support().is_empty():
				break
		_business_support_wave_count = expected_wave_count
	elif active_definition.boss_id == RESIDENTIAL_ID:
		if breacher_active:
			breacher_deployed = false
			deploy_breacher()
		if runner_active:
			var deployed_count: int = runners_deployed
			runners_deployed = maxi(deployed_count - 1, 0)
			deploy_next_runner()
			runners_deployed = deployed_count


func _release_support(support: EnemyActor2D) -> void:
	if encounter_runtime != null and support != null and is_instance_valid(support):
		encounter_runtime.release(support)


func _cleanup_generation(token: int) -> void:
	if generation_token != token:
		return
	if _preserve_state_on_cleanup:
		boss_volley.cancel()
		for support: EnemyActor2D in _business_support_actors:
			_release_support(support)
		_business_support_actors.clear()
		_release_support(_active_breacher)
		_release_support(active_runner_slot)
		_release_residential_reinforcements()
		_active_breacher = null
		active_runner_slot = null
		generation_token = 0
		_preserve_state_on_cleanup = false
		return
	deactivate()
