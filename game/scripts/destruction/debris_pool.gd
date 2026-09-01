class_name DebrisPool
extends Node2D

signal aerial_impact_accepted(
	body: DebrisBody2D,
	event: DamageEvent,
	target: EnemyActor2D
)
signal ground_impact_accepted(
	body: DebrisBody2D,
	event: DamageEvent,
	target: EnemyActor2D,
	impact_speed: float
)
signal crucible_detonated(body: DebrisBody2D, event: DamageEvent)

@export var debris_scene: PackedScene
@export_range(1, 128, 1) var capacity: int = 48
@export var cull_margin: Vector2 = Vector2(192.0, 160.0)
@export_range(0.02, 1.0, 0.02) var cull_interval: float = 0.10
@export var use_generated_visuals: bool = true

var recycle_count: int = 0
var offscreen_recycle_count: int = 0
var peak_active_count: int = 0
var _free: Array[DebrisBody2D] = []
var _active: Array[DebrisBody2D] = []
var _culling_camera: CameraRig
var _cull_elapsed: float = 0.0


func _ready() -> void:
	set_physics_process(false)
	for index: int in range(capacity):
		var body: DebrisBody2D
		if debris_scene != null:
			body = debris_scene.instantiate() as DebrisBody2D
		else:
			body = DebrisBody2D.new()
		if body == null:
			push_error("debris_scene root must extend DebrisBody2D")
			return
		body.name = "Debris_%03d" % index
		body.recycle_requested.connect(_on_recycle_requested)
		body.aerial_impact_accepted.connect(_on_aerial_impact_accepted)
		body.ground_impact_accepted.connect(_on_ground_impact_accepted)
		body.crucible_detonated.connect(_on_crucible_detonated)
		add_child(body)
		body.deactivate()
		_free.append(body)


func _physics_process(delta: float) -> void:
	if _culling_camera == null or _active.is_empty():
		return
	_cull_elapsed += delta
	if _cull_elapsed < cull_interval:
		return
	_cull_elapsed = 0.0
	cull_offscreen_now()


func acquire(
	spawn_transform: Transform2D,
	linear_impulse: Vector2,
	angular_impulse: float = 0.0,
	body_mass: float = 4.0,
	body_size: Vector2 = Vector2(36.0, 22.0),
	material_id: StringName = &"concrete",
	primary_color: Color = Color("4f4a46"),
	facet_color: Color = Color("786d65")
) -> DebrisBody2D:
	if _free.is_empty():
		var recyclable: DebrisBody2D = _oldest_recyclable_body()
		if recyclable == null:
			return null
		release(recyclable)
		recycle_count += 1
	var body: DebrisBody2D = _free.pop_back()
	_active.append(body)
	peak_active_count = maxi(peak_active_count, _active.size())
	body.activate(
		spawn_transform,
		linear_impulse,
		angular_impulse,
		body_mass,
		body_size,
		material_id,
		primary_color,
		facet_color,
		use_generated_visuals
	)
	return body


func release(body: DebrisBody2D) -> void:
	if body == null or not _active.has(body):
		return
	_active.erase(body)
	body.deactivate()
	_free.append(body)


func release_all() -> void:
	for body: DebrisBody2D in _active.duplicate():
		release(body)
	_cull_elapsed = 0.0


func available_count() -> int:
	return _free.size()


func active_count() -> int:
	return _active.size()


func active_body_at(index: int) -> DebrisBody2D:
	if index < 0 or index >= _active.size():
		return null
	return _active[index]


func active_bodies() -> Array[DebrisBody2D]:
	return _active.duplicate()


func set_culling_camera(camera: CameraRig) -> void:
	_culling_camera = camera
	_cull_elapsed = 0.0
	set_physics_process(_culling_camera != null)


func cull_offscreen_now() -> int:
	if _culling_camera == null or _active.is_empty():
		return 0
	var culling_rect: Rect2 = _culling_camera.visible_world_rect(cull_margin)
	var culled_count: int = 0
	for body: DebrisBody2D in _active.duplicate():
		if body.is_crucible_captured():
			continue
		if culling_rect.has_point(body.global_position):
			continue
		release(body)
		culled_count += 1
	offscreen_recycle_count += culled_count
	return culled_count


func arm_kinetic_debris(_body: DebrisBody2D, _source_event: DamageEvent) -> bool:
	return false


func _oldest_recyclable_body() -> DebrisBody2D:
	for body: DebrisBody2D in _active:
		if not body.is_crucible_captured():
			return body
	return null


func _on_recycle_requested(body: DebrisBody2D) -> void:
	release(body)


func _on_aerial_impact_accepted(
	body: DebrisBody2D,
	event: DamageEvent,
	target: EnemyActor2D
) -> void:
	aerial_impact_accepted.emit(body, event, target)


func _on_ground_impact_accepted(
	body: DebrisBody2D,
	event: DamageEvent,
	target: EnemyActor2D,
	impact_speed: float
) -> void:
	ground_impact_accepted.emit(body, event, target, impact_speed)


func _on_crucible_detonated(body: DebrisBody2D, event: DamageEvent) -> void:
	crucible_detonated.emit(body, event)
