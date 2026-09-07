class_name CityStreetChunk
extends Node2D

const CHUNK_WIDTH: float = 1344.0
const WORLD_LAYER: int = 1 << 0
const ROBOT_LAYER: int = 1 << 1
const ENEMY_LAYER: int = 1 << 2
const PROP_LAYER: int = 1 << 7
const DEBRIS_LAYER: int = 1 << 8
const REMAINS_LAYER: int = 1 << 9
const REMAINS_GROUND_LAYER: int = 1 << 10
const LAND_VISUAL_BASELINE_Y: float = 655.0
const ROAD_COLLISION_SURFACE_Y: float = 590.0
const ROAD_DIVIDER_Y: float = 694.0
const LAND_ENEMY_VISUAL_BASELINE_Y: float = ROAD_DIVIDER_Y - 10.0
const GROUND_COLLISION_HEIGHT: float = 70.0
const UNUSED_INDEX: int = -2_147_483_648

var logical_index: int = UNUSED_INDEX
var generation_seed: int = 0
var district_index: int = 0
var district_id: StringName = &"BUSINESS"
var building_variant_id: StringName = &""
var road_surface: Polygon2D
var lower_asphalt: Polygon2D
var lane_marks: Array[Line2D] = []
var ground: StaticBody2D
var remains_ground: StaticBody2D
var culled: bool = false
var _collision_state: Dictionary[int, Vector2i] = {}


func _ready() -> void:
	_build_visuals()
	_build_collision()


func configure(blueprint: CityChunkBlueprint, runtime_x: float) -> void:
	set_culled(false)
	logical_index = blueprint.logical_index
	generation_seed = blueprint.generation_seed
	district_index = blueprint.district_index
	district_id = blueprint.district_id
	building_variant_id = blueprint.building_variant_id
	set_meta(&"district_id", district_id)
	set_meta(&"building_variant_id", building_variant_id)
	position = Vector2(runtime_x, 0.0)
	road_surface.color = blueprint.asphalt_color
	lower_asphalt.color = blueprint.asphalt_color
	var lane_color: Color = blueprint.district_profile.accent_color
	lane_color.a = 0.32
	for mark_index: int in range(lane_marks.size()):
		var segment_x: float = blueprint.lane_phase + float(mark_index) * 336.0
		lane_marks[mark_index].default_color = lane_color
		lane_marks[mark_index].points = PackedVector2Array([
			Vector2(segment_x, ROAD_DIVIDER_Y),
			Vector2(segment_x + 170.0, ROAD_DIVIDER_Y),
		])
	visible = true


func set_culled(should_cull: bool, refresh_descendants: bool = false) -> void:
	if culled == should_cull and not refresh_descendants:
		return
	culled = should_cull
	if culled:
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
		for node: Node in find_children("*", "CollisionObject2D", true, false):
			var collision_object: CollisionObject2D = node as CollisionObject2D
			var instance_id: int = collision_object.get_instance_id()
			if not _collision_state.has(instance_id):
				_collision_state[instance_id] = Vector2i(
					collision_object.collision_layer,
					collision_object.collision_mask
				)
			collision_object.collision_layer = 0
			collision_object.collision_mask = 0
		return
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	for node: Node in find_children("*", "CollisionObject2D", true, false):
		var collision_object: CollisionObject2D = node as CollisionObject2D
		var saved_state: Vector2i = _collision_state.get(
			collision_object.get_instance_id(),
			Vector2i(collision_object.collision_layer, collision_object.collision_mask)
		)
		collision_object.collision_layer = saved_state.x
		collision_object.collision_mask = saved_state.y
	_collision_state.clear()


func contains_runtime_x(runtime_x: float) -> bool:
	return runtime_x >= global_position.x and runtime_x < global_position.x + CHUNK_WIDTH


func _build_visuals() -> void:
	road_surface = Polygon2D.new()
	road_surface.name = "RoadSurface"
	road_surface.z_index = -10
	road_surface.polygon = PackedVector2Array([
		Vector2(0.0, ROAD_COLLISION_SURFACE_Y),
		Vector2(CHUNK_WIDTH + 1.0, ROAD_COLLISION_SURFACE_Y),
		Vector2(CHUNK_WIDTH + 1.0, 1400.0),
		Vector2(0.0, 1400.0),
	])
	add_child(road_surface)
	lower_asphalt = Polygon2D.new()
	lower_asphalt.name = "LowerAsphalt"
	lower_asphalt.z_index = -9
	lower_asphalt.polygon = PackedVector2Array([
		Vector2(0.0, 670.0),
		Vector2(CHUNK_WIDTH + 1.0, 670.0),
		Vector2(CHUNK_WIDTH + 1.0, 1400.0),
		Vector2(0.0, 1400.0),
	])
	add_child(lower_asphalt)
	for mark_index: int in range(4):
		var lane_mark: Line2D = Line2D.new()
		lane_mark.name = "LaneMark%02d" % mark_index
		lane_mark.width = 5.0
		lane_mark.default_color = Color(0.72, 0.67, 0.54, 0.32)
		lane_mark.z_index = -8
		lane_marks.append(lane_mark)
		add_child(lane_mark)
	var curb: Line2D = Line2D.new()
	curb.name = "Curb"
	curb.width = 8.0
	curb.default_color = Color("8f8175")
	curb.points = PackedVector2Array([
		Vector2(0.0, ROAD_COLLISION_SURFACE_Y),
		Vector2(CHUNK_WIDTH + 1.0, ROAD_COLLISION_SURFACE_Y),
	])
	curb.z_index = -9
	add_child(curb)


func _build_collision() -> void:
	ground = _make_ground(
		"Ground",
		WORLD_LAYER,
		ROBOT_LAYER | ENEMY_LAYER | PROP_LAYER | DEBRIS_LAYER,
		ROAD_COLLISION_SURFACE_Y + GROUND_COLLISION_HEIGHT * 0.5
	)
	remains_ground = _make_ground(
		"RemainsGround",
		REMAINS_GROUND_LAYER,
		REMAINS_LAYER,
		LAND_ENEMY_VISUAL_BASELINE_Y + GROUND_COLLISION_HEIGHT * 0.5
	)


func _make_ground(
	body_name: String,
	layer: int,
	mask: int,
	y_position: float
) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = body_name
	body.collision_layer = layer
	body.collision_mask = mask
	body.position = Vector2(CHUNK_WIDTH * 0.5, y_position)
	var collision: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(CHUNK_WIDTH + 4.0, GROUND_COLLISION_HEIGHT)
	collision.shape = rectangle
	body.add_child(collision)
	add_child(body)
	return body
