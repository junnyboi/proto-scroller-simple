class_name BuildingSectionBurstPool
extends Node2D

@export_range(1, 24, 1) var capacity: int = 12

var spawn_count: int = 0
var rubble_dust_spawn_count: int = 0
var recycle_count: int = 0
var peak_active_count: int = 0
var last_material_id: StringName = &""
var last_district_id: StringName = &""
var last_origin: Vector2 = Vector2.ZERO
var _slots: Array[BuildingSectionBurst2D] = []
var _sequence: int = 0


func _ready() -> void:
	if not _slots.is_empty():
		return
	z_as_relative = false
	z_index = BuildingSectionBurst2D.DEBRIS_Z_INDEX
	for index: int in range(capacity):
		var slot: BuildingSectionBurst2D = BuildingSectionBurst2D.new()
		slot.name = "SectionBurst%02d" % index
		slot.setup()
		add_child(slot)
		_slots.append(slot)


func spawn(
	origin: Vector2,
	direction: Vector2,
	impact_speed: float,
	profile: StructuralMaterialProfile,
	district_id: StringName = &"BUSINESS"
) -> BuildingSectionBurst2D:
	if profile == null or _slots.is_empty():
		return null
	var slot: BuildingSectionBurst2D = _acquire_slot()
	_sequence += 1
	last_material_id = profile.material_id
	last_district_id = district_id
	last_origin = origin
	slot.activate(origin, direction, impact_speed, profile, _sequence, district_id)
	spawn_count += 1
	rubble_dust_spawn_count += 1
	peak_active_count = maxi(peak_active_count, active_count())
	return slot


func spawn_rubble_dust(
	origin: Vector2,
	footprint_width: float,
	district_id: StringName
) -> BuildingSectionBurst2D:
	if _slots.is_empty():
		return null
	var slot: BuildingSectionBurst2D = _acquire_slot()
	_sequence += 1
	last_material_id = &"rubble_dust"
	last_district_id = district_id
	last_origin = origin
	slot.activate_rubble_dust(origin, footprint_width, district_id, _sequence)
	rubble_dust_spawn_count += 1
	peak_active_count = maxi(peak_active_count, active_count())
	return slot


func reset_all() -> void:
	for slot: BuildingSectionBurst2D in _slots:
		slot.deactivate()
	spawn_count = 0
	rubble_dust_spawn_count = 0
	recycle_count = 0
	peak_active_count = 0
	last_material_id = &""
	last_district_id = &""
	last_origin = Vector2.ZERO
	_sequence = 0


func slot_count() -> int:
	return _slots.size()


func active_count() -> int:
	var count: int = 0
	for slot: BuildingSectionBurst2D in _slots:
		if slot.is_active():
			count += 1
	return count


func active_slots() -> Array[BuildingSectionBurst2D]:
	var result: Array[BuildingSectionBurst2D] = []
	for slot: BuildingSectionBurst2D in _slots:
		if slot.is_active():
			result.append(slot)
	return result


func _acquire_slot() -> BuildingSectionBurst2D:
	for slot: BuildingSectionBurst2D in _slots:
		if not slot.is_active():
			return slot
	var oldest: BuildingSectionBurst2D = _slots[0]
	for slot: BuildingSectionBurst2D in _slots:
		if slot.activation_sequence < oldest.activation_sequence:
			oldest = slot
	oldest.deactivate()
	recycle_count += 1
	return oldest
