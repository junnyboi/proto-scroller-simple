class_name HapticsAdapter
extends Node

const AUTO_GAMEPAD_DEVICE: int = -2
const MIN_RUMBLE_SECONDS: float = 0.02
const MAX_RUMBLE_SECONDS: float = 0.12

@export var enabled: bool = true
@export_range(-1, 1, 1) var detection_override: int = -1
@export_range(-2, 8, 1) var gamepad_device_override: int = AUTO_GAMEPAD_DEVICE

var request_count: int = 0
var last_duration_ms: int = 0
var mobile_device_detected: bool = false
var gamepad_device_id: int = -1
var gamepad_vibration_request_count: int = 0
var last_weak_magnitude: float = 0.0
var last_strong_magnitude: float = 0.0
var last_gamepad_duration_seconds: float = 0.0


func _ready() -> void:
	mobile_device_detected = _detect_mobile_device()
	gamepad_device_id = _detect_gamepad_device()
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)


func setup(
	p_detection_override: int = -1,
	p_gamepad_device_override: int = AUTO_GAMEPAD_DEVICE
) -> void:
	detection_override = p_detection_override
	gamepad_device_override = p_gamepad_device_override


func pulse(duration_ms: int) -> bool:
	if not enabled:
		return false
	last_duration_ms = clampi(duration_ms, 1, 100)
	var mobile_requested: bool = _pulse_mobile()
	var gamepad_requested: bool = _pulse_gamepad()
	if not mobile_requested and not gamepad_requested:
		return false
	request_count += 1
	return true


func cancel() -> void:
	if detection_override < 0:
		if OS.has_feature("web"):
			JavaScriptBridge.eval("navigator.vibrate && navigator.vibrate(0)", true)
		else:
			Input.vibrate_handheld(0)
	if gamepad_device_id >= 0 and gamepad_device_override == AUTO_GAMEPAD_DEVICE:
		Input.stop_joy_vibration(gamepad_device_id)


func reset_runtime_state() -> void:
	cancel()
	request_count = 0
	last_duration_ms = 0
	gamepad_vibration_request_count = 0
	last_weak_magnitude = 0.0
	last_strong_magnitude = 0.0
	last_gamepad_duration_seconds = 0.0


func _pulse_mobile() -> bool:
	if not mobile_device_detected:
		return false
	if detection_override >= 0:
		return true
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"navigator.vibrate && navigator.vibrate(%d)" % last_duration_ms,
			true
		)
		return true
	Input.vibrate_handheld(last_duration_ms)
	return true


func _pulse_gamepad() -> bool:
	if (
		gamepad_device_id < 0
		or not InputBindingSettings.controller_vibration_enabled()
		or not bool(RuntimeTweakAccess.live_value(
			&"input.controller_vibration_enabled", true
		))
	):
		return false
	var intensity: float = clampf(float(last_duration_ms) / 100.0, 0.0, 1.0)
	last_weak_magnitude = lerpf(0.18, 0.55, intensity)
	last_strong_magnitude = lerpf(0.35, 1.0, intensity)
	last_gamepad_duration_seconds = clampf(
		float(last_duration_ms) / 1000.0,
		MIN_RUMBLE_SECONDS,
		MAX_RUMBLE_SECONDS
	)
	gamepad_vibration_request_count += 1
	if gamepad_device_override == AUTO_GAMEPAD_DEVICE:
		Input.start_joy_vibration(
			gamepad_device_id,
			last_weak_magnitude,
			last_strong_magnitude,
			last_gamepad_duration_seconds
		)
	return true


func _detect_mobile_device() -> bool:
	if detection_override >= 0:
		return detection_override == 1
	if OS.has_feature("web"):
		var browser_touch: Variant = JavaScriptBridge.eval(
			"(navigator.maxTouchPoints || 0) > 0",
			true
		)
		if bool(browser_touch):
			return true
	return (
		OS.has_feature("mobile")
		or OS.has_feature("android")
		or OS.has_feature("ios")
		or DisplayServer.is_touchscreen_available()
	)


func _detect_gamepad_device() -> int:
	if gamepad_device_override != AUTO_GAMEPAD_DEVICE:
		return gamepad_device_override
	var connected: PackedInt32Array = Input.get_connected_joypads()
	return connected[0] if not connected.is_empty() else -1


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if gamepad_device_override != AUTO_GAMEPAD_DEVICE:
		return
	if connected and gamepad_device_id < 0:
		gamepad_device_id = device
	elif not connected and device == gamepad_device_id:
		gamepad_device_id = _detect_gamepad_device()
