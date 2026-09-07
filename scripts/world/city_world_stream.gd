# gdlint: disable=max-public-methods
class_name CityWorldStream
extends Node2D

signal origin_shift_requested(offset: Vector2, chunk_delta: int)
signal window_changed(current_chunk: int)
signal chunk_reassigning(chunk: CityStreetChunk, previous_index: int, next_index: int)
signal chunk_reassigned(
	chunk: CityStreetChunk,
	previous_index: int,
	next_index: int,
	blueprint: CityChunkBlueprint
)
signal run_configured(run_seed: int)
signal district_changed(
	previous_district_id: StringName,
	district_id: StringName,
	logical_chunk: int
)
signal district_clear_progress(
	district_id: StringName,
	cleared_buildings: int,
	required_buildings: int
)
signal district_boss_ready(district_id: StringName, district_index: int)
signal district_handoff_started(district_id: StringName, next_district_id: StringName)
signal district_handoff_completed(district_id: StringName, next_district_id: StringName)
signal content_access_changed
signal district_exit_unlocked(district_id: StringName, next_district_id: StringName)
signal rear_frontier_changed(logical_x: float, runtime_x: float)
signal rear_barrier_contact

const CHUNK_WIDTH: float = CityStreetChunk.CHUNK_WIDTH
const CHUNK_CAPACITY: int = 6
const BEHIND_CHUNKS: int = 2
const AHEAD_CHUNKS: int = 3
const PROGRESSION_CHUNKS_PER_TIER: int = CityDistrictCatalog.CHUNKS_PER_DISTRICT
const MAX_PROGRESSION_TIER: int = 4
const LEFT_RETENTION_DISTANCE: float = 1000.0
const DISTRICT_BUILDINGS_REQUIRED: int = (
	CityDistrictCatalog.FACADE_ENCOUNTERS_PER_DISTRICT
)
const BARRIER_WIDTH: float = 48.0
const BARRIER_HEIGHT: float = 1200.0
const ROBOT_BARRIER_CLEARANCE: float = 72.0
const FRONTIER_CULL_STEP: float = 64.0
const CHUNK_CONTENT_OVERHANG: float = 384.0
const REAR_CONTACT_TOLERANCE: float = 12.0
const REAR_BARRIER_LAYER: int = 1 << 11
const BUILDING_LAYER: int = 1 << 3
const BOSS_TRAVERSAL_BYPASS_LAYERS: int = REAR_BARRIER_LAYER | BUILDING_LAYER
const CHUNK_SCRIPT: Script = preload("res://scripts/world/city_street_chunk.gd")

var robot: GiantRobotController
var run_seed: int = 0
var current_logical_chunk: int = 0
var current_district_id: StringName = &"BUSINESS"
var minimum_visited_chunk: int = 0
var maximum_visited_chunk: int = 0
var transition_count: int = 0
var post_warm_creation_count: int = 0
var floating_origin: FloatingOriginRuntime = FloatingOriginRuntime.new()
var chunks: Array[CityStreetChunk] = []
var landmark_root: Node2D
var furthest_progress_logical_x: float = 0.0
var rear_frontier_logical_x: float = 0.0
var unlocked_district_index: int = 0
var rear_barrier: StaticBody2D
var district_exit_barrier: StaticBody2D
var _rear_barrier_collision: CollisionShape2D
var _district_exit_collision: CollisionShape2D
var _cleared_encounters_by_district: Dictionary[StringName, Dictionary] = {}
var _last_frontier_signal_logical_x: float = 0.0
var _resident_lease_owner: Object
var _rear_barrier_contact_active: bool = false
var _boss_traversal_bypass_active: bool = false
var _robot_mask_before_boss_bypass: int = 0
var _pending_boss_district_index: int = -1
var _corridor_district_index: int = -1
var _campaign_handoff_complete: bool = false


func setup(
	p_robot: GiantRobotController,
	p_run_seed: int = 0,
	p_initial_origin_chunk: int = 0
) -> void:
	robot = p_robot
	run_seed = p_run_seed
	floating_origin.origin_chunk = maxi(p_initial_origin_chunk, 0)


func _ready() -> void:
	_build_progression_barriers()
	for slot_index: int in range(CHUNK_CAPACITY):
		var chunk: CityStreetChunk = CHUNK_SCRIPT.new() as CityStreetChunk
		chunk.name = "StreetChunk%02d" % slot_index
		add_child(chunk)
		chunks.append(chunk)
	if robot != null:
		current_logical_chunk = logical_index_for_runtime_x(robot.global_position.x)
		current_district_id = CityDistrictCatalog.district_for_chunk(
			current_logical_chunk
		).district_id
		minimum_visited_chunk = current_logical_chunk
		maximum_visited_chunk = current_logical_chunk
		furthest_progress_logical_x = logical_distance_x(robot.global_position.x)
		rear_frontier_logical_x = (
			furthest_progress_logical_x - LEFT_RETENTION_DISTANCE
		)
		_last_frontier_signal_logical_x = rear_frontier_logical_x
		unlocked_district_index = CityDistrictCatalog.district_index_for_chunk(
			current_logical_chunk
		)
	_refresh_window()
	_update_progression_barriers()


func _physics_process(_delta: float) -> void:
	advance_stream()


func advance_stream() -> void:
	if robot == null or chunks.is_empty():
		return
	_update_rear_frontier(logical_distance_x(robot.global_position.x))
	var chunk_delta: int = floating_origin.required_chunk_shift(
		robot.global_position.x,
		CHUNK_WIDTH
	)
	if chunk_delta != 0:
		floating_origin.commit(chunk_delta)
		origin_shift_requested.emit(Vector2(-float(chunk_delta) * CHUNK_WIDTH, 0.0), chunk_delta)
	_update_progression_barriers()
	_enforce_rear_barrier()
	var next_chunk: int = logical_index_for_runtime_x(robot.global_position.x)
	if next_chunk == current_logical_chunk:
		if chunk_delta != 0:
			_refresh_window()
		else:
			_refresh_culling()
		return
	transition_count += absi(next_chunk - current_logical_chunk)
	var previous_district_id: StringName = current_district_id
	current_logical_chunk = next_chunk
	current_district_id = CityDistrictCatalog.district_for_chunk(
		current_logical_chunk
	).district_id
	minimum_visited_chunk = mini(minimum_visited_chunk, current_logical_chunk)
	maximum_visited_chunk = maxi(maximum_visited_chunk, current_logical_chunk)
	_refresh_window()
	if current_district_id != previous_district_id:
		district_changed.emit(
			previous_district_id,
			current_district_id,
			current_logical_chunk
		)
	window_changed.emit(current_logical_chunk)


func configure_run(p_run_seed: int) -> void:
	run_seed = p_run_seed
	run_configured.emit(run_seed)
	_refresh_window()


func set_landmark_root(p_landmark_root: Node2D) -> void:
	landmark_root = p_landmark_root
	_update_landmark_root()


func active_chunk_count() -> int:
	return chunks.size()


func begin_resident_lease(owner: Object) -> bool:
	if owner == null or (_resident_lease_owner != null and _resident_lease_owner != owner):
		return false
	_resident_lease_owner = owner
	_set_boss_traversal_bypass(true)
	_update_progression_barriers()
	return true


func end_resident_lease(owner: Object) -> void:
	if _resident_lease_owner == owner:
		_resident_lease_owner = null
		_set_boss_traversal_bypass(false)
		_refresh_window()
		_update_progression_barriers()


func resident_lease_active() -> bool:
	return _resident_lease_owner != null


func logical_index_for_runtime_x(runtime_x: float) -> int:
	return floating_origin.origin_chunk + floori(runtime_x / CHUNK_WIDTH)


func runtime_x_for_logical_index(logical_index: int) -> float:
	return float(logical_index - floating_origin.origin_chunk) * CHUNK_WIDTH


func chunk_for_logical(logical_index: int) -> CityStreetChunk:
	for chunk: CityStreetChunk in chunks:
		if chunk.logical_index == logical_index:
			return chunk
	return null


func resident_bounds() -> Vector2:
	return Vector2(
		(
			runtime_x_for_logical_index(current_logical_chunk - BEHIND_CHUNKS)
			if resident_lease_active()
			else maxf(
				runtime_x_for_logical_index(current_logical_chunk - BEHIND_CHUNKS),
				rear_frontier_runtime_x()
			)
		),
		runtime_x_for_logical_index(current_logical_chunk + AHEAD_CHUNKS + 1)
	)


func logical_distance_x(runtime_x: float) -> float:
	return float(floating_origin.origin_chunk) * CHUNK_WIDTH + runtime_x


func progression_distance_chunks() -> int:
	return maxi(absi(current_logical_chunk), maximum_visited_chunk)


func progression_tier() -> int:
	return mini(
		floori(
			float(progression_distance_chunks())
			/ float(PROGRESSION_CHUNKS_PER_TIER)
		),
		MAX_PROGRESSION_TIER
	)


func current_district() -> CityDistrictProfile:
	return CityDistrictCatalog.district_for_chunk(current_logical_chunk)


func rear_frontier_runtime_x() -> float:
	return rear_frontier_logical_x - float(floating_origin.origin_chunk) * CHUNK_WIDTH


func district_clear_count(district_id: StringName = current_district_id) -> int:
	var cleared: Dictionary = _cleared_encounters_by_district.get(district_id, {})
	return cleared.size()


func district_exit_is_unlocked(district_index: int = -1) -> bool:
	var selected_index: int = (
		CityDistrictCatalog.district_index_for_chunk(current_logical_chunk)
		if district_index < 0
		else district_index
	)
	return (
		selected_index < unlocked_district_index
		or (
			selected_index >= CityDistrictCatalog.DISTRICT_COUNT - 1
			and _campaign_handoff_complete
		)
	)


func district_boss_is_ready(district_index: int) -> bool:
	return district_index == _pending_boss_district_index


func begin_post_boss_corridor(district_index: int) -> bool:
	if (
		district_index != unlocked_district_index
		or district_index != _pending_boss_district_index
		or _corridor_district_index >= 0
	):
		return false
	_corridor_district_index = district_index
	var districts: Array[CityDistrictProfile] = CityDistrictCatalog.districts()
	var current: CityDistrictProfile = districts[district_index]
	var next_id: StringName = (
		districts[district_index + 1].district_id
		if district_index + 1 < districts.size()
		else &""
	)
	district_handoff_started.emit(current.district_id, next_id)
	_update_progression_barriers()
	return true


func post_boss_corridor_is_clear(district_index: int) -> bool:
	return district_index == _corridor_district_index


func complete_district_handoff(district_index: int) -> bool:
	var final_district: bool = district_index >= CityDistrictCatalog.DISTRICT_COUNT - 1
	if (
		district_index != _corridor_district_index
		and not (
			final_district
			and district_index == _pending_boss_district_index
		)
	):
		return false
	var districts: Array[CityDistrictProfile] = CityDistrictCatalog.districts()
	if district_index < 0 or district_index >= districts.size():
		return false
	var previous: CityDistrictProfile = districts[district_index]
	var next_id: StringName = &""
	if district_index < districts.size() - 1:
		unlocked_district_index = district_index + 1
		next_id = districts[unlocked_district_index].district_id
		district_exit_unlocked.emit(previous.district_id, next_id)
	else:
		_campaign_handoff_complete = true
	_pending_boss_district_index = -1
	_corridor_district_index = -1
	district_handoff_completed.emit(previous.district_id, next_id)
	content_access_changed.emit()
	_queue_recorded_boss_if_ready(districts)
	_update_progression_barriers()
	return true


func should_present_chunk_content(logical_index: int) -> bool:
	return CityDistrictCatalog.chunk_hosts_facade(logical_index)


func report_building_cleared(
	building: StructuralBuilding2D,
	_event: DamageEvent = null
) -> bool:
	if building == null:
		return false
	var district_id: StringName = StringName(building.get_meta(&"district_id", &""))
	var district_index: int = int(building.get_meta(&"district_index", -1))
	var variant_id: StringName = StringName(
		building.get_meta(&"building_variant_id", &"")
	)
	var logical_chunk: int = int(building.get_meta(&"logical_chunk", -1))
	if district_id.is_empty() or variant_id.is_empty() or logical_chunk < 0:
		return false
	var districts: Array[CityDistrictProfile] = CityDistrictCatalog.districts()
	if district_index < 0 or district_index >= districts.size():
		return false
	var district: CityDistrictProfile = districts[district_index]
	if (
		district.district_id != district_id
		or district.variant_by_id(variant_id) == null
		or CityDistrictCatalog.district_index_for_chunk(logical_chunk) != district_index
		or not CityDistrictCatalog.chunk_hosts_facade(logical_chunk)
	):
		return false
	var cleared: Dictionary = _cleared_encounters_by_district.get(district_id, {})
	if cleared.has(logical_chunk):
		return false
	cleared[logical_chunk] = variant_id
	_cleared_encounters_by_district[district_id] = cleared
	district_clear_progress.emit(
		district_id,
		cleared.size(),
		DISTRICT_BUILDINGS_REQUIRED
	)
	if (
		cleared.size() >= DISTRICT_BUILDINGS_REQUIRED
		and district_index == unlocked_district_index
		and _pending_boss_district_index < 0
	):
		_pending_boss_district_index = district_index
		district_boss_ready.emit(district_id, district_index)
	_update_progression_barriers()
	return true


func reset_stream(p_run_seed: int = 0, preserve_spatial_state: bool = false) -> void:
	run_seed = p_run_seed
	var previous_district_id: StringName = current_district_id
	floating_origin.reset()
	if preserve_spatial_state and robot != null:
		floating_origin.origin_chunk = -floori(robot.global_position.x / CHUNK_WIDTH)
	current_logical_chunk = logical_index_for_runtime_x(
		robot.global_position.x if robot != null else 0.0
	)
	current_district_id = CityDistrictCatalog.district_for_chunk(
		current_logical_chunk
	).district_id
	minimum_visited_chunk = current_logical_chunk
	maximum_visited_chunk = current_logical_chunk
	furthest_progress_logical_x = logical_distance_x(
		robot.global_position.x if robot != null else 0.0
	)
	rear_frontier_logical_x = furthest_progress_logical_x - LEFT_RETENTION_DISTANCE
	unlocked_district_index = CityDistrictCatalog.district_index_for_chunk(
		current_logical_chunk
	)
	_cleared_encounters_by_district.clear()
	_pending_boss_district_index = -1
	_corridor_district_index = -1
	_campaign_handoff_complete = false
	_last_frontier_signal_logical_x = rear_frontier_logical_x
	_rear_barrier_contact_active = false
	transition_count = 0
	run_configured.emit(run_seed)
	_refresh_window()
	_update_progression_barriers()
	if current_district_id != previous_district_id:
		district_changed.emit(
			previous_district_id,
			current_district_id,
			current_logical_chunk
		)


func _refresh_window() -> void:
	var desired: Array[int] = []
	for logical_index: int in range(
		current_logical_chunk - BEHIND_CHUNKS,
		current_logical_chunk + AHEAD_CHUNKS + 1
	):
		desired.append(logical_index)
	var reusable: Array[CityStreetChunk] = []
	for chunk: CityStreetChunk in chunks:
		if not desired.has(chunk.logical_index):
			reusable.append(chunk)
	for logical_index: int in desired:
		var chunk: CityStreetChunk = chunk_for_logical(logical_index)
		if chunk == null:
			if reusable.is_empty():
				post_warm_creation_count += 1
				continue
			chunk = reusable.pop_back()
		var blueprint: CityChunkBlueprint = CityChunkBlueprint.generate(
			run_seed,
			logical_index
		)
		var previous_index: int = chunk.logical_index
		if previous_index != logical_index:
			chunk_reassigning.emit(chunk, previous_index, logical_index)
		chunk.configure(blueprint, runtime_x_for_logical_index(logical_index))
		if previous_index != logical_index:
			chunk_reassigned.emit(chunk, previous_index, logical_index, blueprint)
	_update_landmark_root()
	_refresh_culling()


func refresh_culling() -> void:
	_refresh_culling(true)


func _refresh_culling(refresh_descendants: bool = false) -> void:
	for chunk: CityStreetChunk in chunks:
		if resident_lease_active():
			chunk.set_culled(false, refresh_descendants)
			continue
		var chunk_right_logical_x: float = (
			float(chunk.logical_index + 1) * CHUNK_WIDTH
			+ CHUNK_CONTENT_OVERHANG
		)
		chunk.set_culled(
			chunk_right_logical_x <= rear_frontier_logical_x,
			refresh_descendants
		)


func _update_rear_frontier(robot_logical_x: float) -> void:
	if resident_lease_active():
		return
	if robot_logical_x <= furthest_progress_logical_x:
		return
	furthest_progress_logical_x = robot_logical_x
	rear_frontier_logical_x = furthest_progress_logical_x - LEFT_RETENTION_DISTANCE
	_refresh_culling()
	if (
		rear_frontier_logical_x - _last_frontier_signal_logical_x
		>= FRONTIER_CULL_STEP
	):
		_last_frontier_signal_logical_x = rear_frontier_logical_x
		rear_frontier_changed.emit(
			rear_frontier_logical_x,
			rear_frontier_runtime_x()
		)


func _build_progression_barriers() -> void:
	rear_barrier = _make_progression_barrier(
		"RearFrontierBarrier",
		REAR_BARRIER_LAYER
	)
	district_exit_barrier = _make_progression_barrier(
		"DistrictExitBarrier",
		CityStreetChunk.WORLD_LAYER
	)


func _make_progression_barrier(
	barrier_name: String,
	barrier_layer: int
) -> StaticBody2D:
	var barrier: StaticBody2D = StaticBody2D.new()
	barrier.name = barrier_name
	var is_rear_barrier: bool = barrier_name == "RearFrontierBarrier"
	barrier.collision_layer = barrier_layer if is_rear_barrier else 0
	barrier.collision_mask = CityStreetChunk.ROBOT_LAYER if is_rear_barrier else 0
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "Collision"
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(BARRIER_WIDTH, BARRIER_HEIGHT)
	collision.shape = shape
	collision.position.y = BARRIER_HEIGHT * 0.5 - 200.0
	barrier.add_child(collision)
	add_child(barrier)
	if is_rear_barrier:
		_rear_barrier_collision = collision
	else:
		_district_exit_collision = collision
	return barrier


func _update_progression_barriers() -> void:
	if rear_barrier == null or district_exit_barrier == null:
		return
	rear_barrier.position.x = rear_frontier_runtime_x()
	var active_district: CityDistrictProfile = CityDistrictCatalog.districts()[
		unlocked_district_index
	]
	var cleared_buildings: int = district_clear_count(active_district.district_id)
	var gate_offset: int = (
		CityDistrictCatalog.CHUNKS_PER_DISTRICT
		if (
			_pending_boss_district_index == unlocked_district_index
			or _corridor_district_index == unlocked_district_index
		)
		else mini(cleared_buildings + 1, DISTRICT_BUILDINGS_REQUIRED)
	)
	var gate_logical_x: float = (
		float(
			unlocked_district_index * CityDistrictCatalog.CHUNKS_PER_DISTRICT
			+ gate_offset
		)
		* CHUNK_WIDTH
	)
	district_exit_barrier.position.x = (
		gate_logical_x - float(floating_origin.origin_chunk) * CHUNK_WIDTH
	)
	_rear_barrier_collision.disabled = resident_lease_active()
	_district_exit_collision.disabled = true


func _enforce_rear_barrier() -> void:
	if robot == null or resident_lease_active():
		_rear_barrier_contact_active = false
		return
	var minimum_runtime_x: float = rear_frontier_runtime_x() + ROBOT_BARRIER_CLEARANCE
	var clamped: bool = false
	if robot.global_position.x < minimum_runtime_x:
		robot.global_position.x = minimum_runtime_x
		robot.velocity.x = maxf(robot.velocity.x, 0.0)
		clamped = true
	var pressing_left: bool = (
		Input.get_axis(&"move_left", &"move_right") < -0.05
		or robot.virtual_move_axis < -0.05
		or robot.velocity.x < -1.0
	)
	var touching: bool = (
		clamped
		or (
			robot.global_position.x <= minimum_runtime_x + REAR_CONTACT_TOLERANCE
			and pressing_left
		)
	)
	if touching and not _rear_barrier_contact_active:
		rear_barrier_contact.emit()
	_rear_barrier_contact_active = touching


func _set_boss_traversal_bypass(active: bool) -> void:
	if robot == null or active == _boss_traversal_bypass_active:
		return
	_boss_traversal_bypass_active = active
	if active:
		_robot_mask_before_boss_bypass = robot.collision_mask
		robot.collision_mask &= ~BOSS_TRAVERSAL_BYPASS_LAYERS
	else:
		robot.collision_mask = _robot_mask_before_boss_bypass
		_robot_mask_before_boss_bypass = 0


func _queue_recorded_boss_if_ready(
	districts: Array[CityDistrictProfile]
) -> void:
	if (
		_pending_boss_district_index >= 0
		or unlocked_district_index < 0
		or unlocked_district_index >= districts.size()
	):
		return
	var district: CityDistrictProfile = districts[unlocked_district_index]
	if district_clear_count(district.district_id) < DISTRICT_BUILDINGS_REQUIRED:
		return
	_pending_boss_district_index = unlocked_district_index


func _update_landmark_root() -> void:
	if landmark_root == null:
		return
	var landmarks_resident: bool = (
		absi(current_logical_chunk) <= AHEAD_CHUNKS
		or absi(current_logical_chunk - 1) <= AHEAD_CHUNKS
	)
	landmark_root.visible = landmarks_resident
	landmark_root.process_mode = (
		Node.PROCESS_MODE_INHERIT if landmarks_resident else Node.PROCESS_MODE_DISABLED
	)
	landmark_root.position = (
		Vector2(-float(floating_origin.origin_chunk) * CHUNK_WIDTH, 0.0)
		if landmarks_resident
		else Vector2(-8192.0, -8192.0)
	)
