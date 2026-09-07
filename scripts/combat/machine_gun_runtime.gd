class_name MachineGunRuntime
extends UpgradeRuntime

const SCAN_INTERVAL: float = 0.10
const BASE_DAMAGE: float = 12.0
const BASE_INTERVAL: float = 0.24
const BULLET_SPEED: float = 1350.0
const BULLET_LIFETIME: float = 0.56
const TARGET_MASK: int = (1 << 2) | (1 << 3) | (1 << 6) | (1 << 7)
const SPREAD_DEGREES: Array[float] = [-1.25, 0.0, 1.25]
const MOUNT_TEXTURE: Texture2D = preload(
	"res://assets/player/weapons/machine_gun_mount.png"
)
const MUZZLE_FLASH_TEXTURE: Texture2D = preload(
	"res://assets/player/weapons/machine_gun_muzzle_flash.png"
)

var arsenal: PlayerArsenalRuntime
var target: EnemyActor2D
var target_activation_generation: int = 0
var scan_remaining: float = 0.0
var fire_remaining: float = 0.0
var shot_cycle: int = 0
var shots_fired: int = 0
var mount: WeaponDroneVisual2D
var drones: Array[WeaponDroneVisual2D] = []
var drone_cursor: int = 0


func _init() -> void:
	setup(&"MACHINE_GUN", 5)


func setup_arsenal(
	p_arsenal: PlayerArsenalRuntime,
	drone_orbit: WeaponDroneOrbit2D
) -> void:
	arsenal = p_arsenal
	for _index: int in range(runtime_max_rank):
		drones.append(drone_orbit.create_drone(
			&"MACHINE_GUN",
			MOUNT_TEXTURE,
			Vector2(62.0, 40.0),
			43.0,
			3,
			MUZZLE_FLASH_TEXTURE,
			Vector2(44.0, 30.0)
		))
	mount = drones[0]


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if stopped or paused or current_rank <= 0 or arsenal == null:
		return
	scan_remaining = maxf(scan_remaining - delta, 0.0)
	fire_remaining = maxf(fire_remaining - delta, 0.0)
	if target != null and not arsenal.target_is_current(
		target,
		target_activation_generation
	):
		target = null
	if target == null or scan_remaining <= 0.0:
		target = arsenal.acquire_target()
		target_activation_generation = target.activation_generation if target != null else 0
		scan_remaining = SCAN_INTERVAL
	if target != null and fire_remaining <= 0.0:
		_fire()


func apply_rank(total_rank: int, _context: Dictionary = {}) -> bool:
	var next_rank: int = clampi(total_rank, 0, runtime_max_rank)
	if current_rank == next_rank:
		return false
	current_rank = next_rank
	if current_rank <= 0:
		target = null
	_sync_drones()
	return true


func stop_and_release() -> void:
	super.stop_and_release()
	target = null
	if arsenal != null:
		arsenal.projectile_pool.release_partition(&"player_bullet")
	_set_all_drones_armed(false)


func reset_run() -> void:
	super.reset_run()
	target = null
	target_activation_generation = 0
	scan_remaining = 0.0
	fire_remaining = 0.0
	shot_cycle = 0
	shots_fired = 0
	drone_cursor = 0
	_set_all_drones_armed(false)


func damage_per_shot() -> float:
	return BASE_DAMAGE * (1.0 + 0.15 * float(maxi(current_rank - 1, 0)))


func fire_interval() -> float:
	var base_interval: float = BASE_INTERVAL / (
		1.0 + 0.05 * float(maxi(current_rank - 1, 0))
	)
	return arsenal.scale_cooldown(base_interval) if arsenal != null else base_interval


func snapshot() -> Dictionary:
	var data: Dictionary = super.snapshot()
	data.merge({
		"shots_fired": shots_fired,
		"target_id": target.get_instance_id() if target != null else 0,
		"target_generation": target_activation_generation,
		"cooldown": fire_remaining,
	}, true)
	return data


func _fire() -> void:
	var firing_drone: WeaponDroneVisual2D = _next_drone()
	var origin: Vector2 = (
		firing_drone.muzzle_global_position()
		if firing_drone != null
		else arsenal.robot.global_position + Vector2(
			48.0 * float(arsenal.robot.facing),
			-30.0
		)
	)
	var direction: Vector2 = (target.global_position - origin).normalized()
	var spread: float = deg_to_rad(SPREAD_DEGREES[shot_cycle % SPREAD_DEGREES.size()])
	direction = direction.rotated(spread)
	if firing_drone != null:
		firing_drone.aim_at(direction)
		origin = firing_drone.muzzle_global_position()
	var attack_id: int = arsenal.reserve_attack_id()
	var damage: float = arsenal.scale_damage(
		damage_per_shot(),
		&"machine_gun",
		target,
		attack_id
	)
	var projectile: Projectile2D = arsenal.projectile_pool.acquire(
		origin,
		direction,
		BULLET_SPEED,
		damage,
		arsenal.robot,
		TARGET_MASK,
		&"machine_gun"
	)
	if projectile == null:
		fire_remaining = fire_interval()
		return
	projectile.set_delivery_identity(attack_id, attack_id, BULLET_LIFETIME)
	if firing_drone != null:
		firing_drone.flash()
	shots_fired += 1
	shot_cycle += 1
	fire_remaining = fire_interval()


func _next_drone() -> WeaponDroneVisual2D:
	if current_rank <= 0 or drones.is_empty():
		return null
	var active_total: int = mini(current_rank, drones.size())
	var drone: WeaponDroneVisual2D = drones[drone_cursor % active_total]
	drone_cursor = (drone_cursor + 1) % active_total
	mount = drone
	return drone


func _sync_drones() -> void:
	for index: int in range(drones.size()):
		drones[index].set_armed(index < current_rank)
	if current_rank <= 0 or drone_cursor >= current_rank:
		drone_cursor = 0
	mount = drones[0] if not drones.is_empty() else null


func _set_all_drones_armed(value: bool) -> void:
	for drone: WeaponDroneVisual2D in drones:
		drone.set_armed(value)
