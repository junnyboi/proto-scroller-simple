class_name BossCampaignDirector
extends Node

signal gate_triggered(definition: BossEncounterDefinition, marker: BossGateMarker)
signal attempt_started(definition: BossEncounterDefinition)
signal attempt_retried(definition: BossEncounterDefinition)
signal boss_completed(definition: BossEncounterDefinition)

const GATE_APPROACH_FRACTION: float = 0.62
const GATE_INSET: float = 80.0
const COMPLETION_RETRY_SECONDS: float = 1.0
const HANDOFF_NONE: StringName = &"NONE"
const HANDOFF_ROUTE_PENDING: StringName = &"ROUTE_PENDING"
const HANDOFF_CORRIDOR: StringName = &"CORRIDOR"

var siege: UrbanSiegeRuntime
var world_stream: CityWorldStream
var destructibles: StreamedDestructibleRuntime
var gates: Array[BossGateMarker] = []
var arena_lease: ArenaLease = ArenaLease.new()
var interlock: BossSiegeInterlock = BossSiegeInterlock.new()
var attempt_snapshot: BossAttemptSnapshot = BossAttemptSnapshot.new()
var music_director: BossMusicDirector
var arena_barrier: BossArenaBarrier2D
var active_definition: BossEncounterDefinition
var active_gate: BossGateMarker
var attempt_failed: bool = false
var completion_pending: bool = false
var handoff_state: StringName = HANDOFF_NONE
var pending_finale_outcome: int = -1
var _completion_retry_elapsed: float = 0.0
var _triggered_ids: Dictionary[StringName, bool] = {}
var _completed_ids: Dictionary[StringName, bool] = {}


func setup(p_siege: UrbanSiegeRuntime) -> void:
	siege = p_siege
	world_stream = siege.dependencies.city.world_stream
	destructibles = siege.dependencies.city.streamed_destructibles
	arena_lease.setup(world_stream, destructibles)
	interlock.setup(siege)
	music_director = BossMusicDirector.new()
	music_director.setup(_background_music_player())
	add_child(music_director)
	arena_barrier = BossArenaBarrier2D.new()
	add_child(arena_barrier)
	attempt_started.connect(music_director.play_definition)
	attempt_retried.connect(music_director.play_definition)
	for definition: BossEncounterDefinition in BossCampaignCatalog.definitions():
		var marker: BossGateMarker = BossGateMarker.new()
		marker.configure(definition)
		add_child(marker)
		gates.append(marker)
	siege.boss_session.completed.connect(_on_boss_completed)
	siege.boss_session.state_changed.connect(_on_boss_state_changed)
	siege.boss_session.armor_changed.connect(_on_boss_durability_changed)
	siege.boss_session.body_changed.connect(_on_boss_durability_changed)
	siege.boss_session.feedback_changed.connect(_on_slice_feedback_changed)
	siege.boss_session.utility_pool.vertical_slice.attack_changed.connect(_on_slice_feedback_changed)
	siege.boss_session.utility_pool.vertical_slice.archive_revealed.connect(_on_slice_feedback_changed)
	siege.boss_session.utility_pool.vertical_slice.rescue_tally_changed.connect(
		_on_slice_feedback_changed
	)
	siege.boss_session.utility_pool.escalation.attack_changed.connect(
		_on_slice_feedback_changed
	)
	siege.boss_session.utility_pool.escalation.record_changed.connect(
		_on_slice_feedback_changed
	)
	siege.boss_session.utility_pool.escalation.support_changed.connect(
		_on_slice_feedback_changed
	)
	world_stream.district_boss_ready.connect(_on_district_boss_ready)


func _process(delta: float) -> void:
	if completion_pending:
		_completion_retry_elapsed += delta
		if _completion_retry_elapsed >= COMPLETION_RETRY_SECONDS:
			_completion_retry_elapsed = 0.0
			_try_commit_completion()
		return
	if handoff_state == HANDOFF_ROUTE_PENDING:
		_complete_handoff_route()
		return
	if handoff_state == HANDOFF_CORRIDOR:
		if world_stream.post_boss_corridor_is_clear(_active_district_index()):
			_finalize_handoff()
		return
	if handoff_state != HANDOFF_NONE:
		return
	advance()


func advance() -> void:
	if siege == null or not siege.run_active or active_definition != null:
		return
	if siege.is_simulation_paused() or siege.boss_session.active():
		return
	var logical_distance: float = world_stream.logical_distance_x(
		siege.dependencies.robot.global_position.x
	)
	for definition: BossEncounterDefinition in BossCampaignCatalog.definitions():
		if _triggered_ids.has(definition.boss_id) or _completed_ids.has(definition.boss_id):
			continue
		if not world_stream.district_boss_is_ready(
			_district_index(definition.district_id)
		):
			continue
		var threshold: float = (
			float(definition.trigger_chunk) + GATE_APPROACH_FRACTION
		) * CityWorldStream.CHUNK_WIDTH
		if logical_distance >= threshold:
			_begin_attempt(definition)
		break


func reset_run(preserve_music: bool = false) -> void:
	stop(preserve_music)
	_triggered_ids.clear()
	_completed_ids.clear()
	handoff_state = HANDOFF_NONE
	pending_finale_outcome = -1
	for gate: BossGateMarker in gates:
		gate.reset_gate()


func stop(preserve_music: bool = false) -> void:
	if music_director != null and not preserve_music:
		music_director.stop_music()
	if siege != null and siege.boss_session != null:
		siege.boss_session.stop()
	if active_gate != null:
		active_gate.release()
	if arena_barrier != null:
		arena_barrier.deactivate(siege.dependencies.robot if siege != null else null)
	arena_lease.release()
	interlock.discard()
	attempt_snapshot.clear()
	active_definition = null
	active_gate = null
	attempt_failed = false
	completion_pending = false
	handoff_state = HANDOFF_NONE
	pending_finale_outcome = -1
	_completion_retry_elapsed = 0.0
	if siege != null and siege.dependencies.gameplay_hud != null:
		siege.dependencies.gameplay_hud.hide_boss_status()


func owns_combat() -> bool:
	return (
		active_definition != null
		and active_gate != null
		and active_gate.owned
		and handoff_state == HANDOFF_NONE
	)


func fail_attempt() -> bool:
	if not owns_combat() or attempt_failed:
		return false
	if not attempt_snapshot.capture_boss_runtime(siege.boss_session):
		return false
	attempt_failed = true
	siege.boss_session.stop()
	return true


func retry_attempt() -> bool:
	if not owns_combat() or not attempt_failed or not attempt_snapshot.valid:
		return false
	var definition: BossEncounterDefinition = active_definition
	if not attempt_snapshot.restore(
		arena_lease,
		siege.boss_session,
		siege.dependencies.rampage_session,
		active_gate,
		siege.dependencies.robot,
		world_stream
	):
		return false
	attempt_failed = false
	var city: CitySlice = siege.dependencies.city
	city.game_over_active = false
	city.mobile_controls.set_controls_enabled(true)
	city.gameplay_hud.hide_terminal_overlay()
	if not _start_boss_session(definition):
		attempt_failed = true
		return false
	siege.dependencies.gameplay_hud.show_boss_fight()
	attempt_retried.emit(definition)
	attempt_started.emit(definition)
	return true


func gate_for_trigger(trigger_chunk: int) -> BossGateMarker:
	for gate: BossGateMarker in gates:
		if gate.definition.trigger_chunk == trigger_chunk:
			return gate
	return null


func completed_count() -> int:
	return _completed_ids.size()


func _begin_attempt(definition: BossEncounterDefinition) -> bool:
	if (
		definition == null
		or handoff_state != HANDOFF_NONE
		or not world_stream.district_boss_is_ready(
			_district_index(definition.district_id)
		)
	):
		return false
	var gate: BossGateMarker = _acquire_arena_gate(definition)
	if gate == null:
		return false
	active_definition = definition
	active_gate = gate
	_triggered_ids[definition.boss_id] = true
	if not interlock.acquire():
		_rollback_attempt_start()
		return false
	if not attempt_snapshot.capture(
		arena_lease,
		siege.boss_session,
		siege.dependencies.rampage_session,
		gate,
		siege.dependencies.robot,
		world_stream
	):
		_rollback_attempt_start()
		return false
	if not _start_boss_session(definition):
		_rollback_attempt_start()
		return false
	_refresh_hud()
	siege.dependencies.gameplay_hud.show_boss_fight()
	gate_triggered.emit(definition, gate)
	attempt_started.emit(definition)
	return true


func _start_boss_session(definition: BossEncounterDefinition) -> bool:
	if not siege.boss_session.start_definition(definition):
		return false
	if not arena_barrier.activate(
		siege.boss_session.boss.global_position,
		siege.dependencies.robot
	):
		siege.boss_session.stop()
		return false
	return true


func _acquire_arena_gate(
	definition: BossEncounterDefinition
) -> BossGateMarker:
	var gate: BossGateMarker = gate_for_trigger(definition.trigger_chunk)
	if gate == null or not arena_lease.acquire(definition):
		return null
	var gate_anchor: Vector2 = Vector2(
		world_stream.runtime_x_for_logical_index(gate.gate_chunk()) - GATE_INSET,
		0.0
	)
	if not gate.acquire(gate_anchor):
		arena_lease.release()
		return null
	return gate


func _rollback_attempt_start() -> void:
	_triggered_ids.erase(active_definition.boss_id if active_definition != null else &"")
	attempt_snapshot.clear()
	interlock.discard()
	arena_lease.release()
	if arena_barrier != null:
		arena_barrier.deactivate(siege.dependencies.robot)
	if active_gate != null:
		active_gate.release()
	active_definition = null
	active_gate = null


func _on_boss_completed(_elapsed_seconds: float) -> void:
	if not owns_combat():
		return
	_try_commit_completion()


func _try_commit_completion() -> bool:
	if not owns_combat():
		return false
	var completed_definition: BossEncounterDefinition = active_definition
	var choir: ProjectChoirRuntime = siege.dependencies.city.project_choir_runtime
	var payload: Dictionary = siege.boss_session.completion_payload()
	var persisted: bool = choir != null and choir.commit_boss_completion(
		completed_definition, payload
	)
	if persisted and completed_definition.boss_id == &"CHOIR_PRIME":
		var royal_outcome: int = int(payload.get("finale_outcome", -1))
		persisted = BossOutcome.is_valid(royal_outcome) and choir.commit_finale_ending(
			royal_outcome, payload
		)
	if not persisted:
		completion_pending = true
		_completion_retry_elapsed = 0.0
		siege.boss_session.mark_completion_pending()
		_refresh_hud()
		return false
	completion_pending = false
	siege.boss_session.mark_completion_committed()
	_completed_ids[completed_definition.boss_id] = true
	active_gate.consume()
	attempt_snapshot.clear()
	attempt_failed = false
	siege.dependencies.gameplay_hud.hide_boss_status()
	handoff_state = HANDOFF_ROUTE_PENDING
	if completed_definition.boss_id == &"CHOIR_PRIME":
		pending_finale_outcome = int(payload.get("finale_outcome", -1))
	_prepare_completed_boss_handoff()
	_complete_handoff_route()
	return true


func _complete_handoff_route() -> bool:
	var district_index: int = _active_district_index()
	if district_index >= CityDistrictCatalog.DISTRICT_COUNT - 1:
		return _finalize_handoff()
	if not world_stream.begin_post_boss_corridor(district_index):
		return false
	handoff_state = HANDOFF_CORRIDOR
	siege.dependencies.gameplay_hud.set_objective("objective.clear_handoff_corridor")
	if world_stream.post_boss_corridor_is_clear(district_index):
		return _finalize_handoff()
	return true


func _on_district_boss_ready(_district_id: StringName, district_index: int) -> void:
	if active_definition != null or handoff_state != HANDOFF_NONE:
		return
	for definition: BossEncounterDefinition in BossCampaignCatalog.definitions():
		if _district_index(definition.district_id) != district_index:
			continue
		call_deferred("_begin_attempt", definition)
		return


func _prepare_completed_boss_handoff() -> void:
	if siege.dependencies.encounter_runtime != null:
		siege.dependencies.encounter_runtime.set_attack_gate(false)
	if siege.dependencies.telegraphs != null:
		siege.dependencies.telegraphs.cancel_all()


func _finalize_handoff() -> bool:
	if active_definition == null:
		return false
	var completed_definition: BossEncounterDefinition = active_definition
	var district_index: int = _active_district_index()
	if not world_stream.complete_district_handoff(district_index):
		return false
	arena_lease.release()
	if not interlock.complete_after_handoff(district_index):
		return false
	handoff_state = HANDOFF_NONE
	active_definition = null
	active_gate = null
	boss_completed.emit(completed_definition)
	if completed_definition.boss_id == &"CHOIR_PRIME" and BossOutcome.is_valid(
		pending_finale_outcome
	):
		siege.call_deferred("resolve_finale", pending_finale_outcome)
	pending_finale_outcome = -1
	_refresh_hud()
	return true


func _active_district_index() -> int:
	return (
		_district_index(active_definition.district_id)
		if active_definition != null
		else -1
	)


func _district_index(district_id: StringName) -> int:
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		if district.district_id == district_id:
			return district.district_index
	return -1


func _refresh_hud(_state: StringName = &"") -> void:
	if active_definition == null:
		return
	var session: CommandBossSession = siege.boss_session
	var armor: float = session.boss.boss_armor if session.boss != null else 0.0
	var armor_maximum: float = (
		session.boss.boss_max_armor if session.boss != null else active_definition.armor
	)
	var body: float = session.boss.current_health if session.boss != null else 0.0
	siege.dependencies.gameplay_hud.set_campaign_boss_status(
		active_definition,
		session.state,
		armor,
		armor_maximum,
		body,
		active_definition.health,
		active_definition.evidence_flag_id,
		session.live_boss_feedback()
	)


func _on_boss_durability_changed(_current: float, _maximum: float) -> void:
	_refresh_hud()


func _on_boss_state_changed(state: StringName) -> void:
	if state in [
		CommandBossSession.STATE_WRECK,
		CommandBossSession.STATE_COMPLETION_PENDING,
		CommandBossSession.STATE_COMPLETE,
	]:
		arena_barrier.deactivate(siege.dependencies.robot)
	_refresh_hud(state)


func _on_slice_feedback_changed(_first: Variant = null, _second: Variant = null) -> void:
	_refresh_hud()


func _background_music_player() -> AudioStreamPlayer:
	var city: CitySlice = siege.dependencies.city
	if city == null or city.get_parent() == null:
		return null
	return city.get_parent().get("background_music_player") as AudioStreamPlayer
