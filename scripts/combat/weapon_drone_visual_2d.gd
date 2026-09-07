class_name WeaponDroneVisual2D
extends Node2D

const CHASSIS_TEXTURE: Texture2D = preload(
	"res://assets/player/drones/weapon_drone_chassis_east.png"
)
const CHASSIS_DISPLAY_SIZE: Vector2 = Vector2(58.0, 42.0)
const REAR_ORBIT_Z_OFFSET: int = -12

var robot: GiantRobotController
var weapon_key: StringName = &""
var paused: bool = false
var armed: bool = false
var chassis_facing: int = 1
var behind_robot: bool = false
var base_z_index: int = 0
var flash_count: int = 0
var weapon_pivot: Node2D
var weapon_sprite: Sprite2D
var muzzle: Marker2D
var chassis_sprite: Sprite2D
var flash_sprite: Sprite2D
var _flash_age: float = 0.0
var _flash_lifetime: float = 0.09


func _init() -> void:
	chassis_sprite = _make_sprite(CHASSIS_TEXTURE, CHASSIS_DISPLAY_SIZE)
	chassis_sprite.name = "ChassisSprite"
	add_child(chassis_sprite)
	weapon_pivot = Node2D.new()
	weapon_pivot.name = "WeaponPivot"
	add_child(weapon_pivot)
	weapon_sprite = Sprite2D.new()
	weapon_sprite.name = "WeaponSprite"
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	weapon_pivot.add_child(weapon_sprite)
	muzzle = Marker2D.new()
	muzzle.name = "Muzzle"
	weapon_pivot.add_child(muzzle)
	set_process(false)


func setup(
	p_robot: GiantRobotController,
	p_weapon_key: StringName,
	weapon_texture: Texture2D,
	weapon_display_size: Vector2,
	muzzle_distance: float,
	p_z_index: int,
	flash_texture: Texture2D = null,
	flash_size: Vector2 = Vector2(42.0, 32.0)
) -> void:
	robot = p_robot
	weapon_key = p_weapon_key
	base_z_index = p_z_index
	_set_behind_robot(false)
	_configure_sprite(weapon_sprite, weapon_texture, weapon_display_size)
	weapon_sprite.position = Vector2(8.0, 0.0)
	muzzle.position = Vector2(muzzle_distance, 0.0)
	if flash_texture != null:
		flash_sprite = _make_sprite(flash_texture, flash_size)
		flash_sprite.name = "MuzzleFlash"
		flash_sprite.position = Vector2(muzzle_distance + flash_size.x * 0.22, 0.0)
		flash_sprite.visible = false
		flash_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
		weapon_pivot.add_child(flash_sprite)
	set_armed(false)


func set_armed(value: bool) -> void:
	armed = value
	visible = value
	if not value:
		cancel_flash()
	var orbit: WeaponDroneOrbit2D = get_parent() as WeaponDroneOrbit2D
	if orbit != null:
		orbit.refresh_layout()


func aim_at(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	weapon_pivot.rotation = direction.angle()
	var westward: bool = direction.x < 0.0
	weapon_sprite.flip_v = westward
	if flash_sprite != null:
		flash_sprite.flip_v = westward


func update_orbit(
	next_position: Vector2,
	tangent: Vector2,
	p_behind_robot: bool
) -> void:
	position = next_position
	chassis_facing = 1 if tangent.x >= 0.0 else -1
	chassis_sprite.flip_h = chassis_facing < 0
	_set_behind_robot(p_behind_robot)


func _set_behind_robot(value: bool) -> void:
	behind_robot = value
	z_index = base_z_index + (REAR_ORBIT_Z_OFFSET if value else 0)


func muzzle_global_position() -> Vector2:
	return muzzle.global_position


func flash() -> void:
	if not armed or flash_sprite == null:
		return
	_flash_age = 0.0
	flash_sprite.visible = true
	flash_sprite.modulate = Color.WHITE
	flash_count += 1
	set_process(true)


func cancel_flash() -> void:
	_flash_age = 0.0
	if flash_sprite != null:
		flash_sprite.visible = false
	set_process(false)


func _process(delta: float) -> void:
	if paused or flash_sprite == null or not flash_sprite.visible:
		return
	_flash_age += delta
	var progress: float = clampf(_flash_age / _flash_lifetime, 0.0, 1.0)
	flash_sprite.modulate.a = 1.0 - progress
	if _flash_age >= _flash_lifetime:
		cancel_flash()


func _make_sprite(texture: Texture2D, display_size: Vector2) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_configure_sprite(sprite, texture, display_size)
	return sprite


func _configure_sprite(
	sprite: Sprite2D,
	texture: Texture2D,
	display_size: Vector2
) -> void:
	sprite.texture = texture
	var texture_size: Vector2 = texture.get_size()
	var fit_scale: float = minf(
		display_size.x / maxf(texture_size.x, 1.0),
		display_size.y / maxf(texture_size.y, 1.0)
	)
	sprite.scale = Vector2.ONE * fit_scale
