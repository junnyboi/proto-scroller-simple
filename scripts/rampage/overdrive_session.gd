class_name OverdriveSession
extends Node

signal activated(attack_id: int)
signal time_changed(remaining: float)
signal ended

const DURATION_SECONDS: float = 4.0
const FORCE_MULTIPLIER: float = 1.25
const STRUCTURE_MULTIPLIER: float = 1.25
const ACCELERATION_MULTIPLIER: float = 1.15
var momentum_meter: MomentumMeter
var robot: GiantRobotController
var active: bool = false
var remaining: float = 0.0
var activation_count: int = 0
var _active_attack_id: int = 0


func setup(p_meter: MomentumMeter, p_robot: GiantRobotController) -> void:
	momentum_meter = p_meter
	robot = p_robot


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if not active:
		return
	remaining = maxf(remaining - delta, 0.0)
	time_changed.emit(remaining)
	if is_zero_approx(remaining):
		end_overdrive()


func consume_ready_for_attack(attack_id: int) -> bool:
	if active or momentum_meter == null or not momentum_meter.consume_ready():
		return false
	active = true
	remaining = DURATION_SECONDS
	activation_count += 1
	_active_attack_id = attack_id
	momentum_meter.set_overdrive_active(true)
	set_process(true)
	activated.emit(attack_id)
	time_changed.emit(remaining)
	return true


func force_multiplier() -> float:
	return FORCE_MULTIPLIER if active else 1.0


func structure_multiplier() -> float:
	return STRUCTURE_MULTIPLIER if active else 1.0


func acceleration_multiplier() -> float:
	return ACCELERATION_MULTIPLIER if active else 1.0


func has_opening_compression(attack_id: int) -> bool:
	return active and attack_id == _active_attack_id


func end_overdrive() -> void:
	if not active:
		return
	active = false
	remaining = 0.0
	_active_attack_id = 0
	set_process(false)
	if momentum_meter != null:
		momentum_meter.set_overdrive_active(false)
	ended.emit()


func reset_run() -> void:
	end_overdrive()
	activation_count = 0
