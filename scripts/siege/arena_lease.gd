# gdlint: disable=max-returns
class_name ArenaLease
extends RefCounted

var world_stream: CityWorldStream
var destructibles: StreamedDestructibleRuntime
var definition: BossEncounterDefinition
var chunks: Array[CityStreetChunk] = []
var buildings: Array[StructuralBuilding2D] = []
var cached_building_anchors: PackedVector2Array = PackedVector2Array()
var arena_building: StructuralBuilding2D
var active: bool = false
var generation: int = 0


func setup(
	p_world_stream: CityWorldStream,
	p_destructibles: StreamedDestructibleRuntime
) -> void:
	world_stream = p_world_stream
	destructibles = p_destructibles
	if not world_stream.origin_shift_requested.is_connected(_on_origin_shift_requested):
		world_stream.origin_shift_requested.connect(_on_origin_shift_requested)


func acquire(p_definition: BossEncounterDefinition) -> bool:
	if active or world_stream == null or destructibles == null or p_definition == null:
		return false
	if (
		world_stream.active_chunk_count() != CityWorldStream.CHUNK_CAPACITY
		or destructibles.active_building_count() != CityWorldStream.CHUNK_CAPACITY
	):
		return false
	if not world_stream.begin_resident_lease(self):
		return false
	definition = p_definition
	chunks.assign(world_stream.chunks)
	chunks.sort_custom(func(a: CityStreetChunk, b: CityStreetChunk) -> bool:
		return a.logical_index < b.logical_index
	)
	buildings.clear()
	cached_building_anchors.clear()
	arena_building = null
	for chunk: CityStreetChunk in chunks:
		var building: StructuralBuilding2D = destructibles.building_for_chunk(chunk)
		if building == null:
			_fail_acquire()
			return false
		buildings.append(building)
		cached_building_anchors.append(building.global_position)
		if chunk.logical_index == definition.arena_logical_chunk:
			arena_building = building
	if buildings.size() != CityWorldStream.CHUNK_CAPACITY or arena_building == null:
		_fail_acquire()
		return false
	if definition.summon_uses_arena_landmark and not destructibles.bind_landmark_for_chunk(
		world_stream.chunk_for_logical(definition.arena_logical_chunk),
		definition.arena_landmark_variant_id
	):
		_fail_acquire()
		return false
	if not definition.summon_uses_arena_landmark:
		arena_building.set_encounter_suppressed(true)
	_refresh_cached_anchors()
	active = true
	generation += 1
	return true


func release() -> void:
	if active and world_stream != null:
		world_stream.end_resident_lease(self)
	_clear()


func capture_structural_state() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not active:
		return result
	for index: int in range(buildings.size()):
		var building: StructuralBuilding2D = buildings[index]
		result.append({
			"logical_chunk": chunks[index].logical_index,
			"building_instance_id": building.get_instance_id(),
			"variant_id": building.current_variant_id(),
			"state": building.capture_stream_state(),
		})
	return result


func restore_structural_state(states: Array[Dictionary]) -> bool:
	if not active or states.size() != CityWorldStream.CHUNK_CAPACITY:
		return false
	for record: Dictionary in states:
		var logical_chunk: int = int(
			record.get("logical_chunk", CityStreetChunk.UNUSED_INDEX)
		)
		var variant_id: StringName = StringName(record.get("variant_id", &""))
		var state: Dictionary = record.get("state", {}) as Dictionary
		var resident_chunk: CityStreetChunk = world_stream.chunk_for_logical(logical_chunk)
		var building: StructuralBuilding2D = destructibles.building_for_chunk(resident_chunk)
		if building == null:
			var persisted_state: Dictionary = state.duplicate(true)
			persisted_state.pristine = false
			destructibles.ledger.store(
				destructibles.ledger.make_object_id(logical_chunk, &"building"),
				persisted_state
			)
			continue
		if building.current_variant_id() != variant_id:
			var variant: StructuralBuildingVariant = CityDistrictCatalog.variant_by_id(
				variant_id
			)
			if variant == null or not building.apply_variant(variant):
				return false
			building.set_meta(&"building_variant_id", variant_id)
		building.restore_stream_state(state)
		if building == arena_building and not definition.summon_uses_arena_landmark:
			building.set_encounter_suppressed(true)
	return true


func resident_count() -> int:
	return chunks.size() if active else 0


func landmark_instance_count() -> int:
	if (
		not active
		or arena_building == null
		or definition == null
		or not definition.summon_uses_arena_landmark
	):
		return 0
	var count: int = 0
	for building: StructuralBuilding2D in buildings:
		if building.current_variant_id() == definition.arena_landmark_variant_id:
			count += 1
	return count


func _on_origin_shift_requested(offset: Vector2, _chunk_delta: int) -> void:
	if not active:
		return
	for index: int in range(cached_building_anchors.size()):
		cached_building_anchors[index] += offset


func _refresh_cached_anchors() -> void:
	cached_building_anchors.clear()
	for building: StructuralBuilding2D in buildings:
		cached_building_anchors.append(building.global_position)


func _fail_acquire() -> void:
	world_stream.end_resident_lease(self)
	_clear()


func _clear() -> void:
	if arena_building != null:
		arena_building.set_encounter_suppressed(false)
	active = false
	definition = null
	arena_building = null
	chunks.clear()
	buildings.clear()
	cached_building_anchors.clear()
