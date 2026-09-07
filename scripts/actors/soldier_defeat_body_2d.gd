class_name SoldierDefeatBody2D
extends RigidBody2D

signal recycle_requested(body: SoldierDefeatBody2D)

const REMAINS_LAYER: int = 1 << 9
const REMAINS_GROUND_LAYER: int = 1 << 10
const SOLDIER_TEXTURE: Texture2D = preload("res://assets/city/enemies/soldier.png")

@export_range(0.1, 5.0, 0.1) var fade_delay: float = 1.35
@export_range(0.1, 3.0, 0.1) var fade_duration: float = 0.75

var visual: Sprite2D
var _active: bool = false
var _age: float = 0.0


func _ready() -> void:
	mass = 7.0
	gravity_scale = 1.0
	linear_damp = 0.65
	angular_damp = 1.1
	can_sleep = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	z_as_relative = false
	z_index = 20
	set_meta(&"enemy_remains", &"soldier")
	_build_visual()
	deactivate()


func activate(
	world_position: Vector2,
	facing: int,
	impact_event: DamageEvent,
	texture: Texture2D = SOLDIER_TEXTURE,
	display_size: Vector2 = Vector2(68.0, 108.0)
) -> void:
	freeze = true
	global_position = world_position
	rotation = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	collision_layer = REMAINS_LAYER
	collision_mask = REMAINS_GROUND_LAYER
	visual.texture = texture
	var texture_size: Vector2 = texture.get_size()
	var fit: float = minf(display_size.x / texture_size.x, display_size.y / texture_size.y)
	visual.scale = Vector2.ONE * fit
	visual.flip_h = facing > 0
	visual.modulate = Color.WHITE
	_age = 0.0
	_active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	reset_physics_interpolation()
	_apply_fatal_impact(facing, impact_event)
	set_deferred(&"freeze", false)


func deactivate() -> void:
	_active = false
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = true
	sleeping = true
	visible = false


func is_active() -> bool:
	return _active


func fade_alpha() -> float:
	return visual.modulate.a if visual != null else 0.0


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_age += delta
	var fade_progress: float = clampf(
		(_age - fade_delay) / maxf(fade_duration, 0.01),
		0.0,
		1.0
	)
	visual.modulate.a = 1.0 - fade_progress
	if fade_progress >= 1.0 or global_position.y > 1200.0:
		recycle_requested.emit(self)


func _build_visual() -> void:
	var collision: CollisionShape2D = CollisionShape2D.new()
	var capsule: CapsuleShape2D = CapsuleShape2D.new()
	capsule.radius = 20.0
	capsule.height = 90.0
	collision.shape = capsule
	add_child(collision)
	visual = Sprite2D.new()
	visual.name = "Visual"
	visual.texture = SOLDIER_TEXTURE
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var texture_size: Vector2 = SOLDIER_TEXTURE.get_size()
	var fit: float = minf(68.0 / texture_size.x, 108.0 / texture_size.y)
	visual.scale = Vector2.ONE * fit
	add_child(visual)


func _apply_fatal_impact(facing: int, impact_event: DamageEvent) -> void:
	var direction: Vector2 = Vector2(float(facing), -0.35).normalized()
	var impulse_per_mass: float = 200.0
	if impact_event != null:
		direction = impact_event.direction
		impulse_per_mass = maxf(impact_event.impulse_per_mass, 200.0)
	if direction.is_zero_approx():
		direction = Vector2(float(facing), -0.35).normalized()
	linear_velocity = direction * impulse_per_mass * 0.72 + Vector2.UP * 105.0
	angular_velocity = direction.x * 7.5
