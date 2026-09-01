class_name BossStructuralAdapter
extends Node2D

const MASK_COUNT: int = 1 << StructuralBuilding2D.CELL_COUNT
const CONDUCTOR_CAPACITY: int = StructuralBuilding2D.CELL_COUNT
const WEAK_POINT_TEXTURE: Texture2D = preload("res://art/player/vfx/photon_core_orb.png")

var building: StructuralBuilding2D
var definition: BossEncounterDefinition
var fallback_conductors: Array[Sprite2D] = []
var current_mask: int = 0
var current_binding: Dictionary = {}
var binding_generation: int = 0


func _init() -> void:
	name = "BossStructuralAdapter"
	for index: int in range(CONDUCTOR_CAPACITY):
		var conductor: Sprite2D = Sprite2D.new()
		conductor.name = "FallbackConductor%02d" % index
		conductor.texture = WEAK_POINT_TEXTURE
		conductor.scale = Vector2(0.22, 0.22)
		conductor.modulate = Color(0.82, 1.0, 0.96, 0.92)
		conductor.z_index = 4
		conductor.visible = false
		add_child(conductor)
		fallback_conductors.append(conductor)
	visible = false


func bind(
	p_building: StructuralBuilding2D,
	p_definition: BossEncounterDefinition
) -> bool:
	unbind()
	if p_building == null or p_definition == null:
		return false
	building = p_building
	definition = p_definition
	global_position = building.global_position
	if not building.cell_destroyed.is_connected(_on_cell_destroyed):
		building.cell_destroyed.connect(_on_cell_destroyed)
	binding_generation += 1
	refresh()
	return true


func unbind() -> void:
	if building != null and building.cell_destroyed.is_connected(_on_cell_destroyed):
		building.cell_destroyed.disconnect(_on_cell_destroyed)
	building = null
	definition = null
	current_mask = 0
	current_binding.clear()
	visible = false
	for conductor: Sprite2D in fallback_conductors:
		conductor.visible = false


func refresh() -> Dictionary:
	if building == null or definition == null:
		current_binding = {}
		return current_binding
	current_mask = mask_for_building(building)
	current_binding = binding_for_mask(current_mask, definition.arena_cell_indices)
	_update_conductors()
	return current_binding.duplicate(true)


func all_masks_valid(bound_cells: PackedInt32Array = PackedInt32Array()) -> bool:
	for mask: int in range(MASK_COUNT):
		var binding: Dictionary = binding_for_mask(mask, bound_cells)
		if (
			not bool(binding.lower_passage)
			or not bool(binding.visible_weak_point)
			or not bool(binding.direct_damage_route)
			or not bool(binding.valid_finisher_receiver)
		):
			return false
	return true


func binding_for_mask(
	mask: int,
	bound_cells: PackedInt32Array = PackedInt32Array()
) -> Dictionary:
	var legal_mask: int = mask & (MASK_COUNT - 1)
	var authored_cells: PackedInt32Array = _normalized_bound_cells(bound_cells)
	var lower_target: int = _lower_passage_target(legal_mask, authored_cells)
	var weak_cell: int = _first_intact_bound_cell(legal_mask, authored_cells)
	var fallback: bool = weak_cell < 0
	if fallback:
		weak_cell = _fallback_cell(authored_cells)
	var royal: bool = definition != null and definition.boss_id == &"CHOIR_PRIME"
	return {
		"mask": legal_mask,
		"lower_passage": true,
		"lower_passage_open": _cell_destroyed(legal_mask, lower_target),
		"lower_passage_cell": lower_target,
		"visible_weak_point": true,
		"weak_point_cell": weak_cell,
		"fallback_conductor": fallback,
		"direct_damage_route": true,
		"valid_finisher_receiver": true,
		"palace_lower_route": true if royal else false,
		"palace_upper_crownfall": true if royal else false,
		"direct_core_fallback": true if royal else false,
	}


static func mask_for_building(p_building: StructuralBuilding2D) -> int:
	if p_building == null:
		return 0
	var mask: int = 0
	for row: int in range(StructuralBuilding2D.ROWS):
		for column: int in range(StructuralBuilding2D.COLUMNS):
			var index: int = row * StructuralBuilding2D.COLUMNS + column
			if p_building.is_cell_destroyed(column, row):
				mask |= 1 << index
	return mask


func _normalized_bound_cells(bound_cells: PackedInt32Array) -> PackedInt32Array:
	if bound_cells.is_empty():
		return PackedInt32Array([0, 1, 2, 3, 4, 5])
	var result: PackedInt32Array = PackedInt32Array()
	for cell_index: int in bound_cells:
		if (
			cell_index >= 0
			and cell_index < StructuralBuilding2D.CELL_COUNT
			and not result.has(cell_index)
		):
			result.append(cell_index)
	return result


func _lower_passage_target(mask: int, bound_cells: PackedInt32Array) -> int:
	var lower_start: int = StructuralBuilding2D.COLUMNS
	for cell_index: int in bound_cells:
		if cell_index >= lower_start and _cell_destroyed(mask, cell_index):
			return cell_index
	for preferred: int in [4, 3, 5]:
		if bound_cells.has(preferred):
			return preferred
	return 4


func _first_intact_bound_cell(mask: int, bound_cells: PackedInt32Array) -> int:
	for cell_index: int in bound_cells:
		if not _cell_destroyed(mask, cell_index):
			return cell_index
	return -1


func _fallback_cell(bound_cells: PackedInt32Array) -> int:
	if bound_cells.has(1):
		return 1
	return bound_cells[0] if not bound_cells.is_empty() else 1


func _cell_destroyed(mask: int, cell_index: int) -> bool:
	return mask & (1 << cell_index) != 0


func _update_conductors() -> void:
	for conductor: Sprite2D in fallback_conductors:
		conductor.visible = false
	visible = bool(current_binding.get("fallback_conductor", false))
	if not visible or building == null:
		return
	var cell_index: int = int(current_binding.weak_point_cell)
	var column: int = cell_index % StructuralBuilding2D.COLUMNS
	var row: int = cell_index / StructuralBuilding2D.COLUMNS
	var cell_size: Vector2 = building.display_size / Vector2(
		float(StructuralBuilding2D.COLUMNS),
		float(StructuralBuilding2D.ROWS)
	)
	var conductor: Sprite2D = fallback_conductors[cell_index]
	conductor.position = Vector2(
		-building.display_size.x * 0.5 + cell_size.x * (float(column) + 0.5),
		-building.display_size.y + cell_size.y * (float(row) + 0.5)
	)
	conductor.visible = true


func _on_cell_destroyed(_column: int, _row: int, _event: DamageEvent) -> void:
	refresh()
