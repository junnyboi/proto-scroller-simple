class_name UpgradeSession
extends Node

signal offer_opened(offer: UpgradeOffer)
signal offer_resolved(offer: UpgradeOffer, selected_id: StringName, new_rank: int)
signal upgrade_acquired(
	profile: UpgradeProfile,
	rank: int,
	max_rank: int,
	grant_id: StringName
)
signal rank_changed(upgrade_id: StringName, rank: int, max_rank: int)
signal queue_drained
signal auto_resolved(level: int, result: StringName)

enum State {
	IDLE,
	WAITING_FOR_UI_CLEAR,
	ACQUIRING_PAUSE,
	BUILDING_OFFER,
	SHOWING,
	APPLYING,
	RELEASING,
	STOPPED,
}

const SYSTEM_SALT: int = 0x51A71E5
const MAX_PENDING: int = 64
const UNACQUIRED_OFFER_WEIGHT_MULTIPLIER: int = 2

var run_seed: int
var run_generation: int
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var rng_draw_count: int = 0
var offer_sequence: int = 0
var ranks: Dictionary[StringName, int] = {}
var accepted_grant_ids: Dictionary[StringName, bool] = {}
var claimed_level_rewards: Dictionary[StringName, bool] = {}
var pending: Array[UpgradeEntitlement] = []
var active_offer: UpgradeOffer
var pause_token: int = 0
var state: State = State.IDLE
var stopped: bool = false
var runtimes: Dictionary[StringName, UpgradeRuntime] = {}
var replay_records: Array[Dictionary] = []
var catalog: UpgradeCatalog
var pause: RunPauseCoordinator
var presentation_blocked: bool = false
var _resolution_scheduled: bool = false


func setup(
	p_seed: int,
	p_catalog: UpgradeCatalog,
	p_pause: RunPauseCoordinator,
	p_runtimes: Dictionary[StringName, UpgradeRuntime],
	generation: int = 1
) -> PackedStringArray:
	run_seed = p_seed
	run_generation = generation
	catalog = p_catalog
	pause = p_pause
	runtimes = p_runtimes
	rng.seed = p_seed ^ SYSTEM_SALT
	var errors: PackedStringArray = []
	if catalog == null:
		errors.append("missing catalog")
	else:
		errors.append_array(catalog.rebuild())
	if catalog != null:
		for profile: UpgradeProfile in catalog.sorted_profiles():
			if not runtimes.has(profile.runtime_key):
				errors.append("missing runtime %s" % profile.runtime_key)
			ranks[profile.upgrade_id] = 0
	return errors


func queue_level(level: int, accepted_event_id: int) -> bool:
	if stopped or level < 2 or accepted_event_id <= 0 or pending.size() >= MAX_PENDING:
		return false
	var entitlement: UpgradeEntitlement = UpgradeEntitlement.new(
		level,
		accepted_event_id,
		_count_event_entitlements(accepted_event_id)
	)
	if claimed_level_rewards.has(entitlement.claim_key):
		return false
	claimed_level_rewards[entitlement.claim_key] = true
	pending.append(entitlement)
	_schedule_resolution()
	return true


func select_choice(upgrade_id: StringName, sequence: int) -> bool:
	if stopped or active_offer == null or state != State.SHOWING:
		return false
	if active_offer.sequence != sequence or active_offer.resolved:
		return false
	if not active_offer.choice_ids.has(upgrade_id):
		return false
	state = State.APPLYING
	active_offer.resolved = true
	active_offer.selected_id = upgrade_id
	var resolved_offer: UpgradeOffer = active_offer
	active_offer = null
	var new_rank: int = _apply_upgrade(upgrade_id, resolved_offer)
	if new_rank <= 0:
		return false
	offer_resolved.emit(resolved_offer, upgrade_id, new_rank)
	_continue_resolution()
	return true


func rank_of(upgrade_id: StringName) -> int:
	return int(ranks.get(upgrade_id, 0))


func legal_profiles() -> Array[UpgradeProfile]:
	var result: Array[UpgradeProfile] = []
	if catalog == null:
		return result
	var acquired_tags: Dictionary[StringName, bool] = {}
	for profile: UpgradeProfile in catalog.sorted_profiles():
		if rank_of(profile.upgrade_id) > 0:
			for tag: String in profile.tags:
				acquired_tags[StringName(tag)] = true
	for profile: UpgradeProfile in catalog.sorted_profiles():
		if not profile.enabled or rank_of(profile.upgrade_id) >= profile.max_rank:
			continue
		var runtime: UpgradeRuntime = runtimes.get(profile.runtime_key) as UpgradeRuntime
		if runtime == null or not runtime.is_available({"session": self}):
			continue
		if _has_conflict(profile, acquired_tags):
			continue
		result.append(profile)
	return result


func set_presentation_blocked(value: bool) -> void:
	presentation_blocked = value
	if not value and state == State.WAITING_FOR_UI_CLEAR:
		_schedule_resolution()


func stop_run() -> void:
	stopped = true
	state = State.STOPPED
	active_offer = null
	pending.clear()
	_release_pause()
	for runtime: UpgradeRuntime in runtimes.values():
		runtime.stop_and_release()


func continue_cycle() -> void:
	for runtime: UpgradeRuntime in runtimes.values():
		runtime.continue_cycle()


func reset_run_for_tools(p_seed: int) -> void:
	_release_pause()
	active_offer = null
	pending.clear()
	accepted_grant_ids.clear()
	claimed_level_rewards.clear()
	replay_records.clear()
	ranks.clear()
	offer_sequence = 0
	rng_draw_count = 0
	stopped = false
	state = State.IDLE
	run_seed = p_seed
	rng.seed = p_seed ^ SYSTEM_SALT
	if catalog != null:
		for profile: UpgradeProfile in catalog.sorted_profiles():
			ranks[profile.upgrade_id] = 0
	for runtime: UpgradeRuntime in runtimes.values():
		runtime.reset_run()


func resolve_pending_for_tests() -> void:
	_resolution_scheduled = false
	_begin_resolution()


func _schedule_resolution() -> void:
	if _resolution_scheduled or stopped:
		return
	_resolution_scheduled = true
	call_deferred(&"_begin_resolution")


func _begin_resolution() -> void:
	_resolution_scheduled = false
	if stopped or active_offer != null or pending.is_empty():
		return
	if presentation_blocked:
		state = State.WAITING_FOR_UI_CLEAR
		return
	if pause_token == 0 and pause != null:
		state = State.ACQUIRING_PAUSE
		pause_token = pause.acquire(&"upgrade_choice")
	_resolve_next()


func _resolve_next() -> void:
	while not stopped and active_offer == null and not pending.is_empty():
		state = State.BUILDING_OFFER
		var entitlement: UpgradeEntitlement = pending.pop_front()
		var legal: Array[UpgradeProfile] = legal_profiles()
		offer_sequence += 1
		if legal.size() >= 2:
			var draw_before: int = rng_draw_count
			var choices: PackedStringArray = _draw_two(legal)
			active_offer = UpgradeOffer.new(
				offer_sequence,
				entitlement,
				choices,
				run_seed,
				draw_before
			)
			state = State.SHOWING
			offer_opened.emit(active_offer)
			return
		if legal.size() == 1:
			var auto_offer: UpgradeOffer = UpgradeOffer.new(
				offer_sequence,
				entitlement,
				PackedStringArray([legal[0].upgrade_id]),
				run_seed,
				rng_draw_count
			)
			auto_offer.resolved = true
			auto_offer.selected_id = legal[0].upgrade_id
			_apply_upgrade(legal[0].upgrade_id, auto_offer)
			auto_resolved.emit(entitlement.level, &"granted_single")
		else:
			auto_resolved.emit(entitlement.level, &"no_legal")
	_finish_resolution()


func _continue_resolution() -> void:
	if pending.is_empty():
		_finish_resolution()
	else:
		_resolve_next()


func _finish_resolution() -> void:
	state = State.RELEASING
	_release_pause()
	state = State.IDLE
	queue_drained.emit()


func _release_pause() -> void:
	if pause != null and pause_token != 0:
		pause.release(pause_token)
	pause_token = 0


func _draw_two(legal: Array[UpgradeProfile]) -> PackedStringArray:
	var candidates: Array[UpgradeProfile] = legal.duplicate()
	var choices: PackedStringArray = []
	for draw_index: int in range(2):
		var total_weight: int = 0
		for profile: UpgradeProfile in candidates:
			total_weight += _effective_offer_weight(profile)
		var roll: int = rng.randi_range(0, total_weight - 1)
		rng_draw_count += 1
		var cumulative: int = 0
		for index: int in range(candidates.size()):
			cumulative += _effective_offer_weight(candidates[index])
			if roll < cumulative:
				choices.append(candidates[index].upgrade_id)
				candidates.remove_at(index)
				break
	return choices


func _effective_offer_weight(profile: UpgradeProfile) -> int:
	if rank_of(profile.upgrade_id) == 0:
		return profile.offer_weight * UNACQUIRED_OFFER_WEIGHT_MULTIPLIER
	return profile.offer_weight


func _apply_upgrade(upgrade_id: StringName, offer: UpgradeOffer) -> int:
	var profile: UpgradeProfile = catalog.get_profile(upgrade_id)
	if profile == null:
		return 0
	var previous_rank: int = rank_of(upgrade_id)
	if previous_rank >= profile.max_rank:
		return 0
	var grant_id: StringName = StringName(
		"upgrade:%d:level:%d:event:%d:%s" % [
			offer.sequence,
			offer.entitlement.level,
			offer.entitlement.accepted_event_id,
			upgrade_id,
		]
	)
	if accepted_grant_ids.has(grant_id):
		return 0
	accepted_grant_ids[grant_id] = true
	var next_rank: int = previous_rank + 1
	ranks[upgrade_id] = next_rank
	var runtime: UpgradeRuntime = runtimes[profile.runtime_key]
	runtime.apply_rank(next_rank, {
		"grant_id": grant_id,
		"level": offer.entitlement.level,
		"event_id": offer.entitlement.accepted_event_id,
		"run_generation": run_generation,
	})
	upgrade_acquired.emit(profile, next_rank, profile.max_rank, grant_id)
	rank_changed.emit(upgrade_id, next_rank, profile.max_rank)
	replay_records.append({
		"offer_sequence": offer.sequence,
		"level": offer.entitlement.level,
		"event_id": offer.entitlement.accepted_event_id,
		"rng_draw_before": offer.rng_draw_before,
		"choices": offer.choice_ids,
		"selected": upgrade_id,
		"resulting_rank": next_rank,
	})
	return next_rank


func _has_conflict(
	profile: UpgradeProfile,
	acquired_tags: Dictionary[StringName, bool]
) -> bool:
	for tag: String in profile.incompatible_tags:
		if acquired_tags.has(StringName(tag)):
			return true
	return false


func _count_event_entitlements(event_id: int) -> int:
	var count: int = 0
	for entitlement: UpgradeEntitlement in pending:
		if entitlement.accepted_event_id == event_id:
			count += 1
	return count
