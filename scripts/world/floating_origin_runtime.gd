class_name FloatingOriginRuntime
extends RefCounted

const REBASE_CHUNK_INTERVAL: int = 32

var origin_chunk: int = 0
var shift_count: int = 0
var total_rebased_chunks: int = 0


func required_chunk_shift(runtime_x: float, chunk_width: float) -> int:
	var runtime_chunk: int = floori(runtime_x / chunk_width)
	if absi(runtime_chunk) < REBASE_CHUNK_INTERVAL:
		return 0
	return runtime_chunk


func commit(chunk_delta: int) -> void:
	if chunk_delta == 0:
		return
	origin_chunk += chunk_delta
	shift_count += 1
	total_rebased_chunks += absi(chunk_delta)


func apply_to_scene(root: Node, offset: Vector2, excluded: Array[Node]) -> int:
	var shifted_roots: int = 0
	for child: Node in root.get_children():
		shifted_roots += _shift_spatial_roots(child, offset, false, excluded)
	_rebase_cached_state(root, offset)
	return shifted_roots


func reset() -> void:
	origin_chunk = 0
	shift_count = 0
	total_rebased_chunks = 0


func _shift_spatial_roots(
	node: Node,
	offset: Vector2,
	ancestor_shifted: bool,
	excluded: Array[Node]
) -> int:
	if excluded.has(node) or node is CanvasLayer or node is Control:
		return 0
	var shifted: bool = ancestor_shifted
	var count: int = 0
	if node is Node2D and not ancestor_shifted:
		var node_2d: Node2D = node as Node2D
		node_2d.global_position += offset
		node_2d.reset_physics_interpolation()
		shifted = true
		count = 1
	for child: Node in node.get_children():
		count += _shift_spatial_roots(child, offset, shifted, excluded)
	return count


func _rebase_cached_state(node: Node, offset: Vector2) -> void:
	if node.has_method("rebase_cached_world_state"):
		node.call("rebase_cached_world_state", offset)
	elif node.has_method("_rebase_cached_world_state"):
		node.call("_rebase_cached_world_state", offset)
	for child: Node in node.get_children():
		_rebase_cached_state(child, offset)
