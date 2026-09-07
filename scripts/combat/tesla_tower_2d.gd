class_name TeslaTower2D
extends Node2D

const TOWER_TEXTURE: Texture2D = preload(
	"res://assets/player/upgrades/tesla_tower.png"
)
const ARC_CAPACITY: int = 3
const ARMING_SECONDS: float = 0.25
const LIFETIME_SECONDS: float = 30.0
const RANGE_RADIUS_BONUS: float = 500.0
const LIFETIMES: Array[float] = [
	0.0, LIFETIME_SECONDS, LIFETIME_SECONDS, LIFETIME_SECONDS,
]
const PULSE_INTERVALS: Array[float] = [0.0, 1.20, 1.00, 0.90]
const RANGES: Array[float] = [
	0.0,
	430.0 + RANGE_RADIUS_BONUS,
	500.0 + RANGE_RADIUS_BONUS,
	570.0 + RANGE_RADIUS_BONUS,
]
const TARGET_CAPS: Array[int] = [0, 1, 2, 3]
const DAMAGE_MULTIPLIER: float = 3.0
const DAMAGE: Array[float] = [
	0.0,
	18.0 * DAMAGE_MULTIPLIER,
	20.0 * DAMAGE_MULTIPLIER,
	22.0 * DAMAGE_MULTIPLIER,
]

static var _next_pulse_attack_id: int = 4_000_000

var active: bool = false
var paused: bool = false
var current_rank: int = 0
var lifetime_remaining: float = 0.0
var arming_remaining: float = 0.0
var pulse_elapsed: float = 0.0
var deployment_attack_id: int = 0
var deployment_count: int = 0
var pulse_count: int = 0
var accepted_hit_count: int = 0
var robot: GiantRobotController
var encounter: EncounterRuntime
var sprite: Sprite2D
var arcs: Array[TeslaArcVisual2D] = []
var _targets: Array[EnemyActor2D] = []
var _target_distances: PackedFloat32Array = PackedFloat32Array()
var _target_ordinals: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	_targets.resize(ARC_CAPACITY)
	_target_distances.resize(ARC_CAPACITY)
	_target_ordinals.resize(ARC_CAPACITY)


func _ready() -> void:
	z_index = 40
	sprite = Sprite2D.new()
	sprite.name = "TowerSprite"
	sprite.texture = TOWER_TEXTURE
	sprite.centered = true
	sprite.position = Vector2(0.0, -72.0)
	sprite.scale = Vector2.ONE * 0.58
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	for index: int in range(ARC_CAPACITY):
		var arc: TeslaArcVisual2D = TeslaArcVisual2D.new()
		arc.name = "Arc%02d" % index
		add_child(arc)
		arcs.append(arc)
	deactivate()


func setup(p_robot: GiantRobotController, p_encounter: EncounterRuntime) -> void:
	robot = p_robot
	encounter = p_encounter


func activate(origin: Vector2, rank: int, root_attack_id: int) -> bool:
	if robot == null or encounter == null:
		return false
	current_rank = clampi(rank, 1, 3)
	global_position = origin
	lifetime_remaining = LIFETIMES[current_rank]
	arming_remaining = ARMING_SECONDS
	pulse_elapsed = 0.0
	deployment_attack_id = root_attack_id
	deployment_count += 1
	active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	for arc: TeslaArcVisual2D in arcs:
		arc.deactivate()
	reset_physics_interpolation()
	return true


func deactivate() -> void:
	active = false
	current_rank = 0
	lifetime_remaining = 0.0
	arming_remaining = 0.0
	pulse_elapsed = 0.0
	deployment_attack_id = 0
	visible = false
	set_process(false)
	for arc: TeslaArcVisual2D in arcs:
		arc.deactivate()


func set_paused(value: bool) -> void:
	paused = value
	for arc: TeslaArcVisual2D in arcs:
		arc.set_paused(value)


func active_arc_count() -> int:
	var count: int = 0
	for arc: TeslaArcVisual2D in arcs:
		if arc.active:
			count += 1
	return count


func snapshot() -> Dictionary:
	return {
		"active": active,
		"rank": current_rank,
		"remaining": lifetime_remaining,
		"arming_remaining": arming_remaining,
		"deployment_attack_id": deployment_attack_id,
		"deployments": deployment_count,
		"pulses": pulse_count,
		"accepted_hits": accepted_hit_count,
		"arc_capacity": arcs.size(),
		"active_arcs": active_arc_count(),
	}


func _process(delta: float) -> void:
	if not active or paused:
		return
	var safe_delta: float = maxf(delta, 0.0)
	lifetime_remaining = maxf(lifetime_remaining - safe_delta, 0.0)
	if lifetime_remaining <= 0.0:
		deactivate()
		return
	if arming_remaining > 0.0:
		arming_remaining = maxf(arming_remaining - safe_delta, 0.0)
		return
	pulse_elapsed += safe_delta
	if pulse_elapsed < PULSE_INTERVALS[current_rank]:
		return
	pulse_elapsed = fmod(pulse_elapsed, PULSE_INTERVALS[current_rank])
	_pulse()


func _pulse() -> void:
	_clear_targets()
	var range_squared: float = RANGES[current_rank] * RANGES[current_rank]
	var target_limit: int = TARGET_CAPS[current_rank]
	for ordinal: int in range(encounter.actor_registry_count()):
		var enemy: EnemyActor2D = encounter.actor_at_registry_index(ordinal)
		if (
			enemy == null
			or not enemy.active
			or enemy.dead
			or not enemy.visible
			or enemy.hidden_authority
		):
			continue
		var distance_squared: float = global_position.distance_squared_to(
			enemy.global_position
		)
		if distance_squared > range_squared:
			continue
		_insert_target(enemy, distance_squared, ordinal, target_limit)
	var pulse_attack_id: int = _allocate_pulse_attack_id()
	var tower_origin: Vector2 = global_position + Vector2(0.0, -132.0)
	for index: int in range(target_limit):
		var enemy: EnemyActor2D = _targets[index]
		if enemy == null:
			break
		var target_point: Vector2 = enemy.center_of_mass_world_position()
		var direction: Vector2 = (target_point - tower_origin).normalized()
		if direction.is_zero_approx():
			direction = Vector2.RIGHT
		var event: DamageEvent = DamageEvent.new(
			pulse_attack_id,
			robot,
			DAMAGE[current_rank],
			&"tesla_tower",
			target_point,
			direction,
			0.0,
			deployment_attack_id,
			1,
			DamageEvent.FLAG_TESLA_TOWER
		)
		if enemy.receive_damage(event):
			accepted_hit_count += 1
		arcs[index].activate(tower_origin, target_point)
	pulse_count += 1


func _clear_targets() -> void:
	for index: int in range(ARC_CAPACITY):
		_targets[index] = null
		_target_distances[index] = INF
		_target_ordinals[index] = 2_147_483_647


func _insert_target(
	enemy: EnemyActor2D,
	distance_squared: float,
	ordinal: int,
	limit: int
) -> void:
	var insertion_index: int = limit
	for index: int in range(limit):
		if (
			_targets[index] == null
			or distance_squared < _target_distances[index]
			or (
				is_equal_approx(distance_squared, _target_distances[index])
				and ordinal < _target_ordinals[index]
			)
		):
			insertion_index = index
			break
	if insertion_index >= limit:
		return
	for index: int in range(limit - 1, insertion_index, -1):
		_targets[index] = _targets[index - 1]
		_target_distances[index] = _target_distances[index - 1]
		_target_ordinals[index] = _target_ordinals[index - 1]
	_targets[insertion_index] = enemy
	_target_distances[insertion_index] = distance_squared
	_target_ordinals[insertion_index] = ordinal


static func _allocate_pulse_attack_id() -> int:
	_next_pulse_attack_id += 1
	return _next_pulse_attack_id
