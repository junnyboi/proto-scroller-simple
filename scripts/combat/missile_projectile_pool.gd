class_name MissileProjectilePool
extends Node2D

const CAPACITY: int = 4

var missiles: Array[MissileProjectile2D] = []
var denial_count: int = 0
var peak_active_count: int = 0


func _ready() -> void:
	name = "MissileProjectilePool"
	for index: int in range(CAPACITY):
		var missile: MissileProjectile2D = MissileProjectile2D.new()
		missile.name = "PlayerMissile%02d" % index
		missile.explosion_requested.connect(_on_explosion_requested)
		add_child(missile)
		missiles.append(missile)


func acquire(
	origin: Vector2,
	target: EnemyActor2D,
	generation: int,
	fallback_point: Vector2,
	attack_id: int,
	root_attack_id: int
) -> MissileProjectile2D:
	for missile: MissileProjectile2D in missiles:
		if not missile.active:
			missile.activate(
				origin,
				target,
				generation,
				fallback_point,
				attack_id,
				root_attack_id
			)
			peak_active_count = maxi(peak_active_count, active_count())
			return missile
	denial_count += 1
	return null


func release(missile: MissileProjectile2D) -> void:
	if missile != null and missile.active:
		missile.deactivate()


func release_all() -> void:
	for missile: MissileProjectile2D in missiles:
		release(missile)


func set_paused(value: bool) -> void:
	for missile: MissileProjectile2D in missiles:
		missile.paused = value


func active_count() -> int:
	var total: int = 0
	for missile: MissileProjectile2D in missiles:
		if missile.active:
			total += 1
	return total


func _on_explosion_requested(
	missile: MissileProjectile2D,
	world_position: Vector2,
	attack_id: int,
	root_attack_id: int
) -> void:
	var parent_runtime: MissileWeapon = get_parent() as MissileWeapon
	if parent_runtime != null:
		parent_runtime.enqueue_explosion(world_position, attack_id, root_attack_id)
	release(missile)
