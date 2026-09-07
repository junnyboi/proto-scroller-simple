class_name SimulationPause
extends Node

# Modal pauses and hit-stop share the tree without restoring each other's leases.
var _leases: Dictionary[int, StringName] = {}
var _next_token: int = 1
var _tree: SceneTree
var _tree_was_paused: bool = false


func acquire(reason: StringName) -> int:
	if not is_inside_tree():
		return 0
	if _leases.is_empty():
		_tree = get_tree()
		_tree_was_paused = _tree.paused
		_tree.paused = true
	var token: int = _next_token
	_next_token += 1
	_leases[token] = reason
	return token


func release(token: int) -> bool:
	if not _leases.has(token):
		return false
	_leases.erase(token)
	if _leases.is_empty():
		_restore_tree()
	return true


func _restore_tree() -> void:
	if is_instance_valid(_tree):
		_tree.paused = _tree_was_paused
	_tree = null


func _exit_tree() -> void:
	_leases.clear()
	_restore_tree()
