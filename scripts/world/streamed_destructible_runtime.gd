class_name StreamedDestructibleRuntime
extends Node

signal building_damage_applied(building: StructuralBuilding2D, amount: float, event: DamageEvent)
signal building_cell_destroyed(
	building: StructuralBuilding2D,
	column: int,
	row: int,
	event: DamageEvent
)
signal building_chain_started(
	building: StructuralBuilding2D,
	kind: StringName,
	event: DamageEvent
)
signal building_chain_step(
	building: StructuralBuilding2D,
	kind: StringName,
	column: int,
	row: int,
	event: DamageEvent
)
signal building_chain_completed(building: StructuralBuilding2D, kind: StringName)
signal building_destroyed(building: StructuralBuilding2D, event: DamageEvent)
signal prop_destroyed(
	prop: DestructibleProp2D,
	event: DamageEvent,
	points: int,
	is_car: bool
)

const LAMP_INTACT: Texture2D = preload(
	"res://assets/city/destructibles/streetlamp_intact.png"
)
const LAMP_BROKEN: Texture2D = preload(
	"res://assets/city/destructibles/streetlamp_broken.png"
)
const CAR_INTACT: Texture2D = preload("res://assets/city/destructibles/car_intact.png")
const CAR_WRECK: Texture2D = preload("res://assets/city/destructibles/car_wreck.png")
const BUILDING_SCRIPT: Script = preload(
	"res://scripts/destruction/structural_building_2d.gd"
)
const PROP_SCRIPT: Script = preload("res://scripts/destruction/destructible_prop_2d.gd")
const BUILDING_LAYER: int = 1 << 3
const ROBOT_LAYER: int = 1 << 1
const HURTBOX_LAYER: int = 1 << 6
const PROP_LAYER: int = 1 << 7
const WORLD_LAYER: int = 1 << 0
const BUILDING_SLOTS: int = CityWorldStream.CHUNK_CAPACITY
const PROP_SLOTS: int = CityWorldStream.CHUNK_CAPACITY * 2

var world_stream: CityWorldStream
var ledger: WorldMutationLedger = WorldMutationLedger.new()
var buildings: Array[StructuralBuilding2D] = []
var props: Array[DestructibleProp2D] = []
var post_warm_creation_count: int = 0
var _slot_buildings: Dictionary[int, StructuralBuilding2D] = {}
var _slot_props: Dictionary[int, Array] = {}
var _suppressed_collision_state: Dictionary[int, Vector2i] = {}


func setup(p_world_stream: CityWorldStream) -> void:
	world_stream = p_world_stream


func _ready() -> void:
	assert(world_stream != null, "StreamedDestructibleRuntime requires CityWorldStream")
	building_destroyed.connect(world_stream.report_building_cleared)
	ledger.reset(world_stream.run_seed)
	world_stream.chunk_reassigning.connect(_on_chunk_reassigning)
	world_stream.chunk_reassigned.connect(_on_chunk_reassigned)
	world_stream.run_configured.connect(_on_run_configured)
	world_stream.content_access_changed.connect(refresh_content_access)
	for chunk: CityStreetChunk in world_stream.chunks:
		_build_slot(chunk)
		_configure_slot(
			chunk,
			CityChunkBlueprint.generate(world_stream.run_seed, chunk.logical_index)
		)
	world_stream.refresh_culling()
	refresh_content_access()


func primary_building() -> StructuralBuilding2D:
	var current_chunk: CityStreetChunk = world_stream.chunk_for_logical(
		world_stream.current_logical_chunk
	)
	if current_chunk == null:
		return null
	return _slot_buildings[current_chunk.get_instance_id()]


func primary_car() -> DestructibleProp2D:
	return _primary_prop(&"car")


func primary_streetlamp() -> DestructibleProp2D:
	return _primary_prop(&"streetlamp")


func nearest_intact_building(
	runtime_x: float,
	include_destroyed: bool = false
) -> StructuralBuilding2D:
	var nearest: StructuralBuilding2D
	var nearest_distance: float = INF
	for building: StructuralBuilding2D in buildings:
		if not building.visible or (building.is_destroyed() and not include_destroyed):
			continue
		var distance: float = absf(building.global_position.x - runtime_x)
		if distance < nearest_distance:
			nearest = building
			nearest_distance = distance
	return nearest


func active_building_count() -> int:
	return buildings.size()


func active_prop_count() -> int:
	return props.size()


func building_for_chunk(chunk: CityStreetChunk) -> StructuralBuilding2D:
	if chunk == null:
		return null
	return _slot_buildings.get(chunk.get_instance_id()) as StructuralBuilding2D


func bind_landmark_for_chunk(chunk: CityStreetChunk, variant_id: StringName) -> bool:
	var target: StructuralBuilding2D = building_for_chunk(chunk)
	var landmark: StructuralBuildingVariant = CityDistrictCatalog.variant_by_id(variant_id)
	if target == null or landmark == null:
		return false
	if target.current_variant_id() == variant_id:
		return true
	var displaced: StructuralBuildingVariant = CityDistrictCatalog.variant_by_id(
		target.current_variant_id()
	)
	for candidate: StructuralBuilding2D in buildings:
		if candidate != target and candidate.current_variant_id() == variant_id:
			if displaced == null or not candidate.apply_variant(displaced):
				return false
			candidate.set_meta(&"building_variant_id", displaced.variant_id)
	if not target.apply_variant(landmark):
		return false
	target.set_meta(&"building_variant_id", landmark.variant_id)
	return true


func mutation_count() -> int:
	return ledger.state_count()


func reset_run(run_seed: int) -> void:
	ledger.reset(run_seed)
	for chunk: CityStreetChunk in world_stream.chunks:
		_configure_slot(chunk, CityChunkBlueprint.generate(run_seed, chunk.logical_index))
	refresh_content_access()


func refresh_content_access() -> void:
	for chunk: CityStreetChunk in world_stream.chunks:
		_set_slot_content_enabled(
			chunk,
			world_stream.should_present_chunk_content(chunk.logical_index)
		)


func _build_slot(chunk: CityStreetChunk) -> void:
	var building: StructuralBuilding2D = BUILDING_SCRIPT.new() as StructuralBuilding2D
	var bootstrap_variant: StructuralBuildingVariant = CityDistrictCatalog.variant_for_chunk(
		0,
		0
	)
	building.name = "StreamedBuilding"
	building.z_index = 5
	building.intact_texture = bootstrap_variant.intact_texture
	building.display_size = bootstrap_variant.display_size
	building.collision_layer_value = BUILDING_LAYER
	building.collision_mask_value = ROBOT_LAYER
	building.hurtbox_layer_value = HURTBOX_LAYER
	building.debris_pool_path = ^"../../../BuildingDebrisPool"
	building.section_burst_pool_path = ^"../../../BuildingSectionBurstPool"
	building.damage_applied.connect(_emit_building_damage.bind(building))
	building.cell_destroyed.connect(_emit_building_cell.bind(building))
	building.chain_reaction_started.connect(_emit_chain_started.bind(building))
	building.chain_reaction_step.connect(_emit_chain_step.bind(building))
	building.chain_reaction_completed.connect(_emit_chain_completed.bind(building))
	building.destroyed.connect(_emit_building_destroyed.bind(building))
	chunk.add_child(building)
	buildings.append(building)
	_slot_buildings[chunk.get_instance_id()] = building
	var car: DestructibleProp2D = _create_prop("StreamedCar", {
		"kind": &"car",
		"intact": CAR_INTACT,
		"broken": CAR_WRECK,
		"intact_size": Vector2(165.0, 78.0),
		"broken_size": Vector2(175.0, 76.0),
		"collision": Vector2(150.0, 62.0),
		"broken_collision": Vector2(160.0, 58.0),
		"health": 260.0,
		"wreck_health": 165.0,
		"chunks": 5,
		"mass": 12.0,
		"points": 300,
		"is_car": true,
		"ground_smash_breaks_immediately": true,
		"wreck_next_hit_fully_destroys": true,
	})
	var lamp: DestructibleProp2D = _create_prop("StreamedStreetlamp", {
		"kind": &"streetlamp",
		"intact": LAMP_INTACT,
		"broken": LAMP_BROKEN,
		"intact_size": Vector2(70.0, 235.0),
		"broken_size": Vector2(185.0, 90.0),
		"collision": Vector2(42.0, 220.0),
		"broken_collision": Vector2(170.0, 55.0),
		"health": 160.0,
		"wreck_health": 95.0,
		"chunks": 3,
		"mass": 4.0,
		"points": 150,
		"is_car": false,
		"ground_smash_breaks_immediately": true,
		"wreck_next_hit_fully_destroys": true,
	})
	chunk.add_child(car)
	chunk.add_child(lamp)
	props.append(car)
	props.append(lamp)
	_slot_props[chunk.get_instance_id()] = [car, lamp]


func _create_prop(
	prop_name: String,
	spec: Dictionary
) -> DestructibleProp2D:
	var prop: DestructibleProp2D = PROP_SCRIPT.new() as DestructibleProp2D
	prop.name = prop_name
	prop.z_index = 25
	prop.set_meta(&"street_destructible_kind", StringName(spec.kind))
	var health_multiplier: float = float(RuntimeTweakAccess.run_value(
		&"world.street_prop.health_multiplier", 1.0
	))
	prop.max_health = float(spec.health) * health_multiplier
	prop.wreck_health = float(spec.wreck_health) * health_multiplier
	prop.gameplay_chunk_count = int(spec.chunks)
	prop.debris_pool_path = ^"../../../BuildingDebrisPool"
	prop.rubble_dust_pool_path = ^"../../../BuildingSectionBurstPool"
	prop.mass = float(spec.mass)
	prop.collision_layer = PROP_LAYER
	prop.collision_mask = WORLD_LAYER
	prop.intact_texture = spec.intact as Texture2D
	prop.destroyed_texture = spec.broken as Texture2D
	prop.intact_display_size = spec.intact_size as Vector2
	prop.destroyed_display_size = spec.broken_size as Vector2
	prop.destroyed_collision_size = spec.broken_collision as Vector2
	prop.ground_smash_breaks_immediately = bool(
		spec.get("ground_smash_breaks_immediately", false)
	)
	prop.wreck_next_hit_fully_destroys = bool(
		spec.get("wreck_next_hit_fully_destroys", false)
	)
	prop.destroyed.connect(
		_emit_prop_destroyed.bind(int(spec.points), bool(spec.is_car))
	)
	var visual: Sprite2D = Sprite2D.new()
	visual.name = "Visual"
	prop.add_child(visual)
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = spec.collision as Vector2
	collision.shape = rectangle
	prop.add_child(collision)
	return prop


func _configure_slot(chunk: CityStreetChunk, blueprint: CityChunkBlueprint) -> void:
	var building: StructuralBuilding2D = _slot_buildings[chunk.get_instance_id()]
	var slot_props: Array = _slot_props[chunk.get_instance_id()]
	var car: DestructibleProp2D = slot_props[0] as DestructibleProp2D
	var lamp: DestructibleProp2D = slot_props[1] as DestructibleProp2D
	var building_id: StringName = ledger.make_object_id(blueprint.logical_index, &"building")
	var car_id: StringName = ledger.make_object_id(blueprint.logical_index, &"car")
	var lamp_id: StringName = ledger.make_object_id(blueprint.logical_index, &"streetlamp")
	var building_state: Dictionary = ledger.restore(building_id)
	var configured_variant: StructuralBuildingVariant = blueprint.building_variant
	var stored_variant_id: StringName = StringName(
		building_state.get("variant_id", &"")
	)
	if not stored_variant_id.is_empty():
		var stored_variant: StructuralBuildingVariant = CityDistrictCatalog.variant_by_id(
			stored_variant_id
		)
		if stored_variant != null:
			configured_variant = stored_variant
	var variant_applied: bool = building.apply_variant(configured_variant)
	if not variant_applied:
		push_error(
			"Failed to apply streamed facade %s to logical chunk %d"
			% [configured_variant.variant_id, blueprint.logical_index]
		)
		return
	assert(variant_applied)
	building.set_meta(&"stream_object_id", building_id)
	building.set_meta(&"district_id", blueprint.district_id)
	building.set_meta(&"district_index", blueprint.district_index)
	building.set_meta(&"logical_chunk", blueprint.logical_index)
	building.set_meta(&"building_variant_id", configured_variant.variant_id)
	car.set_meta(&"stream_object_id", car_id)
	lamp.set_meta(&"stream_object_id", lamp_id)
	car.configure_terminal_district(blueprint.district_id)
	lamp.configure_terminal_district(blueprint.district_id)
	building.position = Vector2(blueprint.building_x, CitySlice.LAND_VISUAL_BASELINE_Y)
	building.restore_stream_state(building_state)
	car.visual_ground_offset = CitySlice.LAND_VISUAL_BASELINE_Y - blueprint.car_y
	car.restore_stream_state(
		Vector2(blueprint.car_x, blueprint.car_y),
		ledger.restore(car_id)
	)
	lamp.visual_ground_offset = CitySlice.LAND_VISUAL_BASELINE_Y - blueprint.lamp_y
	lamp.restore_stream_state(
		Vector2(blueprint.lamp_x, blueprint.lamp_y),
		ledger.restore(lamp_id)
	)
	_set_slot_content_enabled(
		chunk,
		world_stream.should_present_chunk_content(blueprint.logical_index)
	)


func _set_slot_content_enabled(chunk: CityStreetChunk, enabled: bool) -> void:
	if chunk == null or not _slot_buildings.has(chunk.get_instance_id()):
		return
	var roots: Array[CanvasItem] = [_slot_buildings[chunk.get_instance_id()]]
	for value: Variant in _slot_props[chunk.get_instance_id()]:
		roots.append(value as CanvasItem)
	for root: CanvasItem in roots:
		root.visible = enabled
		root.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
		var collision_objects: Array[CollisionObject2D] = []
		if root is CollisionObject2D:
			collision_objects.append(root as CollisionObject2D)
		for descendant: Node in root.find_children("*", "CollisionObject2D", true, false):
			collision_objects.append(descendant as CollisionObject2D)
		for collision_object: CollisionObject2D in collision_objects:
			var instance_id: int = collision_object.get_instance_id()
			if enabled:
				if _suppressed_collision_state.has(instance_id):
					var saved: Vector2i = _suppressed_collision_state[instance_id]
					collision_object.collision_layer = saved.x
					collision_object.collision_mask = saved.y
					_suppressed_collision_state.erase(instance_id)
			else:
				if not _suppressed_collision_state.has(instance_id):
					_suppressed_collision_state[instance_id] = Vector2i(
						collision_object.collision_layer,
						collision_object.collision_mask
					)
				collision_object.collision_layer = 0
				collision_object.collision_mask = 0


func _save_slot(chunk: CityStreetChunk) -> void:
	var building: StructuralBuilding2D = _slot_buildings[chunk.get_instance_id()]
	ledger.store(
		StringName(building.get_meta(&"stream_object_id", &"")),
		building.capture_stream_state()
	)
	for value: Variant in _slot_props[chunk.get_instance_id()]:
		var prop: DestructibleProp2D = value as DestructibleProp2D
		ledger.store(
			StringName(prop.get_meta(&"stream_object_id", &"")),
			prop.capture_stream_state()
		)


func _on_chunk_reassigning(
	chunk: CityStreetChunk,
	_previous_index: int,
	_next_index: int
) -> void:
	if _slot_buildings.has(chunk.get_instance_id()):
		_save_slot(chunk)


func _on_chunk_reassigned(
	chunk: CityStreetChunk,
	_previous_index: int,
	_next_index: int,
	blueprint: CityChunkBlueprint
) -> void:
	if _slot_buildings.has(chunk.get_instance_id()):
		_configure_slot(chunk, blueprint)


func _on_run_configured(run_seed_value: int) -> void:
	reset_run(run_seed_value)


func _primary_prop(role: StringName) -> DestructibleProp2D:
	var current_chunk: CityStreetChunk = world_stream.chunk_for_logical(
		world_stream.current_logical_chunk
	)
	if current_chunk == null:
		return null
	var slot_props: Array = _slot_props[current_chunk.get_instance_id()]
	return (
		slot_props[0] as DestructibleProp2D
		if role == &"car"
		else slot_props[1] as DestructibleProp2D
	)


func _emit_building_damage(
	amount: float,
	event: DamageEvent,
	building: StructuralBuilding2D
) -> void:
	building_damage_applied.emit(building, amount, event)


func _emit_building_cell(
	column: int,
	row: int,
	event: DamageEvent,
	building: StructuralBuilding2D
) -> void:
	building_cell_destroyed.emit(building, column, row, event)
	if row == StructuralBuilding2D.ROWS - 1 and building.ground_passage_open():
		world_stream.report_building_cleared(building)


func _emit_chain_started(
	kind: StringName,
	event: DamageEvent,
	building: StructuralBuilding2D
) -> void:
	building_chain_started.emit(building, kind, event)


func _emit_chain_step(
	kind: StringName,
	column: int,
	row: int,
	event: DamageEvent,
	building: StructuralBuilding2D
) -> void:
	building_chain_step.emit(building, kind, column, row, event)


func _emit_chain_completed(
	kind: StringName,
	building: StructuralBuilding2D
) -> void:
	building_chain_completed.emit(building, kind)


func _emit_building_destroyed(
	event: DamageEvent,
	building: StructuralBuilding2D
) -> void:
	building_destroyed.emit(building, event)


func _emit_prop_destroyed(
	prop: DestructibleProp2D,
	event: DamageEvent,
	points: int,
	is_car: bool
) -> void:
	prop_destroyed.emit(prop, event, points, is_car)
