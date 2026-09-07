class_name CausalChainTracker
extends RefCounted

const RECORD_LIFETIME: float = 5.0
const MAX_RECORDS: int = 64

var best_depth: int = 0
var rejected_count: int = 0
var _records: Dictionary[int, Dictionary] = {}
var _order: Array[int] = []


func register(event: GameplayEvent) -> bool:
	if event == null or event.root_attack_id == 0:
		return false
	var root_id: int = event.root_attack_id
	var event_key: Variant = event.event_id if event.event_id != 0 else event.dedupe_key
	if not _records.has(root_id):
		if event.causal_depth > 0:
			rejected_count += 1
			return false
		_evict_if_needed()
		_records[root_id] = {
			"depth": 0,
			"remaining": RECORD_LIFETIME,
			"events": {event_key: true},
		}
		_order.append(root_id)
		return true
	var record: Dictionary = _records[root_id]
	var events: Dictionary = record.events
	if events.has(event_key):
		rejected_count += 1
		return false
	var current_depth: int = int(record.depth)
	if event.causal_depth > current_depth + 1:
		rejected_count += 1
		return false
	events[event_key] = true
	record.events = events
	record.depth = maxi(current_depth, event.causal_depth)
	record.remaining = RECORD_LIFETIME
	_records[root_id] = record
	best_depth = maxi(best_depth, int(record.depth))
	return true


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	for index: int in range(_order.size() - 1, -1, -1):
		var root_id: int = _order[index]
		var record: Dictionary = _records[root_id]
		record.remaining = maxf(float(record.remaining) - delta, 0.0)
		if is_zero_approx(float(record.remaining)):
			_records.erase(root_id)
			_order.remove_at(index)
		else:
			_records[root_id] = record


func active_count() -> int:
	return _records.size()


func reset() -> void:
	best_depth = 0
	rejected_count = 0
	_records.clear()
	_order.clear()


func capture_attempt_state() -> Dictionary:
	return {
		"best_depth": best_depth,
		"rejected_count": rejected_count,
		"records": _records.duplicate(true),
		"order": _order.duplicate(),
	}


func restore_attempt_state(state: Dictionary) -> void:
	best_depth = int(state.get("best_depth", best_depth))
	rejected_count = int(state.get("rejected_count", rejected_count))
	_records = state.get("records", {}).duplicate(true)
	_order.assign(state.get("order", []))


func _evict_if_needed() -> void:
	if _order.size() < MAX_RECORDS:
		return
	var oldest: int = _order.pop_front()
	_records.erase(oldest)
