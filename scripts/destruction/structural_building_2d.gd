class_name StructuralBuilding2D
extends Node2D

signal damage_applied(amount: float, event: DamageEvent)
signal cell_destroyed(column: int, row: int, event: DamageEvent)
signal chain_reaction_started(kind: StringName, event: DamageEvent)
signal chain_reaction_step(
	kind: StringName,
	column: int,
	row: int,
	event: DamageEvent
)
signal chain_reaction_completed(kind: StringName)
signal destroyed(event: DamageEvent)

const COLUMNS: int = 3
const ROWS: int = 2
const CELL_COUNT: int = COLUMNS * ROWS
const STREAM_STATE_SCHEMA_VERSION: int = 2
const UPPER_SUPPORT_DAMAGE_RATIO: float = 0.5
const CELL_SCRIPT: Script = preload("res://scripts/destruction/destructible_2d.gd")

@export var intact_texture: Texture2D
@export var display_size: Vector2 = Vector2(600.0, 534.0)
@export var collision_layer_value: int = 0
@export var collision_mask_value: int = 0
@export var hurtbox_layer_value: int = 0
@export var debris_pool_path: NodePath
@export var section_burst_pool_path: NodePath

var last_chain_reaction_kind: StringName = &""
var chain_reaction_count: int = 0
var active_variant: StructuralBuildingVariant
var active_variant_id: StringName = &"legacy"
var encounter_suppressed: bool = false
var _cells: Array[Destructible2D] = []
var _destroyed_cells: int = 0
var _last_destruction_event: DamageEvent
var _chain_reaction_active: bool = false
var _steel_chain_triggered: bool = false
var _triggered_floor_rows: Dictionary[int, bool] = {}
var _stream_generation: int = 0
var _tuning_attack_id: int = 0
var _tuning_damaged_stage_ratio: float = 0.65
var _tuning_support_transfer_ratio: float = UPPER_SUPPORT_DAMAGE_RATIO
var _tuning_chain_delay_multiplier: float = 1.0


func _ready() -> void:
	_build_cells()


func apply_variant(variant: StructuralBuildingVariant) -> bool:
	if variant == null:
		push_error("StructuralBuilding2D cannot apply a null variant")
		return false
	var errors: PackedStringArray = variant.validation_errors()
	if not errors.is_empty():
		push_error(
			"Structural building variant %s is invalid: %s"
			% [variant.variant_id, "; ".join(errors)]
		)
		return false
	active_variant = variant
	active_variant_id = variant.variant_id
	intact_texture = variant.intact_texture
	display_size = variant.display_size
	set_meta(&"building_variant_id", active_variant_id)
	set_meta(&"destruction_signature", variant.destruction_signature)
	for row: int in range(ROWS):
		for column: int in range(COLUMNS):
			_reconfigure_cell(column, row)
	restore_stream_state({})
	return true


func current_variant_id() -> StringName:
	return active_variant_id


func receive_damage(event: DamageEvent) -> bool:
	tuning_snapshot_for_event(event)
	var cell: Destructible2D = cell_at_world_point(event.hit_position)
	if cell == null:
		return false
	return cell.receive_damage(event)


func tuning_snapshot_for_event(event: DamageEvent) -> Dictionary:
	var attack_id: int = 0
	if event != null:
		attack_id = event.root_attack_id if event.root_attack_id != 0 else event.attack_id
	if attack_id != 0 and attack_id != _tuning_attack_id:
		_tuning_attack_id = attack_id
		_tuning_damaged_stage_ratio = float(RuntimeTweakAccess.next_attack_value(
			&"world.facade.damaged_stage_ratio", 0.65
		))
		_tuning_support_transfer_ratio = float(RuntimeTweakAccess.next_attack_value(
			&"world.facade.support_transfer_ratio", UPPER_SUPPORT_DAMAGE_RATIO
		))
		_tuning_chain_delay_multiplier = float(RuntimeTweakAccess.next_attack_value(
			&"world.facade.chain_delay_multiplier", 1.0
		))
	return {
		"damaged_stage_ratio": _tuning_damaged_stage_ratio,
		"support_transfer_ratio": _tuning_support_transfer_ratio,
		"chain_delay_multiplier": _tuning_chain_delay_multiplier,
	}


func rebase_cached_world_state(offset: Vector2) -> void:
	if _last_destruction_event != null:
		_last_destruction_event.hit_position += offset


func cell_at_world_point(world_point: Vector2) -> Destructible2D:
	var local_point: Vector2 = to_local(world_point)
	var cell_size: Vector2 = _cell_size()
	var column: int = clampi(
		floori((local_point.x + display_size.x * 0.5) / cell_size.x),
		0,
		COLUMNS - 1
	)
	var row: int = clampi(
		floori((local_point.y + display_size.y) / cell_size.y),
		0,
		ROWS - 1
	)
	return get_cell(column, row)


func get_cell(column: int, row: int) -> Destructible2D:
	if column < 0 or column >= COLUMNS or row < 0 or row >= ROWS:
		return null
	var index: int = row * COLUMNS + column
	if index >= _cells.size():
		return null
	return _cells[index]


func get_material_profile(column: int, row: int) -> StructuralMaterialProfile:
	var cell: Destructible2D = get_cell(column, row)
	return cell.get_material_profile() if cell != null else null


func destroyed_cell_count() -> int:
	return _destroyed_cells


func is_cell_destroyed(column: int, row: int) -> bool:
	var cell: Destructible2D = get_cell(column, row)
	return cell != null and cell.is_destroyed()


func is_destroyed() -> bool:
	return _destroyed_cells >= CELL_COUNT


func ground_passage_open() -> bool:
	for column: int in range(COLUMNS):
		if not is_cell_destroyed(column, ROWS - 1):
			return false
	return true


func set_encounter_suppressed(suppressed: bool) -> void:
	encounter_suppressed = suppressed
	visible = not suppressed
	_refresh_ground_passage_collision()
	for cell: Destructible2D in _cells:
		var hurtbox: CollisionShape2D = cell.get_node_or_null(
			^"Hurtbox/CollisionShape2D"
		) as CollisionShape2D
		if hurtbox != null:
			hurtbox.set_deferred("disabled", suppressed or cell.is_destroyed())


func is_chain_reaction_active() -> bool:
	return _chain_reaction_active


func capture_stream_state() -> Dictionary:
	var cells: Array[Dictionary] = []
	var pristine: bool = true
	for cell: Destructible2D in _cells:
		var cell_state: Dictionary = cell.capture_stream_state()
		cells.append(cell_state)
		pristine = pristine and bool(cell_state.pristine)
	return {
		"schema_version": STREAM_STATE_SCHEMA_VERSION,
		"variant_id": active_variant_id,
		"columns": COLUMNS,
		"rows": ROWS,
		"cells": cells,
		"chain_count": chain_reaction_count,
		"last_chain": last_chain_reaction_kind,
		"steel_chain": _steel_chain_triggered,
		"floor_rows": _triggered_floor_rows.duplicate(),
		"pristine": pristine,
	}


func restore_stream_state(state: Dictionary) -> void:
	var restored_state: Dictionary = state
	if not state.is_empty():
		var stored_variant_id: StringName = StringName(
			state.get("variant_id", active_variant_id)
		)
		var stored_columns: int = int(state.get("columns", COLUMNS))
		var stored_rows: int = int(state.get("rows", ROWS))
		if (
			stored_variant_id != active_variant_id
			or stored_columns != COLUMNS
			or stored_rows != ROWS
		):
			restored_state = {}
	_stream_generation += 1
	_chain_reaction_active = false
	_tuning_attack_id = 0
	_tuning_damaged_stage_ratio = 0.65
	_tuning_support_transfer_ratio = UPPER_SUPPORT_DAMAGE_RATIO
	_tuning_chain_delay_multiplier = 1.0
	_last_destruction_event = null
	_destroyed_cells = 0
	chain_reaction_count = int(restored_state.get("chain_count", 0))
	last_chain_reaction_kind = StringName(restored_state.get("last_chain", &""))
	_steel_chain_triggered = bool(restored_state.get("steel_chain", false))
	_triggered_floor_rows.clear()
	var floor_rows: Dictionary = restored_state.get("floor_rows", {}) as Dictionary
	for row_value: Variant in floor_rows:
		_triggered_floor_rows[int(row_value)] = bool(floor_rows[row_value])
	var cell_states: Array = restored_state.get("cells", []) as Array
	for cell_index: int in range(_cells.size()):
		var cell_state: Dictionary = {}
		if cell_index < cell_states.size():
			cell_state = cell_states[cell_index] as Dictionary
		_cells[cell_index].restore_stream_state(cell_state)
		_destroyed_cells += 1 if _cells[cell_index].is_destroyed() else 0
	_refresh_ground_passage_collision()


func _build_cells() -> void:
	if intact_texture == null:
		push_error("StructuralBuilding2D requires one authored facade texture")
		return
	for row: int in range(ROWS):
		for column: int in range(COLUMNS):
			var cell: Destructible2D = _create_cell(column, row)
			_cells.append(cell)
			add_child(cell)
	_refresh_ground_passage_collision()


func _create_cell(column: int, row: int) -> Destructible2D:
	var cell: Destructible2D = CELL_SCRIPT.new() as Destructible2D
	var profile: StructuralMaterialProfile = _material_for_cell(column, row)
	_apply_tuned_facade_health(profile)
	cell.name = "Cell_%d_%d" % [column, row]
	cell.position = _cell_center(column, row)
	cell.material_profile = profile
	cell.max_health = profile.max_health
	cell.damaged_stage_ratio = 0.65
	cell.gameplay_chunk_count = profile.chunk_count
	cell.debris_pool_path = NodePath("../" + str(debris_pool_path))
	cell.section_burst_pool_path = NodePath("../" + str(section_burst_pool_path))
	cell.intact_visual_path = ^"IntactVisual"
	cell.damaged_visual_path = ^"DamagedVisual"
	cell.intact_collision_path = ^"IntactBody/CollisionShape2D"
	cell.hurtbox_collision_path = ^"Hurtbox/CollisionShape2D"
	cell.damage_applied.connect(_on_cell_damage_applied)
	cell.destroyed.connect(_on_cell_destroyed.bind(column, row))
	cell.set_meta(&"structural_column", column)
	cell.set_meta(&"structural_row", row)
	cell.set_meta(&"structural_material", profile.material_id)
	cell.set_meta(&"district_id", _active_district_id())
	var intact_visual: Sprite2D = _create_cell_sprite(
		"IntactVisual",
		intact_texture,
		column,
		row,
		profile
	)
	cell.add_child(intact_visual)
	var damage_pattern: BuildingDamagePattern2D = _create_damage_pattern(
		column,
		row,
		profile
	)
	damage_pattern._bind_facade_sprite(intact_visual)
	cell.add_child(damage_pattern)
	cell.add_child(_create_intact_body(row))
	cell.add_child(_create_hurtbox())
	return cell


func _create_cell_sprite(
	sprite_name: String,
	texture: Texture2D,
	column: int,
	row: int,
	_profile: StructuralMaterialProfile
) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.region_enabled = true
	sprite.region_filter_clip_enabled = true
	var source_size: Vector2 = texture.get_size()
	var source_cell_size: Vector2 = Vector2(
		source_size.x / float(COLUMNS),
		source_size.y / float(ROWS)
	)
	sprite.region_rect = Rect2(
		Vector2(source_cell_size.x * float(column), source_cell_size.y * float(row)),
		source_cell_size
	)
	sprite.scale = _cell_size() / source_cell_size
	sprite.modulate = Color.WHITE
	return sprite


func _create_damage_pattern(
	column: int,
	row: int,
	profile: StructuralMaterialProfile
) -> BuildingDamagePattern2D:
	var pattern: BuildingDamagePattern2D = BuildingDamagePattern2D.new()
	pattern.name = "DamagedVisual"
	var source_size: Vector2 = intact_texture.get_size()
	var source_cell_size: Vector2 = Vector2(
		source_size.x / float(COLUMNS),
		source_size.y / float(ROWS)
	)
	pattern.configure(
		intact_texture,
		Rect2(
			Vector2(source_cell_size.x * float(column), source_cell_size.y * float(row)),
			source_cell_size
		),
		_cell_size(),
		1 + row * COLUMNS + column,
		profile.material_id,
		profile.visual_tint,
		_active_district_id(),
		row == ROWS - 1
	)
	return pattern


func _reconfigure_cell(column: int, row: int) -> void:
	var cell: Destructible2D = get_cell(column, row)
	if cell == null:
		return
	var profile: StructuralMaterialProfile = _material_for_cell(column, row)
	_apply_tuned_facade_health(profile)
	cell.position = _cell_center(column, row)
	cell.configure_material_profile(profile)
	cell.set_meta(&"structural_material", profile.material_id)
	cell.set_meta(&"district_id", _active_district_id())
	var intact_visual: Sprite2D = cell.get_node_or_null(^"IntactVisual") as Sprite2D
	_configure_cell_sprite(intact_visual, intact_texture, column, row, profile)
	var pattern: BuildingDamagePattern2D = cell.get_node_or_null(
		^"DamagedVisual"
	) as BuildingDamagePattern2D
	if pattern != null:
		pattern.reconfigure(
			intact_texture,
			_cell_region(intact_texture, column, row),
			_cell_size(),
			_pattern_seed_for_cell(column, row),
			profile.material_id,
			_cell_visual_tint(profile),
			_active_district_id(),
			row == ROWS - 1
		)
		pattern._bind_facade_sprite(intact_visual)
	_configure_intact_collision(cell, row)
	_configure_hurtbox(cell)


func _configure_cell_sprite(
	sprite: Sprite2D,
	texture: Texture2D,
	column: int,
	row: int,
	_profile: StructuralMaterialProfile
) -> void:
	if sprite == null:
		return
	sprite.texture = texture
	sprite.region_rect = _cell_region(texture, column, row)
	sprite.scale = _cell_size() / sprite.region_rect.size
	sprite.modulate = Color.WHITE


func _configure_intact_collision(cell: Destructible2D, row: int) -> void:
	var collision: CollisionShape2D = cell.get_node_or_null(
		^"IntactBody/CollisionShape2D"
	) as CollisionShape2D
	if collision == null:
		return
	var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
	if rectangle == null:
		return
	var cell_size: Vector2 = _cell_size()
	if row == ROWS - 1:
		rectangle.size = Vector2(cell_size.x - 8.0, cell_size.y - 6.0)
		collision.position.y = 0.0
	else:
		rectangle.size = Vector2(cell_size.x - 8.0, minf(118.0, cell_size.y - 6.0))
		collision.position.y = -cell_size.y * 0.5 + rectangle.size.y * 0.5


func _configure_hurtbox(cell: Destructible2D) -> void:
	var collision: CollisionShape2D = cell.get_node_or_null(
		^"Hurtbox/CollisionShape2D"
	) as CollisionShape2D
	if collision == null:
		return
	var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = _cell_size() - Vector2(4.0, 4.0)


func _cell_region(texture: Texture2D, column: int, row: int) -> Rect2:
	var source_size: Vector2 = texture.get_size()
	var source_cell_size: Vector2 = Vector2(
		source_size.x / float(COLUMNS),
		source_size.y / float(ROWS)
	)
	return Rect2(
		Vector2(source_cell_size.x * float(column), source_cell_size.y * float(row)),
		source_cell_size
	)


func _pattern_seed_for_cell(column: int, row: int) -> int:
	return posmod(
		hash("%s:%d:%d" % [active_variant_id, column, row]),
		2_000_000_000
	) + 1


func _cell_visual_tint(profile: StructuralMaterialProfile) -> Color:
	if active_variant == null:
		return profile.visual_tint
	return profile.visual_tint * active_variant.visual_tint


func _active_district_id() -> StringName:
	if active_variant != null:
		return active_variant.district_id
	return StringName(get_meta(&"district_id", &"BUSINESS"))


func _material_for_cell(column: int, row: int) -> StructuralMaterialProfile:
	if active_variant != null:
		return _profile_for_material_id(active_variant.material_id_at(column, row))
	var material_grid: Array[Array] = [
		[concrete_profile(), steel_profile(), concrete_profile()],
		[glass_profile(), concrete_profile(), steel_profile()],
	]
	return material_grid[row][column] as StructuralMaterialProfile


func _profile_for_material_id(material_id: StringName) -> StructuralMaterialProfile:
	if material_id == &"glass":
		return glass_profile()
	if material_id == &"steel":
		return steel_profile()
	return concrete_profile()


func _apply_tuned_facade_health(profile: StructuralMaterialProfile) -> void:
	if profile == null:
		return
	var tuned_multiplier: float = float(RuntimeTweakAccess.run_value(
		&"world.facade.health_multiplier",
		StructuralMaterialProfile.FACADE_HEALTH_MULTIPLIER
	))
	profile.max_health *= (
		tuned_multiplier / StructuralMaterialProfile.FACADE_HEALTH_MULTIPLIER
	)


func concrete_profile() -> StructuralMaterialProfile:
	return StructuralMaterialProfile.concrete()


func glass_profile() -> StructuralMaterialProfile:
	return StructuralMaterialProfile.glass()


func steel_profile() -> StructuralMaterialProfile:
	return StructuralMaterialProfile.steel()


func _create_intact_body(row: int) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "IntactBody"
	body.collision_layer = collision_layer_value
	body.collision_mask = collision_mask_value
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	var cell_size: Vector2 = _cell_size()
	if row == ROWS - 1:
		rectangle.size = Vector2(cell_size.x - 8.0, cell_size.y - 6.0)
	else:
		rectangle.size = Vector2(cell_size.x - 8.0, 118.0)
		collision.position.y = -cell_size.y * 0.5 + 59.0
	collision.shape = rectangle
	body.add_child(collision)
	return body


func _create_hurtbox() -> Area2D:
	var hurtbox: Area2D = Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = hurtbox_layer_value
	hurtbox.collision_mask = 0
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = _cell_size() - Vector2(4.0, 4.0)
	collision.shape = rectangle
	hurtbox.add_child(collision)
	return hurtbox


func _cell_size() -> Vector2:
	return Vector2(
		display_size.x / float(COLUMNS),
		display_size.y / float(ROWS)
	)


func _cell_center(column: int, row: int) -> Vector2:
	var cell_size: Vector2 = _cell_size()
	return Vector2(
		-display_size.x * 0.5 + cell_size.x * (float(column) + 0.5),
		-display_size.y + cell_size.y * (float(row) + 0.5)
	)


func _on_cell_damage_applied(amount: float, event: DamageEvent) -> void:
	damage_applied.emit(amount, event)


func _on_cell_destroyed(event: DamageEvent, column: int, row: int) -> void:
	_destroyed_cells += 1
	_last_destruction_event = event
	if row == ROWS - 1:
		_damage_cell_above(column, row, event)
	_refresh_ground_passage_collision()
	cell_destroyed.emit(column, row, event)
	if is_destroyed():
		destroyed.emit(event)
		return
	call_deferred("_evaluate_chain_reactions")


func _refresh_ground_passage_collision() -> void:
	for row: int in range(ROWS):
		for column: int in range(COLUMNS):
			var cell: Destructible2D = get_cell(column, row)
			if cell == null:
				continue
			var collision: CollisionShape2D = cell.get_node_or_null(
				^"IntactBody/CollisionShape2D"
			) as CollisionShape2D
			if collision != null:
				collision.set_deferred(
					"disabled",
					encounter_suppressed or cell.is_destroyed()
				)


func _damage_cell_above(
	column: int,
	destroyed_row: int,
	source_event: DamageEvent
) -> void:
	var upper_row: int = destroyed_row - 1
	var upper_cell: Destructible2D = get_cell(column, upper_row)
	if upper_cell == null or upper_cell.is_destroyed():
		return
	var source: Node = source_event.source if source_event != null else null
	var attack_id: int = source_event.attack_id if source_event != null else 0
	var support_event: DamageEvent = DamageEvent.new(
		attack_id,
		source,
		upper_cell.max_health * _tuning_support_transfer_ratio,
		&"support_failure",
		upper_cell.global_position + Vector2(0.0, _cell_size().y * 0.34),
		Vector2.UP,
		260.0
	)
	upper_cell.receive_damage(support_event)


func _evaluate_chain_reactions() -> void:
	if _chain_reaction_active or is_destroyed():
		return
	if not _steel_chain_triggered and _all_steel_cells_destroyed():
		_steel_chain_triggered = true
		_start_chain_reaction(&"steel_support_chain", -1)
		return
	for row: int in range(ROWS):
		if _triggered_floor_rows.has(row) or not _is_floor_destroyed(row):
			continue
		_triggered_floor_rows[row] = true
		_start_chain_reaction(&"floor_chain", row)
		return


func _all_steel_cells_destroyed() -> bool:
	var steel_count: int = 0
	for cell: Destructible2D in _cells:
		var profile: StructuralMaterialProfile = cell.get_material_profile()
		if profile == null or profile.material_id != &"steel":
			continue
		steel_count += 1
		if not cell.is_destroyed():
			return false
	return steel_count > 0


func _is_floor_destroyed(row: int) -> bool:
	for column: int in range(COLUMNS):
		if not is_cell_destroyed(column, row):
			return false
	return true


func _start_chain_reaction(kind: StringName, destroyed_floor: int) -> void:
	_chain_reaction_active = true
	last_chain_reaction_kind = kind
	chain_reaction_count += 1
	chain_reaction_started.emit(kind, _last_destruction_event)
	_run_chain_reaction(kind, destroyed_floor, _stream_generation)


func _run_chain_reaction(
	kind: StringName,
	destroyed_floor: int,
	stream_generation: int
) -> void:
	var impulse_per_mass: float = 340.0
	var step_delay: float = 0.11
	if kind == &"steel_support_chain":
		impulse_per_mass = 470.0
		step_delay = 0.075
	var origin_column: int = _last_impact_column()
	var column_order: Array[int] = _column_order(origin_column)
	for row: int in range(ROWS - 1, -1, -1):
		if row == destroyed_floor:
			continue
		for column: int in column_order:
			var cell: Destructible2D = get_cell(column, row)
			if cell == null or cell.is_destroyed():
				continue
			await get_tree().create_timer(
				step_delay * _tuning_chain_delay_multiplier, false
			).timeout
			if stream_generation != _stream_generation:
				return
			var event: DamageEvent = _chain_event(
				cell,
				kind,
				impulse_per_mass,
				origin_column
			)
			if cell.receive_damage(event):
				chain_reaction_step.emit(kind, column, row, event)
	if stream_generation != _stream_generation:
		return
	_chain_reaction_active = false
	chain_reaction_completed.emit(kind)
	call_deferred("_evaluate_chain_reactions")


func _chain_event(
	cell: Destructible2D,
	kind: StringName,
	impulse_per_mass: float,
	origin_column: int
) -> DamageEvent:
	var cell_column: int = int(cell.get_meta(&"structural_column", 0))
	var horizontal_direction: float = signf(float(cell_column - origin_column))
	if is_zero_approx(horizontal_direction):
		horizontal_direction = 1.0 if origin_column <= 1 else -1.0
	var direction: Vector2 = Vector2(horizontal_direction * 0.48, 1.0).normalized()
	return DamageEvent.new(
		0,
		_last_destruction_event.source if _last_destruction_event != null else null,
		cell.max_health + 1.0,
		kind,
		cell.global_position,
		direction,
		impulse_per_mass
	)


func _last_impact_column() -> int:
	if _last_destruction_event == null:
		return 1
	var local_x: float = to_local(_last_destruction_event.hit_position).x
	return clampi(
		floori((local_x + display_size.x * 0.5) / _cell_size().x),
		0,
		COLUMNS - 1
	)


func _column_order(origin_column: int) -> Array[int]:
	var order: Array[int] = [origin_column]
	for distance: int in range(1, COLUMNS):
		var left: int = origin_column - distance
		var right: int = origin_column + distance
		if left >= 0:
			order.append(left)
		if right < COLUMNS:
			order.append(right)
	return order
