class_name FlamethrowerRuntime
extends UpgradeRuntime

const FLAME_CAPACITY: int = 6
const SCORCH_CAPACITY: int = 8
const LOOP_AUDIO_VOICES: int = 1
const DAMAGE_PER_TICK: Array[float] = [0.0, 12.0, 14.0, 15.0, 15.0, 18.0]
const MAXIMUM_TARGETS: Array[int] = [0, 4, 5, 5, 6, 6]
const MOUNT_TEXTURE: Texture2D = preload(
	"res://assets/player/weapons/flamethrower_nozzle.png"
)

var arsenal: PlayerArsenalRuntime
var emitter: Node2D
var resolver: FlamethrowerConeResolver = FlamethrowerConeResolver.new()
var flames: Array[FlameVisualSlot2D] = []
var scorches: Array[ScorchVisualSlot2D] = []
var loop_audio: AudioStreamPlayer2D
var cooldown_remaining: float = 0.0
var burst_active: bool = false
var burst_direction: Vector2 = Vector2.RIGHT
var burst_root_attack_id: int = 0
var ticks_remaining: int = 0
var tick_remaining: float = 0.0
var bursts_started: int = 0
var ticks_delivered: int = 0
var loop_audio_active: bool = false
var mount: WeaponDroneVisual2D
var active_drone: WeaponDroneVisual2D
var drones: Array[WeaponDroneVisual2D] = []
var _flame_cursor: int = 0
var _scorch_cursor: int = 0
var _drone_cursor: int = 0


func _init() -> void:
	setup(&"FLAMETHROWER", 5)
	for index: int in range(FLAME_CAPACITY):
		var flame: FlameVisualSlot2D = FlameVisualSlot2D.new()
		flame.name = "FlameVisual%02d" % index
		add_child(flame)
		flames.append(flame)
	for index: int in range(SCORCH_CAPACITY):
		var scorch: ScorchVisualSlot2D = ScorchVisualSlot2D.new()
		scorch.name = "ScorchVisual%02d" % index
		add_child(scorch)
		scorches.append(scorch)
	loop_audio = AudioStreamPlayer2D.new()
	loop_audio.name = "FlamethrowerLoopAudio"
	loop_audio.bus = GameAudioBus.SFX
	add_child(loop_audio)


func setup_arsenal(
	p_arsenal: PlayerArsenalRuntime,
	drone_orbit: WeaponDroneOrbit2D
) -> void:
	arsenal = p_arsenal
	for _index: int in range(runtime_max_rank):
		drones.append(drone_orbit.create_drone(
			&"FLAMETHROWER",
			MOUNT_TEXTURE,
			Vector2(58.0, 38.0),
			38.0,
			5
		))
	mount = drones[0]
	emitter = mount.muzzle


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if stopped or paused or current_rank <= 0 or arsenal == null or emitter == null:
		return
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	if burst_active:
		_advance_burst(delta)
		return
	if cooldown_remaining > 0.0:
		return
	var firing_drone: WeaponDroneVisual2D = _peek_next_drone()
	var firing_emitter: Node2D = firing_drone.muzzle if firing_drone != null else emitter
	var direction: Vector2 = resolver.target_direction(
		arsenal,
		firing_emitter.global_position,
		flame_range()
	)
	if direction.is_zero_approx():
		return
	_start_burst(direction)
	_advance_burst(0.0)


func apply_rank(total_rank: int, _context: Dictionary = {}) -> bool:
	var next_rank: int = clampi(total_rank, 0, runtime_max_rank)
	if current_rank == next_rank:
		return false
	current_rank = next_rank
	_sync_drones()
	return true


func set_paused(value: bool) -> void:
	super.set_paused(value)
	for flame: FlameVisualSlot2D in flames:
		flame.paused = value
	for scorch: ScorchVisualSlot2D in scorches:
		scorch.paused = value
	for drone: WeaponDroneVisual2D in drones:
		drone.paused = value
	if value:
		_stop_loop_audio()
	elif burst_active:
		_start_loop_audio()


func stop_and_release() -> void:
	super.stop_and_release()
	burst_active = false
	_stop_loop_audio()
	for flame: FlameVisualSlot2D in flames:
		flame.deactivate()
	for scorch: ScorchVisualSlot2D in scorches:
		scorch.deactivate()
	active_drone = null
	_set_all_drones_armed(false)


func reset_run() -> void:
	super.reset_run()
	cooldown_remaining = 0.0
	burst_active = false
	burst_direction = Vector2.RIGHT
	burst_root_attack_id = 0
	ticks_remaining = 0
	tick_remaining = 0.0
	bursts_started = 0
	ticks_delivered = 0
	_flame_cursor = 0
	_scorch_cursor = 0
	_drone_cursor = 0
	active_drone = null
	_stop_loop_audio()
	_set_all_drones_armed(false)


func flame_range() -> float:
	if current_rank >= 5:
		return 255.0
	return 235.0 if current_rank >= 3 else 220.0


func half_angle() -> float:
	if current_rank >= 5:
		return deg_to_rad(40.0)
	return deg_to_rad(38.0) if current_rank >= 3 else deg_to_rad(32.0)


func damage_per_tick() -> float:
	return DAMAGE_PER_TICK[current_rank]


func tick_count() -> int:
	return 5 if current_rank >= 4 else 4


func tick_interval() -> float:
	var base_interval: float = 0.18 if current_rank >= 5 else 0.20
	return arsenal.scale_cooldown(base_interval) if arsenal != null else base_interval


func maximum_targets() -> int:
	return MAXIMUM_TARGETS[current_rank]


func cooldown_duration() -> float:
	var base_duration: float = 1.0 if current_rank >= 5 else 1.20
	return arsenal.scale_cooldown(base_duration) if arsenal != null else base_duration


func active_flame_count() -> int:
	var total: int = 0
	for flame: FlameVisualSlot2D in flames:
		if flame.active:
			total += 1
	return total


func active_scorch_count() -> int:
	var total: int = 0
	for scorch: ScorchVisualSlot2D in scorches:
		if scorch.active:
			total += 1
	return total


func _start_burst(direction: Vector2) -> void:
	burst_active = true
	burst_direction = direction
	burst_root_attack_id = arsenal.reserve_attack_id()
	ticks_remaining = tick_count()
	tick_remaining = 0.0
	bursts_started += 1
	active_drone = _next_drone()
	if active_drone != null:
		mount = active_drone
		emitter = active_drone.muzzle
		active_drone.aim_at(direction)
	_start_loop_audio()


func _advance_burst(delta: float) -> void:
	_sync_loop_audio_position()
	tick_remaining -= delta
	while burst_active and tick_remaining <= 0.0:
		_deliver_tick()
		ticks_remaining -= 1
		if ticks_remaining <= 0:
			burst_active = false
			active_drone = null
			cooldown_remaining = cooldown_duration()
			_stop_loop_audio()
			return
		tick_remaining += tick_interval()


func _deliver_tick() -> void:
	var origin: Vector2 = emitter.global_position
	var attack_id: int = arsenal.reserve_attack_id()
	var damage: float = arsenal.scale_damage(
		damage_per_tick(),
		&"flamethrower",
		null,
		attack_id
	)
	resolver.resolve_tick(
		arsenal.robot,
		origin,
		burst_direction,
		flame_range(),
		half_angle(),
		damage,
		maximum_targets(),
		attack_id,
		burst_root_attack_id
	)
	flames[_flame_cursor].activate(origin, burst_direction, flame_range(), half_angle())
	_flame_cursor = (_flame_cursor + 1) % flames.size()
	for hit_position: Vector2 in resolver.accepted_positions:
		scorches[_scorch_cursor].activate(hit_position)
		_scorch_cursor = (_scorch_cursor + 1) % scorches.size()
	ticks_delivered += 1


func _start_loop_audio() -> void:
	loop_audio_active = true
	_sync_loop_audio_position()
	if loop_audio.stream != null and not loop_audio.playing:
		loop_audio.play()


func _stop_loop_audio() -> void:
	loop_audio_active = false
	loop_audio.stop()


func _sync_loop_audio_position() -> void:
	if loop_audio != null and emitter != null:
		loop_audio.global_position = emitter.global_position


func _next_drone() -> WeaponDroneVisual2D:
	var drone: WeaponDroneVisual2D = _peek_next_drone()
	if drone == null:
		return null
	var active_total: int = mini(current_rank, drones.size())
	_drone_cursor = (_drone_cursor + 1) % active_total
	return drone


func _peek_next_drone() -> WeaponDroneVisual2D:
	if current_rank <= 0 or drones.is_empty():
		return null
	var active_total: int = mini(current_rank, drones.size())
	return drones[_drone_cursor % active_total]


func _sync_drones() -> void:
	for index: int in range(drones.size()):
		drones[index].set_armed(index < current_rank)
	if current_rank <= 0 or _drone_cursor >= current_rank:
		_drone_cursor = 0
	mount = drones[0] if not drones.is_empty() else null
	emitter = mount.muzzle if mount != null else null


func _set_all_drones_armed(value: bool) -> void:
	for drone: WeaponDroneVisual2D in drones:
		drone.set_armed(value)
