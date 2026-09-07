class_name HitStopLease
extends Node

const MINIMUM_DURATION_MS: int = 25
const MAXIMUM_DURATION_MS: int = 110

@export var enabled: bool = true
var simulation_pause: SimulationPause

var request_count: int = 0
var ignored_request_count: int = 0
var restore_count: int = 0
var last_duration_ms: int = 0
var _active: bool = false
var _end_usec: int = 0
var _pause_token: int = 0
var _seen_request_ids: Dictionary[int, bool] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if _active and Time.get_ticks_usec() >= _end_usec:
		cancel_and_restore()


func request(duration_ms: int, request_id: int = 0) -> bool:
	if request_id != 0 and _seen_request_ids.has(request_id):
		ignored_request_count += 1
		return false
	if request_id != 0:
		_seen_request_ids[request_id] = true
	last_duration_ms = clampi(duration_ms, MINIMUM_DURATION_MS, MAXIMUM_DURATION_MS)
	request_count += 1
	if not enabled:
		return true
	var next_end_usec: int = Time.get_ticks_usec() + last_duration_ms * 1000
	if not _active:
		if not is_instance_valid(simulation_pause):
			return false
		_pause_token = simulation_pause.acquire(&"hit_stop")
		if _pause_token == 0:
			return false
		_active = true
	_end_usec = maxi(_end_usec, next_end_usec)
	return true


func cancel_and_restore() -> void:
	if not _active:
		return
	_active = false
	_end_usec = 0
	if is_instance_valid(simulation_pause):
		simulation_pause.release(_pause_token)
	_pause_token = 0
	restore_count += 1


func reset_runtime_state() -> void:
	cancel_and_restore()
	_seen_request_ids.clear()
	request_count = 0
	ignored_request_count = 0
	last_duration_ms = 0


func is_active() -> bool:
	return _active


func _exit_tree() -> void:
	cancel_and_restore()
