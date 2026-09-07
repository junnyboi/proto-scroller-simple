class_name MomentumMeter
extends Node

signal momentum_changed(value: float, band: int)
signal overdrive_ready
signal overdrive_active_changed(active: bool)

enum Band {
	NORMAL,
	SURGE,
	CRITICAL,
	READY,
}

const MAX_VALUE: float = 100.0
const SURGE_THRESHOLD: float = 40.0
const CRITICAL_THRESHOLD: float = 80.0
const GAIN_SPEED_RATIO: float = 0.70
const IDLE_SPEED_RATIO: float = 0.20
const MOTION_GAIN_PER_SECOND: float = 12.0
const IDLE_LOSS_PER_SECOND: float = 10.0
const IDLE_GRACE_SECONDS: float = 1.0

var value: float = 0.0
var _idle_elapsed: float = 0.0
var _ready_locked: bool = false
var _overdrive_active: bool = false


func advance_motion(actual_speed_ratio: float, delta: float) -> void:
	if _ready_locked or _overdrive_active or delta <= 0.0:
		return
	if actual_speed_ratio >= GAIN_SPEED_RATIO:
		_idle_elapsed = 0.0
		_set_value(value + MOTION_GAIN_PER_SECOND * delta)
	elif actual_speed_ratio < IDLE_SPEED_RATIO:
		var previous_idle: float = _idle_elapsed
		_idle_elapsed += delta
		var decay_time: float = maxf(
			_idle_elapsed - maxf(previous_idle, IDLE_GRACE_SECONDS),
			0.0
		)
		if decay_time > 0.0:
			_set_value(value - IDLE_LOSS_PER_SECOND * decay_time)
	else:
		_idle_elapsed = 0.0


func apply_event(event: GameplayEvent) -> void:
	if event == null or _ready_locked or _overdrive_active or is_zero_approx(event.momentum_delta):
		return
	_set_value(value + event.momentum_delta)


func band() -> Band:
	if value >= MAX_VALUE:
		return Band.READY
	if value >= CRITICAL_THRESHOLD:
		return Band.CRITICAL
	if value >= SURGE_THRESHOLD:
		return Band.SURGE
	return Band.NORMAL


func is_ready() -> bool:
	return _ready_locked


func is_overdrive_active() -> bool:
	return _overdrive_active


func consume_ready() -> bool:
	if not _ready_locked or _overdrive_active:
		return false
	_ready_locked = false
	value = 0.0
	_idle_elapsed = 0.0
	momentum_changed.emit(value, band())
	return true


func set_overdrive_active(active: bool) -> void:
	if _overdrive_active == active:
		return
	_overdrive_active = active
	overdrive_active_changed.emit(active)


func acceleration_multiplier() -> float:
	return 1.08 if value >= SURGE_THRESHOLD else 1.0


func reset_run() -> void:
	value = 0.0
	_idle_elapsed = 0.0
	_ready_locked = false
	_overdrive_active = false


func _set_value(next_value: float) -> void:
	var clamped_value: float = clampf(next_value, 0.0, MAX_VALUE)
	if is_equal_approx(clamped_value, value):
		return
	value = clamped_value
	if value >= MAX_VALUE:
		_ready_locked = true
	momentum_changed.emit(value, band())
	if _ready_locked:
		overdrive_ready.emit()
