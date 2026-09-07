class_name CapacityReservationLedger
extends RefCounted

var denial_count: int = 0
var peak_pending: int = 0
var _reservations: Dictionary[int, Dictionary] = {}
var _next_id: int = 1


func reserve_beat(beat: DistrictBeat, runtime: EncounterRuntime) -> int:
	return reserve_counts(counts_for_beat(beat), runtime)


func reserve_counts(
	counts: Dictionary[StringName, int],
	runtime: EncounterRuntime
) -> int:
	if runtime == null or not can_commit_counts(counts, runtime):
		denial_count += 1
		return 0
	var reservation_id: int = _next_id
	_next_id += 1
	_reservations[reservation_id] = counts
	peak_pending = maxi(peak_pending, pending_count())
	return reservation_id


func consume_actor(reservation_id: int, kind: StringName) -> bool:
	if not _reservations.has(reservation_id):
		return false
	var key: StringName = EnemyArchetypeCatalog.reservation_key(kind)
	var counts: Dictionary = _reservations[reservation_id]
	if int(counts.get(key, 0)) <= 0:
		return false
	counts[key] = int(counts[key]) - 1
	if _dictionary_total(counts) <= 0:
		_reservations.erase(reservation_id)
	return true


func cancel(reservation_id: int) -> void:
	_reservations.erase(reservation_id)


func cancel_all() -> void:
	_reservations.clear()


func pending_count(kind: StringName = &"") -> int:
	var total: int = 0
	var key: StringName = EnemyArchetypeCatalog.reservation_key(kind) if not kind.is_empty() else &""
	for counts: Dictionary in _reservations.values():
		total += _dictionary_total(counts) if key.is_empty() else int(counts.get(key, 0))
	return total


func reservation_count() -> int:
	return _reservations.size()


func can_commit(beat: DistrictBeat, runtime: EncounterRuntime) -> bool:
	if beat == null or runtime == null:
		return false
	return can_commit_counts(counts_for_beat(beat), runtime)


func can_commit_counts(
	counts: Dictionary[StringName, int],
	runtime: EncounterRuntime
) -> bool:
	if runtime == null:
		return false
	if counts.is_empty():
		return false
	for key: StringName in counts:
		var requested: int = int(counts.get(key, 0))
		var unreserved: int = runtime.available_reservation_capacity(key) - _pending_for_key(key)
		if requested > unreserved:
			return false
	return true


func counts_for_beat(beat: DistrictBeat) -> Dictionary[StringName, int]:
	var counts: Dictionary[StringName, int] = {}
	if beat == null:
		return counts
	for entry: EnemySpawnEntry in beat.spawns:
		var kind: StringName = StringName(entry.kind)
		if not EnemyArchetypeCatalog.is_valid_kind(kind):
			continue
		var key: StringName = EnemyArchetypeCatalog.reservation_key(kind)
		counts[key] = (
			int(counts.get(key, 0))
			+ EnemySpawnTuning.scaled_count(
				EnemyArchetypeCatalog.spawn_multiplier(kind)
			)
		)
	return counts


func _pending_for_key(key: StringName) -> int:
	var total: int = 0
	for counts: Dictionary in _reservations.values():
		total += int(counts.get(key, 0))
	return total


func _dictionary_total(counts: Dictionary) -> int:
	var total: int = 0
	for value: int in counts.values():
		total += value
	return total
