class_name RuntimeTweakPauseAdapter
extends RefCounted
## Gameplay modals delegate to the city's shared pause owner. Title modals own
## only their title-tree pause and focus; they never restore a gameplay lease.

var pause_coordinator: RunPauseCoordinator
var pause_token: int = 0
var _tree: SceneTree
var _tree_was_paused: bool = false
var _return_focus: Control
var _active: bool = false


func acquire(target_city: CitySlice, context: Node = null, reason: StringName = &"runtime_tuning") -> bool:
	if _active:
		return false
	var owner: Node = context if context != null else target_city
	if not is_instance_valid(owner) or not owner.is_inside_tree():
		return false
	if is_instance_valid(target_city):
		if target_city.urban_siege == null or target_city.urban_siege.pause_coordinator == null:
			return false
		pause_coordinator = target_city.urban_siege.pause_coordinator
		pause_token = pause_coordinator.acquire(reason)
		if pause_token == 0:
			pause_coordinator = null
			return false
	else:
		_tree = owner.get_tree()
		_tree_was_paused = _tree.paused
		_tree.paused = true
	_return_focus = owner.get_viewport().gui_get_focus_owner()
	_active = true
	return true


func release() -> bool:
	if not _active:
		return false
	if is_instance_valid(pause_coordinator) and pause_token != 0:
		pause_coordinator.release(pause_token)
	if is_instance_valid(_tree):
		_tree.paused = _tree_was_paused
	if is_instance_valid(_return_focus) and _return_focus.is_inside_tree():
		_return_focus.call_deferred("grab_focus")
	pause_token = 0
	pause_coordinator = null
	_tree = null
	_return_focus = null
	_active = false
	return true


func is_active() -> bool:
	return _active
