class_name WeaponMountVisual2D
extends Node2D

var robot: GiantRobotController
var base_position: Vector2 = Vector2.ZERO
var muzzle_distance: float = 42.0
var paused: bool = false
var armed: bool = false
var flash_count: int = 0
var mount_sprite: Sprite2D
var flash_sprite: Sprite2D
var muzzle: Marker2D
var _flash_age: float = 0.0
var _flash_lifetime: float = 0.09


func setup(
	p_robot: GiantRobotController,
	mount_texture: Texture2D,
	display_size: Vector2,
	p_base_position: Vector2,
	p_muzzle_distance: float,
	p_z_index: int,
	flash_texture: Texture2D = null,
	flash_size: Vector2 = Vector2(42.0, 32.0)
) -> void:
	robot = p_robot
	base_position = p_base_position
	muzzle_distance = p_muzzle_distance
	z_index = p_z_index
	mount_sprite = _make_sprite(mount_texture, display_size)
	mount_sprite.name = "MountSprite"
	add_child(mount_sprite)
	muzzle = Marker2D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector2(muzzle_distance, 0.0)
	add_child(muzzle)
	if flash_texture != null:
		flash_sprite = _make_sprite(flash_texture, flash_size)
		flash_sprite.name = "MuzzleFlash"
		flash_sprite.position = Vector2(muzzle_distance + flash_size.x * 0.22, 0.0)
		flash_sprite.visible = false
		flash_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
		add_child(flash_sprite)
	if not robot.facing_changed.is_connected(_on_facing_changed):
		robot.facing_changed.connect(_on_facing_changed)
	_on_facing_changed(robot.facing)
	set_armed(false)


func set_armed(value: bool) -> void:
	armed = value
	visible = value
	if value and robot != null:
		_on_facing_changed(robot.facing)
	if not value:
		_flash_age = 0.0
		if flash_sprite != null:
			flash_sprite.visible = false
		set_process(false)


func aim_at(direction: Vector2) -> void:
	if direction.is_zero_approx():
		_on_facing_changed(robot.facing if robot != null else 1)
		return
	if not is_zero_approx(direction.x):
		var sign_value: float = 1.0 if direction.x > 0.0 else -1.0
		position = Vector2(absf(base_position.x) * sign_value, base_position.y)
	rotation = direction.angle()


func muzzle_global_position() -> Vector2:
	return muzzle.global_position if muzzle != null else global_position


func flash() -> void:
	if not armed or flash_sprite == null:
		return
	_flash_age = 0.0
	flash_sprite.visible = true
	flash_sprite.modulate = Color.WHITE
	flash_sprite.scale = flash_sprite.scale.abs()
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


func _on_facing_changed(facing: int) -> void:
	var sign_value: float = 1.0 if facing >= 0 else -1.0
	position = Vector2(absf(base_position.x) * sign_value, base_position.y)
	rotation = 0.0 if facing >= 0 else PI


func _make_sprite(texture: Texture2D, display_size: Vector2) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var texture_size: Vector2 = texture.get_size()
	var fit_scale: float = minf(
		display_size.x / maxf(texture_size.x, 1.0),
		display_size.y / maxf(texture_size.y, 1.0)
	)
	sprite.scale = Vector2.ONE * fit_scale
	return sprite
