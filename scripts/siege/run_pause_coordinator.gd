class_name RunPauseCoordinator
extends Node

signal pause_changed(paused: bool)

var dependencies: UrbanSiegeDependencies
var director: DistrictResponseDirector
var catalysts: CatalystRuntime
var hazards: HazardRuntime
var _leases: Dictionary[int, StringName] = {}
var _next_token: int = 1
var _simulation_pause: SimulationPause
var _simulation_token: int = 0
var _mobile_controls_were_enabled: bool = true


func setup(
	p_dependencies: UrbanSiegeDependencies,
	p_director: DistrictResponseDirector,
	p_catalysts: CatalystRuntime,
	p_hazards: HazardRuntime = null
) -> void:
	dependencies = p_dependencies
	director = p_director
	catalysts = p_catalysts
	hazards = p_hazards
	_simulation_pause = dependencies.city.runtime_services.simulation_pause


func acquire(reason: StringName) -> int:
	var token: int = _next_token
	_next_token += 1
	_leases[token] = reason
	if _leases.size() == 1:
		_apply_pause(true)
	return token


func release(token: int) -> bool:
	if not _leases.has(token):
		return false
	_leases.erase(token)
	if _leases.is_empty():
		_apply_pause(false)
	return true


func release_all() -> void:
	if _leases.is_empty():
		return
	_leases.clear()
	_apply_pause(false)


func is_paused() -> bool:
	return not _leases.is_empty()


func lease_count() -> int:
	return _leases.size()


func lease_reasons() -> Array[StringName]:
	var reasons: Array[StringName] = []
	for reason: StringName in _leases.values():
		reasons.append(reason)
	reasons.sort_custom(func(first: StringName, second: StringName) -> bool:
		return String(first) < String(second)
	)
	return reasons


func _apply_pause(paused: bool) -> void:
	var city: CitySlice = dependencies.city
	if paused:
		_simulation_token = _simulation_pause.acquire(&"modal")
		_mobile_controls_were_enabled = city.mobile_controls.controls_enabled()
		city.mobile_controls.set_controls_enabled(false)
		# A held charge loses its input owner when a modal opens. Cancel it without
		# releasing a strike; already committed melee and dodge resume in place.
		if city.contextual_attacks.is_charging():
			city.contextual_attacks.cancel_attack()
	else:
		city.mobile_controls.set_controls_enabled(_mobile_controls_were_enabled)
	city.robot.discard_modal_input()
	for action: StringName in [&"move_left", &"move_right", &"stomp", &"dodge"]:
		Input.action_release(action)
	if hazards != null:
		hazards.set_paused(paused)
	if not paused:
		_release_simulation()
	pause_changed.emit(paused)


func _release_simulation() -> void:
	if is_instance_valid(_simulation_pause) and _simulation_token != 0:
		_simulation_pause.release(_simulation_token)
	_simulation_token = 0


func _exit_tree() -> void:
	_release_simulation()
