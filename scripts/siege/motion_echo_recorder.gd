class_name MotionEchoRecorder
extends Node2D

const CAPACITY: int = 8
const HISTORY_SECONDS: float = 3.0
const QUANTIZATION: float = 64.0
const FOOTPRINT_SIZE: Vector2 = Vector2(144.0, 96.0)
const CYAN_FILL: Color = Color(0.08, 0.82, 0.92, 0.12)
const CYAN_EDGE: Color = Color(0.45, 0.96, 1.0, 0.92)
const HISTORY_DISPLAY_SIZE: Vector2 = Vector2(48.0, 32.0)
const SELECTED_DISPLAY_SIZE: Vector2 = Vector2(60.0, 40.0)

var count: int = 0
var armed_index: int = -1
var armed_active: bool = false
var _markers: Array[Marker2D] = []
var _damage_area: BossAttackArea2D
var _positions: PackedVector2Array = PackedVector2Array()
var _timestamps: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	_positions.resize(CAPACITY)
	_timestamps.resize(CAPACITY)
	visible = false


func setup(markers: Array[Marker2D], damage_area: BossAttackArea2D) -> bool:
	if markers.size() < CAPACITY or damage_area == null:
		return false
	_markers.assign(markers.slice(0, CAPACITY))
	_damage_area = damage_area
	deactivate()
	return true


func activate() -> void:
	visible = true
	_sync_markers()


func deactivate() -> void:
	count = 0
	armed_index = -1
	armed_active = false
	visible = false
	for marker: Marker2D in _markers:
		marker.visible = false
	if _damage_area != null:
		_damage_area.deactivate()
	_sync_marker_presentations()
	queue_redraw()


func record_motion(world_position: Vector2, timestamp: float) -> int:
	if not visible:
		return -1
	expire(timestamp)
	var quantized: Vector2 = Vector2(
		roundf(world_position.x / QUANTIZATION) * QUANTIZATION,
		roundf(world_position.y / QUANTIZATION) * QUANTIZATION
	)
	var existing: int = _index_of(quantized)
	if existing >= 0:
		for index: int in range(existing, count - 1):
			_positions[index] = _positions[index + 1]
			_timestamps[index] = _timestamps[index + 1]
		_positions[count - 1] = quantized
		_timestamps[count - 1] = timestamp
		_sync_markers()
		return count - 1
	if count >= CAPACITY:
		_shift_left()
		count = CAPACITY - 1
	_positions[count] = quantized
	_timestamps[count] = timestamp
	count += 1
	_sync_markers()
	return count - 1


func expire(timestamp: float) -> void:
	var expired: int = 0
	while expired < count and timestamp - _timestamps[expired] > HISTORY_SECONDS:
		expired += 1
	if expired == 0:
		return
	for index: int in range(count - expired):
		_positions[index] = _positions[index + expired]
		_timestamps[index] = _timestamps[index + expired]
	count -= expired
	if armed_index >= 0:
		armed_index -= expired
		if armed_index < 0:
			disarm()
	_sync_markers()


func arm_marker(index: int, attack_id: StringName) -> bool:
	if index < 0 or index >= count or _damage_area == null:
		disarm()
		return false
	armed_index = index
	armed_active = false
	_damage_area.set_presentation_role(BossAttackArea2D.PresentationRole.GENERIC)
	_damage_area.configure_footprint(
		_positions[index],
		FOOTPRINT_SIZE,
		BossAttackArea2D.VisualState.TELEGRAPH,
		attack_id
	)
	_sync_marker_presentations()
	queue_redraw()
	return true


func activate_armed_footprint() -> bool:
	if armed_index < 0 or armed_index >= count or _damage_area == null:
		return false
	armed_active = true
	_damage_area.configure_footprint(
		_positions[armed_index],
		FOOTPRINT_SIZE,
		BossAttackArea2D.VisualState.ARMED,
		&"ARMED_AFTERIMAGE"
	)
	queue_redraw()
	return true


func activate_armed_presentation() -> bool:
	if armed_index < 0 or armed_index >= count or _damage_area == null:
		return false
	armed_active = true
	_damage_area.configure_footprint(
		_positions[armed_index],
		FOOTPRINT_SIZE,
		BossAttackArea2D.VisualState.TELEGRAPH,
		&"ARMED_AFTERIMAGE"
	)
	queue_redraw()
	return true


func disarm() -> void:
	armed_index = -1
	armed_active = false
	if _damage_area != null:
		_damage_area.deactivate()
	_sync_marker_presentations()
	queue_redraw()


func history_can_damage() -> bool:
	# History uses Marker2D presentation records only; the separately configured
	# BossAttackArea2D is the sole collision-bearing afterimage.
	return false


func damage_footprint_matches_collision() -> bool:
	if not armed_active or _damage_area == null:
		return false
	var collision: CollisionShape2D = _damage_area.get_node(^"Collision") as CollisionShape2D
	var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
	return (
		not collision.disabled
		and rectangle.size.is_equal_approx(_damage_area.footprint_size)
		and _damage_area.footprint_size.is_equal_approx(FOOTPRINT_SIZE)
		and _damage_area.global_position.is_equal_approx(_positions[armed_index])
	)


func marker_positions() -> PackedVector2Array:
	return _positions.slice(0, count)


func capture_state() -> Dictionary:
	return {
		"count": count,
		"positions": marker_positions(),
		"timestamps": _timestamps.slice(0, count),
		"armed_index": armed_index,
		"armed_active": armed_active,
	}


func restore_state(state: Dictionary, attack_id: StringName = &"ARMED_AFTERIMAGE") -> void:
	count = clampi(int(state.get("count", 0)), 0, CAPACITY)
	var positions: PackedVector2Array = state.get("positions", PackedVector2Array())
	var timestamps: PackedFloat32Array = state.get("timestamps", PackedFloat32Array())
	for index: int in range(count):
		_positions[index] = positions[index] if index < positions.size() else Vector2.ZERO
		_timestamps[index] = timestamps[index] if index < timestamps.size() else 0.0
	armed_index = int(state.get("armed_index", -1))
	armed_active = bool(state.get("armed_active", false))
	activate()
	if armed_index >= 0 and armed_index < count:
		arm_marker(armed_index, attack_id)
		if armed_active:
			activate_armed_presentation()
	else:
		disarm()


func _index_of(position_value: Vector2) -> int:
	for index: int in range(count):
		if _positions[index].is_equal_approx(position_value):
			return index
	return -1


func _shift_left() -> void:
	for index: int in range(CAPACITY - 1):
		_positions[index] = _positions[index + 1]
		_timestamps[index] = _timestamps[index + 1]


func _sync_markers() -> void:
	for index: int in range(_markers.size()):
		var marker: Marker2D = _markers[index]
		marker.visible = visible and index < count
		if index < count:
			marker.global_position = _positions[index]
	_sync_marker_presentations()
	queue_redraw()


func _sync_marker_presentations() -> void:
	for index: int in range(_markers.size()):
		var presentation: Sprite2D = _markers[index].get_child(0) as Sprite2D
		if presentation == null or presentation.texture == null:
			continue
		var display_size: Vector2 = (
			SELECTED_DISPLAY_SIZE if index == armed_index else HISTORY_DISPLAY_SIZE
		)
		var texture_size: Vector2 = presentation.texture.get_size()
		presentation.scale = Vector2(
			display_size.x / maxf(texture_size.x, 1.0),
			display_size.y / maxf(texture_size.y, 1.0)
		)
		presentation.modulate = Color(
			0.35, 0.98, 1.0, 0.58 if index == armed_index else 0.42
		)
		presentation.visible = visible and index < count


func _draw() -> void:
	if not visible:
		return
	for index: int in range(count):
		var local_point: Vector2 = to_local(_positions[index])
		var radius: float = 24.0 if index != armed_index else 30.0
		draw_circle(local_point, radius, CYAN_FILL)
		draw_arc(local_point, radius, 0.0, TAU, 24, CYAN_EDGE, 3.0)
		draw_line(
			local_point + Vector2(-radius * 0.6, 0.0),
			local_point + Vector2(radius * 0.6, 0.0),
			CYAN_EDGE,
			2.0
		)
		draw_line(
			local_point + Vector2(0.0, -radius * 0.6),
			local_point + Vector2(0.0, radius * 0.6),
			CYAN_EDGE,
			2.0
		)
