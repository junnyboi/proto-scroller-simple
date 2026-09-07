class_name LeaderboardBridge
extends Node

signal state_changed(state: StringName)

## Retained reference protocol; this template has no global-leaderboard opt-in.
const GLOBAL_ENABLED: bool = false
const CHANNEL: String = "proto-scroller-leaderboard"
const PROTOCOL_VERSION: int = 1
const REQUEST_TIMEOUT_SECONDS: float = 4.0
const LIST_LIMIT: int = 10
const MAX_RESPONSE_ROWS: int = 20
const QUEUE_NAME: String = "__PROTO_SCROLLER_LEADERBOARD_RESPONSES__"

var profile_store: PlayerCombatProfileStore
var panel: Node
var state: StringName = &"native_local"
var last_submission_blocked: bool = false
var _request_counter: int = 0
var _submitted_run_ids: Array[String] = []
var _pending: Dictionary = {}


func setup(store: PlayerCombatProfileStore, leaderboard_panel: Node) -> void:
	profile_store = store
	panel = leaderboard_panel
	if panel != null:
		if panel.has_signal(&"global_refresh_requested"):
			panel.connect(&"global_refresh_requested", request_list)
		if panel.has_signal(&"callsign_saved"):
			panel.connect(&"callsign_saved", _on_callsign_saved)
	if not GLOBAL_ENABLED or not OS.has_feature("web"):
		_set_state(&"native_local")
		set_process(false)
		return
	_install_receiver()
	set_process(true)
	_set_state(&"syncing")
	request_list()


func submit_summary(summary: RunSummarySnapshot) -> void:
	if profile_store == null or summary == null:
		return
	if not summary.tuning_ranked_eligible or summary.tutorial_run or summary.debug_run:
		last_submission_blocked = true
		_set_state(&"unranked")
		return
	last_submission_blocked = false
	if not summary.run_id.is_empty() and summary.run_id in _submitted_run_ids:
		return
	if not GLOBAL_ENABLED or not OS.has_feature("web"):
		_set_state(&"native_local")
		return
	if _send_request(&"submit", profile_store.leaderboard_candidate(summary, _build_revision())) and not summary.run_id.is_empty():
		_submitted_run_ids.append(summary.run_id)
		if _submitted_run_ids.size() > 128:
			_submitted_run_ids.pop_front()


func request_list() -> void:
	if profile_store == null:
		_set_state(&"local_fallback")
		return
	if not GLOBAL_ENABLED or not OS.has_feature("web"):
		_set_state(&"native_local")
		return
	_set_state(&"syncing")
	var profile: Dictionary = profile_store.snapshot()
	_send_request(&"list", {
		"anonymous_profile_id": String(profile.get("anonymous_profile_id", "")),
		"limit": LIST_LIMIT,
	})


func debug_snapshot() -> Dictionary:
	return {
		"state": String(state),
		"pending_count": _pending.size(),
		"request_counter": _request_counter,
		"last_submission_blocked": last_submission_blocked,
	}


func _process(_delta: float) -> void:
	if not GLOBAL_ENABLED or not OS.has_feature("web"):
		return
	_poll_response_queue()
	var now: float = Time.get_ticks_msec() / 1000.0
	var timed_out: Array[String] = []
	var callsign_timed_out: bool = false
	for request_id: Variant in _pending:
		var request: Dictionary = _pending[request_id] as Dictionary
		if now >= float(request.get("deadline", 0.0)):
			timed_out.append(String(request_id))
	for request_id: String in timed_out:
		var request: Dictionary = _pending.get(request_id, {}) as Dictionary
		if StringName(request.get("type", &"")) == &"update_callsign":
			callsign_timed_out = true
		_pending.erase(request_id)
	if callsign_timed_out and is_instance_valid(panel):
		_call_panel(&"set_callsign_uplink_state", [&"failure"])
	if not timed_out.is_empty():
		_set_state(&"local_fallback")


func _on_callsign_saved(callsign: String) -> void:
	if profile_store == null or not OS.has_feature("web"):
		return
	var profile: Dictionary = profile_store.snapshot()
	_send_request(&"update_callsign", {
		"anonymous_profile_id": String(profile.get("anonymous_profile_id", "")),
		"callsign": callsign,
		"build_revision": _build_revision(),
	})


func _send_request(request_type: StringName, payload: Dictionary) -> bool:
	if not GLOBAL_ENABLED:
		return false
	# Bound outstanding requests, even when the host never responds.
	if _pending.size() >= 8:
		_set_state(&"local_fallback")
		return false
	_request_counter += 1
	var request_id: String = "%d-%d" % [Time.get_ticks_msec(), _request_counter]
	var envelope: Dictionary = {
		"channel": CHANNEL,
		"version": PROTOCOL_VERSION,
		"type": String(request_type),
		"requestId": request_id,
		"payload": payload,
	}
	var encoded: String = JSON.stringify(envelope)
	var script: String = "window.parent.postMessage(%s, window.location.origin); true;" % encoded
	var sent: bool = bool(JavaScriptBridge.eval(script, true))
	if not sent:
		if request_type == &"update_callsign" and is_instance_valid(panel):
			_call_panel(&"set_callsign_uplink_state", [&"failure"])
		_set_state(&"local_fallback")
		return false
	_pending[request_id] = {
		"type": request_type,
		"deadline": Time.get_ticks_msec() / 1000.0 + float(
			RuntimeTweakAccess.live_value(
				&"interface.leaderboard_timeout_seconds", REQUEST_TIMEOUT_SECONDS
			)
		),
	}

	return true

func _build_revision() -> String:
	if not GLOBAL_ENABLED or not OS.has_feature("web"):
		return "native"
	return String(JavaScriptBridge.eval(
		"String(window.__PROTO_SCROLLER_SOURCE_REVISION__ || 'web-development')",
		true
	)).left(64)


func _install_receiver() -> void:
	var script: String = """
(() => {
  if (window.__PROTO_SCROLLER_LEADERBOARD_RECEIVER__) return true;
  window.__PROTO_SCROLLER_LEADERBOARD_RECEIVER__ = true;
  window.%s = window.%s || [];
  window.addEventListener('message', (event) => {
    if (event.origin !== window.location.origin || event.source !== window.parent) return;
    const data = event.data;
    if (!data || data.channel !== %s || data.version !== %d ||
        typeof data.requestId !== 'string') return;
    const queue = window.%s;
    queue.push(JSON.stringify(data));
    while (queue.length > 20) queue.shift();
  });
  return true;
})()
""" % [QUEUE_NAME, QUEUE_NAME, JSON.stringify(CHANNEL), PROTOCOL_VERSION, QUEUE_NAME]
	if not bool(JavaScriptBridge.eval(script, true)):
		_set_state(&"local_fallback")


func _poll_response_queue() -> void:
	for _index: int in range(4):
		var raw: Variant = JavaScriptBridge.eval(
			"(window.%s || []).shift() || '';" % QUEUE_NAME,
			true
		)
		var encoded: String = String(raw)
		if encoded.is_empty():
			return
		var parser: JSON = JSON.new()
		if parser.parse(encoded) != OK or not parser.data is Dictionary:
			continue
		_handle_response(parser.data as Dictionary)


func _handle_response(response: Dictionary) -> void:
	if (
		_safe_text(response.get("channel", "")) != CHANNEL
		or _safe_int(response.get("version", 0)) != PROTOCOL_VERSION
	):
		return
	var request_id: String = _safe_text(response.get("requestId", ""))
	if request_id.is_empty() or not _pending.has(request_id):
		return
	var request: Dictionary = _pending[request_id] as Dictionary
	var request_type: StringName = StringName(request.get("type", &""))
	_pending.erase(request_id)
	if not bool(response.get("ok", false)):
		if request_type == &"update_callsign":
			var error_code: String = _safe_text(response.get("error", "UPLINK_UNAVAILABLE"))
			_call_panel(&"set_callsign_uplink_state", [
				&"rejected" if error_code == "CALLSIGN_REJECTED" else &"failure"
			])
			return
		_set_state(&"local_fallback")
		return
	var raw_data: Variant = response.get("data", {})
	if not raw_data is Dictionary:
		_set_state(&"local_fallback")
		return
	var data: Dictionary = raw_data as Dictionary
	var raw_entries: Variant = data.get("entries", [])
	var entries: Array[Dictionary] = _sanitize_entries(raw_entries if raw_entries is Array else [])
	var personal_value: Variant = data.get("personalRank", {})
	var personal_rank: Dictionary = (
		_sanitize_personal_rank(personal_value as Dictionary)
		if personal_value is Dictionary
		else {}
	)
	_set_state(&"online", entries, personal_rank)
	if request_type == &"update_callsign" and is_instance_valid(panel):
		_call_panel(&"set_callsign_uplink_state", [&"success"])


func _sanitize_entries(raw_entries: Array) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for raw: Variant in raw_entries:
		if entries.size() >= MAX_RESPONSE_ROWS:
			break
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw as Dictionary
		var rank: int = clampi(_safe_int(entry.get("rank", 0)), 1, 1_000_000)
		var callsign: String = _safe_text(entry.get("callsign", "UNKNOWN")).left(20)
		entries.append({
			"rank": rank,
			"callsign": callsign,
			"highest_combo_tier": clampi(
				_safe_int(entry.get("highestComboTier", entry.get("highest_combo_tier", 0))),
				0,
				1_000_000
			),
			"best_score": clampi(
				_safe_int(entry.get("bestScore", entry.get("best_score", 0))),
				0,
				9_000_000_000_000
			),
			"best_physical_chain": clampi(
				_safe_int(entry.get("bestPhysicalChain", entry.get("best_physical_chain", 0))),
				0,
				1_000_000
			),
			"preferred_weapon": _safe_text(
				entry.get("preferredWeapon", entry.get("preferred_weapon", "UNKNOWN"))
			).left(32),
		})
	return entries


func _sanitize_personal_rank(raw: Dictionary) -> Dictionary:
	if raw.is_empty():
		return {}
	return {
		"rank": clampi(_safe_int(raw.get("rank", 0)), 1, 1_000_000),
		"callsign": _safe_text(raw.get(
			"callsign",
			profile_store.callsign() if profile_store != null else "UNKNOWN"
		)).left(20),
	}


func _set_state(
	new_state: StringName,
	entries: Array[Dictionary] = [],
	personal_rank: Dictionary = {}
) -> void:
	state = new_state
	if is_instance_valid(panel):
		_call_panel(&"set_global_state", [new_state, entries, personal_rank])
	state_changed.emit(new_state)


func _call_panel(method: StringName, arguments: Array = []) -> void:
	if is_instance_valid(panel) and panel.has_method(method):
		panel.callv(method, arguments)


func _safe_int(value: Variant) -> int:
	return int(clampf(float(value), 0, 9_000_000_000_000)) if (value is int or value is float) and is_finite(float(value)) else 0


func _safe_text(value: Variant) -> String:
	return value if value is String else ""
