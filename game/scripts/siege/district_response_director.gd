# gdlint: disable=max-public-methods
class_name DistrictResponseDirector
extends EncounterDirector

signal beat_changed(act_index: int, beat_index: int, beat_id: StringName)
signal act_completed(act_index: int, act_id: StringName, display_name: String)
signal recovery_started(duration: float)
signal milestone_reached(milestone: StringName)

const STATE_WAITING: int = 0
const STATE_PRESSURE: int = 1
const STATE_RECOVERY: int = 2
const MAX_PENDING_RECORDS: int = RuntimeBudget.PENDING_BEAT_RECORDS
const MAXIMUM_ACT_OVERRUN: float = 20.0
const LOW_THREAT_WEIGHT: int = 2
const ELITE_SYSTEM_SALT: int = 0x0E11E77
const CHAOS_SYSTEM_SALT: int = 0x0C4A05
const ELITE_AFFIXES: Array[StringName] = EnemyArchetypeCatalog.RANDOM_AFFIXES
const HUMAN_COPY_STAGGER: float = 0.14
const HUMAN_COPY_SPACING: float = 64.0
const BLOCKED_CONTINUITY_SOLDIER_COUNT: int = 4
const BLOCKED_CONTINUITY_OFFSETS: Array[Vector2] = [
	Vector2(-156.0, 0.0),
	Vector2(-84.0, 0.0),
	Vector2(84.0, 0.0),
	Vector2(156.0, 0.0),
]

var district: DistrictDefinition
var ledger: CapacityReservationLedger = CapacityReservationLedger.new()
var beat_index: int = -1
var state: int = STATE_WAITING
var pressure_remaining: float = 0.0
var recovery_remaining: float = 0.0
var elapsed: float = 0.0
var act_elapsed: float = 0.0
var peak_pending_records: int = 0
var elite_assignments: Array[Dictionary] = []
var elite_roll_count: int = 0
var progression_peak_tier: int = 0
var progression_copy_peak: int = 0
var progression_degradation_count: int = 0
var hybrid_substitution_trace: Array[Dictionary] = []
var district_variant_substitution_trace: Array[Dictionary] = []
var hazard_runtime: HazardRuntime
var hazard_pressure: HazardPressureController
var current_pressure_profile: DistrictPressureProfile
var peak_hazard_pending: int = 0
var progression_peak_threat: int = 0
var continuity_spawn_count: int = 0
var _elite_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _elite_seed: int = ELITE_SYSTEM_SALT
var _chaos_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _chaos_seed: int = CHAOS_SYSTEM_SALT
var _beat_reservation_id: int = 0
var _beat_pending: Array[Dictionary] = []
var _hazard_pending: Array[Dictionary] = []
var _act_completion_emitted: bool = false
var _act_advance_blocked: bool = false
var _boss_suspended: bool = false
var _boss_resume_snapshot: Dictionary = {}
var _engaged_facade_chunks: Dictionary[int, bool] = {}
var _pending_facade_reinforcements: int = 0
var _started_beat_count: int = 0


func setup(p_runtime: EncounterRuntime, p_waves: Array[EnemyWave]) -> void:
	district = null
	super.setup(p_runtime, p_waves)


func setup_district(
	p_runtime: EncounterRuntime,
	p_district: DistrictDefinition
) -> void:
	runtime = p_runtime
	district = p_district
	configure_elite_affixes(0, 1)


func configure_hazards(
	p_hazard_runtime: HazardRuntime,
	p_hazard_pressure: HazardPressureController
) -> void:
	hazard_runtime = p_hazard_runtime
	hazard_pressure = p_hazard_pressure


func configure_elite_affixes(run_seed: int, cycle: int) -> void:
	_elite_seed = run_seed ^ ELITE_SYSTEM_SALT ^ maxi(cycle, 1) * 7919
	_chaos_seed = run_seed ^ CHAOS_SYSTEM_SALT ^ maxi(cycle, 1) * 3571
	_elite_rng.seed = _elite_seed
	_chaos_rng.seed = _chaos_seed
	elite_assignments.clear()
	elite_roll_count = 0


func start() -> void:
	if district == null:
		super.start()
		return
	stop()
	completed = false
	running = true
	phase_index = -1
	beat_index = -1
	elapsed = 0.0
	act_elapsed = 0.0
	_elite_rng.seed = _elite_seed
	_chaos_rng.seed = _chaos_seed
	if hazard_pressure != null:
		hazard_pressure.reset_sequence()
	elite_assignments.clear()
	elite_roll_count = 0
	progression_peak_tier = 0
	progression_copy_peak = 0
	progression_degradation_count = 0
	progression_peak_threat = 0
	continuity_spawn_count = 0
	hybrid_substitution_trace.clear()
	district_variant_substitution_trace.clear()
	peak_hazard_pending = 0
	_act_completion_emitted = false
	_act_advance_blocked = false
	_engaged_facade_chunks.clear()
	_pending_facade_reinforcements = 0
	_started_beat_count = 0
	_seed_current_facade_engagement()
	_advance_act()


func stop() -> void:
	if district == null:
		super.stop()
		return
	running = false
	state = STATE_WAITING
	pressure_remaining = 0.0
	recovery_remaining = 0.0
	_beat_pending.clear()
	_hazard_pending.clear()
	_act_completion_emitted = false
	_act_advance_blocked = false
	_boss_suspended = false
	_boss_resume_snapshot.clear()
	_engaged_facade_chunks.clear()
	_pending_facade_reinforcements = 0
	if _beat_reservation_id != 0:
		ledger.cancel(_beat_reservation_id)
	_beat_reservation_id = 0
	ledger.cancel_all()
	if runtime != null:
		runtime.set_attack_gate(true)


func reset_to_contact() -> void:
	stop()
	if runtime != null:
		runtime.release_all()
	start()


func _process(delta: float) -> void:
	if district == null:
		_process_legacy(delta)
		return
	advance(delta)


func advance(delta: float) -> void:
	if not running or completed or runtime == null or district == null or _boss_suspended:
		return
	elapsed += delta
	act_elapsed += delta
	match state:
		STATE_WAITING:
			_try_start_next_beat()
		STATE_PRESSURE:
			_process_pending(delta)
			_process_hazard_pending(delta)
			pressure_remaining = maxf(pressure_remaining - delta, 0.0)
			if is_zero_approx(pressure_remaining) and _beat_pending.is_empty():
				_start_recovery()
		STATE_RECOVERY:
			if _pending_facade_reinforcements > 0:
				recovery_remaining = 0.0
				runtime.set_attack_gate(true)
				state = STATE_WAITING
				_try_start_next_beat()
				return
			recovery_remaining = maxf(recovery_remaining - delta, 0.0)
			if is_zero_approx(recovery_remaining):
				runtime.set_attack_gate(true)
				state = STATE_WAITING


func current_phase_name() -> String:
	if district == null:
		return super.current_phase_name()
	if phase_index < 0 or phase_index >= district.acts.size():
		return ""
	return district.acts[phase_index].display_name


func pending_count() -> int:
	if district == null:
		return super.pending_count()
	return _beat_pending.size()


func hazard_pending_count() -> int:
	return _hazard_pending.size()


func current_beat_id() -> StringName:
	if district == null or phase_index < 0 or beat_index < 0:
		return &""
	var act: DistrictAct = district.acts[phase_index]
	if beat_index >= act.beats.size():
		return &""
	return act.beats[beat_index].beat_id


func phase_count() -> int:
	return district.acts.size() if district != null else waves.size()


func is_recovery_active() -> bool:
	return district != null and state == STATE_RECOVERY


func hold_act_advance() -> void:
	_act_advance_blocked = true


func resume_act_advance() -> void:
	_act_advance_blocked = false


func request_facade_reinforcement(logical_chunk: int) -> bool:
	if (
		district == null
		or not running
		or completed
		or _boss_suspended
		or not CityDistrictCatalog.chunk_hosts_facade(logical_chunk)
		or _engaged_facade_chunks.has(logical_chunk)
	):
		return false
	_engaged_facade_chunks[logical_chunk] = true
	_pending_facade_reinforcements = mini(
		_pending_facade_reinforcements + 1,
		CityDistrictCatalog.FACADE_ENCOUNTERS_PER_DISTRICT
	)
	if state == STATE_WAITING:
		_try_start_next_beat()
	elif state == STATE_PRESSURE and _beat_pending.is_empty():
		pressure_remaining = 0.0
		_start_recovery()
	return true


func facade_engagement_count() -> int:
	return _engaged_facade_chunks.size()


func pending_facade_reinforcement_count() -> int:
	return _pending_facade_reinforcements


func started_beat_count() -> int:
	return _started_beat_count


func current_act_progress() -> float:
	if district == null or phase_index < 0 or phase_index >= district.acts.size():
		return 0.0
	var act: DistrictAct = district.acts[phase_index]
	return clampf(act_elapsed / maxf(_scaled_target_duration(act), 1.0), 0.0, 1.0)


func suspend_for_boss() -> Dictionary:
	if district == null or _boss_suspended:
		return _boss_resume_snapshot.duplicate(true)
	_boss_resume_snapshot = {
		"running": running,
		"completed": completed,
		"state": state,
		"phase_index": phase_index,
		"beat_index": beat_index,
		"next_beat_index": beat_index + 1,
		"elapsed": elapsed,
		"act_elapsed": act_elapsed,
		"pressure_remaining": pressure_remaining,
		"recovery_remaining": recovery_remaining,
		"pressure_profile": current_pressure_profile,
		"act_completion_emitted": _act_completion_emitted,
		"act_advance_blocked": _act_advance_blocked,
	}
	_boss_suspended = true
	return _boss_resume_snapshot.duplicate(true)


func resume_after_boss(recovery_seconds: float) -> bool:
	if not _boss_suspended or _boss_resume_snapshot.is_empty():
		return false
	running = bool(_boss_resume_snapshot.running)
	completed = bool(_boss_resume_snapshot.completed)
	phase_index = int(_boss_resume_snapshot.phase_index)
	beat_index = int(_boss_resume_snapshot.next_beat_index) - 1
	elapsed = float(_boss_resume_snapshot.elapsed)
	act_elapsed = float(_boss_resume_snapshot.act_elapsed)
	current_pressure_profile = _boss_resume_snapshot.pressure_profile as DistrictPressureProfile
	_act_completion_emitted = bool(_boss_resume_snapshot.act_completion_emitted)
	_act_advance_blocked = bool(_boss_resume_snapshot.act_advance_blocked)
	pressure_remaining = 0.0
	recovery_remaining = maxf(recovery_seconds, 0.0)
	state = STATE_RECOVERY
	_boss_suspended = false
	_boss_resume_snapshot.clear()
	runtime.set_attack_gate(false)
	recovery_started.emit(recovery_remaining)
	return true


func advance_after_district_handoff(completed_act_index: int) -> bool:
	if not _boss_suspended or district == null or _boss_resume_snapshot.is_empty():
		return false
	phase_index = clampi(
		completed_act_index,
		0,
		maxi(district.acts.size() - 1, 0)
	)
	beat_index = district.acts[phase_index].beats.size() - 1
	elapsed = float(_boss_resume_snapshot.get("elapsed", elapsed))
	act_elapsed = float(_boss_resume_snapshot.get("act_elapsed", act_elapsed))
	pressure_remaining = 0.0
	recovery_remaining = 0.0
	state = STATE_WAITING
	running = true
	completed = false
	_boss_suspended = false
	_boss_resume_snapshot.clear()
	_beat_pending.clear()
	_hazard_pending.clear()
	if _beat_reservation_id != 0:
		ledger.cancel(_beat_reservation_id)
		_beat_reservation_id = 0
	ledger.cancel_all()
	_pending_facade_reinforcements = 0
	var completed_act: DistrictAct = district.acts[phase_index]
	if not _act_completion_emitted:
		_act_completion_emitted = true
		act_completed.emit(
			phase_index,
			completed_act.act_id,
			completed_act.display_name
		)
	if not completed_act.milestone_after.is_empty():
		milestone_reached.emit(completed_act.milestone_after)
	_act_advance_blocked = false
	_advance_act()
	_act_advance_blocked = true
	if runtime != null:
		runtime.set_attack_gate(true)
	return true


func discard_boss_suspension() -> void:
	_boss_suspended = false
	_boss_resume_snapshot.clear()


func is_suspended_for_boss() -> bool:
	return _boss_suspended


func _advance_act() -> void:
	phase_index += 1
	beat_index = -1
	if district == null or phase_index >= district.acts.size():
		completed = true
		running = false
		district_completed.emit()
		return
	var act: DistrictAct = district.acts[phase_index]
	act_elapsed = 0.0
	_act_completion_emitted = false
	phase_changed.emit(phase_index, act.display_name)
	state = STATE_WAITING


func _try_start_next_beat() -> void:
	var act: DistrictAct = district.acts[phase_index]
	if beat_index >= act.beats.size() - 1:
		if _act_advance_blocked:
			_try_emit_held_act_completion(act)
			beat_index = -1
			_try_start_next_beat()
			if _beat_pending.is_empty() and runtime.active_count() == 0:
				_ensure_blocked_act_continuity()
			return
		var target_duration: float = _scaled_target_duration(act)
		if act_elapsed < target_duration:
			return
		var overrun_expired: bool = (
			act_elapsed
			>= target_duration + EnemySpawnTuning.scaled_interval(MAXIMUM_ACT_OVERRUN)
		)
		if _threat_weight() > LOW_THREAT_WEIGHT and not overrun_expired:
			return
		if not _act_completion_emitted:
			_act_completion_emitted = true
			act_completed.emit(phase_index, act.act_id, act.display_name)
		if not act.milestone_after.is_empty():
			milestone_reached.emit(act.milestone_after)
		_advance_act()
		return
	var authored_beat: DistrictBeat = act.beats[beat_index + 1]
	var spatial_district_id: StringName = (
		runtime.world_stream.current_district_id
		if runtime.world_stream != null
		else &"BUSINESS"
	)
	var resolution: Dictionary = HybridEncounterResolver.resolve_with_trace(
		authored_beat,
		spatial_district_id,
		phase_index,
		beat_index + 1,
		_elite_seed
	)
	var next_beat: DistrictBeat = resolution.get("beat") as DistrictBeat
	for staged_change: Dictionary in resolution.get("substitutions", []):
		var context: Dictionary = {
			"district_id": spatial_district_id,
			"act_index": phase_index,
			"beat_index": beat_index + 1,
			"entry_index": int(staged_change.entry_index),
		}
		if bool(staged_change.hybrid_applied):
			var hybrid_change: Dictionary = context.duplicate(true)
			hybrid_change["before"] = StringName(staged_change.before)
			hybrid_change["after"] = StringName(staged_change.hybrid_after)
			hybrid_substitution_trace.append(hybrid_change)
		if bool(staged_change.variant_applied):
			var variant_change: Dictionary = context.duplicate(true)
			variant_change["before"] = StringName(staged_change.hybrid_after)
			variant_change["after"] = StringName(staged_change.after)
			district_variant_substitution_trace.append(variant_change)
	current_pressure_profile = _effective_pressure_profile()
	var authored_threat_floor: int = _authored_threat(authored_beat)
	var resolved_threat: int = _authored_threat(next_beat)
	var beat_threat_ceiling: int = maxi(
		EnemySpawnTuning.scaled_threat(current_pressure_profile.live_threat_ceiling),
		authored_threat_floor
	)
	var admission_threat: int = (
		_planned_threat(next_beat, {})
		- resolved_threat
		+ maxi(resolved_threat, authored_threat_floor)
	)
	if admission_threat > beat_threat_ceiling:
		return
	var progression_tier: int = current_pressure_profile.district_index
	var progression_copies: Dictionary[int, int] = _progression_copy_plan(
		next_beat,
		current_pressure_profile
	)
	var counts: Dictionary[StringName, int] = ledger.counts_for_beat(next_beat)
	for entry_index: int in progression_copies:
		var extra_entry: EnemySpawnEntry = next_beat.spawns[entry_index]
		var extra_kind: StringName = StringName(extra_entry.kind)
		var key: StringName = EnemyArchetypeCatalog.reservation_key(extra_kind)
		counts[key] = (
			int(counts.get(key, 0))
			+ EnemySpawnTuning.scaled_count(int(progression_copies[entry_index]))
		)
	var reservation_id: int = ledger.reserve_counts(counts, runtime)
	if reservation_id == 0 and not progression_copies.is_empty():
		progression_degradation_count += 1
		progression_copies.clear()
		counts = ledger.counts_for_beat(next_beat)
		reservation_id = ledger.reserve_counts(counts, runtime)
	if reservation_id == 0:
		return
	progression_peak_tier = maxi(progression_peak_tier, progression_tier)
	progression_copy_peak = maxi(progression_copy_peak, _dictionary_total(progression_copies))
	progression_peak_threat = maxi(
		progression_peak_threat,
		_planned_threat(next_beat, progression_copies)
	)
	beat_index += 1
	_started_beat_count += 1
	if _pending_facade_reinforcements > 0:
		_pending_facade_reinforcements -= 1
	_beat_reservation_id = reservation_id
	_beat_pending.clear()
	var elite_plan: Dictionary[int, StringName] = _roll_elite_plan(
		act,
		next_beat,
		current_pressure_profile
	)
	var pending_index: int = 0
	var cadence_scale: float = (
		current_pressure_profile.cadence_scale * EnemySpawnTuning.INTERVAL_SCALE
	)
	for entry_index: int in range(next_beat.spawns.size()):
		var entry: EnemySpawnEntry = next_beat.spawns[entry_index]
		var kind: StringName = StringName(entry.kind)
		var spawn_count: int = EnemySpawnTuning.scaled_count(
			EnemyArchetypeCatalog.spawn_multiplier(kind)
			+ int(progression_copies.get(entry_index, 0))
		)
		for copy_index: int in range(spawn_count):
			if _beat_pending.size() >= MAX_PENDING_RECORDS:
				break
			var stagger: float = float(copy_index) * HUMAN_COPY_STAGGER * cadence_scale
			if act.chaos_enabled:
				stagger += float(pending_index) * act.spawn_stagger_seconds * cadence_scale
				stagger += EnemySpawnTuning.scaled_interval(
					_chaos_rng.randf_range(0.0, act.spawn_jitter_seconds)
				)
			var spawn_anchor: String = entry.spawn_anchor
			if act.chaos_enabled and _chaos_rng.randf() < act.mirrored_flank_chance:
				spawn_anchor = _mirrored_anchor(spawn_anchor)
			var copy_direction: float = -1.0 if spawn_anchor in ["BEHIND", "CAMERA_LEFT"] else 1.0
			_beat_pending.append({
				"entry": entry,
				"remaining": EnemySpawnTuning.scaled_interval(entry.delay) + stagger,
				"trait_id": elite_plan.get(entry_index, entry.trait_id),
				"spawn_anchor": spawn_anchor,
				"offset": Vector2(copy_direction * float(copy_index) * HUMAN_COPY_SPACING, 0.0),
				})
			pending_index += 1
	_hazard_pending.clear()
	if hazard_pressure != null and hazard_runtime != null:
		var robot_x: float = runtime.robot.global_position.x if runtime.robot != null else 760.0
		_hazard_pending = hazard_pressure.plan_for_beat(
			phase_index,
			beat_index,
			act,
			next_beat,
			robot_x,
				current_pressure_profile
		)
		peak_hazard_pending = maxi(peak_hazard_pending, _hazard_pending.size())
	peak_pending_records = maxi(peak_pending_records, _beat_pending.size())
	pressure_remaining = EnemySpawnTuning.scaled_interval(
		next_beat.pressure_seconds
	)
	recovery_remaining = maxf(
		EnemySpawnTuning.scaled_interval(1.0),
		EnemySpawnTuning.scaled_interval(
			next_beat.recovery_seconds
			* current_pressure_profile.recovery_scale
		)
	)
	runtime.set_attack_gate(true)
	state = STATE_PRESSURE
	beat_changed.emit(phase_index, beat_index, next_beat.beat_id)


func _ensure_blocked_act_continuity() -> void:
	if (
		runtime == null
		or _boss_suspended
		or runtime.active_count() > 0
		or not _beat_pending.is_empty()
	):
		return
	var center: Vector2 = runtime.resolve_spawn_position(Vector2(0.0, 655.0), &"AHEAD")
	for index: int in range(BLOCKED_CONTINUITY_SOLDIER_COUNT):
		var spawn_anchor: StringName = &"AHEAD" if index % 2 == 0 else &"BEHIND"
		var spawn_position: Vector2 = runtime.resolve_spawn_position(
			Vector2(0.0, 655.0),
			spawn_anchor,
			BLOCKED_CONTINUITY_OFFSETS[index]
		)
		if runtime.acquire(&"soldier", spawn_position) != null:
			continuity_spawn_count += 1
	if continuity_spawn_count == 0:
		push_warning("Blocked act continuity could not acquire infantry near %s" % center)


func _start_recovery() -> void:
	if _beat_reservation_id != 0:
		ledger.cancel(_beat_reservation_id)
	_beat_reservation_id = 0
	if _pending_facade_reinforcements > 0:
		runtime.set_attack_gate(true)
		state = STATE_WAITING
		_try_start_next_beat()
		return
	runtime.set_attack_gate(false)
	state = STATE_RECOVERY
	recovery_started.emit(recovery_remaining)


func _process_pending(delta: float) -> void:
	for index: int in range(_beat_pending.size() - 1, -1, -1):
		var record: Dictionary = _beat_pending[index]
		record.remaining = maxf(float(record.remaining) - delta, 0.0)
		if not is_zero_approx(float(record.remaining)):
			continue
		var entry: EnemySpawnEntry = record.entry
		var kind: StringName = StringName(entry.kind)
		if runtime.acquire(
			kind,
			_resolve_position(
				entry,
				String(record.spawn_anchor),
				record.offset as Vector2
			),
			entry.role_id,
			StringName(record.trait_id)
		) == null:
			continue
		ledger.consume_actor(_beat_reservation_id, kind)
		_beat_pending.remove_at(index)


func _process_hazard_pending(delta: float) -> void:
	if hazard_runtime == null:
		_hazard_pending.clear()
		return
	for index: int in range(_hazard_pending.size() - 1, -1, -1):
		var record: Dictionary = _hazard_pending[index]
		record.remaining = maxf(float(record.remaining) - delta, 0.0)
		if not is_zero_approx(float(record.remaining)):
			continue
		var activated: EnvironmentalHazard2D = hazard_runtime.activate(
			StringName(record.hazard_id),
			record.position as Vector2,
			int(record.facing),
			bool(record.get("auto_trigger", true))
		)
		_hazard_pending.remove_at(index)
		if activated == null:
			continue


func _process_legacy(delta: float) -> void:
	if not running or runtime == null or completed:
		return
	_process_legacy_pending(delta)
	if not _pending.is_empty() or runtime.active_count() > 0:
		return
	if _respite_remaining <= 0.0:
		_respite_remaining = EnemySpawnTuning.scaled_interval(
			waves[phase_index].minimum_respite
		)
	_respite_remaining = maxf(_respite_remaining - delta, 0.0)
	if not is_zero_approx(_respite_remaining):
		return
	if phase_index >= waves.size() - 1:
		completed = true
		running = false
		district_completed.emit()
	else:
		_advance_phase()


func _process_legacy_pending(delta: float) -> void:
	for index: int in range(_pending.size() - 1, -1, -1):
		var record: Dictionary = _pending[index]
		record.remaining = maxf(float(record.remaining) - delta, 0.0)
		if not is_zero_approx(float(record.remaining)):
			continue
		var entry: EnemySpawnEntry = record.entry
		if runtime.acquire(StringName(entry.kind), entry.position) != null:
			_pending.remove_at(index)


func _seed_current_facade_engagement() -> void:
	if runtime == null or runtime.world_stream == null:
		return
	var logical_chunk: int = runtime.world_stream.current_logical_chunk
	if CityDistrictCatalog.chunk_hosts_facade(logical_chunk):
		_engaged_facade_chunks[logical_chunk] = true


func _try_emit_held_act_completion(act: DistrictAct) -> void:
	if _act_completion_emitted or act_elapsed < _scaled_target_duration(act):
		return
	var overrun_deadline: float = (
		_scaled_target_duration(act)
		+ EnemySpawnTuning.scaled_interval(MAXIMUM_ACT_OVERRUN)
	)
	if _threat_weight() > LOW_THREAT_WEIGHT and act_elapsed < overrun_deadline:
		return
	_act_completion_emitted = true
	act_completed.emit(phase_index, act.act_id, act.display_name)
	if not act.milestone_after.is_empty():
		milestone_reached.emit(act.milestone_after)


func _resolve_position(
	entry: EnemySpawnEntry,
	spawn_anchor: String = "",
	extra_offset: Vector2 = Vector2.ZERO
) -> Vector2:
	var resolved_anchor: String = entry.spawn_anchor if spawn_anchor.is_empty() else spawn_anchor
	return runtime.resolve_spawn_position(
		entry.position,
		StringName(resolved_anchor),
		entry.offset + extra_offset
	)


func rebase_cached_world_state(offset: Vector2) -> void:
	for record: Dictionary in _hazard_pending:
		record.position = (record.position as Vector2) + offset


func _roll_elite_plan(
	act: DistrictAct,
	beat: DistrictBeat,
	pressure_source: Variant = 0
) -> Dictionary[int, StringName]:
	var plan: Dictionary[int, StringName] = {}
	if not act.elite_allowed:
		return plan
	var eligible: Array[int] = []
	for entry_index: int in range(beat.spawns.size()):
		if beat.spawns[entry_index].trait_id.is_empty():
			eligible.append(entry_index)
	if eligible.is_empty():
		return plan
	var profile: DistrictPressureProfile = DistrictPressureCatalog.coerce_profile(
		pressure_source
	)
	var elite_count: int = mini(
		act.elite_units_per_beat + profile.elite_bonus,
		mini(eligible.size(), 3)
	)
	for elite_index: int in range(elite_count):
		var eligible_draw: int = _elite_rng.randi_range(0, eligible.size() - 1)
		var entry_index: int = eligible.pop_at(eligible_draw)
		var affix_limit: int = 2 if phase_index == 3 else ELITE_AFFIXES.size()
		var trait_id: StringName = ELITE_AFFIXES[_elite_rng.randi_range(0, affix_limit - 1)]
		elite_roll_count += 2
		plan[entry_index] = trait_id
		var entry: EnemySpawnEntry = beat.spawns[entry_index]
		elite_assignments.append({
			"act_index": phase_index,
			"beat_id": beat.beat_id,
			"entry_index": entry_index,
			"kind": StringName(entry.kind),
			"trait_id": trait_id,
		})
	return plan


func _mirrored_anchor(spawn_anchor: String) -> String:
	match spawn_anchor:
		"AHEAD":
			return "BEHIND"
		"BEHIND":
			return "AHEAD"
		"CAMERA_LEFT":
			return "CAMERA_RIGHT"
		"CAMERA_RIGHT":
			return "CAMERA_LEFT"
		_:
			return spawn_anchor


func _threat_weight() -> int:
	var weight: int = 0
	for actor: EnemyActor2D in runtime.all_actors():
		if not actor.active or actor.dead:
			continue
		var kind: StringName = &"soldier"
		if actor is ProceduralEnemy:
			kind = (actor as ProceduralEnemy).archetype_id
		elif actor is TankEnemy:
			kind = &"tank"
		elif actor is HelicopterEnemy:
			kind = &"helicopter"
		weight += EnemyArchetypeCatalog.threat_cost(kind)
	return weight


func _progression_tier() -> int:
	return _effective_pressure_profile().district_index


func _scaled_target_duration(act: DistrictAct) -> float:
	return (
		EnemySpawnTuning.scaled_interval(act.target_duration)
		if act != null
		else 0.0
	)


func _progression_copy_plan(
	beat: DistrictBeat,
	pressure_source: Variant
) -> Dictionary[int, int]:
	var plan: Dictionary[int, int] = {}
	var profile: DistrictPressureProfile = DistrictPressureCatalog.coerce_profile(
		pressure_source
	)
	if beat == null or beat.spawns.is_empty() or profile.threat_allowance <= 0:
		return plan
	var available_threat: int = mini(
		EnemySpawnTuning.scaled_threat(profile.threat_allowance),
		EnemySpawnTuning.scaled_threat(profile.live_threat_ceiling)
		- _threat_weight()
		- _planned_threat(beat, {})
	)
	if available_threat <= 0:
		return plan
	var start_index: int = wrapi(
		absi(runtime.world_stream.current_logical_chunk) + beat_index + 1,
		0,
		beat.spawns.size()
	)
	var candidates: Array[Dictionary] = []
	for offset: int in range(beat.spawns.size()):
		var entry_index: int = wrapi(start_index + offset, 0, beat.spawns.size())
		var entry: EnemySpawnEntry = beat.spawns[entry_index]
		candidates.append({
			"entry_index": entry_index,
			"cost": EnemySpawnTuning.scaled_threat(
				EnemyArchetypeCatalog.threat_cost(StringName(entry.kind))
			),
			"rotation": offset,
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.cost) == int(b.cost):
			return int(a.rotation) < int(b.rotation)
		return int(a.cost) < int(b.cost)
	)
	for candidate: Dictionary in candidates:
		var cost: int = int(candidate.cost)
		if cost <= 0 or cost > available_threat:
			continue
		plan[int(candidate.entry_index)] = 1
		available_threat -= cost
	return plan


func _effective_pressure_profile() -> DistrictPressureProfile:
	if runtime == null or runtime.world_stream == null:
		return DistrictPressureCatalog.profile_by_index(0)
	var authored: DistrictPressureProfile = DistrictPressureCatalog.authored_profile(
		runtime.world_stream.current_district_id
	)
	return authored if authored != null else DistrictPressureCatalog.profile_by_index(0)


func _planned_threat(beat: DistrictBeat, extra_copies: Dictionary) -> int:
	var threat: int = _threat_weight()
	for entry_index: int in range(beat.spawns.size()):
		var entry: EnemySpawnEntry = beat.spawns[entry_index]
		var kind: StringName = StringName(entry.kind)
		var count: int = EnemySpawnTuning.scaled_count(
			EnemyArchetypeCatalog.spawn_multiplier(kind)
			+ int(extra_copies.get(entry_index, 0))
		)
		threat += EnemyArchetypeCatalog.threat_cost(kind) * count
	return threat


func _authored_threat(beat: DistrictBeat) -> int:
	var threat: int = 0
	for entry: EnemySpawnEntry in beat.spawns:
		var kind: StringName = StringName(entry.kind)
		threat += EnemyArchetypeCatalog.threat_cost(kind) * EnemySpawnTuning.scaled_count(
			EnemyArchetypeCatalog.spawn_multiplier(kind)
		)
	return threat


func _dictionary_total(values: Dictionary) -> int:
	var total: int = 0
	for value: int in values.values():
		total += value
	return total
