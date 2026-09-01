# gdlint: disable=max-public-methods
class_name BossRoyalFinaleController
extends Node

signal attack_changed(mechanic_id: StringName, echo_id: StringName, stage: StringName)
signal pylon_connection_changed(connection_count: int, remaining_pylons: int)
signal severance_changed(completed: int, required: int, loop_count: int)
signal severance_receiver_moved(offset: Vector2)

const ROYAL_ID: StringName = &"CHOIR_PRIME"
const CONNECTION_COUNT: int = 3
const PYLON_COUNT: int = 5
const SEVERANCE_WINDOW_COUNT: int = 5
const TELEGRAPH_SECONDS: float = 0.85
const ACTIVE_SECONDS: float = 0.55
const RECOVERY_SECONDS: float = 0.75
const SEVERANCE_WINDOW_SECONDS: float = 2.6
const PYLON_NAMES: Array[StringName] = [
	&"LEDGER", &"NURSERY", &"STAGE", &"ARSENAL", &"CROWN",
]
const MECHANICS: Array[StringName] = [
	&"LEDGER_SETTLEMENT_SWEEP",
	&"NURSERY_BRACED_SHOCK",
	&"STAGE_ARMED_RING",
	&"ARSENAL_PRODUCTION_LANES",
	&"CROWN_RADIAL_VERDICT",
]
const ARMORED_TESTIMONIES: Array[int] = [0, 1]
const EXPOSED_TESTIMONIES: Array[int] = [2, 3]
const FINAL_TESTIMONIES: Array[int] = [3, 4]
const COMPOSITION_ECHOES: Array[StringName] = [
	&"BULWARK_SAPPER",
	&"BREACHER_GRAFT",
	&"SIREN_DECOY",
	&"LONGBOW_BASILISK_SHRIKE_SERAPH",
	&"GOLIATH_NEMESIS",
]
const CONNECTION_PYLONS: Array = [
	[0, 1],
	[2, 3],
	[4],
]
const ECHO_TEXTURES: Dictionary = {
	&"BULWARK": preload("res://art/city/enemies/archetypes/02-bulwark-riot-trooper.png"),
	&"SAPPER": preload("res://art/city/enemies/archetypes/05-sapper-combat-engineer.png"),
	&"BREACHER": preload("res://art/city/enemies/archetypes/21-reclaimed-breacher.png"),
	&"GRAFT": preload("res://art/city/enemies/archetypes/22-graft-runner.png"),
	&"SIREN": preload("res://art/city/enemies/archetypes/01-needle-spotter-drone.png"),
	&"LONGBOW": preload("res://art/city/enemies/archetypes/03-jackal-recon-buggy.png"),
	&"BASILISK": preload("res://art/city/enemies/archetypes/04-lobber-grenadier.png"),
	&"SHRIKE": preload("res://art/city/enemies/archetypes/06-hound-hunter-drone.png"),
	&"SERAPH": preload("res://art/city/enemies/archetypes/01-needle-spotter-drone.png"),
	&"GOLIATH": preload("res://art/city/enemies/archetypes/21-reclaimed-breacher.png"),
	&"NEMESIS": preload("res://art/city/enemies/archetypes/22-graft-runner.png"),
}
const ECHO_KEYS: Array = [
	[&"BULWARK", &"SAPPER"],
	[&"BREACHER", &"GRAFT"],
	[&"SIREN", &"SIREN", &"SIREN"],
	[&"LONGBOW", &"BASILISK", &"SHRIKE", &"SERAPH"],
	[&"GOLIATH", &"NEMESIS"],
]
const ECHO_OFFSETS: Array = [
	[Vector2(-370.0, -28.0), Vector2(370.0, -28.0)],
	[Vector2(-350.0, -18.0), Vector2(350.0, -18.0)],
	[Vector2(-300.0, -176.0), Vector2(0.0, -228.0), Vector2(300.0, -176.0)],
	[
		Vector2(-430.0, -42.0), Vector2(-150.0, -30.0),
		Vector2(150.0, -208.0), Vector2(430.0, -260.0),
	],
	[Vector2(-330.0, -42.0), Vector2(330.0, -42.0)],
]
const ECHO_SIZES: Array[Vector2] = [
	Vector2(78.0, 112.0), Vector2(112.0, 100.0), Vector2(92.0, 92.0),
	Vector2(132.0, 104.0), Vector2(154.0, 142.0),
]
const SEVERANCE_RECEIVER_OFFSETS: Array[Vector2] = [
	Vector2(160.0, -18.0), Vector2(190.0, -54.0), Vector2(220.0, -18.0),
	Vector2(190.0, 18.0), Vector2(160.0, 18.0),
]
const CROWN_CANON_PROJECTILE_SCALE: float = 1.5
const CROWN_CANON_PROJECTILE_SPEED: float = 900.0
const CROWN_CANON_PROJECTILE_DAMAGE: float = 44.0
const CROWN_CANON_SOCKETS: Array[StringName] = [&"LEFT_EMITTER", &"RIGHT_EMITTER"]
const CROWN_CANON_DELAYS: Array[float] = [0.0, 0.22]
const ROYAL_REINFORCEMENT_CAP: int = 2
const ROYAL_REINFORCEMENT_SECONDS: float = 1.15
const ROYAL_REINFORCEMENTS: Array[StringName] = [
	&"privy_chirurgeon",
	&"laureate_courser",
	&"ninefold_witness",
	&"regency_conservator",
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
var _active_telegraph_seconds: float = TELEGRAPH_SECONDS
var active_pylon_index: int = -1
var active_mechanic: StringName = &""
var active_echo: StringName = &""
var armor_connections: int = 0
var combat_state: StringName = CommandBossSession.STATE_SCREEN
var body_health_ratio: float = 1.0
var testimony_cycle_count: int = 0
var finale_snapshot: FinaleEligibilitySnapshot
var wreck_active: bool = false
var severance_active: bool = false
var severance_completed: int = 0
var severance_loop_count: int = 0
var severance_window_remaining: float = 0.0
var crown_transaction_committed: bool = false
var boss_volley: BossProjectileVolley = BossProjectileVolley.new()
var _reinforcement_actors: Array[EnemyActor2D] = []
var _reinforcement_elapsed: float = 0.0
var _reinforcement_cursor: int = 0
var _reinforcement_interval_multiplier: float = 1.0
var _preserve_state_on_cleanup: bool = false


func setup(pool: BossUtilityPool, runtime: EncounterRuntime) -> void:
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
		or definition.boss_id != ROYAL_ID
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
	combat_state = CommandBossSession.STATE_SCREEN
	body_health_ratio = 1.0
	_configure_pylons()
	utility_pool.register_generation_cleanup(_cleanup_generation.bind(token), token)
	_begin_next_testimony()
	return true


func deactivate() -> void:
	boss_volley.cancel()
	_release_reinforcements()
	active_definition = null
	generation_token = 0
	elapsed_seconds = 0.0
	attack_elapsed = 0.0
	attack_index = -1
	attack_stage = &"IDLE"
	active_pylon_index = -1
	active_mechanic = &""
	active_echo = &""
	armor_connections = 0
	combat_state = CommandBossSession.STATE_SCREEN
	body_health_ratio = 1.0
	testimony_cycle_count = 0
	finale_snapshot = null
	wreck_active = false
	severance_active = false
	severance_completed = 0
	severance_loop_count = 0
	severance_window_remaining = 0.0
	crown_transaction_committed = false
	_reinforcement_elapsed = 0.0
	_reinforcement_cursor = 0
	if utility_pool != null:
		_hide_pressure()
		utility_pool.hide_royal_echo_presentations()


func advance(delta: float) -> void:
	if not active() or delta <= 0.0:
		return
	elapsed_seconds += delta
	attack_elapsed += delta
	boss_volley.advance(delta)
	_advance_reinforcements(delta)
	if severance_active:
		severance_window_remaining = maxf(severance_window_remaining - delta, 0.0)
		if is_zero_approx(severance_window_remaining):
			severance_loop_count += 1
			severance_window_remaining = SEVERANCE_WINDOW_SECONDS
			severance_changed.emit(
				severance_completed, SEVERANCE_WINDOW_COUNT, severance_loop_count
			)
	if attack_stage == &"TELEGRAPH" and attack_elapsed >= _active_telegraph_seconds:
		attack_elapsed -= _active_telegraph_seconds
		attack_stage = &"ACTIVE"
		_set_mechanic_state(BossAttackArea2D.VisualState.ARMED)
		if not wreck_active:
			boss_volley.commit()
		attack_changed.emit(active_mechanic, active_echo, attack_stage)
	elif attack_stage == &"ACTIVE" and attack_elapsed >= ACTIVE_SECONDS:
		attack_elapsed -= ACTIVE_SECONDS
		attack_stage = &"RECOVERY"
		boss_volley.cancel()
		_set_mechanic_state(BossAttackArea2D.VisualState.TELEGRAPH)
		attack_changed.emit(active_mechanic, active_echo, attack_stage)
	elif attack_stage == &"RECOVERY" and attack_elapsed >= RECOVERY_SECONDS:
		_begin_next_testimony()


func active() -> bool:
	return (
		active_definition != null
		and utility_pool != null
		and utility_pool.is_current_generation(generation_token)
	)


func active_testimony_choices() -> Array[int]:
	if combat_state != CommandBossSession.STATE_EXPOSED:
		return ARMORED_TESTIMONIES.duplicate()
	return (
		EXPOSED_TESTIMONIES.duplicate()
		if body_health_ratio > 0.33
		else FINAL_TESTIMONIES.duplicate()
	)


func set_combat_state(state_value: StringName, health_ratio: float) -> void:
	var previous_choices: Array[int] = active_testimony_choices()
	combat_state = state_value
	body_health_ratio = clampf(health_ratio, 0.0, 1.0)
	if body_health_ratio <= 0.0:
		boss_volley.cancel()
		_release_reinforcements()
	var next_choices: Array[int] = active_testimony_choices()
	if active() and next_choices != previous_choices and not active_pylon_index in next_choices:
		_begin_next_testimony()


func register_armor_connection() -> bool:
	if not active() or armor_connections >= CONNECTION_COUNT:
		return false
	for pylon_index: int in CONNECTION_PYLONS[armor_connections]:
		utility_pool.set_royal_pylon_visible(pylon_index, false)
	armor_connections += 1
	crown_transaction_committed = crown_transaction_committed or (
		armor_connections == CONNECTION_COUNT
	)
	pylon_connection_changed.emit(armor_connections, remaining_pylon_count())
	return true


func remaining_pylon_count() -> int:
	var remaining: int = 0
	for pylon_index: int in range(PYLON_COUNT):
		if not _pylon_severed(pylon_index):
			remaining += 1
	return remaining


func begin_wreck(snapshot: FinaleEligibilitySnapshot) -> bool:
	if not active() or snapshot == null:
		return false
	finale_snapshot = snapshot
	wreck_active = true
	boss_volley.cancel()
	_release_reinforcements()
	severance_active = false
	severance_completed = 0
	severance_loop_count = 0
	severance_window_remaining = 0.0
	return true


func begin_severance() -> bool:
	if (
		not active()
		or not wreck_active
		or finale_snapshot == null
		or not finale_snapshot.disentangle_eligible
		or severance_active
	):
		return false
	severance_active = true
	severance_completed = 0
	severance_loop_count = 0
	severance_window_remaining = SEVERANCE_WINDOW_SECONDS
	severance_receiver_moved.emit(SEVERANCE_RECEIVER_OFFSETS[0])
	severance_changed.emit(0, SEVERANCE_WINDOW_COUNT, 0)
	return true


func complete_severance_window() -> bool:
	if not severance_active or severance_completed >= SEVERANCE_WINDOW_COUNT:
		return false
	severance_completed += 1
	severance_window_remaining = SEVERANCE_WINDOW_SECONDS
	# A successful severance explicitly cancels the current pressure sequence.
	_hide_pressure()
	if severance_completed < SEVERANCE_WINDOW_COUNT:
		severance_receiver_moved.emit(
			SEVERANCE_RECEIVER_OFFSETS[severance_completed]
		)
		_begin_next_testimony()
	else:
		severance_active = false
		attack_stage = &"IDLE"
		active_mechanic = &""
		active_echo = &""
		utility_pool.hide_royal_echo_presentations()
	severance_changed.emit(
		severance_completed, SEVERANCE_WINDOW_COUNT, severance_loop_count
	)
	return true


func complete_severance_immediately() -> bool:
	if (
		not active()
		or not wreck_active
		or finale_snapshot == null
		or not finale_snapshot.disentangle_eligible
	):
		return false
	severance_active = false
	severance_completed = SEVERANCE_WINDOW_COUNT
	severance_window_remaining = 0.0
	_hide_pressure()
	attack_stage = &"IDLE"
	active_mechanic = &""
	active_echo = &""
	utility_pool.hide_royal_echo_presentations()
	severance_changed.emit(
		severance_completed,
		SEVERANCE_WINDOW_COUNT,
		severance_loop_count
	)
	return true


func cancel_pressure() -> void:
	severance_active = false
	_hide_pressure()
	utility_pool.hide_royal_echo_presentations()
	attack_stage = &"IDLE"
	active_mechanic = &""
	active_echo = &""


func active_mechanic_count() -> int:
	return int(active() and not active_mechanic.is_empty())


func active_composition_echo_count() -> int:
	return int(active() and not active_echo.is_empty())


func composition_marker_count() -> int:
	var count: int = 0
	if utility_pool == null:
		return count
	for presentation: Sprite2D in utility_pool.marker_presentations:
		if presentation.visible:
			count += 1
	return count


func echo_collision_count() -> int:
	var count: int = 0
	if utility_pool == null:
		return count
	for area: BossAttackArea2D in utility_pool.lane_damage_areas + utility_pool.line_areas:
		if String(area.attack_id).begins_with("ECHO_") and area.monitoring:
			count += 1
	return count


func live_support_count() -> int:
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


func player_motion_history_recorded() -> bool:
	return (
		utility_pool != null
		and (
			utility_pool.motion_echo_recorder.visible
			or utility_pool.motion_echo_recorder.count > 0
		)
	)


func all_pylons_distinct() -> bool:
	var names: Dictionary[StringName, bool] = {}
	if utility_pool == null:
		return false
	for pylon: Node2D in utility_pool.pylon_presentations:
		var pylon_id: StringName = StringName(pylon.get_meta(&"pylon_id", &""))
		if pylon_id.is_empty() or names.has(pylon_id):
			return false
		names[pylon_id] = true
	return names.size() == PYLON_COUNT


func mechanical_signature() -> Dictionary:
	var footprints: Array[Dictionary] = []
	if utility_pool != null:
		for area: BossAttackArea2D in utility_pool.lane_damage_areas + utility_pool.line_areas:
			if area.visible:
				footprints.append({
					"attack": area.attack_id,
					"position": area.position,
					"size": area.footprint_size,
				})
	return {
		"boss_id": active_definition.boss_id if active_definition != null else &"",
		"pylons": PYLON_NAMES,
		"connection_pylons": CONNECTION_PYLONS,
		"mechanics": MECHANICS,
		"echoes": COMPOSITION_ECHOES,
		"footprints": footprints,
		"marker_capacity": BossUtilityPool.MARKER_CAPACITY,
		"severance_windows": SEVERANCE_WINDOW_COUNT,
		"overall_timeout": false,
	}


func hud_feedback() -> Dictionary:
	if active_definition == null:
		return {}
	var objective_key: String = "boss.objective.royal.connect"
	var objective_tokens: Dictionary = {
		"current": armor_connections,
		"total": CONNECTION_COUNT,
	}
	var consequence_key: String = "boss.record.crown_pending"
	var consequence_tokens: Dictionary = {}
	if crown_transaction_committed:
		consequence_key = "boss.record.crown_committed"
	if armor_connections >= CONNECTION_COUNT:
		objective_key = "boss.objective.royal.core"
		objective_tokens = {}
	if wreck_active:
		if finale_snapshot != null and finale_snapshot.disentangle_eligible:
			objective_key = "boss.objective.royal.wreck_eligible"
			objective_tokens = {
				"current": severance_completed,
				"total": SEVERANCE_WINDOW_COUNT,
			}
			consequence_key = "finale.receiver.eligible"
		else:
			objective_key = "boss.objective.royal.wreck_ineligible"
			objective_tokens = {}
			consequence_key = "finale.receiver.warning"
	return {
		"objective": L10n.t(objective_key, objective_tokens),
		"attack": L10n.t(
			"boss.attack.%s" % String(active_mechanic).to_lower()
			if not active_mechanic.is_empty()
			else "boss.attack.none"
		),
		"consequence": L10n.t(consequence_key, consequence_tokens),
	}


func completion_payload(outcome: int) -> Dictionary:
	return {
		"boss_id": ROYAL_ID,
		"finale_outcome": outcome,
		"ending_id": BossOutcome.id_for(outcome),
		"crown_transaction_id": ProjectChoirRuntime.CROWN_PYLON_TRANSACTION_ID,
		"finale_snapshot_transaction_id": CampaignProgressStore.FINALE_SNAPSHOT_TRANSACTION_ID,
		"severance_windows_completed": severance_completed,
		"severance_window_loops": severance_loop_count,
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
		"active_pylon_index": active_pylon_index,
		"active_mechanic": active_mechanic,
		"active_echo": active_echo,
		"armor_connections": armor_connections,
		"combat_state": combat_state,
		"body_health_ratio": body_health_ratio,
		"testimony_cycle_count": testimony_cycle_count,
		"finale_snapshot": finale_snapshot.as_dictionary() if finale_snapshot != null else {},
		"wreck_active": wreck_active,
		"severance_active": severance_active,
		"severance_completed": severance_completed,
		"severance_loop_count": severance_loop_count,
		"severance_window_remaining": severance_window_remaining,
		"crown_transaction_committed": crown_transaction_committed,
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
	active_pylon_index = int(state.get("active_pylon_index", 0))
	active_mechanic = StringName(state.get("active_mechanic", MECHANICS[0]))
	active_echo = StringName(state.get("active_echo", COMPOSITION_ECHOES[0]))
	armor_connections = clampi(
		int(state.get("armor_connections", 0)), 0, CONNECTION_COUNT
	)
	combat_state = StringName(state.get("combat_state", CommandBossSession.STATE_SCREEN))
	body_health_ratio = float(state.get("body_health_ratio", 1.0))
	testimony_cycle_count = int(state.get("testimony_cycle_count", 0))
	var snapshot_data: Dictionary = state.get("finale_snapshot", {})
	finale_snapshot = (
		FinaleEligibilitySnapshot.from_dictionary(snapshot_data)
		if not snapshot_data.is_empty()
		else null
	)
	wreck_active = bool(state.get("wreck_active", false))
	severance_active = bool(state.get("severance_active", false))
	severance_completed = clampi(
		int(state.get("severance_completed", 0)), 0, SEVERANCE_WINDOW_COUNT
	)
	severance_loop_count = maxi(int(state.get("severance_loop_count", 0)), 0)
	severance_window_remaining = maxf(
		float(state.get("severance_window_remaining", 0.0)), 0.0
	)
	crown_transaction_committed = bool(state.get(
		"crown_transaction_committed", armor_connections == CONNECTION_COUNT
	))
	_reinforcement_elapsed = float(state.get("reinforcement_elapsed", 0.0))
	_reinforcement_cursor = int(state.get("reinforcement_cursor", 0))
	_restore_pylon_integrity()
	_configure_testimony(active_pylon_index)
	_set_mechanic_state(
		BossAttackArea2D.VisualState.ARMED
		if attack_stage == &"ACTIVE"
		else BossAttackArea2D.VisualState.TELEGRAPH
	)
	if severance_active and severance_completed < SEVERANCE_WINDOW_COUNT:
		severance_receiver_moved.emit(
			SEVERANCE_RECEIVER_OFFSETS[severance_completed]
		)
	if not wreck_active and body_health_ratio > 0.0:
		_restore_reinforcements(state.get("reinforcement_ids", []) as Array)
		if attack_stage == &"TELEGRAPH":
			_prepare_crown_canon()


func _configure_pylons() -> void:
	utility_pool.present_royal_pylons(center)
	for index: int in range(PYLON_COUNT):
		utility_pool.configure_royal_pylon(index, PYLON_NAMES[index])


func _restore_pylon_integrity() -> void:
	utility_pool.present_royal_pylons(center)
	for connection_index: int in range(armor_connections):
		for pylon_index: int in CONNECTION_PYLONS[connection_index]:
			utility_pool.set_royal_pylon_visible(pylon_index, false)


func _pylon_severed(pylon_index: int) -> bool:
	for connection_index: int in range(armor_connections):
		if CONNECTION_PYLONS[connection_index].has(pylon_index):
			return true
	return false


func _begin_next_testimony() -> void:
	if not active():
		return
	boss_volley.cancel()
	attack_elapsed = 0.0
	attack_stage = &"TELEGRAPH"
	_active_telegraph_seconds = TELEGRAPH_SECONDS * float(
		RuntimeTweakAccess.next_attack_value(&"boss.telegraph.duration_multiplier", 1.0)
	)
	var choices: Array[int] = active_testimony_choices()
	var current_choice_index: int = choices.find(active_pylon_index)
	var next_choice_index: int = (
		0 if current_choice_index < 0 else posmod(current_choice_index + 1, choices.size())
	)
	attack_index += 1
	testimony_cycle_count += 1
	_configure_testimony(choices[next_choice_index])
	if not wreck_active and not _prepare_crown_canon():
		_hide_pressure()
	attack_changed.emit(active_mechanic, active_echo, attack_stage)


func _configure_testimony(pylon_index: int) -> void:
	_hide_pressure()
	utility_pool.hide_royal_echo_presentations()
	active_pylon_index = clampi(pylon_index, 0, PYLON_COUNT - 1)
	active_mechanic = MECHANICS[active_pylon_index]
	active_echo = COMPOSITION_ECHOES[active_pylon_index]
	_configure_mechanic(active_pylon_index)
	_configure_composition_echo(active_pylon_index)
	for index: int in range(PYLON_COUNT):
		utility_pool.set_royal_pylon_active(index, index == active_pylon_index)


func _configure_mechanic(pylon_index: int) -> void:
	match pylon_index:
		0:
			utility_pool.lane_damage_areas[0].configure_footprint(
				center + Vector2(-276.0, 2.0), Vector2(380.0, 112.0),
				BossAttackArea2D.VisualState.TELEGRAPH, active_mechanic
			)
		1:
			utility_pool.lane_damage_areas[0].configure_footprint(
				center + Vector2(0.0, 0.0), Vector2(330.0, 120.0),
				BossAttackArea2D.VisualState.TELEGRAPH, active_mechanic
			)
		2:
			utility_pool.lane_damage_areas[0].configure_footprint(
				center + Vector2(0.0, -34.0), Vector2(430.0, 154.0),
				BossAttackArea2D.VisualState.TELEGRAPH, active_mechanic
			)
		3:
			var safe_lane: int = posmod(testimony_cycle_count, 3)
			for lane_index: int in range(3):
				utility_pool.lane_damage_areas[lane_index].configure_footprint(
					center + Vector2(-360.0 + float(lane_index) * 360.0, 4.0),
					Vector2(272.0, 112.0),
					BossAttackArea2D.VisualState.DRY
					if lane_index == safe_lane
					else BossAttackArea2D.VisualState.TELEGRAPH,
					active_mechanic
				)
		4:
			utility_pool.line_areas[0].configure_footprint(
				center + Vector2(0.0, -82.0), Vector2(780.0, 58.0),
				BossAttackArea2D.VisualState.TELEGRAPH, active_mechanic
			)


func _configure_composition_echo(pylon_index: int) -> void:
	var keys: Array = ECHO_KEYS[pylon_index]
	var offsets: Array = ECHO_OFFSETS[pylon_index]
	for index: int in range(keys.size()):
		var texture: Texture2D = ECHO_TEXTURES.get(StringName(keys[index])) as Texture2D
		utility_pool.configure_royal_echo_presentation(
			index,
			texture,
			center + offsets[index],
			ECHO_SIZES[pylon_index]
		)
	# Echo areas are presentation-only exact pooled footprints and never arm collision.
	utility_pool.line_areas[1].set_presentation_role(
		BossAttackArea2D.PresentationRole.ECHO_PRESENTATION
	)
	utility_pool.line_areas[1].configure_footprint(
		center + Vector2(0.0, -126.0),
		Vector2(920.0, 300.0),
		BossAttackArea2D.VisualState.TELEGRAPH,
		StringName("ECHO_%s" % active_echo)
	)


func _set_mechanic_state(state_value: BossAttackArea2D.VisualState) -> void:
	if utility_pool == null or active_mechanic.is_empty():
		return
	if not wreck_active and state_value == BossAttackArea2D.VisualState.ARMED:
		state_value = BossAttackArea2D.VisualState.TELEGRAPH
	for area: BossAttackArea2D in utility_pool.lane_damage_areas + utility_pool.line_areas:
		if area.attack_id != active_mechanic or area.visual_state == BossAttackArea2D.VisualState.DRY:
			continue
		area.configure_footprint(
			area.global_position, area.footprint_size, state_value, active_mechanic
		)


func _prepare_crown_canon() -> bool:
	if (
		wreck_active
		or body_health_ratio <= 0.0
		or encounter_runtime == null
		or encounter_runtime.robot == null
	):
		return false
	var player_snapshot: Vector2 = encounter_runtime.robot.global_position
	var lead: float = 90.0 if testimony_cycle_count % 2 == 0 else -90.0
	return boss_volley.begin(
		&"rocket",
		ProjectileVisualCatalog.ENEMY_ROCKET_DIRECT,
		CROWN_CANON_SOCKETS,
		[player_snapshot - Vector2(lead, 0.0), player_snapshot + Vector2(lead, 0.0)],
		CROWN_CANON_DELAYS,
		CROWN_CANON_PROJECTILE_SPEED,
		CROWN_CANON_PROJECTILE_DAMAGE,
		CROWN_CANON_PROJECTILE_SCALE,
		_active_telegraph_seconds
	)


func _hide_pressure() -> void:
	if utility_pool == null:
		return
	for area: BossAttackArea2D in utility_pool.lane_damage_areas + utility_pool.line_areas:
		area.deactivate()


func _advance_reinforcements(delta: float) -> void:
	_prune_reinforcements()
	if (
		wreck_active
		or body_health_ratio <= 0.0
		or combat_state not in [
			CommandBossSession.STATE_BARRAGE,
			CommandBossSession.STATE_EXPOSED,
		]
		or _reinforcement_actors.size() >= ROYAL_REINFORCEMENT_CAP
	):
		return
	_reinforcement_elapsed += delta
	if (
		_reinforcement_elapsed
		< ROYAL_REINFORCEMENT_SECONDS * _reinforcement_interval_multiplier
	):
		return
	_reinforcement_elapsed = 0.0
	var archetype_id: StringName = ROYAL_REINFORCEMENTS[
		posmod(_reinforcement_cursor, ROYAL_REINFORCEMENTS.size())
	]
	if _spawn_reinforcement(archetype_id) != null:
		_reinforcement_cursor += 1


func _spawn_reinforcement(archetype_id: StringName) -> EnemyActor2D:
	if encounter_runtime == null:
		return null
	var ordinal: int = _reinforcement_cursor + _reinforcement_actors.size()
	var side: float = -1.0 if ordinal % 2 == 0 else 1.0
	var spawn_position: Vector2 = center + Vector2(side * (520.0 + float(ordinal % 2) * 70.0), 0.0)
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
		if _reinforcement_actors.size() >= ROYAL_REINFORCEMENT_CAP:
			break
		_spawn_reinforcement(StringName(id_value))


func _release_reinforcements() -> void:
	if encounter_runtime != null:
		for support: EnemyActor2D in _reinforcement_actors:
			if support != null and is_instance_valid(support):
				encounter_runtime.release(support)
	_reinforcement_actors.clear()


func _cleanup_generation(token: int) -> void:
	if generation_token != token:
		return
	if _preserve_state_on_cleanup:
		boss_volley.cancel()
		_release_reinforcements()
		generation_token = 0
		_preserve_state_on_cleanup = false
		return
	deactivate()
