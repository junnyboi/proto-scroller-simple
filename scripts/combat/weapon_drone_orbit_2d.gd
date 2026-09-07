class_name WeaponDroneOrbit2D
extends Node2D

const ORBIT_CENTER: Vector2 = Vector2(0.0, -54.0)
const SINGLE_RING_RADII: Vector2 = Vector2(92.0, 58.0)
const OUTER_RING_RADII: Vector2 = Vector2(170.0, 100.0)
const INNER_RING_RADII: Vector2 = Vector2(112.0, 66.0)
const ANGULAR_SPEED: float = 0.42
const SINGLE_RING_LIMIT: int = 10

var robot: GiantRobotController
var paused: bool = false
var orbit_angle: float = -PI * 0.5
var drones: Array[WeaponDroneVisual2D] = []


func setup(p_robot: GiantRobotController) -> void:
	robot = p_robot
	name = "WeaponDroneOrbit"
	z_index = 6
	_layout_active_drones()


func create_drone(
	weapon_key: StringName,
	weapon_texture: Texture2D,
	weapon_display_size: Vector2,
	muzzle_distance: float,
	p_z_index: int,
	flash_texture: Texture2D = null,
	flash_size: Vector2 = Vector2(42.0, 32.0)
) -> WeaponDroneVisual2D:
	var drone: WeaponDroneVisual2D = WeaponDroneVisual2D.new()
	drone.name = "%sDrone%02d" % [
		String(weapon_key).to_pascal_case(),
		_count_for_weapon(weapon_key) + 1,
	]
	add_child(drone)
	drone.setup(
		robot,
		weapon_key,
		weapon_texture,
		weapon_display_size,
		muzzle_distance,
		p_z_index,
		flash_texture,
		flash_size
	)
	drones.append(drone)
	_layout_active_drones()
	return drone


func set_paused(value: bool) -> void:
	paused = value
	for drone: WeaponDroneVisual2D in drones:
		drone.paused = value


func active_count() -> int:
	var total: int = 0
	for drone: WeaponDroneVisual2D in drones:
		if drone.armed:
			total += 1
	return total


func active_drones_for(weapon_key: StringName) -> Array[WeaponDroneVisual2D]:
	var active: Array[WeaponDroneVisual2D] = []
	for drone: WeaponDroneVisual2D in drones:
		if drone.armed and drone.weapon_key == weapon_key:
			active.append(drone)
	return active


func refresh_layout() -> void:
	_layout_active_drones()


func _process(delta: float) -> void:
	if not paused:
		orbit_angle = fposmod(orbit_angle + delta * ANGULAR_SPEED, TAU)
	_layout_active_drones()


func _layout_active_drones() -> void:
	var active: Array[WeaponDroneVisual2D] = []
	for drone: WeaponDroneVisual2D in drones:
		if drone.armed:
			active.append(drone)
	var total: int = active.size()
	if total <= 0:
		return
	if total <= SINGLE_RING_LIMIT:
		_layout_ring(active, 0, total, total, SINGLE_RING_RADII, 0.0)
		return
	var outer_total: int = ceili(float(total) * 0.5)
	var inner_total: int = total - outer_total
	var outer: Array[WeaponDroneVisual2D] = []
	var inner: Array[WeaponDroneVisual2D] = []
	for index: int in range(total):
		if index % 2 == 0:
			outer.append(active[index])
		else:
			inner.append(active[index])
	_layout_ring(outer, 0, outer.size(), outer_total, OUTER_RING_RADII, 0.0)
	_layout_ring(
		inner,
		0,
		inner.size(),
		inner_total,
		INNER_RING_RADII,
		PI / maxf(float(inner_total), 1.0)
	)


func _layout_ring(
	ring: Array[WeaponDroneVisual2D],
	start: int,
	count: int,
	slot_total: int,
	radii: Vector2,
	phase_offset: float
) -> void:
	var responsive_radii: Vector2 = radii
	var responsive_center: Vector2 = ORBIT_CENTER
	var presentation_scale: float = 1.0
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.y > viewport_size.x:
		responsive_radii.x *= 0.55
		responsive_center.x += 60.0
		presentation_scale = 0.82
	for local_index: int in range(count):
		var slot_index: int = start + local_index
		var angle: float = (
			orbit_angle
			+ phase_offset
			+ TAU * float(slot_index) / maxf(float(slot_total), 1.0)
		)
		var next_position: Vector2 = responsive_center + Vector2(
			cos(angle) * responsive_radii.x,
			sin(angle) * responsive_radii.y
		)
		var tangent: Vector2 = Vector2(
			-sin(angle) * responsive_radii.x,
			cos(angle) * responsive_radii.y
		)
		ring[local_index].scale = Vector2.ONE * presentation_scale
		ring[local_index].update_orbit(
			next_position,
			tangent,
			sin(angle) < 0.0
		)


func _count_for_weapon(weapon_key: StringName) -> int:
	var total: int = 0
	for drone: WeaponDroneVisual2D in drones:
		if drone.weapon_key == weapon_key:
			total += 1
	return total
