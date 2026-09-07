class_name MissileWeapon
extends UpgradeRuntime

const COOLDOWN: float = 4.8
const SALVO_SPACING: float = 0.12
const MIN_RANGE: float = 260.0
const MAX_RANGE: float = 780.0
const IDEAL_RANGE: float = 520.0
const BLAST_RADIUS: float = 150.0
const BLAST_DAMAGE: float = 90.0
const BLAST_IMPULSE: float = 460.0
const QUERY_LIMIT: int = 12
const ACCEPTED_LIMIT: int = 6
const STRUCTURAL_LIMIT: int = 2
const EXPLOSION_QUEUE_CAPACITY: int = 8
const EXPLOSIONS_PER_FRAME: int = 2
const EXPLOSION_VISUAL_CAPACITY: int = 4
const TARGET_MASK: int = (1 << 2) | (1 << 3) | (1 << 6) | (1 << 7)
const MOUNT_TEXTURE: Texture2D = preload(
	"res://assets/player/weapons/missile_pod_mount.png"
)

var arsenal: PlayerArsenalRuntime
var emitter: Node2D
var pool: MissileProjectilePool
var explosion_visuals: Array[MissileExplosionVisual2D] = []
var mount: WeaponDroneVisual2D
var drones: Array[WeaponDroneVisual2D] = []
var cooldown_remaining: float = 0.0
var salvo_remaining: int = 0
var salvo_spacing_remaining: float = 0.0
var salvo_root_attack_id: int = 0
var salvo_targets: Array[EnemyActor2D] = []
var salvo_generations: Array[int] = []
var salvo_points: Array[Vector2] = []
var salvo_cursor: int = 0
var salvos_started: int = 0
var missiles_launched: int = 0
var blast_count: int = 0
var explosion_denial_count: int = 0
var last_blast_accepted: int = 0
var last_blast_structural: int = 0
var _explosion_queue: Array[Dictionary] = []
var _blast_shape: CircleShape2D = CircleShape2D.new()
var _blast_parameters: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
var _explosion_visual_cursor: int = 0


func _init() -> void:
	setup(&"MISSILE", 4)
	pool = MissileProjectilePool.new()
	add_child(pool)
	for index: int in range(EXPLOSION_VISUAL_CAPACITY):
		var visual: MissileExplosionVisual2D = MissileExplosionVisual2D.new()
		visual.name = "MissileExplosion%02d" % index
		add_child(visual)
		explosion_visuals.append(visual)
	_blast_shape.radius = BLAST_RADIUS
	_blast_parameters.shape = _blast_shape
	_blast_parameters.collision_mask = TARGET_MASK
	_blast_parameters.collide_with_areas = true
	_blast_parameters.collide_with_bodies = true


func setup_arsenal(
	p_arsenal: PlayerArsenalRuntime,
	drone_orbit: WeaponDroneOrbit2D
) -> void:
	arsenal = p_arsenal
	for _index: int in range(runtime_max_rank):
		drones.append(drone_orbit.create_drone(
			&"MISSILE",
			MOUNT_TEXTURE,
			Vector2(52.0, 38.0),
			32.0,
			2
		))
	mount = drones[0]
	emitter = mount.muzzle
	_blast_parameters.exclude = [arsenal.robot.get_rid()]


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if stopped or paused or current_rank <= 0 or arsenal == null or emitter == null:
		return
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	if salvo_remaining > 0:
		salvo_spacing_remaining -= delta
		while salvo_remaining > 0 and salvo_spacing_remaining <= 0.0:
			_launch_next_missile()
			salvo_spacing_remaining += SALVO_SPACING
	elif cooldown_remaining <= 0.0:
		_try_start_salvo()
	_flush_explosions()


func apply_rank(total_rank: int, _context: Dictionary = {}) -> bool:
	var next_rank: int = clampi(total_rank, 0, runtime_max_rank)
	if current_rank == next_rank:
		return false
	current_rank = next_rank
	_sync_drones()
	return true


func set_paused(value: bool) -> void:
	super.set_paused(value)
	pool.set_paused(value)
	for visual: MissileExplosionVisual2D in explosion_visuals:
		visual.paused = value
	for drone: WeaponDroneVisual2D in drones:
		drone.paused = value


func stop_and_release() -> void:
	super.stop_and_release()
	pool.release_all()
	_explosion_queue.clear()
	salvo_remaining = 0
	for visual: MissileExplosionVisual2D in explosion_visuals:
		visual.deactivate()
	_set_all_drones_armed(false)


func reset_run() -> void:
	super.reset_run()
	pool.release_all()
	cooldown_remaining = 0.0
	salvo_remaining = 0
	salvo_spacing_remaining = 0.0
	salvo_root_attack_id = 0
	salvo_targets.clear()
	salvo_generations.clear()
	salvo_points.clear()
	salvo_cursor = 0
	salvos_started = 0
	missiles_launched = 0
	blast_count = 0
	explosion_denial_count = 0
	last_blast_accepted = 0
	last_blast_structural = 0
	_explosion_queue.clear()
	_explosion_visual_cursor = 0
	for visual: MissileExplosionVisual2D in explosion_visuals:
		visual.paused = false
		visual.deactivate()
	_set_all_drones_armed(false)


func enqueue_explosion(
	world_position: Vector2,
	attack_id: int,
	root_attack_id: int
) -> bool:
	if _explosion_queue.size() >= EXPLOSION_QUEUE_CAPACITY:
		explosion_denial_count += 1
		return false
	_explosion_queue.append({
		"position": world_position,
		"attack_id": attack_id,
		"root_attack_id": root_attack_id,
	})
	return true


func pending_explosion_count() -> int:
	return _explosion_queue.size()


func active_explosion_visual_count() -> int:
	var total: int = 0
	for visual: MissileExplosionVisual2D in explosion_visuals:
		if visual.active:
			total += 1
	return total


func rebase_cached_world_state(offset: Vector2) -> void:
	for index: int in range(salvo_points.size()):
		salvo_points[index] += offset
	for record: Dictionary in _explosion_queue:
		record.position = (record.position as Vector2) + offset


func flush_explosions() -> void:
	_flush_explosions()


func ordered_targets() -> Array[EnemyActor2D]:
	var candidates: Array[EnemyActor2D] = []
	for enemy: EnemyActor2D in arsenal.actors:
		if not arsenal.target_matches_class(
			enemy,
			PlayerArsenalRuntime.TargetClass.ANY
		):
			continue
		var distance: float = arsenal.robot.global_position.distance_to(enemy.global_position)
		if distance < MIN_RANGE or distance > MAX_RANGE:
			continue
		candidates.append(enemy)
	if candidates.size() > 1:
		candidates.sort_custom(_target_precedes)
	return candidates


func _try_start_salvo() -> void:
	var candidates: Array[EnemyActor2D] = ordered_targets()
	if candidates.is_empty():
		return
	salvo_targets.clear()
	salvo_generations.clear()
	salvo_points.clear()
	for enemy: EnemyActor2D in candidates:
		salvo_targets.append(enemy)
		salvo_generations.append(enemy.activation_generation)
		salvo_points.append(enemy.global_position)
	salvo_root_attack_id = arsenal.reserve_attack_id()
	salvo_remaining = current_rank
	salvo_cursor = 0
	salvo_spacing_remaining = 0.0
	cooldown_remaining = arsenal.scale_cooldown(COOLDOWN)
	salvos_started += 1
	_launch_next_missile()
	salvo_spacing_remaining = SALVO_SPACING


func _launch_next_missile() -> void:
	if salvo_remaining <= 0 or salvo_targets.is_empty():
		return
	var target_index: int = salvo_cursor % salvo_targets.size()
	var attack_id: int = arsenal.reserve_attack_id()
	var firing_drone: WeaponDroneVisual2D = _drone_for_launch(salvo_cursor)
	if firing_drone != null:
		mount = firing_drone
		emitter = firing_drone.muzzle
		firing_drone.aim_at(
			emitter.global_position.direction_to(salvo_points[target_index])
		)
	var missile: MissileProjectile2D = pool.acquire(
		emitter.global_position,
		salvo_targets[target_index],
		salvo_generations[target_index],
		salvo_points[target_index],
		attack_id,
		salvo_root_attack_id
	)
	if missile != null:
		missiles_launched += 1
	salvo_cursor += 1
	salvo_remaining -= 1


func _drone_for_launch(index: int) -> WeaponDroneVisual2D:
	if current_rank <= 0 or drones.is_empty():
		return null
	return drones[index % mini(current_rank, drones.size())]


func _sync_drones() -> void:
	for index: int in range(drones.size()):
		drones[index].set_armed(index < current_rank)
	mount = drones[0] if not drones.is_empty() else null
	emitter = mount.muzzle if mount != null else null


func _set_all_drones_armed(value: bool) -> void:
	for drone: WeaponDroneVisual2D in drones:
		drone.set_armed(value)


func _flush_explosions() -> void:
	var count: int = mini(EXPLOSIONS_PER_FRAME, _explosion_queue.size())
	for _explosion_index: int in range(count):
		var record: Dictionary = _explosion_queue.pop_front()
		_resolve_blast(
			record.position,
			int(record.attack_id),
			int(record.root_attack_id)
		)


func _resolve_blast(origin: Vector2, attack_id: int, root_attack_id: int) -> void:
	explosion_visuals[_explosion_visual_cursor].activate(origin)
	_explosion_visual_cursor = (
		(_explosion_visual_cursor + 1) % explosion_visuals.size()
	)
	_blast_parameters.transform = Transform2D(0.0, origin)
	var results: Array[Dictionary] = (
		arsenal.robot.get_world_2d().direct_space_state.intersect_shape(
			_blast_parameters,
			QUERY_LIMIT
		)
	)
	if results.size() > 1:
		results.sort_custom(_blast_result_precedes.bind(origin))
	var seen: Dictionary[int, bool] = {}
	last_blast_accepted = 0
	last_blast_structural = 0
	for result: Dictionary in results:
		var collider: Node2D = result.get("collider") as Node2D
		if collider == null:
			continue
		var receiver: Node = DamageReceiverLookup.find(collider)
		if receiver == null or receiver == arsenal.robot:
			continue
		var receiver_id: int = receiver.get_instance_id()
		if seen.has(receiver_id):
			continue
		seen[receiver_id] = true
		var structural: bool = receiver is Destructible2D or receiver is StructuralBuilding2D
		if structural and last_blast_structural >= STRUCTURAL_LIMIT:
			continue
		var distance: float = minf(origin.distance_to(collider.global_position), BLAST_RADIUS)
		var damage: float = arsenal.scale_damage(
			BLAST_DAMAGE * (1.0 - distance / BLAST_RADIUS),
			&"missile",
			receiver,
			attack_id
		)
		if damage <= 0.0:
			continue
		var direction: Vector2 = origin.direction_to(collider.global_position)
		var event: DamageEvent = DamageEvent.new(
			attack_id,
			arsenal.robot,
			damage,
			&"missile",
			collider.global_position,
			direction,
			BLAST_IMPULSE,
			root_attack_id
		)
		if bool(receiver.call("receive_damage", event)):
			last_blast_accepted += 1
			if structural:
				last_blast_structural += 1
		if last_blast_accepted >= ACCEPTED_LIMIT:
			break
	blast_count += 1


func _target_precedes(a: EnemyActor2D, b: EnemyActor2D) -> bool:
	var a_offset: Vector2 = a.global_position - arsenal.robot.global_position
	var b_offset: Vector2 = b.global_position - arsenal.robot.global_position
	var facing: float = float(arsenal.robot.facing)
	var a_penalty: int = 0 if a_offset.x * facing >= 0.0 else 1
	var b_penalty: int = 0 if b_offset.x * facing >= 0.0 else 1
	if a_penalty != b_penalty:
		return a_penalty < b_penalty
	var a_error: float = absf(a_offset.length() - IDEAL_RANGE)
	var b_error: float = absf(b_offset.length() - IDEAL_RANGE)
	if not is_equal_approx(a_error, b_error):
		return a_error < b_error
	if not is_equal_approx(absf(a_offset.y), absf(b_offset.y)):
		return absf(a_offset.y) < absf(b_offset.y)
	return a.get_instance_id() < b.get_instance_id()


func _blast_result_precedes(a: Dictionary, b: Dictionary, origin: Vector2) -> bool:
	var a_node: Node2D = a.get("collider") as Node2D
	var b_node: Node2D = b.get("collider") as Node2D
	var a_distance: float = origin.distance_squared_to(a_node.global_position)
	var b_distance: float = origin.distance_squared_to(b_node.global_position)
	if not is_equal_approx(a_distance, b_distance):
		return a_distance < b_distance
	return a_node.get_instance_id() < b_node.get_instance_id()
